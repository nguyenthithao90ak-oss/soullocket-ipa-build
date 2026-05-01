import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// ============================================================
///  AntiSpamRateLimitService — Gra (Logic/Data)
///  Bộ lọc chống SPAM cho Tin nhắn và Tương tác (Phase 6)
///
///  Chức năng:
///  1. Theo dõi tần suất gọi API từ màn hình Chat, thả tim.
///  2. Giới hạn số gửi không quá 5 tin nhắn/2 giây.
///  3. Block tạm thời thiết bị nếu phát hiện spam (Phạt lũy tiến).
///  4. Shadow Ban nếu vi phạm quá nhiều.
/// ============================================================
class AntiSpamRateLimitService {
  static final AntiSpamRateLimitService _instance =
      AntiSpamRateLimitService._internal();
  factory AntiSpamRateLimitService() => _instance;
  AntiSpamRateLimitService._internal();

  // Lưu trữ lịch sử gọi hàm theo Action Tên.
  final Map<String, List<int>> _actionTimestamps = {};

  String? _deviceId;

  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('il_antispam_device_id');

      if (_deviceId == null) {
        // Tạo một ID ngẫu nhiên thay vì dùng ANDROID_ID (deviceInfo.androidInfo.id)
        // Việc này giúp tránh bị Google Play bắt khai báo thu thập "Device or other IDs"
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final randomVal = Random().nextInt(999999);
        _deviceId = 'dev_${timestamp}_$randomVal';
        await prefs.setString('il_antispam_device_id', _deviceId!);
      }
    } catch (e) {
      _deviceId = 'unknown_device';
    }
    return _deviceId!;
  }

  /// Kiểm tra xem thiết bị có đang bị khoá Spam không
  Future<bool> get isLocked async {
    final prefs = await SharedPreferences.getInstance();
    final cooldown = prefs.getInt('il_antispam_cooldown') ?? 0;
    return DateTime.now().millisecondsSinceEpoch < cooldown;
  }

  /// Kiểm tra xem người dùng có bị Shadow Ban không
  Future<bool> get isShadowBanned async {
    final prefs = await SharedPreferences.getInstance();
    final violations = prefs.getInt('il_antispam_violations') ?? 0;
    return violations >= 5; // Cấm ngầm nếu vi phạm từ 5 lần trở lên
  }

  /// Gọi hàm này trước TẤT CẢ nút bấm gửi API (ví dụ nút gửi tin nhắn)
  ///
  /// Trả về `true` nếu hợp lệ (được gửi), `false` nếu đang bị block.
  Future<bool> checkRateLimit(
      {required String action,
      int maxCalls = 5,
      int timeWindowMs = 2000}) async {
    if (await isShadowBanned) {
      // Đánh lừa bot/tool: Trả về true nhưng thực tế hệ thống gọi API bên ngoài sẽ tự drop hoặc block ngầm.
      // Tuy nhiên, để cho giao diện chạy mượt, ta có thể trả về true.
      // (Nhưng tuỳ cách triển khai, nếu trả về true thì UI vẫn gọi Firebase.
      // Do đó ta trả về false nếu muốn chặn, hoặc throw lỗi ngầm).
      // Để dễ cho UI, ta cứ trả về false để chặn hẳn.
      return false;
    }

    if (await isLocked) return false;

    final now = DateTime.now().millisecondsSinceEpoch;

    if (!_actionTimestamps.containsKey(action)) {
      _actionTimestamps[action] = [];
    }

    final timestamps = _actionTimestamps[action]!;

    // Xoá các mốc thời gian đã quá cũ
    timestamps.removeWhere((t) => now - t > timeWindowMs);

    // Kiểm tra vi phạm
    if (timestamps.length >= maxCalls) {
      await _handleViolation();
      return false;
    }

    timestamps.add(now);
    return true;
  }

  Future<void> _handleViolation() async {
    final prefs = await SharedPreferences.getInstance();
    int violations = (prefs.getInt('il_antispam_violations') ?? 0) + 1;
    await prefs.setInt('il_antispam_violations', violations);

    int cooldownSeconds = 10;
    if (violations == 1) {
      cooldownSeconds = 10;
    } else if (violations == 2) {
      cooldownSeconds = 60; // 1 phút
    } else if (violations == 3) {
      cooldownSeconds = 15 * 60; // 15 phút
    } else if (violations >= 4) {
      cooldownSeconds = 24 * 3600; // 24 giờ
    }

    final cooldownMs =
        DateTime.now().millisecondsSinceEpoch + (cooldownSeconds * 1000);
    await prefs.setInt('il_antispam_cooldown', cooldownMs);
  }

  /// Lấy số giây còn lại phải chờ (khi bị block)
  Future<int> get remainingCooldownSeconds async {
    final prefs = await SharedPreferences.getInstance();
    final cooldown = prefs.getInt('il_antispam_cooldown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cooldown <= now) return 0;
    return ((cooldown - now) / 1000).ceil();
  }

  /// Xoá dữ liệu rác (gọi khi huỷ màn hình hoặc tắt app)
  Future<void> clear() async {
    _actionTimestamps.clear();
    // Không xoá cooldown hay violations ở đây để tránh bot reset app
  }
}
