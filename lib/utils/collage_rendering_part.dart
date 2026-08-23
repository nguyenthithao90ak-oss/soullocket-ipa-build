part of 'collage_generator.dart';

final Map<String, ui.Image> _loadedStickerImages = <String, ui.Image>{};

double _drawText(
  Canvas canvas,
  String text,
  double x,
  double y,
  Color color,
  double fontSize, {
  bool isBold = true,
  double maxWidth = 10000,
  double? centerWidth,
  TextAlign textAlign = TextAlign.center,
  FontStyle fontStyle = FontStyle.normal,
  double letterSpacing = 0,
}) {
  final paragraphStyle = ui.ParagraphStyle(
    textAlign: textAlign,
    fontSize: fontSize,
    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    fontStyle: fontStyle,
  );
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(
      ui.TextStyle(
        color: color,
        letterSpacing: letterSpacing,
      ),
    )
    ..addText(text);
  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: maxWidth));
  final dx = textAlign == TextAlign.center
      ? x - (centerWidth ?? paragraph.longestLine) / 2
      : x;
  canvas.drawParagraph(paragraph, Offset(dx, y));
  return paragraph.height;
}

void _drawCenteredTextInRect(
  Canvas canvas,
  String text,
  Rect rect,
  Color color,
  double fontSize, {
  bool isBold = true,
  FontStyle fontStyle = FontStyle.normal,
  double letterSpacing = 0,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final contentRect = Rect.fromLTRB(
    rect.left + padding.left,
    rect.top + padding.top,
    rect.right - padding.right,
    rect.bottom - padding.bottom,
  );
  final paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.center,
    fontSize: fontSize,
    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    fontStyle: fontStyle,
    maxLines: 1,
    ellipsis: '…',
  );
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(
      ui.TextStyle(
        color: color,
        letterSpacing: letterSpacing,
      ),
    )
    ..addText(text);
  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: contentRect.width));
  canvas.drawParagraph(
    paragraph,
    Offset(
      contentRect.left,
      contentRect.top + (contentRect.height - paragraph.height) / 2,
    ),
  );
}

void _drawBackground(
  Canvas canvas,
  double width,
  double height,
  CollageDecor decor,
  CollageRenderOptions options,
) {
  final rect = Rect.fromLTWH(0, 0, width, height);
  if (options.backgroundTheme != 'default') {
    _drawCuteBackgroundTheme(canvas, width, height, decor, options);
    return;
  }

  final paint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(width, height),
      [decor.backgroundTop, decor.backgroundBottom],
    );
  canvas.drawRect(rect, paint);

  canvas.drawCircle(
    Offset(width * 0.12, height * 0.14),
    min(width, height) * 0.15,
    Paint()..color = decor.secondary.withValues(alpha: 0.18),
  );
  canvas.drawCircle(
    Offset(width * 0.88, height * 0.18),
    min(width, height) * 0.18,
    Paint()..color = decor.primary.withValues(alpha: 0.10),
  );
  canvas.drawCircle(
    Offset(width * 0.76, height * 0.86),
    min(width, height) * 0.12,
    Paint()..color = const Color(0xFFC7D4C8).withValues(alpha: 0.18),
  );
  canvas.drawCircle(
    Offset(width * 0.52, height * 0.10),
    min(width, height) * 0.10,
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );
  canvas.drawCircle(
    Offset(width * 0.48, height * 0.68),
    min(width, height) * 0.16,
    Paint()..color = decor.primary.withValues(alpha: 0.05),
  );
  _drawRobotCatMascot(
    canvas,
    Offset(width * 0.12, height * 0.23),
    min(width, height) * 0.16,
    opacity: 0.16,
    rotation: -0.18,
  );
  _drawBoyMascot(
    canvas,
    Offset(width * 0.88, height * 0.23),
    min(width, height) * 0.15,
    opacity: 0.16,
    rotation: 0.14,
  );

  final random = _layoutRandom(options, 0x0242);
  final int charmCount = (width * height / 180000).ceil().clamp(12, 34);
  for (int i = 0; i < charmCount; i++) {
    final double x = random.nextDouble() * width;
    final double y = random.nextDouble() * height;
    final double size = 10 + random.nextDouble() * 18;
    final color = i.isEven ? decor.primary : const Color(0xFFC7D4C8);
    if (i % 5 == 0) {
      _drawRobotCatMascot(
        canvas,
        Offset(x, y),
        size * 1.45,
        opacity: 0.13,
        rotation: (random.nextDouble() - 0.5) * 0.5,
      );
    } else if (i % 5 == 1) {
      _drawBoyMascot(
        canvas,
        Offset(x, y),
        size * 1.35,
        opacity: 0.12,
        rotation: (random.nextDouble() - 0.5) * 0.5,
      );
    } else if (i % 3 == 0) {
      _drawHeart(canvas, Offset(x, y), size, color.withValues(alpha: 0.18));
    } else {
      _drawSparkle(canvas, Offset(x, y), size, color.withValues(alpha: 0.20));
    }
  }
}

