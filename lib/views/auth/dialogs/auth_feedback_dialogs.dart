import 'package:flutter/material.dart';

import '../../../widgets/sl_dialog.dart';
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
    final navigator =
        NotificationService.navigatorKey.currentState ??
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
      builder: (dialogContext) => SLAlertDialog(
        title: SLDialogHeading(
          title: l10n.translate('dialog_success_title'),
          tone: SLDialogTone.success,
        ),
        content: Text(l10n.translate(message)),
        actions: [
          SLDialogAction(
            primary: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              navigateToTarget();
            },
            child: Text(l10n.translate('dialog_get_started')),
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
    final l10n = L10nService();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: SLDialogHeading(
          title: l10n.translate('dialog_account_not_found'),
          tone: SLDialogTone.info,
          icon: Icons.person_search_rounded,
        ),
        content: Text(l10n.translate(message)),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('dialog_retry')),
          ),
          SLDialogAction(
            primary: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onCreateNew();
            },
            child: Text(l10n.translate('dialog_create_account')),
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
    final l10n = L10nService();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: SLDialogHeading(
          title: l10n.translate('dialog_login_failed'),
          tone: SLDialogTone.warning,
          icon: Icons.lock_outline_rounded,
        ),
        content: Text(l10n.translate(message)),
        actions: [
          SLDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onForgotGmail();
            },
            child: Text(l10n.translate('dialog_recover_email')),
          ),
          SLDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRegister();
            },
            child: Text(l10n.translate('dialog_create_account')),
          ),
          SLDialogAction(
            primary: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onForgotPassword();
            },
            child: Text(l10n.translate('dialog_reset_password')),
          ),
        ],
      ),
    );
  }
}
