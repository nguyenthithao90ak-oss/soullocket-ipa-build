/// Tín hiệu nhỏ trong House; SDP và ICE tiếp tục nằm ở phòng gọi riêng.
class CoupleCallInvite {
  const CoupleCallInvite({
    required this.roomId,
    required this.houseId,
    required this.callerUid,
    required this.callerName,
    required this.isVideo,
    required this.timestamp,
  });

  final String roomId;
  final String houseId;
  final String callerUid;
  final String callerName;
  final bool isVideo;
  final int timestamp;

  static const ringingSeconds = 45;
  static String inboxPath(String houseId) =>
      'houses/$houseId/soul_merge/call_invite';

  static CoupleCallInvite? incoming(
    Object? raw, {
    required String houseId,
    required String uid,
    required int now,
  }) {
    if (raw is! Map || uid.isEmpty) return null;
    final roomId = raw['roomId']?.toString().trim() ?? '';
    final callerUid = raw['callerUid']?.toString().trim() ?? '';
    final timestamp = raw['timestamp'];
    if (roomId.isEmpty ||
        RegExp(r'[.#$\[\]/]').hasMatch(roomId) ||
        raw['houseId'] != houseId ||
        callerUid.isEmpty ||
        callerUid == uid ||
        !isFreshCallTimestamp(timestamp, now: now)) {
      return null;
    }
    return CoupleCallInvite(
      roomId: roomId,
      houseId: houseId,
      callerUid: callerUid,
      callerName: raw['callerName']?.toString() ?? '',
      isVideo: raw['isVideo'] == true,
      timestamp: (timestamp as num).toInt(),
    );
  }

  bool matchesRingingRoom(Object? raw) =>
      raw is Map &&
      raw['status'] == 'ringing' &&
      raw['houseId'] == houseId &&
      raw['calleeId'] == houseId &&
      raw['callerId'] == callerUid &&
      (raw['isVideo'] == true) == isVideo;
}

/// Dùng giờ server để không phát lại phòng đổ chuông cũ khi mở lại ứng dụng.
bool isFreshCallTimestamp(Object? timestamp, {required int now}) =>
    timestamp is num &&
    timestamp.isFinite &&
    timestamp > 0 &&
    now - timestamp <= CoupleCallInvite.ringingSeconds * 1000 &&
    timestamp - now <= 30000;

/// ICE tới sớm phải đợi remote description và được áp dụng theo thứ tự.
class RtcCandidateQueue<T> {
  RtcCandidateQueue(this.apply);
  final Future<void> Function(T candidate) apply;
  final List<T> _pending = [];
  bool _ready = false;
  bool _closed = false;
  Future<void>? _draining;

  Future<void> add(T candidate) {
    if (_closed) return Future.value();
    _pending.add(candidate);
    return _drain();
  }

  Future<void> markReady() {
    _ready = true;
    return _drain();
  }

  Future<void> _drain() {
    if (_closed || !_ready || _pending.isEmpty) return Future.value();
    return _draining ??= _consume();
  }

  Future<void> _consume() async {
    try {
      while (!_closed && _pending.isNotEmpty) {
        await apply(_pending.removeAt(0));
      }
    } finally {
      _draining = null;
    }
  }

  void close() {
    _closed = true;
    _pending.clear();
  }
}
