import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/collage_limit_service.dart';

class CollageLimitUiHelper {
  static Future<bool> checkLimitAndAskAd(BuildContext context) {
    return CollageLimitService().checkLimitAndAskAd(
      onAskUserToWatchAd: (currentLimit, dailyLimit) async {
        if (!context.mounted) return false;
        return await showDialog<bool>(
              context: context,
              builder: (context) => SLAlertDialog(
                title: const Text('Hết lượt tạo ảnh'),
                content: Text(
                  'Bạn đã hết lượt tạo ảnh hôm nay ($currentLimit lượt).\nHãy xem 1 quảng cáo để nhận thêm $dailyLimit lượt tạo ảnh nữa nhé!',
                ),
                actions: [
                  SLDialogAction(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  SLDialogAction.icon(
                    primary: true,
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.play_circle_fill),
                    label: Text('Nhận $dailyLimit lượt'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onShowMessage: (message, {bool isError = false}) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(message,
                ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError ? null : const Color(0xFFD81B60),
          ),
        );
      },
    );
  }
}