void _drawCuteBackgroundTheme(
  Canvas canvas,
  double width,
  double height,
  CollageDecor decor,
  CollageRenderOptions options,
) {
  switch (options.backgroundTheme) {
    case 'cloud_pink':
      _drawPastelWash(
        canvas,
        width,
        height,
        const Color(0xFFFFD6E3),
        const Color(0xFFFFF5D9),
      );
      _drawSkyCloudTheme(
        canvas,
        width,
        height,
        decor,
        options,
        cloudTint: const Color(0xFFFFAFC7),
        sparkleTint: const Color(0xFFFF7DA7),
      );
      break;
    case 'bogo_blue':
      _drawPastelWash(
        canvas,
        width,
        height,
        const Color(0xFFDDF4FF),
        const Color(0xFFE6FFF6),
      );
      _drawBubbleCloudTheme(
        canvas,
        width,
        height,
        decor,
        options,
        bubbleBias: 0.82,
        heartBias: 0.05,
        bubbleTint: const Color(0xFF6DB7E5),
        accentTint: const Color(0xFF74D6C4),
      );
      break;
    case 'cotton_candy':
      _drawPastelWash(
        canvas,
        width,
        height,
        const Color(0xFFF3D8FF),
        const Color(0xFFFFE1F0),
      );
      _drawPaperCloudTheme(
        canvas,
        width,
        height,
        decor,
        options,
        cloudTint: const Color(0xFFE6B6FF),
        bandTint: const Color(0xFFFFB9D5),
      );
      break;
    case 'heart':
      _drawBubbleCloudTheme(canvas, width, height, decor, options,
          bubbleBias: 0.6, heartBias: 0.35);
      break;
    case 'scatter':
      _drawBubbleCloudTheme(canvas, width, height, decor, options,
          bubbleBias: 0.75, heartBias: 0.12);
      break;
    case 'story':
    case 'poster':
      _drawSkyCloudTheme(canvas, width, height, decor, options,
          denserTopBand: true);
      break;
    case 'polaroid':
      _drawPaperCloudTheme(canvas, width, height, decor, options);
      break;
    case 'masonry':
      _drawBubbleCloudTheme(canvas, width, height, decor, options,
          bubbleBias: 0.4, heartBias: 0.18);
      break;
    case 'grid':
    default:
      _drawSkyCloudTheme(canvas, width, height, decor, options);
      break;
  }
}

void _drawPastelWash(
  Canvas canvas,
  double width,
  double height,
  Color top,
  Color bottom,
) {
  final rect = Rect.fromLTWH(0, 0, width, height);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [top, bottom],
      ),
  );
  canvas.drawCircle(
    Offset(width * 0.18, height * 0.18),
    min(width, height) * 0.20,
    Paint()..color = top.withValues(alpha: 0.20),
  );
  canvas.drawCircle(
    Offset(width * 0.82, height * 0.80),
    min(width, height) * 0.18,
    Paint()..color = bottom.withValues(alpha: 0.18),
  );
  canvas.drawCircle(
    Offset(width * 0.52, height * 0.10),
    min(width, height) * 0.10,
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );
  canvas.drawCircle(
    Offset(width * 0.46, height * 0.70),
    min(width, height) * 0.14,
    Paint()..color = Colors.white.withValues(alpha: 0.08),
  );
}

