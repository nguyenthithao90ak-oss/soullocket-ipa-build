import 'package:shared_preferences/shared_preferences.dart';

/// Mốc chống lặp trên máy chỉ thuộc tài khoản, Nhà và loại tín hiệu đã bắt đầu.
class HomeInteractionCooldown {
  static const interval = Duration(hours: 1);
  static final Set<String> _pending = <String>{};

  static String key({
    required String uid,
    required String houseId,
    required String role,
    required String type,
    required String channel,
  }) {
    final normalizedType = type.trim().toLowerCase();
    final parts = [
      channel,
      uid,
      houseId,
      role,
      normalizedType.isEmpty ? 'miss' : normalizedType,
    ];
    return 'il_home_interaction_cooldown_v4/${parts.map(Uri.encodeComponent).join('/')}';
  }

  static Future<bool> run({
    required String key,
    required Future<SharedPreferences> Function() loadPreferences,
    required bool Function() isCurrent,
    required Future<void> Function() action,
    int Function()? nowMilliseconds,
  }) async {
    if (!isCurrent() || !_pending.add(key)) return false;
    try {
      final prefs = await loadPreferences();
      if (!isCurrent()) return false;
      final now =
          nowMilliseconds?.call() ?? DateTime.now().millisecondsSinceEpoch;
      final previous = prefs.getInt(key);
      if (previous != null && now - previous < interval.inMilliseconds) {
        return false;
      }
      await action();
      // Nếu phiên đổi trong khi gửi, chỉ ghi mốc vào khóa của phiên đã gửi.
      // Không chuyển mốc vô chủ cũ sang tài khoản vừa đăng nhập.
      await prefs.setInt(key, now);
      return true;
    } finally {
      _pending.remove(key);
    }
  }
}
