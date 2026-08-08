import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import '../core/sl_theme.dart';

class LegacyWebUi {
  static const Color accentPink = SLColors.primary;
  static const Color accentRose = SLColors.accentPink;
  static const Color accentPeach = Color(0xFFF2D1C5);
  static const Color accentBlue = SLColors.secondary;
  static const Color accentGold = Color(0xFFE1B968);

  static BorderRadius avatarBorderRadiusForKey(String frameKey, double size) {
    if (frameKey.startsWith('sticker_')) {
      return BorderRadius.circular(size * 0.16);
    }
    switch (frameKey) {
      case 'rounded':
        return BorderRadius.circular(size * 0.36);
      case 'squircle':
        return BorderRadius.circular(size * 0.40);
      case 'glass':
        return BorderRadius.circular(size * 0.38);
      case 'vip':
        return BorderRadius.circular(size * 0.42);
      default:
        return BorderRadius.circular(size / 2);
    }
  }

  static bool avatarFrameIsCircle(String frameKey) {
    if (frameKey.startsWith('sticker_')) {
      return false;
    }
    switch (frameKey) {
      case 'rounded':
      case 'squircle':
      case 'glass':
      case 'vip':
        return false;
      default:
        return true;
    }
  }

  static EdgeInsets avatarFramePaddingForKey(String frameKey, double size) {
    final base = (size * 0.06).clamp(4.0, 7.0).toDouble();
    if (frameKey.startsWith('sticker_')) {
      return EdgeInsets.all((base * 0.5).clamp(2.0, 3.5).toDouble());
    }
    switch (frameKey) {
      case 'off':
        return EdgeInsets.zero;
      case 'rounded':
        return EdgeInsets.all((base + 0.8).clamp(4.8, 7.8).toDouble());
      case 'squircle':
        return EdgeInsets.all((base + 1.0).clamp(5.0, 8.0).toDouble());
      case 'pearl':
        return EdgeInsets.all((base + 1).clamp(5.0, 8.0).toDouble());
      case 'glass':
        return EdgeInsets.all((base + 0.5).clamp(4.5, 7.5).toDouble());
      case 'vip':
        return EdgeInsets.all((base + 1.2).clamp(5.4, 8.4).toDouble());
      default:
        return EdgeInsets.all(base);
    }
  }

  static BoxDecoration avatarFrameDecoration(
    String frameKey,
    double size, {
    Color accentColor = accentPink,
  }) {
    final isCircle = avatarFrameIsCircle(frameKey);
    final blur = (size * 0.22).clamp(12.0, 24.0).toDouble();
    final yOffset = (size * 0.09).clamp(4.0, 9.0).toDouble();
    final radius = isCircle ? null : avatarBorderRadiusForKey(frameKey, size);

    BoxDecoration build({
      Color? color,
      Gradient? gradient,
      required BoxBorder border,
      required List<BoxShadow> boxShadow,
    }) {
      return BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius,
        color: color,
        gradient: gradient,
        border: border,
        boxShadow: boxShadow,
      );
    }

