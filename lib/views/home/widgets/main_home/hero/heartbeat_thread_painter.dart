import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class HeartbeatThreadWidget extends StatefulWidget {
  final bool isOnline;
  const HeartbeatThreadWidget({super.key, this.isOnline = true});

  @override
  State<HeartbeatThreadWidget> createState() => _HeartbeatThreadWidgetState();
}

class _HeartbeatThreadWidgetState extends State<HeartbeatThreadWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _FateStringPainter(
            progress: _controller.value,
            isOnline: widget.isOnline,
          ),
        );
      },
    );
  }
}

class _FateStringPainter extends CustomPainter {
  final double progress;
  final bool isOnline;

  _FateStringPainter({
    required this.progress,
    required this.isOnline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final start = Offset(size.width * 0.2, size.height * 0.5);
    final end = Offset(size.width * 0.8, size.height * 0.5);
    
    // Wave animation for the string to feel "alive"
    final waveOffset = sin(progress * 2 * pi) * 8.0;
    final controlPoint = Offset(size.width * 0.5, size.height * 0.15 + waveOffset);

    // Build the path
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);

    // 1. Draw glowing shadow of the string
    final shadowPaint = Paint()
      ..color = const Color(0xFFFF4D79).withValues(alpha: isOnline ? 0.4 : 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, shadowPaint);

    // 2. Draw the main string with a beautiful gradient
    final gradient = ui.Gradient.linear(
      start,
      end,
      [
        const Color(0xFFFF9EBB).withValues(alpha: isOnline ? 0.9 : 0.4),
        const Color(0xFFFF4D79).withValues(alpha: isOnline ? 1.0 : 0.4),
        const Color(0xFFFF9EBB).withValues(alpha: isOnline ? 0.9 : 0.4),
      ],
      [0.0, 0.5, 1.0],
    );

    final basePaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, basePaint);

    // 3. Draw the traveling pulse (shooting star / comet effect)
    if (isOnline) {
      // Calculate current position on quadratic bezier
      Offset getPointOnBezier(double t) {
        final x = (1 - t) * (1 - t) * start.dx +
            2 * (1 - t) * t * controlPoint.dx +
            t * t * end.dx;
        final y = (1 - t) * (1 - t) * start.dy +
            2 * (1 - t) * t * controlPoint.dy +
            t * t * end.dy;
        return Offset(x, y);
      }

      final currentPos = getPointOnBezier(progress);

      // Draw the trail
      final trailPath = Path();
      const int trailSegments = 12;
      for (int i = 0; i <= trailSegments; i++) {
        // Calculate a trailing t value
        final trailT = (progress - (i * 0.015)).clamp(0.0, 1.0);
        final pt = getPointOnBezier(trailT);
        if (i == 0) {
          trailPath.moveTo(pt.dx, pt.dy);
        } else {
          trailPath.lineTo(pt.dx, pt.dy);
        }
      }

      final trailPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(trailPath, trailPaint);

      // Draw the core glowing dot (the star)
      final coreGlowPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(currentPos, 6.0, coreGlowPaint);

      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(currentPos, 3.0, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FateStringPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isOnline != isOnline;
  }
}
