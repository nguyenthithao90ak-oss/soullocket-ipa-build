import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

/// Decorative floating orbs cho Aurora Login Screen.
/// 3 orbs đặt ở các góc với subtle floating animation.
/// Sử dụng FastBackdropFilter để tự động disable blur khi scrolling.
class AuroraDecorativeOrbs extends StatefulWidget {
  const AuroraDecorativeOrbs({super.key});

  @override
  State<AuroraDecorativeOrbs> createState() => _AuroraDecorativeOrbsState();
}

class _AuroraDecorativeOrbsState extends State<AuroraDecorativeOrbs>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -12.0, end: 12.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, _) {
        return Stack(
          children: [
            // Top-left: Rose orb (lớn nhất)
            Positioned(
              top: -60 + _floatAnim.value * 0.5,
              left: -80,
              child: _AuroraOrb(
                radius: 200,
                gradientColors: const [
                  Color(0xFFFF6B9D), // roseDeep
                  Color(0xFFFFB3CC), // roseMid
                ],
                blurSigma: 48,
              ),
            ),

            // Top-right: Lavender orb
            Positioned(
              top: -40 + _floatAnim.value * -0.4,
              right: -60,
              child: _AuroraOrb(
                radius: 150,
                gradientColors: const [
                  Color(0xFFB19CD9), // lavender
                  Color(0xFFE8DEFF), // lavenderLight
                ],
                blurSigma: 40,
              ),
            ),

            // Bottom-center: Peach orb
            Positioned(
              bottom: -80 + _floatAnim.value * 0.3,
              left: 0,
              right: 0,
              child: Center(
                child: _AuroraOrb(
                  radius: 180,
                  gradientColors: const [
                    Color(0xFFFFAB91), // peach
                    Color(0xFFFF8A65), // peachDeep
                  ],
                  blurSigma: 44,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuroraOrb extends StatelessWidget {
  final double radius;
  final List<Color> gradientColors;
  final double blurSigma;

  const _AuroraOrb({
    required this.radius,
    required this.gradientColors,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        fallbackColor: Colors.transparent,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                gradientColors[0].withValues(alpha: 0.45),
                gradientColors[1].withValues(alpha: 0.25),
                gradientColors[1].withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
