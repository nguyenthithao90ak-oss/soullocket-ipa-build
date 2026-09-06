import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight floating doodles for the redesigned auth screen.
/// Kept under the old class name so no auth-flow code needs to change.
class AuroraDecorativeOrbs extends StatefulWidget {
  const AuroraDecorativeOrbs({super.key});

  @override
  State<AuroraDecorativeOrbs> createState() => _AuroraDecorativeOrbsState();
}

class _AuroraDecorativeOrbsState extends State<AuroraDecorativeOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return const IgnorePointer(child: _DoodleLayer(progress: 0.35));
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _DoodleLayer(progress: _controller.value),
      ),
    );
  }
}

class _DoodleLayer extends StatelessWidget {
  final double progress;

  const _DoodleLayer({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOut.transform(progress);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: width < 520 ? -20 : width * 0.05,
              top: height * 0.12 + (t - 0.5) * 14,
              child: Transform.rotate(
                angle: -0.10 + (t - 0.5) * 0.05,
                child: const _PaperSticker(
                  size: 74,
                  type: _StickerType.heart,
                  fill: Color(0xFFFFDCE6),
                  stroke: Color(0xFFF195AD),
                ),
              ),
            ),
            Positioned(
              right: width < 520 ? -18 : width * 0.06,
              top: height * 0.20 - (t - 0.5) * 18,
              child: Transform.rotate(
                angle: 0.12 - (t - 0.5) * 0.05,
                child: const _PaperSticker(
                  size: 64,
                  type: _StickerType.star,
                  fill: Color(0xFFFFECC8),
                  stroke: Color(0xFFD59B48),
                ),
              ),
            ),
            Positioned(
              left: width * 0.05,
              bottom: height * 0.13 + math.sin(t * math.pi) * 6,
              child: const _PaperSticker(
                size: 54,
                type: _StickerType.flower,
                fill: Color(0xFFE7DFFF),
                stroke: Color(0xFF8F7AD6),
              ),
            ),
            Positioned(
              right: width * 0.08,
              bottom: height * 0.08 - math.sin(t * math.pi) * 5,
              child: const _PaperSticker(
                size: 48,
                type: _StickerType.spark,
                fill: Color(0xFFDDF5F2),
                stroke: Color(0xFF53A79B),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _StickerType { heart, star, flower, spark }

class _PaperSticker extends StatelessWidget {
  final double size;
  final _StickerType type;
  final Color fill;
  final Color stroke;

  const _PaperSticker({
    required this.size,
    required this.type,
    required this.fill,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PaperStickerPainter(type: type, fill: fill, stroke: stroke),
        size: Size.square(size),
      ),
    );
  }
}

class _PaperStickerPainter extends CustomPainter {
  final _StickerType type;
  final Color fill;
  final Color stroke;

  const _PaperStickerPainter({
    required this.type,
    required this.fill,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.33;

    final halo = Paint()..color = Colors.white.withValues(alpha: 0.62);
    canvas.drawCircle(center, size.shortestSide * 0.47, halo);

    final fillPaint = Paint()
      ..color = fill.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = stroke.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case _StickerType.heart:
        final path = Path()
          ..moveTo(center.dx, center.dy + radius * 0.72)
          ..cubicTo(
            center.dx - radius * 1.35,
            center.dy - radius * 0.10,
            center.dx - radius * 0.76,
            center.dy - radius * 1.18,
            center.dx,
            center.dy - radius * 0.42,
          )
          ..cubicTo(
            center.dx + radius * 0.76,
            center.dy - radius * 1.18,
            center.dx + radius * 1.35,
            center.dy - radius * 0.10,
            center.dx,
            center.dy + radius * 0.72,
          );
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, outline);
        break;
      case _StickerType.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final r = i.isEven ? radius : radius * 0.45;
          final point = Offset(
            center.dx + math.cos(angle) * r,
            center.dy + math.sin(angle) * r,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, outline);
        break;
      case _StickerType.flower:
        for (var i = 0; i < 5; i++) {
          final angle = -math.pi / 2 + i * math.pi * 2 / 5;
          final petal = Offset(
            center.dx + math.cos(angle) * radius * 0.70,
            center.dy + math.sin(angle) * radius * 0.70,
          );
          canvas.drawCircle(petal, radius * 0.42, fillPaint);
          canvas.drawCircle(petal, radius * 0.42, outline);
        }
        canvas.drawCircle(
          center,
          radius * 0.34,
          Paint()..color = const Color(0xFFFFD77A),
        );
        break;
      case _StickerType.spark:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..quadraticBezierTo(
            center.dx + radius * 0.16,
            center.dy - radius * 0.16,
            center.dx + radius,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx + radius * 0.16,
            center.dy + radius * 0.16,
            center.dx,
            center.dy + radius,
          )
          ..quadraticBezierTo(
            center.dx - radius * 0.16,
            center.dy + radius * 0.16,
            center.dx - radius,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx - radius * 0.16,
            center.dy - radius * 0.16,
            center.dx,
            center.dy - radius,
          )
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, outline);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperStickerPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke;
  }
}
