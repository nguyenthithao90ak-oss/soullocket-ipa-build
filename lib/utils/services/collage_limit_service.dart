import 'package:soullocket_app/utils/ui_copy.dart';
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
  /// VIP được ghép ảnh không giới hạn (VIP không có quảng cáo để xem thêm lượt).
  Future<bool> checkLimitAndAskAd({
    required Future<bool> Function(int currentLimit, int dailyLimit)
        onAskUserToWatchAd,
    required void Function(String message, {bool isError}) onShowMessage,
    Future<bool> Function()? isVip,
    bool Function()? isCurrent,
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
      // Chỉ hỏi quyền VIP khi đã hết lượt thường, tránh gọi mạng mỗi lần ghép.
      if (await _checkVip(isVip)) return true;
      if (isCurrent?.call() == false) return false;
      final lastAdTime = prefs.getInt('collage_last_ad_time_$today') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const int cooldownMs = 15 * 60 * 1000;

      // Nếu đã xem quảng cáo trong vòng 15 phút, tặng luôn lượt mà không cần xem lại
      if (nowMs - lastAdTime < cooldownMs) {
        await prefs.setInt(extraKey, extraLimit + dailyLimit);
        onShowMessage(
            UiCopy.text('copy_d3235d2eafe4', {'value1': dailyLimit}),
            isError: false);
        return true;
      }

      AdMobService().preloadRewardedAd();
      bool wantToWatchAd = await onAskUserToWatchAd(currentLimit, dailyLimit);
      if (!wantToWatchAd || isCurrent?.call() == false) {
        return false;
      }

      // Show rewarded ad
      bool watched = await AdMobService().showRewardedAd(isCurrent: isCurrent);
      if (watched) {
        await prefs.setInt(extraKey, extraLimit + dailyLimit);
        await prefs.setInt('collage_last_ad_time_$today',
            DateTime.now().millisecondsSinceEpoch);
        onShowMessage(UiCopy.text('copy_9824528f08aa', {'value1': dailyLimit}),
            isError: false);
        return true;
      } else {
        onShowMessage(UiCopy.text('copy_4f6681c556f3'), isError: true);
        return false;
      }
    }
    return true;
  }

  Future<bool> _checkVip(Future<bool> Function()? isVip) async {
    try {
      return await (isVip ?? AdMobService().isProUser)().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      // Không đọc được quyền VIP thì giữ luồng thường (xem quảng cáo thêm lượt).
      return false;
    }
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
