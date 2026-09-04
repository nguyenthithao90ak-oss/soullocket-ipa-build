import 'package:flutter/material.dart';
import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';
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

  static String? _lastMessage;
  static DateTime? _lastMessageTime;

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    final messenger = _resolveMessenger(context);
    if (messenger == null) return;

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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final horizontalMargin = viewportWidth > 552
        ? (viewportWidth - 520) / 2
        : 16.0;

    try {
      messenger
        ..clearSnackBars()
        ..removeCurrentSnackBar()
        ..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: 24,
            left: horizontalMargin,
            right: horizontalMargin,
          ),
          duration: const Duration(seconds: 4),
          content: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: SLColors.paper,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: backgroundColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: backgroundColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: backgroundColor, size: 22),
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Text(
                      resolvedMessage,
                      style: SLTheme.quicksand(
                        color: SLColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    String confirmText = 'confirm',
    String cancelText = 'cancel',
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
        backgroundColor: SLColors.paper,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 480),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                    color: accent.withValues(alpha: 0.24),
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
                resolvedTitle,
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
