import 'dart:math';
import 'package:flutter/material.dart';

/// A painter that draws glittering sparkle/star particles around a circle.
/// Used to highlight anniversary/milestone days.
class AnniversarySparklePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, driven by AnimationController
  final Color primaryColor;
  final Color accentColor;
  final int particleCount;
  final double radius; // radius of the circle around which stars orbit

  const AnniversarySparklePainter({
    required this.progress,
    required this.radius,
    this.primaryColor = const Color(0xFFFFD700),
    this.accentColor = const Color(0xFFFF80AB),
    this.particleCount = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = Random(42); // fixed seed for stable layout

    for (int i = 0; i < particleCount; i++) {
      final fraction = i / particleCount;
      // Each particle orbits at a slightly different speed
      final phase = fraction * 2 * pi;
      final speed = 0.8 + (i % 3) * 0.2;
      final angle = phase + progress * 2 * pi * speed;

      // Vary the orbit radius slightly per particle
      final orbitR = radius + (random.nextDouble() - 0.5) * 18.0;
      final x = center.dx + cos(angle) * orbitR;
      final y = center.dy + sin(angle) * orbitR;

      // Pulse size: star is largest at its "peak" phase
      final pulseCycle = (progress * speed * 2 + fraction) % 1.0;
      final sizeFactor = 0.4 + 0.6 * sin(pulseCycle * pi);
      final maxSize = 3.0 + (i % 4) * 1.5;
      final starSize = maxSize * sizeFactor;

      // Alternate colours
      final color = i % 3 == 0
          ? primaryColor
          : i % 3 == 1
              ? accentColor
              : Colors.white;

      // Opacity also pulses
      final opacity = (0.5 + 0.5 * sin(pulseCycle * pi)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      _drawStar(canvas, Offset(x, y), starSize, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    if (size < 0.5) return;
    final path = Path();
    const spikes = 4;
    const outerR = 1.0;
    const innerR = 0.4;
    for (int i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR * size : innerR * size;
      final angle = (i * pi / spikes) - pi / 2;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AnniversarySparklePainter old) =>
      old.progress != progress ||
      old.primaryColor != primaryColor ||
      old.accentColor != accentColor;
}

/// Widget wrapper that animates the sparkle painter continuously.
class AnniversarySparkleRing extends StatefulWidget {
  final double size; // width/height of the containing box
  final double ringRadius; // distance of stars from center
  final bool enabled;
  final Color primaryColor;
  final Color accentColor;

  const AnniversarySparkleRing({
    super.key,
    required this.size,
    required this.ringRadius,
    this.enabled = true,
    this.primaryColor = const Color(0xFFFFD700),
    this.accentColor = const Color(0xFFFF80AB),
  });

  @override
  State<AnniversarySparkleRing> createState() => _AnniversarySparkleRingState();
}

class _AnniversarySparkleRingState extends State<AnniversarySparkleRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: AnniversarySparklePainter(
            progress: _controller.value,
            radius: widget.ringRadius,
            primaryColor: widget.primaryColor,
            accentColor: widget.accentColor,
            particleCount: 20,
          ),
        );
      },
    );
  }
}
