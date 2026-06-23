part of '../gift_maker_screen.dart';

class _GiftBackdropPainter extends CustomPainter {
  const _GiftBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    const spacing = 34.0;

    for (double y = -spacing; y <= size.height + spacing; y += spacing) {
      for (double x = -spacing; x <= size.width + spacing; x += spacing) {
        final shift = ((y / spacing).round().isEven) ? 0.0 : spacing / 2;
        canvas.drawCircle(Offset(x + shift, y), 1.3, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFF4F93).withValues(alpha: 0.10)
      ..strokeWidth = 1;

    for (double x = -size.height; x <= size.width; x += 180) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF7AB8).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.16, size.height * 0.18),
        radius: size.width * 0.52,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.18),
      size.width * 0.52,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GiftTouchTile extends StatefulWidget {
  const _GiftTouchTile({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_GiftTouchTile> createState() => _GiftTouchTileState();
}

class _GiftTouchTileState extends State<_GiftTouchTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _pressed ? const Offset(0, 0.01) : Offset.zero,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius,
            splashColor: const Color(0xFFD81B60).withValues(alpha: 0.12),
            highlightColor: const Color(0xFFD81B60).withValues(alpha: 0.05),
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
