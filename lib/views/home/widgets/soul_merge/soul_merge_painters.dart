part of '../soul_merge_screen.dart';

class _SparklePainter extends CustomPainter {
  final double pulseValue;

  static const _radius = 45.0;
  static const _sizes = [6.0, 4.5, 6.0, 4.5];
  static const _colors = [
    Color(0xFFFF80B3),
    Color(0xFFD8A4FF),
    Color(0xFFFFEAA0),
    Color(0xFFFFB7D5),
  ];
  static const _angles = [0.0, 90.0, 180.0, 270.0];

  const _SparklePainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < _angles.length; i++) {
      final angleRad = _angles[i] * math.pi / 180;
      final dx = math.cos(angleRad) * _radius;
      final dy = math.sin(angleRad) * _radius;
      final opacity = (i % 2 == 0
              ? (0.3 + 0.65 * pulseValue)
              : (0.95 - 0.65 * pulseValue))
          .clamp(0.0, 1.0);
      paint.color = _colors[i % _colors.length].withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(centerX + dx, centerY + dy),
        _sizes[i] / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      pulseValue != old.pulseValue;
}

// ─── Cute Background Pattern Painter ──────────────────────────────────────────
class _CuteBgPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final heartPaint = Paint()..style = PaintingStyle.fill;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Pattern grid — rải đều
    const double spacing = 52;

    final colors = [
      const Color(0xFFFFB3CC), // hồng pastel
      const Color(0xFFFFD6E8), // hồng nhạt
      const Color(0xFFE4B5FF), // tím pastel
      const Color(0xFFFFEAF0), // trắng hồng
      const Color(0xFFFFCC99), // cam đào
    ];

    int colorIdx = 0;
    for (double cy = -spacing; cy < size.height + spacing; cy += spacing) {
      bool oddRow = ((cy / spacing).round() % 2 == 1);
      for (double cx = oddRow ? spacing * 0.5 : 0;
          cx < size.width + spacing;
          cx += spacing) {
        final color = colors[colorIdx % colors.length];
        colorIdx++;

        // Vẽ tim nhỏ
        heartPaint.color = color.withValues(alpha: 0.13);
        _drawHeart(canvas, heartPaint, cx, cy, 7.0);

        // Chấm tròn nhỏ lân cận
        dotPaint.color =
            colors[(colorIdx + 2) % colors.length].withValues(alpha: 0.09);
        canvas.drawCircle(Offset(cx + 14, cy + 8), 3.0, dotPaint);

        // Dấu x nhỏ (sparkle) offset khác
        _drawSparkle(
          canvas,
          colors[(colorIdx + 1) % colors.length].withValues(alpha: 0.10),
          cx - 12,
          cy + 22,
          4.5,
        );
      }
    }

    // Lớp chấm tròn gradient nhẹ theo đường chéo
    for (double t = 0; t < size.width + size.height; t += 36) {
      final dx = t * (size.width / (size.width + size.height));
      final dy = t * (size.height / (size.width + size.height));
      dotPaint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.04);
      canvas.drawCircle(Offset(dx, dy), 5.0, dotPaint);
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path();
    // Trái tim đơn giản bằng cubic bezier
    path.moveTo(cx, cy + r * 0.4);
    path.cubicTo(cx, cy - r * 0.5, cx - r * 1.4, cy - r * 0.5, cx - r * 1.4,
        cy + r * 0.2);
    path.cubicTo(
        cx - r * 1.4, cy + r * 0.9, cx, cy + r * 1.5, cx, cy + r * 1.5);
    path.cubicTo(cx, cy + r * 1.5, cx + r * 1.4, cy + r * 0.9, cx + r * 1.4,
        cy + r * 0.2);
    path.cubicTo(
        cx + r * 1.4, cy - r * 0.5, cx, cy - r * 0.5, cx, cy + r * 0.4);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(
      Canvas canvas, Color color, double cx, double cy, double r) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Dấu + xoay 45°
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
    canvas.drawLine(Offset(cx - r * 0.7, cy - r * 0.7),
        Offset(cx + r * 0.7, cy + r * 0.7), paint);
    canvas.drawLine(Offset(cx + r * 0.7, cy - r * 0.7),
        Offset(cx - r * 0.7, cy + r * 0.7), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
