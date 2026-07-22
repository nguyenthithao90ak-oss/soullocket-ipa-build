// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/services/session/presence_status_formatter.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/role_utils.dart';
import 'package:soullocket_app/utils/services/device_manager_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PresenceService {
  static const PresenceStatusFormatter _statusFormatter =
      PresenceStatusFormatter();

  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  static const Duration onlineFreshness = Duration(minutes: 15);
  // Heartbeat mỗi 60s để session luôn fresh trong ngưỡng 30 phút stale threshold.
  // Lightweight heartbeat chỉ ghi 1 field 'ts' → ít writes, ít băng thông.
  static const Duration heartbeatInterval = Duration(seconds: 60);
  static const Duration staleSessionThreshold = Duration(minutes: 30);
  static const Duration justDisconnectedThreshold = Duration(minutes: 1);

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  DatabaseReference? _myPresenceRef;
  String? _mySessionId;
  bool _shouldBeOnline = false;
  bool _isConnected = false;
  String? _activeHouseId;
  String? _activeRole;
  String? _activeDeviceType;
  String? _lastOnlineFingerprint;
  DateTime? _lastDuplicateRoleWarnedAt;
  DateTime? _lastMarkActiveAt;
  // ignore: cancel_subscriptions
  StreamSubscription? _connectedSub;
  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference _presenceRoleRef(String houseId, String role) {
    return _dbRef.child('houses/$houseId/presence/$role');
  }

  DatabaseReference get _backendProbeRef {
    return _dbRef.child('public_love_card_links/__presence_probe__');
  }

  Map<dynamic, dynamic> _readSessionMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return const <dynamic, dynamic>{};
  }

  static int? _readSessionTimestamp(dynamic raw) {
    if (raw is Map) {
      return _readEpochMs(raw['ts'] ?? raw['lastSeen'] ?? raw['updatedAt']);
    }
    return _readEpochMs(raw);
  }

  static String? _readSessionUid(dynamic raw) {
    if (raw is! Map) return null;
    final uid = raw['uid']?.toString().trim();
    return uid == null || uid.isEmpty ? null : uid;
  }

  Stream<Map<String, dynamic>> streamPresence(String houseId) {
    return _dbRef.child('houses/$houseId/presence').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return {};
      }
      final raw = event.snapshot.value;
      if (raw is! Map) {
        return {};
      }
      return Map<String, dynamic>.from(raw);
    });
  }

  static int? _readEpochMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  static int _countFreshSessions(
    Map<dynamic, dynamic> sessions, {
    required int nowMs,
    String? ignoreUid,
  }) {
    var count = 0;
    for (final value in sessions.values) {
      final ts = _readSessionTimestamp(value);
      if (ts != null) {
        final diff = nowMs - ts;
        // Cho phép lệch đồng hồ giữa các thiết bị (không giới hạn chênh lệch âm nếu thiết bị kia nhanh hơn)
        if (diff <= onlineFreshness.inMilliseconds) {
          count += 1;
        }
      }
    }
    return count;
  }

  static bool isPresenceOnline(
    Map<dynamic, dynamic>? data, {
    int? nowMs,
    String? ignoreUid,
  }) {
    if (data == null || data.isEmpty) {
      return false;
    }

    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final sessions = data['sessions'];
    
    if (sessions is Map && sessions.isNotEmpty) {
      final freshSessionCount = _countFreshSessions(
        sessions,
        nowMs: now,
        ignoreUid: ignoreUid,
      );
      return freshSessionCount > 0;
    }

    // Nếu không có sessions (bị onDisconnect xoá) hoặc sessions rỗng -> offline
    return false;
  }

  static int? lastSeenMs(Map<dynamic, dynamic>? data) {
    return _readEpochMs(data?['lastSeen']);
  }

  static int? latestSessionTimestamp(Map<dynamic, dynamic>? data) {
    final sessions = data?['sessions'];
    if (sessions is! Map || sessions.isEmpty) {
      return null;
    }
    var latest = 0;
    for (final value in sessions.values) {
      final ts = _readSessionTimestamp(value);
      if (ts != null && ts > latest) {
        latest = ts;
      }
    }
    return latest == 0 ? null : latest;
  }

  static int activeSessionCount(
    Map<dynamic, dynamic>? data, {
    int? nowMs,
  }) {
    if (data == null || data.isEmpty) {
      return 0;
    }
    final sessions = data['sessions'];
    if (sessions is! Map || sessions.isEmpty) {
      final activeCount = data['activeSessionCount'];
      if (activeCount is num) {
        return activeCount.toInt();
      }
      return 0;
    }
    return _countFreshSessions(
      sessions,
      nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  static bool hasEverConnected(Map<dynamic, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return false;
    }
    if (lastSeenMs(data) != null) {
      return true;
    }
    if (latestSessionTimestamp(data) != null) {
      return true;
    }
    final activeSessionCount = data['activeSessionCount'];
    if (activeSessionCount is num && activeSessionCount.toInt() > 0) {
      return true;
    }
    final status = data['status']?.toString().trim().toLowerCase();
    return status == 'online' || status == 'offline';
  }

  static bool isTemporarilyDisconnected(
    Map<dynamic, dynamic>? data, {
    int? nowMs,
  }) {
    final lastSeen = lastSeenMs(data);
    if (lastSeen == null) {
      return false;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - lastSeen;
    return diffMs >= 0 && diffMs <= justDisconnectedThreshold.inMilliseconds;
  }

  static String formatStatusLabel(
    Map<dynamic, dynamic>? data, {
    int? nowMs,
    String? ignoreUid,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (isPresenceOnline(data, nowMs: now, ignoreUid: ignoreUid)) {
      return _statusFormatter.onlineLabel();
    }

    final lastSeen = lastSeenMs(data) ?? latestSessionTimestamp(data);
    if (lastSeen == null) {
      final activeSessionCount = data?['activeSessionCount'];
      if (activeSessionCount is num && activeSessionCount.toInt() > 0) {
        return _statusFormatter.formatLastSeen(now - 60000);
      }
      return _statusFormatter.neverConnectedLabel();
    }
    return _statusFormatter.formatLastSeen(lastSeen);
  }

  static String formatLastSeen(int? lastSeenMs) {
    return _statusFormatter.formatLastSeen(lastSeenMs);
  }

  Future<void> goOnline({
    required String houseId,
    required String role,
    String? deviceType,
  }) async {
    await FirebaseDatabase.instance.goOnline();
    final previousHouseId = _activeHouseId;
    final previousRole = _activeRole;
    final targetChanged = previousHouseId != null &&
        previousRole != null &&
        (previousHouseId != houseId || previousRole != role);
    debugPrint(
      '[Presence] goOnline start role=$role house=$houseId targetChanged=$targetChanged device=${deviceType ?? 'flutter'}',
    );

    if (targetChanged) {
      await _cleanupPresence(
        houseId: previousHouseId,
        role: previousRole,
        markOfflineIfEmpty: true,
        lastSeenMs: null,
      );
      _myPresenceRef = null;
      _mySessionId = null;
    }

    _shouldBeOnline = true;
    _activeHouseId = houseId;
    _activeRole = role;
    _activeDeviceType = deviceType;
    _heartbeatCount = 0;

    final nextFingerprint = '$houseId|$role|${deviceType ?? 'flutter'}';
    final canReuseCurrentSession = !targetChanged &&
        _myPresenceRef != null &&
        _mySessionId != null &&
        _lastOnlineFingerprint == nextFingerprint;
    if (canReuseCurrentSession) {
      debugPrint(
        '[Presence] goOnline reuse session=$_mySessionId role=$role house=$houseId',
      );
      _setupConnectedListener();
      _startHeartbeat();
      await _heartbeat();
      return;
    }

    _lastOnlineFingerprint = nextFingerprint;
    _setupConnectedListener();
    await _doGoOnline();
    _startHeartbeat();
  }

  void _setupConnectedListener() {
    if (_connectedSub != null) return;
    _connectedSub = _dbRef.child('.info/connected').onValue.listen(
      (event) {
        final connected = event.snapshot.value == true;
        _isConnected = connected;
        if (connected && _shouldBeOnline) {
          unawaited(_doGoOnline());
        }
      },
      onError: (Object error) {
        debugPrint('Presence backend listener failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể lắng nghe trạng thái hiện diện.',
        ).message}');
      },
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_shouldBeOnline) {
        unawaited(_lightweightHeartbeat());
      }
    });
  }

  /// Chỉ heartbeat nhẹ — không prune + không refresh aggregate mỗi lần
  Future<void> _lightweightHeartbeat() async {
    if (!_shouldBeOnline || _myPresenceRef == null || _mySessionId == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final showStatus = prefs.getBool('il_show_status') ?? true;
    if (!showStatus) return;

    if (!_isConnected) {
      debugPrint(
          '[Presence] Skip lightweight heartbeat because connection is offline');
      return;
    }
    try {
      await _myPresenceRef!.child('sessions/$_mySessionId').update({
        'ts': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[Presence] Lightweight heartbeat failed: $e');
    }
  }

  Future<void> _heartbeat() async {
    if (!_shouldBeOnline || _myPresenceRef == null || _mySessionId == null) {
      return;
    }
    if (!_isConnected) {
      debugPrint('[Presence] Skip heartbeat because connection is offline');
      return;
    }

    // ⚡ Full heartbeat mỗi 10 lần (thay vì 5) = mỗi 50 phút thay vì 15 phút
    final shouldRunFull = _heartbeatCount == 0 || _heartbeatCount % 10 == 0;
    _heartbeatCount++;

    if (!shouldRunFull) {
      await _lightweightHeartbeat();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final deviceId =
          await DeviceManagerService().getCurrentDeviceIdentifier();
      await _myPresenceRef!.child('sessions/$_mySessionId').set({
        'ts': now,
        if (_currentUid != null) 'uid': _currentUid,
        if (_activeDeviceType != null) 'device': _activeDeviceType,
        'deviceId': deviceId,
      }).timeout(const Duration(seconds: 3));

      // Prune stale sessions cho chính role của mình để đảm bảo status chính xác
      if (_myPresenceRef != null) {
        await _pruneStaleSessions(_myPresenceRef!, nowMs: now);
      }

      await _refreshAggregatePresence(
        _myPresenceRef!,
        nowMs: now,
        preferredDevice: _activeDeviceType,
      );

      // Không refresh AggregatePresence của đối phương để tránh đè trạng thái do lệch đồng hồ

      // Phát hiện trùng vai
      await _checkDuplicateRole(nowMs: now);

      debugPrint('Presence full heartbeat refreshed session $_mySessionId');
    } on TimeoutException {
      return;
    } catch (e) {
      debugPrint('Presence heartbeat failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể cập nhật trạng thái hiện diện.',
      ).message}');
    }
  }

  /// Kiểm tra có thiết bị khác cùng vai đang online không.
  /// Nếu có và chưa cảnh báo trong 24h → set duplicateRoleNotifier = true.
  Future<void> _checkDuplicateRole({required int nowMs}) async {
    final houseId = _activeHouseId;
    final role = _activeRole;
    final sessionId = _mySessionId;
    if (houseId == null || role == null || sessionId == null) return;

    // Throttle 24h
    final lastWarned = _lastDuplicateRoleWarnedAt;
    if (lastWarned != null &&
        DateTime.now().difference(lastWarned).inHours < 24) {
      return;
    }

    try {
      final safeGet = _dbRef
          .child('houses/$houseId/presence/$role/sessions')
          .get();
      safeGet.ignore();
      final snap = await safeGet.timeout(const Duration(seconds: 3));
      final raw = snap.value;
      if (raw is! Map) return;

      final currentDeviceId =
          await DeviceManagerService().getCurrentDeviceIdentifier();
      var otherFreshCount = 0;
      raw.forEach((key, value) {
        if (key.toString() == sessionId) return; // bỏ qua session của mình
        final ts = _readSessionTimestamp(value);
        if (ts != null &&
            nowMs - ts >= 0 &&
            nowMs - ts <= onlineFreshness.inMilliseconds) {
          // Bỏ qua nếu là cùng một thiết bị (tránh false positive khi restart/hot reload)
          if (value is Map) {
            final otherDeviceId = value['deviceId']?.toString();
            if (otherDeviceId != null && otherDeviceId == currentDeviceId) {
              return;
            }
          }
          otherFreshCount++;
        }
      });

      if (otherFreshCount > 0) {
        _lastDuplicateRoleWarnedAt = DateTime.now();
        RoleUtils.duplicateRoleNotifier.value = true;
        debugPrint(
            '[Presence] Duplicate role detected: $otherFreshCount other session(s) on $role');
      }
    } catch (_) {}
  }

  Future<void> markActiveNow() async {
    if (!_shouldBeOnline) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final showStatus = prefs.getBool('il_show_status') ?? true;
    if (!showStatus) return;

    // Throttle: không gọi heartbeat quá 1 lần mỗi 180s (3 phút) để giảm writes
    if (_lastMarkActiveAt != null &&
        DateTime.now().difference(_lastMarkActiveAt!).inSeconds < 180) {
      return;
    }
    _lastMarkActiveAt = DateTime.now();
    if (_myPresenceRef == null || _mySessionId == null) {
      await _doGoOnline();
      return;
    }
    // Dùng lightweight update thay vì full _heartbeat() để tiết kiệm băng thông khi tương tác
    await _lightweightHeartbeat();
  }

  Future<void> _pruneStaleSessions(
    DatabaseReference ref, {
    required int nowMs,
  }) async {
    try {
      final safeGet = ref.child('sessions').get();
      safeGet.ignore();
      final snap = await safeGet.timeout(const Duration(seconds: 3));
      final raw = snap.value;
      if (raw is! Map) {
        return;
      }

      final updates = <String, dynamic>{};
      raw.forEach((key, value) {
        final ts = _readSessionTimestamp(value);
        if (ts == null || nowMs - ts > staleSessionThreshold.inMilliseconds) {
          updates[key.toString()] = null;
        }
      });

      if (updates.isNotEmpty) {
        await ref.child('sessions').update(updates);
        debugPrint(
            'Presence pruned stale sessions: ${updates.keys.join(', ')}');
      }
    } catch (e) {
      debugPrint('Presence stale session prune failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể dọn phiên hiện diện cũ.',
      ).message}');
    }
  }

  Future<void> _removeCurrentUidGhostSessions({
    required int nowMs,
  }) async {
    // [Vô hiệu hóa] Theo rule dự án Shared Account, 2 user dùng chung 1 UID.
    // Nếu xóa ghost sessions của vai đối diện theo UID,
    // người này online sẽ đá trạng thái online của người kia.
    return;
  }

  Future<void> _refreshAggregatePresence(
    DatabaseReference ref, {
    required int nowMs,
    int? lastSeenMs,
    String? preferredDevice,
  }) async {
    try {
      final safeGet = ref.get();
      safeGet.ignore();
      final snap = await safeGet.timeout(const Duration(seconds: 3));
      final raw = snap.value;
      final data = raw is Map
          ? Map<dynamic, dynamic>.from(raw)
          : const <dynamic, dynamic>{};
      final sessionsRaw = data['sessions'];
      final sessions = _readSessionMap(sessionsRaw);
      var freshSessionCount = _countFreshSessions(sessions, nowMs: nowMs);
      var latestSessionSeen = sessions.values
          .map(_readSessionTimestamp)
          .whereType<int>()
          .fold<int>(0, (latest, ts) => ts > latest ? ts : latest);
      if (_shouldCountCurrentSessionFor(ref) && freshSessionCount == 0) {
        freshSessionCount = 1;
        latestSessionSeen = nowMs;
      }
      final resolvedLastSeen = latestSessionSeen > 0
          ? latestSessionSeen
          : (lastSeenMs ?? _readEpochMs(data['lastSeen']) ?? nowMs);
      final resolvedDevice =
          preferredDevice ?? data['device']?.toString().trim();

      // Grace period: chỉ ghi 'offline' nếu lastSeen đã cũ hơn 3 phút
      // Tránh race condition khi 2 thiết bị heartbeat gần nhau (lệch đồng hồ, mạng chậm)
      final shouldMarkOffline = freshSessionCount == 0 &&
          (resolvedLastSeen == 0 ||
              nowMs - resolvedLastSeen > const Duration(minutes: 3).inMilliseconds);
      final safeUpdate = ref.update({
        'status': freshSessionCount > 0
            ? 'online'
            : (shouldMarkOffline ? 'offline' : 'online'),
        'lastSeen': freshSessionCount > 0
            ? resolvedLastSeen
            : (lastSeenMs ?? resolvedLastSeen),
        'activeSessionCount': freshSessionCount,
        if (resolvedDevice != null && resolvedDevice.isNotEmpty)
          'device': resolvedDevice,
      });
      safeUpdate.ignore();
      await safeUpdate.timeout(const Duration(seconds: 3));
      debugPrint(
        '[Presence] aggregate role=${ref.key} status=${freshSessionCount > 0 ? 'online' : 'offline'} sessions=$freshSessionCount lastSeen=$resolvedLastSeen device=${resolvedDevice ?? '-'}',
      );
    } catch (e) {
      debugPrint('Presence aggregate refresh failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể tổng hợp trạng thái hiện diện.',
      ).message}');
    }
  }

  bool _shouldBeOnlineActiveFor(DatabaseReference ref) {
    final currentRef = _myPresenceRef;
    return _shouldBeOnline &&
        currentRef != null &&
        _mySessionId != null &&
        currentRef.path == ref.path;
  }

  bool _shouldCountCurrentSessionFor(DatabaseReference ref) {
    final currentRef = _myPresenceRef;
    return _shouldBeOnline &&
        currentRef != null &&
        _mySessionId != null &&
        currentRef.path == ref.path;
  }

  Future<void> _doGoOnline() async {
    if (!_shouldBeOnline || _activeHouseId == null || _activeRole == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final showStatus = prefs.getBool('il_show_status') ?? true;
    if (!showStatus) return;

    final nextPath = 'houses/$_activeHouseId/presence/$_activeRole';
    _myPresenceRef = _dbRef.child(nextPath);

    final now = DateTime.now().millisecondsSinceEpoch;
    _mySessionId ??= '${now}_${_dbRef.push().key}';

    try {
      // Vì giờ 2 người dùng tài khoản riêng, ta bật lại tính năng xóa ghost session chéo
      await _removeCurrentUidGhostSessions(nowMs: now);

      // Chỉ dọn dẹp stale sessions cho bản thân, không dọn cho người kia để tránh lệch giờ làm xoá nhầm
      await _pruneStaleSessions(_myPresenceRef!, nowMs: now);

      final deviceId =
          await DeviceManagerService().getCurrentDeviceIdentifier();
      await _myPresenceRef!.child('sessions/$_mySessionId').set({
        'ts': now,
        if (_currentUid != null) 'uid': _currentUid,
        if (_activeDeviceType != null) 'device': _activeDeviceType,
        'deviceId': deviceId,
      }).timeout(const Duration(seconds: 3));
      // ⚡ onDisconnect chỉ xóa đúng session của mình — không ghi 'status: offline'
      // vào node cha để tránh đè trạng thái của thiết bị/session khác đang online cùng vai.
      // Status sẽ được tính lại từ sessions map khi heartbeat tiếp theo chạy.
      await _myPresenceRef!
          .child('sessions/$_mySessionId')
          .onDisconnect()
          .remove()
          .timeout(const Duration(seconds: 3));
      await _refreshAggregatePresence(
        _myPresenceRef!,
        nowMs: now,
        preferredDevice: _activeDeviceType,
      );

      // Không cập nhật lại aggregate presence cho vai trò đối diện để tránh ghi đè sai lệch

      _heartbeatCount = 0;
      debugPrint('Presence online for $_activeRole in $_activeHouseId');
    } on TimeoutException {
      return;
    } catch (e) {
      debugPrint('Presence write failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể ghi trạng thái hiện diện.',
      ).message}');
    }
  }

  Future<void> hidePresence() async {
    final houseId = _activeHouseId;
    final role = _activeRole;
    if (houseId == null || role == null) return;
    
    debugPrint('[Presence] hidePresence start role=$role house=$houseId');
    _heartbeatTimer?.cancel();
    await _cleanupPresence(
      houseId: houseId,
      role: role,
      markOfflineIfEmpty: true,
      lastSeenMs: DateTime.now().millisecondsSinceEpoch,
    );
    _myPresenceRef = null;
    _mySessionId = null;
    _lastOnlineFingerprint = null;
  }

  Future<void> reconnectPresence() async {
    if (!_shouldBeOnline) return;
    await _doGoOnline();
  }

  Future<void> goOffline({
    required String houseId,
    required String role,
    int? lastSeenMs,
  }) async {
    debugPrint(
      '[Presence] goOffline start role=$role house=$houseId session=${_mySessionId ?? '-'} lastSeen=${lastSeenMs ?? '-'}',
    );
    _shouldBeOnline = false;
    _heartbeatTimer?.cancel();
    await _cleanupPresence(
      houseId: houseId,
      role: role,
      markOfflineIfEmpty: true,
      lastSeenMs: lastSeenMs,
    );
    _myPresenceRef = null;
    _mySessionId = null;
    _lastOnlineFingerprint = null;
    await FirebaseDatabase.instance.goOffline();
  }

  Future<void> _cleanupPresence({
    required String houseId,
    required String role,
    required bool markOfflineIfEmpty,
    int? lastSeenMs,
  }) async {
    final ref = _dbRef.child('houses/$houseId/presence/$role');
    final sessionId = _mySessionId;
    if (sessionId != null) {
      try {
        await ref
            .onDisconnect()
            .cancel()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      try {
        await ref.child('sessions/$sessionId').remove();
      } catch (_) {}
    }

    if (!markOfflineIfEmpty) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _pruneStaleSessions(ref, nowMs: now);
    await _refreshAggregatePresence(
      ref,
      nowMs: now,
      lastSeenMs: lastSeenMs,
      preferredDevice: _activeDeviceType,
    );
  }

  Future<void> refreshCurrentPresenceSnapshot() async {
    final ref = _myPresenceRef;
    if (ref == null) {
      return;
    }
    await _refreshAggregatePresence(
      ref,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      preferredDevice: _activeDeviceType,
    );
  }

  Future<bool> verifyBackendReachability() async {
    try {
      await _backendProbeRef.get().timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      if (_isPermissionDenied(e)) {
        return true;
      }
      debugPrint(
          'Presence backend reachability failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra kết nối hiện diện.',
      ).message}');
      return false;
    }
  }

  static bool _isPermissionDenied(Object error) {
    return error.toString().toLowerCase().contains('permission denied');
  }

  Future<bool> refreshAndVerifyBackendReachability() async {
    final connected = await verifyBackendReachability();
    if (!connected || !_shouldBeOnline) {
      return connected;
    }
    await _doGoOnline();
    return true;
  }

  Future<void> notifyAppPaused({int? lastSeenMs}) async {
    final ref = _myPresenceRef;
    if (ref == null) {
      return;
    }
    await _refreshAggregatePresence(
      ref,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      lastSeenMs: lastSeenMs,
      preferredDevice: _activeDeviceType,
    );
  }

  Future<void> notifyAppResumed() async {
    if (!_shouldBeOnline) {
      return;
    }
    await _heartbeat();
  }

  Future<void> notifyConnectivityLost({int? lastSeenMs}) async {
    await notifyAppPaused(lastSeenMs: lastSeenMs);
  }

  Future<void> notifyConnectivityRestored() async {
    if (!_shouldBeOnline) {
      return;
    }
    debugPrint(
      '[Presence] connectivity restored role=${_activeRole ?? '-'} house=${_activeHouseId ?? '-'} session=${_mySessionId ?? '-'}',
    );
    await _doGoOnline();
  }

  Future<bool> isPartnerOnline(String houseId, String myRole) async {
    final partnerRole = myRole == 'user1' ? 'user2' : 'user1';
    try {
      final snap =
          await _dbRef.child('houses/$houseId/presence/$partnerRole').get();
      if (!snap.exists || snap.value == null) {
        return false;
      }
      final raw = snap.value;
      if (raw is! Map) {
        return false;
      }
      return isPresenceOnline(raw);
    } catch (_) {
      return false;
    }
  }

  /// Cancel all subscriptions and timers to prevent leaks.
  void dispose() {
    _connectedSub?.cancel();
    _heartbeatTimer?.cancel();
    _shouldBeOnline = false;
  }
  Future<void> setSleepMode(bool isSleeping) async {
    final houseId = _activeHouseId;
    final role = _activeRole;
    if (houseId == null || role == null) return;
    
    final updates = <String, dynamic>{
      'sleep_mode': isSleeping,
    };
    if (isSleeping) {
      updates['sleep_start_time'] = ServerValue.timestamp;
    }
    
    try {
      await _presenceRoleRef(houseId, role).update(updates);
    } catch (e) {
      debugPrint('[Presence] Error setting sleep mode: $e');
    }
  }

  static bool isSleeping(Map<dynamic, dynamic>? data) {
    if (data == null) return false;
    
    final sleepMode = data['sleep_mode'];
    if (sleepMode is bool && sleepMode) return true;
    
    final lastSeen = lastSeenMs(data) ?? latestSessionTimestamp(data);
    if (lastSeen != null) {
      final now = DateTime.now();
      final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
      final diffHours = now.difference(lastSeenDate).inHours;
      
      if (diffHours >= 1 && (now.hour >= 23 || now.hour <= 6)) {
        return true;
      }
    }
    
    return false;
  }
}
