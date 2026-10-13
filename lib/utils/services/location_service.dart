import 'package:soullocket_app/utils/ui_copy.dart';
// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/permission_helper.dart';
import 'offline_cache_service.dart';
import 'package:soullocket_app/views/map/map_screen.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'house_service.dart';
import 'role_utils.dart';
import 'app_lifecycle_presence_guard.dart';
import 'gps_tracking_state.dart';
import '../../widgets/sl_dialog.dart';

export 'gps_tracking_state.dart';

class LocationService {
  factory LocationService() => _instance;

  LocationService._()
    : _dbRef = FirebaseDatabase.instance.ref(),
      _prefsProvider = (() async =>
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance()),
      _uidProvider = (() => FirebaseAuth.instance.currentUser?.uid),
      _ensureDatabaseOnline = (() => FirebaseDatabase.instance.goOnline()),
      _now = DateTime.now;

  @visibleForTesting
  LocationService.forTesting({
    required DatabaseReference database,
    required SharedPreferences preferences,
    required String? Function() currentUid,
    DateTime Function()? now,
    Future<void> Function()? ensureDatabaseOnline,
  }) : _dbRef = database,
       _prefsProvider = (() async => preferences),
       _uidProvider = currentUid,
       _ensureDatabaseOnline = ensureDatabaseOnline ?? (() async {}),
       _now = now ?? DateTime.now;

  static final LocationService _instance = LocationService._();

  static const int _kGpsHistoryRetentionDays = 14;
  static const int _kGpsHistoryMaxPointsPerDay = 600;
  static const Duration _kGpsHistoryCleanupInterval = Duration(hours: 6);
  static const Duration _kInitialPositionTimeout = Duration(seconds: 15);
  static const Duration _kFirebaseMinWriteInterval = Duration(seconds: 60);
  static const Duration _kLastKnownMaxAge = Duration(minutes: 5);
  static const Duration _kLiveSourceMaxAge = Duration(minutes: 2);
  static const int _kStreamDistanceFilterMeters = 25;
  static const double _kMaxAcceptedAccuracyMeters = 100;
  static const double _kGoodAccuracyMeters = 30;
  static const double _kFairAccuracyMeters = 75;
  static const double _kForceWriteDistanceMeters = 50;
  static const double _kStationaryDistanceMeters = 15;
  static const double _kAccuracyImprovementMeters = 20;
  static const double _kMaxPlausibleSpeedMps = 70;

  final DatabaseReference _dbRef;
  final Future<SharedPreferences> Function() _prefsProvider;
  final String? Function() _uidProvider;
  final Future<void> Function() _ensureDatabaseOnline;
  final DateTime Function() _now;
  final ValueNotifier<GpsTrackingState> _trackingState = ValueNotifier(
    const GpsTrackingState(),
  );
  ValueListenable<GpsTrackingState> get trackingState => _trackingState;
  Future<void> _operationTail = Future<void>.value();
  Future<void> _positionTail = Future<void>.value();
  int _requestEpoch = 0;
  int _trackingEpoch = 0;
  int? _activeTrackingEpoch;
  int _permissionRequestDepth = 0;
  int _lastSyncedSourceTs = 0;
  bool _appInForeground = true;
  bool _activeBackgroundEnabled = false;
  String? _activeMode;
  String? _activeUid;
  String? _cachedUid;
  Position? _lastWrittenPosition;
  static const MethodChannel _deviceInfoChannel = MethodChannel(
    'soul_locket/device_info',
  );
  StreamSubscription<Position>? _positionStream;
  String? _activeHouseId;
  String? _activeRole;
  Position? _lastAcceptedPosition;
  int _lastAcceptedTs = 0;
  Map<String, dynamic>? _lastGpsPayload;
  final Map<String, int> _historyCleanupTsByScope = <String, int>{};
  StreamSubscription? _partnerMapVisibilitySub;
  bool _partnerIsViewingMap = false;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _operationTail.then((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  void _setTrackingState(GpsTrackingIssue issue) {
    _trackingState.value = GpsTrackingState(
      issue: issue,
      isTracking: _positionStream != null,
      backgroundEnabled: _activeBackgroundEnabled,
      lastSyncedAt: _lastSyncedSourceTs > 0
          ? DateTime.fromMillisecondsSinceEpoch(_lastSyncedSourceTs)
          : null,
    );
  }

  Future<bool> requestPermission({
    BuildContext? context,
    bool forcePrompt = false,
  }) async {
    _permissionRequestDepth++;
    try {
      return await _requestPermission(context: context);
    } finally {
      _permissionRequestDepth--;
    }
  }

  Future<bool> _requestPermission({BuildContext? context}) async {
    try {
      final prefs = await _prefsProvider();

      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 6),
        onTimeout: () => LocationPermission.denied,
      );

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context == null || !context.mounted) {
          _setTrackingState(GpsTrackingIssue.permissionRequired);
          return false;
        }
        final granted = await PermissionHelper.requestLocationWithDisclosure(
          context,
          title: context.tr('map_refresh_permission_title'),
          disclosure: context.tr('map_refresh_disclosure'),
        );
        await prefs.setBool('il_gps_prompted', true);
        if (!granted) {
          _setTrackingState(GpsTrackingIssue.permissionRequired);
          return false;
        }
      }

