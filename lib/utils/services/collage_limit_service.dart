import 'package:shared_preferences/shared_preferences.dart';
import 'admob_service.dart';
import 'offline_cache_service.dart';

class CollageLimitService {
  static final CollageLimitService _instance = CollageLimitService._internal();
  factory CollageLimitService() => _instance;
  CollageLimitService._internal();

  static const int dailyLimit = 5;

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  /// Kiểm tra có thể tạo không, nếu chưa thể thì hỏi xem quảng cáo.
  Future<bool> checkLimitAndAskAd({
    required Future<bool> Function(int currentLimit, int dailyLimit)
        onAskUserToWatchAd,
    required void Function(String message, {bool isError}) onShowMessage,
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final countKey = 'collage_count_$today';
    final extraKey = 'collage_extra_$today';

    int currentCount = prefs.getInt(countKey) ?? 0;
    int extraLimit = prefs.getInt(extraKey) ?? 0;
    int currentLimit = dailyLimit + extraLimit;

    if (currentCount >= currentLimit) {
      final lastAdTime = prefs.getInt('collage_last_ad_time_$today') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const int cooldownMs = 15 * 60 * 1000;

      // Nếu đã xem quảng cáo trong vòng 15 phút, tặng luôn lượt mà không cần xem lại
      if (nowMs - lastAdTime < cooldownMs) {
        await prefs.setInt(extraKey, extraLimit + dailyLimit);
        onShowMessage(
            'Vì bạn vừa xem quảng cáo gần đây, tặng bạn thêm $dailyLimit lượt miễn phí!',
            isError: false);
        return true;
      }

      bool wantToWatchAd = await onAskUserToWatchAd(currentLimit, dailyLimit);
      if (!wantToWatchAd) {
        return false;
      }

      // Show rewarded ad
      bool watched = await AdMobService().showRewardedAd();
      if (watched) {
        await prefs.setInt(extraKey, extraLimit + dailyLimit);
        await prefs.setInt('collage_last_ad_time_$today',
            DateTime.now().millisecondsSinceEpoch);
        onShowMessage('Bạn đã nhận thêm $dailyLimit lượt tạo ảnh!',
            isError: false);
        return true;
      } else {
        onShowMessage('Chưa xem xong quảng cáo!', isError: true);
        return false;
      }
    }
    return true;
  }

  /// Trừ 1 lượt sau khi tạo thành công (để không bị mất lượt nếu fail giữa chừng)
  Future<void> consumeLimit() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final countKey = 'collage_count_$today';
    int currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);
  }
}
