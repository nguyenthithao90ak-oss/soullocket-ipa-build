import 'package:flutter/material.dart';
import '../core/sl_theme.dart';
import '../services/l10n_service.dart';
import 'services/notification_service.dart';

class SLNotice {
  /// Hiển thị thông báo dạng Snackbar cao cấp
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: SLColors.success,
    );
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: SLColors.danger,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: SLColors.info,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    final messenger = _resolveMessenger(context);
    if (messenger == null) return;

    final resolvedMessage = L10nService().translate(message);
    try {
      messenger
        ..clearSnackBars()
        ..removeCurrentSnackBar()
        ..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              SLSpacing.w8,
              Expanded(
                child: Text(
                  resolvedMessage,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: SLRadius.lgAll,
          ),
          elevation: 8,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {}
  }

  static ScaffoldMessengerState? _resolveMessenger(BuildContext context) {
    final rootContext = NotificationService.navigatorKey.currentContext;
    if (rootContext != null) {
      try {
        final messenger = ScaffoldMessenger.maybeOf(rootContext);
        if (messenger != null) {
          return messenger;
        }
      } catch (_) {}
    }

    try {
      return ScaffoldMessenger.maybeOf(context);
    } catch (_) {
      return null;
    }
  }

  /// Hiển thị Dialog cảnh báo/xác nhận cao cấp
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy',
    bool isDanger = false,
  }) {
    final l10n = L10nService();
    final resolvedTitle = l10n.translate(title);
    final resolvedMessage = l10n.translate(message);
    final resolvedConfirmText = l10n.translate(confirmText);
    final resolvedCancelText = l10n.translate(cancelText);
    final accent = isDanger ? SLColors.danger : const Color(0xFFD81B60);

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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: SLSpacing.all8,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isDanger
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SLSpacing.w12,
            Expanded(
              child: Text(
                resolvedTitle.toUpperCase(),
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolvedMessage,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SLColors.textSecondary,
                  height: 1.5,
                ),
              ),
              SLSpacing.h24,
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.lgAll,
                          side: const BorderSide(color: SLColors.border),
                        ),
                      ),
                      child: Text(
                        resolvedCancelText,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          color: SLColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: SLTheme.primaryButton(
                      text: resolvedConfirmText,
                      onPressed: () => Navigator.pop(context, true),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
