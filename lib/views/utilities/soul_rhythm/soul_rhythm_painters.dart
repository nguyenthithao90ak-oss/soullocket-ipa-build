import 'dart:math' as math;

import 'package:flutter/material.dart';

class _GridGeometryCache {
  const _GridGeometryCache({required this.vertical, required this.horizontal});

  final List<double> vertical;
  final List<double> horizontal;
}

class _LaneGeometryCache {
  const _LaneGeometryCache(this.positions);

  final List<double> positions;
}

class _PerspectiveGridCache {
  const _PerspectiveGridCache({
    required this.diagonalStarts,
    required this.horizontalY,
  });

  final List<double> diagonalStarts;
  final List<double> horizontalY;
}

class _BgParticleSeed {
  const _BgParticleSeed({
    required this.baseX,
    required this.baseY,
    required this.speedX,
    required this.speedY,
    required this.alphaPhase,
    required this.sizePhase,
  });

  final double baseX;
  final double baseY;
  final double speedX;
  final double speedY;
  final double alphaPhase;
  final double sizePhase;
}

const double _kGridSpacing = 40;

final List<_BgParticleSeed> _kBgParticleSeeds = List<_BgParticleSeed>.generate(
  28,
  (int index) => _BgParticleSeed(
    baseX: index * 133.3,
    baseY: index * 244.4,
    speedX: math.sin(index * 123.45),
    speedY: -0.5 - math.cos(index * 321.12).abs(),
    alphaPhase: index * 99.0,
    sizePhase: index.toDouble(),
  ),
  growable: false,
);

final Map<String, _GridGeometryCache> _gridGeometryCache =
    <String, _GridGeometryCache>{};
final Map<String, _LaneGeometryCache> _laneGeometryCache =
    <String, _LaneGeometryCache>{};
final Map<String, _PerspectiveGridCache> _perspectiveGridCache =
    <String, _PerspectiveGridCache>{};

String _sizeCacheKey(Size size, [Object? extra]) =>
    '${size.width.toStringAsFixed(2)}:${size.height.toStringAsFixed(2)}:${extra ?? ''}';

_GridGeometryCache _resolveGridGeometry(Size size) {
  return _gridGeometryCache.putIfAbsent(_sizeCacheKey(size, _kGridSpacing), () {
    final List<double> vertical = <double>[];
    for (double x = 0; x < size.width; x += _kGridSpacing) {
      vertical.add(x);
    }
    final List<double> horizontal = <double>[];
    for (double y = 0; y < size.height; y += _kGridSpacing) {
      horizontal.add(y);
    }
    return _GridGeometryCache(vertical: vertical, horizontal: horizontal);
  });
}

_LaneGeometryCache _resolveLaneGeometry(Size size, int laneCount) {
  return _laneGeometryCache.putIfAbsent(_sizeCacheKey(size, laneCount), () {
    final double laneWidth = size.width / laneCount;
    return _LaneGeometryCache(
      List<double>.generate(
        laneCount - 1,
        (int index) => laneWidth * (index + 1),
        growable: false,
      ),
    );
  });
}

_PerspectiveGridCache _resolvePerspectiveGrid(Size size) {
  return _perspectiveGridCache.putIfAbsent(_sizeCacheKey(size), () {
    final List<double> diagonalStarts = <double>[];
    final double diagonalStep = size.width / 6;
    for (double x = -size.width; x < size.width * 2; x += diagonalStep) {
      diagonalStarts.add(x);
    }

    final List<double> horizontalY = <double>[];
    for (double y = 0; y < size.height; y += _kGridSpacing) {
      final double progress = y / size.height;
      horizontalY.add(size.height * math.pow(progress, 1.5));
    }
    return _PerspectiveGridCache(
      diagonalStarts: diagonalStarts,
      horizontalY: horizontalY,
    );
  });
}

class GridPainter extends CustomPainter {
  final double opacity;
  static final Paint _paint = Paint()..strokeWidth = 1;

