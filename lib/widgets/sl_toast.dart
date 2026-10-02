import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/services/l10n_service.dart';
import 'sl_feedback.dart';
import 'sl_dialog.dart';

/// Các variant của toast/snackbar theo ngữ nghĩa.
enum SLToastVariant {
  /// Thông báo thành công (xanh lá)
  success,

  /// Cảnh báo (vàng/cam)
  warning,

  /// Lỗi (đ�)
  danger,

  /// Thông tin (xanh dương)
  info,

  /// Mặc định (primary pink - thương hiệu)
  primary,
}

class SLToast {
  static OverlayEntry? _activeEntry;
  static VoidCallback? _dismissActiveEntry;

  static SLDialogTone _dialogTone(SLToastVariant variant) => switch (variant) {
    SLToastVariant.success => SLDialogTone.success,
    SLToastVariant.warning => SLDialogTone.warning,
    SLToastVariant.danger => SLDialogTone.danger,
    SLToastVariant.info => SLDialogTone.info,
    SLToastVariant.primary => SLDialogTone.neutral,
  };

  // ═══════════════════════════════════════════════════════════════════════
  // SNACKBAR — Thay thế Material SnackBar mặc định bằng UI đẹp hơn
  // ═══════════════════════════════════════════════════════════════════════

  /// Hiển thị thông báo gọn phía trên hoặc snackbar có hành động phía dưới.
  ///
  /// Example:
  /// ```dart
  /// SLToast.show(context, 'Đăng xuất thành công',
  ///     variant: SLToastVariant.success);
  /// ```
  static void show(
    BuildContext context,
    String message, {
    SLToastVariant variant = SLToastVariant.primary,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    if (!context.mounted || message.trim().isEmpty) return;

    final accent = switch (variant) {
      SLToastVariant.success => SLFeedbackStyle.success,
      SLToastVariant.warning => SLFeedbackStyle.warning,
      SLToastVariant.danger => SLFeedbackStyle.danger,
      SLToastVariant.info => SLFeedbackStyle.info,
      SLToastVariant.primary => SLFeedbackStyle.primary,
    };
    _dismissActiveEntry?.call();
    _activeEntry = null;
    _dismissActiveEntry = null;

    if (actionLabel != null && onAction != null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SLSnackBar(
              content: Text(message),
              backgroundColor: accent,
              icon: icon ?? SLFeedbackStyle.iconFor(accent),
              action: SnackBarAction(label: actionLabel, onPressed: onAction),
              duration: duration,
            ),
          );
        return;
      }
    }

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    var removed = false;
    void dismissEntry() {
      if (removed) return;
      removed = true;
      if (identical(_activeEntry, entry)) {
        _activeEntry = null;
        _dismissActiveEntry = null;
      }
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (ctx) => _SLToastEntry(
        message: message,
        title: title,
        accent: accent,
        actionLabel: actionLabel,
        onAction: () {
          try {
            onAction?.call();
          } finally {
            dismissEntry();
          }
        },
        onDismiss: dismissEntry,
        duration: duration,
        icon: icon,
      ),
    );
    var wasMounted = false;
    entry.addListener(() {
      if (entry.mounted) {
        wasMounted = true;
      } else if (wasMounted && !removed) {
        scheduleMicrotask(dismissEntry);
      }
    });
    _activeEntry = entry;
    _dismissActiveEntry = dismissEntry;
    overlay.insert(entry);
  }

  static void dismiss() => _dismissActiveEntry?.call();

  /// Shortcut cho success.
  static void success(BuildContext context, String message) =>
      show(context, message, variant: SLToastVariant.success);

  /// Shortcut cho error.
  static void error(BuildContext context, String message) =>
      show(context, message, variant: SLToastVariant.danger);

  /// Shortcut cho warning.
  static void warning(BuildContext context, String message) =>
      show(context, message, variant: SLToastVariant.warning);

  /// Shortcut cho info.
  static void info(BuildContext context, String message) =>
      show(context, message, variant: SLToastVariant.info);

  // ═══════════════════════════════════════════════════════════════════════
  // ALERT DIALOG — Thay thế AlertDialog mặc định
  // ═══════════════════════════════════════════════════════════════════════

  /// Hiển thị dialog đẹp với header gradient, icon tròn, nút hành động.
  ///
  /// Example:
  /// ```dart
  /// final ok = await SLToast.confirm(
  ///   context,
  ///   title: 'Đăng xuất?',
  ///   message: 'Bạn sẽ cần đăng nhập lại để tiếp tục.',
  ///   confirmLabel: 'Đăng xuất',
  ///   variant: SLToastVariant.warning,
  /// );
  /// ```
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    SLToastVariant variant = SLToastVariant.warning,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SLMessageDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel ?? L10nService().translate('toast_confirm'),
        cancelLabel: cancelLabel ?? L10nService().translate('toast_cancel'),
        tone: _dialogTone(variant),
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// Hiển thị alert đơn (1 nút OK).
  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    SLToastVariant variant = SLToastVariant.info,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => SLMessageDialog(
        title: title,
        message: message,
        confirmLabel: okLabel ?? L10nService().translate('toast_ok'),
        tone: _dialogTone(variant),
        icon: icon,
      ),
    ).then<void>((_) {});
  }
}

