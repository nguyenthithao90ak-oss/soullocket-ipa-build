part of '../../../tabs/main_home_tab.dart';

class _AnimatedWaveBackground extends StatefulWidget {
  final String styleKey;
  final bool enableMotion;

  const _AnimatedWaveBackground({
    required this.styleKey,
    required this.enableMotion,
  });

  static bool hasMotion(String styleKey) {
    return styleKey != 'plain';
  }

  @override
  State<_AnimatedWaveBackground> createState() =>
      _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<_AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    UiPrefs.notifier.addListener(_onUiPrefsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState(_shouldAnimateFor());
  }

  @override
  void didUpdateWidget(_AnimatedWaveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleKey != widget.styleKey ||
        oldWidget.enableMotion != widget.enableMotion) {
      _syncAnimationState(_shouldAnimateFor());
    }
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_onUiPrefsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onUiPrefsChanged() {
    if (!mounted) return;
    setState(() {
      _syncAnimationState(_shouldAnimateFor());
    });
  }

  bool _shouldAnimateFor() {
    if (!_AnimatedWaveBackground.hasMotion(widget.styleKey)) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    return widget.enableMotion;
  }

  void _syncAnimationState(bool shouldAnimate) {
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_AnimatedWaveBackground.hasMotion(widget.styleKey)) {
      return const SizedBox.expand();
    }
    final shouldAnimate = _shouldAnimateFor();
    _syncAnimationState(shouldAnimate);
    if (!shouldAnimate) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _WavePainter(0, widget.styleKey),
        ),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(_controller.value, widget.styleKey),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final String styleKey;

  _WavePainter(this.animationValue, this.styleKey);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final radius = min(width, height) / 2;
    final center = Offset(width / 2, height / 2);

    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    if (styleKey == 'plain') {
      return;
    } else if (styleKey == 'glow') {
      _drawGlowHearts(canvas, width, height);
    } else if (styleKey == 'glass') {
      _drawGlassBubbles(canvas, width, height);
    } else if (styleKey == 'galaxy') {
      _drawGalaxy(canvas, width, height, center, radius);
    } else if (styleKey == 'neon') {
      _drawNeonParty(canvas, width, height, center, radius);
    } else if (styleKey == 'aurora') {
      _drawAurora(canvas, width, height, center, radius);
    } else if (styleKey == 'crystal') {
      _drawCrystal(canvas, width, height, center, radius);
    } else if (styleKey == 'candy') {
      _drawCandyPop(canvas, width, height, center, radius);
    } else if (styleKey == 'hyper') {
      _drawHyperColor(canvas, width, height, center, radius);
    } else if (styleKey == 'fireworks') {
      _drawFireworks(canvas, width, height, center, radius);
    } else if (styleKey == 'lava') {
      _drawLava(canvas, width, height, center, radius);
    } else {
      _drawDefaultWaves(canvas, width, height, center, radius);
    }
  }

  void _drawHeartPath(
    Canvas canvas,
    double x,
    double y,
    double size,
    double opacity,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFF4F93).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(x, y + size / 4);
    path.cubicTo(
      x - size,
      y - size * 0.7,
      x - size * 0.5,
      y - size,
      x,
      y - size / 4,
    );
    path.cubicTo(
      x + size * 0.5,
      y - size,
      x + size,
      y - size * 0.7,
      x,
      y + size / 4,
    );

    canvas.drawShadow(
      path,
      const Color(0xFFFF4F93).withValues(alpha: opacity * 0.3),
      4,
      false,
    );
    canvas.drawPath(path, paint);
  }

  void _drawGlowHearts(Canvas canvas, double width, double height) {
    const heartCount = 8;
    for (var i = 0; i < heartCount; i++) {
      final startX = width * ((i * 0.37 + 0.1) % 1.0);
      final speed = 0.5 + (i * 0.2 % 0.5);
      final size = 12.0 + (i * 5 % 12);

      final progress = (animationValue * speed + (i * 0.17)) % 1.0;
      final y = height + size - progress * (height + size * 2);
      final x = startX + sin((animationValue * pi * 4) + i) * 15;
      final opacity = sin(progress * pi);

      _drawHeartPath(canvas, x, y, size, opacity * 0.8);
    }
  }

  void _drawGlassBubbles(Canvas canvas, double width, double height) {
    final bubblePaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const count = 10;
    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.43 + 0.05) % 1.0);
      final speed = 0.4 + (i * 0.15 % 0.6);
      final size = 6.0 + (i * 7 % 14);

      final progress = (animationValue * speed + (i * 0.23)) % 1.0;
      final y = height + size - progress * (height + size * 2);
      final x = startX + cos((animationValue * pi * 3) + i * 2) * 12;
      final opacity = sin(progress * pi);

      bubblePaint.color = Colors.white.withValues(alpha: 0.15 * opacity);
      borderPaint.color = Colors.white.withValues(alpha: 0.4 * opacity);

      canvas.drawCircle(Offset(x, y), size, bubblePaint);
      canvas.drawCircle(Offset(x, y), size, borderPaint);
    }
  }

  void _drawDefaultWaves(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    // Pulsing ring - nhẹ, chỉ drawCircle
    final ringPaint1 = Paint()
      ..color = const Color(0xFFFFC6DA).withValues(alpha: 0.13 * (1 - animationValue))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * (0.8 + 0.2 * animationValue), ringPaint1);

    final phase2 = (animationValue + 0.5) % 1.0;
    final ringPaint2 = Paint()
      ..color = const Color(0xFFFF9EBB).withValues(alpha: 0.08 * (1 - phase2))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * (0.8 + 0.2 * phase2), ringPaint2);

    // Dùng bezier thay vòng lặp pixel-by-pixel (~400 pts → 4 điểm điều khiển)
    void drawWaveBezier(
      Color color,
      double amplitude,
      double phaseShift,
      double verticalOffset,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final yBase = height * verticalOffset;
      final t = animationValue * pi * 2 + phaseShift;

      // 4 control points tạo sóng bezier đơn giản
      final y0 = yBase + sin(t) * amplitude;
      final y1 = yBase + sin(t + pi * 0.5) * amplitude;
      final y2 = yBase + sin(t + pi) * amplitude;
      final y3 = yBase + sin(t + pi * 1.5) * amplitude;

      final path = Path()
        ..moveTo(0, height)
        ..lineTo(0, y0)
        ..cubicTo(width * 0.25, y1, width * 0.5, y2, width * 0.75, y3)
        ..cubicTo(width * 0.88, yBase + sin(t + pi * 1.75) * amplitude, width, y0, width, y0)
        ..lineTo(width, height)
        ..close();

      canvas.drawPath(path, paint);
    }

    drawWaveBezier(const Color(0xFFFFC6DA).withValues(alpha: 0.32), 18, 0, 0.55);
    drawWaveBezier(const Color(0xFFFF9EBB).withValues(alpha: 0.26), 14, pi / 2, 0.60);
    drawWaveBezier(const Color(0xFFFFB1CA).withValues(alpha: 0.40), 10, pi, 0.65);

    // Bubbles nhẹ - bỏ maskFilter.blur (nặng GPU)
    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final bubbleY1 = height - (height * ((animationValue + 0.2) % 1.0));
    final bubbleX1 = width * 0.3 + sin(animationValue * pi * 4) * 10;
    canvas.drawCircle(Offset(bubbleX1, bubbleY1), 5, bubblePaint);

    final bubbleY2 = height - (height * ((animationValue + 0.65) % 1.0));
    final bubbleX2 = width * 0.68 + cos(animationValue * pi * 4) * 12;
    canvas.drawCircle(Offset(bubbleX2, bubbleY2), 7, bubblePaint);
  }

  void _drawGalaxy(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          const Color(0xFF1A0533).withValues(alpha: 0.9),
          const Color(0xFF0D0221).withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    final angle = animationValue * pi * 2;
    final swirl1 = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: const [
          Color(0xFF8B2FC9),
          Color(0xFF4A6CF7),
          Color(0xFFFF4EBB),
          Color(0xFF00D4FF),
          Color(0xFF8B2FC9),
        ],
        startAngle: angle,
        endAngle: angle + pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(
      Offset(
        center.dx + cos(angle) * radius * 0.2,
        center.dy + sin(angle) * radius * 0.2,
      ),
      radius * 0.45,
      swirl1,
    );

    final swirl2 = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: const [
          Color(0xFF00D4FF),
          Color(0xFFFF4EBB),
          Color(0xFF8B2FC9),
          Color(0xFF00D4FF),
        ],
        startAngle: angle + pi,
        endAngle: angle + pi * 3,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(
      Offset(
        center.dx + cos(angle + pi) * radius * 0.15,
        center.dy + sin(angle + pi) * radius * 0.15,
      ),
      radius * 0.3,
      swirl2,
    );

    final starPaint = Paint()..style = PaintingStyle.fill;
    const starPositions = [
      [0.15, 0.20],
      [0.72, 0.15],
      [0.38, 0.08],
      [0.85, 0.42],
      [0.10, 0.55],
      [0.60, 0.75],
      [0.25, 0.82],
      [0.80, 0.68],
      [0.45, 0.35],
      [0.55, 0.60],
      [0.30, 0.45],
      [0.68, 0.30],
      [0.90, 0.25],
      [0.05, 0.75],
      [0.50, 0.90],
      [0.78, 0.85],
    ];
    for (var i = 0; i < starPositions.length; i++) {
      final twinkle = (sin((animationValue * pi * 4) + i * 1.3) + 1) / 2;
      final starR = (1.5 + (i % 3) * 1.0) * (0.6 + twinkle * 0.4);
      starPaint.color = Colors.white.withValues(alpha: 0.4 + twinkle * 0.6);
      canvas.drawCircle(
        Offset(width * starPositions[i][0], height * starPositions[i][1]),
        starR,
        starPaint,
      );
    }

    final shootProgress = (animationValue * 1.5) % 1.0;
    if (shootProgress < 0.35) {
      final t = shootProgress / 0.35;
      final sx = width * 0.1 + t * width * 0.8;
      final sy = height * 0.15 + t * height * 0.3;
      final trailPaint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.9 * (1 - t)), Colors.transparent],
        ).createShader(
          Rect.fromPoints(Offset(sx - 30, sy - 10), Offset(sx, sy)),
        )
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(sx - 30, sy - 10), Offset(sx, sy), trailPaint);
      canvas.drawCircle(
        Offset(sx, sy),
        2.5,
        Paint()..color = Colors.white.withValues(alpha: 1 - t),
      );
    }
  }

  void _drawNeonParty(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF0A001A).withValues(alpha: 0.92),
    );

    final barColors = [
      const Color(0xFFFF0080),
      const Color(0xFF00FFEA),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF44),
      const Color(0xFFFF6600),
      const Color(0xFF9900FF),
    ];
    for (var i = 0; i < barColors.length; i++) {
      final barAngle = animationValue * pi * 2 + (i * pi / 3);
      final pulse = (sin(animationValue * pi * 6 + i) + 1) / 2;
      final len = radius * (0.55 + pulse * 0.2);
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(barAngle) * len,
          center.dy + sin(barAngle) * len,
        ),
        Paint()
          ..color = barColors[i].withValues(alpha: 0.4 + pulse * 0.35)
          ..strokeWidth = 3.5 + pulse * 2.0
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + pulse * 4)
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var r = 0; r < 3; r++) {
      final phase = (animationValue + r * 0.33) % 1.0;
      final ringR = radius * 0.3 + radius * 0.65 * phase;
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..color = barColors[r * 2 % barColors.length]
              .withValues(alpha: (1 - phase) * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    for (var i = 0; i < 8; i++) {
      final sparkAngle = animationValue * pi * (i.isEven ? 2 : -2) + i * pi / 4;
      final sparkR = radius * (0.35 + (i % 3) * 0.15);
      final pulse = (sin(animationValue * pi * 8 + i) + 1) / 2;
      canvas.drawCircle(
        Offset(
          center.dx + cos(sparkAngle) * sparkR,
          center.dy + sin(sparkAngle) * sparkR,
        ),
        2.5 + pulse * 2.5,
        Paint()
          ..color =
              barColors[i % barColors.length].withValues(alpha: 0.7 + pulse * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + pulse * 3),
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 
              0.35 + sin(animationValue * pi * 4).abs() * 0.2,
            ),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.25)),
    );
  }

  void _drawAurora(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF011329).withValues(alpha: 0.95),
            const Color(0xFF001A12).withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );

    final auroraConfig = [
      [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
      [0.42, 0.10, 0.8, 0.2, 0.9, 1.0, 0.45],
      [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
      [0.58, 0.08, 0.7, 0.0, 0.8, 0.5, 0.30],
      [0.65, 0.11, 1.5, 0.8, 0.2, 1.0, 0.25],
    ];

    for (final cfg in auroraConfig) {
      final yBase = height * cfg[0];
      final amp = height * cfg[1];
      final speed = cfg[2];
      final bandColor = Color.fromRGBO(
        (cfg[3] * 255).round(),
        (cfg[4] * 255).round(),
        (cfg[5] * 255).round(),
        cfg[6],
      );
      final path = Path()..moveTo(0, height);
      for (double x = 0; x <= width; x += 2) {
        final wave1 =
            sin((x / width * 2 * pi) + animationValue * speed * pi * 2) * amp;
        final wave2 = sin(
              (x / width * 3 * pi) + animationValue * speed * pi * 1.3 + pi / 3,
            ) *
            amp *
            0.5;
        path.lineTo(x, yBase + wave1 + wave2);
      }
      path
        ..lineTo(width, height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bandColor,
              bandColor.withValues(alpha: bandColor.a * 0.3),
            ],
          ).createShader(Rect.fromLTWH(0, yBase - amp * 2, width, amp * 4))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 22; i++) {
      final sx = width * ((i * 0.13 + 0.04) % 1.0);
      final sy = height * ((i * 0.19 + 0.03) % 0.35);
      final twinkle = (sin(animationValue * pi * 3 + i * 1.7) + 1) / 2;
      starPaint.color = Colors.white.withValues(alpha: 0.3 + twinkle * 0.5);
      canvas.drawCircle(Offset(sx, sy), 1.0 + (i % 2), starPaint);
    }
  }

  void _drawCrystal(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            const Color(0xFFE8F4FF).withValues(alpha: 0.8),
            const Color(0xFFF0E8FF).withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final crystalAngle = animationValue * pi * 0.3;
    final facetColors = [
      const Color(0xFFFF9ECC),
      const Color(0xFFA8E6FF),
      const Color(0xFFCCA8FF),
      const Color(0xFFA8FFD4),
      const Color(0xFFFFE8A8),
      const Color(0xFFFF9ECC),
    ];
    final facetOpacities = [0.5, 0.45, 0.4, 0.4, 0.45, 0.35];

    for (var i = 0; i < 6; i++) {
      final facetAngle = crystalAngle + (i * pi / 3);
      final facetAngle2 = crystalAngle + ((i + 1) * pi / 3);
      final pulse = (sin(animationValue * pi * 4 + i) + 1) / 2;
      final path = Path()
        ..moveTo(
          center.dx + cos(facetAngle) * radius * (0.25 + pulse * 0.08),
          center.dy + sin(facetAngle) * radius * (0.25 + pulse * 0.08),
        )
        ..lineTo(
          center.dx + cos(facetAngle) * radius * (0.72 + pulse * 0.06),
          center.dy + sin(facetAngle) * radius * (0.72 + pulse * 0.06),
        )
        ..lineTo(
          center.dx + cos(facetAngle2) * radius * (0.72 + pulse * 0.06),
          center.dy + sin(facetAngle2) * radius * (0.72 + pulse * 0.06),
        )
        ..lineTo(
          center.dx + cos(facetAngle2) * radius * (0.25 + pulse * 0.08),
          center.dy + sin(facetAngle2) * radius * (0.25 + pulse * 0.08),
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = facetColors[i]
              .withValues(alpha: facetOpacities[i] * (0.6 + pulse * 0.4))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    for (var i = 0; i < 6; i++) {
      final lineAngle = crystalAngle * 2 + (i * pi / 3);
      final pulse = (sin(animationValue * pi * 6 + i * 0.7) + 1) / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(lineAngle) * radius * (0.5 + pulse * 0.2),
          center.dy + sin(lineAngle) * radius * (0.5 + pulse * 0.2),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.4)
          ..strokeWidth = 1.5 + pulse * 1.5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + pulse * 3),
      );
    }

    for (var i = 0; i < 12; i++) {
      final fleckAngle =
          animationValue * pi * 2 * (i.isEven ? 1 : -0.7) + i * pi / 6;
      final fleckR = radius * ((i * 0.07 + 0.2) % 0.7);
      final pulse = (sin(animationValue * pi * 5 + i) + 1) / 2;
      canvas.drawCircle(
        Offset(
          center.dx + cos(fleckAngle) * fleckR,
          center.dy + sin(fleckAngle) * fleckR,
        ),
        1.5 + pulse * 2.0,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + pulse * 2),
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.22,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFF9ECC),
            Color(0xFFA8E6FF),
            Color(0xFFCCA8FF),
            Color(0xFFA8FFD4),
            Color(0xFFFFE8A8),
            Color(0xFFFF9ECC),
          ],
          startAngle: crystalAngle,
          endAngle: crystalAngle + pi * 2,
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.22))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _drawCandyPop(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD8F0), Color(0xFFDDF8FF), Color(0xFFFFF3C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final stripeColors = [
      const Color(0xFFFF6FB7),
      const Color(0xFF53D8FF),
      const Color(0xFFFFD54F),
      const Color(0xFFB388FF),
    ];
    for (var i = 0; i < 7; i++) {
      final offset = ((animationValue + i * 0.18) % 1.0) * width * 1.6;
      stripePaint.color =
          stripeColors[i % stripeColors.length].withValues(alpha: 0.20);
      canvas.drawLine(
        Offset(offset - width * 0.9, -height * 0.1),
        Offset(offset, height * 1.1),
        stripePaint,
      );
    }

    for (var i = 0; i < 14; i++) {
      final progress = (animationValue * (0.45 + i * 0.02) + i * 0.11) % 1.0;
      final x = width * ((i * 0.23 + 0.08) % 1.0) +
          sin(animationValue * pi * 4 + i) * 10;
      final y = height + 16 - progress * (height + 36);
      final size = 4.0 + (i % 4) * 2.0;
      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = stripeColors[(i + 1) % stripeColors.length]
              .withValues(alpha: 0.34 + sin(progress * pi) * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  void _drawHyperColor(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final angle = animationValue * pi * 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFF005D),
            Color(0xFFFFD600),
            Color(0xFF00F5FF),
            Color(0xFF00FF66),
            Color(0xFF7C4DFF),
            Color(0xFFFF00C8),
            Color(0xFFFF005D),
          ],
          startAngle: angle,
          endAngle: angle + pi * 2,
        ).createShader(rect),
    );

    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..blendMode = BlendMode.screen,
    );

    final colors = [
      const Color(0xFFFFF176),
      const Color(0xFFFF00A8),
      const Color(0xFF00E5FF),
      const Color(0xFF69F0AE),
      const Color(0xFFFF6D00),
      Colors.white,
    ];
    for (var i = 0; i < 18; i++) {
      final orbit = radius * (0.28 + (i % 5) * 0.11);
      final a = angle * (i.isEven ? 1.0 : -1.25) + i * pi / 9;
      final pulse = (sin(animationValue * pi * 8 + i) + 1) / 2;
      final p = Offset(center.dx + cos(a) * orbit, center.dy + sin(a) * orbit);
      canvas.drawCircle(
        p,
        2.8 + pulse * 3.2,
        Paint()
          ..color = colors[i % colors.length].withValues(alpha: 0.72)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + pulse * 3),
      );
      if (i % 3 == 0) {
        canvas.drawLine(
          center,
          p,
          Paint()
            ..color = colors[i % colors.length].withValues(alpha: 0.18)
            ..strokeWidth = 1.4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }

    for (var i = 0; i < 12; i++) {
      final burst = (animationValue + i * 0.083) % 1.0;
      final burstRadius = radius * (0.16 + burst * 0.72);
      canvas.drawCircle(
        center,
        burstRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 + (1 - burst) * 2.8
          ..color = colors[i % colors.length].withValues(alpha: (1 - burst) * 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _drawFireworks(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF140026), Color(0xFF06000F)],
          radius: 0.8,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final colors = [
      const Color(0xFFFFD54F),
      const Color(0xFFFF4FB3),
      const Color(0xFF40C4FF),
      const Color(0xFF69F0AE),
      const Color(0xFFFF8A65),
      const Color(0xFFE040FB),
      Colors.white,
    ];
    final anchors = [
      Offset(width * 0.32, height * 0.35),
      Offset(width * 0.68, height * 0.42),
      Offset(width * 0.48, height * 0.65),
      Offset(width * 0.20, height * 0.58),
      Offset(width * 0.78, height * 0.28),
    ];

    for (var b = 0; b < anchors.length; b++) {
      final progress = (animationValue + b * 0.29) % 1.0;
      if (progress < 0.2) {
        final t = progress / 0.2;
        final sy = height - (height - anchors[b].dy) * t;
        canvas.drawLine(
          Offset(anchors[b].dx, sy + 25),
          Offset(anchors[b].dx, sy),
          Paint()
            ..color = colors[b % colors.length].withValues(alpha: 1 - t)
            ..strokeWidth = 2.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    for (var b = 0; b < anchors.length; b++) {
      final progress = (animationValue + b * 0.29) % 1.0;
      if (progress >= 0.2) {
        final burstProgress = (progress - 0.2) / 0.8;
        final burstRadius = radius * (0.05 + burstProgress * 0.65);
        const particleCount = 24;

        for (var i = 0; i < particleCount; i++) {
          final a = i * (pi * 2 / particleCount) + (burstProgress * pi * 0.1);
          final isLong = i % 2 == 0;
          final currentRadius = isLong ? burstRadius : burstRadius * 0.6;

          final start = Offset(
            anchors[b].dx + cos(a) * (currentRadius * 0.4),
            anchors[b].dy +
                sin(a) * (currentRadius * 0.4) +
                (burstProgress * 20),
          );
          final end = Offset(
            anchors[b].dx + cos(a) * currentRadius,
            anchors[b].dy + sin(a) * currentRadius + (burstProgress * 30),
          );

          final twinkle = (sin(animationValue * pi * 10 + i) + 1) / 2;
          canvas.drawLine(
            start,
            end,
            Paint()
              ..color = colors[(i + b) % colors.length]
                  .withValues(alpha: (1 - burstProgress) * (0.6 + twinkle * 0.4))
              ..strokeWidth = 1.5 + (1 - burstProgress) * 2.0
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );

          if (isLong && burstProgress > 0.4 && burstProgress < 0.9) {
            canvas.drawCircle(
              end,
              2.0 * (1 - burstProgress),
              Paint()
                ..color = Colors.white.withValues(alpha: 1 - burstProgress)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
            );
          }
        }

        if (burstProgress < 0.4) {
          canvas.drawCircle(
            anchors[b],
            6 * (1 - burstProgress / 0.4),
            Paint()
              ..color = Colors.white.withValues(alpha: 1 - burstProgress / 0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
      }
    }
  }

  void _drawLava(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF5A0000), Color(0xFF280000), Color(0xFF0A0000)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final lavaColors = [
      const Color(0xFFFFEA00),
      const Color(0xFFFF9100),
      const Color(0xFFFF1744),
      const Color(0xFFFF3D00),
      const Color(0xFFFFC400),
    ];

    for (var i = 0; i < 14; i++) {
      final speed = 0.25 + i * 0.025;
      final progress = (animationValue * speed + i * 0.17) % 1.0;
      final blobRadius = radius * (0.12 + (i % 5) * 0.04);
      final x = width * ((i * 0.27 + 0.08) % 1.0) +
          sin(animationValue * pi * 4 + i) * radius * 0.15;
      final y = height + blobRadius * 2 - progress * (height + blobRadius * 3);

      final blobColor = lavaColors[i % lavaColors.length];

      canvas.drawCircle(
        Offset(x, y),
        blobRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              blobColor.withValues(alpha: 0.95),
              blobColor.withValues(alpha: 0.5),
              Colors.transparent,
            ],
            stops: const [0.3, 0.7, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(x, y), radius: blobRadius * 1.5),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.drawCircle(
        Offset(x - blobRadius * 0.2, y - blobRadius * 0.2),
        blobRadius * 0.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    for (var i = 0; i < 5; i++) {
      final phase = (animationValue * (1.2 + i * 0.1) + i * 0.2) % 1.0;
      final y = height * (0.50 + i * 0.1);
      final path = Path()..moveTo(0, height);
      for (double x = 0; x <= width; x += 4) {
        path.lineTo(
          x,
          y +
              sin((x / width * pi * 2) + phase * pi * 2) *
                  radius *
                  (0.06 + i * 0.02) +
              cos((x / width * pi * 4) - phase * pi) * radius * 0.03,
        );
      }
      path
        ..lineTo(width, height)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lavaColors[i % lavaColors.length].withValues(alpha: 0.4 + i * 0.1),
              const Color(0xFF3E0000).withValues(alpha: 0.8),
            ],
          ).createShader(Rect.fromLTWH(0, y - 50, width, height - y + 50))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    for (var i = 0; i < 25; i++) {
      final p = (animationValue * 1.5 + i * 0.04) % 1.0;
      final sx = width * ((i * 0.37) % 1.0) + sin(p * pi * 6 + i) * 20;
      final sy = height - p * height;
      canvas.drawCircle(
        Offset(sx, sy),
        1.5 + (i % 3),
        Paint()
          ..color = lavaColors[i % lavaColors.length].withValues(alpha: (1 - p) * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.styleKey != styleKey;
  }
}
