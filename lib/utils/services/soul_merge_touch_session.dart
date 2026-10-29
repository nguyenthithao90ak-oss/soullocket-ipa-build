import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Chỉ là trạng thái tương tác tạm thời, không thay thế quyền House ở rules.
@immutable
class SoulMergeTouchState {
  const SoulMergeTouchState({
    this.isHolding = false,
    this.isSelfReady = false,
    this.isPartnerReady = false,
    this.pairId,
  });

  final bool isHolding;
  final bool isSelfReady;
  final bool isPartnerReady;
  final String? pairId;
  bool get isTogether => isHolding && isSelfReady && isPartnerReady;

  @override
  bool operator ==(Object other) =>
      other is SoulMergeTouchState &&
      isHolding == other.isHolding &&
      isSelfReady == other.isSelfReady &&
      isPartnerReady == other.isPartnerReady &&
      pairId == other.pairId;

  @override
  int get hashCode =>
      Object.hash(isHolding, isSelfReady, isPartnerReady, pairId);
}

abstract interface class SoulMergeTouchTransport {
  Stream<bool> watchConnected();
  Stream<int> watchServerOffset();
  Stream<Object?> watchRole(String role);
  String newSessionId();
  Future<bool> writeTouch(
    String role,
    Map<String, Object?> record, {
    required bool claim,
  });
  Future<void> clearTouch(String role, String uid, String sessionId);
}

class FirebaseSoulMergeTouchTransport implements SoulMergeTouchTransport {
  FirebaseSoulMergeTouchTransport(this.database, this.houseId);

  final FirebaseDatabase database;
  final String houseId;
  DatabaseReference _role(String role) =>
      database.ref('houses/$houseId/soul_merge/touches/$role');

  @override
  Stream<bool> watchConnected() => database
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  @override
  Stream<int> watchServerOffset() => database
      .ref('.info/serverTimeOffset')
      .onValue
      .where((event) => event.snapshot.value is num)
      .map((event) => (event.snapshot.value as num).toInt());

  @override
  Stream<Object?> watchRole(String role) =>
      _role(role).onValue.map((event) => event.snapshot.value);

  @override
  String newSessionId() => _role('user1').push().key!;

  @override
  Future<bool> writeTouch(
    String role,
    Map<String, Object?> record, {
    required bool claim,
  }) async {
    if (claim) {
      await _role(role).set(record);
      return true;
    }
    final result = await _role(role).runTransaction((raw) {
      // null lần đầu có thể chỉ là cache lạnh; để server đối chiếu lại.
      if (raw == null) return Transaction.success(null);
      if (raw is! Map ||
          raw['sessionId'] != record['sessionId'] ||
          raw['uid'] != record['uid']) {
        return Transaction.abort();
      }
      return Transaction.success(record);
    }, applyLocally: false);
    return result.committed && result.snapshot.value != null;
  }

  @override
  Future<void> clearTouch(String role, String uid, String sessionId) async {
    await _role(role).runTransaction((raw) {
      if (raw == null) return Transaction.success(null);
      if (raw is Map && raw['sessionId'] == sessionId && raw['uid'] == uid) {
        return Transaction.success(null);
      }
      return Transaction.abort();
    }, applyLocally: false);
  }
}

/// Một lần giữ tay có ID mới; chỉ ghép khi hai role có hai phiên cùng giữ.
/// Không dùng bump cũ hoặc trạng thái online để suy ra người ấy đang chạm.
class SoulMergeTouchSession extends ValueNotifier<SoulMergeTouchState> {
  SoulMergeTouchSession({
    required this.transport,
    required this.uid,
    required this.role,
    required this.validateScope,
    required this.scopeStillCurrent,
    DateTime Function()? now,
    this.heartbeat = const Duration(seconds: 1),
    this.ttl = const Duration(seconds: 3),
  }) : assert(role == 'user1' || role == 'user2'),
       _now = now ?? DateTime.now,
       super(const SoulMergeTouchState()) {
    _subscriptions.addAll([
      transport.watchConnected().listen(_onConnected, onError: _onError),
      transport.watchServerOffset().listen((offset) {
        _offset = offset;
        _publish();
        _sendPulse();
      }, onError: _onError),
      for (final r in ['user1', 'user2'])
        transport.watchRole(r).listen((raw) {
          _records[r] = raw;
          _publish();
        }, onError: _onError),
    ]);
  }

  final SoulMergeTouchTransport transport;
  final String uid;
  final String role;
  final Future<bool> Function() validateScope;
  final bool Function() scopeStillCurrent;
  final DateTime Function() _now;
  final Duration heartbeat;
  final Duration ttl;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _records = <String, Object?>{};
  final _clearing = <String, Future<void>>{};
  Timer? _heartbeatTimer;
  Timer? _expiryTimer;
  bool _closed = false;
  bool _connected = false;
  bool _holding = false;
  bool _writing = false;
  bool _claimed = false;
  int? _offset;
  int _generation = 0;
  String? _sessionId;
  String? _ackedSessionId;
  String? _attemptedSessionId;

  String? get sessionId => _sessionId;
  int get _serverNow => _now().millisecondsSinceEpoch + (_offset ?? 0);

