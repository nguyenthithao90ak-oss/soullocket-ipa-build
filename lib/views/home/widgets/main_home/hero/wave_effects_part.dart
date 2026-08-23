part of 'main_home_animated_wave_background.dart';

class _TapInteractionEffect {
  final Offset centerOffset;
  final DateTime startTime;
  final Duration duration;
  final int seed;

  _TapInteractionEffect({
    required this.centerOffset,
    required this.startTime,
    required this.duration,
  }) : seed = startTime.microsecondsSinceEpoch;

  double getProgress(DateTime now) {
    final elapsed = now.difference(startTime).inMilliseconds;
    return (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

extension _WaveEffectsPart on _WavePainter {
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

    if (quality == 'high') {
      paint.maskFilter = _getBlur(size * 0.25);
    } else if (quality == 'balanced') {
      paint.maskFilter = _getBlur(size * 0.15);
    }

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

    if (quality == 'high') {
      canvas.drawShadow(
        path,
        const Color(0xFFFF4F93).withValues(alpha: opacity * 0.3),
        4,
        false,
      );
    }
    canvas.drawPath(path, paint);
  }

  void _drawGlowHearts(Canvas canvas, double width, double height) {
    final heartCount = quality == 'low' ? 3 : (quality == 'balanced' ? 6 : 8);
    for (var i = 0; i < heartCount; i++) {
      final startX = width * ((i * 0.37 + 0.1) % 1.0);
      final speed = 0.5 + (i * 0.2 % 0.5);
      final size = 12.0 + (i * 5 % 12);

      final progress = (animationValue * speed + (i * 0.17)) % 1.0;
      final y = height +
          size -
          progress * (height + size * 2) +
          tiltY * (0.6 + i * 0.1);
      final x = startX +
          sin((animationValue * pi * 4) + i) * 15 +
          tiltX * (0.6 + i * 0.1);
      final opacity = sin(progress * pi);

      _drawHeartPath(canvas, x, y, size, opacity * 0.8);
    }
  }

  void _drawGlassBubbles(Canvas canvas, double width, double height) {
    final bubblePaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final count = quality == 'low' ? 4 : (quality == 'balanced' ? 7 : 10);
    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.43 + 0.05) % 1.0);
      final speed = 0.4 + (i * 0.15 % 0.6);
      final size = 6.0 + (i * 7 % 14);

      final progress = (animationValue * speed + (i * 0.23)) % 1.0;
      final y = height +
          size -
          progress * (height + size * 2) +
          tiltY * (0.5 + i * 0.1);
      final x = startX +
          cos((animationValue * pi * 3) + i * 2) * 12 +
          tiltX * (0.5 + i * 0.1);
      final opacity = sin(progress * pi);

      bubblePaint.color = Colors.white.withValues(alpha: 0.15 * opacity);
      if (quality == 'high') {
        bubblePaint.maskFilter = _getBlur(2);
      } else if (quality == 'balanced') {
        bubblePaint.maskFilter = _getBlur(1);
      } else {
        bubblePaint.maskFilter = null;
      }
      canvas.drawCircle(Offset(x, y), size, bubblePaint);

      if (quality != 'low') {
        borderPaint.color = Colors.white.withValues(alpha: 0.4 * opacity);
        canvas.drawCircle(Offset(x, y), size, borderPaint);
      }
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
    final anchors = quality == 'low'
        ? [
            Offset(width * 0.32, height * 0.35),
            Offset(width * 0.68, height * 0.42),
          ]
        : (quality == 'balanced'
            ? [
                Offset(width * 0.32, height * 0.35),
                Offset(width * 0.68, height * 0.42),
                Offset(width * 0.48, height * 0.65),
              ]
            : [
                Offset(width * 0.32, height * 0.35),
                Offset(width * 0.68, height * 0.42),
                Offset(width * 0.48, height * 0.65),
                Offset(width * 0.20, height * 0.58),
                Offset(width * 0.78, height * 0.28),
              ]);

    for (var b = 0; b < anchors.length; b++) {
      final progress = (animationValue + b * 0.29) % 1.0;
      if (progress < 0.2) {
        final t = progress / 0.2;
        final sy = height - (height - anchors[b].dy) * t;
        final paint = Paint()
          ..color = colors[b % colors.length].withValues(alpha: 1 - t)
          ..strokeWidth = 2.0;
        if (quality == 'high') {
          paint.maskFilter = _getBlur(2);
        } else if (quality == 'balanced') {
          paint.maskFilter = _getBlur(1);
        }
        canvas.drawLine(
          Offset(anchors[b].dx, sy + 25),
          Offset(anchors[b].dx, sy),
          paint,
        );
      }
    }

    final particleCount =
        quality == 'low' ? 8 : (quality == 'balanced' ? 14 : 24);
    for (var b = 0; b < anchors.length; b++) {
      final progress = (animationValue + b * 0.29) % 1.0;
      if (progress >= 0.2) {
        final burstProgress = (progress - 0.2) / 0.8;
        final burstRadius = radius * (0.05 + burstProgress * 0.65);

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
          final paint = Paint()
            ..color = colors[(i + b) % colors.length]
                .withValues(alpha: (1 - burstProgress) * (0.6 + twinkle * 0.4))
            ..strokeWidth = 1.5 + (1 - burstProgress) * 2.0
            ..strokeCap = StrokeCap.round;
          if (quality == 'high') {
            paint.maskFilter = _getBlur(3);
          } else if (quality == 'balanced') {
            paint.maskFilter = _getBlur(1.5);
          }
          canvas.drawLine(start, end, paint);

          if (quality != 'low' &&
              isLong &&
              burstProgress > 0.4 &&
              burstProgress < 0.9) {
            final paintDot = Paint()
              ..color = Colors.white.withValues(alpha: 1 - burstProgress);
            if (quality == 'high') {
              paintDot.maskFilter = _getBlur(2);
            } else if (quality == 'balanced') {
              paintDot.maskFilter = _getBlur(1);
            }
            canvas.drawCircle(
              end,
              2.0 * (1 - burstProgress),
              paintDot,
            );
          }
        }

        if (quality != 'low' && burstProgress < 0.4) {
          final paintFlash = Paint()
            ..color = Colors.white.withValues(alpha: 1 - burstProgress / 0.4);
          if (quality == 'high') {
            paintFlash.maskFilter = _getBlur(5);
          } else if (quality == 'balanced') {
            paintFlash.maskFilter = _getBlur(2.5);
          }
          canvas.drawCircle(
            anchors[b],
            6 * (1 - burstProgress / 0.4),
            paintFlash,
          );
        }
      }
    }
  }

  void _drawCherryBlossom(Canvas canvas, double width, double height,
      Offset center, double radius) {
    // Nền gradient hồng pastel mềm mại
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        colors: [
          const Color(0xFFFFF0F5).withValues(alpha: 0.95),
          const Color(0xFFFFE4EC).withValues(alpha: 0.9),
          const Color(0xFFFFC1D4).withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Lớp glow hồng nhẹ ở tâm
    if (quality != 'low') {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF69B4).withValues(alpha: 0.12)
        ..maskFilter = _getBlur(40);
      canvas.drawCircle(
        Offset(center.dx, center.dy + sin(animationValue * pi * 2) * 10),
        radius * 0.5,
        glowPaint,
      );
    }

    final count = quality == 'low' ? 8 : (quality == 'balanced' ? 16 : 28);
    final petalColors = [
      const Color(0xFFFFB7C5),
      const Color(0xFFF8A4B8),
      const Color(0xFFFFCDD2),
      const Color(0xFFFF8FAB),
      const Color(0xFFFFE0E6),
    ];
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.19 + 0.05) % 1.0);
      final speed = 0.15 + (i * 0.07 % 0.35);
      final size = 5.0 + (i * 3.7 % 10);

      final progress = (animationValue * speed + (i * 0.11)) % 1.0;
      final swayAmount = 25.0 + (i % 4) * 8;
      final y =
          -size * 2 + progress * (height + size * 4) + tiltY * (0.3 + i * 0.08);
      final x = startX +
          sin((animationValue * pi * 2.5) + i * 1.3) * swayAmount +
          cos((animationValue * pi * 1.7) + i * 0.7) * swayAmount * 0.4 +
          tiltX * (0.3 + i * 0.08);
      final opacity = sin(progress * pi) * (0.6 + (i % 3) * 0.15);

      final colorIdx = i % petalColors.length;
      paint.color =
          petalColors[colorIdx].withValues(alpha: opacity.clamp(0.0, 1.0));

      if (quality == 'high' && size > 7) {
        paint.maskFilter = _getBlur(size * 0.12);
      }

      canvas.save();
      canvas.translate(x, y);
      final rotSpeed = (i % 2 == 0 ? 1.0 : -1.0) * (0.6 + (i % 5) * 0.15);
      canvas.rotate(animationValue * pi * rotSpeed + i * 0.5);

      // 5 cánh hoa anh đào
      const petalCount = 5;
      for (var p = 0; p < petalCount; p++) {
        canvas.save();
        canvas.rotate(p * 2 * pi / petalCount);
        final petal = Path();
        petal.moveTo(0, 0);
        petal.quadraticBezierTo(size * 0.5, -size * 0.6, 0, -size);
        petal.quadraticBezierTo(-size * 0.5, -size * 0.6, 0, 0);
        canvas.drawPath(petal, paint);
        canvas.restore();
      }
      // Nhụy hoa nhỏ ở giữa
      canvas.drawCircle(
          Offset.zero,
          size * 0.15,
          Paint()
            ..color = const Color(0xFFFFEB3B).withValues(alpha: opacity * 0.9));
      canvas.restore();
    }
  }

  void _drawMeteorShower(Canvas canvas, double width, double height,
      Offset center, double radius) {
    // Nền trời đêm gradient sâu
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.5),
        colors: [
          const Color(0xFF1A1A3E).withValues(alpha: 0.98),
          const Color(0xFF0D0D2B).withValues(alpha: 0.98),
          const Color(0xFF050510).withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Dải ngân hà mờ
    if (quality != 'low') {
      final milkyPaint = Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.06)
        ..maskFilter = _getBlur(50);
      final milkyPath = Path();
      milkyPath.moveTo(0, height * 0.2);
      milkyPath.quadraticBezierTo(
          width * 0.3, height * 0.4, width * 0.6, height * 0.15);
      milkyPath.quadraticBezierTo(
          width * 0.8, height * 0.05, width, height * 0.3);
      milkyPath.lineTo(width, height * 0.4);
      milkyPath.quadraticBezierTo(
          width * 0.7, height * 0.15, width * 0.4, height * 0.35);
      milkyPath.quadraticBezierTo(width * 0.15, height * 0.5, 0, height * 0.35);
      milkyPath.close();
      canvas.drawPath(milkyPath, milkyPaint);
    }

    // Sao nhấp nháy nhiều lớp
    final starCount = quality == 'low' ? 15 : (quality == 'balanced' ? 30 : 55);
    final starPaint = Paint();
    for (var i = 0; i < starCount; i++) {
      final x = width * ((i * 0.137 + 0.03) % 1.0);
      final y = height * ((i * 0.193 + 0.02) % 1.0);
      final twinkleSpeed = 3.0 + (i % 5) * 1.5;
      final twinkle =
          (sin(animationValue * pi * twinkleSpeed + i * 1.7) + 1) * 0.5;
      final starSize = 0.5 + (i % 4) * 0.5;
      final starColor = i % 7 == 0
          ? const Color(0xFFBBDEFB)
          : (i % 5 == 0 ? const Color(0xFFFFCDD2) : Colors.white);
      starPaint.color =
          starColor.withValues(alpha: (0.2 + 0.8 * twinkle).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), starSize, starPaint);

      // Tia sáng cho sao lớn
      if (quality != 'low' && starSize > 1.2 && twinkle > 0.7) {
        starPaint.color = starColor.withValues(alpha: twinkle * 0.3);
        canvas.drawLine(Offset(x - starSize * 2, y),
            Offset(x + starSize * 2, y), starPaint..strokeWidth = 0.5);
        canvas.drawLine(Offset(x, y - starSize * 2),
            Offset(x, y + starSize * 2), starPaint);
        starPaint.strokeWidth = 0.0;
      }
    }

    // Sao băng với đuôi dài gradient và glow
    final meteorCount = quality == 'low' ? 2 : (quality == 'balanced' ? 3 : 5);
    for (var i = 0; i < meteorCount; i++) {
      final speed = 0.8 + (i * 0.35);
      final progress = (animationValue * speed + (i * 0.25)) % 1.0;
      if (progress > 0.7) continue;

      final tailLength = 50.0 + (i * 15);
      final angle = -pi / 4 - (i * 0.15);
      final originX = width * (0.2 + (i * 0.18) % 0.7);
      const originY = -20.0;

      final headX = originX + progress * width * 0.8 * cos(angle + pi / 2);
      final headY = originY + progress * height * 1.3;
      final tailX = headX - tailLength * cos(angle + pi / 4);
      final tailY = headY - tailLength * sin(angle + pi / 4).abs();

      // Glow quanh đầu sao băng
      if (quality != 'low') {
        canvas.drawCircle(
          Offset(headX, headY),
          4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..maskFilter = _getBlur(6),
        );
      }

      // Đuôi gradient
      final meteorPaint = Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFBBDEFB).withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(
            Rect.fromPoints(Offset(headX, headY), Offset(tailX, tailY)));
      canvas.drawLine(Offset(headX, headY), Offset(tailX, tailY), meteorPaint);

      // Đầu sao băng sáng
      canvas.drawCircle(
          Offset(headX, headY), 2.0, Paint()..color = Colors.white);
    }
  }

  void _drawTapEffects(Canvas canvas, Offset center, double radius) {
    if (tapEffects.isEmpty) return;
    final now = DateTime.now();

    for (final effect in tapEffects) {
      final rawProgress = effect.getProgress(now);
      if (rawProgress >= 1.0) continue;

      // Easing curve (easeOutCubic) to make explosion pop fast then slow down
      final progress = 1.0 - pow(1.0 - rawProgress, 3);
      final origin = Offset(center.dx + effect.centerOffset.dx,
          center.dy + effect.centerOffset.dy);
      final rng = Random(effect.seed);
      final fadeOpacity = (1.0 - rawProgress);

      if (styleKey == 'fireworks' ||
          styleKey == 'meteor_shower' ||
          styleKey == 'galaxy') {
        // --- Starburst / Fireworks ---
        final particleCount =
            quality == 'low' ? 8 : (quality == 'balanced' ? 14 : 20);
        final paint = Paint()
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus;

        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 40.0 + rng.nextDouble() * 100.0;
          final pDist = progress * speed;

          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy +
              sin(angle) * pDist +
              (progress * progress * 20.0); // Slight gravity

          final trailLength = (speed * 0.15 * fadeOpacity).clamp(2.0, 15.0);
          final size = 1.5 + rng.nextDouble() * 2.5;

          paint.color = (rng.nextBool()
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFF00F5FF))
              .withValues(alpha: fadeOpacity * (0.6 + rng.nextDouble() * 0.4));
          paint.strokeWidth = size * fadeOpacity;

          canvas.drawLine(
            Offset(
                px - cos(angle) * trailLength, py - sin(angle) * trailLength),
            Offset(px, py),
            paint,
          );
        }
      } else if (styleKey == 'candy' || styleKey == 'hyper') {
        // --- Confetti ---
        final colors = [
          const Color(0xFFFF6FB7),
          const Color(0xFF53D8FF),
          const Color(0xFFFFD54F),
          const Color(0xFFB388FF),
          const Color(0xFF69F0AE)
        ];
        final particleCount =
            quality == 'low' ? 6 : (quality == 'balanced' ? 10 : 15);
        final paint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 30.0 + rng.nextDouble() * 60.0;
          final pDist = progress * speed;
          final gravity = progress * progress * 50.0;

          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy + sin(angle) * pDist + gravity;

          final size = 3.0 + rng.nextDouble() * 5.0;
          paint.color =
              colors[rng.nextInt(colors.length)].withValues(alpha: fadeOpacity);
          canvas.drawCircle(Offset(px, py), size * fadeOpacity, paint);
        }
      } else if (styleKey == 'cherry_blossom') {
        // --- Petal Burst ---
        final colors = [
          const Color(0xFFFFB7C5),
          const Color(0xFFF8A4B8),
          const Color(0xFFFFCDD2),
          const Color(0xFFFFF0F5)
        ];
        final particleCount =
            quality == 'low' ? 4 : (quality == 'balanced' ? 6 : 9);
        final paint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 30.0 + rng.nextDouble() * 50.0;
          final pDist = progress * speed;

          final drift = sin(progress * pi * 3 + i) * 15.0; // Swaying motion
          final px = origin.dx + cos(angle) * pDist + drift;
          final py = origin.dy + sin(angle) * pDist + progress * 25.0;

          final size = 4.0 + rng.nextDouble() * 4.0;
          paint.color =
              colors[rng.nextInt(colors.length)].withValues(alpha: fadeOpacity);

          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(progress * pi * 5 * (rng.nextBool() ? 1 : -1) + angle);
          final petal = Path();
          petal.moveTo(0, 0);
          petal.quadraticBezierTo(size * 0.5, -size * 0.6, 0, -size);
          petal.quadraticBezierTo(-size * 0.5, -size * 0.6, 0, 0);
          canvas.drawPath(petal, paint);
          canvas.restore();
        }
      } else if (styleKey == 'floating_hearts' || styleKey == 'glow') {
        // --- Heart / Glow Burst ---
        final particleCount =
            quality == 'low' ? 4 : (quality == 'balanced' ? 6 : 10);
        final paint = Paint()..style = PaintingStyle.fill;
        if (styleKey == 'glow') {
          paint.blendMode = BlendMode.plus;
        }
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 20.0 + rng.nextDouble() * 40.0;
          final pDist = progress * speed;

          final px = origin.dx + cos(angle) * pDist;
          final py =
              origin.dy + sin(angle) * pDist - progress * 30.0; // Float up

          final size = 3.0 + rng.nextDouble() * 6.0;
          paint.color =
              const Color(0xFFFF4F93).withValues(alpha: fadeOpacity * 0.85);

          final path = Path();
          path.moveTo(px, py + size / 4);
          path.cubicTo(px - size, py - size * 0.7, px - size * 0.5, py - size,
              px, py - size / 4);
          path.cubicTo(px + size * 0.5, py - size, px + size, py - size * 0.7,
              px, py + size / 4);
          canvas.drawPath(path, paint);
        }
      } else if (styleKey == 'lava') {
        // --- Lava Bubbles ---
        final colors = [
          const Color(0xFFFF1744),
          const Color(0xFFFF9100),
          const Color(0xFFFFEA00)
        ];
        final particleCount =
            quality == 'low' ? 4 : (quality == 'balanced' ? 6 : 10);
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.screen;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 15.0 + rng.nextDouble() * 35.0;
          final pDist = progress * speed;

          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy + sin(angle) * pDist - progress * 15.0;

          final size = 4.0 + rng.nextDouble() * 7.0;
          paint.color =
              colors[rng.nextInt(colors.length)].withValues(alpha: fadeOpacity);
          canvas.drawCircle(Offset(px, py), size * fadeOpacity, paint);
        }
      } else if (styleKey == 'neon' ||
          styleKey == 'neon_pulse' ||
          styleKey == 'aurora') {
        // --- Neon Pulse ---
        final ringColor = styleKey == 'aurora'
            ? const Color(0xFF00FFEA)
            : const Color(0xFFFF003C);
        final paint = Paint()
          ..color = ringColor.withValues(alpha: fadeOpacity * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * fadeOpacity
          ..blendMode = BlendMode.plus;

        canvas.drawCircle(origin, progress * 55.0, paint);

        final particleCount = quality == 'low' ? 4 : 8;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final px = origin.dx + cos(angle) * progress * 65.0;
          final py = origin.dy + sin(angle) * progress * 65.0;
          canvas.drawCircle(
              Offset(px, py),
              2.5 * fadeOpacity,
              Paint()
                ..color = Colors.white.withValues(alpha: fadeOpacity)
                ..blendMode = BlendMode.plus);
        }
      } else {
        // --- Default Ripple (Plain/Glass/Deep Ocean/Golden Sunset) ---
        final maxR = radius * 0.6;
        final currentRadius = maxR * progress;
        final baseColor = (styleKey == 'deep_ocean')
            ? const Color(0xFF90E0EF)
            : (styleKey == 'golden_sunset')
                ? const Color(0xFFFFD54F)
                : const Color(0xFFFFEBF2);

        final ripplePaint = Paint()
          ..color = baseColor.withValues(alpha: fadeOpacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + fadeOpacity * 3.0;

        canvas.drawCircle(origin, currentRadius, ripplePaint);

        if (progress > 0.2) {
          final progress2 = (progress - 0.2) / 0.8;
          final opacity2 = (1.0 - rawProgress) * 0.4;
          final ripplePaint2 = Paint()
            ..color = baseColor.withValues(alpha: opacity2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0 + fadeOpacity * 2.0;

          canvas.drawCircle(origin, maxR * 0.75 * progress2, ripplePaint2);
        }
      }
    }
  }
}