void _drawSkyCloudTheme(
  Canvas canvas,
  double width,
  double height,
  CollageDecor decor,
  CollageRenderOptions options, {
  bool denserTopBand = false,
  Color? cloudTint,
  Color? sparkleTint,
}) {
  final random = _layoutRandom(options, 0x0C10D);
  final cloudCount = options.isPreviewQuality
      ? (denserTopBand ? 5 : 4)
      : (denserTopBand ? 8 : 6);
  for (int i = 0; i < cloudCount; i++) {
    final x = width * (0.08 + random.nextDouble() * 0.84);
    final y = height *
        (denserTopBand
            ? (0.06 + random.nextDouble() * 0.18)
            : (0.08 + random.nextDouble() * 0.24));
    final size = min(width, height) * (0.055 + random.nextDouble() * 0.05);
    final tint = i.isEven
        ? Colors.white.withValues(alpha: cloudTint == null ? 0.22 : 0.34)
        : (cloudTint ?? decor.secondary)
            .withValues(alpha: cloudTint == null ? 0.14 : 0.24);
    _drawCloudPuff(canvas, Offset(x, y), size, tint);
  }

  final starCount = options.isPreviewQuality ? 10 : 18;
  for (int i = 0; i < starCount; i++) {
    final x = random.nextDouble() * width;
    final y = height * (0.04 + random.nextDouble() * 0.34);
    final size = 4 + random.nextDouble() * 7;
    _drawSparkle(
      canvas,
      Offset(x, y),
      size,
      (sparkleTint ?? Colors.white)
          .withValues(alpha: sparkleTint == null ? 0.16 : 0.22),
    );
  }
}

void _drawBubbleCloudTheme(
  Canvas canvas,
  double width,
  double height,
  CollageDecor decor,
  CollageRenderOptions options, {
  required double bubbleBias,
  required double heartBias,
  Color? bubbleTint,
  Color? accentTint,
}) {
  final random = _layoutRandom(options, 0x0B0BA);
  final bubbleCount = options.isPreviewQuality ? 12 : 20;
  for (int i = 0; i < bubbleCount; i++) {
    final radius = min(width, height) * (0.012 + random.nextDouble() * 0.022);
    final center = Offset(
      width * (0.04 + random.nextDouble() * 0.92),
      height * (0.08 + random.nextDouble() * 0.84),
    );
    final fill = i / bubbleCount < bubbleBias
        ? (bubbleTint ?? decor.secondary).withValues(
            alpha: (bubbleTint == null ? 0.10 : 0.18) +
                random.nextDouble() * 0.10)
        : (accentTint ?? decor.primary).withValues(
            alpha: (accentTint == null ? 0.07 : 0.14) +
                random.nextDouble() * 0.08);
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, radius * 0.08)
        ..color = Colors.white.withValues(alpha: 0.20),
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.28, center.dy - radius * 0.24),
      radius * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  final charmCount = options.isPreviewQuality ? 8 : 14;
  for (int i = 0; i < charmCount; i++) {
    final center = Offset(
      width * (0.07 + random.nextDouble() * 0.86),
      height * (0.10 + random.nextDouble() * 0.80),
    );
    final size = 7 + random.nextDouble() * 10;
    if (i / charmCount < heartBias) {
      _drawHeart(
        canvas,
        center,
        size,
        (accentTint ?? decor.primary)
            .withValues(alpha: accentTint == null ? 0.12 : 0.18),
      );
    } else {
      _drawCloudPuff(
        canvas,
        center,
        size * 1.1,
        (bubbleTint ?? Colors.white)
            .withValues(alpha: bubbleTint == null ? 0.12 : 0.16),
      );
    }
  }
}

void _drawPaperCloudTheme(
  Canvas canvas,
  double width,
  double height,
  CollageDecor decor,
  CollageRenderOptions options, {
  Color? cloudTint,
  Color? bandTint,
}) {
  final random = _layoutRandom(options, 0x0FACE);
  final bandPaint = Paint()
    ..color = (bandTint ?? Colors.white)
        .withValues(alpha: bandTint == null ? 0.08 : 0.16);
  final bandCount = options.isPreviewQuality ? 2 : 3;
  for (int i = 0; i < bandCount; i++) {
    final top = height * (0.12 + i * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          width * 0.06,
          top,
          width * 0.88,
          height * 0.08,
        ),
        const Radius.circular(999),
      ),
      bandPaint,
    );
  }

  final cloudCount = options.isPreviewQuality ? 6 : 10;
  for (int i = 0; i < cloudCount; i++) {
    _drawCloudPuff(
      canvas,
      Offset(
        width * (0.06 + random.nextDouble() * 0.88),
        height * (0.10 + random.nextDouble() * 0.78),
      ),
      min(width, height) * (0.036 + random.nextDouble() * 0.03),
      (i.isEven ? Colors.white : (cloudTint ?? decor.secondary))
          .withValues(alpha: cloudTint == null ? 0.14 : 0.22),
    );
  }
  canvas.drawCircle(
    Offset(width * 0.18, height * 0.76),
    min(width, height) * 0.11,
    Paint()..color = (cloudTint ?? decor.primary).withValues(alpha: 0.07),
  );
}

