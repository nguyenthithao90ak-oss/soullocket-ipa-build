part of '../../love_insights_view.dart';

// Minh họa thuần vector: không tải ảnh mạng, không tạo dữ liệu hoạt động giả.
class _InsightCompanionArt extends StatefulWidget {
  final bool single;
  const _InsightCompanionArt({required this.single});

  @override
  State<_InsightCompanionArt> createState() => _InsightCompanionArtState();
}

class _InsightCompanionArtState extends State<_InsightCompanionArt>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final media = MediaQuery.of(context);
    final enabled =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        !media.accessibleNavigation;
    if (enabled && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!enabled) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('insight-companion-art'),
          painter: _InsightCompanionPainter(
            motion: _motion,
            single: widget.single,
          ),
        ),
      ),
    );
  }
}

class _InsightCompanionPainter extends CustomPainter {
  final Animation<double> motion;
  final bool single;
  _InsightCompanionPainter({required this.motion, required this.single})
    : super(repaint: motion);

  static const _ink = Color(0xFF755147);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 190, size.height / 155);
    canvas.save();
    canvas.translate(
      (size.width - 190 * scale) / 2,
      (size.height - 155 * scale) / 2,
    );
    canvas.scale(scale);
    final wave = math.sin(motion.value * math.pi * 2);
    canvas.drawOval(
      const Rect.fromLTWH(6, 130, 178, 17),
      Paint()..color = const Color(0xFFEBCED8),
    );
    canvas.drawCircle(
      const Offset(96, 81),
      63,
      Paint()..color = const Color(0xFFFFF8EF),
    );
    _sparkle(canvas, Offset(24, 48 + wave * 2), 6, const Color(0xFFE8AE49));
    _sparkle(canvas, Offset(163, 39 - wave * 2), 8, const Color(0xFFE6AD48));
    _heart(canvas, Offset(104, 19 - wave * 3), 14, const Color(0xFFF198B5));
    _heart(canvas, Offset(172, 91 - wave * 2), 8, const Color(0xFFD4B2E9));
    _heart(canvas, Offset(15, 94 + wave * 2), 9, const Color(0xFFEAA2B4));
    if (single) {
      _friend(canvas, const Offset(95, 94), bunny: false, lean: wave * 0.025);
    } else {
      _friend(
        canvas,
        const Offset(59, 95),
        bunny: false,
        lean: 0.09 + wave * 0.025,
      );
      _friend(
        canvas,
        const Offset(129, 91),
        bunny: true,
        lean: -0.09 - wave * 0.025,
      );
    }
    _heart(canvas, Offset(95, 112 - wave * 1.5), 36, const Color(0xFFE989AA));
    _heart(canvas, Offset(90, 104 - wave * 1.5), 9, const Color(0xFFFFC9DA));
    final paw = Paint()..color = const Color(0xFFFFE2BD);
    canvas.drawOval(const Rect.fromLTWH(64, 106, 19, 12), paw);
    canvas.drawOval(
      const Rect.fromLTWH(108, 106, 19, 12),
      Paint()
        ..color = single ? const Color(0xFFFFE2BD) : const Color(0xFFFFFCF5),
    );
    canvas.restore();
  }

  void _friend(
    Canvas canvas,
    Offset center, {
    required bool bunny,
    required double lean,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(lean);
    final fur = bunny ? const Color(0xFFFFFCF5) : const Color(0xFFFFE2BD);
    final outline = Paint()
      ..color = bunny ? const Color(0xFFE8CBC7) : const Color(0xFFD7AA87)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3;
    void oval(Rect rect, Color color) {
      canvas.drawOval(rect, Paint()..color = color);
      canvas.drawOval(rect, outline);
    }

    if (bunny) {
      oval(const Rect.fromLTWH(-27, -66, 18, 48), fur);
      oval(const Rect.fromLTWH(9, -68, 18, 50), fur);
      canvas.drawOval(
        const Rect.fromLTWH(-22, -58, 8, 29),
        Paint()..color = const Color(0xFFFFD8E1),
      );
      canvas.drawOval(
        const Rect.fromLTWH(14, -60, 8, 31),
        Paint()..color = const Color(0xFFFFD8E1),
      );
    } else {
      oval(const Rect.fromLTWH(-35, -42, 24, 25), fur);
      oval(const Rect.fromLTWH(11, -42, 24, 25), fur);
      canvas.drawCircle(
        const Offset(-23, -30),
        6,
        Paint()..color = const Color(0xFFF1BB9E),
      );
      canvas.drawCircle(
        const Offset(23, -30),
        6,
        Paint()..color = const Color(0xFFF1BB9E),
      );
    }
    oval(const Rect.fromLTWH(-28, -1, 56, 43), fur);
    oval(const Rect.fromLTWH(-36, -34, 72, 61), fur);
    for (final x in [-21.0, 21.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 6), width: 15, height: 8),
        Paint()..color = const Color(0xFFF4AFB5),
      );
    }
    for (final x in [-12.0, 12.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, -3), width: 4, height: 6),
        Paint()..color = _ink,
      );
      canvas.drawCircle(
        Offset(x + 0.4, -4),
        0.8,
        Paint()..color = Colors.white,
      );
    }
    canvas.drawOval(const Rect.fromLTWH(-3, 1, 6, 4), Paint()..color = _ink);
    final mouth = Path()
      ..moveTo(-6, 7)
      ..quadraticBezierTo(-3, 11, 0, 7)
      ..quadraticBezierTo(3, 11, 6, 7);
    canvas.drawPath(
      mouth,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    oval(const Rect.fromLTWH(-26, 33, 21, 11), fur);
    oval(const Rect.fromLTWH(5, 33, 21, 11), fur);
    if (bunny) {
      _heart(canvas, const Offset(24, -26), 9, const Color(0xFFCFACDF));
    }
    canvas.restore();
  }

  void _heart(Canvas canvas, Offset center, double radius, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius / 20);
    final path = Path()
      ..moveTo(0, 17)
      ..cubicTo(-34, -4, -14, -27, 0, -12)
      ..cubicTo(14, -27, 34, -4, 0, 17)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + 2,
        center.dy - 2,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 2,
        center.dy + 2,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - 2,
        center.dy + 2,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - 2,
        center.dy - 2,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InsightCompanionPainter oldDelegate) =>
      oldDelegate.single != single || oldDelegate.motion != motion;
}