// ════════════════════════════════════════════════════════════════════════
// INTERNAL WIDGETS
// ════════════════════════════════════════════════════════════════════════

/// Toast entry — chạy slide-down animation + auto-dismiss.
class _SLToastEntry extends StatefulWidget {
  final String message;
  final String? title;
  final Color accent;
  final String? actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;
  final Duration duration;
  final IconData? icon;

  const _SLToastEntry({
    required this.message,
    required this.title,
    required this.accent,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
    required this.duration,
    required this.icon,
  });

  @override
  State<_SLToastEntry> createState() => _SLToastEntryState();
}

class _SLToastEntryState extends State<_SLToastEntry>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  var _isDismissing = false;
  var _hasStarted = false;
  var _hasActed = false;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _slide = Tween<double>(
    begin: -1.0,
    end: 0.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    if (!_hasStarted) {
      _hasStarted = true;
      _ctrl.forward();
    }
    _dismissTimer?.cancel();
    if (!MediaQuery.accessibleNavigationOf(context) && !_isDismissing) {
      _dismissTimer = Timer(widget.duration, _dismiss);
    }
  }

  Future<void> _dismiss() async {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    try {
      await _ctrl.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final title = widget.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final availableHeight =
        (media.size.height -
                media.padding.vertical -
                media.viewInsets.bottom -
                24)
            .clamp(1.0, double.infinity);

    return Positioned(
      top: media.padding.top + 12,
      left: media.padding.left + 16,
      right: media.padding.right + 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, 24 * _slide.value),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: SLFeedbackStyle.maxWidth,
                  maxHeight: availableHeight,
                ),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Material(
                    color: SLFeedbackStyle.surface,
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.24),
                    shape: SLFeedbackStyle.shape,
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          14,
                          10,
                          6,
                          10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SLFeedbackContent(
                                accent: widget.accent,
                                icon: widget.icon,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasTitle)
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    if (hasTitle) const SizedBox(height: 3),
                                    Text(
                                      widget.message,
                                      style: TextStyle(
                                        color: hasTitle
                                            ? SLFeedbackStyle.secondary
                                            : SLFeedbackStyle.foreground,
                                      ),
                                    ),
                                    if (widget.actionLabel != null)
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: TextButton(
                                          onPressed: () {
                                            if (_hasActed || _isDismissing) {
                                              return;
                                            }
                                            _hasActed = true;
                                            _dismissTimer?.cancel();
                                            widget.onAction();
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: widget.accent,
                                          ),
                                          child: Text(widget.actionLabel!),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              onPressed: _dismiss,
                              color: SLFeedbackStyle.secondary,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
