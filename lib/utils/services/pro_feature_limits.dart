import 'package:shared_preferences/shared_preferences.dart';

/// Hạn mức tài khoản thường và PRO cho các tiện ích chạy trên máy.
/// Theo bảng chủ dự án chốt ngày 12/10/2026 (tài khoản thường dùng thử có giới hạn,
/// PRO mở rộng). Hạn mức tốn tài nguyên máy chủ (AI, ảnh, video) nằm ở functions/.
abstract final class ProFeatureLimits {
  /// Thư hẹn giờ: số thư đang chờ mở tối đa của tài khoản thường.
  static const int freeCapsulePending = 3;

  /// Lời nhắn thoại: độ dài tối đa mỗi tin của tài khoản thường.
  /// PRO ghi tới hết dung lượng chung của nhà (5 phút).
  static const Duration freeVoiceMessage = Duration(seconds: 60);

  /// Tarot và Vòng quay: lượt miễn phí mỗi ngày.
  static const int freeTarotReadingsPerDay = 1;
  static const int freeWheelSpinsPerDay = 1;

  /// Xuất nhật ký: tài khoản thường chỉ xuất bấy nhiêu ngày gần nhất.
  static const int freeDiaryExportDays = 30;

  /// Mẫu Love Card thuộc bộ PRO.
  static const Set<String> proLoveCardThemes = {
    'gratitude',
    'adventure',
    'serenity',
  };

  /// Kiểu trải bài Tarot dành cho cặp đôi (PRO).
  static const Set<String> proTarotSpreads = {'connection'};
}

/// Đếm lượt dùng miễn phí mỗi ngày theo tài khoản, lưu trên máy.
/// Ngày tính theo giờ máy; khóa có uid nên đổi tài khoản không dùng chung lượt.
class DailyFreeUsage {
  DailyFreeUsage(
    this.feature, {
    DateTime Function()? now,
    Future<SharedPreferences> Function()? prefs,
  }) : _now = now ?? DateTime.now,
       _prefs = prefs ?? SharedPreferences.getInstance;

  final String feature;
  final DateTime Function() _now;
  final Future<SharedPreferences> Function() _prefs;

  String _key(String uid) {
    final day = _now();
    final date =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    return 'pro_free_usage_${feature}_${uid}_$date';
  }

  Future<int> used(String uid) async {
    final value = (await _prefs()).getInt(_key(uid)) ?? 0;
    return value < 0 ? 0 : value;
  }

  Future<bool> canUse(String uid, int limit) async =>
      (await used(uid)) < limit;

  Future<void> record(String uid) async {
    final prefs = await _prefs();
    final key = _key(uid);
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }
}
