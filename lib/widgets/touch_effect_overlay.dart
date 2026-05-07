import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TouchEffectOverlay extends StatefulWidget {
  final Widget child;

  const TouchEffectOverlay({super.key, required this.child});

  @override
  State<TouchEffectOverlay> createState() => _TouchEffectOverlayState();
}

class _TouchEffectOverlayState extends State<TouchEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_TouchParticle> _particles = [];
  final math.Random _random = math.Random();
  final Duration _moveThrottle = kIsWeb
      ? const Duration(milliseconds: 95)
      : const Duration(milliseconds: 60);
  DateTime? _lastTrailAt;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  void _tickParticles() {
    if (_particles.isEmpty) return;
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.12; // gravity
      p.rotation += p.rotationSpeed;
      p.life -= kIsWeb ? 0.035 : 0.03;
      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }
    if (_particles.isEmpty && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ensureTickerRunning() {
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _addParticles(Offset position, {int? countOverride}) {
    if (!mounted) return;
    final int count = countOverride ??
        (kIsWeb ? 2 + _random.nextInt(2) : 2 + _random.nextInt(2));

    _ensureTickerRunning();
    for (int i = 0; i < count; i++) {
      final speed = 2.0 + _random.nextDouble() * 3.0;
      final angle = _random.nextDouble() * 2 * math.pi;
      _particles.add(
        _TouchParticle(
          x: position.dx,
          y: position.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 2.0, // Initial upward burst
          life: 1.0,
          size: (kIsWeb ? 6.0 : 7.0) + _random.nextDouble() * 8.0,
          color: _randomColor(),
          rotation: _random.nextDouble() * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.25,
          type: _random.nextInt(3), // 0: star, 1: heart, 2: circle
        ),
      );
    }
    const maxParticles = kIsWeb ? 20 : 32;
    if (_particles.length > maxParticles) {
      _particles.removeRange(0, _particles.length - maxParticles);
    }
  }

  Color _randomColor() {
    const colors = [
      Color(0xFFFF4D73), // Pink
      Color(0xFFFF97BA), // Light Pink
      Color(0xFFFFD54F), // Yellow/Gold
      Color(0xFF9EE7FF), // Light Blue
      Color(0xFFB388FF), // Light Purple
      Color(0xFFFFFFFF), // White
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _addParticles(event.localPosition),
      onPointerMove: (event) {
        if (event.buttons == 0 || _particles.length > (kIsWeb ? 18 : 32)) {
          return;
        }
        final now = DateTime.now();
        if (_lastTrailAt != null &&
            now.difference(_lastTrailAt!) < _moveThrottle) {
          return;
        }
        _lastTrailAt = now;
        _addParticles(event.localPosition, countOverride: 1);
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    if (_controller.isAnimating) {
                      _tickParticles();
                    }
                    if (_particles.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: _TouchEffectPainter(
                        particles: _particles,
                        useGlow: !kIsWeb && _particles.length <= 20,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TouchParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  int type;

  _TouchParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.type,
  });
}

class _TouchEffectPainter extends CustomPainter {
  final List<_TouchParticle> particles;
  final bool useGlow;

  _TouchEffectPainter({required this.particles, required this.useGlow});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      if (p.life <= 0) continue;

      paint.color = p.color.withValues(alpha: (p.life * 0.8).clamp(0.0, 1.0));
      paint.maskFilter =
          useGlow ? MaskFilter.blur(BlurStyle.normal, p.size * 0.28) : null;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      final currentSize =
          p.size * Curves.easeOutCubic.transform(p.life.clamp(0.0, 1.0));

      if (p.type == 0) {
        _drawStar(canvas, paint, currentSize);
      } else if (p.type == 1) {
        _drawHeart(canvas, paint, currentSize);
      } else {
        canvas.drawCircle(Offset.zero, currentSize * 0.4, paint);
        paint.maskFilter = null;
        paint.color = Colors.white.withValues(alpha: p.life.clamp(0.0, 1.0));
        canvas.drawCircle(Offset.zero, currentSize * 0.15, paint);
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    path.moveTo(0, -radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.quadraticBezierTo(0, 0, 0, radius);
    path.quadraticBezierTo(0, 0, -radius, 0);
    path.quadraticBezierTo(0, 0, 0, -radius);

    canvas.drawPath(path, paint);

    paint.maskFilter = null;
    paint.color = Colors.white.withValues(alpha: paint.color.opacity);
    final corePath = Path();
    final coreRadius = radius * 0.4;
    corePath.moveTo(0, -coreRadius);
    corePath.quadraticBezierTo(0, 0, coreRadius, 0);
    corePath.quadraticBezierTo(0, 0, 0, coreRadius);
    corePath.quadraticBezierTo(0, 0, -coreRadius, 0);
    corePath.quadraticBezierTo(0, 0, 0, -coreRadius);
    canvas.drawPath(corePath, paint);
  }

  void _drawHeart(Canvas canvas, Paint paint, double size) {
    final width = size;
    final height = size * 0.9;
    final path = Path();

    path.moveTo(0, height * 0.3);
    path.cubicTo(-width * 0.5, -height * 0.2, -width, height * 0.4, 0, height);
    path.moveTo(0, height * 0.3);
    path.cubicTo(width * 0.5, -height * 0.2, width, height * 0.4, 0, height);

    canvas.drawPath(path, paint);

    paint.maskFilter = null;
    paint.color = Colors.white.withValues(alpha: paint.color.opacity * 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TouchEffectPainter oldDelegate) => true;
}
