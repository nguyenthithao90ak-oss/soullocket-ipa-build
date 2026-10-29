import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../incoming_call_payload.dart';

/// Giữ quyết định đóng chuông qua isolate nền và lần mở app kế tiếp.
abstract final class IncomingCallSuppression {
  static const _prefix = 'il_call_closed:';
  static const lifetime = Duration(seconds: 90);

  static String _key(String uid, String roomId) => '$_prefix$uid:$roomId';

  static bool isClosed(
    SharedPreferences prefs, {
    required String? uid,
    required String roomId,
    int? now,
  }) {
    if (uid == null || uid.isEmpty || !validIncomingCallRoomId(roomId)) {
      return false;
    }
    final value = prefs.get(_key(uid, roomId));
    if (value is! int) return false;
    final current = now ?? DateTime.now().millisecondsSinceEpoch;
    // Đồng hồ đổi lùi không được giữ dấu đóng vô hạn.
    return value > current && value <= current + lifetime.inMilliseconds;
  }

  static Future<void> close({
    required String? uid,
    required String roomId,
    int? now,
  }) async {
    if (uid == null || uid.isEmpty || !validIncomingCallRoomId(roomId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final current = now ?? DateTime.now().millisecondsSinceEpoch;
      final until = current + lifetime.inMilliseconds;
      // Mỗi room một key: hai isolate không ghi đè cả bản đồ quyết định của nhau.
      await prefs.setInt(_key(uid, roomId), until);
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith(_prefix),
      )) {
        final value = prefs.get(key);
        if (value is! int || value <= current || value > until + lifetime.inMilliseconds) {
          await prefs.remove(key);
        }
      }
    } catch (error) {
      // Lỗi bộ nhớ không được ngăn người dùng ngắt chuông/cuộc gọi.
      debugPrint('[IncomingCall] Chưa lưu được dấu đóng: ${error.runtimeType}');
    }
  }
}
