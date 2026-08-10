import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
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

    final l10n = L10nService();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: SLSpacing.all24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: SLRadius.xlAll,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: SLSpacing.all16,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              SLSpacing.h16,
              Text(
                l10n.translate('Thành công'),
                style: SLTheme.quicksand(
                  color: Colors.green,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              SLSpacing.h12,
              Text(
                l10n.translate(message),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: SLColors.textSecond,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SLSpacing.h24,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.pillAll,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    navigateToTarget();
                  },
                  child: Text(
                    l10n.translate('BẮT ĐẦU NGAY'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showAccountNotFoundDialog(
    BuildContext context, {
    required String message,
    required VoidCallback onCreateNew,
  }) {
    if (!context.mounted) return Future.value();
    final l10n = L10nService();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: SLSpacing.all24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: SLRadius.xlAll,
            boxShadow: [
              BoxShadow(
                color: SLColors.danger.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: SLSpacing.all16,
                decoration: BoxDecoration(
                  color: SLColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_off_rounded,
                  color: SLColors.danger,
                  size: 40,
                ),
              ),
              SLSpacing.h16,
              Text(
                l10n.translate('Không tìm thấy tài khoản'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: SLColors.danger,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              SLSpacing.h12,
              Text(
                l10n.translate(message),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: SLColors.textSecond,
                  fontSize: 14,
                ),
              ),
              SLSpacing.h24,
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.pillAll,
                        ),
                      ),
                      child: Text(
                        l10n.translate('Thử lại'),
                        style: SLTheme.quicksand(
                          color: SLColors.textSecond,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onCreateNew();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SLColors.primaryActive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.pillAll,
                        ),
                      ),
                      child: Text(
                        l10n.translate('Tạo Mới Ngay'),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    final l10n = L10nService();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: SLSpacing.all24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: SLRadius.xlAll,
            boxShadow: [
              BoxShadow(
                color: SLColors.danger.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: SLSpacing.all16,
                decoration: BoxDecoration(
                  color: SLColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: SLColors.danger,
                  size: 40,
                ),
              ),
              SLSpacing.h16,
              Text(
                l10n.translate('Không đăng nhập được'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: SLColors.danger,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              SLSpacing.h12,
              Text(
                l10n.translate(message),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: SLColors.textSecond,
                  fontSize: 14,
                ),
              ),
              SLSpacing.h16,
              GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  onForgotGmail();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: SLColors.primaryActive.withValues(alpha: 0.1),
                    borderRadius: SLRadius.pillAll,
                  ),
                  child: Text(
                    l10n.translate('Quên Gmail?'),
                    style: SLTheme.quicksand(
                      color: SLColors.primaryActive,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SLSpacing.h24,
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onRegister();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.pillAll,
                        ),
                      ),
                      child: Text(
                        l10n.translate('Đăng Ký Mới'),
                        style: SLTheme.quicksand(
                          color: SLColors.primaryActive,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onForgotPassword();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SLColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.pillAll,
                        ),
                      ),
                      child: Text(
                        l10n.translate('Quên Mật Khẩu'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
