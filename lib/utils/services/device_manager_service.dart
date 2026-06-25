// ignore_for_file: unused_field, unused_element
import 'dart:async';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'consent_service.dart';
import 'security_service.dart';
import 'core/cloud_functions_helper.dart';
import 'offline_cache_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'secure_storage_service.dart';

class DeviceTrustState {
  static const Duration autoTrustDelay = Duration(hours: 12);

  final String houseId;
  final String deviceId;
  final String status;
  final int firstSeenAtMs;
  final int autoApproveAtMs;
  final bool exists;
  final bool isAdmin;

  const DeviceTrustState({
    required this.houseId,
    required this.deviceId,
    required this.status,
    required this.firstSeenAtMs,
    required this.autoApproveAtMs,
    required this.exists,
    required this.isAdmin,
  });

  bool get isTrusted => status == 'approved' || status == 'pending' || status == 'unknown' || status == 'blocked';
  bool get isPendingApproval => false;
  bool get isBlocked => false;

  Duration? get remainingAutoApproval {
    if (!isPendingApproval || autoApproveAtMs <= 0) return null;
    final diff = autoApproveAtMs - DateTime.now().millisecondsSinceEpoch;
    if (diff <= 0) return Duration.zero;
    return Duration(milliseconds: diff);
  }

  int get remainingFullDays {
    final remaining = remainingAutoApproval;
    if (remaining == null || remaining <= Duration.zero) return 0;
    return (remaining.inHours / 24).ceil();
  }
}

/// ============================================================
///  DeviceManagerService — GRA (Logic/Bảo mật)
///  Quản lý Thiết bị Đăng nhập (Phase giải đoạn Mới)
///
///  Dựa theo logic trong bundle.js (~30415, ~30422)
///  Chức năng:
///  1. Ghi log thiết bị mỗi khi đăng nhập
///  2. Lấy danh sách thiết bị của user từ Firebase
///  3. Chặn / Duyệt / Xóa thiết bị lạ
/// ============================================================
class DeviceManagerService {
  static const Duration pendingAutoTrustDelay = DeviceTrustState.autoTrustDelay;
  static const int autoTrustedDeviceLimit = 3;
  static const Duration _houseIdCacheTtl = Duration(minutes: 10);
  static const String _prefHouseId = 'il_house_id';
  static const String _prefAuthUid = 'il_auth_uid';
  static const DeviceTrustState _unknownTrustState = DeviceTrustState(
    houseId: '',
    deviceId: 'unknown',
    status: 'unknown',
    firstSeenAtMs: 0,
    autoApproveAtMs: 0,
    exists: false,
    isAdmin: false,
  );
  static final DeviceManagerService _instance =
      DeviceManagerService._internal();
  factory DeviceManagerService() => _instance;
  DeviceManagerService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;
  final ConsentService _consentService = ConsentService();
  Map<String, String>? _cachedDeviceInfo;
  String? _cachedHouseId;
  String? _cachedHouseAuthUid;
  Future<String?>? _currentHouseIdFuture;
  String? _currentHouseIdFutureUid;
  int _cachedHouseIdAtMs = 0;

