import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LegacyFallingEffect extends StatefulWidget {
  final String type;
  final bool isDark;
  final String density;
  final double opacity;
  final bool animate;

  const LegacyFallingEffect({
    super.key,
    required this.type,
    required this.isDark,
    this.density = 'balanced',
    this.opacity = 1,
    this.animate = true,
  });

  @override
  State<LegacyFallingEffect> createState() => _LegacyFallingEffectState();
}

class _LegacyFallingEffectState extends State<LegacyFallingEffect>
    with SingleTickerProviderStateMixin {
  static const Duration _initialAnimationDelay = Duration(milliseconds: 400);
  static const Duration _animationLoopDuration = Duration(seconds: 48);

  AnimationController? _controller;
  final List<_LegacyParticle> _particles = [];
  final math.Random _random = math.Random();
  bool _startupDelayApplied = false;

  bool get _shouldAnimate => widget.animate && widget.type != 'off';

  @override
  void initState() {
    super.initState();
    _seedParticles(reset: true);
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant LegacyFallingEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type || oldWidget.density != widget.density) {
      _seedParticles(reset: true);
    }
    if (oldWidget.animate != widget.animate ||
        oldWidget.type != widget.type ||
        oldWidget.density != widget.density) {
      _syncAnimationState();
    }
  }

  void _syncAnimationState() {
    if (_shouldAnimate) {
      final controller = _controller ??= AnimationController(
        vsync: this,
        duration: _animationLoopDuration,
      );
      if (!controller.isAnimating) {
        // ⚡ Delay animation start by 3s to reduce initial app startup lag
        if (!_startupDelayApplied) {
          _startupDelayApplied = true;
          Future.delayed(_initialAnimationDelay, () {
            if (mounted && _shouldAnimate) {
              controller.repeat();
            }
          });
        } else {
          controller.repeat();
        }
      }
      return;
    }

    _controller?.stop();
  }

  int _countForType(String type) {
    final base = switch (type) {
      'meteors' => 5,
      'bubbles' => 10,
      'snow' => 18,
      'leaves' => 8,
      'sparkles' => 9,
      'stars' => 8,
      _ => 7,
    };
    final scale = type == 'snow'
        ? switch (widget.density) {
            'low' => 0.12,
            'normal' => 0.46,
            'balanced' => 0.72,
            'high' => 0.96,
            _ => 1.0,
          }
        : switch (widget.density) {
            'low' => 0.08,
            'normal' => 0.34,
            'balanced' => 0.62,
            'high' => 0.92,
            _ => 1.0,
          };
    const platformScale = kIsWeb ? 0.48 : 0.82;
    final rawCount = math.max(1, (base * scale * platformScale).round());
    final maxCount = switch (widget.density) {
      'low' => 4,
      'balanced' => 10,
      'high' => 16,
      'normal' => 8,
      _ => 12,
    };
    return rawCount.clamp(1, maxCount);
  }

  void _seedParticles({bool reset = false}) {
    if (reset) {
      _particles.clear();
    }
    if (widget.type == 'off') {
      return;
    }
    final target = _countForType(widget.type);
    while (_particles.length < target) {
      _particles.add(_createParticle(initial: true));
    }
    if (_particles.length > target) {
      _particles.removeRange(target, _particles.length);
    }
  }

  _LegacyParticle _createParticle({required bool initial}) {
    final type = widget.type;
    final sizeBase = switch (type) {
      'sparkles' => 11.0,
      'stars' => 12.0,
      'meteors' => 18.0,
      'bubbles' => 24.0,
      'snow' => 12.5,
      'leaves' => 16.0,
      _ => 20.0,
    };
    final speedBase = switch (type) {
      'meteors' => 0.0046,
      'bubbles' => 0.00145,
      'snow' => 0.0012,
      'leaves' => 0.00135,
      'sparkles' => 0.0014,
      'stars' => 0.00095,
      _ => 0.00145,
    };
    final driftBase = switch (type) {
      'meteors' => 0.0024,
      'bubbles' => 0.0014,
      'snow' => 0.00235,
      'leaves' => 0.0026,
      'sparkles' => 0.0012,
      'stars' => 0.0008,
      _ => 0.0018,
    };

    final y = switch (type) {
      'bubbles' =>
        initial ? _random.nextDouble() : 1.05 + _random.nextDouble() * 0.35,
      'meteors' =>
        initial ? _random.nextDouble() : -0.25 - _random.nextDouble() * 0.3,
      'snow' => initial
          ? (_random.nextDouble() * 1.24) - 0.16
          : -0.36 - _random.nextDouble() * 0.56,
      _ => initial
          ? (_random.nextDouble() * 1.18) - 0.1
          : -0.3 - _random.nextDouble() * 0.52,
    };

    final x = switch (type) {
      'meteors' when !initial => _random.nextDouble() * 0.7,
      'snow' => (_random.nextDouble() * 1.12) - 0.06,
      _ => _random.nextDouble(),
    };

    final highDensity = widget.density == 'high';
    return _LegacyParticle(
      x: x,
      y: y,
      size: ((_random.nextDouble() * sizeBase) + (sizeBase * 0.46)) *
          (highDensity ? 1.08 : 1.0),
      speed: ((_random.nextDouble() * speedBase) + (speedBase * 0.6)) *
          (highDensity ? 0.94 : 1.0),
      drift: ((_random.nextDouble() * driftBase) + (driftBase * 0.4)) *
          (highDensity ? 1.16 : 1.0),
      opacity: (_random.nextDouble() * (highDensity ? 0.48 : 0.42)) +
          (highDensity ? 0.34 : 0.28),
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() * (highDensity ? 0.018 : 0.022)) -
          (highDensity ? 0.009 : 0.011),
      phase: _random.nextDouble() * math.pi * 2,
      twinkle: _random.nextDouble() * math.pi * 2,
      twinkleSpeed: _random.nextDouble() * (highDensity ? 0.06 : 0.08) +
          (highDensity ? 0.012 : 0.015),
      variant: _random.nextInt(3),
    );
  }

  void _recycleParticle(int index) {
    _particles[index] = _createParticle(initial: false);
  }

  void _tickParticles() {
    for (var i = 0; i < _particles.length; i++) {
      final particle = _particles[i];
      particle.rotation += particle.rotationSpeed;
      particle.twinkle += particle.twinkleSpeed;

      switch (widget.type) {
        case 'meteors':
          particle.y += particle.speed * 2.2;
          particle.x += particle.drift * 1.35;
          if (particle.y > 1.15 || particle.x > 1.18) {
            _recycleParticle(i);
          }
          break;
        case 'bubbles':
          particle.y -= particle.speed;
          particle.x += math.sin(particle.twinkle + particle.phase) *
              (particle.drift * 0.38);
          if (particle.y < -0.18 || particle.x < -0.15 || particle.x > 1.15) {
            _recycleParticle(i);
          }
          break;
        case 'snow':
          final sway = (math.sin(particle.twinkle + particle.phase) * 0.82) +
              (math.cos((particle.twinkle * 0.58) + particle.phase) * 0.34);
          particle.y += particle.speed * (0.96 + (particle.size * 0.014));
          particle.x += sway * (particle.drift * 0.72);
          if (particle.y > 1.2 || particle.x < -0.22 || particle.x > 1.22) {
            _recycleParticle(i);
          }
          break;
        case 'leaves':
          particle.y += particle.speed * 0.92;
          particle.x += math.sin(particle.twinkle + particle.phase) *
              (particle.drift * 0.75);
          if (particle.y > 1.18 || particle.x < -0.2 || particle.x > 1.2) {
            _recycleParticle(i);
          }
          break;
        case 'sparkles':
        case 'stars':
          particle.y += particle.speed * 0.58;
          particle.x += math.sin(particle.twinkle + particle.phase) *
              (particle.drift * 0.2);
          if (particle.y > 1.12 || particle.x < -0.15 || particle.x > 1.15) {
            _recycleParticle(i);
          }
          break;
        case 'hearts':
        default:
          particle.y += particle.speed;
          particle.x += math.sin(particle.twinkle + particle.phase) *
              (particle.drift * 0.46);
          if (particle.y > 1.16 || particle.x < -0.18 || particle.x > 1.18) {
            _recycleParticle(i);
          }
          break;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'off') {
      return const SizedBox.shrink();
    }
    final opacity = widget.opacity.clamp(0.0, 1.0);
    if (opacity <= 0.0) {
      return const SizedBox.shrink();
    }

    final shouldAnimateNow = _shouldAnimate && TickerMode.valuesOf(context).enabled;
    final useLiteRendering =
        kIsWeb || widget.density == 'low' || widget.density == 'balanced';

    if (!shouldAnimateNow) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: _LegacyFallingPainter(
            particles: _particles,
            type: widget.type,
            isDark: widget.isDark,
            globalOpacity: opacity,
            useLiteRendering: useLiteRendering,
          ),
          size: Size.infinite,
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          _tickParticles();
          return CustomPaint(
            painter: _LegacyFallingPainter(
              particles: _particles,
              type: widget.type,
              isDark: widget.isDark,
              globalOpacity: opacity,
              useLiteRendering: useLiteRendering,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _LegacyParticle {
  double x;
  double y;
  double size;
  double speed;
  double drift;
  double opacity;
  double rotation;
  double rotationSpeed;
  double phase;
  double twinkle;
  double twinkleSpeed;
  int variant;

  _LegacyParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.phase,
    required this.twinkle,
    required this.twinkleSpeed,
    required this.variant,
  });
}

class _LegacyFallingPainter extends CustomPainter {
  final List<_LegacyParticle> particles;
  final String type;
  final bool isDark;
  final double globalOpacity;
  final bool useLiteRendering;

  const _LegacyFallingPainter({
    required this.particles,
    required this.type,
    required this.isDark,
    required this.globalOpacity,
    required this.useLiteRendering,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final particle in particles) {
      final offset = Offset(particle.x * size.width, particle.y * size.height);
      final pulse = 0.7 + (math.sin(particle.twinkle) * 0.3);
      final alpha = (particle.opacity * pulse * globalOpacity).clamp(0.0, 1.0);
      if (alpha <= 0.001) {
        continue;
      }

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(particle.rotation);

      switch (type) {
        case 'sparkles':
          _paintSparkle(canvas, paint, particle, alpha);
          break;
        case 'stars':
          _paintStar(canvas, paint, particle, alpha);
          break;
        case 'meteors':
          _paintMeteor(canvas, paint, particle, alpha);
          break;
        case 'bubbles':
          _paintBubble(canvas, paint, particle, alpha);
          break;
        case 'snow':
          _paintSnowflake(canvas, paint, particle, alpha);
          break;
        case 'leaves':
          _paintLeaf(canvas, paint, particle, alpha);
          break;
        case 'hearts':
        default:
          _paintHeart(canvas, paint, particle, alpha);
          break;
      }

      canvas.restore();
    }
  }

  void _paintSparkle(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    if (!useLiteRendering) {
      final glowPaint = Paint()
        ..color = (isDark ? const Color(0xFFFFE8A3) : const Color(0xFFFFF3BF))
            .withValues(alpha: alpha * 0.52)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset.zero, particle.size * 0.24, glowPaint);
    }

    paint
      ..color =
          (isDark ? const Color(0xFFFFF4C1) : Colors.white).withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    _drawSparkle(canvas, paint, particle.size);
  }

  void _paintStar(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    if (!useLiteRendering) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFD965).withValues(alpha: alpha * 0.48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset.zero, particle.size * 0.28, glowPaint);
    }

    paint
      ..color = const Color(0xFFFFD54F).withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    _drawStar(canvas, paint, particle.size);
  }

  void _paintMeteor(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    if (useLiteRendering) {
      paint
        ..shader = null
        ..color =
            (isDark ? const Color(0xFFA7EEFF) : Colors.white).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (particle.size * 0.09).clamp(1.0, 2.4);
      canvas.drawLine(
        Offset(-particle.size * 0.7, -particle.size * 0.16),
        Offset(particle.size * 0.64, particle.size * 0.16),
        paint,
      );
      canvas.drawCircle(
        Offset(particle.size * 0.68, particle.size * 0.18),
        (particle.size * 0.12).clamp(1.4, 3.8),
        Paint()
          ..color = (isDark ? const Color(0xFFA7EEFF) : Colors.white)
              .withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final trailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          (isDark ? const Color(0xFF6FE3FF) : const Color(0xFFFFFBFF))
              .withValues(alpha: (alpha * 1.05).clamp(0.0, 1.0)),
        ],
      ).createShader(Rect.fromLTWH(
        -particle.size,
        -particle.size * 0.4,
        particle.size * 2.1,
        particle.size * 0.9,
      ))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (particle.size * 0.11).clamp(1.1, 3.2);
    final meteorGlowPaint = Paint()
      ..color = (isDark ? const Color(0xFF89EAFF) : Colors.white)
          .withValues(alpha: alpha * 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, particle.size * 0.32, meteorGlowPaint);
    canvas.drawLine(
      Offset(-particle.size * 0.8, -particle.size * 0.2),
      Offset(particle.size * 0.7, particle.size * 0.18),
      trailPaint,
    );

    paint
      ..color =
          (isDark ? const Color(0xFF7FE8FF) : Colors.white).withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(particle.size * 0.78, particle.size * 0.2),
      (particle.size * 0.14).clamp(1.8, 4.8),
      paint,
    );
  }

  void _paintBubble(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    paint
      ..color = (isDark ? const Color(0xFFB9F3FF) : Colors.white)
          .withValues(alpha: alpha * 0.64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (particle.size * 0.075).clamp(1.0, 2.4);
    canvas.drawCircle(Offset.zero, particle.size * 0.34, paint);

    paint
      ..color = (isDark ? const Color(0xFFDFFBFF) : Colors.white)
          .withValues(alpha: alpha * 0.24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, particle.size * 0.34, paint);

    paint
      ..color = Colors.white.withValues(alpha: alpha * 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-particle.size * 0.11, -particle.size * 0.12),
      particle.size * 0.11,
      paint,
    );
  }

  void _paintSnowflake(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    final frostColor =
        (isDark ? const Color(0xFFE8FAFF) : Colors.white).withValues(alpha: alpha);
    final glowColor =
        (isDark ? const Color(0xFFBFE8FF) : const Color(0xFFD9F3FF))
            .withValues(alpha: alpha * 0.38);

    if (!useLiteRendering) {
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          particle.size * 0.18,
        );
      canvas.drawCircle(Offset.zero, particle.size * 0.34, glowPaint);
    }

    if (useLiteRendering || particle.variant == 2) {
      paint
        ..shader = null
        ..color = frostColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, particle.size * 0.16, paint);

      paint
        ..color = glowColor.withValues(alpha: alpha * 0.92)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (particle.size * 0.06).clamp(1.0, 2.0);
      final radius = particle.size * 0.24;
      canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), paint);
      canvas.drawLine(Offset(0, -radius), Offset(0, radius), paint);
      return;
    }

    paint
      ..shader = LinearGradient(
        colors: [
          glowColor,
          frostColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: particle.size * 0.4),
      )
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (particle.size * 0.055).clamp(1.0, 2.2);

    final radius = particle.size * (particle.variant == 1 ? 0.3 : 0.26);
    for (int i = 0; i < 3; i++) {
      _drawSnowArm(
        canvas,
        paint,
        angle: i * (math.pi / 3),
        radius: radius,
        branchScale: particle.variant == 1 ? 0.26 : 0.22,
      );
    }

    paint
      ..shader = null
      ..color = frostColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, particle.size * 0.07, paint);
    canvas.drawCircle(
      Offset.zero,
      particle.size * 0.13,
      Paint()
        ..color = frostColor.withValues(alpha: alpha * 0.14)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawSnowArm(
    Canvas canvas,
    Paint paint, {
    required double angle,
    required double radius,
    required double branchScale,
  }) {
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    final end = Offset(dx, dy);
    final start = Offset(-dx, -dy);
    canvas.drawLine(start, end, paint);

    final branchLength = radius * branchScale;
    const branchAngleOffset = math.pi / 4.8;
    for (final (base, armAngle) in [
      (Offset(dx * 0.7, dy * 0.7), angle),
      (Offset(-dx * 0.7, -dy * 0.7), angle + math.pi),
    ]) {
      for (final direction in [-1.0, 1.0]) {
        final branchAngle =
            armAngle + math.pi + (branchAngleOffset * direction);
        canvas.drawLine(
          base,
          base +
              Offset(
                math.cos(branchAngle) * branchLength,
                math.sin(branchAngle) * branchLength,
              ),
          paint,
        );
      }
    }
  }

  void _paintLeaf(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    final palette = switch (particle.variant) {
      1 => const [Color(0xFFFFB74D), Color(0xFFFF7043)],
      2 => const [Color(0xFFFF8A65), Color(0xFFD84315)],
      _ => const [Color(0xFFFFCC80), Color(0xFFE65100)],
    };
    final path = Path()
      ..moveTo(0, -particle.size * 0.46)
      ..quadraticBezierTo(
        particle.size * 0.46,
        -particle.size * 0.18,
        particle.size * 0.28,
        particle.size * 0.18,
      )
      ..quadraticBezierTo(
        particle.size * 0.08,
        particle.size * 0.44,
        0,
        particle.size * 0.5,
      )
      ..quadraticBezierTo(
        -particle.size * 0.08,
        particle.size * 0.44,
        -particle.size * 0.28,
        particle.size * 0.18,
      )
      ..quadraticBezierTo(
        -particle.size * 0.46,
        -particle.size * 0.18,
        0,
        -particle.size * 0.46,
      );

    if (useLiteRendering) {
      paint
        ..shader = null
        ..color = palette.first.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
    } else {
      paint
        ..shader = LinearGradient(
          colors: [
            palette.first.withValues(alpha: alpha),
            palette.last.withValues(alpha: alpha),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: particle.size * 0.52),
        )
        ..style = PaintingStyle.fill;
    }
    canvas.drawPath(path, paint);

    paint
      ..shader = null
      ..color = const Color(0xFF8D4F25).withValues(alpha: alpha * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (particle.size * 0.03).clamp(0.8, 1.4);
    canvas.drawLine(
      Offset.zero,
      Offset(0, particle.size * 0.34),
      paint,
    );
  }

  void _paintHeart(
    Canvas canvas,
    Paint paint,
    _LegacyParticle particle,
    double alpha,
  ) {
    final color = switch (particle.variant) {
      1 => const Color(0xFFFF7DA8),
      2 => const Color(0xFFFF5E92),
      _ => isDark ? const Color(0xFFFF97BA) : const Color(0xFFFF4D73),
    };

    paint
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    final s = particle.size;
    final path = Path()
      ..moveTo(0, s * 0.34)
      ..cubicTo(0, s * 0.08, -s * 0.42, -s * 0.04, -s * 0.46, s * 0.3)
      ..cubicTo(-s * 0.48, s * 0.58, -s * 0.08, s * 0.84, 0, s)
      ..cubicTo(s * 0.08, s * 0.84, s * 0.48, s * 0.58, s * 0.46, s * 0.3)
      ..cubicTo(s * 0.42, -s * 0.04, 0, s * 0.08, 0, s * 0.34);
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(Canvas canvas, Paint paint, double size) {
    final outer = size * 0.34;
    final inner = size * 0.12;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi) / 4;
      final radius = i.isEven ? outer : inner;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final outer = size * 0.38;
    final inner = size * 0.16;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * math.pi) / 5 - (math.pi / 2);
      final radius = i.isEven ? outer : inner;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
