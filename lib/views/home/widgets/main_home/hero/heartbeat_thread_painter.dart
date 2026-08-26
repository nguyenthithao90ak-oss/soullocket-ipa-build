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

    // 1. Draw glowing shadow of the vein
    final shadowPaint = Paint()
      ..color = const Color(0xFFFF1A1A).withValues(alpha: isOnline ? 0.5 : 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Create an organic, vein-like path with multiple curves
    final path1 = Path();
    final path2 = Path();
    
    path1.moveTo(start.dx, start.dy);
    path2.moveTo(start.dx, start.dy);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    
    // Draw 2 intertwined veins
    for (int i = 1; i <= 10; i++) {
      final t = i / 10;
      final currentX = start.dx + dx * t;
      final currentY = start.dy + dy * t;
      
      // Add organic noise/wiggles
      final wave1 = sin(progress * pi * 2 + t * pi * 4) * 8.0 + sin(t * pi * 8) * 4.0;
      final wave2 = cos(progress * pi * 2 + t * pi * 5) * 6.0 - cos(t * pi * 7) * 5.0;
      
      if (i == 10) {
        path1.lineTo(end.dx, end.dy);
        path2.lineTo(end.dx, end.dy);
      } else {
        path1.lineTo(currentX, currentY + wave1);
        path2.lineTo(currentX, currentY + wave2);
      }
    }

    canvas.drawPath(path1, shadowPaint);
    canvas.drawPath(path2, shadowPaint);

    // 2. Draw the main veins with a deep red color
    final basePaint1 = Paint()
      ..color = const Color(0xFFFF2A2A).withValues(alpha: isOnline ? 0.9 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final basePaint2 = Paint()
      ..color = const Color(0xFFD30000).withValues(alpha: isOnline ? 0.85 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path1, basePaint1);
    canvas.drawPath(path2, basePaint2);

    // 3. Draw blood cells (flowing particles) inside the veins
    if (isOnline) {
      void drawBloodCell(double t, Path veinPath) {
        // Approximate point on path
        final px = start.dx + dx * t;
        final py = start.dy + dy * t;
        
        final trailPaint = Paint()
          ..color = const Color(0xFFFF8888).withValues(alpha: 0.9)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          
        canvas.drawCircle(Offset(px, py), 2.5, trailPaint);
        
        final corePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), 1.0, corePaint);
      }

      final cell1Progress = (progress + 0.0) % 1.0;
      final cell2Progress = (progress + 0.33) % 1.0;
      final cell3Progress = (progress + 0.66) % 1.0;

      drawBloodCell(cell1Progress, path1);
      drawBloodCell(cell2Progress, path2);
      drawBloodCell(cell3Progress, path1);
    }
  }

  @override
  bool shouldRepaint(covariant _FateStringPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isOnline != isOnline;
  }
}
