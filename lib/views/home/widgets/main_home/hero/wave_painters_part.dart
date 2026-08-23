part of 'main_home_animated_wave_background.dart';

class _WavePainter extends CustomPainter {
  final double animationValue;
  final String styleKey;
  final String quality;
  final double tiltX;
  final double tiltY;
  final double shakeIntensity;
  final List<_TapInteractionEffect> tapEffects;

  _WavePainter(
    this.animationValue,
    this.styleKey, {
    required this.quality,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.shakeIntensity = 0.0,
    this.tapEffects = const [],
  });

  MaskFilter? _getBlur(double sigma) {
    if (quality != 'high') return null;
    return MaskFilter.blur(BlurStyle.normal, sigma);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final radius = min(width, height) / 2;
    final center = Offset(width / 2, height / 2);

    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    if (styleKey == 'plain' || styleKey == 'floating_hearts') {
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
      _drawDefaultWaves(canvas, width, height, center, radius);
    } else if (styleKey == 'cherry_blossom') {
      _drawCherryBlossom(canvas, width, height, center, radius);
    } else if (styleKey == 'meteor_shower') {
      _drawMeteorShower(canvas, width, height, center, radius);
    } else if (styleKey == 'deep_ocean') {
      _drawDeepOcean(canvas, width, height, center, radius);
    } else if (styleKey == 'golden_sunset') {
      _drawGoldenSunset(canvas, width, height, center, radius);
    } else if (styleKey == 'neon_pulse') {
      _drawNeonPulse(canvas, width, height, center, radius);
    } else {
      _drawDefaultWaves(canvas, width, height, center, radius);
    }

    // Draw tap effects specific to style at the end of paint so they overlay on any background style
    _drawTapEffects(canvas, center, radius);
  }

