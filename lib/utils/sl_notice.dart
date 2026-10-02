import 'package:flutter/material.dart';
import '../widgets/sl_dialog.dart';
import '../utils/services/l10n_service.dart';
import 'services/notification_service.dart';
import '../widgets/sl_toast.dart';

class SLNotice {
  /// Hiển thị thông báo dạng Snackbar cao cấp
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      variant: SLToastVariant.success,
    );
  }

  static void showError(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.error_rounded,
      variant: SLToastVariant.danger,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.info_rounded,
      variant: SLToastVariant.info,
    );
  }

  static String? _lastMessage;
  static DateTime? _lastMessageTime;

  static void _showToast(
    BuildContext context, {
    required String message,
    required IconData icon,
    required SLToastVariant variant,
  }) {
    final resolvedMessage = L10nService().translate(message);

    // Deduplicate: If the same message is shown within 2 seconds, ignore it to prevent spam
    final now = DateTime.now();
    if (_lastMessage == resolvedMessage &&
        _lastMessageTime != null &&
        now.difference(_lastMessageTime!).inSeconds < 2) {
      return;
    }

    _lastMessage = resolvedMessage;
    _lastMessageTime = now;

    try {
      SLToast.show(
        context,
        resolvedMessage,
        variant: variant,
        icon: icon,
        duration: const Duration(seconds: 4),
      );
    } catch (error) {
      debugPrint('[SuppressedError] lib/utils/sl_notice.dart: $error');
    }
  }

  /// Hiển thị Dialog cảnh báo/xác nhận cao cấp
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'confirm',
    String cancelText = 'cancel',
    bool isDanger = false,
    IconData? icon,
  }) {
    final l10n = L10nService();
    final resolvedTitle = l10n.translate(title);
    final resolvedMessage = l10n.translate(message);
    final resolvedConfirmText = l10n.translate(confirmText);
    final resolvedCancelText = l10n.translate(cancelText);

    BuildContext? dialogContext;
    final rootContext = NotificationService.navigatorKey.currentContext;
    if (rootContext != null) {
      dialogContext = rootContext;
    } else {
      try {
        if (Navigator.maybeOf(context) != null) {
          dialogContext = context;
        }
      } catch (_) {
        dialogContext = null;
      }
    }
    if (dialogContext == null) {
      return Future<bool?>.value(false);
    }

    return showDialog<bool>(
      context: dialogContext,
      builder: (context) => SLMessageDialog(
        title: resolvedTitle,
        message: resolvedMessage,
        confirmLabel: resolvedConfirmText,
        cancelLabel: resolvedCancelText,
        tone: isDanger ? SLDialogTone.danger : SLDialogTone.neutral,
        icon: icon,
      ),
    );
  }
}
