import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';

class LoveWeatherOverlay extends StatefulWidget {
  final String weatherType;

  const LoveWeatherOverlay({
    super.key,
    required this.weatherType,
  });

  @override
  State<LoveWeatherOverlay> createState() => _LoveWeatherOverlayState();
}

class _LoveWeatherOverlayState extends State<LoveWeatherOverlay>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  final List<_WeatherParticle> _particles = [];
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _seedParticles();
  }

  @override
  void didUpdateWidget(covariant LoveWeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherType != widget.weatherType) {
      _seedParticles();
    }
  }

  void _seedParticles() {
    final config = _configFor(widget.weatherType);
    _particles
      ..clear()
      ..addAll(
        List.generate(config.count, (_) {
          return _WeatherParticle.random(_random, config);
        }),
      );
  }

  void _updateParticles() {
    final config = _configFor(widget.weatherType);
    for (var i = 0; i < _particles.length; i++) {
      final particle = _particles[i];
      final next = particle.copyWith(
        x: particle.x + particle.drift,
        y: particle.y + particle.speed,
        rotation: particle.rotation + particle.rotationSpeed,
      );

      if (next.y > 1.15 || next.x < -0.2 || next.x > 1.2) {
        _particles[i] = _WeatherParticle.reset(_random, config);
      } else {
        _particles[i] = next;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            _updateParticles();
            return CustomPaint(
              painter: _WeatherPainter(
                particles: _particles,
                config: _configFor(widget.weatherType),
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final List<_WeatherParticle> particles;
  final _WeatherConfig config;

  const _WeatherPainter({
    required this.particles,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final dx = particle.x * size.width;
      final dy = particle.y * size.height;
      final offset = Offset(dx, dy);
      paint.color = config.color.withValues(alpha: particle.opacity);

      switch (config.type) {
        case 'hearts':
          _drawHeart(canvas, offset, particle.size, paint);
          break;
        case 'rain':
          _drawRain(canvas, offset, particle, paint);
          break;
        case 'snow':
          canvas.drawCircle(offset, particle.size * 0.22, paint);
          break;
        case 'sun':
          _drawSun(canvas, offset, particle.size, paint);
          break;
        default:
          canvas.drawCircle(offset, particle.size * 0.2, paint);
      }
    }
  }

  void _drawRain(
    Canvas canvas,
    Offset offset,
    _WeatherParticle particle,
    Paint paint,
  ) {
    final rainPaint = paint
      ..strokeWidth = max(1.4, particle.size * 0.12)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      offset,
      Offset(
        offset.dx + particle.size * 0.18,
        offset.dy + particle.size,
      ),
      rainPaint,
    );
  }

  void _drawSun(Canvas canvas, Offset center, double size, Paint paint) {
    final glowPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, size * 0.55, glowPaint);
    canvas.drawCircle(center, size * 0.28, paint);

    final rayPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final inner = Offset(
        center.dx + cos(angle) * size * 0.4,
        center.dy + sin(angle) * size * 0.4,
      );
      final outer = Offset(
        center.dx + cos(angle) * size * 0.7,
        center.dy + sin(angle) * size * 0.7,
      );
      canvas.drawLine(inner, outer, rayPaint);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.25)
      ..cubicTo(
        center.dx - size * 0.45,
        center.dy - size * 0.32,
        center.dx - size * 0.9,
        center.dy + size * 0.22,
        center.dx,
        center.dy + size,
      )
      ..cubicTo(
        center.dx + size * 0.9,
        center.dy + size * 0.22,
        center.dx + size * 0.45,
        center.dy - size * 0.32,
        center.dx,
        center.dy + size * 0.25,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.config.type != config.type ||
        oldDelegate.particles != particles;
  }
}

_WeatherConfig _configFor(String type) {
  switch (type) {
    case 'rain':
      return const _WeatherConfig(
        type: 'rain',
        count: 36,
        baseSpeed: 0.018,
        driftRange: 0.002,
        sizeRange: 18,
        minSize: 10,
        color: SLColors.info,
      );
    case 'snow':
      return const _WeatherConfig(
        type: 'snow',
        count: 30,
        baseSpeed: 0.006,
        driftRange: 0.004,
        sizeRange: 16,
        minSize: 8,
        color: Colors.white,
      );
    case 'sun':
      return const _WeatherConfig(
        type: 'sun',
        count: 14,
        baseSpeed: 0.003,
        driftRange: 0.002,
        sizeRange: 20,
        minSize: 18,
        color: SLColors.warningGold,
      );
    default:
      return const _WeatherConfig(
        type: 'hearts',
        count: 24,
        baseSpeed: 0.008,
        driftRange: 0.003,
        sizeRange: 18,
        minSize: 12,
        color: SLColors.primaryActive,
      );
  }
}

class _WeatherParticle {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double opacity;
  final double drift;
  final double rotation;
  final double rotationSpeed;

  const _WeatherParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.drift,
    required this.rotation,
    required this.rotationSpeed,
  });

  factory _WeatherParticle.random(Random random, _WeatherConfig config) {
    return _WeatherParticle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      speed: config.baseSpeed + random.nextDouble() * 0.008,
      size: config.minSize + random.nextDouble() * config.sizeRange,
      opacity: 0.24 + random.nextDouble() * 0.56,
      drift: (random.nextDouble() - 0.5) * config.driftRange,
      rotation: random.nextDouble() * pi,
      rotationSpeed: (random.nextDouble() - 0.5) * 0.04,
    );
  }

  factory _WeatherParticle.reset(Random random, _WeatherConfig config) {
    return _WeatherParticle(
      x: random.nextDouble(),
      y: -0.15 - random.nextDouble() * 0.25,
      speed: config.baseSpeed + random.nextDouble() * 0.008,
      size: config.minSize + random.nextDouble() * config.sizeRange,
      opacity: 0.24 + random.nextDouble() * 0.56,
      drift: (random.nextDouble() - 0.5) * config.driftRange,
      rotation: random.nextDouble() * pi,
      rotationSpeed: (random.nextDouble() - 0.5) * 0.04,
    );
  }

  _WeatherParticle copyWith({
    double? x,
    double? y,
    double? rotation,
  }) {
    return _WeatherParticle(
      x: x ?? this.x,
      y: y ?? this.y,
      speed: speed,
      size: size,
      opacity: opacity,
      drift: drift,
      rotation: rotation ?? this.rotation,
      rotationSpeed: rotationSpeed,
    );
  }
}

class _WeatherConfig {
  final String type;
  final int count;
  final double baseSpeed;
  final double driftRange;
  final double sizeRange;
  final double minSize;
  final Color color;

  const _WeatherConfig({
    required this.type,
    required this.count,
    required this.baseSpeed,
    required this.driftRange,
    required this.sizeRange,
    required this.minSize,
    required this.color,
  });
}