    switch (frameKey) {
      case 'off':
        return BoxDecoration(
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: radius,
        );
      case 'rounded':
        return build(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBFD), Color(0xFFFFE4EE), Color(0xFFFCE8DE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFFFB7CB), width: 2.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8F9F).withValues(alpha: 0.20),
              blurRadius: blur * 0.92,
              offset: Offset(0, yOffset),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.72),
              blurRadius: 1.4,
              spreadRadius: 0.6,
              blurStyle: BlurStyle.inner,
            ),
          ],
        );
      case 'squircle':
        return build(
          gradient: const LinearGradient(
            colors: [Color(0xFFF7E9FF), Color(0xFFD6D0FF), Color(0xFFADD7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFF8F6FF), width: 2.3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9D9CFF).withValues(alpha: 0.20),
              blurRadius: blur * 0.88,
              offset: Offset(0, yOffset),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.62),
              blurRadius: 1.2,
              spreadRadius: 0.5,
              blurStyle: BlurStyle.inner,
            ),
          ],
        );
      case 'pearl':
        return build(
          gradient: const RadialGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFEDF4), Color(0xFFFFC2D4)],
            center: Alignment.topLeft,
            radius: 1.1,
          ),
          border: Border.all(color: const Color(0xFFFFFAFC), width: 2.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF93B8).withValues(alpha: 0.18),
              blurRadius: blur * 0.84,
              offset: Offset(0, yOffset),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.82),
              blurRadius: 1.4,
              spreadRadius: 0.8,
              blurStyle: BlurStyle.inner,
            ),
          ],
        );
      case 'glass':
        return build(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.96),
              const Color(0xFFE9F7FF).withValues(alpha: 0.88),
              const Color(0xFFF1ECFF).withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.92), width: 2.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8DCDFD).withValues(alpha: 0.20),
              blurRadius: blur * 0.86,
              offset: Offset(0, yOffset),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.09),
              blurRadius: 1.4,
              spreadRadius: 0.7,
              blurStyle: BlurStyle.inner,
            ),
          ],
        );
      case 'vip':
        return build(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7CC), Color(0xFFFFD966), Color(0xFFFFA92D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFFFF8DE), width: 2.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFBC42).withValues(alpha: 0.26),
              blurRadius: blur,
              offset: Offset(0, yOffset),
            ),
          ],
        );
      default:
        return build(
          color: Colors.white,
          border: Border.all(
            color: Color.lerp(accentColor, Colors.white, 0.52) ??
                const Color(0xFFFFB7CF),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.22),
              blurRadius: blur,
              offset: Offset(0, yOffset),
            ),
          ],
        );
    }
  }

  static BoxDecoration softPanelDecoration({
    required Color accent,
    double radius = 28,
    List<Color>? colors,
  }) {
    final palette = colors ??
        [
          SLColors.bgElevated.withValues(alpha: 0.98),
          Color.lerp(accent, SLColors.bgElevated, 0.92) ?? SLColors.bgElevated,
          SLColors.bgCard.withValues(alpha: 0.96),
        ];
    return BoxDecoration(
      gradient: LinearGradient(
        colors: palette,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.72),
          blurRadius: 1,
          spreadRadius: 1,
          blurStyle: BlurStyle.inner,
        ),
      ],
    );
  }

  static InputDecoration softInputDecoration({
    required String hintText,
    Color accent = accentPink,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: SLTheme.quicksand(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: SLColors.textTertiary,
      ),
      border: OutlineInputBorder(
        borderRadius: SLRadius.xlAll,
        borderSide:
            BorderSide(color: accent.withValues(alpha: 0.18), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: SLRadius.xlAll,
        borderSide:
            BorderSide(color: accent.withValues(alpha: 0.16), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: SLRadius.xlAll,
        borderSide:
            BorderSide(color: accent.withValues(alpha: 0.70), width: 1.8),
      ),
      filled: true,
      fillColor: SLColors.bgElevated.withValues(alpha: 0.96),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      isDense: true,
    );
  }

  static void showNotice(
    BuildContext context, {
    required String message,
    bool success = true,
    String? title,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final notice =
        _resolveNoticeStyleV2(message, success, title: title, icon: icon);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          padding: EdgeInsets.zero,
          duration: Duration(seconds: success ? 3 : 4),
          content: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: softPanelDecoration(
              accent: notice.borderColor,
              radius: 24,
              colors: notice.gradient,
            ).copyWith(
              border:
                  Border.all(color: notice.borderColor.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        notice.iconTint.withValues(alpha: 0.16),
                        Colors.white
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                        color: notice.iconTint.withValues(alpha: 0.14)),
                  ),
                  child: Icon(notice.icon, color: notice.iconTint, size: 20),
                ),
                SLSpacing.w10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notice.title,
                        style: SLTheme.quicksand(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: notice.titleColor,
                        ),
                      ),
                      SLSpacing.gapH(2),
                      Text(
                        message,
                        style: SLTheme.quicksand(
                          fontSize: 12.4,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: notice.bodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static void showNoticeWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    bool success = true,
    String? title,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final notice =
        _resolveNoticeStyleV2(message, success, title: title, icon: icon);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          padding: EdgeInsets.zero,
          duration: Duration(seconds: success ? 3 : 8),
          content: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: softPanelDecoration(
              accent: notice.borderColor,
              radius: 24,
              colors: notice.gradient,
            ).copyWith(
              border:
                  Border.all(color: notice.borderColor.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        notice.iconTint.withValues(alpha: 0.16),
                        Colors.white
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                        color: notice.iconTint.withValues(alpha: 0.14)),
                  ),
                  child: Icon(notice.icon, color: notice.iconTint, size: 20),
                ),
                SLSpacing.w10,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notice.title,
                        style: SLTheme.quicksand(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: notice.titleColor,
                        ),
                      ),
                      SLSpacing.gapH(2),
                      Text(
                        message,
                        style: SLTheme.quicksand(
                          fontSize: 12.4,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: notice.bodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SLSpacing.w8,
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    foregroundColor: notice.iconTint,
                    textStyle: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.pillAll,
                      side: BorderSide(
                          color: notice.iconTint.withValues(alpha: 0.28)),
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      );
  }

  // ignore: unused_element
  static _LegacyNoticeStyle _resolveNotice(
    String message,
    bool success, {
    String? title,
    IconData? icon,
  }) {
    final lower = message.toLowerCase();
    final isAccount = lower.contains('email') ||
        lower.contains('tài khoản') ||
        lower.contains('google') ||
        lower.contains('xác thực');
    final isSecurity = lower.contains('bảo mật') ||
        lower.contains('mật mã') ||
        lower.contains('khóa');
    final isSave = lower.contains('lưu') ||
        lower.contains('cập nhật') ||
        lower.contains('đồng bộ');

    if (isAccount) {
      return _LegacyNoticeStyle(
        title: title ??
            (success
                ? L10nService().translate('legacy_account_status')
                : L10nService().translate('legacy_account_check_needed')),
        icon: icon ?? Icons.manage_accounts_rounded,
        iconTint: const Color(0xFF7C4DFF),
        borderColor: const Color(0xFFB39DDB),
        gradient: const [
          Color(0xFFFFFBFF),
          Color(0xFFF4EEFF),
          Color(0xFFFFFFFF)
        ],
        titleColor: const Color(0xFF5B35B1),
        bodyColor: const Color(0xFF564A74),
      );
    }

    if (isSecurity) {
      return _LegacyNoticeStyle(
        title: title ??
            (success
                ? L10nService().translate('legacy_security_updated')
                : L10nService().translate('legacy_security_warning')),
        icon: icon ?? Icons.verified_user_rounded,
        iconTint: const Color(0xFFEF6C00),
        borderColor: const Color(0xFFFFCC80),
        gradient: const [
          Color(0xFFFFFCF7),
          Color(0xFFFFF1E4),
          Color(0xFFFFFFFF)
        ],
        titleColor: const Color(0xFFB05A00),
        bodyColor: const Color(0xFF755236),
      );
    }

    if (isSave) {
      return _LegacyNoticeStyle(
        title: title ??
            (success
                ? L10nService().translate('legacy_saved_success')
                : L10nService().translate('legacy_save_failed')),
        icon: icon ??
            (success ? Icons.auto_awesome_rounded : Icons.warning_rounded),
        iconTint: success ? const Color(0xFFD81B60) : const Color(0xFFE53935),
        borderColor:
            success ? const Color(0xFFF48FB1) : const Color(0xFFEF9A9A),
        gradient: success
            ? const [Color(0xFFFFFBFD), Color(0xFFFFEEF5), Color(0xFFFFFFFF)]
            : const [Color(0xFFFFF7F7), Color(0xFFFFEBEE), Color(0xFFFFFFFF)],
        titleColor: success ? const Color(0xFFB01457) : const Color(0xFFC62828),
        bodyColor: success ? const Color(0xFF6D4C57) : const Color(0xFF7A4D4D),
      );
    }

    return _LegacyNoticeStyle(
      title: title ??
          (success
              ? L10nService().translate('legacy_action_done')
              : L10nService().translate('legacy_error_occurred')),
      icon:
          icon ?? (success ? Icons.check_circle_rounded : Icons.error_rounded),
      iconTint: success ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
      borderColor: success ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
      gradient: success
          ? const [Color(0xFFF9FFF9), Color(0xFFF0FFF4), Color(0xFFFFFFFF)]
          : const [Color(0xFFFFF7F7), Color(0xFFFFEBEE), Color(0xFFFFFFFF)],
      titleColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      bodyColor: success ? const Color(0xFF48624C) : const Color(0xFF7A4D4D),
    );
  }
}

_LegacyNoticeStyle _resolveNoticeStyleV2(
  String message,
  bool success, {
  String? title,
  IconData? icon,
}) {
  final lower = message.toLowerCase();
  final isAccount = lower.contains('email') ||
      lower.contains('tài khoản') ||
      lower.contains('google') ||
      lower.contains('xác thực');
  final isSecurity = lower.contains('bảo mật') ||
      lower.contains('mật mã') ||
      lower.contains('khóa') ||
      lower.contains('pin');
  final isSave = lower.contains('lưu') ||
      lower.contains('cập nhật') ||
      lower.contains('đồng bộ');

  if (isAccount) {
    return _LegacyNoticeStyle(
      title: title ??
          (success
              ? L10nService().translate('legacy_account_status')
              : L10nService().translate('legacy_account_check_needed')),
      icon: icon ?? Icons.manage_accounts_rounded,
      iconTint: SLColors.accentPurpleDark,
      borderColor: SLColors.accentPurple,
      gradient: const [
        Color(0xFFFFFBFF),
        SLColors.tertiarySoft,
        Color(0xFFFFFFFF),
      ],
      titleColor: const Color(0xFF5A4D8A),
      bodyColor: SLColors.textSecond,
    );
  }

  if (isSecurity) {
    return _LegacyNoticeStyle(
      title: title ??
          (success
              ? L10nService().translate('legacy_security_updated')
              : L10nService().translate('legacy_security_warning')),
      icon: icon ?? Icons.verified_user_rounded,
      iconTint: const Color(0xFFBF7A17),
      borderColor: const Color(0xFFE9C98C),
      gradient: const [
        Color(0xFFFFFCF7),
        Color(0xFFFFF2DE),
        Color(0xFFFFFFFF),
      ],
      titleColor: const Color(0xFF935F14),
      bodyColor: const Color(0xFF7D5C38),
    );
  }

  if (isSave) {
    return _LegacyNoticeStyle(
      title: title ??
          (success
              ? L10nService().translate('legacy_saved_success')
              : L10nService().translate('legacy_save_failed')),
      icon: icon ??
          (success ? Icons.auto_awesome_rounded : Icons.warning_rounded),
      iconTint: success ? const Color(0xFF2E7D32) : SLColors.danger,
      borderColor: success ? const Color(0xFFA5D6A7) : const Color(0xFFF2C5C5),
      gradient: success
          ? const [
              Color(0xFFF9FFF9),
              Color(0xFFF0FFF4),
              Color(0xFFFFFFFF),
            ]
          : const [
              Color(0xFFFFF7F7),
              Color(0xFFFFEBEE),
              Color(0xFFFFFFFF),
            ],
      titleColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      bodyColor: success ? SLColors.textSecond : const Color(0xFF7A4D4D),
    );
  }

  return _LegacyNoticeStyle(
    title: title ??
        (success
            ? L10nService().translate('legacy_action_done')
            : L10nService().translate('legacy_error_occurred')),
    icon: icon ?? (success ? Icons.check_circle_rounded : Icons.error_rounded),
    iconTint: success ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
    borderColor: success ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
    gradient: success
        ? const [Color(0xFFF9FFF9), Color(0xFFF0FFF4), Color(0xFFFFFFFF)]
        : const [Color(0xFFFFF7F7), Color(0xFFFFEBEE), Color(0xFFFFFFFF)],
    titleColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
    bodyColor: success ? const Color(0xFF48624C) : const Color(0xFF7A4D4D),
  );
}

class SlAnimatedVipFrame extends StatefulWidget {
  const SlAnimatedVipFrame({
    super.key,
    required this.size,
    required this.padding,
    required this.child,
    required this.isCircle,
    this.borderRadius,
  });

  final double size;
  final EdgeInsets padding;
  final Widget child;
  final bool isCircle;
  final BorderRadius? borderRadius;

  @override
  State<SlAnimatedVipFrame> createState() => _SlAnimatedVipFrameState();
}

class _SlAnimatedVipFrameState extends State<SlAnimatedVipFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.isCircle
        ? null
        : (widget.borderRadius ?? BorderRadius.circular(widget.size * 0.40));
    final orbitRadius = widget.size * 0.33;
    final orbitDot = (widget.size * 0.14).clamp(5.0, 12.0).toDouble();
    final ringBorder = (widget.size * 0.028).clamp(1.4, 2.6).toDouble();

    Widget buildDot({
      required Offset center,
      required double scale,
      required List<Color> colors,
    }) {
      return Positioned(
        left: (widget.size / 2) + center.dx - (orbitDot * scale / 2),
        top: (widget.size / 2) + center.dy - (orbitDot * scale / 2),
        child: IgnorePointer(
          child: Container(
            width: orbitDot * scale,
            height: orbitDot * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.26),
                  blurRadius: orbitDot * 0.9,
                  spreadRadius: 0.2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * math.pi * 2;
        final pulse = 0.985 + (math.sin(angle * 2) * 0.018);
        final primaryDot = Offset(
          math.cos(angle) * orbitRadius,
          math.sin(angle) * orbitRadius,
        );
        final secondaryDot = Offset(
          math.cos(angle + 2.2) * orbitRadius * 0.94,
          math.sin(angle + 2.2) * orbitRadius * 0.94,
        );
        final tertiaryDot = Offset(
          math.cos(angle + 4.3) * orbitRadius * 0.88,
          math.sin(angle + 4.3) * orbitRadius * 0.88,
        );

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: shape,
                    borderRadius: radius,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFFFF8D9),
                        Color(0xFFFFE38A),
                        Color(0xFFFFBF46),
                        Color(0xFFFFEAB2),
                        Color(0xFFFFF8D9),
                      ],
                      stops: const [0.0, 0.22, 0.52, 0.82, 1.0],
                      transform: GradientRotation(angle * 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC44D).withValues(alpha: 0.26),
                        blurRadius: widget.size * 0.18,
                        offset: Offset(0, widget.size * 0.08),
                      ),
                    ],
                  ),
                  child: const SizedBox.expand(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: shape,
                        borderRadius: radius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.62),
                          width: ringBorder,
                        ),
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 1.0],
                          center: const Alignment(-0.25, -0.35),
                          radius: 0.96,
                        ),
                      ),
                    ),
                  ),
                ),
                buildDot(
                  center: primaryDot,
                  scale: 1.0,
                  colors: const [Color(0xFFFFF7D6), Color(0xFFFFD86B)],
                ),
                buildDot(
                  center: secondaryDot,
                  scale: 0.78,
                  colors: const [Color(0xFFFFF5CD), Color(0xFFFFB946)],
                ),
                buildDot(
                  center: tertiaryDot,
                  scale: 0.62,
                  colors: const [Color(0xFFFFFFFF), Color(0xFFFFE7A3)],
                ),
                Padding(
                  padding: widget.padding,
                  child: widget.isCircle
                      ? ClipOval(child: widget.child)
                      : ClipRRect(
                          borderRadius: radius!,
                          child: widget.child,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegacyNoticeStyle {
  final String title;
  final IconData icon;
  final Color iconTint;
  final Color borderColor;
  final List<Color> gradient;
  final Color titleColor;
  final Color bodyColor;

  const _LegacyNoticeStyle({
    required this.title,
    required this.icon,
    required this.iconTint,
    required this.borderColor,
    required this.gradient,
    required this.titleColor,
    required this.bodyColor,
  });
}

class SlAvatarFrame extends StatelessWidget {
  final String frameKey;
  final double size;
  final Color accentColor;
  final Widget child;
  final bool isUser1;

  const SlAvatarFrame({
    super.key,
    required this.frameKey,
    required this.size,
    required this.accentColor,
    required this.child,
    this.isUser1 = true,
  });

  @override
  Widget build(BuildContext context) {
    final framePadding = LegacyWebUi.avatarFramePaddingForKey(frameKey, size);
    final frameRadius = LegacyWebUi.avatarBorderRadiusForKey(frameKey, size);
    final frameIsCircle = LegacyWebUi.avatarFrameIsCircle(frameKey);

    // Tính toán inner border radius để ôm concentric hoàn hảo
    final double rawRadius =
        LegacyWebUi.avatarBorderRadiusForKey(frameKey, size).bottomRight.x;
    final double rawPadding = framePadding.top;
    final innerRadius = frameIsCircle
        ? null
        : BorderRadius.circular((rawRadius - rawPadding).clamp(2.0, size));

    final clippedAvatar = frameIsCircle
        ? ClipOval(child: child)
        : ClipRRect(
            borderRadius: innerRadius ?? frameRadius,
            child: child,
          );

    final mainFrame = frameKey == 'vip'
        ? SlAnimatedVipFrame(
            size: size,
            padding: framePadding,
            isCircle: frameIsCircle,
            borderRadius: frameRadius,
            child: child,
          )
        : Container(
            width: size,
            height: size,
            decoration: LegacyWebUi.avatarFrameDecoration(
              frameKey,
              size,
              accentColor: accentColor,
            ),
            child: Padding(
              padding: framePadding,
              child: clippedAvatar,
            ),
          );

    if (frameKey == 'off') {
      return mainFrame;
    }

    final List<Widget> decorations = [];

    switch (frameKey) {
      case 'rounded':
        decorations.addAll([
          Positioned(
            top: -size * 0.08,
            right: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            left: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
        ]);
        break;
      case 'squircle':
        decorations.addAll([
          Positioned(
            top: -size * 0.08,
            left: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            right: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
        ]);
        break;
      case 'pearl':
        decorations.addAll([
          Positioned(
            top: -size * 0.08,
            right: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            left: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
        ]);
        break;
      case 'glass':
        decorations.addAll([
          Positioned(
            top: -size * 0.08,
            left: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            right: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.35,
              height: size * 0.35,
              fit: BoxFit.contain,
            ),
          ),
        ]);
        break;
      case 'vip':
        decorations.addAll([
          Positioned(
            top: -size * 0.22,
            left: 0,
            right: 0,
            child: Center(
              child: R2StickerImage(
                'assets/images/anhtomau_stickers/sticker_1.gif',
                width: size * 0.45,
                height: size * 0.45,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            left: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.3,
              height: size * 0.3,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            right: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.3,
              height: size * 0.3,
              fit: BoxFit.contain,
            ),
          ),
        ]);
        break;
      case 'circle':
      default:
        decorations.addAll([
          Positioned(
            top: -size * 0.08,
            left: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.32,
              height: size * 0.32,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: -size * 0.08,
            right: -size * 0.08,
            child: R2StickerImage(
              'assets/images/anhtomau_stickers/sticker_1.gif',
              width: size * 0.32,
              height: size * 0.32,
              fit: BoxFit.contain,
            ),
          ),
        ]);
        break;
    }

    if (frameKey.startsWith('sticker_')) {
      decorations.add(
        Positioned(
          bottom: -size * 0.1,
          right: -size * 0.15,
          child: R2StickerImage(
            'assets/images/anhtomau_stickers/sticker_1.gif',
            width: size * 0.65,
            height: size * 0.65,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        mainFrame,
        ...decorations,
      ],
    );
  }
}