  /// Lấy houseId từ cache (TTL 10 phút), tránh đọc RTDB lặp nhiều lần
  Future<String?> _getHouseIdCached() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_cachedHouseId != null &&
        _cachedHouseAuthUid == uid &&
        nowMs - _cachedHouseIdAtMs < _houseIdCacheTtl.inMilliseconds) {
      return _cachedHouseId;
    }
    final snap = await _db.ref('users/$uid/houseId').get().timeout(const Duration(seconds: 10));
    final houseId = snap.value?.toString().trim();
    if (houseId != null && houseId.isNotEmpty) {
      _cachedHouseId = houseId;
      _cachedHouseAuthUid = uid;
      _cachedHouseIdAtMs = nowMs;
    }
    return houseId;
  }
  DeviceTrustState? _cachedTrustState;
  String? _cachedTrustStateUid;
  int _cachedTrustStateAtMs = 0;

  Future<bool> isSecurityDeviceSignalsAllowed() async {
    return _consentService.isSecurityDeviceSignalsAllowed();
  }

  Future<void> setSecurityDeviceSignalsAllowed(bool value) async {
    await _consentService.setSecurityDeviceSignalsAllowed(value);
  }

  Future<String> getCurrentDeviceIdentifier() async {
    final deviceInfo = await _getDeviceInfo();
    return deviceInfo['deviceId'] ?? 'unknown';
  }

  Future<Map<String, String>> getCurrentDeviceSnapshot() async {
    return _getDeviceInfo();
  }

  Future<DeviceTrustState> getCurrentDeviceTrustState({
    bool autoApprove = true,
  }) async {
    // DISABLED: Always return a trusted state for the current device so that
    // logging in on a new device is never blocked by the device-trust flow.
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return _unknownTrustState;
    }
    return const DeviceTrustState(
      houseId: '',
      deviceId: 'auto-trusted',
      status: 'approved',
      firstSeenAtMs: 0,
      autoApproveAtMs: 0,
      exists: true,
      isAdmin: true,
    );
    /*

    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedState = _cachedTrustState;
    if (cachedState != null &&
        _cachedTrustStateUid == uid &&
        _isCacheFresh(_cachedTrustStateAtMs, _trustStateCacheTtl) &&
        !_shouldRefreshPendingTrustState(cachedState, autoApprove, now)) {
      return cachedState;
    }

    final pendingFuture = _currentTrustStateFuture;
    if (pendingFuture != null && _currentTrustStateFutureUid == uid) {
      return pendingFuture;
    }

    final future =
        _loadCurrentDeviceTrustState(autoApprove: autoApprove, uid: uid);
    _currentTrustStateFuture = future;
    _currentTrustStateFutureUid = uid;
    try {
      final trustState = await future;
      if (trustState.status == 'unknown' &&
          cachedState != null &&
          _cachedTrustStateUid == uid) {
        return cachedState;
      }
      if (trustState.status != 'unknown') {
        _rememberTrustState(trustState, uid: uid);
      }
      return trustState;
    } catch (e) {
      debugPrint('getCurrentDeviceTrustState ignored: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra trạng thái thiết bị.',
      ).message}');
      return _cachedTrustStateUid == uid
          ? _cachedTrustState ?? _unknownTrustState
          : _unknownTrustState;
    } finally {
      if (identical(_currentTrustStateFuture, future)) {
        _currentTrustStateFuture = null;
        _currentTrustStateFutureUid = null;
      }
    }
    */
  }

  Future<DeviceTrustState> _loadCurrentDeviceTrustState({
    required bool autoApprove,
    required String uid,
  }) async {
    try {
      final houseId = await _resolveCurrentHouseId(uid);
      if (houseId.isEmpty) {
        return _unknownTrustState;
      }

      final deviceInfo = await _getDeviceInfo();
      final deviceId = deviceInfo['deviceId'] ?? 'unknown';
      final ref = _db.ref('houses/$houseId/security/devices/$deviceId');
      var snap = await ref.get().timeout(const Duration(seconds: 5));
      if (!snap.exists || snap.value is! Map) {
        await registerCurrentDevice();
        snap = await ref.get().timeout(const Duration(seconds: 5));
        if (!snap.exists || snap.value is! Map) {
          return DeviceTrustState(
            houseId: houseId,
            deviceId: deviceId,
            status: 'unknown',
            firstSeenAtMs: 0,
            autoApproveAtMs: 0,
            exists: false,
            isAdmin: false,
          );
        }
      }

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      var status = data['status']?.toString() ?? 'unknown';
      final firstSeenAtMs = (data['first_seen'] as num?)?.toInt() ?? 0;
      final storedAutoApproveAtMs =
          (data['auto_approve_at'] as num?)?.toInt() ?? 0;
      final autoApproveAtMs = storedAutoApproveAtMs > 0
          ? storedAutoApproveAtMs
          : firstSeenAtMs > 0
              ? firstSeenAtMs + pendingAutoTrustDelay.inMilliseconds
              : 0;

      var isAdmin = data['is_admin'] == true;

      if (autoApprove && status == 'pending') {
        final trustedCount = await _countTrustedDevicesForHouse(houseId);
        if (trustedCount < autoTrustedDeviceLimit) {
          await ref.update({
            'status': 'approved',
            'is_admin': true,
            'approved_at': ServerValue.timestamp,
            'approved_reason': 'auto_first_three_devices',
          }).timeout(const Duration(seconds: 5));
          status = 'approved';
          isAdmin = true;
        }
      }

      if (autoApprove &&
          status == 'pending' &&
          autoApproveAtMs > 0 &&
          DateTime.now().millisecondsSinceEpoch >= autoApproveAtMs) {
        await ref.update({
          'status': 'approved',
          'approved_at': ServerValue.timestamp,
          'approved_reason': 'auto_after_12_hours',
        }).timeout(const Duration(seconds: 5));
        status = 'approved';
      }

      return DeviceTrustState(
        houseId: houseId,
        deviceId: deviceId,
        status: status,
        firstSeenAtMs: firstSeenAtMs,
        autoApproveAtMs: autoApproveAtMs,
        exists: true,
        isAdmin: isAdmin,
      );
    } catch (e) {
      debugPrint('getCurrentDeviceTrustState ignored: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra trạng thái thiết bị.',
      ).message}');
      return _unknownTrustState;
    }
  }

  /// Ghi thông tin thiết bị hiện tại vào Firebase khi đăng nhập
  Future<void> registerCurrentDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final houseId = await _resolveCurrentHouseId(uid);
      if (houseId.isEmpty) return;

      final deviceInfo = await _getDeviceInfo();
      final deviceId = deviceInfo['deviceId'] as String;

      final ref = _db.ref('houses/$houseId/security/devices/$deviceId');
      final snap = await ref.get().timeout(const Duration(seconds: 5));

      final ipPayload = await _resolveDeviceIpPayload();

      final existingStatus = snap.child('status').value?.toString();
      final isNew = !snap.exists ||
          existingStatus == 'deleted' ||
          existingStatus == 'local_only' ||
          existingStatus == 'pending' ||
          existingStatus == null;

      final updateData = {
        'deviceId': deviceId,
        'model': deviceInfo['model'],
        'os': deviceInfo['os'],
        'platform': deviceInfo['platform'],
        'ip': ipPayload['ip'],
        'location': ipPayload['location'],
        'city': ipPayload['city'] ?? '',
        'region': ipPayload['region'] ?? '',
        'country': ipPayload['country'] ?? '',
        'timezone': ipPayload['timezone'] ?? '',
        'latitude': ipPayload['latitude'] ?? '',
        'longitude': ipPayload['longitude'] ?? '',
        'org': ipPayload['org'] ?? '',
        'ipSource': ipPayload['ipSource'] ?? '',
        'last_seen': ServerValue.timestamp,
        'first_seen': snap.exists
            ? (snap.child('first_seen').value ?? ServerValue.timestamp)
            : ServerValue.timestamp,
        'auto_approve_at': snap.exists
            ? (snap.child('auto_approve_at').value ?? DateTime.now().millisecondsSinceEpoch)
            : DateTime.now().millisecondsSinceEpoch,
        'status': isNew ? 'approved' : (snap.child('status').value ?? 'approved'),
        'uid': uid,
        'is_admin': isNew ? true : (snap.child('is_admin').value ?? true),
      };

      if (isNew) {
        updateData['approved_at'] = ServerValue.timestamp;
        updateData['approved_reason'] = 'auto_approved_register';
      } else {
        if (snap.child('approved_at').value != null) {
          updateData['approved_at'] = snap.child('approved_at').value;
        }
        if (snap.child('approved_reason').value != null) {
          updateData['approved_reason'] = snap.child('approved_reason').value;
        }
      }

      await ref.update(updateData).timeout(const Duration(seconds: 5));

      // Dọn device cũ sau khi đăng ký xong (không chặn flow)
      unawaited(_pruneStaleDevices(houseId, deviceId).catchError((_) {}));
    } catch (e) {
      debugPrint('registerCurrentDevice ignored: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể đăng ký thiết bị hiện tại.',
      ).message}');
    }
  }

  /// Dọn device không hoạt động > 30 ngày để giảm kích thước node devices
  Future<void> _pruneStaleDevices(String houseId, String currentDeviceId) async {
    try {
      final snap = await _db
          .ref('houses/$houseId/security/devices')
          .get()
          .timeout(const Duration(seconds: 10));
      if (!snap.exists || snap.value is! Map) return;

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final cutoffMs = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;

      final toDelete = <String>[];
      for (final entry in data.entries) {
        final id = entry.key.toString();
        if (id == currentDeviceId) continue; // giữ nguyên device hiện tại
        final device = entry.value;
        if (device is! Map) continue;
        final lastSeen = (device['last_seen'] as num?)?.toInt() ?? 0;
        if (lastSeen > 0 && lastSeen < cutoffMs) {
          toDelete.add(id);
        }
      }

      for (final id in toDelete) {
        await _db
            .ref('houses/$houseId/security/devices/$id')
            .remove()
            .timeout(const Duration(seconds: 5));
        debugPrint('[DeviceManager] Pruned stale device: $id');
      }
    } catch (e) {
      debugPrint('_pruneStaleDevices ignored: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể dọn thiết bị cũ.',
      ).message}');
    }
  }

  Future<bool> _registerCurrentDeviceWithFunction() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final ipPayload = await _resolveDeviceIpPayload();
      await CloudFunctionsHelper.callSecure<dynamic>(
        'registerCurrentDeviceSecure',
        payload: {
          'deviceId': deviceInfo['deviceId'],
          'model': deviceInfo['model'],
          'os': deviceInfo['os'],
          'platform': deviceInfo['platform'],
          ...ipPayload,
        },
        timeout: const Duration(seconds: 15),
        throwOriginalException: true,
      );
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'registerCurrentDeviceSecure fallback to legacy DB write: ${e.code}');
      return false;
    } catch (e) {
      debugPrint(
          'registerCurrentDeviceSecure fallback to legacy DB write: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể đăng ký thiết bị qua máy chủ bảo mật.',
      ).message}');
      return false;
    }
  }

  Future<Map<String, dynamic>> _resolveDeviceIpPayload() async {
    String ip = 'unknown';
    String location = 'unknown';
    String ipSource = 'unknown';
    Map<String, dynamic> ipData = {};

    Future<Map<String, dynamic>?> fetchIpData(
        String url, String sourceName) async {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          data['source'] = sourceName;
          return data;
        }
      } catch (e) {
        debugPrint('fetchIpData error: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể lấy dữ liệu mạng thiết bị.',
        ).message}');
      }
      return null;
    }

    final sources = [
      {'url': 'https://get.geojs.io/v1/ip/geo.json', 'name': 'geojs'},
      {'url': 'https://ipapi.co/json/', 'name': 'ipapi'},
      {'url': 'https://ip-api.com/json/', 'name': 'ip-api'},
    ];

    for (var s in sources) {
      final data = await fetchIpData(s['url']!, s['name']!);
      if (data != null && (data['ip'] != null || data['query'] != null)) {
        ipData = data;
        ip = (data['ip'] ?? data['query']).toString();
        ipSource = s['name']!;
        break;
      }
    }

    if (ip == 'unknown') {
      final data =
          await fetchIpData('https://api.ipify.org?format=json', 'ipify');
      if (data != null && data['ip'] != null) {
        ipData = data;
        ip = data['ip'].toString();
        ipSource = 'ipify';
      }
    }

    if (ip != 'unknown' && ipData.isNotEmpty) {
      final city = ipData['city']?.toString() ?? '';
      final region =
          (ipData['region'] ?? ipData['regionName'])?.toString() ?? '';
      final country =
          (ipData['country'] ?? ipData['country_name'])?.toString() ?? '';
      final locParts =
          [city, region, country].where((e) => e.isNotEmpty).toList();
      if (locParts.isNotEmpty) {
        location = locParts.join(', ');
      }
    }

    return {
      'ip': ip,
      'location': location,
      'city': ipData['city']?.toString() ?? '',
      'region': (ipData['region'] ?? ipData['regionName'])?.toString() ?? '',
      'country':
          (ipData['country'] ?? ipData['country_name'])?.toString() ?? '',
      'timezone': ipData['timezone']?.toString() ?? '',
      'latitude': (ipData['latitude'] ?? ipData['lat'])?.toString() ?? '',
      'longitude': (ipData['longitude'] ?? ipData['lon'])?.toString() ?? '',
      'org': (ipData['organization_name'] ?? ipData['org'] ?? ipData['isp'])
              ?.toString() ??
          '',
      'ipSource': ipSource,
    };
  }

  StreamSubscription? _deviceStatusSub;

  /// Lắng nghe trạng thái thiết bị realtime để tự động đăng xuất nếu bị chặn/xóa
  Future<void> startRealtimeTracking() async {
    // [DISABLED_NEW_DEVICE_AUTH_BLOCK] The realtime device-status listener
    // is disabled so a new device is never force-signed-out after login.
    _deviceStatusSub?.cancel();
    _deviceStatusSub = null;
    return;
    /* Original block/delete listener kept below for reference.
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final houseSnap = await _db.ref('users/$uid/houseId').get();
    final houseId = houseSnap.value?.toString().trim();
    if (houseId == null || houseId.isEmpty) return;

    final deviceInfo = await _getDeviceInfo();
    final deviceId = deviceInfo['deviceId'] as String;

    _deviceStatusSub?.cancel();

    bool hasSeenExists = false;
    _deviceStatusSub = _db
        .ref('houses/$houseId/security/devices/$deviceId')
        .onValue
        .listen((event) async {
      final snap = event.snapshot;
      if (snap.exists) {
        hasSeenExists = true;
        final data = snap.value as Map?;
        if (data != null) {
          if (data['status'] == 'blocked') {
            stopRealtimeTracking();
            final prefs = OfflineCacheService.getPrefsSync() ??
                await SharedPreferences.getInstance();
            await prefs.setString('il_kick_reason',
                'Thiết bị của bạn đã bị chủ nhà chặn truy cập vĩnh viễn.');
            await _forceSignOutWithLocalSessionClear();
          } else if (data['status'] == 'deleted') {
            stopRealtimeTracking();
            final prefs = OfflineCacheService.getPrefsSync() ??
                await SharedPreferences.getInstance();
            await prefs.setString('il_kick_reason',
                'Thiết bị của bạn đã bị xóa khỏi nhà. Bạn sẽ không thể đăng nhập lại trong 1 giờ tới.');
            await _forceSignOutWithLocalSessionClear();
          }
        }
      } else {
        // Nếu thiết bị từng tồn tại nhưng sau đó bị xóa khỏi DB
        if (hasSeenExists) {
          stopRealtimeTracking();
          final prefs = OfflineCacheService.getPrefsSync() ??
              await SharedPreferences.getInstance();
          await prefs.setString('il_kick_reason',
              'Thiết bị của bạn đã bị xóa khỏi nhà. Bạn sẽ không thể đăng nhập lại trong 1 giờ tới.');
          await _forceSignOutWithLocalSessionClear();
        }
      }
    });
    */
  }

  void stopRealtimeTracking() {
    _deviceStatusSub?.cancel();
    _deviceStatusSub = null;
  }

  Future<void> _forceSignOutWithLocalSessionClear() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await SecureStorageService.instance.delete(SecureStorageService.keyHouseId);
    await SecureStorageService.instance.delete(SecureStorageService.keyAuthUid);
    await SecureStorageService.instance.delete(SecureStorageService.keyRole);
    await SecureStorageService.instance.delete(SecureStorageService.keyRelMode);
    await prefs.remove(_prefHouseId);
    await prefs.remove(_prefAuthUid);
    await prefs.remove('il_role');
    await prefs.remove('il_rel_mode');
    _rememberHouseId('');
    _cachedTrustState = null;
    _cachedTrustStateUid = null;
    _cachedTrustStateAtMs = 0;
    await _auth.signOut();
  }

  /// Kiểm tra thiết bị hiện tại có phải là thiết bị quen (tin cậy) không
  Future<bool> isCurrentDeviceTrusted() async {
    // DISABLED: Always return true so new devices are not blocked.
    return true;
    // -------------------------------------------------------
    // ORIGINAL CODE (commented out — kept for reference):
    //
    // try {
    //   final trustState = await getCurrentDeviceTrustState(autoApprove: true);
    //   return trustState.isTrusted;
    //   /*
    //   // ignore: dead_code
    //   final data = const <String, Object?>{};
    //   final houseId = '';
    //   final deviceId = '';
    //   if (false) {
    //     final firstSeen = (data['first_seen'] as num?)?.toInt() ?? 0;
    //     if (firstSeen > 0) {
    //       final days = (DateTime.now().millisecondsSinceEpoch - firstSeen) /
    //           (1000 * 60 * 60 * 24);
    //       if (days >= 7) {
    //         // Tự động duyệt nếu đã trên 7 ngày
    //         await _db
    //             .ref('houses/$houseId/security/devices/$deviceId/status')
    //             .set('approved')
    //             .timeout(const Duration(seconds: 5));
    //         return true;
    //       }
    //     }
    //   }
    //   return false;
    //   */
    // } catch (e) {
    //   debugPrint('isCurrentDeviceTrusted ignored: ${AppErrorMapper.resolve(
    //     e,
    //     fallbackMessage: 'Không thể kiểm tra thiết bị tin cậy.',
    //   ).message}');
    //   return false;
    // }
    // -------------------------------------------------------
  }

  /// Kiểm tra thiết bị hiện tại có bị chặn không
  Future<bool> isCurrentDeviceBlocked() async {
    // DISABLED: Always return false so new devices are never blocked.
    return false;
    /*
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final houseSnap = await _db.ref('users/$uid/houseId').get();
    final houseId = houseSnap.value?.toString().trim();
    if (houseId == null || houseId.isEmpty) return false;

    final deviceInfo = await _getDeviceInfo();
    final deviceId = deviceInfo['deviceId'] as String;

    try {
      final snap = await _db
          .ref('houses/$houseId/security/devices/$deviceId/status')
          .get();
      if (!snap.exists) return false;
      return snap.value == 'blocked';
    } catch (e) {
      debugPrint('isCurrentDeviceBlocked ignored: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra trạng thái chặn thiết bị.',
      ).message}');
      return false;
    }
    */
  }

  /// Load danh sách tất cả thiết bị của user
  Future<List<Map<String, dynamic>>> loadDevices() async {
    final functionDevices = await _loadDevicesFromFunction();

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return functionDevices ?? [];
    }

    final houseSnap = await _db
        .ref('users/$uid/houseId')
        .get()
        .timeout(const Duration(seconds: 10));
    final houseId = houseSnap.value?.toString().trim();
    if (houseId == null || houseId.isEmpty) {
      return functionDevices ?? [];
    }

    final snap = await _db
        .ref('houses/$houseId/security/devices')
        .get()
        .timeout(const Duration(seconds: 10));
    if (!snap.exists) {
      return functionDevices ?? [];
    }

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final legacyDevices = data.entries
        .map((e) {
          final device = Map<String, dynamic>.from(e.value as Map);
          device['deviceId'] = e.key;

          if (device['status'] == 'pending') {
            final firstSeen = (device['first_seen'] as num?)?.toInt() ?? 0;
            if (firstSeen > 0) {
              final ageMs = DateTime.now().millisecondsSinceEpoch - firstSeen;
              if (ageMs >= pendingAutoTrustDelay.inMilliseconds) {
                device['status'] = 'approved';
                unawaited(
                  _db.ref('houses/$houseId/security/devices/${e.key}').update({
                    'status': 'approved',
                    'approved_at': ServerValue.timestamp,
                    'approved_reason': 'auto_after_12_hours',
                  }).catchError((_) {}),
                );
              }
            }
          }

          return device;
        })
        .where((d) => d['status'] != 'deleted')
        .toList();

    final merged = <String, Map<String, dynamic>>{};
    for (final device in legacyDevices) {
      final id = device['deviceId']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      merged[id] = device;
    }
    for (final device in functionDevices ?? const <Map<String, dynamic>>[]) {
      final id = device['deviceId']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      merged[id] = device;
    }

    final devices = merged.values.toList(growable: false)
      ..sort((a, b) {
        final aTs = (a['last_seen'] as num?)?.toInt() ?? 0;
        final bTs = (b['last_seen'] as num?)?.toInt() ?? 0;
        return bTs.compareTo(aTs);
      });

    return devices.isEmpty ? (functionDevices ?? []) : devices;
  }

  Future<List<Map<String, dynamic>>?> _loadDevicesFromFunction() async {
    try {
      final currentDeviceId = await getCurrentDeviceIdentifier();
      final result = await CloudFunctionsHelper.callSecure<dynamic>(
        'getDeviceListSecure',
        payload: {'currentDeviceId': currentDeviceId},
        timeout: const Duration(seconds: 6),
        throwOriginalException: true,
      );
      final rawDevices = result.data is Map ? result.data['devices'] : null;
      if (rawDevices is! List) {
        return const [];
      }
      return rawDevices
          .whereType<Map>()
          .map((device) => Map<String, dynamic>.from(device))
          .toList(growable: false);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('getDeviceListSecure fallback to legacy DB read: ${e.code}');
      return null;
    } catch (e) {
      debugPrint(
          'getDeviceListSecure fallback to legacy DB read: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể tải danh sách thiết bị bảo mật.',
      ).message}');
      return null;
    }
  }

  /// Duyệt thiết bị đang ở trạng thái pending
  Future<void> approveDevice(String deviceId) async {
    if (await _callDeviceActionFunction('approveDeviceSecure', deviceId)) {
      return;
    }
    final houseId = await _getHouseIdCached();
    if (houseId == null || houseId.isEmpty) return;
    await _db.ref('houses/$houseId/security/devices/$deviceId').update({
      'status': 'approved',
      'approved_at': ServerValue.timestamp,
      'approved_reason': 'manual_device_approval',
    });
  }

  /// Chặn thiết bị lạ (Vĩnh viễn)
  Future<void> blockDevice(String deviceId) async {
    if (await _callDeviceActionFunction('blockDeviceSecure', deviceId)) {
      return;
    }
    final houseId = await _getHouseIdCached();
    if (houseId == null || houseId.isEmpty) return;

    final ref = _db.ref('houses/$houseId/security/devices/$deviceId');
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.value as Map;
      final ip = data['ip'] as String?;
      if (ip != null && ip.isNotEmpty && ip != 'unknown') {
        final cleanIp = ip.replaceAll('.', '_');
        // B?n IP trên toàn hệ thống
        await _db.ref('banned_ips/$cleanIp').set(true);
      }
    }

    await ref.update({
      'status': 'blocked',
      'blocked_at': ServerValue.timestamp,
    });
  }

  /// Xóa thiết bị khỏi danh sách (Không thể đăng nhập trong 1 giờ)
  Future<void> deleteDevice(String deviceId) async {
    if (await _callDeviceActionFunction('deleteDeviceSecure', deviceId)) {
      return;
    }
    final houseId = await _getHouseIdCached();
    if (houseId == null || houseId.isEmpty) return;

    await _db.ref('houses/$houseId/security/devices/$deviceId').update({
      'status': 'deleted',
      'deleted_at': ServerValue.timestamp,
    });
  }

  Future<bool> _callDeviceActionFunction(
      String functionName, String deviceId) async {
    try {
      final currentDeviceId = await getCurrentDeviceIdentifier();
      final callable = _functions.httpsCallable(functionName);
      await callable.call({
        'deviceId': deviceId,
        'currentDeviceId': currentDeviceId,
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('$functionName fallback to legacy DB write: ${e.code}');
      return false;
    } catch (e) {
      debugPrint(
          'Device action fallback to legacy DB write: ${AppErrorMapper.resolve(
        e,
        fallbackMessage:
            'Không thể xử lý thao tác thiết bị qua máy chủ bảo mật.',
      ).message}');
      return false;
    }
  }

  /// Lấy thông tin thiết bị hiện tại
  Future<String> _resolveCurrentHouseId(String uid) async {
    final memoryHouseId = _cachedHouseId?.trim() ?? '';
    if (memoryHouseId.isNotEmpty &&
        _cachedHouseAuthUid == uid &&
        _isCacheFresh(_cachedHouseIdAtMs, _houseIdCacheTtl)) {
      return memoryHouseId;
    }

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await SecureStorageService.instance.migrateFromPrefs(SecureStorageService.keyHouseId, prefs.getString(_prefHouseId));
    await SecureStorageService.instance.migrateFromPrefs(SecureStorageService.keyAuthUid, prefs.getString(_prefAuthUid));
    final cachedHouseId = (await SecureStorageService.instance.read(SecureStorageService.keyHouseId))?.trim() ?? '';
    final cachedAuthUid = (await SecureStorageService.instance.read(SecureStorageService.keyAuthUid))?.trim() ?? '';
    if (cachedHouseId.isNotEmpty) {
      if (cachedAuthUid == uid) {
        _rememberHouseId(cachedHouseId, uid: uid);
        return cachedHouseId;
      }
      await SecureStorageService.instance.delete(SecureStorageService.keyHouseId);
      await SecureStorageService.instance.delete(SecureStorageService.keyAuthUid);
      await SecureStorageService.instance.delete(SecureStorageService.keyRole);
      await prefs.remove(_prefHouseId);
      await prefs.remove(_prefAuthUid);
      await prefs.remove('il_role');
    }

    final pendingFuture = _currentHouseIdFuture;
    if (pendingFuture != null && _currentHouseIdFutureUid == uid) {
      return await pendingFuture ?? '';
    }

    final future = _loadHouseIdFromRemote(uid, prefs);
    _currentHouseIdFuture = future;
    _currentHouseIdFutureUid = uid;
    try {
      return await future ?? '';
    } finally {
      if (identical(_currentHouseIdFuture, future)) {
        _currentHouseIdFuture = null;
        _currentHouseIdFutureUid = null;
      }
    }
  }

  Future<String?> _loadHouseIdFromRemote(
    String uid,
    SharedPreferences prefs,
  ) async {
    final houseSnap = await _db
        .ref('users/$uid/houseId')
        .get()
        .timeout(const Duration(seconds: 5));
    final houseId = houseSnap.value?.toString().trim() ?? '';
    if (houseId.isEmpty) {
      return null;
    }

    _rememberHouseId(houseId, uid: uid);
    await SecureStorageService.instance.write(SecureStorageService.keyHouseId, houseId);
    await SecureStorageService.instance.write(SecureStorageService.keyAuthUid, uid);
    await prefs.remove(_prefHouseId);
    await prefs.remove(_prefAuthUid);
    return houseId;
  }

  bool _shouldRefreshPendingTrustState(
    DeviceTrustState trustState,
    bool autoApprove,
    int now,
  ) {
    return autoApprove &&
        trustState.isPendingApproval &&
        trustState.autoApproveAtMs > 0 &&
        now >= trustState.autoApproveAtMs;
  }

  void _rememberHouseId(String houseId, {String? uid}) {
    final trimmed = houseId.trim();
    if (trimmed.isEmpty) {
      _cachedHouseId = null;
      _cachedHouseAuthUid = null;
      _cachedHouseIdAtMs = 0;
      return;
    }

    _cachedHouseId = trimmed;
    final trimmedUid = uid?.trim() ?? _auth.currentUser?.uid.trim() ?? '';
    _cachedHouseAuthUid = trimmedUid.isEmpty ? null : trimmedUid;
    _cachedHouseIdAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _rememberTrustState(DeviceTrustState trustState, {String? uid}) {
    _cachedTrustState = trustState;
    final trimmedUid = uid?.trim() ?? _auth.currentUser?.uid.trim() ?? '';
    _cachedTrustStateUid = trimmedUid.isEmpty ? null : trimmedUid;
    _cachedTrustStateAtMs = DateTime.now().millisecondsSinceEpoch;
    if (trustState.houseId.trim().isNotEmpty) {
      _rememberHouseId(trustState.houseId, uid: trimmedUid);
    }
  }

  bool _isCacheFresh(int cachedAtMs, Duration ttl) {
    if (cachedAtMs <= 0) {
      return false;
    }

    final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
    return age <= ttl.inMilliseconds;
  }

  List<Map<String, dynamic>> _snapshotDeviceRecords(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value is! Map) {
      return <Map<String, dynamic>>[];
    }

    final rawDevices = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final devices = <Map<String, dynamic>>[];
    for (final rawDevice in rawDevices.values) {
      if (rawDevice is! Map) {
        continue;
      }

      devices.add(
        Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(rawDevice).map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        ),
      );
    }
    return devices;
  }

  int _countTrustedActiveDevices(List<Map<String, dynamic>> devices) {
    return devices.where(_isTrustedActiveDevice).length;
  }

  Future<int> _countTrustedDevicesForHouse(String houseId) async {
    // Chỉ query devices có status == 'approved', không load toàn bộ node
    final devicesSnap = await _db
        .ref('houses/$houseId/security/devices')
        .orderByChild('status')
        .equalTo('approved')
        .get()
        .timeout(const Duration(seconds: 5));
    if (!devicesSnap.exists || devicesSnap.value is! Map) return 0;
    return (devicesSnap.value as Map).length;
  }

  bool _isTrustedActiveDevice(Map<String, dynamic> device) {
    return device['status']?.toString() == 'approved';
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final cachedDeviceInfo = _cachedDeviceInfo;
    if (cachedDeviceInfo != null) {
      return Map<String, String>.from(cachedDeviceInfo);
    }

    final plugin = DeviceInfoPlugin();
    String deviceId = 'unknown';
    String model = 'Unknown';
    String os = 'Unknown';
    String platform = 'unknown';
    String stableDeviceId = '';

    try {
      stableDeviceId = (await SecurityService().getDeviceId()).trim();
    } catch (_) {}

    try {
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        deviceId = stableDeviceId.isNotEmpty
            ? stableDeviceId
            : (info.userAgent ?? 'web_browser');
        // Clean user agent string to avoid invalid characters for Firebase path
        deviceId = deviceId
            .replaceAll(RegExp(r'[.#$\[\]]'), '_')
            .replaceAll(RegExp(r'[/]'), '-');
        model = '${info.browserName.name} on ${info.platform}';
        os = info.platform ?? 'web';
        platform = 'web';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        deviceId = stableDeviceId.isNotEmpty ? stableDeviceId : info.id;
        model = '${info.brand} ${info.model}';
        os = 'Android ${info.version.release}';
        platform = 'android';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        deviceId = stableDeviceId.isNotEmpty
            ? stableDeviceId
            : (info.identifierForVendor ?? 'ios_unknown');
        model = info.model;
        os = 'iOS ${info.systemVersion}';
        platform = 'ios';
      }
    } catch (_) {}

    // Ensure no invalid characters remain
    deviceId = deviceId.replaceAll(RegExp(r'[.#$\[\]/]'), '_');

    final deviceInfo = {
      'deviceId': deviceId,
      'model': model,
      'os': os,
      'platform': platform,
    };
    _cachedDeviceInfo = deviceInfo;
    return Map<String, String>.from(deviceInfo);
  }
}
