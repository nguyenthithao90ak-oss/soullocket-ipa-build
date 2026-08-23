import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import '../sl_theme.dart';

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

