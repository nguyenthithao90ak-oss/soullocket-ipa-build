import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';

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
  /// Helper lấy palette màu theo variant (dùng cả cho snackbar & dialog).
  static _Palette _palette(SLToastVariant variant, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (variant) {
      case SLToastVariant.success:
        return _Palette(
          accent: isDark ? const Color(0xFF69F0AE) : const Color(0xFF00C853),
          accentSoft: isDark
              ? const Color(0xFF1B5E20)
              : const Color(0xFFE8F5E9),
          icon: Icons.check_circle_rounded,
          iconBg: const Color(0xFF00C853),
        );
      case SLToastVariant.warning:
        return _Palette(
          accent: isDark ? const Color(0xFFFFD740) : const Color(0xFFFFAB00),
          accentSoft: isDark
              ? const Color(0xFF5C4500)
              : const Color(0xFFFFF8E1),
          icon: Icons.warning_amber_rounded,
          iconBg: const Color(0xFFFFAB00),
        );
      case SLToastVariant.danger:
        return _Palette(
          accent: isDark ? const Color(0xFFFF6E6E) : const Color(0xFFFF5252),
          accentSoft: isDark
              ? const Color(0xFF5C0F0F)
              : const Color(0xFFFFEBEE),
          icon: Icons.error_rounded,
          iconBg: const Color(0xFFFF5252),
        );
      case SLToastVariant.info:
        return _Palette(
          accent: isDark ? const Color(0xFF82B1FF) : const Color(0xFF2979FF),
          accentSoft: isDark
              ? const Color(0xFF0D2D5C)
              : const Color(0xFFE3F2FD),
          icon: Icons.info_rounded,
          iconBg: const Color(0xFF2979FF),
        );
      case SLToastVariant.primary:
        return _Palette(
          accent: SLColors.primary,
          accentSoft: SLColors.primaryLight,
          icon: Icons.favorite_rounded,
          iconBg: SLColors.primary,
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SNACKBAR — Thay thế Material SnackBar mặc định bằng UI đẹp hơn
  // ═══════════════════════════════════════════════════════════════════════

  /// Hiển thị snackbar đ�p (top-positioned, glassmorphism, có icon + action).
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
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final media = MediaQuery.of(context);
    final palette = _palette(variant, Theme.of(context).brightness);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _SLToastEntry(
        message: message,
        variant: variant,
        palette: palette,
        actionLabel: actionLabel,
        onAction: () {
          onAction?.call();
          entry.remove();
        },
        duration: duration,
        topPadding: media.padding.top,
        icon: icon,
      ),
    );
    overlay.insert(entry);
  }

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
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, secondaryAnim) {
        final palette = _palette(variant, Theme.of(ctx).brightness);
        return _SLDialogShell(
          palette: palette,
          variant: variant,
          icon: icon,
          title: title,
          message: message,
          confirmLabel: confirmLabel ?? L10nService().translate('toast_confirm'),
          cancelLabel: cancelLabel ?? L10nService().translate('toast_cancel'),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(
              parent: anim, curve: Curves.easeOutCubic),
        );
        final fade = Tween<double>(begin: 0, end: 1).animate(anim);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
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
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, secondaryAnim) => _SLDialogShell(
        palette: _palette(variant, Theme.of(ctx).brightness),
        variant: variant,
        icon: icon,
        title: title,
        message: message,
        confirmLabel: okLabel ?? L10nService().translate('toast_ok'),
        cancelLabel: null,
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        );
        final fade = Tween<double>(begin: 0, end: 1).animate(anim);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// INTERNAL WIDGETS
// ════════════════════════════════════════════════════════════════════════

class _Palette {
  final Color accent;
  final Color accentSoft;
  final IconData icon;
  final Color iconBg;

  const _Palette({
    required this.accent,
    required this.accentSoft,
    required this.icon,
    required this.iconBg,
  });
}

/// Toast entry — chạy slide-down animation + auto-dismiss.
class _SLToastEntry extends StatefulWidget {
  final String message;
  final SLToastVariant variant;
  final _Palette palette;
  final String? actionLabel;
  final VoidCallback onAction;
  final Duration duration;
  final double topPadding;
  final IconData? icon;

  const _SLToastEntry({
    required this.message,
    required this.variant,
    required this.palette,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.topPadding,
    required this.icon,
  });

  @override
  State<_SLToastEntry> createState() => _SLToastEntryState();
}

class _SLToastEntryState extends State<_SLToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _slide =
      Tween<double>(begin: -1.0, end: 0.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _fade = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) {
      (context.findAncestorStateOfType<_SLToastEntryState>())?.mounted;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final iconData = widget.icon ?? widget.palette.icon;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final slideValue = _slide.value;
          final fadeValue = _fade.value;
          return Opacity(
            opacity: fadeValue,
            child: Transform.translate(
              offset: Offset(0, -80 + (-80 * -slideValue)),
              child: Padding(
                padding: EdgeInsets.only(
                  top: widget.topPadding + 12,
                  left: 16,
                  right: 16,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.palette.accent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  widget.palette.accent.withValues(alpha: 0.18),
                              blurRadius: 24,
                              spreadRadius: -2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icon tròn có glow
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: widget.palette.iconBg
                                    .withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.palette.iconBg
                                      .withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                iconData,
                                size: 22,
                                color: widget.palette.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Message
                            Expanded(
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.95)
                                      : SLColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            // Action button
                            if (widget.actionLabel != null)
                              TextButton(
                                onPressed: widget.onAction,
                                style: TextButton.styleFrom(
                                  foregroundColor: widget.palette.accent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            // Close button
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : SLColors.textTertiary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: _dismiss,
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
      );
    },
  ),
);
  }
}

/// Dialog shell — header gradient + icon + body + actions.
class _SLDialogShell extends StatefulWidget {
  final _Palette palette;
  final SLToastVariant variant;
  final IconData? icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;

  const _SLDialogShell({
    required this.palette,
    required this.variant,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  @override
  State<_SLDialogShell> createState() => _SLDialogShellState();
}

class _SLDialogShellState extends State<_SLDialogShell> {
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final iconData = widget.icon ?? widget.palette.icon;
    final isDanger = widget.variant == SLToastVariant.danger;
    final isWarning = widget.variant == SLToastVariant.warning;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A3A).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: widget.palette.accent.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            widget.palette.accent.withValues(alpha: 0.18),
                        blurRadius: 32,
                        spreadRadius: -4,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Header gradient với icon ─────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.palette.accent.withValues(alpha: 0.18),
                              widget.palette.accent.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Icon tròn lớn có glow
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.palette.iconBg,
                                    widget.palette.iconBg
                                        .withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.palette.iconBg
                                        .withValues(alpha: 0.45),
                                    blurRadius: 22,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                iconData,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : SLColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.2,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Body message ─────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.78)
                                : SLColors.textSecond,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                      ),

                      // ─── Actions ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        child: widget.cancelLabel != null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _SecondaryButton(
                                      label: widget.cancelLabel!,
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PrimaryButton(
                                      label: widget.confirmLabel,
                                      color: widget.palette.accent,
                                      isLoading: _isConfirming,
                                      onPressed: () async {
                                        setState(() => _isConfirming = true);
                                        Navigator.of(context).pop(true);
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: _PrimaryButton(
                                  label: widget.confirmLabel,
                                  color: widget.palette.accent,
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                ),
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
    );
  }
}

/// Nút hành động chính (gradient + shadow theo màu accent).
class _PrimaryButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withValues(alpha: 0.78)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.40),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Nút phụ (outline + background tint theo màu accent).
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : SLColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
