import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/collage_limit_service.dart';

class CollageLimitUiHelper {
  static Future<bool> checkLimitAndAskAd(BuildContext context) {
    return CollageLimitService().checkLimitAndAskAd(
      onAskUserToWatchAd: (currentLimit, dailyLimit) async {
        if (!context.mounted) return false;
        return await showDialog<bool>(
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
      },
      onShowMessage: (message, {bool isError = false}) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message,
                style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError ? null : const Color(0xFFD81B60),
          ),
        );
      },
    );
  }
}
