import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Background of the redesigned authentication flow.
///
/// The class name is intentionally kept for compatibility with the existing
/// AuroraLoginScreen, but the visual language is now a softer "Locket Garden"
/// illustration drawn completely with Canvas. No external image asset is
/// required, which keeps the login screen deterministic on first launch.
class AuroraHeroBackground extends StatefulWidget {
  final Widget? child;

  const AuroraHeroBackground({super.key, this.child});

  @override
  State<AuroraHeroBackground> createState() => _AuroraHeroBackgroundState();
}

class _AuroraHeroBackgroundState extends State<AuroraHeroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: const _LocketGardenPainter(progress: 0.18),
          child: widget.child,
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _LocketGardenPainter(progress: _controller.value),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _LocketGardenPainter extends CustomPainter {
  final double progress;

  const _LocketGardenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = progress * math.pi * 2;

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFBF5),
          Color(0xFFFFF1F5),
          Color(0xFFF4EFFF),
          Color(0xFFEFF8FF),
        ],
        stops: [0.0, 0.35, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    _drawSoftBlob(
      canvas,
      center: Offset(
        size.width * (0.10 + 0.025 * math.sin(phase)),
        size.height * 0.18,
      ),
      radius: size.shortestSide * 0.40,
      color: const Color(0xFFFFA9BD).withValues(alpha: 0.20),
    );
    _drawSoftBlob(
      canvas,
      center: Offset(
        size.width * (0.92 + 0.018 * math.cos(phase * 0.8)),
        size.height * 0.28,
      ),
      radius: size.shortestSide * 0.34,
      color: const Color(0xFFCDBEFF).withValues(alpha: 0.22),
    );
    _drawSoftBlob(
      canvas,
      center: Offset(
        size.width * (0.52 + 0.025 * math.sin(phase * 0.65)),
        size.height * 0.90,
      ),
      radius: size.shortestSide * 0.42,
      color: const Color(0xFFFFD7AE).withValues(alpha: 0.20),
    );

    _drawPaperHill(
      canvas,
      size,
      y: size.height * 0.78,
      amplitude: 18,
      color: const Color(0xFFFFF7ED).withValues(alpha: 0.72),
      phase: phase,
    );
    _drawPaperHill(
      canvas,
      size,
      y: size.height * 0.87,
      amplitude: 13,
      color: const Color(0xFFF2EBFF).withValues(alpha: 0.72),
      phase: -phase * 0.75,
    );

    _drawThread(
      canvas,
      size,
      start: Offset(-24, size.height * 0.60),
      end: Offset(size.width + 20, size.height * 0.43),
      phase: phase,
    );

    final doodlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    _drawHeart(
      canvas,
      Offset(size.width * 0.12, size.height * 0.42),
      10 + 1.5 * math.sin(phase),
      doodlePaint..color = const Color(0xFFF08AA4).withValues(alpha: 0.32),
    );
    _drawHeart(
      canvas,
      Offset(size.width * 0.88, size.height * 0.62),
      8 + 1.1 * math.cos(phase * 1.2),
      doodlePaint..color = const Color(0xFF8F7AD6).withValues(alpha: 0.28),
    );

    _drawStar(
      canvas,
      Offset(size.width * 0.80, size.height * 0.14),
      7,
      const Color(0xFFE1A44F).withValues(alpha: 0.35),
    );
    _drawStar(
      canvas,
      Offset(size.width * 0.20, size.height * 0.70),
      5,
      const Color(0xFFE1A44F).withValues(alpha: 0.28),
    );
  }

  void _drawSoftBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawPaperHill(
    Canvas canvas,
    Size size, {
    required double y,
    required double amplitude,
    required Color color,
    required double phase,
  }) {
    final path = Path()..moveTo(0, y);
    const segments = 6;
    for (var i = 0; i <= segments; i++) {
      final x = size.width * i / segments;
      final waveY = y + math.sin(i * 1.2 + phase) * amplitude;
      path.lineTo(x, waveY);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawThread(
    Canvas canvas,
    Size size, {
    required Offset start,
    required Offset end,
    required double phase,
  }) {
    final path = Path()..moveTo(start.dx, start.dy);
    path.cubicTo(
      size.width * 0.22,
      start.dy - 36 + math.sin(phase) * 5,
      size.width * 0.68,
      end.dy + 42 + math.cos(phase) * 4,
      end.dx,
      end.dy,
    );

    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = const Color(0xFFDF91AA).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    var distance = 0.0;
    const dash = 8.0;
    const gap = 7.0;
    while (distance < metric.length) {
      final extract = metric.extractPath(
        distance,
        math.min(distance + dash, metric.length),
      );
      canvas.drawPath(extract, paint);
      distance += dash + gap;
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.35)
      ..cubicTo(
        center.dx - size * 0.90,
        center.dy - size * 0.20,
        center.dx - size * 0.55,
        center.dy - size * 0.85,
        center.dx,
        center.dy - size * 0.30,
      )
      ..cubicTo(
        center.dx + size * 0.55,
        center.dy - size * 0.85,
        center.dx + size * 0.90,
        center.dy - size * 0.20,
        center.dx,
        center.dy + size * 0.35,
      );
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LocketGardenPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