void _drawCloudPuff(
  Canvas canvas,
  Offset center,
  double size,
  Color color,
) {
  final paint = Paint()..color = color;
  canvas.drawCircle(
      Offset(center.dx - size * 0.56, center.dy), size * 0.48, paint);
  canvas.drawCircle(Offset(center.dx - size * 0.12, center.dy - size * 0.18),
      size * 0.58, paint);
  canvas.drawCircle(
      Offset(center.dx + size * 0.42, center.dy), size * 0.44, paint);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - size * 0.04, center.dy + size * 0.22),
        width: size * 1.9,
        height: size * 0.76,
      ),
      Radius.circular(size * 0.38),
    ),
    paint,
  );
}

void _drawSparkle(
  Canvas canvas,
  Offset center,
  double size,
  Color color,
) {
  final path = Path()
    ..moveTo(center.dx, center.dy - size)
    ..quadraticBezierTo(
      center.dx + size * 0.22,
      center.dy - size * 0.22,
      center.dx + size,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + size * 0.22,
      center.dy + size * 0.22,
      center.dx,
      center.dy + size,
    )
    ..quadraticBezierTo(
      center.dx - size * 0.22,
      center.dy + size * 0.22,
      center.dx - size,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx - size * 0.22,
      center.dy - size * 0.22,
      center.dx,
      center.dy - size,
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _drawHeart(
  Canvas canvas,
  Offset center,
  double size,
  Color color,
) {
  final path = Path();
  path.moveTo(center.dx, center.dy + size * 0.32);
  path.cubicTo(
    center.dx - size * 1.05,
    center.dy - size * 0.18,
    center.dx - size * 0.58,
    center.dy - size,
    center.dx,
    center.dy - size * 0.42,
  );
  path.cubicTo(
    center.dx + size * 0.58,
    center.dy - size,
    center.dx + size * 1.05,
    center.dy - size * 0.18,
    center.dx,
    center.dy + size * 0.32,
  );
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

void _drawRobotCatMascot(
  Canvas canvas,
  Offset center,
  double size, {
  double opacity = 1,
  double rotation = 0,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotation);

  final blue = const Color(0xFF38BDF8).withValues(alpha: opacity);
  final white = Colors.white.withValues(alpha: opacity * 0.92);
  final red = const Color(0xFFFF4B6E).withValues(alpha: opacity);
  final line = const Color(0xFF2563EB).withValues(alpha: opacity * 0.55);

  canvas.drawCircle(Offset.zero, size, Paint()..color = blue);
  canvas.drawCircle(
    Offset(0, size * 0.08),
    size * 0.72,
    Paint()..color = white,
  );
  canvas.drawCircle(
    Offset(0, -size * 0.08),
    size * 0.09,
    Paint()..color = red,
  );
  canvas.drawCircle(
    Offset(-size * 0.25, -size * 0.18),
    size * 0.11,
    Paint()..color = Colors.white.withValues(alpha: opacity),
  );
  canvas.drawCircle(
    Offset(size * 0.25, -size * 0.18),
    size * 0.11,
    Paint()..color = Colors.white.withValues(alpha: opacity),
  );
  canvas.drawCircle(
    Offset(-size * 0.25, -size * 0.17),
    size * 0.045,
    Paint()..color = line,
  );
  canvas.drawCircle(
    Offset(size * 0.25, -size * 0.17),
    size * 0.045,
    Paint()..color = line,
  );

  final whiskerPaint = Paint()
    ..color = line
    ..strokeWidth = max(1, size * 0.025)
    ..strokeCap = StrokeCap.round;
  for (final dy in [-0.02, 0.12]) {
    canvas.drawLine(
      Offset(-size * 0.62, size * dy),
      Offset(-size * 0.18, size * (dy + 0.02)),
      whiskerPaint,
    );
    canvas.drawLine(
      Offset(size * 0.18, size * (dy + 0.02)),
      Offset(size * 0.62, size * dy),
      whiskerPaint,
    );
  }
  canvas.drawLine(
    Offset(0, size * 0.03),
    Offset(0, size * 0.32),
    whiskerPaint,
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(0, size * 0.22),
      width: size * 0.42,
      height: size * 0.28,
    ),
    0,
    pi,
    false,
    whiskerPaint,
  );
  canvas.drawCircle(
    Offset(0, size * 0.9),
    size * 0.12,
    Paint()..color = const Color(0xFFFFD166).withValues(alpha: opacity),
  );
  canvas.restore();
}

void _drawBoyMascot(
  Canvas canvas,
  Offset center,
  double size, {
  double opacity = 1,
  double rotation = 0,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotation);

  final skin = const Color(0xFFFFD7B5).withValues(alpha: opacity);
  final hair = const Color(0xFF2F2A37).withValues(alpha: opacity);
  final shirt = const Color(0xFFFFD166).withValues(alpha: opacity);
  final line = const Color(0xFF7C2D12).withValues(alpha: opacity * 0.55);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, size * 0.72),
        width: size * 1.34,
        height: size * 0.88,
      ),
      Radius.circular(size * 0.28),
    ),
    Paint()..color = shirt,
  );
  canvas.drawCircle(Offset.zero, size * 0.58, Paint()..color = skin);
  canvas.drawPath(
    Path()
      ..moveTo(-size * 0.58, -size * 0.18)
      ..quadraticBezierTo(
        -size * 0.14,
        -size * 0.75,
        size * 0.58,
        -size * 0.18,
      )
      ..quadraticBezierTo(
        size * 0.18,
        -size * 0.50,
        -size * 0.58,
        -size * 0.18,
      )
      ..close(),
    Paint()..color = hair,
  );
  final glassPaint = Paint()
    ..color = line
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1, size * 0.035);
  canvas.drawCircle(
    Offset(-size * 0.20, size * 0.02),
    size * 0.14,
    glassPaint,
  );
  canvas.drawCircle(
    Offset(size * 0.20, size * 0.02),
    size * 0.14,
    glassPaint,
  );
  canvas.drawLine(
    Offset(-size * 0.06, size * 0.02),
    Offset(size * 0.06, size * 0.02),
    glassPaint,
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(0, size * 0.23),
      width: size * 0.34,
      height: size * 0.18,
    ),
    0.15,
    pi - 0.3,
    false,
    glassPaint,
  );
  canvas.restore();
}

