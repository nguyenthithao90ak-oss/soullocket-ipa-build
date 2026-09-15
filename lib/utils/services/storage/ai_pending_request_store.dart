import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Chỉ giữ mã khôi phục, không giữ prompt, câu trả lời hoặc token xác thực.
/// UID cố định của màn hình là namespace; quyền đọc kết quả vẫn do server kiểm tra.
class AiPendingRequestStore {
  AiPendingRequestStore(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  static Future<void>? _writes;
  static final _idPattern = RegExp(r'^\d{13}_[a-f0-9]{32}$');

  String _key(String uid) {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid');
    return 'ai_pending_chat_v1_${base64Url.encode(utf8.encode(uid))}';
  }

  bool _valid(String id) {
    if (!_idPattern.hasMatch(id)) return false;
    final age = _now().millisecondsSinceEpoch - int.parse(id.substring(0, 13));
    return age >= -const Duration(minutes: 5).inMilliseconds &&
        age < const Duration(hours: 1).inMilliseconds;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final next = (_writes ?? Future<void>.value()).then((_) => action());
    // Lỗi một lần ghi không làm hỏng toàn bộ hàng đợi lần sau.
    final settled = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes = settled;
    unawaited(
      settled.then((_) {
        if (identical(_writes, settled)) _writes = null;
      }),
    );
    return next;
  }

  Future<String?> read(String uid) => _serialized(() async {
    final key = _key(uid);
    final raw = _prefs.get(key);
    if (raw == null) return null;
    if (raw is String && _valid(raw)) return raw;
    if (!await _prefs.remove(key)) throw StateError('Pending cleanup failed');
    return null;
  });

  Future<void> save(String uid, String requestId) => _serialized(() async {
    if (!_valid(requestId)) throw ArgumentError('Invalid pending request');
    final key = _key(uid);
    final previous = _prefs.get(key);
    // Không cho một màn hình mới ghi đè lượt chưa được người dùng xử lý.
    if (previous is String && _valid(previous) && previous != requestId) {
      throw StateError('Pending request already exists');
    }
    if (!await _prefs.setString(key, requestId)) {
      throw StateError('Pending persistence failed');
    }
  });

  Future<void> clear(String uid, String requestId) => _serialized(() async {
    final key = _key(uid);
    // Response/cleanup cũ không được xóa marker của lượt mới.
    if (_prefs.get(key) != requestId) return;
    if (!await _prefs.remove(key)) throw StateError('Pending cleanup failed');
  });
}
