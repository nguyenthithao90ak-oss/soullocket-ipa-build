import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SeasonalType {
  snow, // Tháng 12: Tuyết rơi mùa đông
  fireworks, // Cuối năm & Tết: Pháo hoa lấp lánh
  rosePetals, // Valentine (10-18/02): Cánh hoa hồng rơi
  magicSparkles, // Ngày thường: Bụi sao lấp lánh nhẹ nhàng
}

class SeasonalParticleOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const SeasonalParticleOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<SeasonalParticleOverlay> createState() => _SeasonalParticleOverlayState();
}

class _SeasonalParticleOverlayState extends State<SeasonalParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final SeasonalType _season;
  final List<_SeasonalParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _season = _determineSeason();
    _initParticlePool();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  SeasonalType _determineSeason() {
    final now = DateTime.now();
    if (now.month == 12) return SeasonalType.snow;
    if ((now.month == 1 && now.day >= 20) || (now.month == 2 && now.day <= 5)) {
      return SeasonalType.fireworks; // Tết Nguyên Đán
    }
    if (now.month == 2 && now.day >= 10 && now.day <= 18) {
      return SeasonalType.rosePetals; // Valentine
    }
    return SeasonalType.magicSparkles;
  }

  void _initParticlePool() {
    final count = _season == SeasonalType.snow ? 24 : 18;
    for (int i = 0; i < count; i++) {
      _particles.add(_SeasonalParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.15 + _random.nextDouble() * 0.35,
        size: 3.0 + _random.nextDouble() * 5.0,
        opacity: 0.2 + _random.nextDouble() * 0.5,
        wobbleSpeed: 1.0 + _random.nextDouble() * 2.0,
        wobbleOffset: _random.nextDouble() * math.pi * 2,
        rotation: _random.nextDouble() * math.pi * 2,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SeasonalParticlePainter(
                      particles: _particles,
                      season: _season,
                      progress: _animCtrl.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonalParticle {
  double x;
  double y;
  final double speed;
  final double size;
  final double opacity;
  final double wobbleSpeed;
  final double wobbleOffset;
  double rotation;

  _SeasonalParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.wobbleSpeed,
    required this.wobbleOffset,
    required this.rotation,
  });
}

class _SeasonalParticlePainter extends CustomPainter {
  final List<_SeasonalParticle> particles;
  final SeasonalType season;
  final double progress;

  _SeasonalParticlePainter({
    required this.particles,
    required this.season,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Calculate dynamic position based on progress
      final currentY = (p.y + progress * p.speed) % 1.0;
      final wobble = math.sin(progress * math.pi * 2 * p.wobbleSpeed + p.wobbleOffset) * 0.03;
      final currentX = (p.x + wobble).clamp(0.0, 1.0);

      final dx = currentX * size.width;
      final dy = currentY * size.height;

      switch (season) {
        case SeasonalType.snow:
          paint.color = Colors.white.withValues(alpha: p.opacity * 0.85);
          canvas.drawCircle(Offset(dx, dy), p.size, paint);
          break;

        case SeasonalType.rosePetals:
          paint.color = const Color(0xFFFF2D75).withValues(alpha: p.opacity * 0.6);
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(progress * math.pi * 2 + p.wobbleOffset);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size),
            paint,
          );
          canvas.restore();
          break;

        case SeasonalType.fireworks:
          final color = p.wobbleOffset > math.pi
              ? const Color(0xFFFFD700)
              : const Color(0xFFFF4081);
          paint.color = color.withValues(alpha: p.opacity * 0.7);
          canvas.drawCircle(Offset(dx, dy), p.size * 0.8, paint);
          break;

        case SeasonalType.magicSparkles:
          paint.color = const Color(0xFFF472B6).withValues(alpha: p.opacity * 0.45);
          canvas.drawCircle(Offset(dx, dy), p.size * 0.6, paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonalParticlePainter oldDelegate) => true;
}
