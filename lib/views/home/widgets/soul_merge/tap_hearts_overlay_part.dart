part of '../soul_merge_screen.dart';

class TinyHeart {
  final double angle;
  final double speed;
  final double size;
  Color color;
  final UniqueKey id = UniqueKey();
  double x;
  double y;
  double opacity = 1.0;

  // New fields for premium styles
  final String style;
  final double startX;
  final double swayPhase;
  double lifeTimeProgress = 0.0;
  final List<Offset> trail = [];

  // Fields for flying to target
  bool isFlyingToTarget = false;
  double targetX = 0;
  double targetY = 0;
  int flightPathType = 0;

  TinyHeart({
    required this.x,
    required this.y,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.style,
  })  : startX = x,
        swayPhase = math.Random().nextDouble() * math.pi * 2;
}

class FlyingStickerParticle {
  final String assetPath;
  double x;
  double y;
  double targetX;
  double targetY;
  double size;
  double speed;
  double lifeTimeProgress = 0.0;
  int flightPathType;

  FlyingStickerParticle({
    required this.assetPath,
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    required this.size,
    required this.speed,
    required this.flightPathType,
  });
}

class TapHeartsOverlay extends StatefulWidget {
  final String style;
  const TapHeartsOverlay({super.key, required this.style});

  @override
  State<TapHeartsOverlay> createState() => TapHeartsOverlayState();
}

