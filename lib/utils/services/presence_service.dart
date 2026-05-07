import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../services/session/presence_status_formatter.dart';

class PresenceService {
  static const PresenceStatusFormatter _statusFormatter =
      PresenceStatusFormatter();

  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  static const Duration onlineFreshness = Duration(minutes: 5);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration staleSessionThreshold = Duration(minutes: 5);
  static const Duration justDisconnectedThreshold = Duration(minutes: 1);

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  DatabaseReference? _myPresenceRef;
  String? _mySessionId;
  bool _shouldBeOnline = false;
  String? _activeHouseId;
  String? _activeRole;
  String? _activeDeviceType;
  String? _lastOnlineFingerprint;
  StreamSubscription? _connectedSub;
  Timer? _heartbeatTimer;

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
    final normalizedIgnoredUid = ignoreUid?.trim();
    for (final value in sessions.values) {
      if (normalizedIgnoredUid != null &&
          normalizedIgnoredUid.isNotEmpty &&
          _readSessionUid(value) == normalizedIgnoredUid) {
        continue;
      }
      final ts = _readSessionTimestamp(value);
      if (ts != null &&
          nowMs - ts >= 0 &&
          nowMs - ts <= onlineFreshness.inMilliseconds) {
        count += 1;
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
    final normalizedIgnoredUid = ignoreUid?.trim();
    final hasIgnoredUidFilter =
        normalizedIgnoredUid != null && normalizedIgnoredUid.isNotEmpty;
    final sessions = data['sessions'];
    if (sessions is Map) {
      final freshSessionCount = _countFreshSessions(
        sessions,
        nowMs: now,
        ignoreUid: ignoreUid,
      );
      if (freshSessionCount > 0) {
        return true;
      }
      if (hasIgnoredUidFilter) {
        return false;
      }
    }

    final activeSessionCount = data['activeSessionCount'];
    if (activeSessionCount is num && activeSessionCount.toInt() > 0) {
      return true;
    }

    final status = data['status']?.toString().trim().toLowerCase();
    if (status != 'online') {
      return false;
    }

    final lastSeen = _readEpochMs(data['lastSeen']);
    if (lastSeen == null) {
      return true;
    }
    return now - lastSeen >= 0 &&
        now - lastSeen <= onlineFreshness.inMilliseconds;
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
        return _statusFormatter.justDisconnectedLabel();
      }
      return _statusFormatter.neverConnectedLabel();
    }
    if (now - lastSeen >= 0 &&
        now - lastSeen <= justDisconnectedThreshold.inMilliseconds) {
      return _statusFormatter.justDisconnectedLabel();
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
    _connectedSub = _backendProbeRef.onValue.listen(
      (_) {
        if (_shouldBeOnline) {
          unawaited(_doGoOnline());
        }
      },
      onError: (Object error) {
        debugPrint('Presence backend listener failed: $error');
      },
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_shouldBeOnline) {
        unawaited(_heartbeat());
      }
    });
  }

  Future<void> _heartbeat() async {
    if (!_shouldBeOnline || _myPresenceRef == null || _mySessionId == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _myPresenceRef!.child('sessions/$_mySessionId').set({
        'ts': now,
        if (_currentUid != null) 'uid': _currentUid,
        if (_activeDeviceType != null) 'device': _activeDeviceType,
      }).timeout(const Duration(seconds: 3));
      await _refreshAggregatePresence(
        _myPresenceRef!,
        nowMs: now,
        preferredDevice: _activeDeviceType,
      );
      debugPrint('Presence heartbeat refreshed session $_mySessionId');
    } on TimeoutException {
      return;
    } catch (e) {
      debugPrint('Presence heartbeat failed: $e');
    }
  }

  Future<void> markActiveNow() async {
    if (!_shouldBeOnline) {
      return;
    }
    if (_myPresenceRef == null || _mySessionId == null) {
      await _doGoOnline();
      return;
    }
    await _heartbeat();
  }

  Future<void> _pruneStaleSessions(
    DatabaseReference ref, {
    required int nowMs,
  }) async {
    try {
      final snap =
          await ref.child('sessions').get().timeout(const Duration(seconds: 3));
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
      debugPrint('Presence stale session prune failed: $e');
    }
  }

  Future<void> _removeCurrentUidGhostSessions({
    required int nowMs,
  }) async {
    final houseId = _activeHouseId;
    final role = _activeRole;
    final uid = _currentUid;
    if (houseId == null || role == null || uid == null || uid.isEmpty) {
      return;
    }

    final oppositeRole = role == 'user1' ? 'user2' : 'user1';
    final oppositeRef = _presenceRoleRef(houseId, oppositeRole);
    try {
      final snap = await oppositeRef
          .child('sessions')
          .get()
          .timeout(const Duration(seconds: 3));
      final sessions = _readSessionMap(snap.value);
      if (sessions.isEmpty) {
        return;
      }

      final updates = <String, dynamic>{};
      for (final entry in sessions.entries) {
        final sessionUid = _readSessionUid(entry.value);
        if (sessionUid != uid) {
          continue;
        }
        updates[entry.key.toString()] = null;
      }

      if (updates.isEmpty) {
        return;
      }

      await oppositeRef.child('sessions').update(updates);
      await _refreshAggregatePresence(
        oppositeRef,
        nowMs: nowMs,
        preferredDevice: _activeDeviceType,
      );
      debugPrint(
        'Presence removed ghost sessions from $oppositeRole for uid $uid: ${updates.keys.join(', ')}',
      );
    } catch (e) {
      debugPrint('Presence ghost session cleanup failed: $e');
    }
  }

  Future<void> _refreshAggregatePresence(
    DatabaseReference ref, {
    required int nowMs,
    int? lastSeenMs,
    String? preferredDevice,
  }) async {
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 3));
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

      await ref.update({
        'status': freshSessionCount > 0 ? 'online' : 'offline',
        'lastSeen': freshSessionCount > 0
            ? resolvedLastSeen
            : (lastSeenMs ?? resolvedLastSeen),
        'activeSessionCount': freshSessionCount,
        if (resolvedDevice != null && resolvedDevice.isNotEmpty)
          'device': resolvedDevice,
      }).timeout(const Duration(seconds: 3));
      debugPrint(
        '[Presence] aggregate role=${ref.key} status=${freshSessionCount > 0 ? 'online' : 'offline'} sessions=$freshSessionCount lastSeen=$resolvedLastSeen device=${resolvedDevice ?? '-'}',
      );
    } catch (e) {
      debugPrint('Presence aggregate refresh failed: $e');
    }
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

    final nextPath = 'houses/$_activeHouseId/presence/$_activeRole';
    _myPresenceRef = _dbRef.child(nextPath);

    final now = DateTime.now().millisecondsSinceEpoch;
    _mySessionId ??= '${now}_${_dbRef.push().key}';

    try {
      await _removeCurrentUidGhostSessions(nowMs: now);
      await _pruneStaleSessions(_myPresenceRef!, nowMs: now);
      await _myPresenceRef!.child('sessions/$_mySessionId').set({
        'ts': now,
        if (_currentUid != null) 'uid': _currentUid,
        if (_activeDeviceType != null) 'device': _activeDeviceType,
      }).timeout(const Duration(seconds: 3));
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
      debugPrint('Presence online for $_activeRole in $_activeHouseId');
    } on TimeoutException {
      return;
    } catch (e) {
      debugPrint('Presence write failed: $e');
    }
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
            .child('sessions/$sessionId')
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
      debugPrint('Presence backend reachability failed: $e');
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
}
