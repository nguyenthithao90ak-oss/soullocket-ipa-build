import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/theme/sl_shadows.dart';
import 'package:soullocket_app/core/theme/sl_motion.dart';
import 'package:soullocket_app/core/theme/sl_colors.dart';
import '../sl_theme.dart' hide SLColors, SLShadow;

class SLHeroPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color> colors;

  const SLHeroPrimaryButton({super.key, 
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.colors,
  });

  @override
  State<SLHeroPrimaryButton> createState() => SLHeroPrimaryButtonState();
}

class SLHeroPrimaryButtonState extends State<SLHeroPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scaleAnim =
      Tween<double>(begin: 1.0, end: 0.95).animate(
    CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _animCtrl.forward(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _animCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => _animCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: isDisabled ? 0.65 : 1.0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDisabled
                    ? [const Color(0xFFF5D6E0), const Color(0xFFE8C1CD)]
                    : widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: widget.colors.first
                            .withValues(alpha: 0.4), // Glow shadow
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                child: widget.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.label,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 1.2,
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

class SLGlassmorphism {
  static Widget apply({
    required Widget child,
    double blur = 24.0,
    double opacity = 0.65,
    BorderRadius? borderRadius,
    Color? color,
    BoxBorder? border,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? SLColors.bgElevated.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.0,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Aurora Soft UI Components ──────────────────────────────────────────────
// Component library mới cho Aurora Soft redesign.
// Tất cả component dùng SLColors.aurora* cho primary variant.

/// Button variants cho Aurora Soft design system.
enum SLButtonVariant {
  /// Primary action — Aurora gradient với glow shadow
  primary,

  /// Secondary action — Glass white với border
  secondary,

  /// Tertiary action — Transparent với primary text
  ghost,

  /// Destructive action — Solid red gradient
  destructive,

  /// Premium action — Gold gradient với extra glow
  premium,
}

/// Button sizes cho Aurora Soft design system.
enum SLButtonSize {
  small,  // 32px height
  medium, // 40px height
  large,  // 48px height
  xl,     // 56px height
}

/// Aurora Soft button với gradient variants và press animation.
/// Sử dụng SLMotion.pressDuration cho feedback.
class SLButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final SLButtonVariant variant;
  final SLButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const SLButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SLButtonVariant.primary,
    this.size = SLButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  State<SLButton> createState() => _SLButtonState();
}

class _SLButtonState extends State<SLButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: SLMotion.pressDuration,
  );

  late final Animation<double> _scaleAnim = Tween<double>(
    begin: SLMotion.pressScaleBegin,
    end: SLMotion.pressScaleEnd,
  ).animate(
    CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
  );

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  double get _height {
    switch (widget.size) {
      case SLButtonSize.small:
        return 32.0;
      case SLButtonSize.medium:
        return 40.0;
      case SLButtonSize.large:
        return 48.0;
      case SLButtonSize.xl:
        return 56.0;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case SLButtonSize.small:
        return 12.0;
      case SLButtonSize.medium:
        return 14.0;
      case SLButtonSize.large:
        return 16.0;
      case SLButtonSize.xl:
        return 17.0;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case SLButtonSize.small:
        return 14.0;
      case SLButtonSize.medium:
        return 16.0;
      case SLButtonSize.large:
        return 18.0;
      case SLButtonSize.xl:
        return 20.0;
    }
  }

  BorderRadius get _borderRadius => BorderRadius.circular(
        widget.size == SLButtonSize.small ? 16.0 : 24.0,
      );

  BoxDecoration _buildDecoration() {
    final isDisabled = _isDisabled;

    switch (widget.variant) {
      case SLButtonVariant.primary:
        return BoxDecoration(
          gradient: isDisabled
              ? LinearGradient(
                  colors: [
                    SLColors.auroraRoseMid.withValues(alpha: 0.6),
                    SLColors.auroraLavender.withValues(alpha: 0.6),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    SLColors.auroraRoseDeep,
                    SLColors.auroraLavender,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: _borderRadius,
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: SLColors.auroraRoseDeep.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
        );

      case SLButtonVariant.secondary:
        return BoxDecoration(
          color: isDisabled
              ? SLColors.bgElevated.withValues(alpha: 0.5)
              : SLColors.bgElevated.withValues(alpha: 0.85),
          borderRadius: _borderRadius,
          border: Border.all(
            color: isDisabled
                ? SLColors.slate200
                : SLColors.auroraRoseMid.withValues(alpha: 0.5),
            width: 1.2,
          ),
        );

      case SLButtonVariant.ghost:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: _borderRadius,
        );

      case SLButtonVariant.destructive:
        return BoxDecoration(
          gradient: isDisabled
              ? LinearGradient(
                  colors: [
                    SLColors.danger.withValues(alpha: 0.5),
                    SLColors.danger.withValues(alpha: 0.4),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    SLColors.danger,
                    Color(0xFFE53935),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: _borderRadius,
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: SLColors.danger.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
        );

      case SLButtonVariant.premium:
        return BoxDecoration(
          gradient: isDisabled
              ? LinearGradient(
                  colors: [
                    SLColors.auroraGold.withValues(alpha: 0.5),
                    SLColors.auroraGoldDeep.withValues(alpha: 0.4),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFFFFD54F),
                    SLColors.auroraGold,
                    SLColors.auroraGoldDeep,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: _borderRadius,
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: SLColors.auroraGold.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
        );
    }
  }

  Color get _textColor {
    switch (widget.variant) {
      case SLButtonVariant.primary:
      case SLButtonVariant.destructive:
      case SLButtonVariant.premium:
        return Colors.white;
      case SLButtonVariant.secondary:
      case SLButtonVariant.ghost:
        return _isDisabled
            ? SLColors.slate400
            : SLColors.auroraRoseDeep;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => _animCtrl.forward(),
      onTapUp: _isDisabled
          ? null
          : (_) {
              _animCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: _isDisabled ? null : () => _animCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: _isDisabled ? 0.65 : 1.0,
          child: Container(
            width: widget.width,
            height: _height,
            padding: EdgeInsets.symmetric(
              horizontal: widget.size == SLButtonSize.small ? 12.0 : 20.0,
            ),
            decoration: _buildDecoration(),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: _iconSize,
                        height: _iconSize,
                        child: CircularProgressIndicator(
                          color: _textColor,
                          strokeWidth: 2.0,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: _textColor,
                              size: _iconSize,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: _fontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card variants cho Aurora Soft design system.
enum SLCardVariant {
  /// Glass card — FastBackdropFilter blur(24) + translucent white
  glass,

  /// Elevated card — White background + soft shadow
  elevated,

  /// Outlined card — White với border 1px slate200
  outlined,

  /// Filled card — Solid color background
  filled,

  /// Hero card — Image background với overlay
  hero,
}

/// Aurora Soft card với 5 variants và optional onTap.
class SLCard extends StatelessWidget {
  final Widget child;
  final SLCardVariant variant;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final DecorationImage? image;

  const SLCard({
    super.key,
    required this.child,
    this.variant = SLCardVariant.glass,
    this.padding,
    this.margin,
    this.radius = 20.0,
    this.onTap,
    this.color,
    this.borderColor,
    this.boxShadow,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    Widget card;

    switch (variant) {
      case SLCardVariant.glass:
        card = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: FastBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color ?? SLColors.bgElevated.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: borderColor ??
                      Colors.white.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: boxShadow ??
                    [
                      BoxShadow(
                        color: SLColors.auroraRoseDeep.withValues(alpha: 0.06),
                        blurRadius: 24,
                        spreadRadius: -6,
                        offset: const Offset(0, 10),
                      ),
                    ],
              ),
              child: child,
            ),
          ),
        );
        break;

      case SLCardVariant.elevated:
        card = Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? SLColors.bgCard,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? SLColors.slate200.withValues(alpha: 0.5),
              width: 0.8,
            ),
            boxShadow: boxShadow ?? SLShadow.md,
          ),
          child: child,
        );
        break;

      case SLCardVariant.outlined:
        card = Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? SLColors.bgCard,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? SLColors.slate200,
              width: 1.0,
            ),
          ),
          child: child,
        );
        break;

      case SLCardVariant.filled:
        card = Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? SLColors.auroraRose.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(radius),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 0.8)
                : null,
          ),
          child: child,
        );
        break;

      case SLCardVariant.hero:
        card = Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            image: image,
            boxShadow: boxShadow ?? SLShadow.lg,
          ),
          child: child,
        );
        break;
    }

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: card,
    );
  }
}