void _drawHeader(
  Canvas canvas,
  double width,
  String title,
  CollageDecor decor,
) {
  final double headerHeight =
      decor.showBlessing && decor.message.trim().isNotEmpty ? 270 : 210;
  final headerRect = RRect.fromRectAndCorners(
    Rect.fromLTWH(36, 30, width - 72, headerHeight),
    topLeft: const Radius.circular(34),
    topRight: const Radius.circular(16),
    bottomLeft: const Radius.circular(18),
    bottomRight: const Radius.circular(38),
  );
  final double headerCenterX = headerRect.outerRect.center.dx;

  canvas.drawRRect(
    headerRect,
    Paint()
      ..shader = ui.Gradient.linear(
        headerRect.outerRect.topLeft,
        headerRect.outerRect.bottomRight,
        [
          Colors.white.withValues(alpha: 0.96),
          decor.secondary.withValues(alpha: 0.26),
          const Color(0xFFF5E8DA).withValues(alpha: 0.92),
        ],
        [0.0, 0.48, 1.0],
      ),
  );
  canvas.drawRRect(
    headerRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = ui.Gradient.linear(
        headerRect.outerRect.topLeft,
        headerRect.outerRect.topRight,
        [
          decor.primary.withValues(alpha: 0.42),
          const Color(0xFFD7C4B8).withValues(alpha: 0.40),
        ],
      ),
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(62, 48, 30, 42),
      const Radius.circular(12),
    ),
    Paint()..color = decor.secondary.withValues(alpha: 0.58),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(width - 92, 48, 30, 42),
      const Radius.circular(12),
    ),
    Paint()..color = decor.primary.withValues(alpha: 0.20),
  );

  final double ribbonWidth = min(390, max(220, width - 84)).toDouble();
  final ribbonRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(headerCenterX, 64),
      width: ribbonWidth,
      height: 44,
    ),
    const Radius.circular(999),
  );
  canvas.drawRRect(
    ribbonRect,
    Paint()
      ..shader = ui.Gradient.linear(
        ribbonRect.outerRect.centerLeft,
        ribbonRect.outerRect.centerRight,
        [decor.primary, decor.secondary],
      ),
  );
  _drawCenteredTextInRect(
    canvas,
    'KHOẢNH KHẮC ĐẶC BIỆT',
    ribbonRect.outerRect,
    Colors.white,
    width < 420 ? 15 : 18,
    letterSpacing: 1.2,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
  );

  final double badgeWidth =
      min(max(148, decor.badge.length * 10.0 + 36), width - 120).toDouble();
  final badgeRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(headerCenterX, 133),
      width: badgeWidth,
      height: 38,
    ),
    const Radius.circular(999),
  );
  canvas.drawRRect(
    badgeRect,
    Paint()..color = Colors.white.withValues(alpha: 0.78),
  );
  _drawText(
    canvas,
    decor.badge.toUpperCase(),
    headerCenterX,
    123,
    decor.primary,
    width < 420 ? 12 : 14,
    maxWidth: badgeWidth - 18,
    centerWidth: badgeWidth - 18,
    letterSpacing: 1.1,
  );

  const double titleY = 154;
  final double titleSize = width < 420 ? 44 : 58;
  final double titleMaxWidth =
      min(max(190, width - 132).toDouble(), headerRect.outerRect.width - 82);
  _drawText(
    canvas,
    title,
    headerCenterX + 2,
    titleY + 2,
    decor.primary.withValues(alpha: 0.16),
    titleSize,
    maxWidth: titleMaxWidth,
    centerWidth: titleMaxWidth,
  );
  final double titleH = _drawText(
    canvas,
    title,
    headerCenterX,
    titleY,
    decor.primary,
    titleSize,
    maxWidth: titleMaxWidth,
    centerWidth: titleMaxWidth,
  );

  final double occasionY = titleY + titleH + 14;
  final double occasionMaxWidth =
      min(headerRect.outerRect.width - 120, titleMaxWidth + 8);
  final double occasionH = _drawText(
    canvas,
    decor.occasionLabel,
    headerCenterX,
    occasionY,
    const Color(0xFF5F4B43),
    25,
    maxWidth: occasionMaxWidth,
    centerWidth: occasionMaxWidth,
    isBold: false,
    fontStyle: FontStyle.italic,
  );

  // 4. Message (Lời chúc) - Chỉ vẽ nếu có
  if (decor.showBlessing && decor.message.trim().isNotEmpty) {
    final double messageY = occasionY + occasionH + 18;
    final double messageBoxW =
        min(width - 136, headerRect.outerRect.width - 56);

    // Đo chiều cao message để vẽ background chuẩn
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 19,
      fontWeight: FontWeight.normal,
      maxLines: 3,
      ellipsis: '...',
    );
    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(color: const Color(0xFF6A4C40)))
      ..addText(decor.message);
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: messageBoxW - 40));

    final double messageBoxH = paragraph.height + 28;
    final double messageBoxX = headerCenterX - messageBoxW / 2;

    final messageRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(messageBoxX, messageY, messageBoxW, messageBoxH),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      messageRect,
      Paint()
        ..shader = ui.Gradient.linear(
          messageRect.outerRect.centerLeft,
          messageRect.outerRect.centerRight,
          [
            decor.secondary.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.70),
            const Color(0xFFC7D4C8).withValues(alpha: 0.18),
          ],
          [0.0, 0.54, 1.0],
        ),
    );
    canvas.drawRRect(
      messageRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = decor.primary.withValues(alpha: 0.16),
    );

    canvas.drawParagraph(paragraph, Offset(messageBoxX + 20, messageY + 14));
  }
}

