// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
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

class LocationService {
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

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  static const MethodChannel _deviceInfoChannel = MethodChannel(
    'soul_locket/device_info',
  );
  static StreamSubscription<Position>? _positionStream;
  static String? _activeHouseId;
  static String? _activeRole;
  static Position? _lastAcceptedPosition;
  static int _lastAcceptedTs = 0;
  static Map<String, dynamic>? _lastGpsPayload;
  static final Map<String, int> _historyCleanupTsByScope = <String, int>{};
  static StreamSubscription? _partnerMapVisibilitySub;
  static bool _partnerIsViewingMap = false;

  Future<bool> requestPermission({
    BuildContext? context,
    bool forcePrompt = false,
  }) async {
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();

      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 6),
        onTimeout: () => LocationPermission.denied,
      );

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context == null || !context.mounted) {
          return false;
        }
        final granted = await PermissionHelper.requestLocationWithDisclosure(
          context,
          title: context.tr('map_refresh_permission_title'),
          disclosure: context.tr('map_refresh_disclosure'),
        );
        await prefs.setBool('il_gps_prompted', true);
        if (!granted) {
          return false;
        }
      }

      final refreshedPermission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 6),
        onTimeout: () => LocationPermission.denied,
      );
      if (refreshedPermission == LocationPermission.denied ||
          refreshedPermission == LocationPermission.deniedForever) {
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
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'LocationService.requestPermission error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể xin quyền vị trí lúc này.').message}',
        );
      }
      return false;
    }
  }

  Future<bool> requestBackgroundPermission({BuildContext? context}) async {
    if (kIsWeb) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await app_permission.Permission.locationAlways.request();
      return status == app_permission.PermissionStatus.granted;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (await hasBackgroundPermission()) return true;

    await app_permission.openAppSettings();
    return hasBackgroundPermission();
  }

  Future<bool> hasBackgroundPermission() async {
    final status = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 6),
      onTimeout: () => LocationPermission.denied,
    );
    return status == LocationPermission.always;
  }

  Future<bool> startTracking(
    String houseId,
    String role, {
    BuildContext? context,
    bool forcePrompt = false,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = role.trim();
    if (normalizedHouseId.isEmpty || normalizedRole.isEmpty) {
      return false;
    }

    final hasPermission = await requestPermission(
      context: context,
      forcePrompt: forcePrompt,
    );
    if (!hasPermission) return false;

    final sameTarget =
        _activeHouseId == normalizedHouseId &&
        _activeRole == normalizedRole &&
        _positionStream != null;
    if (sameTarget) {
      return true;
    }

    await stopTracking();
    if (context != null && !context.mounted) return false;

    _activeHouseId = normalizedHouseId;
    _activeRole = normalizedRole;
    _lastGpsPayload = null;
    _lastAcceptedPosition = null;
    _lastAcceptedTs = 0;
    _lastFirebaseUpdateTs = 0;

    final oppositeRole = normalizedRole == 'user1' ? 'user2' : 'user1';
    _partnerMapVisibilitySub?.cancel();
    _partnerMapVisibilitySub = _dbRef
        .child('houses/$normalizedHouseId/presence/$oppositeRole/isViewingMap')
        .onValue
        .listen((event) {
          _partnerIsViewingMap = event.snapshot.value == true;
        });

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _bestForegroundAccuracy,
          timeLimit: _kInitialPositionTimeout,
        ),
      ).timeout(_kInitialPositionTimeout);
      _queuePositionUpdate(
        normalizedHouseId,
        normalizedRole,
        initialPosition,
        forceWrite: true,
      );
    } catch (e) {
      if (kDebugMode) {
        final errorMsg = AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể lấy vị trí hiện tại lúc này.',
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
            normalizedHouseId,
            normalizedRole,
            lastKnown,
            forceWrite: true,
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

    final useBackgroundSettings = await hasBackgroundPermission();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: useBackgroundSettings
              ? _backgroundCapableLocationSettings
              : _foregroundLocationSettings,
        ).listen(
          (Position position) =>
              _queuePositionUpdate(normalizedHouseId, normalizedRole, position),
          onError: (e, st) {
            if (kDebugMode) {
              debugPrint(
                'LocationService.positionStream error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Luồng vị trí gặp lỗi.').message}',
              );
            }
          },
        );

    return true;
  }

  Future<void> stopTracking({String? houseId, String? role}) async {
    await _positionStream?.cancel();
    _positionStream = null;
    await _partnerMapVisibilitySub?.cancel();
    _partnerMapVisibilitySub = null;
    _partnerIsViewingMap = false;

    final resolvedHouseId = houseId ?? _activeHouseId;
    final resolvedRole = role ?? _activeRole;
    final lastPayload = _lastGpsPayload == null
        ? null
        : Map<String, dynamic>.from(_lastGpsPayload!);

    _activeHouseId = null;
    _activeRole = null;
    _lastGpsPayload = null;

    if (resolvedHouseId == null || resolvedRole == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'gps/$resolvedHouseId/$resolvedRole/isLive': false,
      'gps/$resolvedHouseId/$resolvedRole/sharingEnabled': false,
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

  static int _lastFirebaseUpdateTs = 0;

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
        showBackgroundLocationIndicator: true,
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
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SoulLocket đang chia sẻ vị trí nền',
          notificationText:
              'Vị trí của bạn đang được cập nhật cho bản đồ chung.',
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
  }) {
    unawaited(
      _handlePositionUpdate(
        houseId,
        role,
        position,
        forceWrite: forceWrite,
      ).catchError((Object error, StackTrace stack) {
        ErrorLoggerService.instance.logError(
          error,
          stack,
          reason: 'LocationService position sync failed',
          fatal: false,
        );
      }),
    );
  }

  Future<void> _handlePositionUpdate(
    String houseId,
    String role,
    Position position, {
    bool forceWrite = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_shouldAcceptPosition(position, now)) {
      return;
    }

    final previous = _lastAcceptedPosition;
    final shouldWrite =
        forceWrite || _shouldWritePosition(position, previous, now);
    _lastAcceptedPosition = position;
    _lastAcceptedTs = now;
    if (!shouldWrite) return;

    await _writeAcceptedLocationToFirebase(houseId, role, position, now);
  }

  bool _shouldAcceptPosition(Position position, int now) {
    if (!_isValidCoordinate(position.latitude, position.longitude)) {
      return false;
    }
    if (position.accuracy.isFinite &&
        position.accuracy > _kMaxAcceptedAccuracyMeters) {
      return false;
    }

    final sourceTs = _positionSourceTs(position);
    if (sourceTs != null &&
        now - sourceTs > _kLiveSourceMaxAge.inMilliseconds) {
      return false;
    }

    final previous = _lastAcceptedPosition;
    if (previous == null || _lastAcceptedTs <= 0) return true;

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
    final ageMs = DateTime.now().millisecondsSinceEpoch - sourceTs;
    return ageMs >= 0 &&
        ageMs <= _kLastKnownMaxAge.inMilliseconds &&
        (!position.accuracy.isFinite ||
            position.accuracy <= _kMaxAcceptedAccuracyMeters);
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
    int now,
  ) async {
    _lastFirebaseUpdateTs = now;

    final batteryInfo = await _fetchBatteryInfo();

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
    _lastGpsPayload = Map<String, dynamic>.from(payload);

    final date = DateTime.now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final historyKey =
        _dbRef.child('gps_history/$houseId/$role/$dateStr').push().key ??
        now.toString();

    final isBackground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    if (isBackground) {
      await FirebaseDatabase.instance.goOnline();
    }

    try {
      await _dbRef.update({
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
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'Location write blocked (permission-denied). Silently failing.',
        );
      } else {
        rethrow;
      }
    }

    if (isBackground) {
      Future.delayed(const Duration(seconds: 4), () {
        FirebaseDatabase.instance.goOffline();
      });
    }

    unawaited(
      _maybeTrimGpsHistory(houseId: houseId, role: role, dateKey: dateStr),
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
  }) async {
    final scopeKey = '$houseId|$role';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastCleanup = _historyCleanupTsByScope[scopeKey] ?? 0;
    if (nowMs - lastCleanup < _kGpsHistoryCleanupInterval.inMilliseconds) {
      return;
    }
    _historyCleanupTsByScope[scopeKey] = nowMs;

    try {
      await _trimExpiredGpsHistoryDays(houseId: houseId, role: role);
      await _trimOverflowGpsHistoryPoints(
        houseId: houseId,
        role: role,
        dateKey: dateKey,
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
  }) async {
    final historyRoot = _dbRef.child('gps_history/$houseId/$role');
    final oldestKeptDay = DateTime.now().subtract(
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
  }) async {
    final dayPath = 'gps_history/$houseId/$role/$dateKey';
    final snap = await _dbRef
        .child(dayPath)
        .get()
        .timeout(const Duration(seconds: 10));
    final raw = _toStringDynamicMap(snap.value);
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
