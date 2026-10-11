part of '../../drawing_studio_screen.dart';

class _StickerPainter extends CustomPainter {
  final List<_DrawStroke> strokes;
  final ui.Image? atlas;

  const _StickerPainter({required this.strokes, this.atlas});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.isEraser) {
        _paintStudioStroke(canvas, stroke, size);
      } else if (stroke.stickerIndex != null) {
        _paintStudioStamp(canvas, stroke, size, atlas);
      } else {
        _paintStudioStroke(
          canvas,
          stroke,
          size,
          width: stroke.width + 18,
          color: Colors.black.withValues(alpha: 0.16),
        );
        _paintStudioStroke(
          canvas,
          stroke,
          size,
          width: stroke.width + 12,
          color: Colors.white,
        );
        _paintStudioStroke(canvas, stroke, size);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StickerPainter oldDelegate) => true;
}

Offset _studioPixelPoint(Offset point, Size size) =>
    Offset(point.dx * size.width, point.dy * size.height);

void _paintStudioStamp(
  Canvas canvas,
  _DrawStroke stroke,
  Size size,
  ui.Image? atlas,
) {
  if (atlas == null || stroke.points.isEmpty || stroke.stickerIndex == null) {
    return;
  }
  _drawStudioSprite(
    canvas,
    atlas,
    stroke.stickerIndex!,
    Rect.fromCenter(
      center: _studioPixelPoint(stroke.points.first, size),
      width: stroke.width,
      height: stroke.width,
    ),
  );
}