void _drawFooter(
  Canvas canvas,
  double width,
  double height,
  CollageDecor decor,
) {
  final footerRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(width - 254, height - 72, 194, 40),
    const Radius.circular(999),
  );
  canvas.drawRRect(
    footerRect,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.68)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawRRect(
    footerRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = decor.primary.withValues(alpha: 0.12),
  );
  _drawText(
    canvas,
    decor.footerText,
    footerRect.outerRect.center.dx,
    height - 66,
    decor.primary.withValues(alpha: 0.88),
    14,
    maxWidth: footerRect.outerRect.width - 28,
    centerWidth: footerRect.outerRect.width - 28,
    isBold: false,
    fontStyle: FontStyle.italic,
  );
}

void _drawSelectedStickers(
  Canvas canvas,
  double width,
  double height,
  List<String> selectedStickers,
  CollageDecor decor,
  CollageRenderOptions options,
) {
  final stickers = selectedStickers
      .where((sticker) => sticker.trim().isNotEmpty)
      .take(18)
      .toList();
  if (stickers.isEmpty) {
    return;
  }
  final random = _layoutRandom(options, 0x0715);
  stickers.shuffle(random);

  final positions = <Offset>[
    Offset(width * 0.12, height * 0.31),
    Offset(width * 0.88, height * 0.33),
    Offset(width * 0.16, height * 0.62),
    Offset(width * 0.83, height * 0.64),
    Offset(width * 0.50, height * 0.92),
    Offset(width * 0.29, height * 0.43),
    Offset(width * 0.72, height * 0.47),
    Offset(width * 0.08, height * 0.82),
    Offset(width * 0.92, height * 0.82),
  ];
  positions.shuffle(random);
  final baseSize = min(width, height) * 0.045;

  for (int i = 0; i < stickers.length; i++) {
    final basePosition = positions[i % positions.length];
    final ring = i ~/ positions.length;
    final wave = (i / max(1, stickers.length - 1)) * pi;
    final size =
        (baseSize * (0.90 + random.nextDouble() * 0.45) + sin(wave) * 6)
            .clamp(34.0, 72.0)
            .toDouble();
    final position = basePosition.translate(
      (random.nextDouble() - 0.5) * (28 + ring * 10),
      (random.nextDouble() - 0.5) * (22 + ring * 10),
    );
    final rotation = (random.nextDouble() - 0.5) * 0.6;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    canvas.drawCircle(
      Offset.zero,
      size * 0.58,
      Paint()..color = Colors.white.withValues(alpha: 0.34),
    );
    canvas.drawCircle(
      Offset.zero,
      size * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = decor.primary.withValues(alpha: 0.10),
    );
    final stickerImage = _loadedStickerImages[stickers[i]];
    if (stickerImage != null) {
      final imageRatio = stickerImage.width / stickerImage.height;
      final drawHeight = size * 1.35;
      final drawWidth = drawHeight * imageRatio;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: drawWidth,
        height: drawHeight,
      );
      paintImage(
        canvas: canvas,
        rect: rect,
        image: stickerImage,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    } else {
      _drawText(
        canvas,
        stickers[i],
        0,
        -size * 0.48,
        const Color(0xFF1F2937),
        size,
        maxWidth: size * 2.2,
        isBold: false,
      );
    }
    canvas.restore();
  }
}

