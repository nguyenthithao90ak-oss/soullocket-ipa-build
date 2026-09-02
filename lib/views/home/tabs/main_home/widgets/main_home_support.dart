// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../main_home_tab.dart';

class _BlinkingAvatarHint extends StatefulWidget {
  const _BlinkingAvatarHint();

  @override
  State<_BlinkingAvatarHint> createState() => _BlinkingAvatarHintState();
}

class _BlinkingAvatarHintState extends State<_BlinkingAvatarHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.28,
      end: 0.78,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          ),
          child: Text(
            context.tr('home_chnnh_719c35'),
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class ShootingHeartEffect extends StatefulWidget {
  final VoidCallback onComplete;
  final bool shootToRight;
  final String emoji;
  final String? assetPath;
  final String? imageUrl;
  final bool hasCollision;

  const ShootingHeartEffect({
    super.key,
    required this.onComplete,
    required this.shootToRight,
    this.emoji = '❤️',
    this.assetPath,
    this.imageUrl,
    this.hasCollision = false,
  });

  @override
  State<ShootingHeartEffect> createState() => _ShootingHeartEffectState();
}

class _ParticleData {
  final double delay;
  final double flightDuration;
  final double peakHeight;
  final double size;
  final double baseRotation;
  final bool willCollide;
  final double wobblePhase;
  final double wobbleAmplitude;

  _ParticleData({
    required this.delay,
    required this.flightDuration,
    required this.peakHeight,
    required this.size,
    required this.baseRotation,
    this.willCollide = false,
    this.wobblePhase = 0.0,
    this.wobbleAmplitude = 0.0,
  });
}

class _ShootingHeartEffectState extends State<ShootingHeartEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ParticleData> _particles = [];
  late final List<Widget> _particleWidgets;

  late final Widget _expSparkle;
  late final Widget _expAssetOrEmoji;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    final random = Random();
    const particleCount = 3;
    final hasAsset =
        widget.assetPath != null && widget.assetPath!.trim().isNotEmpty;
    final hasImage =
        widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty;

    for (int i = 0; i < particleCount; i++) {
      _particles.add(
        _ParticleData(
          delay: i * 0.08 + random.nextDouble() * 0.06,
          flightDuration: 0.62 + random.nextDouble() * 0.08,
          peakHeight: 0.9 + random.nextDouble() * 0.5 + i * 0.15,
          size: 48.0 + random.nextDouble() * 14 + i * 3,
          baseRotation: (random.nextDouble() - 0.5) * 0.5,
          willCollide: widget.hasCollision && i == 0,
          wobblePhase: random.nextDouble() * 2 * pi,
          wobbleAmplitude: 0.03 + random.nextDouble() * 0.04,
        ),
      );
    }

    _expSparkle = const RepaintBoundary(
      child: Text('✨', style: TextStyle(fontSize: 16)),
    );
    if (hasAsset) {
      _expAssetOrEmoji = RepaintBoundary(
        child: R2StickerImage(
          widget.assetPath!,
          width: 16,
          height: 16,
          fit: BoxFit.contain,
          errorWidget: const Text('✨', style: TextStyle(fontSize: 16)),
        ),
      );
    } else {
      _expAssetOrEmoji = const RepaintBoundary(
        child: Text('✨', style: TextStyle(fontSize: 16)),
      );
    }

    _particleWidgets = List.generate(_particles.length, (i) {
      final p = _particles[i];
      return RepaintBoundary(
        child: hasAsset
            ? R2StickerImage(
                widget.assetPath!,
                width: p.size,
                height: p.size,
                fit: BoxFit.contain,
                errorWidget: const SizedBox.shrink(),
              )
            : const SizedBox.shrink(),
      );
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final effectWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaSize.width;
        final effectHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaSize.height;
        final halfWidth = effectWidth / 2;
        final verticalTravel = effectHeight * 0.30;
        final baselineLift = effectHeight * 0.06;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(_particles.length, (index) {
                final p = _particles[index];
                final particleWidget = _particleWidgets[index];

                double t = (_controller.value - p.delay) / p.flightDuration;
                if (t < 0) t = 0;
                if (t > 1) t = 1;

                final startX = widget.shootToRight ? -0.7 : 0.7;
                final endX = widget.shootToRight ? 0.7 : -0.7;
                final curveX = Curves.easeInOutCubic.transform(t);
                final wobbleOffset =
                    sin(t * 3 * pi + p.wobblePhase) * p.wobbleAmplitude;
                final currentX =
                    startX + (endX - startX) * curveX + wobbleOffset;

                final currentY =
                    -p.peakHeight * (1 - 4 * (t - 0.5) * (t - 0.5));

                double currentScale = 1.0;
                double currentOpacity = 1.0;
                bool isCollidingNow = false;
                bool isLanding = false;

                if (p.willCollide && t >= 0.45 && t <= 0.6) {
                  final collideProgress = ((t - 0.45) / 0.15).clamp(0.0, 1.0);
                  currentScale = 1.0 - collideProgress;
                  currentOpacity = 1.0 - collideProgress;
                  isCollidingNow = true;
                } else if (p.willCollide && t > 0.6) {
                  currentScale = 0.0;
                  currentOpacity = 0.0;
                } else if (t < 0.12) {
                  final popT = Curves.elasticOut.transform(
                    (t / 0.12).clamp(0.0, 1.0),
                  );
                  currentScale = popT;
                } else if (t > 0.78) {
                  isLanding = true;
                  final landT = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
                  final bounceT = sin(landT * pi * 2.5) * (1.0 - landT) * 0.25;
                  currentScale = (1.0 - landT * 0.7) + bounceT;
                  currentOpacity = (1.0 - landT).clamp(0.0, 1.0);
                }

                final translateX = currentX * halfWidth;
                final effectiveY = p.willCollide && t >= 0.45
                    ? (currentY * (1 - ((t - 0.45) / 0.15).clamp(0.0, 1.0)))
                    : currentY;
                final translateY = (effectiveY * verticalTravel) - baselineLift;

                final rotationSpeed = t < 0.3 ? 1.5 : (t > 0.7 ? 0.3 : 0.8);
                final mainWidget = Transform.rotate(
                  angle:
                      p.baseRotation +
                      (t *
                          pi *
                          2 *
                          rotationSpeed *
                          (widget.shootToRight ? 1 : -1)),
                  child: Transform.scale(
                    scale: currentScale,
                    child: particleWidget,
                  ),
                );

                final List<Widget> trailAndExplosion = [];

                if (t > 0.05 &&
                    t < 0.85 &&
                    currentOpacity > 0 &&
                    !p.willCollide) {
                  for (int ti = 1; ti <= 3; ti++) {
                    final trailT = (t - ti * 0.04).clamp(0.0, 1.0);
                    final trailCurveX = Curves.easeInOutCubic.transform(trailT);
                    final trailWobble =
                        sin(trailT * 3 * pi + p.wobblePhase) *
                        p.wobbleAmplitude;
                    final trailX =
                        startX + (endX - startX) * trailCurveX + trailWobble;
                    final trailY =
                        -p.peakHeight *
                        (1 - 4 * (trailT - 0.5) * (trailT - 0.5));
                    final trailTx = trailX * halfWidth;
                    final trailTy = (trailY * verticalTravel) - baselineLift;
                    final trailOpacity = (0.35 - ti * 0.1).clamp(0.0, 0.35);
                    final trailSize = p.size * (0.6 - ti * 0.12);

                    trailAndExplosion.add(
                      Positioned.fill(
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(trailTx, trailTy),
                            child: Opacity(
                              opacity: trailOpacity * currentOpacity,
                              child: Container(
                                width: trailSize,
                                height: trailSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(
                                        0xFFFF80AB,
                                      ).withValues(alpha: 0.5),
                                      const Color(
                                        0xFFFF80AB,
                                      ).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }

                if (isCollidingNow) {
                  final collideProgress = ((t - 0.45) / 0.15).clamp(0.0, 1.0);
                  final ext = collideProgress;
                  final expOpacity = (1.0 - ext).clamp(0.0, 1.0);

                  for (int ri = 0; ri < 2; ri++) {
                    final rippleT = (ext - ri * 0.15).clamp(0.0, 1.0);
                    final rippleSize = rippleT * 120.0;
                    final rippleOpacity = (0.5 * (1.0 - rippleT)).clamp(
                      0.0,
                      0.5,
                    );
                    trailAndExplosion.add(
                      Positioned.fill(
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(translateX, translateY),
                            child: Opacity(
                              opacity: rippleOpacity,
                              child: Container(
                                width: rippleSize,
                                height: rippleSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF4081),
                                    width: 2.0 * (1.0 - rippleT),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  for (int i = 0; i < 8; i++) {
                    final angle = i * (2 * pi / 8) + (p.baseRotation * 3);
                    final distance = ext * 90.0;
                    final dx = cos(angle) * distance;
                    final dy = sin(angle) * distance;

                    final bool isSparkle = i % 2 == 0;
                    final Widget expChild = isSparkle
                        ? _expSparkle
                        : _expAssetOrEmoji;
                    final expScale = 0.5 + (1.0 - ext) * 0.9;

                    trailAndExplosion.add(
                      Positioned.fill(
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(translateX + dx, translateY + dy),
                            child: Transform.scale(
                              scale: expScale,
                              child: Opacity(
                                opacity: expOpacity,
                                child: expChild,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                } else if (isLanding && !p.willCollide) {
                  final landT = ((t - 0.78) / 0.22).clamp(0.0, 1.0);

                  for (int ri = 0; ri < 2; ri++) {
                    final rippleT = (landT - ri * 0.2).clamp(0.0, 1.0);
                    if (rippleT <= 0) continue;
                    final rippleSize = rippleT * 80.0;
                    final rippleOpacity = (0.4 * (1.0 - rippleT)).clamp(
                      0.0,
                      0.4,
                    );
                    trailAndExplosion.add(
                      Positioned.fill(
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(translateX, translateY),
                            child: Opacity(
                              opacity: rippleOpacity,
                              child: Container(
                                width: rippleSize,
                                height: rippleSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF80AB),
                                    width: 1.5 * (1.0 - rippleT),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (landT > 0.2) {
                    final burstT = ((landT - 0.2) / 0.8).clamp(0.0, 1.0);
                    final expOpacity = (1.0 - burstT).clamp(0.0, 1.0);
                    for (int i = 0; i < 6; i++) {
                      final angle = i * (2 * pi / 6) + (p.baseRotation * 2);
                      final distance = burstT * 60.0;
                      final dx = cos(angle) * distance;
                      final dy = sin(angle) * distance;
                      final bool isSparkle = i % 2 == 0;
                      final Widget expChild = isSparkle
                          ? _expSparkle
                          : _expAssetOrEmoji;
                      final expScale = 0.4 + (1.0 - burstT) * 0.6;

                      trailAndExplosion.add(
                        Positioned.fill(
                          child: Center(
                            child: Transform.translate(
                              offset: Offset(translateX + dx, translateY + dy),
                              child: Transform.scale(
                                scale: expScale,
                                child: Opacity(
                                  opacity: expOpacity,
                                  child: expChild,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...trailAndExplosion,
                    Positioned.fill(
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(translateX, translateY),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              if (currentOpacity > 0 && currentScale > 0)
                                Opacity(
                                  opacity: currentOpacity,
                                  child: mainWidget,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            );
          },
        );
      },
    );
  }
}

// Painter cho viền nét đứt linh hoạt
class _DashedBorderPainter extends CustomPainter {
  final Color color = Colors.grey;
  final double radius = 24.0;
  static const double strokeWidth = 1.6;

  _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Tối ưu: Dùng path cơ bản thay vì computeMetrics liên tục gây lag khi cuộn
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Fallback: Vẽ viền solid nhạt thay vì dashed để tránh lag trên Web
    // Vì computeMetrics rất tốn tài nguyên trên Web CanvasKit.
    paint.color = color.withValues(alpha: 0.5);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      color != old.color || radius != old.radius;
}

class _HeartbeatWidget extends StatefulWidget {
  final Widget child;
  const _HeartbeatWidget({required this.child});

  @override
  State<_HeartbeatWidget> createState() => _HeartbeatWidgetState();
}

class _HeartbeatWidgetState extends State<_HeartbeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

class FallingEffect extends StatefulWidget {
  final String type;
  final bool isDark;
  final String density;
  const FallingEffect({
    super.key,
    required this.type,
    required this.isDark,
    this.density = 'balanced',
  });

  @override
  State<FallingEffect> createState() => _FallingEffectState();
}

class _FallingEffectState extends State<FallingEffect>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  final List<_FallingItem> _items = [];
  final Random _random = Random();
  late String _type;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _type = widget.type;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _initItems();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant FallingEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type || oldWidget.density != widget.density) {
      _type = widget.type;
      _initItems(reset: true);
    }
  }

  void _initItems({bool reset = false}) {
    if (reset) _items.clear();
    final type = _type;
    if (type == 'off') return;

    final baseCount = switch (type) {
      'meteors' => 8,
      'bubbles' => 12,
      'snow' => 15,
      'leaves' => 10,
      'sparkles' => 12,
      'stars' => 10,
      _ => 10,
    };
    final count = switch (widget.density) {
      'low' => max(1, (baseCount * 0.18).round()),
      'high' => min(baseCount, max(3, (baseCount * 0.78).round())),
      _ => min(baseCount, max(2, (baseCount * 0.52).round())),
    };
    for (int i = 0; i < count; i++) {
      final baseSize = switch (type) {
        'sparkles' => 10.0,
        'meteors' => 18.0,
        'bubbles' => 22.0,
        'snow' => 8.0,
        'leaves' => 15.0,
        'stars' => 12.0,
        _ => 20.0,
      };
      final size = _random.nextDouble() * baseSize + (baseSize * 0.5);
      final speed = switch (type) {
        'meteors' => _random.nextDouble() * 0.004 + 0.002,
        'bubbles' => _random.nextDouble() * 0.0016 + 0.0008,
        'sparkles' => _random.nextDouble() * 0.0018 + 0.001,
        'snow' => _random.nextDouble() * 0.001 + 0.0005,
        'leaves' => _random.nextDouble() * 0.0015 + 0.0008,
        _ => _random.nextDouble() * 0.002 + 0.001,
      };
      _items.add(
        _FallingItem(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: size,
          speed: speed,
          rotationSpeed: _random.nextDouble() * 0.02,
          opacity: _random.nextDouble() * 0.5 + 0.2,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_type == 'off') return const SizedBox.shrink();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          for (var item in _items) {
            item.y += item.speed;
            if (item.y > 1.1) {
              item.y = -0.1;
              item.x = _random.nextDouble();
            }
            item.rotation += item.rotationSpeed;
          }
          return CustomPaint(
            painter: _FallingPainter(
              _items,
              type: _type,
              isDark: widget.isDark,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double width = size.width;
    final double height = size.height;
    final Path path = Path();
    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.2 * width,
      height * 0.1,
      -0.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.8 * width,
      height * 0.1,
      1.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HeartBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final Path path = Path();
    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.2 * width,
      height * 0.1,
      -0.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.8 * width,
      height * 0.1,
      1.25 * width,
      height * 0.6,
      0.5 * width,
      height,
    );

    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _FallingItem {
  double x, y, size, speed, rotation, rotationSpeed, opacity;
  _FallingItem({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rotationSpeed,
    required this.opacity,
  }) : rotation = 0.0;
}

class _FallingPainter extends CustomPainter {
  final List<_FallingItem> items;
  final String type;
  final bool isDark;

  // Reusable paint and path objects to prevent garbage collection pressure
  final Paint _paint = Paint();
  final Path _reusablePath = Path();

  _FallingPainter(this.items, {required this.type, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Disable anti-alias for simple small particles to boost rendering speed
    final isSimpleEffect =
        type == 'snow' || type == 'bubbles' || type == 'sparkles';
    _paint.isAntiAlias = !isSimpleEffect;

    for (var item in items) {
      canvas.save();
      canvas.translate(item.x * size.width, item.y * size.height);
      canvas.rotate(item.rotation);

      final s = item.size;
      switch (type) {
        case 'sparkles':
          _paint
            ..color = (isDark ? const Color(0xFFFFF1B8) : Colors.white)
                .withValues(alpha: item.opacity)
            ..style = PaintingStyle.fill;
          _drawSparkle(canvas, _paint, s);
          break;
        case 'meteors':
          _paint
            ..color = (isDark ? const Color(0xFF9EE7FF) : Colors.white)
                .withValues(alpha: item.opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (s * 0.12).clamp(1.0, 3.0);
          canvas.drawLine(
            Offset(-s * 0.7, -s * 0.2),
            Offset(s * 0.7, s * 0.2),
            _paint,
          );
          _paint
            ..style = PaintingStyle.fill
            ..strokeWidth = 0;
          canvas.drawCircle(
            Offset(s * 0.75, s * 0.22),
            (s * 0.12).clamp(1.5, 4.0),
            _paint,
          );
          break;
        case 'bubbles':
          _paint
            ..color =
                (isDark ? const Color(0xFFB3E5FC) : const Color(0xFFFFFFFF))
                    .withValues(alpha: item.opacity * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (s * 0.08).clamp(1.0, 2.5);
          canvas.drawCircle(Offset.zero, s * 0.35, _paint);
          _paint
            ..color =
                (isDark ? const Color(0xFFE1F5FE) : const Color(0xFFFFFFFF))
                    .withValues(alpha: item.opacity * 0.35)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(-s * 0.12, -s * 0.12), s * 0.12, _paint);
          break;
        case 'leaves':
          _paint
            ..color = const Color(0xFFE65100).withValues(alpha: item.opacity)
            ..style = PaintingStyle.fill;
          _reusablePath.reset();
          _reusablePath
            ..moveTo(0, -s * 0.5)
            ..quadraticBezierTo(s * 0.4, -s * 0.2, s * 0.3, s * 0.2)
            ..quadraticBezierTo(s * 0.1, s * 0.4, 0, s * 0.5)
            ..quadraticBezierTo(-s * 0.1, s * 0.4, -s * 0.3, s * 0.2)
            ..quadraticBezierTo(-s * 0.4, -s * 0.2, 0, -s * 0.5);
          canvas.drawPath(_reusablePath, _paint);
          break;
        case 'stars':
          _paint
            ..color = const Color(0xFFFFD54F).withValues(alpha: item.opacity)
            ..style = PaintingStyle.fill;
          _drawStar(canvas, _paint, s);
          break;
        case 'snow':
          _paint
            ..color = Colors.white.withValues(alpha: item.opacity)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset.zero, s * 0.2, _paint);
          break;
        case 'hearts':
        default:
          _paint
            ..color =
                (isDark ? const Color(0xFFFF7AA2) : const Color(0xFFFF4D73))
                    .withValues(alpha: item.opacity)
            ..style = PaintingStyle.fill;
          _reusablePath.reset();
          _reusablePath
            ..moveTo(0, s * 0.35)
            ..cubicTo(0, s * 0.1, -s * 0.45, 0, -s * 0.45, s * 0.35)
            ..cubicTo(-s * 0.45, s * 0.6, 0, s * 0.9, 0, s)
            ..cubicTo(0, s * 0.9, s * 0.45, s * 0.6, s * 0.45, s * 0.35)
            ..cubicTo(s * 0.45, 0, 0, s * 0.1, 0, s * 0.35);
          canvas.drawPath(_reusablePath, _paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawSparkle(Canvas canvas, Paint paint, double s) {
    final outer = s * 0.35;
    final inner = s * 0.14;
    _reusablePath.reset();
    for (int i = 0; i < 8; i++) {
      final angle = (i * 3.1415926535) / 4;
      final r = i.isEven ? outer : inner;
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) {
        _reusablePath.moveTo(x, y);
      } else {
        _reusablePath.lineTo(x, y);
      }
    }
    _reusablePath.close();
    canvas.drawPath(_reusablePath, paint);
  }

  void _drawStar(Canvas canvas, Paint paint, double s) {
    final outer = s * 0.4;
    final inner = s * 0.15;
    _reusablePath.reset();
    for (int i = 0; i < 10; i++) {
      final angle = (i * 3.1415926535) / 5 - (3.1415926535 / 2);
      final r = i.isEven ? outer : inner;
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) {
        _reusablePath.moveTo(x, y);
      } else {
        _reusablePath.lineTo(x, y);
      }
    }
    _reusablePath.close();
    canvas.drawPath(_reusablePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _InteractionSuccessDialog extends StatelessWidget {
  final String interactionType;
  final String title;
  final String body;
  final String partnerName;
  final bool partnerOnline;

  const _InteractionSuccessDialog({
    required this.interactionType,
    required this.title,
    required this.body,
    required this.partnerName,
    required this.partnerOnline,
  });

  @override
  Widget build(BuildContext context) {
    final presetAssetPath = _maybePresetForInteractionType(
      interactionType,
    )?.assetPath;

    final (
      dynamic iconOrEmoji,
      List<Color> gradient,
      Color accent,
    ) = switch (interactionType) {
      'hot' => (
        Icons.local_fire_department_rounded,
        const [Color(0xFFFFF2CC), Color(0xFFFFC36B)],
        const Color(0xFFE87722),
      ),
      'warmth' => (
        Icons.cloud_rounded,
        const [Color(0xFFEAF8FF), Color(0xFFC6EEFF)],
        const Color(0xFF1497C9),
      ),
      _ => (
        _presetForInteractionType(interactionType).emoji,
        _presetForInteractionType(interactionType).gradient,
        _presetForInteractionType(interactionType).accent,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blurry backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: FastBackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                fallbackColor: Colors.black.withValues(alpha: 0.34),
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.20),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.88), accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: presetAssetPath != null
                        ? _buildInteractionVisual(
                            visual: iconOrEmoji,
                            assetPath: presetAssetPath,
                            size: 56,
                            emojiSize: 40,
                            iconColor: Colors.white,
                            emojiShadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : iconOrEmoji is IconData
                        ? Icon(iconOrEmoji, color: Colors.white, size: 55)
                        : Center(
                            child: Text(
                              iconOrEmoji.toString(),
                              style: TextStyle(
                                fontSize: 40,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  SLSpacing.h16,
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: const Color(0xFF5C6270),
                    ),
                  ),
                  SLSpacing.h16,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      partnerOnline
                          ? '$partnerName đang online, nên người ấy sẽ thấy ngay trên màn hình chính luôn đó.'
                          : '$partnerName chưa mở nhà, nhưng lời nhắn này đã được giữ lại thật cẩn thận.',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.45,
                        color: const Color(0xFF444444),
                      ),
                    ),
                  ),
                  SLSpacing.h12,
                  Text(
                    context.tr('home_chmnhrango_80519e'),
                    style: SLTheme.quicksand(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B8B8B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissYouAlertPayload {
  final String type;
  final String fromUid;
  final String fromRole;
  final String toRole;
  final String title;
  final String message;
  final String body;
  final String fromName;
  final String fromAvatar;
  final String toName;
  final int sentAtMs;
  final String emoji;
  final String assetPath;

  const _MissYouAlertPayload({
    required this.type,
    required this.fromUid,
    required this.fromRole,
    required this.toRole,
    required this.title,
    required this.message,
    required this.body,
    required this.fromName,
    required this.fromAvatar,
    required this.toName,
    required this.sentAtMs,
    this.emoji = '💖',
    this.assetPath = '',
  });

  factory _MissYouAlertPayload.fromMap(Map<String, dynamic> map) {
    int readMs(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return _MissYouAlertPayload(
      type: (map['type']?.toString().trim().isNotEmpty ?? false)
          ? map['type'].toString().trim()
          : 'miss',
      fromUid: map['fromUid']?.toString() ?? '',
      fromRole: map['fromRole']?.toString() ?? '',
      toRole: map['toRole']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      fromName:
          (map['from'] ??
                  map['fromName'] ??
                  L10nService().translate('home_ngiy_5bab37'))
              .toString(),
      fromAvatar: map['fromAvatar']?.toString() ?? '',
      toName: map['toName']?.toString() ?? '',
      sentAtMs: (() {
        final value = readMs(map['sentAt'] ?? map['timestamp'] ?? map['ts']);
        return value > 0 ? value : DateTime.now().millisecondsSinceEpoch;
      })(),
      emoji: map['emoji']?.toString() ?? '💖',
      assetPath: map['assetPath']?.toString() ?? '',
    );
  }
}

class _MissYouScreen extends StatefulWidget {
  final _MissYouAlertPayload payload;

  const _MissYouScreen({required this.payload});

  @override
  __MissYouScreenState createState() => __MissYouScreenState();
}

class __MissYouScreenState extends State<_MissYouScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Auto close after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (
      dynamic iconOrEmoji,
      gradient,
      accent,
      defaultTitle,
      defaultMessage,
      lottieUrl,
    ) = switch (widget.payload.type) {
      'hot' => (
        widget.payload.emoji,
        <Color>[
          const Color(0xFFFFA63D).withValues(alpha: 0.92),
          const Color(0xFFE86C00).withValues(alpha: 0.96),
        ],
        const Color(0xFFFFD18A),
        '${widget.payload.fromName} nhắc bạn uống nước!',
        context.tr('home_bnkiaangnn_c62597'),
        null,
      ),
      'warmth' => (
        widget.payload.emoji,
        <Color>[
          const Color(0xFF49C5F6).withValues(alpha: 0.9),
          const Color(0xFF0E8FC3).withValues(alpha: 0.95),
        ],
        const Color(0xFFC8F1FF),
        '${widget.payload.fromName} nhắc bạn giữ ấm!',
        context.tr('home_bnkiaangma_0a9e8e'),
        null,
      ),
      'kiss' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'kiss',
        ).gradient.map((color) => color.withValues(alpha: 0.92)).toList(),
        Colors.white,
        '${widget.payload.fromName} gửi bạn một nụ hôn!',
        context.tr('home_chtmtcitht_1ca200'),
        'https://assets9.lottiefiles.com/packages/lf20_mjfquvsi.json',
      ),
      'hug' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'hug',
        ).gradient.map((color) => color.withValues(alpha: 0.92)).toList(),
        Colors.white,
        '${widget.payload.fromName} ôm bạn một cái!',
        context.tr('home_mtcimmmang_ce0013'),
        'https://assets10.lottiefiles.com/packages/lf20_96py9mpe.json',
      ),
      'angry' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'angry',
        ).gradient.map((color) => color.withValues(alpha: 0.92)).toList(),
        Colors.white,
        '${widget.payload.fromName} đang dỗi kìa!',
        context.tr('home_dixuthiqua_ed30d2'),
        null,
      ),
      'furious' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'furious',
        ).gradient.map((color) => color.withValues(alpha: 0.94)).toList(),
        Colors.white,
        '${widget.payload.fromName} đang tức lắm đó!',
        context.tr('home_cntcrcvaba_c0f1f0'),
        null,
      ),
      'tease' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'tease',
        ).gradient.map((color) => color.withValues(alpha: 0.92)).toList(),
        Colors.white,
        '${widget.payload.fromName} vừa trêu bạn đó!',
        context.tr('home_mtcchcyusi_aef43a'),
        null,
      ),
      'cry' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'cry',
        ).gradient.map((color) => color.withValues(alpha: 0.94)).toList(),
        Colors.white,
        '${widget.payload.fromName} đang cần bạn dỗ dành!',
        context.tr('home_hmnayngiyh_a67699'),
        null,
      ),
      'poop' => (
        widget.payload.emoji,
        _presetForInteractionType(
          'poop',
        ).gradient.map((color) => color.withValues(alpha: 0.92)).toList(),
        Colors.white,
        '${widget.payload.fromName} ném 💩 vào bạn!',
        context.tr('home_mtctrusiun_2b24ce'),
        null,
      ),
      _ => (
        widget.payload.emoji,
        _presetForInteractionType(
          widget.payload.type,
        ).gradient.map((color) => color.withValues(alpha: 0.92)).toList(),
        Colors.white,
        '${widget.payload.fromName} đang nhớ bạn!',
        context.tr('home_nhphnhilic_33736a'),
        'https://assets3.lottiefiles.com/packages/lf20_o7pajr.json',
      ),
    };
    final presetAssetPath = _maybePresetForInteractionType(
      widget.payload.type,
    )?.assetPath;
    final backgroundVisual = switch (widget.payload.type) {
      'hot' => '☀️',
      'warmth' => '❄️',
      _ => null,
    };

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: gradient.isNotEmpty ? gradient.first : Colors.black87,
            gradient: gradient.length >= 2
                ? LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortestSide = constraints.biggest.shortestSide;
                final artSize = (shortestSide * 0.56)
                    .clamp(140.0, 250.0)
                    .toDouble();
                final emojiSize = (artSize * 0.42)
                    .clamp(64.0, 106.0)
                    .toDouble();
                final reactionVisualSize = presetAssetPath != null
                    ? artSize
                    : emojiSize;
                final titleSize = (shortestSide * 0.062)
                    .clamp(22.0, 26.0)
                    .toDouble();
                final messageSize = constraints.maxWidth < 360 ? 15.0 : 16.0;
                final contentWidth = (constraints.maxWidth - 40)
                    .clamp(280.0, 460.0)
                    .toDouble();
                final verticalGap = shortestSide < 380 ? 20.0 : 30.0;
                final minHeight = constraints.maxHeight > 48
                    ? constraints.maxHeight - 48
                    : 0.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (backgroundVisual != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Transform.translate(
                                      offset: const Offset(0, -18),
                                      child: Opacity(
                                        opacity: 0.15,
                                        child: Text(
                                          backgroundVisual,
                                          style: TextStyle(
                                            fontSize: artSize * 1.22,
                                            height: 1,
                                            fontFamilyFallback: const [
                                              'Noto Color Emoji',
                                              'Apple Color Emoji',
                                              'Segoe UI Emoji',
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (lottieUrl != null)
                                  LottieAsyncLoader(
                                    url: lottieUrl,
                                    width: artSize,
                                    height: artSize,
                                    fit: BoxFit.contain,
                                    loadDelay: const Duration(
                                      milliseconds: 150,
                                    ),
                                    errorWidget: ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: _buildInteractionVisual(
                                        visual: iconOrEmoji,
                                        assetPath: presetAssetPath,
                                        size: reactionVisualSize,
                                        emojiSize: emojiSize,
                                        iconColor: accent,
                                        emojiShadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.14,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildInteractionVisual(
                                      visual: iconOrEmoji,
                                      assetPath: presetAssetPath,
                                      size: reactionVisualSize,
                                      emojiSize: emojiSize,
                                      iconColor: accent,
                                      emojiShadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.14,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(height: verticalGap),
                                Text(
                                  widget.payload.title.isNotEmpty
                                      ? widget.payload.title
                                      : defaultTitle,
                                  style: SLTheme.quicksand(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SLSpacing.h16,
                                Text(
                                  widget.payload.message.isNotEmpty
                                      ? widget.payload.message
                                      : defaultMessage,
                                  style: SLTheme.quicksand(
                                    fontSize: messageSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
