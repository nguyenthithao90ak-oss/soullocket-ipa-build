import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/sl_theme.dart';
import 'package:soullocket_app/utils/services/admob_service.dart';

class CollageLimitService {
  static final CollageLimitService _instance = CollageLimitService._internal();
  factory CollageLimitService() => _instance;
  CollageLimitService._internal();

  static const int dailyLimit = 20;

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  /// Kiểm tra có thể tạo không, nếu chưa thể thì hỏi xem quảng cáo.
  Future<bool> checkLimitAndAskAd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final countKey = 'collage_count_$today';
    final extraKey = 'collage_extra_$today';

    int currentCount = prefs.getInt(countKey) ?? 0;
    int extraLimit = prefs.getInt(extraKey) ?? 0;
    int currentLimit = dailyLimit + extraLimit;

    if (currentCount >= currentLimit) {
      if (!context.mounted) return false;

      final lastAdTime = prefs.getInt('collage_last_ad_time_$today') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const int cooldownMs = 15 * 60 * 1000;

      // Nếu đã xem quảng cáo trong vòng 15 phút, tặng luôn lượt mà không cần xem lại
      if (nowMs - lastAdTime < cooldownMs) {
        await prefs.setInt(extraKey, extraLimit + dailyLimit);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Vì bạn vừa xem quảng cáo gần đây, tặng bạn thêm $dailyLimit lượt miễn phí!',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFD81B60),
            ),
          );
        }
        return true;
      }

      bool wantToWatchAd = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
              title: Text('Hết lượt tạo ảnh',
                  style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60))),
              content: Text(
                'Bạn đã hết lượt tạo ảnh hôm nay ($currentLimit lượt).\nHãy xem 1 quảng cáo để nhận thêm $dailyLimit lượt tạo ảnh nữa nhé!',
                style: SLTheme.quicksand(fontWeight: FontWeight.w600),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Hủy',
                      style: SLTheme.quicksand(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text('Nhận $dailyLimit lượt',
                      style: SLTheme.quicksand(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60)),
                ),
              ],
            ),
          ) ??
          false;

      if (!wantToWatchAd) {
        return false;
      }

      // Show rewarded ad
      bool watched = await AdMobService().showRewardedAd();
      if (watched) {
        await prefs.setInt(extraKey, extraLimit + dailyLimit);
        await prefs.setInt('collage_last_ad_time_$today',
            DateTime.now().millisecondsSinceEpoch);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bạn đã nhận thêm $dailyLimit lượt tạo ảnh!',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFD81B60),
            ),
          );
        }
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chưa xem xong quảng cáo!',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  /// Trừ 1 lượt sau khi tạo thành công (để không bị mất lượt nếu fail giữa chừng)
  Future<void> consumeLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final countKey = 'collage_count_$today';
    int currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);
  }
}