      final refreshedPermission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 6),
        onTimeout: () => LocationPermission.denied,
      );
      if (refreshedPermission != LocationPermission.whileInUse &&
          refreshedPermission != LocationPermission.always) {
        _setTrackingState(GpsTrackingIssue.permissionRequired);
        return false;
      }

      // Đợi tối đa 3 giây để hệ thống phản hồi trạng thái dịch vụ (đề phòng delay)
      bool serviceEnabled = false;
      for (int i = 0; i < 3; i++) {
        serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 2),
          onTimeout: () => kIsWeb,
        );
        if (serviceEnabled) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (!serviceEnabled) {
        _setTrackingState(GpsTrackingIssue.serviceDisabled);
        return false;
      }

      return true;
    } catch (e) {
      _setTrackingState(GpsTrackingIssue.unavailable);
      if (kDebugMode) {
        debugPrint(
          'LocationService.requestPermission error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể xin quyền vị trí lúc này.').message}',
        );
      }
      return false;
    }
  }

  Future<bool> requestBackgroundPermission({BuildContext? context}) async {
    _permissionRequestDepth++;
    try {
      return await _requestBackgroundPermission(context: context);
    } catch (_) {
      return false;
    } finally {
      _permissionRequestDepth--;
    }
  }

  Future<bool> _requestBackgroundPermission({BuildContext? context}) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    if (await hasBackgroundPermission()) return true;
    if (context == null || !context.mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => SLAlertDialog(
        scrollable: true,
        title: Text(ctx.tr('settings_gps_mode_always')),
        content: Text(ctx.tr('map_refresh_privacy_body')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('map_refresh_not_now')),
          ),
          SLDialogAction(
            primary: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('map_refresh_continue')),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return false;
    await AppLifecyclePresenceGuard.guard(
      app_permission.Permission.locationAlways.request,
    );
    if (await hasBackgroundPermission()) return true;
    if (!context.mounted) return false;
    // Android 11+ có thể yêu cầu người dùng tự chọn “Luôn cho phép”.
    // Chỉ mở Cài đặt sau một lần xác nhận riêng, không mở lúc khởi động app.
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => SLAlertDialog(
        scrollable: true,
        title: Text(ctx.tr('settings_gps_mode_title')),
        content: Text(ctx.tr('map_refresh_privacy_body')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('map_refresh_not_now')),
          ),
          SLDialogAction(
            primary: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('map_refresh_open_settings')),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await AppLifecyclePresenceGuard.guard(Geolocator.openAppSettings);
    }
    // Future mở Cài đặt chỉ xác nhận đã mở, không xác nhận người dùng cấp quyền.
    // onAppResumed kiểm tra lại khi người dùng thực sự trở về ứng dụng.
    return hasBackgroundPermission();
  }

  static const String kGpsUpdateModeKey = 'il_gps_update_mode';
  static const String kGpsModeForegroundOnly = 'foreground_only';
  static const String kGpsModeAlways = 'always';

  static Future<String> getGpsUpdateMode() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return _normalizeMode(prefs.getString(kGpsUpdateModeKey));
  }

  static String _normalizeMode(String? mode) =>
      mode == kGpsModeAlways ? kGpsModeAlways : kGpsModeForegroundOnly;

  Future<String> _readMode() async =>
      _normalizeMode((await _prefsProvider()).getString(kGpsUpdateModeKey));

  static Future<void> setGpsUpdateMode(String mode) async {
    await LocationService().applyGpsUpdateMode(mode);
  }

  Future<bool> applyGpsUpdateMode(
    String mode, {
    String? houseId,
    String? role,
    BuildContext? context,
    bool requestBackgroundAccess = false,
  }) {
    if (mode != kGpsModeAlways && mode != kGpsModeForegroundOnly) {
      throw ArgumentError.value(mode, 'mode');
    }
    final requestEpoch = ++_requestEpoch;
    final requestedUid = _uidProvider();
    ++_trackingEpoch;
    _setTrackingState(GpsTrackingIssue.checking);
    return _serialize(() async {
      if (requestEpoch != _requestEpoch || requestedUid != _uidProvider()) {
        return false;
      }
      final targetHouse = houseId ?? _activeHouseId ?? _cachedHouseId;
      final targetRole = role ?? _activeRole ?? _cachedRole;
      if (requestedUid != null && targetHouse != null && targetRole != null) {
        _cachedHouseId = targetHouse;
        _cachedRole = targetRole;
        _cachedUid = requestedUid;
      }
      await _stopTracking(clearCachedTarget: false);
      _setTrackingState(GpsTrackingIssue.checking);
      final prefs = await _prefsProvider();
      if (!await prefs.setString(kGpsUpdateModeKey, mode)) {
        _setTrackingState(GpsTrackingIssue.unavailable);
        return false;
      }
      if (requestBackgroundAccess &&
          mode == kGpsModeAlways &&
          context != null) {
        if (!context.mounted) return false;
        final allowed = await requestPermission(context: context);
        if (allowed &&
            context.mounted &&
            requestEpoch == _requestEpoch &&
            requestedUid == _uidProvider()) {
          await requestBackgroundPermission(context: context);
        }
      }
      if (targetHouse == null || targetRole == null || requestedUid == null) {
        _setTrackingState(GpsTrackingIssue.stopped);
        return false;
      }
      if (requestEpoch != _requestEpoch || requestedUid != _uidProvider()) {
        return false;
      }
      return _startTracking(
        targetHouse,
        targetRole,
        requestEpoch: requestEpoch,
        requestedUid: requestedUid,
        context: context != null && context.mounted ? context : null,
      );
    }).catchError((Object error, StackTrace stack) {
      if (requestEpoch == _requestEpoch) {
        _setTrackingState(GpsTrackingIssue.unavailable);
      }
      unawaited(
        ErrorLoggerService.instance.logError(
          error,
          stack,
          reason: 'LocationService apply GPS mode failed',
          fatal: false,
        ),
      );
      return false;
    });
  }

  String? _cachedHouseId;
  String? _cachedRole;

  Future<void> onAppBackgrounded() async {
    _appInForeground = false;
    final mode = await _readMode();
    if (_appInForeground) return;
    if (mode != kGpsModeAlways || !_activeBackgroundEnabled) {
      // Hộp quyền native cũng làm Home inactive. Không hủy lựa chọn vừa lưu;
      // vẫn ngừng tọa độ foreground và kiểm tra lại khi người dùng quay về.
      if (_permissionRequestDepth == 0) ++_requestEpoch;
      ++_trackingEpoch;
      _setTrackingState(GpsTrackingIssue.stopped);
      await _serialize(() async {
        if (!_appInForeground && !_activeBackgroundEnabled) {
          await _stopTracking(clearCachedTarget: false);
        }
      });
    }
  }

  Future<void> onAppResumed([String? houseId, String? role]) async {
    _appInForeground = true;
    if (_cachedUid != null && _cachedUid != _uidProvider()) {
      await stopTracking();
      return;
    }
    final targetHouseId = houseId ?? _cachedHouseId;
    final targetRole = role ?? _cachedRole;
    if ((targetHouseId ?? '').trim().isNotEmpty &&
        (targetRole ?? '').trim().isNotEmpty) {
      await startTracking(targetHouseId!, targetRole!);
    }
  }

  Future<bool> hasBackgroundPermission() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      final status = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 6),
        onTimeout: () => LocationPermission.denied,
      );
      return status == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startTracking(
    String houseId,
    String role, {
    BuildContext? context,
    bool forcePrompt = false,
  }) {
    final requestedUid = _uidProvider();
    if (_cachedHouseId != houseId.trim() ||
        _cachedRole != role.trim() ||
        _cachedUid != requestedUid) {
      ++_requestEpoch;
      ++_trackingEpoch;
    }
    final requestEpoch = _requestEpoch;
    return _serialize(
      () => _startTracking(
        houseId,
        role,
        context: context,
        forcePrompt: forcePrompt,
        requestEpoch: requestEpoch,
        requestedUid: requestedUid,
      ),
    );
  }

  Future<bool> _startTracking(
    String houseId,
    String role, {
    BuildContext? context,
    bool forcePrompt = false,
    required int requestEpoch,
    required String? requestedUid,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = role.trim();
    final uid = _uidProvider();
    if (normalizedHouseId.isEmpty ||
        (normalizedRole != 'user1' && normalizedRole != 'user2') ||
        uid == null ||
        uid != requestedUid ||
        requestEpoch != _requestEpoch) {
      return false;
    }
    _cachedHouseId = normalizedHouseId;
    _cachedRole = normalizedRole;
    _cachedUid = uid;
    _setTrackingState(GpsTrackingIssue.checking);

    final hasPermission = await requestPermission(
      context: context,
      forcePrompt: forcePrompt,
    );
    if (requestEpoch != _requestEpoch || _uidProvider() != uid) return false;
    if (!hasPermission) {
      final issue = _trackingState.value.issue;
      await _stopTracking(clearCachedTarget: false);
      _setTrackingState(issue);
      return false;
    }

    final mode = await _readMode();
    final useBackgroundSettings =
        mode == kGpsModeAlways && !kIsWeb && await hasBackgroundPermission();
    if (requestEpoch != _requestEpoch || _uidProvider() != uid) return false;
    if (!_appInForeground && !useBackgroundSettings) {
      _setTrackingState(
        mode == kGpsModeAlways
            ? GpsTrackingIssue.backgroundPermissionRequired
            : GpsTrackingIssue.stopped,
      );
      return false;
    }

    final sameTarget =
        _activeHouseId == normalizedHouseId &&
        _activeRole == normalizedRole &&
        _activeUid == uid &&
        _positionStream != null &&
        _activeTrackingEpoch == _trackingEpoch &&
        _activeMode == mode &&
        _activeBackgroundEnabled == useBackgroundSettings;
    if (sameTarget) {
      _setTrackingState(
        mode == kGpsModeAlways && !useBackgroundSettings
            ? GpsTrackingIssue.backgroundPermissionRequired
            : GpsTrackingIssue.none,
      );
      return mode != kGpsModeAlways || useBackgroundSettings;
    }

    await _stopTracking(clearCachedTarget: false);
    if (requestEpoch != _requestEpoch || _uidProvider() != uid) return false;
    if (context != null && !context.mounted) return false;

    _activeHouseId = normalizedHouseId;
    _activeRole = normalizedRole;
    _activeUid = uid;
    _activeMode = mode;
    _activeBackgroundEnabled = useBackgroundSettings;
    _lastGpsPayload = null;
    _lastAcceptedPosition = null;
    _lastAcceptedTs = 0;
    _lastFirebaseUpdateTs = 0;
    _lastSyncedSourceTs = 0;
    _lastWrittenPosition = null;
    final trackingEpoch = _trackingEpoch;
    _activeTrackingEpoch = trackingEpoch;

    final oppositeRole = normalizedRole == 'user1' ? 'user2' : 'user1';
    _partnerMapVisibilitySub?.cancel();
    _partnerMapVisibilitySub = _dbRef
        .child('houses/$normalizedHouseId/presence/$oppositeRole/isViewingMap')
        .onValue
        .listen(
          (event) {
            if (trackingEpoch != _trackingEpoch) return;
            _partnerIsViewingMap = event.snapshot.value == true;
          },
          onError: (Object error, StackTrace stack) {
            // Trạng thái người xem chỉ là tối ưu pin, không làm hỏng luồng GPS.
            if (trackingEpoch == _trackingEpoch) _partnerIsViewingMap = false;
          },
        );

    try {
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: useBackgroundSettings
                ? _backgroundCapableLocationSettings
                : _foregroundLocationSettings,
          ).listen(
            (position) => _queuePositionUpdate(
              normalizedHouseId,
              normalizedRole,
              position,
              trackingEpoch: trackingEpoch,
            ),
            onError: (Object error, StackTrace stack) {
              if (trackingEpoch != _trackingEpoch) return;
              _stopFailedStream(trackingEpoch);
            },
            onDone: () {
              if (trackingEpoch != _trackingEpoch) return;
              _stopFailedStream(trackingEpoch);
            },
          );
    } catch (_) {
      await _stopTracking(clearCachedTarget: false);
      _setTrackingState(GpsTrackingIssue.unavailable);
      return false;
    }
    _setTrackingState(
      mode == kGpsModeAlways && !useBackgroundSettings
          ? GpsTrackingIssue.backgroundPermissionRequired
          : GpsTrackingIssue.none,
    );
    unawaited(
      _loadInitialPosition(normalizedHouseId, normalizedRole, trackingEpoch),
    );
    return mode != kGpsModeAlways || useBackgroundSettings;
  }

  Future<void> _loadInitialPosition(
    String houseId,
    String role,
    int trackingEpoch,
  ) async {
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _bestForegroundAccuracy,
          timeLimit: _kInitialPositionTimeout,
        ),
      ).timeout(_kInitialPositionTimeout);
      _queuePositionUpdate(
        houseId,
        role,
        initialPosition,
        forceWrite: true,
        trackingEpoch: trackingEpoch,
      );
    } catch (e) {
      if (trackingEpoch != _trackingEpoch) return;
      if (kDebugMode) {
        final errorMsg = AppErrorMapper.resolve(
          e,
          fallbackMessage: UiCopy.text('copy_698a8ac897bc'),
        ).message;
        if (!errorMsg.contains('thời gian chờ')) {
          debugPrint('LocationService.getCurrentPosition error: $errorMsg');
        }
      }
      try {
        final lastKnown = await Geolocator.getLastKnownPosition().timeout(
          const Duration(seconds: 3),
        );
        if (lastKnown != null && _isFreshEnoughLastKnown(lastKnown)) {
          _queuePositionUpdate(
            houseId,
            role,
            lastKnown,
            forceWrite: true,
            trackingEpoch: trackingEpoch,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'LocationService.getLastKnownPosition error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể đọc vị trí gần nhất lúc này.').message}',
          );
        }
      }
    }
  }

  void _stopFailedStream(int trackingEpoch) {
    if (trackingEpoch != _trackingEpoch) return;
    final failureEpoch = ++_trackingEpoch;
    final failureRequestEpoch = ++_requestEpoch;
    _setTrackingState(GpsTrackingIssue.unavailable);
    unawaited(
      _serialize(() async {
        if (failureEpoch != _trackingEpoch) return;
        await _stopTracking(clearCachedTarget: false);
        if (failureRequestEpoch == _requestEpoch) {
          _setTrackingState(GpsTrackingIssue.unavailable);
        }
      }),
    );
  }

  Future<void> stopTracking({
    String? houseId,
    String? role,
    bool clearCachedTarget = true,
  }) {
    ++_requestEpoch;
    ++_trackingEpoch;
    _setTrackingState(GpsTrackingIssue.stopped);
    return _serialize(
      () => _stopTracking(
        houseId: houseId,
        role: role,
        clearCachedTarget: clearCachedTarget,
      ),
    );
  }

  Future<void> _stopTracking({
    String? houseId,
    String? role,
    required bool clearCachedTarget,
  }) async {
    ++_trackingEpoch;
    await _positionStream?.cancel();
    _positionStream = null;
    await _partnerMapVisibilitySub?.cancel();
    _partnerMapVisibilitySub = null;
    _partnerIsViewingMap = false;

    final resolvedHouseId = houseId ?? _activeHouseId;
    final resolvedRole = role ?? _activeRole;
    final resolvedUid = _activeUid;
    final lastPayload = _lastGpsPayload == null
        ? null
        : Map<String, dynamic>.from(_lastGpsPayload!);

    _activeHouseId = null;
    _activeRole = null;
    _activeUid = null;
    _activeTrackingEpoch = null;
    _activeMode = null;
    _activeBackgroundEnabled = false;
    _lastGpsPayload = null;
    _lastWrittenPosition = null;
    _lastFirebaseUpdateTs = 0;
    _lastSyncedSourceTs = 0;
    _positionTail = Future<void>.value();
    if (clearCachedTarget) {
      _cachedHouseId = null;
      _cachedRole = null;
      _cachedUid = null;
    }
    _setTrackingState(GpsTrackingIssue.stopped);

    if (resolvedHouseId == null ||
        resolvedRole == null ||
        resolvedUid == null ||
        resolvedUid != _uidProvider()) {
      return;
    }

    final now = _now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'gps/$resolvedHouseId/$resolvedRole/isLive': false,
      'gps/$resolvedHouseId/$resolvedRole/sharingEnabled': false,
      if (lastPayload != null)
        'gps/$resolvedHouseId/$resolvedRole/everShared': true,
      'gps/$resolvedHouseId/$resolvedRole/lastSeenAt': now,
    };

    if (lastPayload != null) {
      updates['gps/$resolvedHouseId/$resolvedRole/lastKnown'] = lastPayload;
    }

    try {
      await _dbRef.update(updates).timeout(const Duration(seconds: 8));
    } catch (e, st) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('permission-denied') ||
          errStr.contains('permission denied')) {
        debugPrint(
          'Location stop write blocked (permission-denied). Silently failing.',
        );
      } else {
        ErrorLoggerService.instance.logError(
          e,
          st,
          reason: 'LocationService.stopTracking database update failed',
          fatal: false,
        );
      }
    }
  }

  int _lastFirebaseUpdateTs = 0;

  LocationAccuracy get _bestForegroundAccuracy =>
      kIsWeb ? LocationAccuracy.high : LocationAccuracy.best;

  LocationSettings get _foregroundLocationSettings {
    final isRealtime =
        _partnerIsViewingMap || MapScreen.isMapScreenActive.value;
    final accuracy = isRealtime
        ? LocationAccuracy.high
        : LocationAccuracy.medium;
    final interval = isRealtime
        ? const Duration(seconds: 10)
        : const Duration(seconds: 30);
    final distanceFilter = isRealtime ? 15 : 50;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  LocationSettings get _backgroundCapableLocationSettings {
    final isRealtime =
        _partnerIsViewingMap || MapScreen.isMapScreenActive.value;
    final accuracy = isRealtime
        ? LocationAccuracy.high
        : LocationAccuracy.medium;
    final interval = isRealtime
        ? const Duration(seconds: 15)
        : const Duration(seconds: 45);
    final distanceFilter = isRealtime ? 20 : 60;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: L10nService().translate(
            'location_background_title',
          ),
          notificationText: L10nService().translate('location_background_body'),
          enableWakeLock:
              false, // ⚡ Không giữ WakeLock liên tục để tiết kiệm 85% pin
        ),
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return _foregroundLocationSettings;
  }

  /// Không giữ màn hình ở trạng thái khởi động trong lúc Firebase chờ mạng.
  /// Lỗi đồng bộ được ghi lại; luồng GPS vẫn có thể nhận các điểm tiếp theo.
  void _queuePositionUpdate(
    String houseId,
    String role,
    Position position, {
    bool forceWrite = false,
    required int trackingEpoch,
  }) {
    final uid = _activeUid;
    if (uid == null) return;
    // Xử lý tuần tự để hai điểm cùng lúc không vượt throttle hoặc ghi đè ack.
    final result = _positionTail.then((_) async {
      if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
      await _handlePositionUpdate(
        houseId,
        role,
        position,
        forceWrite: forceWrite,
        trackingEpoch: trackingEpoch,
        uid: uid,
      );
    });
    _positionTail = result.catchError((Object error, StackTrace stack) {
      if (_matchesTracking(houseId, role, uid, trackingEpoch)) {
        _setTrackingState(GpsTrackingIssue.unavailable);
        unawaited(
          ErrorLoggerService.instance.logError(
            error,
            stack,
            reason: 'LocationService position sync failed',
            fatal: false,
          ),
        );
      }
    });
  }

  bool _matchesTracking(String houseId, String role, String uid, int epoch) =>
      epoch == _trackingEpoch &&
      _activeTrackingEpoch == epoch &&
      _activeHouseId == houseId &&
      _activeRole == role &&
      _activeUid == uid &&
      _uidProvider() == uid &&
      _positionStream != null &&
      (_appInForeground || _activeBackgroundEnabled);

  Future<void> _handlePositionUpdate(
    String houseId,
    String role,
    Position position, {
    bool forceWrite = false,
    required int trackingEpoch,
    required String uid,
  }) async {
    if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
    final now = _now().millisecondsSinceEpoch;
    if (!_shouldAcceptPosition(position, now)) {
      return;
    }

    final shouldWrite =
        (forceWrite && _lastFirebaseUpdateTs == 0) ||
        _shouldWritePosition(position, _lastWrittenPosition, now);
    _lastAcceptedPosition = position;
    _lastAcceptedTs = now;
    if (!shouldWrite) return;

    await _writeAcceptedLocationToFirebase(
      houseId,
      role,
      position,
      now,
      trackingEpoch: trackingEpoch,
      uid: uid,
    );
  }

  bool _shouldAcceptPosition(Position position, int now) {
    if (!_isValidCoordinate(position.latitude, position.longitude)) {
      return false;
    }
    if (!position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > _kMaxAcceptedAccuracyMeters) {
      return false;
    }

    final sourceTs = _positionSourceTs(position);
    if (sourceTs != null &&
        (sourceTs <= 0 ||
            sourceTs > now ||
            now - sourceTs > _kLiveSourceMaxAge.inMilliseconds)) {
      return false;
    }

    final previous = _lastAcceptedPosition;
    if (previous == null || _lastAcceptedTs <= 0) return true;
    if (sourceTs != null &&
        sourceTs < previous.timestamp.millisecondsSinceEpoch) {
      return false;
    }

    final elapsedSeconds = (now - _lastAcceptedTs) / 1000.0;
    if (elapsedSeconds <= 0) return true;

    final movedMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    final speedMps = movedMeters / elapsedSeconds;
    final significantlyBetter =
        previous.accuracy.isFinite &&
        position.accuracy.isFinite &&
        previous.accuracy - position.accuracy >= _kAccuracyImprovementMeters;

    if (speedMps > _kMaxPlausibleSpeedMps && !significantlyBetter) {
      return false;
    }

    if (movedMeters < _kStationaryDistanceMeters &&
        previous.accuracy.isFinite &&
        position.accuracy.isFinite &&
        position.accuracy > previous.accuracy + _kAccuracyImprovementMeters) {
      return false;
    }

    return true;
  }

  bool _shouldWritePosition(Position position, Position? previous, int now) {
    if (_lastFirebaseUpdateTs <= 0 || previous == null) return true;

    final isRealtime =
        _partnerIsViewingMap || MapScreen.isMapScreenActive.value;
    final minIntervalMs = isRealtime
        ? const Duration(seconds: 120).inMilliseconds
        : const Duration(minutes: 30).inMilliseconds;
    final minDistance = isRealtime ? 30.0 : 300.0;

    final elapsedMs = now - _lastFirebaseUpdateTs;
    final movedMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    final accuracyImproved =
        previous.accuracy.isFinite &&
        position.accuracy.isFinite &&
        previous.accuracy - position.accuracy >= _kAccuracyImprovementMeters;

    if (elapsedMs >= minIntervalMs &&
        (movedMeters >= minDistance || accuracyImproved)) {
      return true;
    }
    if (isRealtime &&
        elapsedMs >= const Duration(seconds: 12).inMilliseconds &&
        movedMeters >= _kForceWriteDistanceMeters) {
      return true;
    }
    return false;
  }

  bool _isFreshEnoughLastKnown(Position position) {
    final sourceTs = _positionSourceTs(position);
    if (sourceTs == null) return false;
    final ageMs = _now().millisecondsSinceEpoch - sourceTs;
    return ageMs >= 0 &&
        ageMs <= _kLastKnownMaxAge.inMilliseconds &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= _kMaxAcceptedAccuracyMeters;
  }

  Future<Map<String, dynamic>> _fetchBatteryInfo() async {
    if (kIsWeb) return const {};
    try {
      final raw = await _deviceInfoChannel
          .invokeMapMethod<String, dynamic>('getBatteryInfo')
          .timeout(const Duration(seconds: 3));
      if (raw == null) return const {};
      final level = raw['level'];
      final isCharging = raw['isCharging'];
      if (level is int && level >= 0) {
        return {
          'battery': level,
          if (isCharging is bool) 'isCharging': isCharging,
        };
      }
    } catch (_) {
      // bỏ qua nếu platform không hỗ trợ
    }
    return const {};
  }

  Future<void> _writeAcceptedLocationToFirebase(
    String houseId,
    String role,
    Position position,
    int now, {
    required int trackingEpoch,
    required String uid,
  }) async {
    final batteryInfo = await _fetchBatteryInfo();
    if (!_matchesTracking(houseId, role, uid, trackingEpoch) ||
        _now().millisecondsSinceEpoch -
                position.timestamp.millisecondsSinceEpoch >
            _kLiveSourceMaxAge.inMilliseconds) {
      return;
    }

    final payload = {
      'lt': position.latitude,
      'lg': position.longitude,
      'lat': position.latitude,
      'lng': position.longitude,
      'ts': now,
      'acc': position.accuracy,
      'quality': _locationQuality(position.accuracy),
      'isLowAccuracy':
          position.accuracy.isFinite &&
          position.accuracy > _kFairAccuracyMeters,
      if (_positionSourceTs(position) != null)
        'sourceTs': _positionSourceTs(position),
      if (position.speed.isFinite && position.speed >= 0)
        'speed': position.speed,
      if (position.heading.isFinite && position.heading >= 0)
        'heading': position.heading,
      ...batteryInfo,
    };
    final date = _now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final historyKey =
        _dbRef.child('gps_history/$houseId/$role/$dateStr').push().key ??
        now.toString();

    if (!_appInForeground) {
      await _ensureDatabaseOnline();
    }
    if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;

    await _dbRef
        .update({
          'gps/$houseId/$role': {
            ...payload,
            'isLive': true,
            'sharingEnabled': true,
            'everShared': true,
            'lastSeenAt': now,
            'lastKnown': payload,
          },
          'gps_history/$houseId/$role/$dateStr/$historyKey': {
            'lat': position.latitude,
            'lng': position.longitude,
            'ts': now,
          },
        })
        .timeout(const Duration(seconds: 8));
    if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
    // Chỉ nhớ điểm/thời gian sau ack. Lỗi mạng hoặc rules không làm chặn retry
    // 30 phút và không biến tọa độ đang chờ gửi thành vị trí đã đồng bộ.
    _lastFirebaseUpdateTs = now;
    _lastWrittenPosition = position;
    _lastSyncedSourceTs = position.timestamp.millisecondsSinceEpoch;
    _lastGpsPayload = Map<String, dynamic>.from(payload);
    _setTrackingState(
      _activeMode == kGpsModeAlways && !_activeBackgroundEnabled
          ? GpsTrackingIssue.backgroundPermissionRequired
          : GpsTrackingIssue.none,
    );

    unawaited(
      _maybeTrimGpsHistory(
        houseId: houseId,
        role: role,
        dateKey: dateStr,
        trackingEpoch: trackingEpoch,
        uid: uid,
      ),
    );
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  int? _positionSourceTs(Position position) {
    final timestamp = position.timestamp;
    return timestamp.millisecondsSinceEpoch;
  }

  String _locationQuality(double accuracy) {
    if (!accuracy.isFinite) return 'unknown';
    if (accuracy <= _kGoodAccuracyMeters) return 'good';
    if (accuracy <= _kFairAccuracyMeters) return 'fair';
    return 'poor';
  }

  Stream<DatabaseEvent> streamPartnerLocation(
    String houseId,
    String partnerRole,
  ) {
    return _dbRef.child('gps/$houseId/$partnerRole').onValue;
  }

  Future<Map<String, dynamic>?> fetchBothLocations(String houseId) async {
    try {
      final snap = await _dbRef
          .child('gps/$houseId')
          .get()
          .timeout(const Duration(seconds: 10));
      if (!snap.exists || snap.value == null) return null;
      return Map<String, dynamic>.from(snap.value as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeTrimGpsHistory({
    required String houseId,
    required String role,
    required String dateKey,
    required int trackingEpoch,
    required String uid,
  }) async {
    if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
    final scopeKey = '$uid|$houseId|$role';
    final nowMs = _now().millisecondsSinceEpoch;
    final lastCleanup = _historyCleanupTsByScope[scopeKey] ?? 0;
    if (nowMs - lastCleanup < _kGpsHistoryCleanupInterval.inMilliseconds) {
      return;
    }
    _historyCleanupTsByScope[scopeKey] = nowMs;

    try {
      await _trimExpiredGpsHistoryDays(
        houseId: houseId,
        role: role,
        trackingEpoch: trackingEpoch,
        uid: uid,
      );
      if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
      await _trimOverflowGpsHistoryPoints(
        houseId: houseId,
        role: role,
        dateKey: dateKey,
        trackingEpoch: trackingEpoch,
        uid: uid,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'LocationService._maybeTrimGpsHistory error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể dọn lịch sử GPS lúc này.').message}',
        );
      }
    }
  }

  Future<void> _trimExpiredGpsHistoryDays({
    required String houseId,
    required String role,
    required int trackingEpoch,
    required String uid,
  }) async {
    final historyRoot = _dbRef.child('gps_history/$houseId/$role');
    final oldestKeptDay = _now().subtract(
      const Duration(days: _kGpsHistoryRetentionDays - 1),
    );
    final deleteThroughKey = _formatDateKey(
      oldestKeptDay.subtract(const Duration(days: 1)),
    );
    final snap = await historyRoot
        .orderByKey()
        .endAt(deleteThroughKey)
        .get()
        .timeout(const Duration(seconds: 10));
    final raw = _toStringDynamicMap(snap.value);
    if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
    if (raw.isEmpty) {
      return;
    }

    final updates = <String, dynamic>{
      for (final key in raw.keys) 'gps_history/$houseId/$role/$key': null,
    };
    await _dbRef.update(updates);
  }

  Future<void> _trimOverflowGpsHistoryPoints({
    required String houseId,
    required String role,
    required String dateKey,
    required int trackingEpoch,
    required String uid,
  }) async {
    final dayPath = 'gps_history/$houseId/$role/$dateKey';
    final snap = await _dbRef
        .child(dayPath)
        .get()
        .timeout(const Duration(seconds: 10));
    final raw = _toStringDynamicMap(snap.value);
    if (!_matchesTracking(houseId, role, uid, trackingEpoch)) return;
    if (raw.length <= _kGpsHistoryMaxPointsPerDay) {
      return;
    }

    final rankedEntries =
        raw.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                _readTimestamp(_toStringDynamicMap(entry.value)['ts']),
              ),
            )
            .where((entry) => entry.value != null)
            .cast<MapEntry<String, int>>()
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    if (rankedEntries.length <= _kGpsHistoryMaxPointsPerDay) {
      return;
    }

    final overflowCount = rankedEntries.length - _kGpsHistoryMaxPointsPerDay;
    final updates = <String, dynamic>{
      for (final entry in rankedEntries.take(overflowCount))
        '$dayPath/${entry.key}': null,
    };
    await _dbRef.update(updates);
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  int? _readTimestamp(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      if (raw.isNaN || raw.isInfinite) {
        return null;
      }
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  String _formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }
}