void _paintStudioStroke(
  Canvas canvas,
  _DrawStroke stroke,
  Size size, {
  double? width,
  Color? color,
}) {
  if (stroke.points.isEmpty) return;
  final points = stroke.points.map((p) => _studioPixelPoint(p, size)).toList();
  final brushWidth = width ?? stroke.width;
  final paint = Paint()
    ..color = color ?? stroke.color
    ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
    ..strokeWidth = brushWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  if (points.length == 1) {
    canvas.drawCircle(points.first, brushWidth / 2, paint);
    return;
  }
  paint.style = PaintingStyle.stroke;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final point = points[i];
    final next = points[i + 1];
    final middle = (point + next) / 2;
    path.quadraticBezierTo(point.dx, point.dy, middle.dx, middle.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  canvas.drawPath(path, paint);
}

class _DrawingBackgroundPreviewPainter extends CustomPainter {
  final String backgroundId;

  const _DrawingBackgroundPreviewPainter(this.backgroundId);

  @override
  void paint(Canvas canvas, Size size) {
    _DrawingCanvasPainter(
      backgroundId: backgroundId,
      strokes: const <_DrawStroke>[],
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _DrawingBackgroundPreviewPainter oldDelegate) {
    return oldDelegate.backgroundId != backgroundId;
  }
}

class _DrawingCanvasPainter extends CustomPainter {
  final String backgroundId;
  final List<_DrawStroke> strokes;
  final ui.Image? atlas;

  const _DrawingCanvasPainter({
    required this.backgroundId,
    required this.strokes,
    this.atlas,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    // Tẩy chỉ xóa lớp nét vẽ và sticker, giữ nguyên giấy nền bên dưới.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.stickerIndex != null) {
        _paintStudioStamp(canvas, stroke, size, atlas);
      } else {
        _paintStudioStroke(canvas, stroke, size);
      }
    }
    canvas.restore();
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (backgroundId) {
      case 'blank_paper':
        _paintGradient(canvas, rect, const [
          Color(0xFFFFFEFD),
          Color(0xFFFFFCF9),
        ]);
        const _StudioGrainPainter(paper: true).paint(canvas, size);
        break;
      case 'hearts':
        _paintGradient(canvas, rect, const [
          Color(0xFFFFECF5),
          Color(0xFFFF9BC3),
          Color(0xFFFFD6E7),
        ]);
        _paintBokeh(
          canvas,
          size,
          const Color(0xFFFFFFFF).withValues(alpha: 0.34),
        );
        _paintHearts(canvas, size);
        _paintSparkles(
          canvas,
          size,
          const Color(0xFFFFFFFF).withValues(alpha: 0.72),
        );
        break;
      case 'night_stars':
        _paintGradient(
          canvas,
          rect,
          const [Color(0xFF130A2A), Color(0xFF34216B), Color(0xFF8C5FD5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        _paintMoon(canvas, size);
        _paintNebula(canvas, size);
        _paintStars(canvas, size);
        break;
      case 'blackboard':
        _paintGradient(canvas, rect, const [
          Color(0xFF102E29),
          Color(0xFF225C51),
        ]);
        _paintGrid(
          canvas,
          size,
          Colors.white.withValues(alpha: 0.08),
          step: 34,
        );
        _paintChalkDust(canvas, size);
        break;
      case 'notebook':
        _paintGradient(canvas, rect, const [
          Color(0xFFFFFEFB),
          Color(0xFFF5FAFF),
        ]);
        _paintNotebook(canvas, size);
        _paintPaperNoise(
          canvas,
          size,
          const Color(0xFFCADBFF).withValues(alpha: 0.18),
        );
        break;
      case 'photo_frame':
        _paintGradient(canvas, rect, const [
          Color(0xFFFFEEF7),
          Color(0xFFEDE7FF),
          Color(0xFFFFFBFE),
        ]);
        _paintBokeh(
          canvas,
          size,
          const Color(0xFFFFFFFF).withValues(alpha: 0.30),
        );
        _paintFrame(canvas, size);
        break;
      case 'pastel_dots':
        _paintGradient(canvas, rect, const [
          Color(0xFFFFF5FB),
          Color(0xFFEAF8FF),
          Color(0xFFFFF6D8),
        ]);
        _paintPastelDots(canvas, size);
        break;
      case 'sticker_sheet':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
        _paintCheckerboard(canvas, size);
        _paintStickerGuide(canvas, size);
        break;
      case 'paper_grid':
      default:
        _paintGradient(canvas, rect, const [
          Color(0xFFFFFEFC),
          Color(0xFFFFEAF3),
        ]);
        _paintGrid(
          canvas,
          size,
          const Color(0xFFFFBFD7).withValues(alpha: 0.70),
          step: 24,
        );
        _paintGrid(
          canvas,
          size,
          const Color(0xFFFF82B0).withValues(alpha: 0.28),
          step: 96,
        );
        _paintPaperNoise(
          canvas,
          size,
          const Color(0xFFFFC7DB).withValues(alpha: 0.25),
        );
        break;
    }
  }

  void _paintGradient(
    Canvas canvas,
    Rect rect,
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: colors,
          begin: begin,
          end: end,
        ).createShader(rect),
    );
  }

  void _paintGrid(Canvas canvas, Size size, Color color, {double step = 28}) {
    final gridPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _paintBokeh(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 18; i++) {
      final x = ((i * 67 + 24) % math.max(size.width.toInt(), 1)).toDouble();
      final y = ((i * 91 + 38) % math.max(size.height.toInt(), 1)).toDouble();
      canvas.drawCircle(Offset(x, y), 12 + (i % 5) * 8, paint);
    }
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.16);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.09,
      Paint()..color = const Color(0xFFFFF2B8),
    );
    canvas.drawCircle(
      center.translate(size.shortestSide * 0.035, -size.shortestSide * 0.025),
      size.shortestSide * 0.085,
      Paint()..color = const Color(0xFF34216B),
    );
  }

  void _paintNebula(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFF7AB8).withValues(alpha: 0.20),
      const Color(0xFF7EE8FF).withValues(alpha: 0.16),
      const Color(0xFFFFD166).withValues(alpha: 0.12),
    ];
    for (var i = 0; i < colors.length; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            size.width * (0.25 + i * 0.18),
            size.height * (0.26 + i * 0.18),
          ),
          width: size.width * 0.56,
          height: size.height * 0.18,
        ),
        Paint()..color = colors[i],
      );
    }
  }

  void _paintSparkles(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final center = Offset(
        ((i * 53 + 17) % math.max(size.width.toInt(), 1)).toDouble(),
        ((i * 79 + 31) % math.max(size.height.toInt(), 1)).toDouble(),
      );
      final r = 3.0 + (i % 3) * 1.5;
      canvas.drawLine(center.translate(-r, 0), center.translate(r, 0), paint);
      canvas.drawLine(center.translate(0, -r), center.translate(0, r), paint);
    }
  }

  void _paintChalkDust(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 120; i++) {
      final x = ((i * 37) % math.max(size.width.toInt(), 1)).toDouble();
      final y = ((i * 61) % math.max(size.height.toInt(), 1)).toDouble();
      canvas.drawCircle(Offset(x, y), 0.8 + (i % 4) * 0.35, paint);
    }
  }

  void _paintPastelDots(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFF7AB8).withValues(alpha: 0.26),
      const Color(0xFF69D2E7).withValues(alpha: 0.25),
      const Color(0xFFFFD166).withValues(alpha: 0.28),
      const Color(0xFFA78BFA).withValues(alpha: 0.22),
    ];
    for (double y = 18; y < size.height; y += 42) {
      for (double x = 18; x < size.width; x += 42) {
        final index = ((x + y) ~/ 42) % colors.length;
        canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = colors[index]);
      }
    }
  }

  void _paintCheckerboard(Canvas canvas, Size size) {
    const cell = 22.0;
    final paints = [
      Paint()..color = const Color(0xFFF4F4F5),
      Paint()..color = const Color(0xFFE5E7EB),
    ];
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final index = ((x / cell).floor() + (y / cell).floor()) % 2;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paints[index]);
      }
    }
  }

  void _paintStickerGuide(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFF7AAE).withValues(alpha: 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, 24, size.width - 48, size.height - 48),
        const Radius.circular(28),
      ),
      paint,
    );
  }

  void _paintNotebook(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFBFD7FF).withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (double y = 34; y <= size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    canvas.drawLine(
      const Offset(46, 0),
      Offset(46, size.height),
      Paint()
        ..color = const Color(0xFFFF9DBB).withValues(alpha: 0.55)
        ..strokeWidth = 2,
    );
  }

  void _paintPaperNoise(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 56; i++) {
      final x = ((i * 47) % math.max(size.width.toInt(), 1)).toDouble();
      final y = ((i * 83) % math.max(size.height.toInt(), 1)).toDouble();
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.5, paint);
    }
  }

  void _paintHearts(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 18; i++) {
      textPainter.text = TextSpan(
        text: '♡',
        style: TextStyle(
          color: const Color(0xFFFF80AA).withValues(alpha: 0.18),
          fontSize: 20.0 + (i % 4) * 7,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          ((i * 73) % math.max(size.width.toInt(), 1)).toDouble(),
          ((i * 97) % math.max(size.height.toInt(), 1)).toDouble(),
        ),
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.76);
    for (var i = 0; i < 70; i++) {
      final x = ((i * 59) % math.max(size.width.toInt(), 1)).toDouble();
      final y = ((i * 41) % math.max(size.height.toInt(), 1)).toDouble();
      canvas.drawCircle(Offset(x, y), 0.8 + (i % 3) * 0.45, paint);
    }
  }

  void _paintFrame(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.88);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 20, size.width - 40, size.height - 40),
        const Radius.circular(22),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DrawingCanvasPainter oldDelegate) => true;
}
