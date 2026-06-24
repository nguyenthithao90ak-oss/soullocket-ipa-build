part of 'soul_merge_screen.dart';

class FloatingMessage {
  final String text;
  final bool isSelf;
  final Offset position;
  final UniqueKey id = UniqueKey();

  FloatingMessage({
    required this.text,
    required this.isSelf,
    required this.position,
  });
}

class FloatingMessageWidget extends StatefulWidget {
  final FloatingMessage message;
  const FloatingMessageWidget({super.key, required this.message});

  @override
  State<FloatingMessageWidget> createState() => _FloatingMessageWidgetState();
}

class _FloatingMessageWidgetState extends State<FloatingMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _slideAnim = Tween<double>(begin: 0.0, end: -80.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.message.isSelf
        ? const Color(0xFFFF4F93)
        : const Color(0xFF9C2A6F);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.message.position.dx,
          top: widget.message.position.dy + _slideAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.message.isSelf ? 16 : 4),
            bottomRight: Radius.circular(widget.message.isSelf ? 4 : 16),
          ),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          widget.message.text,
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class PersistentFloatingPhotoWidget extends StatefulWidget {
  final String url;
  final int index;
  const PersistentFloatingPhotoWidget({super.key, required this.url, required this.index});

  @override
  State<PersistentFloatingPhotoWidget> createState() => _PersistentFloatingPhotoWidgetState();
}

class _PersistentFloatingPhotoWidgetState extends State<PersistentFloatingPhotoWidget> {
  double _x = 0;
  double _y = 0;
  double _angle = 0;
  Timer? _timer;
  bool _isDragging = false;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _randomizePosition();
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => _randomizePosition());
    });
  }

  void _randomizePosition() {
    if (!mounted || _isDragging) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      _x = 20 + _random.nextDouble() * (size.width - 140);
      _y = 100 + _random.nextDouble() * (size.height - 400);
      _angle = (_random.nextDouble() - 0.5) * 0.3;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_x == 0 && _y == 0) return const SizedBox();
    
    Widget content = GestureDetector(
      onPanStart: (_) {
         _timer?.cancel();
         setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
         setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;
         });
      },
      onPanEnd: (_) {
         setState(() => _isDragging = false);
         _timer = Timer.periodic(const Duration(seconds: 8), (_) => _randomizePosition());
      },
      child: Transform.rotate(
        angle: _angle,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
            image: DecorationImage(
              image: CachedNetworkImageProvider(widget.url),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    if (_isDragging) {
      return Positioned(left: _x, top: _y, child: content);
    }
    
    return AnimatedPositioned(
      duration: const Duration(seconds: 8),
      curve: Curves.easeInOutSine,
      left: _x,
      top: _y,
      child: content,
    );
  }
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
        dotPaint.color = colors[(colorIdx + 2) % colors.length].withValues(alpha: 0.09);
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
    path.moveTo(cx, cy + r * 0.4);
    path.cubicTo(cx, cy - r * 0.5, cx - r * 1.4, cy - r * 0.5, cx - r * 1.4, cy + r * 0.2);
    path.cubicTo(cx - r * 1.4, cy + r * 0.9, cx, cy + r * 1.5, cx, cy + r * 1.5);
    path.cubicTo(cx, cy + r * 1.5, cx + r * 1.4, cy + r * 0.9, cx + r * 1.4, cy + r * 0.2);
    path.cubicTo(cx + r * 1.4, cy - r * 0.5, cx, cy - r * 0.5, cx, cy + r * 0.4);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(Canvas canvas, Color color, double cx, double cy, double r) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Dấu + xoay 45°
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
    canvas.drawLine(Offset(cx - r * 0.7, cy - r * 0.7), Offset(cx + r * 0.7, cy + r * 0.7), paint);
    canvas.drawLine(Offset(cx + r * 0.7, cy - r * 0.7), Offset(cx - r * 0.7, cy + r * 0.7), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