  void press() {
    if (_closed || _holding || !scopeStillCurrent()) return;
    _generation++;
    _holding = true;
    _sessionId = transport.newSessionId();
    _ackedSessionId = null;
    _claimed = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeat, (_) => _sendPulse());
    _publish();
    _sendPulse();
  }

  void release() {
    if (_closed) return;
    _endHold();
    _publish();
  }

  void _endHold() {
    _generation++;
    _holding = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _ackedSessionId = null;
    final attempted = _attemptedSessionId;
    _attemptedSessionId = null;
    _sessionId = null;
    _claimed = false;
    if (attempted != null) _clear(attempted);
  }

  void _onConnected(bool connected) {
    if (_closed) return;
    _connected = connected;
    // Mất mạng phải thả phiên; nối lại không tự phục hồi cử chỉ đã hết.
    if (!connected) _endHold();
    _publish();
    if (connected) _sendPulse();
  }

  void _onError(Object error, StackTrace stack) {
    if (_closed) return;
    _connected = false;
    _endHold();
    _publish();
    debugPrint('[SoulMergeTouchSession] ${error.runtimeType}');
  }

  bool _sameAttempt(int generation, String id) =>
      !_closed &&
      _holding &&
      _connected &&
      _generation == generation &&
      _sessionId == id &&
      scopeStillCurrent();

  Future<void> _sendPulse() async {
    final id = _sessionId;
    if (_closed ||
        !_holding ||
        !_connected ||
        _offset == null ||
        _writing ||
        id == null) {
      return;
    }
    final generation = _generation;
    _writing = true;
    try {
      if (!await validateScope() || !_sameAttempt(generation, id)) {
        if (!_closed && _generation == generation) release();
        return;
      }
      final sentAt = _serverNow;
      _attemptedSessionId = id;
      final accepted = await transport.writeTouch(role, {
        'sessionId': id,
        'uid': uid,
        'at': ServerValue.timestamp,
        // Timestamp server có thể được giải quyết muộn sau offline; trần này
        // ngăn lệnh chạm cũ trong queue biến thành một lần giữ tay mới.
        'expiresAt': sentAt + ttl.inMilliseconds,
      }, claim: !_claimed);
      if (!await validateScope() || !_sameAttempt(generation, id)) {
        _clear(id);
        if (!_closed && _generation == generation) release();
        return;
      }
      if (!accepted) {
        release();
        return;
      }
      _claimed = true;
      _ackedSessionId = id;
      _publish();
    } catch (error) {
      if (!_closed && _generation == generation) release();
      debugPrint('[SoulMergeTouchSession] ${error.runtimeType}');
    } finally {
      _writing = false;
    }
  }

  Map? _fresh(String r) {
    if (_offset == null) return null;
    final record = _records[r];
    if (record is! Map ||
        record['sessionId'] is! String ||
        (record['sessionId'] as String).isEmpty ||
        record['uid'] is! String ||
        (record['uid'] as String).isEmpty ||
        record['at'] is! num ||
        record['expiresAt'] is! num) {
      return null;
    }
    final now = _serverNow;
    final at = (record['at'] as num).toInt();
    final expiry = (record['expiresAt'] as num).toInt();
    if (at > now + 500 ||
        at < now - ttl.inMilliseconds ||
        expiry <= now ||
        expiry > now + ttl.inMilliseconds + 500 ||
        expiry < at) {
      return null;
    }
    return record;
  }

  void _publish() {
    if (_closed) return;
    _expiryTimer?.cancel();
    if (!scopeStillCurrent()) {
      _endHold();
    }
    final active = _connected && scopeStillCurrent();
    final self = active ? _fresh(role) : null;
    final partnerRole = role == 'user1' ? 'user2' : 'user1';
    final partner = active ? _fresh(partnerRole) : null;
    final selfReady =
        _holding &&
        self != null &&
        self['uid'] == uid &&
        self['sessionId'] == _sessionId &&
        _ackedSessionId == _sessionId;
    final partnerReady = partner != null && partner['sessionId'] != _sessionId;
    final pair = selfReady && partnerReady
        ? (role == 'user1'
              ? '${self['sessionId']}|${partner['sessionId']}'
              : '${partner['sessionId']}|${self['sessionId']}')
        : null;
    final next = SoulMergeTouchState(
      isHolding: _holding,
      isSelfReady: selfReady,
      isPartnerReady: partnerReady,
      pairId: pair,
    );
    if (value != next) value = next;
    final deadlines = [
      if (self != null) ...[
        (self['expiresAt'] as num).toInt(),
        (self['at'] as num).toInt() + ttl.inMilliseconds + 1,
      ],
      if (partner != null) ...[
        (partner['expiresAt'] as num).toInt(),
        (partner['at'] as num).toInt() + ttl.inMilliseconds + 1,
      ],
    ];
    if (deadlines.isNotEmpty) {
      deadlines.sort();
      _expiryTimer = Timer(
        Duration(milliseconds: (deadlines.first - _serverNow).clamp(1, 4000)),
        _publish,
      );
    }
  }

  void _clear(String id) {
    // Không chờ ACK set và không xếp nhiều cleanup cho cùng một phiên offline.
    if (_clearing.containsKey(id)) return;
    final pending = transport.clearTouch(role, uid, id).catchError((Object e) {
      debugPrint('[SoulMergeTouchSession] cleanup ${e.runtimeType}');
    });
    _clearing[id] = pending;
    unawaited(pending.whenComplete(() => _clearing.remove(id)));
  }

  /// Hủy listener/timer ngay; cleanup ownership được hoàn tất ở nền.
  void close() => dispose();

  @override
  void dispose() {
    if (_closed) return;
    _endHold();
    _publish();
    _closed = true;
    _expiryTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }
}
