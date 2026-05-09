import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollageDecor {
  final String badge;
  final String occasionLabel;
  final String message;
  final String footerText;
  final Color primary;
  final Color secondary;
  final Color backgroundTop;
  final Color backgroundBottom;
  final bool showBlessing;

  const CollageDecor({
    required this.badge,
    required this.occasionLabel,
    required this.message,
    required this.footerText,
    required this.primary,
    required this.secondary,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.showBlessing,
  });

  factory CollageDecor.memory({
    required String occasionLabel,
    required String message,
  }) {
    return CollageDecor(
      badge: 'Dấu mốc yêu thương',
      occasionLabel: occasionLabel,
      message: message,
      footerText: 'SoulLocket cảm ơn',
      primary: const Color(0xFFA76F61),
      secondary: const Color(0xFFC7D4C8),
      backgroundTop: const Color(0xFFF7F0E6),
      backgroundBottom: const Color(0xFFF0E3D4),
      showBlessing: true,
    );
  }

  factory CollageDecor.upload() {
    return const CollageDecor(
      badge: 'Bộ sưu tập riêng',
      occasionLabel: 'Khoảnh khắc được bạn chọn',
      message: '',
      footerText: 'SoulLocket cảm ơn',
      primary: Color(0xFF6A4C40),
      secondary: Color(0xFFD7C4B8),
      backgroundTop: Color(0xFFFFF8F2),
      backgroundBottom: Color(0xFFF1E4D6),
      showBlessing: false,
    );
  }
}

enum CollageRenderQuality { preview, full }

class CollagePhotoTransform {
  final double scale;
  final Offset offset;

  const CollagePhotoTransform({
    this.scale = 1,
    this.offset = Offset.zero,
  });
}

class CollageRenderOptions {
  final List<String> stickers;
  final double photoScale;
  final double? outputAspectRatio;
  final String backgroundTheme;
  final int layoutSeed;
  final CollageRenderQuality renderQuality;
  final List<CollagePhotoTransform> photoTransforms;

  const CollageRenderOptions({
    this.stickers = const [],
    this.photoScale = 1,
    this.outputAspectRatio,
    this.backgroundTheme = 'default',
    this.layoutSeed = 1,
    this.renderQuality = CollageRenderQuality.full,
    this.photoTransforms = const [],
  });

  double get safePhotoScale => photoScale.clamp(0.78, 1.24).toDouble();
  double? get safeOutputAspectRatio {
    final ratio = outputAspectRatio;
    if (ratio == null || ratio <= 0) {
      return null;
    }
    return ratio.clamp(0.48, 2.5).toDouble();
  }

  bool get isPreviewQuality => renderQuality == CollageRenderQuality.preview;
  double get renderScale => isPreviewQuality ? 0.62 : 1.0;
}

class _CollageCanvasFrame {
  final double width;
  final double height;
  final double offsetX;
  final double offsetY;

  const _CollageCanvasFrame({
    required this.width,
    required this.height,
    this.offsetX = 0,
    this.offsetY = 0,
  });
}

Random _layoutRandom(CollageRenderOptions options, int salt) {
  return Random((options.layoutSeed ^ salt) & 0x7fffffff);
}

class CollageGenerator {
  static const String watermark = 'SoulLocket cảm ơn';
  static final Map<String, ui.Image> _loadedStickerImages =
      <String, ui.Image>{};