Future<void> _loadStickerImages(
  List<String> stickers,
) async {
  final assetStickers = stickers
      .where(
        (sticker) =>
            sticker.startsWith('assets/') &&
            !_loadedStickerImages.containsKey(sticker),
      )
      .toList(growable: false);
  for (final sticker in assetStickers) {
    try {
      final byteData = await rootBundle.load(sticker);
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      _loadedStickerImages[sticker] = frame.image;
    } catch (_) {}
  }
}

_CollageCanvasFrame _resolveCanvasFrame(
  double contentWidth,
  double contentHeight,
  CollageRenderOptions options,
) {
  final targetRatio = options.safeOutputAspectRatio;
  if (targetRatio == null) {
    return _CollageCanvasFrame(width: contentWidth, height: contentHeight);
  }

  final currentRatio = contentWidth / contentHeight;
  if ((currentRatio - targetRatio).abs() < 0.02) {
    return _CollageCanvasFrame(width: contentWidth, height: contentHeight);
  }

  if (currentRatio < targetRatio) {
    final width = max(contentWidth, contentHeight * targetRatio);
    return _CollageCanvasFrame(
      width: width,
      height: contentHeight,
      offsetX: (width - contentWidth) / 2,
    );
  }

  final height = max(contentHeight, contentWidth / targetRatio);
  return _CollageCanvasFrame(
    width: contentWidth,
    height: height,
    offsetY: (height - contentHeight) / 2,
  );
}

