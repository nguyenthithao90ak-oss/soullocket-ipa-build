part of '../collage_maker_screen.dart';

class _CollageStylePreset {
  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final Color background;

  const _CollageStylePreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.background,
  });
}

class _CollageAspectPreset {
  final String id;
  final String label;
  final String subtitle;
  final double width;
  final double height;

  const _CollageAspectPreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.width,
    required this.height,
  });

  double get ratio => width / height;
}

class _CollageBackgroundPreset {
  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final Color background;
  final IconData icon;

  const _CollageBackgroundPreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.background,
    required this.icon,
  });
}

class _IntroChip extends StatelessWidget {
  final String label;
  final bool centered;
  final double? fixedHeight;

  const _IntroChip({
    required this.label,
    this.centered = false,
    this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: fixedHeight,
      alignment: centered ? Alignment.center : null,
      padding: EdgeInsets.symmetric(
        horizontal: centered ? 10 : 11,
        vertical: fixedHeight == null ? 5 : 0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8DB),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(9),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _paperRose.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: _paperCocoa.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.playfairDisplay(
          fontSize: 10.6,
          fontWeight: FontWeight.w700,
          color: _paperCocoa,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _MemoryMascotBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const [
          _paperCream,
          Color(0xFFF4E9DD),
          Color(0xFFEAEFE8),
        ],
        const [0.0, 0.54, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);

    final softPaint = Paint()..style = PaintingStyle.fill;
    for (final card in [
      (
        Rect.fromCenter(
          center: Offset(size.width * 0.12, size.height * 0.16),
          width: 142,
          height: 102,
        ),
        const Color(0xFFE8D3C0),
        -0.10
      ),
      (
        Rect.fromCenter(
          center: Offset(size.width * 0.88, size.height * 0.14),
          width: 126,
          height: 88,
        ),
        const Color(0xFFD6E0D7),
        0.14
      ),
      (
        Rect.fromCenter(
          center: Offset(size.width * 0.84, size.height * 0.78),
          width: 150,
          height: 112,
        ),
        const Color(0xFFEAD8CF),
        -0.08
      ),
    ]) {
      canvas.save();
      canvas.translate(card.$1.center.dx, card.$1.center.dy);
      canvas.rotate(card.$3);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: card.$1.width,
        height: card.$1.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(26),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(30),
        ),
        softPaint..color = card.$2.withOpacity(0.48),
      );
      canvas.restore();
    }

    final rulePaint = Paint()
      ..color = const Color(0xFFD9C7B8).withOpacity(0.32)
      ..strokeWidth = 1;
    for (double y = 96; y < size.height; y += 92) {
      canvas.drawLine(
        Offset(26, y),
        Offset(size.width - 26, y),
        rulePaint,
      );
    }

    for (final pin in [
      (Offset(size.width * 0.16, size.height * 0.34), const Color(0xFFA76F61)),
      (Offset(size.width * 0.92, size.height * 0.54), const Color(0xFF7B988A)),
      (Offset(size.width * 0.28, size.height * 0.88), const Color(0xFFB4895B)),
    ]) {
      _MascotPainterKit.drawSparkle(
        canvas,
        pin.$1,
        8,
        pin.$2.withOpacity(0.30),
      );
      _MascotPainterKit.drawHeart(
        canvas,
        pin.$1.translate(16, -12),
        6.5,
        pin.$2.withOpacity(0.18),
      );
    }

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _paperRose.withOpacity(0.34)
      ..strokeWidth = 1.2;
    for (final corner in <Offset>[
      const Offset(18, 24),
      Offset(size.width - 18, 24),
      Offset(18, size.height - 24),
      Offset(size.width - 18, size.height - 24),
    ]) {
      final path = Path();
      if (corner.dx < size.width / 2) {
        path.moveTo(corner.dx, corner.dy + 18);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx + 18, corner.dy);
      } else {
        path.moveTo(corner.dx - 18, corner.dy);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx, corner.dy + 18);
      }
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MascotPainterKit {
  static void drawSparkle(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(
        center.dx + size * 0.22,
        center.dy - size * 0.22,
        center.dx + size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size * 0.22,
        center.dy + size * 0.22,
        center.dx,
        center.dy + size,
      )
      ..quadraticBezierTo(
        center.dx - size * 0.22,
        center.dy + size * 0.22,
        center.dx - size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - size * 0.22,
        center.dy - size * 0.22,
        center.dx,
        center.dy - size,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  static void drawHeart(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
  ) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.32);
    path.cubicTo(
      center.dx - size * 1.05,
      center.dy - size * 0.18,
      center.dx - size * 0.58,
      center.dy - size,
      center.dx,
      center.dy - size * 0.42,
    );
    path.cubicTo(
      center.dx + size * 0.58,
      center.dy - size,
      center.dx + size * 1.05,
      center.dy - size * 0.18,
      center.dx,
      center.dy + size * 0.32,
    );
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
}