  static Future<Uint8List?> generateCollage(
    List<ui.Image> images,
    String title,
    String styleType, {
    CollageDecor? decor,
    CollageRenderOptions options = const CollageRenderOptions(),
  }) async {
    if (images.isEmpty) return null;
    final effectiveDecor =
        decor ?? CollageDecor.memory(occasionLabel: 'Kỷ niệm', message: '');
    final renderScale = options.renderScale;
    await _loadStickerImages(options.stickers);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    Size canvasSize;
    if (renderScale != 1.0) {
      canvas.save();
      canvas.scale(renderScale, renderScale);
    }

    switch (styleType) {
      case 'polaroid':
        canvasSize = _drawPolaroidCollage(
            canvas, images, title, effectiveDecor, options);
        break;
      case 'masonry':
        canvasSize =
            _drawMasonryCollage(canvas, images, title, effectiveDecor, options);
        break;
      case 'story':
        canvasSize =
            _drawStoryCollage(canvas, images, title, effectiveDecor, options);
        break;
      case 'scatter':
        canvasSize =
            _drawScatterCollage(canvas, images, title, effectiveDecor, options);
        break;
      case 'heart':
        canvasSize =
            _drawHeartCollage(canvas, images, title, effectiveDecor, options);
        break;
      case 'poster':
        canvasSize =
            _drawPosterCollage(canvas, images, title, effectiveDecor, options);
        break;
      case 'grid':
      default:
        canvasSize =
            _drawGridCollage(canvas, images, title, effectiveDecor, options);
        break;
    }
    if (renderScale != 1.0) {
      canvas.restore();
    }

    final outputWidth =
        (canvasSize.width * renderScale).round().clamp(1, 8192).toInt();
    final outputHeight =
        (canvasSize.height * renderScale).round().clamp(1, 8192).toInt();

    final picture = recorder.endRecording();
    final img = await picture.toImage(outputWidth, outputHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  static double _drawText(
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

  static void _drawCenteredTextInRect(
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

  static void _drawBackground(
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

  static void _drawCuteBackgroundTheme(
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

  static void _drawPastelWash(
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

  static void _drawSkyCloudTheme(
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

  static void _drawBubbleCloudTheme(
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
          ? (bubbleTint ?? decor.secondary).withValues(alpha: 
              (bubbleTint == null ? 0.10 : 0.18) + random.nextDouble() * 0.10)
          : (accentTint ?? decor.primary).withValues(alpha: 
              (accentTint == null ? 0.07 : 0.14) + random.nextDouble() * 0.08);
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

  static void _drawPaperCloudTheme(
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

  static void _drawCloudPuff(
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

  static void _drawSparkle(
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

  static void _drawHeart(
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

  static void _drawRobotCatMascot(
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

  static void _drawBoyMascot(
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

  static void _drawHeader(
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

  static void _drawFooter(
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

  static void _drawSelectedStickers(
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
          filterQuality: FilterQuality.high,
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

  static Future<void> _loadStickerImages(
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

  static _CollageCanvasFrame _resolveCanvasFrame(
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

  static Rect _coverSourceRect(
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
      final double normalizedX = transform.offset.dx.clamp(-1.0, 1.0).toDouble();
      final double normalizedY = transform.offset.dy.clamp(-1.0, 1.0).toDouble();
      final double sx = availableX / 2 + normalizedX * availableX / 2;
      final double sy = availableY / 2 + normalizedY * availableY / 2;
      return Rect.fromLTWH(sx, sy, sourceWidth, sourceHeight);
    }

    final double sx = (img.width - sourceWidth) / 2;
    final double sy = (img.height - sourceHeight) / 2;
    return Rect.fromLTWH(sx, sy, sourceWidth, sourceHeight);
  }

  static void _drawImageWithTransform(
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

  static void _drawImageSurfaceWithTransform(
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

  static void _drawCircularPhotoSurface(
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

  static void _drawFrameImage(
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


  static Size _drawGridCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    final int n = images.length;
    final int cols = sqrt(n).ceil();
    final int rows = (n / cols).ceil();
    const double padding = 22.0;
    const double headerH = 320.0; // Tăng từ 260 lên 320
    const double footerH = 120.0;
    final double photoScale = options.safePhotoScale;
    final double cellW = 280.0 * photoScale;
    final double cellH = 280.0 * photoScale;

    final double contentWidth = cols * cellW + padding * (cols + 1);
    final double contentHeight =
        rows * cellH + padding * (rows + 1) + headerH + footerH;
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);
    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final int c = i % cols;
      final int r = i ~/ cols;
      final double x = padding + c * (cellW + padding);
      final double y = headerH + padding + r * (cellH + padding);
      _drawFrameImage(
        canvas,
        img,
        Rect.fromLTWH(x, y, cellW, cellH),
        decor,
        transform: i < options.photoTransforms.length
            ? options.photoTransforms[i]
            : null,
      );
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);

    return Size(frame.width, frame.height);
  }

  static Size _drawMasonryCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    int cols = 2;
    if (images.length > 6) cols = 3;
    if (images.length > 18) cols = 4;
    if (images.length > 32) cols = 5;

    final double colWidth = 280.0 * options.safePhotoScale;
    const double padding = 22.0;
    const double headerH = 320.0;
    const double footerH = 120.0;
    final double tileHeight = colWidth * 1.02;

    final double contentWidth = cols * colWidth + padding * (cols + 1);
    final List<Map<String, dynamic>> drawPositions = [];

    double cursorY = headerH + padding;
    int imageIndex = 0;

    while (imageIndex < images.length) {
      final int remaining = images.length - imageIndex;
      final int itemsThisRow = min(cols, remaining);
      final double rowWidth =
          itemsThisRow * colWidth + max(0, itemsThisRow - 1) * padding;
      final double startX = max(
        padding,
        (contentWidth - rowWidth) / 2,
      );

      for (int col = 0; col < itemsThisRow; col++) {
        final ui.Image img = images[imageIndex];
        final double x = startX + col * (colWidth + padding);

        drawPositions.add({
          'img': img,
          'index': imageIndex,
          'x': x,
          'y': cursorY,
          'w': colWidth,
          'h': tileHeight,
        });
        imageIndex++;
      }

      cursorY += tileHeight + padding;
    }

    final double contentHeight = cursorY - padding + footerH;
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);
    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    for (final pos in drawPositions) {
      final ui.Image img = pos['img'];
      final int index = pos['index'];
      final double x = pos['x'];
      final double y = pos['y'];
      final double w = pos['w'];
      final double h = pos['h'];
      _drawFrameImage(
        canvas,
        img,
        Rect.fromLTWH(x, y, w, h),
        decor,
        radius: 24,
        transform: index < options.photoTransforms.length
            ? options.photoTransforms[index]
            : null,
      );
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);

    return Size(frame.width, frame.height);
  }

  static Size _drawPolaroidCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    final int n = images.length;
    final double photoScale = options.safePhotoScale;
    final double expectedArea = n * (400.0 * photoScale) * (450.0 * photoScale);
    final double side = sqrt(expectedArea) * 1.5;
    final double contentWidth = max(1200.0, side);
    final double contentHeight = max(1320.0, side + 150);
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);
    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    const double marginX = 200;
    const double marginY = 320;
    final double availW = contentWidth - marginX * 2;
    final double availH = contentHeight - marginY - 200;

    final random = _layoutRandom(options, 0x1205);

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      canvas.save();

      final double x = marginX + random.nextDouble() * availW;
      final double y = marginY + 100 + random.nextDouble() * availH;
      final double angle = (random.nextDouble() - 0.5) * 0.52;

      canvas.translate(x, y);
      canvas.rotate(angle);

      final double pW = 370 * photoScale;
      final double pH = 440 * photoScale;
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawRect(
        Rect.fromLTWH(-pW / 2 + 5, -pH / 2 + 12, pW, pH),
        shadowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-pW / 2, -pH / 2, pW, pH),
          Radius.circular(14 * photoScale),
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(-pW / 2, -pH / 2, pW, pH),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.black.withValues(alpha: 0.06),
      );

      final double imgPadding = 16 * photoScale;
      final double drawW = pW - imgPadding * 2;
      final double drawH = drawW;

      _drawImageSurfaceWithTransform(
        canvas,
        img,
        Rect.fromLTWH(-pW / 2 + imgPadding, -pH / 2 + imgPadding, drawW, drawH),
        radius: 18 * photoScale,
        transform: i < options.photoTransforms.length
            ? options.photoTransforms[i]
            : null,
      );
      _drawText(
        canvas,
        decor.footerText,
        0,
        pH / 2 - 48 * photoScale,
        decor.primary.withValues(alpha: 0.66),
        15 * photoScale,
        maxWidth: pW - 40,
        isBold: false,
        fontStyle: FontStyle.italic,
      );

      canvas.restore();
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);
    return Size(frame.width, frame.height);
  }

  static Size _drawScatterCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    final int n = images.length;
    final double photoScale = options.safePhotoScale;
    final double expectedArea = n * (300.0 * photoScale) * (300.0 * photoScale);
    final double side = sqrt(expectedArea) * 1.3;
    final double contentWidth = max(1000.0, side);
    final double contentHeight = max(1180.0, side + 150);
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);

    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    const double marginX = 150;
    const double marginY = 320;
    final double availW = contentWidth - marginX * 2;
    final double availH = contentHeight - marginY - 170;

    final random = _layoutRandom(options, 0x1260);

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      canvas.save();
      final double x = marginX + random.nextDouble() * availW;
      final double y = marginY + 100 + random.nextDouble() * availH;
      final double angle = (random.nextDouble() - 0.5) * 0.52;

      canvas.translate(x, y);
      canvas.rotate(angle);

      final double size = (280 + random.nextDouble() * 150) * photoScale;
      final double ratio = img.width / img.height;
      double dw = size;
      double dh = size / ratio;

      if (ratio < 1) {
        dh = size;
        dw = size * ratio;
      }
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      final imageRect = Rect.fromLTWH(-dw / 2, -dh / 2, dw, dh);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          imageRect.shift(const Offset(0, 12)),
          const Radius.circular(26),
        ),
        shadowPaint,
      );

      _drawImageSurfaceWithTransform(
        canvas,
        img,
        imageRect,
        radius: 24,
        transform: i < options.photoTransforms.length
            ? options.photoTransforms[i]
            : null,
      );

      canvas.restore();
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);
    return Size(frame.width, frame.height);
  }

  static Size _drawStoryCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    final double photoScale = options.safePhotoScale;
    const double padding = 28.0;
    const double headerH = 320.0;
    const double footerH = 118.0;
    final double contentWidth = max(940.0, 1020.0 * photoScale);
    final double innerWidth = contentWidth - padding * 2;
    final double heroHeight = innerWidth * 0.92;

    double cursorY = headerH + padding;
    final heroRect = Rect.fromLTWH(padding, cursorY, innerWidth, heroHeight);
    cursorY = heroRect.bottom + padding;

    final double columnWidth = (innerWidth - padding) / 2;
    final double tileHeight = max(182.0, 220.0 * photoScale);
    final List<Rect> extraRects = [];
    int index = 1;

    while (index < images.length) {
      final bool useWideTile = (index % 5 == 0 || images.length - index == 1) &&
          index < images.length;
      if (useWideTile) {
        final double wideHeight = tileHeight * 0.84;
        extraRects.add(
          Rect.fromLTWH(padding, cursorY, innerWidth, wideHeight),
        );
        cursorY += wideHeight + padding;
        index += 1;
        continue;
      }

      final int rowCount = min(2, images.length - index);
      for (int col = 0; col < rowCount; col++) {
        extraRects.add(
          Rect.fromLTWH(
            padding + col * (columnWidth + padding),
            cursorY,
            columnWidth,
            tileHeight,
          ),
        );
      }
      cursorY += tileHeight + padding;
      index += rowCount;
    }

    final double contentHeight = cursorY + footerH;
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);
    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    _drawFrameImage(
      canvas,
      images.first,
      heroRect,
      decor,
      radius: 34,
      transform: options.photoTransforms.isNotEmpty
          ? options.photoTransforms.first
          : null,
    );
    for (int rectIndex = 0; rectIndex < extraRects.length; rectIndex++) {
      final imageIndex = rectIndex + 1;
      if (imageIndex >= images.length) {
        break;
      }
      _drawFrameImage(
        canvas,
        images[imageIndex],
        extraRects[rectIndex],
        decor,
        radius: 26,
      );
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);
    return Size(frame.width, frame.height);
  }

  static Size _drawPosterCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    final double photoScale = options.safePhotoScale;
    const double padding = 28.0;
    const double headerH = 320.0;
    const double footerH = 118.0;
    final double contentWidth = max(1180.0, 1320.0 * photoScale);
    final double innerWidth = contentWidth - padding * 2;
    final double leadWidth =
        images.length == 1 ? innerWidth : innerWidth * 0.58;
    final double leadHeight = max(410.0, 560.0 * photoScale);
    final double sideWidth = innerWidth - leadWidth - padding;
    const double topY = headerH + padding;

    final List<(int, Rect)> placements = [
      (0, Rect.fromLTWH(padding, topY, leadWidth, leadHeight)),
    ];

    int imageIndex = 1;
    if (images.length == 2) {
      placements.add(
        (
          1,
          Rect.fromLTWH(
              padding + leadWidth + padding, topY, sideWidth, leadHeight)
        ),
      );
      imageIndex = 2;
    } else if (images.length > 2) {
      final double stackHeight = (leadHeight - padding) / 2;
      placements.add(
        (
          1,
          Rect.fromLTWH(
            padding + leadWidth + padding,
            topY,
            sideWidth,
            stackHeight,
          )
        ),
      );
      placements.add(
        (
          2,
          Rect.fromLTWH(
            padding + leadWidth + padding,
            topY + stackHeight + padding,
            sideWidth,
            stackHeight,
          )
        ),
      );
      imageIndex = 3;
    }

    double cursorY = topY + leadHeight + padding;
    if (imageIndex < images.length) {
      final int cols = min(3, max(1, images.length - imageIndex));
      final double tileWidth = (innerWidth - padding * (cols - 1)) / cols;
      final double tileHeight = max(176.0, tileWidth * 0.74);

      while (imageIndex < images.length) {
        final int rowCount = min(cols, images.length - imageIndex);
        for (int col = 0; col < rowCount; col++) {
          placements.add(
            (
              imageIndex + col,
              Rect.fromLTWH(
                padding + col * (tileWidth + padding),
                cursorY,
                tileWidth,
                tileHeight,
              ),
            ),
          );
        }
        imageIndex += rowCount;
        cursorY += tileHeight + padding;
      }
    }

    final double contentHeight = cursorY + footerH;
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);
    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    for (final placement in placements) {
      if (placement.$1 >= images.length) {
        continue;
      }
      _drawFrameImage(
        canvas,
        images[placement.$1],
        placement.$2,
        decor,
        radius: placement.$1 == 0 ? 34 : 24,
        transform: placement.$1 < options.photoTransforms.length
            ? options.photoTransforms[placement.$1]
            : null,
      );
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);
    return Size(frame.width, frame.height);
  }

  static Size _drawHeartCollage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    const double contentWidth = 1600.0;
    const double contentHeight = 1720.0;
    final frame = _resolveCanvasFrame(contentWidth, contentHeight, options);

    _drawBackground(canvas, frame.width, frame.height, decor, options);
    canvas.save();
    canvas.translate(frame.offsetX, frame.offsetY);
    _drawHeader(
      canvas,
      contentWidth,
      title.isNotEmpty ? title : 'Kỷ niệm của chúng mình ❤️',
      decor,
    );

    final int n = images.length;
    if (n == 0) {
      canvas.restore();
      return Size(frame.width, frame.height);
    }

    final double size =
        min<double>(200.0, 2000.0 / sqrt(n)) * options.safePhotoScale;
    final random = _layoutRandom(options, 0x1541);

    Offset getHeartPoint(
        double t, double scale, double offsetX, double offsetY) {
      final double x = 16 * pow(sin(t), 3).toDouble();
      final double y =
          13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t);
      return Offset(x * scale + offsetX, -y * scale + offsetY);
    }

    for (int i = 0; i < n; i++) {
      canvas.save();
      final double t = random.nextDouble() * pi * 2;
      final double scale = 30.0 + random.nextDouble() * 10.0;
      final Offset pt = getHeartPoint(
        t,
        scale,
        contentWidth / 2,
        contentHeight / 2 + 180,
      );

      final double jx = (random.nextDouble() - 0.5) * 50;
      final double jy = (random.nextDouble() - 0.5) * 50;

      canvas.translate(pt.dx + jx, pt.dy + jy);
      canvas.rotate((random.nextDouble() - 0.5) * 0.5);

      canvas.drawCircle(
        Offset.zero,
        size / 2 + 10,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        Offset.zero,
        size / 2 + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.65),
      );

      final ui.Image img = images[i];
      _drawCircularPhotoSurface(
        canvas,
        img,
        size,
        transform: i < options.photoTransforms.length
            ? options.photoTransforms[i]
            : null,
      );

      canvas.restore();
    }

    _drawFooter(canvas, contentWidth, contentHeight, decor);
    canvas.restore();
    _drawSelectedStickers(
        canvas, frame.width, frame.height, options.stickers, decor, options);
    return Size(frame.width, frame.height);
  }
}