class TapHeartsOverlayState extends State<TapHeartsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickerController;
  final List<TinyHeart> _hearts = [];
  final List<FlyingStickerParticle> _flyingStickers = [];

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tickHearts);
  }

  void _tickHearts() {
    if (_hearts.isEmpty && _flyingStickers.isEmpty) {
      if (_tickerController.isAnimating) {
        _tickerController.stop();
      }
      return;
    }

    setState(() {
      const double dt = 0.016; // approximate delta time per frame

      for (int i = _flyingStickers.length - 1; i >= 0; i--) {
        final sticker = _flyingStickers[i];
        sticker.lifeTimeProgress += dt;
        final dx = sticker.targetX - sticker.x;
        final dy = sticker.targetY - sticker.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < 25.0 || sticker.lifeTimeProgress > 2.0) {
          _flyingStickers.removeAt(i);
          spawnLocalExplosion(Offset(sticker.targetX, sticker.targetY), count: 5);
          continue;
        }

        final targetAngle = math.atan2(dy, dx);
        double currentAngle = targetAngle;
        
        if (sticker.flightPathType == 1) {
          currentAngle += math.sin(sticker.lifeTimeProgress * 15.0) * 0.9;
        } else if (sticker.flightPathType == 2) {
          currentAngle += math.sin(sticker.lifeTimeProgress * 25.0) * 1.5;
        }

        final currentSpeed = math.min(22.0, sticker.speed + sticker.lifeTimeProgress * 20.0);
        sticker.x += math.cos(currentAngle) * currentSpeed;
        sticker.y += math.sin(currentAngle) * currentSpeed;
      }

      for (int i = _hearts.length - 1; i >= 0; i--) {
        final heart = _hearts[i];
        heart.lifeTimeProgress += dt;

        if (heart.isFlyingToTarget) {
          final dx = heart.targetX - heart.x;
          final dy = heart.targetY - heart.y;
          final distance = math.sqrt(dx * dx + dy * dy);

          if (distance < 25.0) {
            _hearts.removeAt(i);
            spawnLocalExplosion(Offset(heart.targetX, heart.targetY), count: 4);
            continue;
          }

          final targetAngle = math.atan2(dy, dx);
          double currentAngle = targetAngle;
          
          if (heart.flightPathType == 1) {
            currentAngle += math.sin(heart.lifeTimeProgress * 15.0) * 0.9;
          } else if (heart.flightPathType == 2) {
            currentAngle += math.sin(heart.lifeTimeProgress * 25.0) * 1.5;
          }

          final currentSpeed = math.min(22.0, heart.speed + heart.lifeTimeProgress * 20.0);
          heart.x += math.cos(currentAngle) * currentSpeed;
          heart.y += math.sin(currentAngle) * currentSpeed;

          if (heart.style == 'aurora' || heart.style == 'cosmic') {
            heart.trail.add(Offset(heart.x, heart.y));
            if (heart.trail.length > 8) {
              heart.trail.removeAt(0);
            }
          }
          
          continue;
        }

        if (heart.style == 'cosmic') {
          final double sway =
              math.sin(heart.lifeTimeProgress * 10.0 + heart.swayPhase) * 1.5;
          heart.x += math.cos(heart.angle) * heart.speed + sway;
          heart.y += math.sin(heart.angle) * heart.speed - 1.5;
        } else if (heart.style == 'aurora') {
          heart.trail.add(Offset(heart.x, heart.y));
          if (heart.trail.length > 10) {
            heart.trail.removeAt(0);
          }
          final double wave =
              math.sin(heart.lifeTimeProgress * 15.0 + heart.swayPhase) * 0.8;
          heart.x += math.cos(heart.angle) * heart.speed + wave;
          heart.y += math.sin(heart.angle) * heart.speed - 1.8;

          final hsl = HSLColor.fromColor(heart.color);
          final newHue = (hsl.hue + 2.5) % 360;
          heart.color = hsl.withHue(newHue).toColor();
        } else {
          final double sway =
              math.sin(heart.lifeTimeProgress * 5.0 + heart.swayPhase) * 0.8;
          heart.x += math.cos(heart.angle) * heart.speed + sway;
          heart.y += math.sin(heart.angle) * heart.speed - 1.2;
        }

        final double fadeRate = heart.style == 'cosmic' ? 0.015 : 0.02;
        heart.opacity -= fadeRate;

        if (heart.opacity <= 0 || heart.y < -100 || heart.x < -100) {
          _hearts.removeAt(i);
        }
      }
    });
  }

  void spawnHeart(Offset globalPosition) {
    if (!mounted) return;
    
    final bool liteMode = UiPrefs.notifier.value.liteMode;
    if (liteMode && _hearts.length > 40) return;
    if (_hearts.length > 150) return; // Hard limit

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      return;
    }
    
    spawnExplosion(globalPosition);
  }

  void spawnExplosion(Offset globalPosition, {int count = 8}) {
    if (!mounted) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      return;
    }
    
    final bool liteMode = UiPrefs.notifier.value.liteMode;
    if (liteMode && _hearts.length > 50) return;
    if (_hearts.length > 150) return; // Hard limit

    int finalCount = liteMode ? math.min(count, 3) : count;

    const palettes = [
      [
        Color(0xFFFFB7D5),
        Color(0xFFFF8FB7),
        Color(0xFFFFD6EE),
        Color(0xFFFF6BA8)
      ],
      [
        Color(0xFFD8A4FF),
        Color(0xFFC680FF),
        Color(0xFFEDD5FF),
        Color(0xFFB85EFF)
      ],
      [
        Color(0xFFA8C8FF),
        Color(0xFF7AABFF),
        Color(0xFFCCE0FF),
        Color(0xFF5591FF)
      ],
      [
        Color(0xFFFFEAA0),
        Color(0xFFFFD966),
        Color(0xFFFFF3CC),
        Color(0xFFFFCB33)
      ],
      [
        Color(0xFFA8F0D0),
        Color(0xFF6EDBB4),
        Color(0xFFCCF7E5),
        Color(0xFF3DC98E)
      ],
      [
        Color(0xFFFFCBA4),
        Color(0xFFFFAA77),
        Color(0xFFFFE3CC),
        Color(0xFFFF8844)
      ],
    ];

    try {
      final localPosition = renderBox.globalToLocal(globalPosition);
      final random = math.Random();
      final palette = palettes[random.nextInt(palettes.length)];

      setState(() {
        for (int i = 0; i < finalCount; i++) {
          final angle = random.nextDouble() * math.pi * 2;
          final speed = 1.5 + random.nextDouble() * 3.0;
          final size = 16.0 +
              random.nextDouble() *
                  20.0; // Slightly larger to compensate for fewer hearts

          _hearts.add(
            TinyHeart(
              x: localPosition.dx,
              y: localPosition.dy,
              angle: angle,
              speed: speed,
              size: size,
              color: palette[random.nextInt(palette.length)],
              style: widget.style,
            ),
          );
        }
      });
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
    } catch (e) {
      debugPrint('[_TapHeartsOverlay] spawnExplosion error: $e');
    }
  }

  void spawnFlyingToExplosion(Offset startPosition, Offset targetPosition, {int count = 6}) {
    if (!mounted) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

    const palettes = [
      [Color(0xFFFFB7D5), Color(0xFFFF8FB7), Color(0xFFFFD6EE), Color(0xFFFF6BA8)],
      [Color(0xFFD8A4FF), Color(0xFFC680FF), Color(0xFFEDD5FF), Color(0xFFB85EFF)],
      [Color(0xFFA8C8FF), Color(0xFF7AABFF), Color(0xFFCCE0FF), Color(0xFF5591FF)],
      [Color(0xFFFFEAA0), Color(0xFFFFD966), Color(0xFFFFF3CC), Color(0xFFFFCB33)],
    ];

    try {
      final bool liteMode = UiPrefs.notifier.value.liteMode;
      if (liteMode && _hearts.length > 50) return;
      if (_hearts.length > 150) return;
      
      int finalCount = liteMode ? math.min(count, 2) : count;

      final localStart = renderBox.globalToLocal(startPosition);
      final localTarget = renderBox.globalToLocal(targetPosition);
      final random = math.Random();
      final palette = palettes[random.nextInt(palettes.length)];

      setState(() {
        for (int i = 0; i < finalCount; i++) {
          final speed = 4.0 + random.nextDouble() * 4.0;
          final size = 16.0 + random.nextDouble() * 12.0;
          final heart = TinyHeart(
            x: localStart.dx,
            y: localStart.dy,
            angle: random.nextDouble() * math.pi * 2,
            speed: speed,
            size: size,
            color: palette[random.nextInt(palette.length)],
            style: widget.style,
          );
          heart.isFlyingToTarget = true;
          heart.targetX = localTarget.dx;
          heart.targetY = localTarget.dy;
          heart.flightPathType = random.nextInt(3); // 0: straight, 1: wave, 2: erratic
          _hearts.add(heart);
        }
      });
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
    } catch (e) {
      debugPrint('[_TapHeartsOverlay] spawnFlyingToExplosion error: $e');
    }
  }

  void spawnFlyingStickers(Offset startPosition, Offset targetPosition, String assetPath, {int count = 3}) {
    if (!mounted) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

    try {
      final bool liteMode = UiPrefs.notifier.value.liteMode;
      if (liteMode && _flyingStickers.length > 30) return;
      if (_flyingStickers.length > 100) return;

      int finalCount = liteMode ? math.min(count, 1) : count;

      final localStart = renderBox.globalToLocal(startPosition);
      final localTarget = renderBox.globalToLocal(targetPosition);
      final random = math.Random();

      setState(() {
        for (int i = 0; i < finalCount; i++) {
          final speed = 4.0 + random.nextDouble() * 4.0;
          final size = 48.0 + random.nextDouble() * 16.0;
          
          _flyingStickers.add(
            FlyingStickerParticle(
              assetPath: assetPath,
              x: localStart.dx,
              y: localStart.dy,
              targetX: localTarget.dx,
              targetY: localTarget.dy,
              size: size,
              speed: speed,
              flightPathType: random.nextInt(3),
            ),
          );
        }
      });
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
    } catch (e) {
      debugPrint('[_TapHeartsOverlay] spawnFlyingStickers error: $e');
    }
  }

  void spawnLocalExplosion(Offset localPosition, {int count = 8}) {
    if (!mounted) return;
    const palettes = [
      [
        Color(0xFFFFB7D5),
        Color(0xFFFF8FB7),
        Color(0xFFFFD6EE),
        Color(0xFFFF6BA8)
      ],
      [
        Color(0xFFD8A4FF),
        Color(0xFFC680FF),
        Color(0xFFEDD5FF),
        Color(0xFFB85EFF)
      ],
      [
        Color(0xFFA8C8FF),
        Color(0xFF7AABFF),
        Color(0xFFCCE0FF),
        Color(0xFF5591FF)
      ],
      [
        Color(0xFFFFEAA0),
        Color(0xFFFFD966),
        Color(0xFFFFF3CC),
        Color(0xFFFFCB33)
      ],
      [
        Color(0xFFA8F0D0),
        Color(0xFF6EDBB4),
        Color(0xFFCCF7E5),
        Color(0xFF3DC98E)
      ],
      [
        Color(0xFFFFCBA4),
        Color(0xFFFFAA77),
        Color(0xFFFFE3CC),
        Color(0xFFFF8844)
      ],
    ];

    try {
      final random = math.Random();
      final palette = palettes[random.nextInt(palettes.length)];

      setState(() {
        for (int i = 0; i < count; i++) {
          final angle = random.nextDouble() * math.pi * 2;
          final speed = 1.5 + random.nextDouble() * 3.0;
          final size = 16.0 + random.nextDouble() * 20.0;

          _hearts.add(
            TinyHeart(
              x: localPosition.dx,
              y: localPosition.dy,
              angle: angle,
              speed: speed,
              size: size,
              color: palette[random.nextInt(palette.length)],
              style: widget.style,
            ),
          );
        }
      });
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
    } catch (e) {
      debugPrint('[TapHeartsOverlay] spawnLocalExplosion error: $e');
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hearts.isEmpty && _flyingStickers.isEmpty) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_hearts.isNotEmpty)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HeartsPainter(hearts: _hearts),
                size: Size.infinite,
              ),
            ),
          ),
        for (final sticker in _flyingStickers)
          Positioned(
            left: sticker.x - sticker.size / 2,
            top: sticker.y - sticker.size / 2,
            child: Image.asset(
              sticker.assetPath,
              width: sticker.size,
              height: sticker.size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class HeartsPainter extends CustomPainter {
  final List<TinyHeart> hearts;
  static final Path _baseHeartPath = _createBaseHeartPath();
  static final Path _baseStarPath = _createBaseStarPath();

  HeartsPainter({required this.hearts});

  static Path _createBaseHeartPath() {
    final Path path = Path();
    const double width = 1.0;
    const double height = 0.9;
    path.moveTo(0, height * 0.3);
    path.cubicTo(-width * 0.5, -height * 0.2, -width, height * 0.4, 0, height);
    path.moveTo(0, height * 0.3);
    path.cubicTo(width * 0.5, -height * 0.2, width, height * 0.4, 0, height);
    return path;
  }

  static Path _createBaseStarPath() {
    final Path path = Path();
    const double r = 1.0;
    path.moveTo(0, -r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.quadraticBezierTo(0, 0, 0, r);
    path.quadraticBezierTo(0, 0, -r, 0);
    path.quadraticBezierTo(0, 0, 0, -r);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final heart in hearts) {
      if (heart.opacity <= 0) continue;

      final double progress = heart.lifeTimeProgress;
      double drawSize = heart.size;
      final mainPaint = Paint()..style = PaintingStyle.fill;

      if (heart.style == 'cosmic') {
        drawSize = heart.size * (1.0 + 0.15 * math.sin(progress * 18.0));

        // Vẽ 1 sao bay quanh (giảm từ 2 xuống 1 để chống lag)
        final double orbitAngle = progress * 8.0;
        final double orbitRadius = drawSize * 0.8;
        final double sx = heart.x + math.cos(orbitAngle) * orbitRadius;
        final double sy = heart.y + math.sin(orbitAngle) * orbitRadius;

        final trailPaint = Paint()
          ..style = PaintingStyle.fill
          ..color =
              const Color(0xFFFFD700).withValues(alpha: heart.opacity * 0.4);
        _drawStar(canvas, trailPaint, sx, sy, drawSize * 0.25);

        // Chỉ vẽ 1 lớp Glow thay vì 2 lớp
        final glowColor =
            const Color(0xFFBF55EC).withValues(alpha: heart.opacity * 0.15);
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = glowColor;
        _drawHeartShape(canvas, glowPaint, heart.x, heart.y, drawSize * 1.3);

        mainPaint.color = heart.color.withValues(alpha: heart.opacity);
        _drawHeartShape(canvas, mainPaint, heart.x, heart.y, drawSize);
      } else if (heart.style == 'aurora') {
        // Rút gọn Trail của Aurora (chỉ vẽ 1 điểm đuôi dài nhất để chống lag)
        if (heart.trail.isNotEmpty) {
          final Offset pos = heart.trail.first;
          final trailPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = heart.color.withValues(alpha: heart.opacity * 0.2);
          _drawStar(canvas, trailPaint, pos.dx, pos.dy, drawSize * 0.2);
        }

        // Chỉ vẽ 1 lớp Glow thay vì 2
        final glowColor = heart.color.withValues(alpha: heart.opacity * 0.15);
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = glowColor;
        _drawHeartShape(canvas, glowPaint, heart.x, heart.y, drawSize * 1.25);

        mainPaint.color = heart.color.withValues(alpha: heart.opacity);
        _drawHeartShape(canvas, mainPaint, heart.x, heart.y, drawSize);
      } else {
        drawSize = heart.size * (1.0 + 0.08 * math.sin(progress * 12.0));
        mainPaint.color = heart.color.withValues(alpha: heart.opacity);
        _drawHeartShape(canvas, mainPaint, heart.x, heart.y, drawSize);
      }
    }
  }

  void _drawHeartShape(
      Canvas canvas, Paint paint, double x, double y, double size) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(size, size);
    canvas.drawPath(_baseHeartPath, paint);
    canvas.restore();
  }

  void _drawStar(
      Canvas canvas, Paint paint, double x, double y, double radius) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(radius, radius);
    canvas.drawPath(_baseStarPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HeartsPainter oldDelegate) => true;
}
