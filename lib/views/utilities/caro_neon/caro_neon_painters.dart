part of '../caro_neon_screen.dart';

class _CaroBackdropPainter extends CustomPainter {
  const _CaroBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF05000E), Color(0xFF12031D), Color(0xFF060112)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    void glowOrb(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.14)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
      );
    }

    glowOrb(Offset(size.width * 0.16, size.height * 0.2), 110,
        const Color(0xFF4EDBFF));
    glowOrb(Offset(size.width * 0.82, size.height * 0.18), 130,
        const Color(0xFFFF5E9E));
    glowOrb(Offset(size.width * 0.72, size.height * 0.84), 150,
        const Color(0xFF8358FF));

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x19D6DFFF);

    const spacing = 46.0;
    for (double x = -spacing; x <= size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + 60, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final frameRect = Rect.fromLTWH(
      14,
      24,
      size.width - 28,
      math.max(180, size.height * 0.32),
    );
    final framePath = Path()
      ..moveTo(frameRect.left + 24, frameRect.top)
      ..lineTo(frameRect.right - 50, frameRect.top)
      ..quadraticBezierTo(frameRect.right, frameRect.top + 10, frameRect.right,
          frameRect.top + 38)
      ..lineTo(frameRect.right, frameRect.bottom - 26)
      ..quadraticBezierTo(frameRect.right, frameRect.bottom,
          frameRect.right - 26, frameRect.bottom)
      ..lineTo(frameRect.left + 62, frameRect.bottom)
      ..quadraticBezierTo(frameRect.left, frameRect.bottom, frameRect.left,
          frameRect.bottom - 56)
      ..lineTo(frameRect.left, frameRect.top + 24)
      ..quadraticBezierTo(
          frameRect.left, frameRect.top, frameRect.left + 24, frameRect.top);

    canvas.drawPath(
      framePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x1FF8E9FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NeonMarkPainter extends CustomPainter {
  const _NeonMarkPainter({
    required this.symbol,
    required this.highlight,
  });

  final String symbol;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final color = highlight
        ? const Color(0xFFFFD76F)
        : symbol == 'X'
            ? const Color(0xFF4EDBFF)
            : const Color(0xFFFF5E9E);

    final strokeWidth = size.shortestSide * 0.11;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: highlight ? 0.8 : 0.48);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.72
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.48
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    if (symbol == 'X') {
      final startA = Offset(size.width * 0.18, size.height * 0.2);
      final endA = Offset(size.width * 0.82, size.height * 0.8);
      final startB = Offset(size.width * 0.82, size.height * 0.2);
      final endB = Offset(size.width * 0.18, size.height * 0.8);
      for (final sigma in [18.0, 8.0]) {
        canvas.drawLine(
          startA,
          endA,
          glowPaint..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
        );
        canvas.drawLine(
          startB,
          endB,
          glowPaint..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
        );
      }
      canvas.drawLine(startA, endA, corePaint);
      canvas.drawLine(startB, endB, corePaint);
      canvas.drawLine(startA, endA, accentPaint);
      canvas.drawLine(startB, endB, accentPaint);
      return;
    }

    final ovalRect = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.18,
      size.width * 0.64,
      size.height * 0.64,
    );
    for (final sigma in [18.0, 8.0]) {
      canvas.drawOval(
        ovalRect,
        glowPaint..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
    canvas.drawOval(ovalRect, corePaint);
    canvas.drawOval(ovalRect, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _NeonMarkPainter oldDelegate) {
    return oldDelegate.symbol != symbol || oldDelegate.highlight != highlight;
  }
}
