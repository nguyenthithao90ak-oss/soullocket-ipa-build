import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated Aurora gradient background cho Aurora Login Screen.
/// 3 màu chuyển động chậm trong 8s loop với phong cách soft romantic.
class AuroraHeroBackground extends StatefulWidget {
  final Widget? child;

  const AuroraHeroBackground({super.key, this.child});

  @override
  State<AuroraHeroBackground> createState() => _AuroraHeroBackgroundState();
}

class _AuroraHeroBackgroundState extends State<AuroraHeroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _AuroraPainter(progress: _ctrl.value),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;

  _AuroraPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Nền soft gradient tĩnh
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFFFF5F7), // warm white top
          Color(0xFFFFF0F5), // soft pink
          Color(0xFFEFE8FF), // soft lavender
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Aurora Layer 1: Rose — di chuyển từ trái sang phải
    _drawAuroraBlob(
      canvas,
      size,
      offsetX: math.sin(progress * 2 * math.pi) * 0.15,
      offsetY: math.cos(progress * 1.5 * math.pi) * 0.08,
      radiusScale: 1.0 + math.sin(progress * 2 * math.pi) * 0.12,
      color1: const Color(0xFFFFB3CC).withValues(alpha: 0.38),
      color2: const Color(0xFFFFE4EC).withValues(alpha: 0.0),
      alignment: const Alignment(-0.7, -0.6),
      radius: size.height * 0.72,
    );

    // Aurora Layer 2: Lavender — di chuyển ngược
    _drawAuroraBlob(
      canvas,
      size,
      offsetX: math.cos(progress * 1.8 * math.pi) * 0.12,
      offsetY: math.sin(progress * 1.2 * math.pi) * 0.06,
      radiusScale: 1.0 + math.cos(progress * 1.8 * math.pi) * 0.1,
      color1: const Color(0xFFB19CD9).withValues(alpha: 0.32),
      color2: const Color(0xFFE8DEFF).withValues(alpha: 0.0),
      alignment: const Alignment(0.75, -0.5),
      radius: size.height * 0.60,
    );

    // Aurora Layer 3: Peach — di chuyển chậm dưới đáy
    _drawAuroraBlob(
      canvas,
      size,
      offsetX: math.sin(progress * 1.3 * math.pi) * 0.1,
      offsetY: math.cos(progress * 1.6 * math.pi) * 0.1,
      radiusScale: 1.0 + math.sin(progress * 1.3 * math.pi) * 0.15,
      color1: const Color(0xFFFFAB91).withValues(alpha: 0.28),
      color2: const Color(0xFFFFE0B2).withValues(alpha: 0.0),
      alignment: const Alignment(0.1, 0.85),
      radius: size.height * 0.65,
    );

    // Subtle shimmer overlay
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.04 + math.sin(progress * 2 * math.pi) * 0.02),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shimmerPaint);
  }

  void _drawAuroraBlob(
    Canvas canvas,
    Size size, {
    required double offsetX,
    required double offsetY,
    required double radiusScale,
    required Color color1,
    required Color color2,
    required Alignment alignment,
    required double radius,
  }) {
    final centerX = size.width * (0.5 + alignment.x * 0.5) + offsetX * size.width * 0.25;
    final centerY = size.height * (0.5 + alignment.y * 0.5) + offsetY * size.height * 0.2;
    final r = radius * radiusScale * 0.5;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color1, color2],
      ).createShader(
        Rect.fromLTWH(centerX - r, centerY - r, r * 2, r * 2),
      );

    canvas.drawCircle(Offset(centerX, centerY), r, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