  void _drawDefaultWaves(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    if (quality != 'low') {
      // Premium pulsing ring with gradient
      final ringAlphaFactor = quality == 'balanced' ? 0.72 : 1.0;

      final ringPaint1 = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            const Color(0xFFFFC6DA).withValues(
                alpha: 0.2 * (1 - animationValue) * ringAlphaFactor),
            const Color(0xFFFF9EBB).withValues(alpha: 0.0),
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(center.dx + tiltX * 0.3, center.dy + tiltY * 0.3),
        radius * (0.8 + 0.2 * animationValue),
        ringPaint1,
      );

      final phase2 = (animationValue + 0.5) % 1.0;
      final ringPaint2 = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            const Color(0xFFFF9EBB)
                .withValues(alpha: 0.15 * (1 - phase2) * ringAlphaFactor),
            const Color(0xFFFF4D94).withValues(alpha: 0.0),
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(center.dx + tiltX * 0.3, center.dy + tiltY * 0.3),
        radius * (0.8 + 0.2 * phase2),
        ringPaint2,
      );
    }

    void drawPremiumWave({
      required List<Color> colors,
      required double amplitude,
      required double frequency,
      required double phaseShift,
      required double verticalOffset,
      bool useBlur = false,
    }) {
      final yBase = height * verticalOffset + (tiltY * 0.75);
      final tiltAmount = tiltX * 3.5;

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, yBase - amplitude),
          Offset(0, height),
          colors,
        )
        ..style = PaintingStyle.fill;

      if (useBlur && quality == 'high') {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      }

      final step = quality == 'high' ? 8.0 : 16.0;
      final path = Path()..moveTo(0, height);
      for (double i = 0; i <= width; i += step) {
        final relX = i / width;
        final wave = sin(
              (relX * frequency * pi * 2) +
                  (animationValue * pi * 2) +
                  phaseShift,
            ) *
            amplitude;
        final tilt = (relX - 0.5) * tiltAmount * 2.0;
        final y = yBase + wave + tilt;
        if (i == 0) {
          path.lineTo(0, y);
        } else {
          path.lineTo(i, y);
        }
      }
      path
        ..lineTo(width, height)
        ..close();

      canvas.drawPath(path, paint);
    }

    final double shakeAmpMultiplier = 1.0 + shakeIntensity * 1.5;

    // Nâng cấp: Dùng Gradient dọc tạo chiều sâu (Premium Gradient Waves)
    final wave1Colors = [
      const Color(0xFFFFC6DA).withValues(alpha: 0.35),
      const Color(0xFFFFE0EB).withValues(alpha: 0.1),
    ];
    final wave2Colors = [
      const Color(0xFFFF9EBB).withValues(alpha: 0.45),
      const Color(0xFFFFC6DA).withValues(alpha: 0.15),
    ];
    final wave3Colors = [
      const Color(0xFFFF72A3).withValues(alpha: 0.55),
      const Color(0xFFFF9EBB).withValues(alpha: 0.25),
    ];

    if (quality == 'low') {
      drawPremiumWave(
          colors: wave1Colors,
          amplitude: 18 * shakeAmpMultiplier,
          frequency: 1.0,
          phaseShift: 0,
          verticalOffset: 0.55);
      drawPremiumWave(
          colors: wave3Colors,
          amplitude: 10 * shakeAmpMultiplier,
          frequency: 1.5,
          phaseShift: pi,
          verticalOffset: 0.65);
    } else if (quality == 'balanced') {
      drawPremiumWave(
          colors: wave1Colors,
          amplitude: 18 * shakeAmpMultiplier,
          frequency: 1.0,
          phaseShift: 0,
          verticalOffset: 0.55);
      drawPremiumWave(
          colors: wave2Colors,
          amplitude: 14 * shakeAmpMultiplier,
          frequency: 1.2,
          phaseShift: pi / 2,
          verticalOffset: 0.60);
      drawPremiumWave(
          colors: wave3Colors,
          amplitude: 10 * shakeAmpMultiplier,
          frequency: 1.5,
          phaseShift: pi,
          verticalOffset: 0.65);
    } else {
      drawPremiumWave(
          colors: wave1Colors,
          amplitude: 18 * shakeAmpMultiplier,
          frequency: 1.0,
          phaseShift: 0,
          verticalOffset: 0.55,
          useBlur: true);
      drawPremiumWave(
          colors: wave2Colors,
          amplitude: 14 * shakeAmpMultiplier,
          frequency: 1.2,
          phaseShift: pi / 2,
          verticalOffset: 0.60,
          useBlur: true);
      drawPremiumWave(
          colors: wave3Colors,
          amplitude: 10 * shakeAmpMultiplier,
          frequency: 1.5,
          phaseShift: pi,
          verticalOffset: 0.65);
    }
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

    if (quality != 'low') {
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
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));

      if (quality == 'high') {
        swirl1.maskFilter = _getBlur(12);
      } else {
        swirl1.maskFilter = _getBlur(5);
      }
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle) * radius * 0.2,
          center.dy + sin(angle) * radius * 0.2,
        ),
        radius * 0.45,
        swirl1,
      );
    }

    if (quality == 'high') {
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
        ..maskFilter = _getBlur(8);
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle + pi) * radius * 0.15,
          center.dy + sin(angle + pi) * radius * 0.15,
        ),
        radius * 0.3,
        swirl2,
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
      const Color(0xFF00FF44),
      const Color(0xFFFF6600),
      const Color(0xFF9900FF),
    ];
    final barCount = quality == 'low' ? 3 : (quality == 'balanced' ? 4 : 6);
    for (var i = 0; i < barCount; i++) {
      final barAngle = animationValue * pi * 2 + (i * pi / 3);
      final pulse = (sin(animationValue * pi * 6 + i) + 1) / 2;
      final len = radius * (0.55 + pulse * 0.2);
      final paint = Paint()
        ..color = barColors[i].withValues(alpha: 0.4 + pulse * 0.35)
        ..strokeWidth = 3.5 + pulse * 2.0
        ..strokeCap = StrokeCap.round;
      if (quality == 'high') {
        paint.maskFilter = _getBlur(6 + pulse * 4);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(3 + pulse * 2);
      }
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(barAngle) * len,
          center.dy + sin(barAngle) * len,
        ),
        paint,
      );
    }

    final ringCount = quality == 'low' ? 1 : (quality == 'balanced' ? 2 : 3);
    for (var r = 0; r < ringCount; r++) {
      final phase = (animationValue + r * 0.33) % 1.0;
      final ringR = radius * 0.3 + radius * 0.65 * phase;
      final paint = Paint()
        ..color = barColors[r * 2 % barColors.length]
            .withValues(alpha: (1 - phase) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      if (quality == 'high') {
        paint.maskFilter = _getBlur(5);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(3);
      }
      canvas.drawCircle(center, ringR, paint);
    }
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

    final auroraConfig = quality == 'low'
        ? [
            [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
            [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
          ]
        : (quality == 'balanced'
            ? [
                [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
                [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
                [0.65, 0.11, 1.5, 0.8, 0.2, 1.0, 0.25],
              ]
            : [
                [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
                [0.42, 0.10, 0.8, 0.2, 0.9, 1.0, 0.45],
                [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
                [0.58, 0.08, 0.7, 0.0, 0.8, 0.5, 0.30],
                [0.65, 0.11, 1.5, 0.8, 0.2, 1.0, 0.25],
              ]);

    final step = quality == 'low' ? 16.0 : (quality == 'balanced' ? 12.0 : 8.0);

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
      for (double x = 0; x <= width; x += step) {
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

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bandColor,
            bandColor.withValues(alpha: bandColor.a * 0.3),
          ],
        ).createShader(Rect.fromLTWH(0, yBase - amp * 2, width, amp * 4));

      if (quality == 'high') {
        paint.maskFilter = _getBlur(8);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(3);
      }

      canvas.drawPath(path, paint);
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

    final facetCount = quality == 'low' ? 3 : (quality == 'balanced' ? 4 : 6);
    for (var i = 0; i < facetCount; i++) {
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

      final paint = Paint()
        ..color = facetColors[i]
            .withValues(alpha: facetOpacities[i] * (0.6 + pulse * 0.4));
      if (quality == 'high') {
        paint.maskFilter = _getBlur(4);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(2);
      }
      canvas.drawPath(path, paint);
    }

    final lineCount = quality == 'low' ? 3 : (quality == 'balanced' ? 4 : 6);
    for (var i = 0; i < lineCount; i++) {
      final lineAngle = crystalAngle * 2 + (i * pi / 3);
      final pulse = (sin(animationValue * pi * 6 + i * 0.7) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.4)
        ..strokeWidth = 1.5 + pulse * 1.5;
      if (quality == 'high') {
        paint.maskFilter = _getBlur(2 + pulse * 3);
      }
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(lineAngle) * radius * (0.5 + pulse * 0.2),
          center.dy + sin(lineAngle) * radius * (0.5 + pulse * 0.2),
        ),
        paint,
      );
    }

    final fleckCount = quality == 'low' ? 4 : (quality == 'balanced' ? 8 : 12);
    for (var i = 0; i < fleckCount; i++) {
      final fleckAngle =
          animationValue * pi * 2 * (i.isEven ? 1 : -0.7) + i * pi / 6;
      final fleckR = radius * ((i * 0.07 + 0.2) % 0.7);
      final pulse = (sin(animationValue * pi * 5 + i) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.45);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(2 + pulse * 2);
      }
      canvas.drawCircle(
        Offset(
          center.dx + cos(fleckAngle) * fleckR,
          center.dy + sin(fleckAngle) * fleckR,
        ),
        1.5 + pulse * 2.0,
        paint,
      );
    }

    final centerPaint = Paint();
    if (quality != 'low') {
      centerPaint.shader = SweepGradient(
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
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.22));
      if (quality == 'high') {
        centerPaint.maskFilter = _getBlur(6);
      } else {
        centerPaint.maskFilter = _getBlur(3);
      }
      canvas.drawCircle(center, radius * 0.22, centerPaint);
    }
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
      ..strokeCap = StrokeCap.round;
    if (quality == 'high') {
      stripePaint.maskFilter = _getBlur(2);
    } else if (quality == 'balanced') {
      stripePaint.maskFilter = _getBlur(1);
    }

    final stripeColors = [
      const Color(0xFFFF6FB7),
      const Color(0xFF53D8FF),
      const Color(0xFFFFD54F),
      const Color(0xFFB388FF),
    ];
    final stripeCount = quality == 'low' ? 3 : (quality == 'balanced' ? 5 : 7);
    for (var i = 0; i < stripeCount; i++) {
      final offset = ((animationValue + i * 0.18) % 1.0) * width * 1.6;
      stripePaint.color =
          stripeColors[i % stripeColors.length].withValues(alpha: 0.20);
      canvas.drawLine(
        Offset(offset - width * 0.9, -height * 0.1),
        Offset(offset, height * 1.1),
        stripePaint,
      );
    }

    final bubbleCount = quality == 'low' ? 5 : (quality == 'balanced' ? 9 : 14);
    for (var i = 0; i < bubbleCount; i++) {
      final progress = (animationValue * (0.45 + i * 0.02) + i * 0.11) % 1.0;
      final x = width * ((i * 0.23 + 0.08) % 1.0) +
          sin(animationValue * pi * 4 + i) * 10;
      final y = height + 16 - progress * (height + 36);
      final size = 4.0 + (i % 4) * 2.0;
      final paint = Paint()
        ..color = stripeColors[(i + 1) % stripeColors.length]
            .withValues(alpha: 0.34 + sin(progress * pi) * 0.22);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(1.5);
      }
      canvas.drawCircle(Offset(x, y), size, paint);
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
    final orbitCount = quality == 'low' ? 5 : (quality == 'balanced' ? 10 : 18);
    for (var i = 0; i < orbitCount; i++) {
      final orbit = radius * (0.28 + (i % 5) * 0.11);
      final a = angle * (i.isEven ? 1.0 : -1.25) + i * pi / 9;
      final pulse = (sin(animationValue * pi * 8 + i) + 1) / 2;
      final p = Offset(center.dx + cos(a) * orbit, center.dy + sin(a) * orbit);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.72);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(3 + pulse * 3);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(1.5 + pulse * 1.5);
      }
      canvas.drawCircle(p, 2.8 + pulse * 3.2, paint);

      if (quality == 'high' && i % 3 == 0) {
        canvas.drawLine(
          center,
          p,
          Paint()
            ..color = colors[i % colors.length].withValues(alpha: 0.18)
            ..strokeWidth = 1.4
            ..maskFilter = _getBlur(5),
        );
      }
    }

    final burstCount = quality == 'low' ? 3 : (quality == 'balanced' ? 6 : 12);
    for (var i = 0; i < burstCount; i++) {
      final burst = (animationValue + i * 0.083) % 1.0;
      final burstRadius = radius * (0.16 + burst * 0.72);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 + (1 - burst) * 2.8
        ..color =
            colors[i % colors.length].withValues(alpha: (1 - burst) * 0.42);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(4);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(2);
      }
      canvas.drawCircle(center, burstRadius, paint);
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

    final blobCount = quality == 'low' ? 4 : (quality == 'balanced' ? 7 : 14);
    for (var i = 0; i < blobCount; i++) {
      final speed = 0.25 + i * 0.025;
      final progress = (animationValue * speed + i * 0.17) % 1.0;
      final blobRadius = radius * (0.12 + (i % 5) * 0.04);
      final x = width * ((i * 0.27 + 0.08) % 1.0) +
          sin(animationValue * pi * 4 + i) * radius * 0.15;
      final y = height + blobRadius * 2 - progress * (height + blobRadius * 3);
      final blobColor = lavaColors[i % lavaColors.length];

      if (quality == 'low') {
        canvas.drawCircle(
          Offset(x, y),
          blobRadius,
          Paint()..color = blobColor.withValues(alpha: 0.24),
        );
      } else if (quality == 'balanced') {
        canvas.drawCircle(
          Offset(x, y),
          blobRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                blobColor.withValues(alpha: 0.40),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(x, y), radius: blobRadius * 1.3),
            ),
        );
      } else {
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
            ..maskFilter = _getBlur(8),
        );

        canvas.drawCircle(
          Offset(x - blobRadius * 0.2, y - blobRadius * 0.2),
          blobRadius * 0.3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..maskFilter = _getBlur(4),
        );
      }
    }

    final waveCount = quality == 'low' ? 2 : (quality == 'balanced' ? 3 : 5);
    final waveStep =
        quality == 'low' ? 16.0 : (quality == 'balanced' ? 12.0 : 8.0);
    for (var i = 0; i < waveCount; i++) {
      final phase = (animationValue * (1.2 + i * 0.1) + i * 0.2) % 1.0;
      final y = height * (0.50 + i * 0.1);
      final path = Path()..moveTo(0, height);
      for (double x = 0; x <= width; x += waveStep) {
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

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lavaColors[i % lavaColors.length].withValues(alpha: 0.4 + i * 0.1),
            const Color(0xFF3E0000).withValues(alpha: 0.8),
          ],
        ).createShader(Rect.fromLTWH(0, y - 50, width, height - y + 50));

      if (quality == 'high') {
        paint.maskFilter = _getBlur(3);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(1.5);
      }

      canvas.drawPath(path, paint);
    }

    final sparkCount = quality == 'low' ? 8 : (quality == 'balanced' ? 12 : 25);
    for (var i = 0; i < sparkCount; i++) {
      final p = (animationValue * 1.5 + i * 0.04) % 1.0;
      final sx = width * ((i * 0.37) % 1.0) + sin(p * pi * 6 + i) * 20;
      final sy = height - p * height;
      final paint = Paint()
        ..color =
            lavaColors[i % lavaColors.length].withValues(alpha: (1 - p) * 0.8);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(2);
      }
      canvas.drawCircle(Offset(sx, sy), 1.5 + (i % 3), paint);
    }
  }

  void _drawDeepOcean(Canvas canvas, double width, double height, Offset center,
      double radius) {
    // Nền gradient đại dương xanh sâu
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.5),
        colors: [
          const Color(0xFF0077B6).withValues(alpha: 0.8),
          const Color(0xFF023E8A).withValues(alpha: 0.85),
          const Color(0xFF03045E).withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Ánh sáng caustic từ trên mặt nước chiếu xuống
    if (quality != 'low') {
      for (var i = 0; i < 4; i++) {
        final cx =
            center.dx + sin(animationValue * pi * 2 + i * 1.5) * radius * 0.3;
        final cy =
            center.dy - radius * 0.4 + cos(animationValue * pi * 1.5 + i) * 15;
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy),
              width: radius * 0.5,
              height: radius * 0.15),
          Paint()
            ..color = const Color(0xFF90E0EF).withValues(
                alpha: 0.08 + sin(animationValue * pi * 3 + i) * 0.04)
            ..maskFilter = _getBlur(25),
        );
      }
    }

    // Bọt khí nổi lên với ánh sáng phản chiếu
    final count = quality == 'low' ? 10 : (quality == 'balanced' ? 18 : 30);
    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.23 + 0.05) % 1.0);
      final speed = 0.12 + (i * 0.08 % 0.3);
      final size = 2.0 + (i * 4.3 % 12);

      final progress = (animationValue * speed + (i * 0.17)) % 1.0;
      final wobble =
          sin((animationValue * pi * 4) + i * 2.3) * (8 + size * 0.5);
      final y = height +
          size -
          progress * (height + size * 3) +
          tiltY * (0.2 + i * 0.06);
      final x = startX + wobble + tiltX * (0.2 + i * 0.06);
      final opacity = sin(progress * pi);

      // Bọt khí chính — viền tròn bán trong suốt
      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = const Color(0xFFCAF0F8).withValues(alpha: 0.25 * opacity)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = const Color(0xFF90E0EF).withValues(alpha: 0.4 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Ánh sáng phản chiếu trên bọt khí
      if (size > 4) {
        canvas.drawCircle(
          Offset(x - size * 0.25, y - size * 0.3),
          size * 0.2,
          Paint()..color = Colors.white.withValues(alpha: 0.5 * opacity),
        );
      }
    }

    // Rong biển nhẹ lay ở dưới
    if (quality != 'low') {
      final seaweedPaint = Paint()
        ..color = const Color(0xFF2D6A4F).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final baseX = width * (0.1 + i * 0.2);
        final baseY = height * 0.95;
        final sway = sin(animationValue * pi * 2 + i * 1.2) * 12;
        final path = Path();
        path.moveTo(baseX, baseY);
        path.quadraticBezierTo(
          baseX + sway,
          baseY - height * 0.12,
          baseX + sway * 0.6,
          baseY - height * 0.22,
        );
        canvas.drawPath(path, seaweedPaint);
      }
    }
  }

  void _drawGoldenSunset(Canvas canvas, double width, double height,
      Offset center, double radius) {
    // Nền gradient hoàng hôn nhiều lớp
    final sunBob = sin(animationValue * pi * 1.5);
    final sunCenter = Offset(center.dx, center.dy + sunBob * 8);

    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, -0.2 + sunBob * 0.05),
        colors: [
          const Color(0xFFFFF8E1).withValues(alpha: 0.95),
          const Color(0xFFFFCC80).withValues(alpha: 0.85),
          const Color(0xFFFF8A65).withValues(alpha: 0.7),
          const Color(0xFFE65100).withValues(alpha: 0.5),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Mặt trời rực rỡ với nhiều lớp glow
    final sunRadius = radius * 0.18;
    if (quality != 'low') {
      // Outer glow
      canvas.drawCircle(
        sunCenter,
        sunRadius * 3,
        Paint()
          ..color = const Color(0xFFFFB74D).withValues(alpha: 0.12)
          ..maskFilter = _getBlur(30),
      );
      // Mid glow
      canvas.drawCircle(
        sunCenter,
        sunRadius * 1.8,
        Paint()
          ..color = const Color(0xFFFFCC02).withValues(alpha: 0.2)
          ..maskFilter = _getBlur(15),
      );
    }
    // Sun core
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFF9C4),
            Color(0xFFFFD54F),
            Color(0xFFFF9800),
          ],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius)),
    );

    // Tia nắng mặt trời xoay chậm
    if (quality != 'low') {
      final rayCount = quality == 'balanced' ? 8 : 14;
      final rayPaint = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < rayCount; i++) {
        final angle = (i * 2 * pi / rayCount) + animationValue * pi * 0.3;
        final rayLen = sunRadius * 1.5 +
            sin(animationValue * pi * 4 + i * 2) * sunRadius * 0.5;
        final startR = sunRadius * 1.1;
        final sx = sunCenter.dx + cos(angle) * startR;
        final sy = sunCenter.dy + sin(angle) * startR;
        final ex = sunCenter.dx + cos(angle) * (startR + rayLen);
        final ey = sunCenter.dy + sin(angle) * (startR + rayLen);
        rayPaint
          ..strokeWidth = 1.5
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFFFD54F).withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ).createShader(Rect.fromPoints(Offset(sx, sy), Offset(ex, ey)));
        canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rayPaint);
      }
    }

    // Hạt bụi vàng lấp lánh bay
    final dustCount = quality == 'low' ? 12 : (quality == 'balanced' ? 25 : 40);
    final dustColors = [
      const Color(0xFFFFCC80),
      const Color(0xFFFFE082),
      const Color(0xFFFFD54F),
      const Color(0xFFFFF9C4),
    ];
    final dustPaint = Paint();
    for (var i = 0; i < dustCount; i++) {
      final x = width * ((i * 0.31 + 0.02) % 1.0);
      final y = height * ((i * 0.43 + 0.05) % 1.0);
      final progress = (animationValue * 0.3 + i * 0.07) % 1.0;
      final moveX = x + sin(progress * pi * 3 + i * 0.7) * 25;
      final moveY = y + cos(progress * pi * 2 + i * 1.1) * 18;
      final opacity = sin(progress * pi) * (0.4 + (i % 3) * 0.15);
      final dotSize = 1.0 + (i % 4) * 0.8;
      dustPaint.color = dustColors[i % dustColors.length]
          .withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(moveX, moveY), dotSize, dustPaint);
    }
  }

  void _drawNeonPulse(Canvas canvas, double width, double height, Offset center,
      double radius) {
    // Nền đen sâu
    canvas.drawCircle(center, radius,
        Paint()..color = const Color(0xFF030308).withValues(alpha: 0.92));

    final pulse = sin(animationValue * pi * 6);
    final pulse2 = sin(animationValue * pi * 4 + pi / 3);

    // Multi-color neon rings
    final neonColors = [
      const Color(0xFFFF003C), // Đỏ neon
      const Color(0xFF00F0FF), // Cyan neon
      const Color(0xFFBF00FF), // Tím neon
      const Color(0xFF39FF14), // Xanh lá neon
    ];

    // Vòng neon nhịp đập
    for (int c = 0; c < neonColors.length; c++) {
      final ringPulse = sin(animationValue * pi * 6 + c * pi / 2);
      final ringRadius = radius * (0.25 + c * 0.12) + ringPulse * radius * 0.06;
      final ringPaint = Paint()
        ..color = neonColors[c].withValues(alpha: 0.35 + ringPulse * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + ringPulse;
      if (quality != 'low') {
        ringPaint.maskFilter = _getBlur(8 + ringPulse * 4);
      }
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Tia sáng xoay xung quanh tâm
    final rayCount = quality == 'low' ? 8 : (quality == 'balanced' ? 16 : 24);
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * pi / rayCount) + animationValue * pi * 1.5;
      final colorIdx = i % neonColors.length;
      final rayPulse = sin(animationValue * pi * 8 + i * 0.5);
      final innerR = radius * 0.15;
      final outerR = innerR + (12 + rayPulse * 15).clamp(0.0, 30.0);
      final rayPaint = Paint()
        ..strokeWidth = 1.5 + rayPulse * 0.5
        ..strokeCap = StrokeCap.round
        ..color = neonColors[colorIdx]
            .withValues(alpha: (0.3 + rayPulse * 0.3).clamp(0.0, 1.0));
      if (quality == 'high') {
        rayPaint.maskFilter = _getBlur(3 + rayPulse * 2);
      }
      canvas.drawLine(
        Offset(
            center.dx + cos(angle) * innerR, center.dy + sin(angle) * innerR),
        Offset(
            center.dx + cos(angle) * outerR, center.dy + sin(angle) * outerR),
        rayPaint,
      );
    }

    // Hạt neon bay lơ lửng
    final particleCount =
        quality == 'low' ? 6 : (quality == 'balanced' ? 12 : 20);
    for (var i = 0; i < particleCount; i++) {
      final angle =
          animationValue * pi * (0.5 + i * 0.15) + i * 2 * pi / particleCount;
      final dist = radius * (0.3 + (i % 4) * 0.1) +
          sin(animationValue * pi * 3 + i) * 10;
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist;
      final pSize = 1.5 + (i % 3);
      final pColor = neonColors[i % neonColors.length];
      final pOpacity =
          (0.4 + sin(animationValue * pi * 5 + i * 1.3) * 0.4).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(px, py),
        pSize,
        Paint()..color = pColor.withValues(alpha: pOpacity),
      );
      if (quality != 'low' && pSize > 2) {
        canvas.drawCircle(
          Offset(px, py),
          pSize * 2,
          Paint()
            ..color = pColor.withValues(alpha: pOpacity * 0.2)
            ..maskFilter = _getBlur(5),
        );
      }
    }

    // Pulse glow ở giữa
    if (quality != 'low') {
      canvas.drawCircle(
        center,
        radius * 0.12 + pulse2 * 5,
        Paint()
          ..color =
              const Color(0xFFFF003C).withValues(alpha: 0.15 + pulse * 0.1)
          ..maskFilter = _getBlur(15 + pulse * 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.styleKey != styleKey ||
        oldDelegate.quality != quality ||
        oldDelegate.shakeIntensity != shakeIntensity ||
        oldDelegate.tapEffects.length != tapEffects.length;
  }
}
