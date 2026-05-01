import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';
import '../../../utils/sl_notice.dart';
import '../../../utils/services/notification_service.dart';
import '../../app_entry.dart';

class AuthFeedbackDialogs {
  const AuthFeedbackDialogs._();

  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    SLNotice.showError(context, message);
  }

  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String message,
    Widget? next,
    bool autoContinue = false,
  }) async {
    if (!context.mounted) return;
    final target = next ?? const AppEntry();
    final navigator = NotificationService.navigatorKey.currentState ??
        Navigator.maybeOf(context, rootNavigator: true);

    void navigateToTarget() {
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => target),
        (route) => false,
      );
    }

    if (autoContinue) {
      SLNotice.showSuccess(context, message);
      navigateToTarget();
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
        title: Text(
          L10nService().translate('Thành công'),
          style: SLTheme.quicksand(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          L10nService().translate(message),
          style: SLTheme.quicksand(fontWeight: FontWeight.w600),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SLColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: SLRadius.smAll),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              navigateToTarget();
            },
            child: const Text(
              'BẮT ĐẦU NGAY',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showAccountNotFoundDialog(
    BuildContext context, {
    required String message,
    required VoidCallback onCreateNew,
  }) {
    if (!context.mounted) return Future.value();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          L10nService().translate('Không tìm thấy tài khoản'),
          style: SLTheme.quicksand(
            color: SLColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          L10nService().translate(message),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              L10nService().translate('Thử lại'),
              style: SLTheme.quicksand(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onCreateNew();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SLColors.primaryActive,
              foregroundColor: Colors.white,
            ),
            child: Text(
              L10nService().translate('Tạo Mới Ngay'),
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showLoginErrorWithRecovery(
    BuildContext context, {
    required String message,
    required VoidCallback onRegister,
    required VoidCallback onForgotPassword,
    required VoidCallback onForgotGmail,
  }) {
    if (!context.mounted) return Future.value();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          L10nService().translate('Không đăng nhập được'),
          style: SLTheme.quicksand(
            color: SLColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10nService().translate(message),
                style: SLTheme.quicksand(),
              ),
              SLSpacing.h16,
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onForgotGmail();
                  },
                  child: Text(
                    L10nService().translate('Quên Gmail?'),
                    style: SLTheme.quicksand(
                      color: SLColors.primaryActive,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRegister();
            },
            child: Text(
              L10nService().translate('Đăng Ký Mới'),
              style: SLTheme.quicksand(
                color: SLColors.primaryActive,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onForgotPassword();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SLColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(
              L10nService().translate('Quên Mật Khẩu'),
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
