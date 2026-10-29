import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Một burst cố định, vẽ cùng nhịp với thẻ ảnh nên không cần thêm ticker/timer.
class SoulMergeMemoryBurstPainter extends CustomPainter {
  const SoulMergeMemoryBurstPainter({
    required this.progress,
    required this.dark,
  });
  final double progress;
  final bool dark;

  Path _heart(Offset center, double radius) {
    final path = Path()..moveTo(0, -radius * .35);
    path.cubicTo(radius, -radius * 1.5, radius * 1.65, 0, 0, radius);
    path.cubicTo(-radius * 1.65, 0, -radius, -radius * 1.5, 0, -radius * .35);
    return path.shift(center);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final travel = Curves.easeOutCubic.transform(progress);
    final opacity = math.sin(math.pi * progress);
    final center = size.center(Offset.zero);
    final radius = size.width * (.28 + travel * .58);
    const colors = [Color(0xFFF28BB4), Color(0xFFFFD58C), Color(0xFFCCAFF7)];
    for (var ring = 0; ring < 2; ring++) {
      canvas.drawCircle(
        center,
        radius * (1 + ring * .19),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = colors[ring].withValues(alpha: opacity * .45),
      );
    }
    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 12;
      final point =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              radius *
              (i.isEven ? 1.05 : .86);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: opacity * (dark ? .95 : .85),
        );
      final dot = (i.isEven ? 7.0 : 4.0) * (1 - progress * .4);
      if (i % 3 == 0) {
        canvas.drawPath(_heart(point, dot), paint);
      } else {
        final star = Path()
          ..moveTo(point.dx, point.dy - dot)
          ..quadraticBezierTo(
            point.dx + dot * .2,
            point.dy - dot * .2,
            point.dx + dot,
            point.dy,
          )
          ..quadraticBezierTo(
            point.dx + dot * .2,
            point.dy + dot * .2,
            point.dx,
            point.dy + dot,
          )
          ..quadraticBezierTo(
            point.dx - dot * .2,
            point.dy + dot * .2,
            point.dx - dot,
            point.dy,
          )
          ..quadraticBezierTo(
            point.dx - dot * .2,
            point.dy - dot * .2,
            point.dx,
            point.dy - dot,
          );
        canvas.drawPath(star, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SoulMergeMemoryBurstPainter oldDelegate) =>
      progress != oldDelegate.progress || dark != oldDelegate.dark;
}