Rect _coverSourceRect(
  ui.Image img,
  Rect destRect, {
  CollagePhotoTransform? transform,
}) {
  final double destRatio = destRect.width / destRect.height;
  final double srcRatio = img.width / img.height;

  double sourceWidth = img.width.toDouble();
  double sourceHeight = img.height.toDouble();

  if (srcRatio > destRatio) {
    sourceWidth = sourceHeight * destRatio;
  } else {
    sourceHeight = sourceWidth / destRatio;
  }

  if (transform != null) {
    final zoom = transform.scale.clamp(1.0, 4.0).toDouble();
    sourceWidth /= zoom;
    sourceHeight /= zoom;

    final double availableX = max(0.0, img.width - sourceWidth);
    final double availableY = max(0.0, img.height - sourceHeight);
    final double normalizedX =
        transform.offset.dx.clamp(-1.0, 1.0).toDouble();
    final double normalizedY =
        transform.offset.dy.clamp(-1.0, 1.0).toDouble();
    final double sx = availableX / 2 + normalizedX * availableX / 2;
    final double sy = availableY / 2 + normalizedY * availableY / 2;
    return Rect.fromLTWH(sx, sy, sourceWidth, sourceHeight);
  }

  final double sx = (img.width - sourceWidth) / 2;
  final double sy = (img.height - sourceHeight) / 2;
  return Rect.fromLTWH(sx, sy, sourceWidth, sourceHeight);
}

void _drawImageWithTransform(
  Canvas canvas,
  ui.Image img,
  Rect destRect,
  CollagePhotoTransform? transform,
) {
  canvas.drawImageRect(
    img,
    _coverSourceRect(img, destRect, transform: transform),
    destRect,
    Paint(),
  );
}

void _drawImageSurfaceWithTransform(
  Canvas canvas,
  ui.Image img,
  Rect imageRect, {
  double radius = 28,
  CollagePhotoTransform? transform,
}) {
  final clipRRect =
      RRect.fromRectAndRadius(imageRect, Radius.circular(radius));

  canvas.save();
  canvas.clipRRect(clipRRect);

  _drawImageWithTransform(canvas, img, imageRect, transform);
  canvas.drawRect(
    imageRect,
    Paint()..color = Colors.white.withValues(alpha: 0.18),
  );
  canvas.drawRect(
    imageRect,
    Paint()
      ..shader = ui.Gradient.linear(
        imageRect.topCenter,
        imageRect.bottomCenter,
        [
          Colors.white.withValues(alpha: 0.14),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.08),
        ],
        [0.0, 0.58, 1.0],
      ),
  );

  canvas.restore();

  canvas.drawRRect(
    clipRRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = Colors.white.withValues(alpha: 0.52),
  );
}

void _drawCircularPhotoSurface(
  Canvas canvas,
  ui.Image img,
  double size, {
  CollagePhotoTransform? transform,
}) {
  final Rect bounds = Rect.fromLTWH(-size / 2, -size / 2, size, size);
  canvas.save();
  canvas.clipPath(Path()..addOval(bounds));
  _drawImageWithTransform(canvas, img, bounds, transform);
  canvas.drawOval(
    bounds,
    Paint()..color = Colors.white.withValues(alpha: 0.15),
  );
  canvas.restore();

  canvas.drawCircle(
    Offset.zero,
    size / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, size * 0.02)
      ..color = Colors.white.withValues(alpha: 0.62),
  );
}

void _drawFrameImage(
  Canvas canvas,
  ui.Image img,
  Rect imageRect,
  CollageDecor decor, {
  double radius = 28,
  CollagePhotoTransform? transform,
}) {
  final outerRect = imageRect.inflate(2);
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.12)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      outerRect.shift(const Offset(0, 12)),
      Radius.circular(radius + 4),
    ),
    shadowPaint,
  );
  _drawImageSurfaceWithTransform(
    canvas,
    img,
    imageRect,
    radius: radius,
    transform: transform,
  );
}
