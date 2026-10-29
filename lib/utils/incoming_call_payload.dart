import 'services/couple_call_signaling.dart';

/// Khóa ổn định giữa isolate FCM, lần mở app mới và thao tác từ khay thông báo.
int incomingCallNotificationId(String roomId) {
  var hash = 0x811c9dc5;
  for (final unit in 'soul_call:$roomId'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

enum IncomingCallAction { open, answer, decline, end, mute }

class IncomingCallRequest {
  const IncomingCallRequest(this.data, this.action);
  final Map<String, dynamic> data;
  final IncomingCallAction action;
  String get roomId => data['roomId']?.toString().trim() ?? '';
}

bool validIncomingCallRoomId(String id) =>
    RegExp(r'^[A-Za-z0-9_-]{1,260}$').hasMatch(id);

int? incomingCallLocalDeadline(Map<String, dynamic> data) {
  final raw = data['localExpiresAt'];
  return raw is num && raw.isFinite
      ? raw.toInt()
      : int.tryParse(raw?.toString() ?? '');
}

bool incomingCallLocallyExpired(Map<String, dynamic> data, int now) =>
    data.containsKey('localExpiresAt') &&
    (incomingCallLocalDeadline(data) ?? 0) <= now;

bool validIncomingCallScopeId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

/// Chặn dữ liệu legacy sai kiểu trước khi mở chuông hoặc cấp SDP cho WebRTC.
/// Quyền caller/House do Rules xác minh khi tạo phòng, không tin payload push.
bool validIncomingCallRoom(Object? raw) {
  if (raw is! Map ||
      raw['status'] != 'ringing' ||
      !validIncomingCallScopeId(raw['callerId']) ||
      !validIncomingCallScopeId(raw['houseId']) ||
      !validIncomingCallScopeId(raw['calleeId']) ||
      raw['isVideo'] is! bool ||
      (raw['callerName'] != null &&
          (raw['callerName'] is! String ||
              (raw['callerName'] as String).length > 120))) {
    return false;
  }
  final offer = raw['offer'];
  return offer is Map &&
      offer['type'] == 'offer' &&
      offer['sdp'] is String &&
      (offer['sdp'] as String).isNotEmpty &&
      (offer['sdp'] as String).length <= 65536;
}

/// Transaction nhận máy phải khớp đúng phòng đã xác minh trước khi tạo answer.
bool sameIncomingCallIdentity(Map current, Map verified) {
  for (final key in [
    'callerId',
    'houseId',
    'calleeId',
    'timestamp',
    'isVideo',
  ]) {
    if (current[key] != verified[key]) return false;
  }
  final offer = current['offer'], original = verified['offer'];
  return offer is Map &&
      original is Map &&
      offer['type'] == original['type'] &&
      offer['sdp'] == original['sdp'];
}

/// Chỉ dữ liệu phòng đã đọc từ server mới được dùng để nhận hoặc từ chối.
Map<String, dynamic>? incomingCallFromRoom({
  required String roomId,
  required Object? raw,
  required String uid,
  required String houseId,
  required int serverNow,
  required int deviceNow,
}) {
  if (!validIncomingCallRoomId(roomId) ||
      raw is! Map ||
      uid.isEmpty ||
      houseId.isEmpty ||
      raw['status'] != 'ringing' ||
      raw['calleeId'] != houseId ||
      raw['callerId'] == uid ||
      (raw['callerId']?.toString().trim().isEmpty ?? true) ||
      (raw['houseId']?.toString().trim().isEmpty ?? true)) {
    return null;
  }
  final expiry = localCallExpiresAt(
    raw['timestamp'],
    serverNow: serverNow,
    deviceNow: deviceNow,
  );
  if (expiry == null || expiry <= deviceNow) return null;
  return {
    ...Map<String, dynamic>.from(raw),
    'roomId': roomId,
    'accountUid': uid,
    'recipientHouseId': houseId,
    'localExpiresAt': expiry,
  };
}