/// Aurora Soft text input với floating label và glass background.
/// Animation mượt khi focus thay đổi.
class SLInput extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? helperText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const SLInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.helperText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
  });

  @override
  State<SLInput> createState() => _SLInputState();
}

class _SLInputState extends State<SLInput>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _animCtrl;
  late final Animation<double> _borderAnim;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _borderAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (_isFocused) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _borderAnim,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: SLColors.bgElevated.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasError
                      ? SLColors.danger
                      : Color.lerp(
                          SLColors.slate200,
                          SLColors.auroraRoseDeep,
                          _borderAnim.value,
                        )!,
                  width: _isFocused ? 1.6 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hasError
                        ? SLColors.danger.withValues(alpha: 0.08)
                        : SLColors.auroraRoseDeep
                            .withValues(alpha: 0.06 * _borderAnim.value),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: widget.textInputAction,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SLColors.slate900,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              labelStyle: TextStyle(
                color: hasError
                    ? SLColors.danger
                    : _isFocused
                        ? SLColors.auroraRoseDeep
                        : SLColors.slate400,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              hintStyle: TextStyle(
                color: SLColors.slate400.withValues(alpha: 0.7),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              floatingLabelStyle: TextStyle(
                color: hasError
                    ? SLColors.danger
                    : SLColors.auroraRoseDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused
                          ? SLColors.auroraRoseDeep
                          : SLColors.slate400,
                      size: 20,
                    )
                  : null,
              suffixIcon: widget.suffixIcon != null
                  ? IconButton(
                      icon: Icon(
                        widget.suffixIcon,
                        color: _isFocused
                            ? SLColors.auroraRoseDeep
                            : SLColors.slate400,
                        size: 20,
                      ),
                      onPressed: widget.onSuffixTap,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        ),
        if (widget.helperText != null && !hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              widget.helperText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SLColors.slate400,
              ),
            ),
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SLColors.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