  GridPainter({this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _resolveGridGeometry(size);
    _paint.color = Colors.white.withValues(alpha: opacity * 0.2);

    for (final double x in geometry.vertical) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _paint);
    }
    for (final double y in geometry.horizontal) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class LanePainter extends CustomPainter {
  final int laneCount;
  static final Paint _dividerPaint = Paint()..strokeWidth = 1.2;
  static final Paint _glowPaint = Paint()..strokeWidth = 7;
  static final Paint _coreGlowPaint = Paint()..strokeWidth = 2.6;
  static final Paint _laneShadePaint = Paint();
  static final Paint _laneAccentPaint = Paint();

  LanePainter({required this.laneCount});

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _resolveLaneGeometry(size, laneCount);
    final double laneWidth = size.width / laneCount;

    for (int lane = 0; lane < laneCount; lane++) {
      final left = lane * laneWidth;
      final laneRect = Rect.fromLTWH(left, 0, laneWidth, size.height);
      final accentOpacity = lane.isEven ? 0.028 : 0.018;
      _laneShadePaint.shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: accentOpacity),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.42, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(laneRect);
      canvas.drawRect(laneRect, _laneShadePaint);
      _laneShadePaint.shader = null;

      if (lane < laneCount - 1) {
        final accentRect =
            Rect.fromLTWH(left + laneWidth - 6, 0, 12, size.height);
        _laneAccentPaint.shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF00E5FF).withValues(alpha: 0.035),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(accentRect);
        canvas.drawRect(accentRect, _laneAccentPaint);
        _laneAccentPaint.shader = null;
      }
    }

    _dividerPaint.color = Colors.white.withValues(alpha: 0.11);
    _glowPaint.color = const Color(0xFF00E5FF).withValues(alpha: 0.10);
    _coreGlowPaint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.12);

    for (final double x in geometry.positions) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _glowPaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _coreGlowPaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LanePainter oldDelegate) {
    return oldDelegate.laneCount != laneCount;
  }
}

class UnityBackgroundPainter extends CustomPainter {
  final double time;
  final double pulse;
  final bool isHighGraphics;
  final bool isLowGraphics;

  UnityBackgroundPainter({
    required this.time,
    required this.pulse,
    required this.isHighGraphics,
    required this.isLowGraphics,
  });

  static final Paint _backgroundPaint = Paint();
  static final Paint _gridPaint = Paint()..strokeWidth = 1.0;
  static final Paint _particlePaint = Paint();
  static final Paint _orbPaint = Paint();
  static final Paint _depthPaint = Paint();
  static final Paint _horizonPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: [
        Color.lerp(const Color(0xFF0F0C29), const Color(0xFF1E0B30), pulse)!,
        Color.lerp(const Color(0xFF241540), const Color(0xFF501430), pulse)!,
        Color.lerp(const Color(0xFF1B1B40), const Color(0xFF380840), pulse)!,
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    _backgroundPaint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, _backgroundPaint);
    _backgroundPaint.shader = null;

