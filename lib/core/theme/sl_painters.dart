import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../sl_theme.dart';

enum SLCanvasBackdropMotif {
  sparkles,
  notes,
  safety,
}

class SLSoftCanvasBackdropPainter extends CustomPainter {
  const SLSoftCanvasBackdropPainter({
    required this.baseColor,
    required this.accentColor,
    required this.secondaryAccent,
    required this.motif,
  });

  final Color baseColor;
  final Color accentColor;
  final Color secondaryAccent;
  final SLCanvasBackdropMotif motif;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = baseColor);

    void radial(Alignment center, double radius, Color color) {
      final Paint paint = Paint()
        ..shader = RadialGradient(
          center: center,
          radius: radius,
          colors: <Color>[color, Colors.transparent],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    radial(const Alignment(-0.95, -0.82), 0.72,
        accentColor.withValues(alpha: 0.18));
    radial(const Alignment(0.88, -0.36), 0.68,
        secondaryAccent.withValues(alpha: 0.14));
    radial(const Alignment(0.16, 1.08), 0.82,
        Colors.white.withValues(alpha: 0.42));

    final Paint linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final Paint dotPaint = Paint()
      ..color = secondaryAccent.withValues(alpha: 0.13);

    switch (motif) {
      case SLCanvasBackdropMotif.notes:
        for (double y = 96; y < size.height; y += 42) {
          canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
        }
        for (int i = 0; i < 5; i++) {
          final double x = 32 + (i * 78) % math.max(96, size.width - 24);
          final double y = 58 + (i * 113) % math.max(140, size.height - 32);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 42, 30),
              const Radius.circular(8),
            ),
            Paint()..color = accentColor.withValues(alpha: 0.055),
          );
        }
        break;
      case SLCanvasBackdropMotif.safety:
        for (int i = 0; i < 7; i++) {
          final double y = 48 + (i * 86.0);
          canvas.drawLine(
            Offset(-28, y),
            Offset(size.width * 0.42, y - 86),
            linePaint,
          );
        }
        final Path shield = Path()
          ..moveTo(size.width - 96, 78)
          ..quadraticBezierTo(size.width - 54, 96, size.width - 60, 144)
          ..quadraticBezierTo(size.width - 66, 184, size.width - 96, 210)
          ..quadraticBezierTo(size.width - 126, 184, size.width - 132, 144)
          ..quadraticBezierTo(size.width - 138, 96, size.width - 96, 78);
        canvas.drawPath(
            shield, Paint()..color = accentColor.withValues(alpha: 0.06));
        break;
      case SLCanvasBackdropMotif.sparkles:
        for (int i = 0; i < 16; i++) {
          final double x = 24 + (i * 53) % math.max(80, size.width - 24);
          final double y = 36 + (i * 91) % math.max(120, size.height - 24);
          canvas.drawCircle(Offset(x, y), i.isEven ? 2.6 : 1.7, dotPaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant SLSoftCanvasBackdropPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.secondaryAccent != secondaryAccent ||
        oldDelegate.motif != motif;
  }
}

/// Background painter (replicates web CSS radial gradients)
class SLBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -1.2),
        radius: 0.65,
        colors: [
          SLColors.primary.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, -0.6),
        radius: 0.7,
        colors: [
          const Color(0xFFF1D1C5).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);

    final paint3 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.6),
        radius: 0.7,
        colors: [
          SLColors.secondary.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SLCuteMeshPatternPainter extends CustomPainter {
  const SLCuteMeshPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    // 1. Váº½ lÆ°á»›i cháº¥m trÃ²n nhá» siÃªu nháº¹ phong cÃ¡ch pastel kute
    final Paint dotPaint = Paint()
      ..color = const Color(0xFFFFB7D1).withValues(alpha: 0.12);
    const double spacing = 32.0;
    for (double x = spacing / 2; x < w; x += spacing) {
      for (double y = spacing / 2; y < h; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }

    // 2. Váº½ cÃ¡c icon dá»… thÆ°Æ¡ng ráº£i rÃ¡c cá»‘ Ä‘á»‹nh vá»‹ trÃ­ (deterministic pseudo-random)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final List<Map<String, dynamic>> icons = [
      {'text': 'âœ¨', 'color': const Color(0xFFFFD54F)},
      {'text': 'â­', 'color': const Color(0xFFFFE082)},
      {'text': 'ðŸ’–', 'color': const Color(0xFFFFB3CC)},
    ];

    int seed = 42;
    int nextRand() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    // Khoáº£ng 35 há»a tiáº¿t xinh xáº¯n ná»•i báº­t
    final int count = ((w * h) / 14000).clamp(15, 60).toInt();
    for (int i = 0; i < count; i++) {
      final double x = (nextRand() % w.toInt()).toDouble();
      final double y = (nextRand() % h.toInt()).toDouble();
      final double sizeVal = (nextRand() % 8) + 12.0; // font size 12-20
      final icon = icons[nextRand() % icons.length];

      textPainter.text = TextSpan(
        text: icon['text'] as String,
        style: TextStyle(
          fontSize: sizeVal,
          color: (icon['color'] as Color).withValues(alpha: 0.16),
          fontFamily: 'Segoe UI Emoji',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant SLCuteMeshPatternPainter oldDelegate) => false;
}


