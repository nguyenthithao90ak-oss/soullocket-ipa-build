/// Phát hiện "trùng vai": một tài khoản KHÁC đang online ở cùng vai với mình.
///
/// Mỗi người dùng một tài khoản riêng, nên cùng tài khoản mở trên máy khác
/// (điện thoại + máy tính bảng) là bình thường, không tính là trùng vai.
class DuplicateRoleDetector {
  const DuplicateRoleDetector._();

  static int countOtherAccountSessions(
    Object? sessions, {
    required String mySessionId,
    required String? myUid,
    required String? myDeviceId,
    required int nowMs,
    required Duration freshness,
  }) {
    final uid = myUid?.trim() ?? '';
    if (sessions is! Map || uid.isEmpty) return 0;
    var count = 0;
    sessions.forEach((key, value) {
      if (key.toString() == mySessionId || value is! Map) return;
      final ts = _epochMs(
        value['ts'] ?? value['lastSeen'] ?? value['updatedAt'],
      );
      if (ts == null) return;
      final age = nowMs - ts;
      if (age < 0 || age > freshness.inMilliseconds) return;
      final deviceId = value['deviceId']?.toString();
      if (myDeviceId != null && deviceId == myDeviceId) return;
      final otherUid = value['uid']?.toString().trim() ?? '';
      // Phiên không rõ chủ thì không đủ căn cứ để cảnh báo.
      if (otherUid.isEmpty || otherUid == uid) return;
      count++;
    });
    return count;
  }

  static int? _epochMs(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}