    final double topBandHeight = size.height * (isLowGraphics ? 0.34 : 0.42);
    final Rect topBandRect = Rect.fromLTWH(0, 0, size.width, topBandHeight);
    _horizonPaint.shader = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: isHighGraphics ? 0.07 : 0.045),
        const Color(0xFF00E5FF).withValues(alpha: isLowGraphics ? 0.03 : 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(topBandRect);
    canvas.drawRect(topBandRect, _horizonPaint);
    _horizonPaint.shader = null;

    final Rect centerDepthRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.44),
      width: size.width * (isLowGraphics ? 0.84 : 0.92),
      height: size.height * (isLowGraphics ? 0.52 : 0.62),
    );
    _depthPaint.shader = RadialGradient(
      colors: [
        const Color(0xFF9C6BFF).withValues(alpha: isHighGraphics ? 0.10 : 0.06),
        const Color(0xFF00E5FF).withValues(alpha: isLowGraphics ? 0.025 : 0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.52, 1.0],
    ).createShader(centerDepthRect);
    canvas.drawOval(centerDepthRect, _depthPaint);
    _depthPaint.shader = null;

    final Rect vignetteRect = Rect.fromLTWH(0, 0, size.width, size.height);
    _depthPaint.shader = RadialGradient(
      center: const Alignment(0, -0.08),
      radius: 0.96,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: isLowGraphics ? 0.10 : 0.16),
      ],
      stops: const [0.62, 1.0],
    ).createShader(vignetteRect);
    canvas.drawRect(vignetteRect, _depthPaint);
    _depthPaint.shader = null;

    final double twoPiTime = time * math.pi * 2;
    final double sinTwoPiTime = math.sin(twoPiTime);
    final double cosTwoPiTime = math.cos(twoPiTime);
    final double sinPiTime = math.sin(time * math.pi);

    final double orbGlow = isHighGraphics ? 1.0 : (isLowGraphics ? 0.4 : 0.7);
    if (!isLowGraphics) {
      _drawOrb(
        canvas,
        Offset(
          size.width * 0.1 + (size.width * 0.1 * sinTwoPiTime),
          size.height * 0.1,
        ),
        size.width * 0.8,
        const Color(0xFFFF0055),
        pulse,
        orbGlow,
      );
      _drawOrb(
        canvas,
        Offset(
          size.width * 0.9 + (size.width * 0.05 * cosTwoPiTime),
          size.height * 0.8,
        ),
        size.width * 0.9,
        const Color(0xFF00E5FF),
        pulse,
        orbGlow,
      );
      if (isHighGraphics) {
        _drawOrb(
          canvas,
          Offset(
            size.width * 0.8,
            size.height * 0.3 + (size.height * 0.1 * sinPiTime),
          ),
          size.width * 0.6,
          const Color(0xFFE040FB),
          pulse,
          orbGlow * 0.8,
        );
      }
    }

    final gridOpacity = isHighGraphics
        ? 0.16 + (pulse * 0.15)
        : isLowGraphics
            ? 0.07 + (pulse * 0.08)
            : 0.11 + (pulse * 0.12);

    _gridPaint.color = Colors.white.withValues(alpha: gridOpacity);

    final double gridOffset = (time * math.pi * 200) % _kGridSpacing;
    final perspectiveGrid = _resolvePerspectiveGrid(size);

    final double centerX = size.width * 0.5;
    for (final double startX in perspectiveGrid.diagonalStarts) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(centerX + (startX - centerX) * 1.5, size.height),
        _gridPaint,
      );
    }

    for (final double baseY in perspectiveGrid.horizontalY) {
      double scaledY = baseY + gridOffset;
      if (scaledY > size.height) {
        scaledY -= size.height;
      }
      canvas.drawLine(
        Offset(-50, scaledY),
        Offset(size.width + 50, scaledY),
        _gridPaint,
      );
    }

    if (!isLowGraphics) {
      final int particleCount = isHighGraphics ? 28 : 14;
      for (int i = 0; i < particleCount; i++) {
        final seed = _kBgParticleSeeds[i];

        double px = (seed.baseX + time * seed.speedX * 100) % size.width;
        double py = (seed.baseY + time * seed.speedY * 600) % size.height;
        if (px < 0) px += size.width;
        if (py < 0) py += size.height;

        final double pSize = 1.0 +
            (math.sin(seed.sizePhase + time * math.pi * 4) * 0.5 + 0.5) * 2.0;
        final double pAlpha =
            (math.sin(seed.alphaPhase + time * math.pi * 2) * 0.5 + 0.5) * 0.6;

        _particlePaint.color = (i % 3 == 0)
            ? const Color(0xFF00E5FF).withValues(alpha: pAlpha)
            : (i % 3 == 1)
                ? const Color(0xFFFF0055).withValues(alpha: pAlpha)
                : Colors.white.withValues(alpha: pAlpha);

        canvas.drawCircle(Offset(px, py), pSize, _particlePaint);
      }
    }
  }

  void _drawOrb(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double pulse,
    double glowLevel,
  ) {
    if (glowLevel <= 0) return;
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    _orbPaint.shader = RadialGradient(
      colors: [
        color.withValues(alpha: (0.35 + (pulse * 0.25)) * glowLevel),
        Colors.transparent,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, _orbPaint);
    _orbPaint.shader = null;
  }

  @override
  bool shouldRepaint(covariant UnityBackgroundPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isHighGraphics != isHighGraphics ||
        oldDelegate.isLowGraphics != isLowGraphics;
  }
}
