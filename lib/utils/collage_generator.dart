import 'package:soullocket_app/utils/ui_copy.dart';
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
      badge: UiCopy.text('copy_b8493e2150b5'),
      occasionLabel: occasionLabel,
      message: message,
      footerText: UiCopy.text('app_name'),
      primary: const Color(0xFF244342),
      secondary: const Color(0xFFC99E78),
      backgroundTop: const Color(0xFFFCFBF7),
      backgroundBottom: const Color(0xFFEDE9E1),
      showBlessing: true,
    );
  }

  factory CollageDecor.upload() {
    return CollageDecor(
      badge: UiCopy.text('copy_707b15afff03'),
      occasionLabel: UiCopy.text('copy_a8d05a7109d2'),
      message: '',
      footerText: UiCopy.text('app_name'),
      primary: const Color(0xFF32474B),
      secondary: const Color(0xFFC8A88F),
      backgroundTop: const Color(0xFFFFFCF8),
      backgroundBottom: const Color(0xFFF0EBE5),
      showBlessing: false,
    );
  }
}

enum CollageRenderQuality { preview, full }

class CollagePhotoTransform {
  final double scale;
  final Offset offset;

  const CollagePhotoTransform({this.scale = 1, this.offset = Offset.zero});
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

class _CollagePage {
  final Size size;
  final Rect photoArea;
  final double typeScale;
  final double gap;
  final String heading;

  const _CollagePage({
    required this.size,
    required this.photoArea,
    required this.typeScale,
    required this.gap,
    required this.heading,
  });
}

Random _layoutRandom(CollageRenderOptions options, int salt) {
  return Random((options.layoutSeed ^ salt) & 0x7fffffff);
}

class CollageGenerator {
  static String get watermark => UiCopy.text('app_name');

  static Future<Uint8List?> generateCollage(
    List<ui.Image> images,
    String title,
    String styleType, {
    CollageDecor? decor,
    CollageRenderOptions options = const CollageRenderOptions(),
  }) async {
    if (images.isEmpty) return null;
    final effectiveDecor =
        decor ??
        CollageDecor.memory(
          occasionLabel: UiCopy.text('copy_fc45b5c58245'),
          message: '',
        );
    final renderScale = options.renderScale;
    final stickerImages = await _loadStickerImages(options.stickers);
    try {

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (renderScale != 1.0) {
      canvas.save();
      canvas.scale(renderScale, renderScale);
    }

    final canvasSize = _drawCollagePage(
      canvas,
      images,
      title,
      styleType,
      effectiveDecor,
      options,
      stickerImages,
    );
    if (renderScale != 1.0) {
      canvas.restore();
    }

    final outputWidth = (canvasSize.width * renderScale)
        .round()
        .clamp(1, 8192)
        .toInt();
    final outputHeight = (canvasSize.height * renderScale)
        .round()
        .clamp(1, 8192)
        .toInt();

    final picture = recorder.endRecording();
    ui.Image? img;
    try {
      img = await picture.toImage(outputWidth, outputHeight);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      img?.dispose();
      picture.dispose();
    }
    } finally {
      for (final image in stickerImages.values) {
        image.dispose();
      }
    }
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
      ..pushStyle(ui.TextStyle(color: color, letterSpacing: letterSpacing))
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
      ..pushStyle(ui.TextStyle(color: color, letterSpacing: letterSpacing))
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
    if (options.backgroundTheme != 'default') {
      _drawCuteBackgroundTheme(canvas, width, height, decor, options);
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = decor.backgroundTop,
    );
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
        _drawBubbleCloudTheme(
          canvas,
          width,
          height,
          decor,
          options,
          bubbleBias: 0.6,
          heartBias: 0.35,
        );
        break;
      case 'scatter':
        _drawBubbleCloudTheme(
          canvas,
          width,
          height,
          decor,
          options,
          bubbleBias: 0.75,
          heartBias: 0.12,
        );
        break;
      case 'story':
      case 'poster':
        _drawSkyCloudTheme(
          canvas,
          width,
          height,
          decor,
          options,
          denserTopBand: true,
        );
        break;
      case 'polaroid':
        _drawPaperCloudTheme(canvas, width, height, decor, options);
        break;
      case 'masonry':
        _drawBubbleCloudTheme(
          canvas,
          width,
          height,
          decor,
          options,
          bubbleBias: 0.4,
          heartBias: 0.18,
        );
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
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
          top,
          bottom,
        ]),
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
      final y =
          height *
          (denserTopBand
              ? (0.06 + random.nextDouble() * 0.18)
              : (0.08 + random.nextDouble() * 0.24));
      final size = min(width, height) * (0.055 + random.nextDouble() * 0.05);
      final tint = i.isEven
          ? Colors.white.withValues(alpha: cloudTint == null ? 0.22 : 0.34)
          : (cloudTint ?? decor.secondary).withValues(
              alpha: cloudTint == null ? 0.14 : 0.24,
            );
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
        (sparkleTint ?? Colors.white).withValues(
          alpha: sparkleTint == null ? 0.16 : 0.22,
        ),
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
          ? (bubbleTint ?? decor.secondary).withValues(
              alpha:
                  (bubbleTint == null ? 0.10 : 0.18) +
                  random.nextDouble() * 0.10,
            )
          : (accentTint ?? decor.primary).withValues(
              alpha:
                  (accentTint == null ? 0.07 : 0.14) +
                  random.nextDouble() * 0.08,
            );
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
          (accentTint ?? decor.primary).withValues(
            alpha: accentTint == null ? 0.12 : 0.18,
          ),
        );
      } else {
        _drawCloudPuff(
          canvas,
          center,
          size * 1.1,
          (bubbleTint ?? Colors.white).withValues(
            alpha: bubbleTint == null ? 0.12 : 0.16,
          ),
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
      ..color = (bandTint ?? Colors.white).withValues(
        alpha: bandTint == null ? 0.08 : 0.16,
      );
    final bandCount = options.isPreviewQuality ? 2 : 3;
    for (int i = 0; i < bandCount; i++) {
      final top = height * (0.12 + i * 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(width * 0.06, top, width * 0.88, height * 0.08),
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
        (i.isEven ? Colors.white : (cloudTint ?? decor.secondary)).withValues(
          alpha: cloudTint == null ? 0.14 : 0.22,
        ),
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
      Offset(center.dx - size * 0.56, center.dy),
      size * 0.48,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx - size * 0.12, center.dy - size * 0.18),
      size * 0.58,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size * 0.42, center.dy),
      size * 0.44,
      paint,
    );
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

  static ui.Paragraph _editorialParagraph(
    String text,
    double width,
    double fontSize,
    Color color, {
    FontWeight weight = FontWeight.w400,
    int maxLines = 2,
    double letterSpacing = 0,
    TextAlign align = TextAlign.left,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              fontSize: fontSize,
              fontWeight: weight,
              height: 1.18,
              maxLines: maxLines,
              ellipsis: '…',
            ),
          )
          ..pushStyle(ui.TextStyle(color: color, letterSpacing: letterSpacing))
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: width));
  }

  static ({double height, List<(ui.Paragraph, Offset)> lines}) _layoutHeader(
    double width,
    String title,
    CollageDecor decor, {
    double? typeScale,
  }) {
    final scale = typeScale ?? (width / 1080).clamp(0.45, 1.2).toDouble();
    final inset = width * 0.06;
    final textWidth = width - inset * 2;
    final lines = <(ui.Paragraph, Offset)>[];
    var y = 42 * scale;
    void add(
      String text,
      double size,
      Color color, {
      FontWeight weight = FontWeight.w400,
      int maxLines = 2,
      double tracking = 0,
    }) {
      if (text.trim().isEmpty) return;
      final paragraph = _editorialParagraph(
        text,
        textWidth,
        size * scale,
        color,
        weight: weight,
        maxLines: maxLines,
        letterSpacing: tracking * scale,
      );
      lines.add((paragraph, Offset(inset, y)));
      y += paragraph.height;
    }

    add(
      decor.badge.toUpperCase(),
      17,
      decor.primary.withValues(alpha: 0.70),
      weight: FontWeight.w600,
      maxLines: 1,
      tracking: 2.6,
    );
    y += 14 * scale;
    add(title, 58, decor.primary, weight: FontWeight.w600);
    y += 12 * scale;
    add(decor.occasionLabel, 23, decor.primary.withValues(alpha: 0.66));
    return (height: y + 26 * scale, lines: lines);
  }

  static double _headerHeight(
    double width,
    String title,
    CollageDecor decor, {
    double? typeScale,
  }) {
    final layout = _layoutHeader(width, title, decor, typeScale: typeScale);
    for (final line in layout.lines) {
      line.$1.dispose();
    }
    return layout.height;
  }

  static void _drawHeader(
    Canvas canvas,
    double width,
    String title,
    CollageDecor decor, {
    double? typeScale,
  }) {
    final layout = _layoutHeader(width, title, decor, typeScale: typeScale);
    for (final line in layout.lines) {
      canvas.drawParagraph(line.$1, line.$2);
      line.$1.dispose();
    }
  }

  static double _footerHeight(
    double width,
    CollageDecor decor, {
    double? typeScale,
  }) {
    final scale = typeScale ?? (width / 1080).clamp(0.45, 1.2).toDouble();
    return (decor.showBlessing && decor.message.trim().isNotEmpty ? 148 : 82) *
        scale;
  }

  static void _drawFooter(
    Canvas canvas,
    double width,
    double height,
    CollageDecor decor, {
    double? typeScale,
  }) {
    final scale = typeScale ?? (width / 1080).clamp(0.45, 1.2).toDouble();
    final inset = width * 0.06;
    final textWidth = width - inset * 2;
    var y = height - _footerHeight(width, decor, typeScale: scale) + 22 * scale;
    if (decor.showBlessing && decor.message.trim().isNotEmpty) {
      final message = _editorialParagraph(
        decor.message,
        textWidth,
        21 * scale,
        decor.primary.withValues(alpha: 0.76),
        align: TextAlign.center,
      );
      canvas.drawParagraph(message, Offset(inset, y));
      y += message.height + 17 * scale;
      message.dispose();
    }
    final brandRect = Rect.fromLTWH(
      width / 2 - 90 * scale,
      y,
      180 * scale,
      22 * scale,
    );
    final linePaint = Paint()
      ..color = decor.primary.withValues(alpha: 0.18)
      ..strokeWidth = scale;
    canvas.drawLine(
      Offset(inset, brandRect.center.dy),
      Offset(brandRect.left - 18 * scale, brandRect.center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(brandRect.right + 18 * scale, brandRect.center.dy),
      Offset(width - inset, brandRect.center.dy),
      linePaint,
    );
    _drawCenteredTextInRect(
      canvas,
      decor.footerText,
      brandRect,
      decor.primary.withValues(alpha: 0.56),
      16 * scale,
      isBold: false,
      letterSpacing: 1.5 * scale,
    );
  }

  static void _drawSelectedStickers(
    Canvas canvas,
    double width,
    double height,
    List<String> selectedStickers,
    Map<String, ui.Image> stickerImages,
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
      Offset(width * 0.09, height * 0.32),
      Offset(width * 0.91, height * 0.32),
      Offset(width * 0.09, height * 0.82),
      Offset(width * 0.91, height * 0.82),
      Offset(width * 0.50, height * 0.92),
      Offset(width * 0.18, height * 0.52),
      Offset(width * 0.82, height * 0.52),
    ];
    final baseSize = min(width, height) * 0.034;

    for (int i = 0; i < stickers.length; i++) {
      final basePosition = positions[i % positions.length];
      final ring = i ~/ positions.length;
      final size = (baseSize * (1.0 - min(0.12, ring * 0.04)))
          .clamp(28.0, 56.0)
          .toDouble();
      final position = basePosition.translate(0, ring * 8.0);
      final rotation = i.isEven ? -0.08 : 0.08;

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
      final stickerImage = stickerImages[stickers[i]];
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

  // Mỗi lượt render sở hữu ảnh riêng; không giữ native image suốt phiên hoặc
  // dispose nhầm ảnh của lượt xuất đang chạy song song.
  static Future<Map<String, ui.Image>> _loadStickerImages(List<String> stickers) async {
    final images = <String, ui.Image>{};
    for (final sticker in stickers.where((value) => value.startsWith('assets/')).toSet()) {
      ui.Codec? codec;
      try {
        final bytes = await rootBundle.load(sticker);
        codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        images[sticker] = (await codec.getNextFrame()).image;
      } catch (error) {
        debugPrint('[Collage] Không đọc được sticker: $error');
      } finally {
        codec?.dispose();
      }
    }
    return images;
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
      final double normalizedX = transform.offset.dx
          .clamp(-1.0, 1.0)
          .toDouble();
      final double normalizedY = transform.offset.dy
          .clamp(-1.0, 1.0)
          .toDouble();
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
    final clipRRect = RRect.fromRectAndRadius(
      imageRect,
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(clipRRect);

    _drawImageWithTransform(canvas, img, imageRect, transform);

    canvas.restore();

    canvas.drawRRect(
      clipRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = Colors.white.withValues(alpha: 0.52),
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
    final matteRect = imageRect.inflate(7);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        matteRect.shift(const Offset(0, 8)),
        Radius.circular(radius + 7),
      ),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(matteRect, Radius.circular(radius + 7)),
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    _drawImageSurfaceWithTransform(
      canvas,
      img,
      imageRect,
      radius: radius,
      transform: transform,
    );
  }

  static _CollagePage _layoutPage(
    String title,
    String style,
    CollageDecor decor,
    CollageRenderOptions options,
  ) {
    final ratio =
        options.safeOutputAspectRatio ??
        (style == 'story'
            ? 9 / 16
            : style == 'poster'
            ? 4 / 3
            : 0.8);
    final width = max(1080.0, 720.0 * ratio);
    final height = width / ratio;
    final scale = min(width / 1080, height / 1350).clamp(0.62, 1.2).toDouble();
    final inset = width * 0.06 / options.safePhotoScale;
    final heading = title.trim().isNotEmpty
        ? title
        : UiCopy.text('copy_6acd69a50487');
    return _CollagePage(
      size: Size(width, height),
      photoArea: Rect.fromLTRB(
        inset,
        _headerHeight(width, heading, decor, typeScale: scale) + 10 * scale,
        width - inset,
        height - _footerHeight(width, decor, typeScale: scale) - 10 * scale,
      ),
      typeScale: scale,
      gap: 22 * scale / options.safePhotoScale,
      heading: heading,
    );
  }

  static int _gridColumns(
    Rect area,
    int count,
    double gap, {
    double preferredRatio = 1,
  }) {
    var columns = 1;
    var bestScore = double.infinity;
    for (var candidate = 1; candidate <= count; candidate++) {
      final rows = (count / candidate).ceil();
      final cellWidth = (area.width - gap * (candidate - 1)) / candidate;
      final cellHeight = (area.height - gap * (rows - 1)) / rows;
      if (cellWidth <= 0 || cellHeight <= 0) continue;
      final empty = (candidate * rows - count) / count;
      final score =
          log(cellWidth / cellHeight / preferredRatio).abs() + empty * 0.65;
      if (score < bestScore) {
        bestScore = score;
        columns = candidate;
      }
    }
    return columns;
  }

  static List<Rect> _gridRects(
    Rect area,
    int count,
    double gap, {
    double preferredRatio = 1,
  }) {
    if (count == 0) return const [];
    final columns = _gridColumns(
      area,
      count,
      gap,
      preferredRatio: preferredRatio,
    );
    final rows = (count / columns).ceil();
    final cellHeight = (area.height - gap * (rows - 1)) / rows;
    final rects = <Rect>[];
    for (var row = 0; row < rows; row++) {
      final items = min(columns, count - row * columns);
      final cellWidth = (area.width - gap * (items - 1)) / items;
      for (var column = 0; column < items; column++) {
        rects.add(
          Rect.fromLTWH(
            area.left + column * (cellWidth + gap),
            area.top + row * (cellHeight + gap),
            cellWidth,
            cellHeight,
          ),
        );
      }
    }
    return rects;
  }

  static List<Rect> _masonryRects(
    Rect area,
    List<ui.Image> images,
    double gap,
  ) {
    final columns = _gridColumns(area, images.length, gap);
    final width = (area.width - gap * (columns - 1)) / columns;
    final assignments = List.generate(columns, (_) => <int>[]);
    final totals = List<double>.filled(columns, 0);
    final heights = <double>[];
    for (var index = 0; index < images.length; index++) {
      final ratio = (images[index].width / images[index].height)
          .clamp(0.6, 1.6)
          .toDouble();
      // Một nhịp cao/thấp nhẹ giữ mẫu so le rõ cả khi ảnh cùng tỉ lệ.
      final height = width / ratio * (index.isEven ? 1.1 : 0.9);
      heights.add(height);
      var column = 0;
      for (var candidate = 1; candidate < columns; candidate++) {
        if (totals[candidate] < totals[column]) column = candidate;
      }
      assignments[column].add(index);
      totals[column] += height + gap;
    }
    final rects = List<Rect>.filled(images.length, Rect.zero);
    for (var column = 0; column < columns; column++) {
      final indexes = assignments[column];
      final photoHeight = indexes.fold<double>(0, (sum, i) => sum + heights[i]);
      final factor = (area.height - gap * (indexes.length - 1)) / photoHeight;
      var y = area.top;
      for (final index in indexes) {
        final height = heights[index] * factor;
        rects[index] = Rect.fromLTWH(
          area.left + column * (width + gap),
          y,
          width,
          height,
        );
        y += height + gap;
      }
    }
    return rects;
  }

  static List<Rect> _featuredRects(
    Rect area,
    int count,
    double gap, {
    required bool story,
  }) {
    if (count == 1) return [area];
    final vertical = area.width / area.height < (story ? 1.5 : 0.62);
    final share = story ? (count > 8 ? 0.36 : 0.5) : (count > 8 ? 0.43 : 0.58);
    final Rect lead;
    final Rect rest;
    if (vertical) {
      final split = area.top + area.height * share;
      lead = Rect.fromLTRB(area.left, area.top, area.right, split - gap / 2);
      rest = Rect.fromLTRB(area.left, split + gap / 2, area.right, area.bottom);
    } else {
      final split = area.left + area.width * share;
      lead = Rect.fromLTRB(area.left, area.top, split - gap / 2, area.bottom);
      rest = Rect.fromLTRB(split + gap / 2, area.top, area.right, area.bottom);
    }
    return [lead, ..._gridRects(rest, count - 1, gap)];
  }

  static Rect _fitRotatedCard(Rect slot, double ratio, double angle) {
    final c = cos(angle).abs();
    final s = sin(angle).abs();
    final width = min(
      slot.width / (c + s / ratio),
      slot.height / (s + c / ratio),
    );
    return Rect.fromCenter(
      center: slot.center,
      width: width,
      height: width / ratio,
    );
  }

  static CollagePhotoTransform? _transformAt(
    CollageRenderOptions options,
    int index,
  ) {
    return index < options.photoTransforms.length
        ? options.photoTransforms[index]
        : null;
  }

  static void _drawPolaroidPhoto(
    Canvas canvas,
    ui.Image image,
    Rect card,
    int index,
    CollageDecor decor,
    double scale,
    CollagePhotoTransform? transform,
  ) {
    final paper = RRect.fromRectAndRadius(card, Radius.circular(6 * scale));
    canvas.drawShadow(
      Path()..addRRect(paper),
      Colors.black.withValues(alpha: 0.16),
      9 * scale,
      false,
    );
    canvas.drawRRect(paper, Paint()..color = Colors.white);
    final edge = card.width * 0.038;
    final captionHeight = card.height * 0.13;
    _drawImageSurfaceWithTransform(
      canvas,
      image,
      Rect.fromLTRB(
        card.left + edge,
        card.top + edge,
        card.right - edge,
        card.bottom - captionHeight,
      ),
      radius: 3 * scale,
      transform: transform,
    );
    final captionY = card.bottom - captionHeight / 2;
    canvas.drawLine(
      Offset(card.left + edge * 1.5, captionY),
      Offset(card.left + card.width * 0.28, captionY),
      Paint()
        ..color = decor.secondary.withValues(alpha: 0.5)
        ..strokeWidth = scale,
    );
    _drawCenteredTextInRect(
      canvas,
      (index + 1).toString().padLeft(2, '0'),
      Rect.fromCenter(
        center: Offset(card.right - edge * 2, captionY),
        width: card.width * 0.12,
        height: captionHeight * 0.8,
      ),
      decor.primary.withValues(alpha: 0.6),
      min(16 * scale, captionHeight * 0.45),
      isBold: false,
      letterSpacing: scale,
    );
  }

  static void _drawHeartPhotos(
    Canvas canvas,
    List<ui.Image> images,
    _CollagePage page,
    CollageRenderOptions options, {
    Rect? photoArea,
  }) {
    final area = photoArea ?? page.photoArea;
    final width = min(area.width, area.height * 1.06);
    final bounds = Rect.fromCenter(
      center: area.center,
      width: width,
      height: width / 1.06,
    );
    Offset point(double x, double y) =>
        Offset(bounds.left + bounds.width * x, bounds.top + bounds.height * y);
    final heart = Path()..moveTo(point(0.5, 0.17).dx, point(0.5, 0.17).dy);
    void curve(
      double x1,
      double y1,
      double x2,
      double y2,
      double x3,
      double y3,
    ) {
      final a = point(x1, y1);
      final b = point(x2, y2);
      final c = point(x3, y3);
      heart.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    curve(0.2, -0.08, 0, 0.15, 0, 0.37);
    curve(0, 0.62, 0.26, 0.82, 0.5, 1);
    curve(0.74, 0.82, 1, 0.62, 1, 0.37);
    curve(1, 0.15, 0.8, -0.08, 0.5, 0.17);
    heart.close();
    canvas.drawShadow(
      heart,
      Colors.black.withValues(alpha: 0.14),
      10 * page.typeScale,
      false,
    );
    canvas.drawPath(heart, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(heart);

    // Phủ kín hình tim; số ảnh ít vẫn giữ được silhouette, không rải ảnh một góc.
    final rows = max(1, (sqrt(images.length) * 0.85).round());
    final counts = List<int>.filled(rows, 1);
    final weights = List<double>.generate(rows, (row) {
      if (rows <= 2) return 1;
      final y = (row + 0.5) / rows;
      return y < 0.3 ? 0.9 : 1.15 - 0.85 * y;
    });
    for (var placed = rows; placed < images.length; placed++) {
      var row = 0;
      for (var candidate = 1; candidate < rows; candidate++) {
        if ((counts[candidate] + 1) / weights[candidate] <
            (counts[row] + 1) / weights[row]) {
          row = candidate;
        }
      }
      counts[row]++;
    }
    var index = 0;
    final rowHeight = bounds.height / rows;
    for (var row = 0; row < rows; row++) {
      final cellWidth = bounds.width / counts[row];
      for (var column = 0; column < counts[row]; column++) {
        final rect = Rect.fromLTWH(
          bounds.left + column * cellWidth,
          bounds.top + row * rowHeight,
          cellWidth,
          rowHeight,
        ).deflate(page.gap * 0.22);
        _drawImageWithTransform(
          canvas,
          images[index],
          rect,
          _transformAt(options, index),
        );
        index++;
      }
    }
    canvas.restore();
    canvas.drawPath(
      heart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9 * page.typeScale
        ..color = Colors.white,
    );
  }

  static Size _drawCollagePage(
    Canvas canvas,
    List<ui.Image> images,
    String title,
    String style,
    CollageDecor decor,
    CollageRenderOptions options,
    Map<String, ui.Image> stickerImages,
  ) {
    final page = _layoutPage(title, style, decor, options);
    _drawBackground(canvas, page.size.width, page.size.height, decor, options);
    _drawHeader(
      canvas,
      page.size.width,
      page.heading,
      decor,
      typeScale: page.typeScale,
    );
    if (style == 'heart') {
      final area = page.photoArea;
      if (area.width / area.height > 1.5 && images.length > 1) {
        final lead = Rect.fromLTWH(
          area.left,
          area.top,
          min(area.height * 1.06, area.width * 0.44),
          area.height,
        );
        _drawHeartPhotos(
          canvas,
          [images.first],
          page,
          options,
          photoArea: lead,
        );
        final rest = Rect.fromLTRB(
          lead.right + page.gap,
          area.top,
          area.right,
          area.bottom,
        );
        final rects = _gridRects(rest, images.length - 1, page.gap);
        for (var index = 1; index < images.length; index++) {
          _drawFrameImage(
            canvas,
            images[index],
            rects[index - 1],
            decor,
            radius: 14 * page.typeScale,
            transform: _transformAt(options, index),
          );
        }
      } else {
        _drawHeartPhotos(canvas, images, page, options);
      }
    } else {
      final List<Rect> rects;
      switch (style) {
        case 'masonry':
          rects = _masonryRects(page.photoArea, images, page.gap);
          break;
        case 'story':
        case 'poster':
          rects = _featuredRects(
            page.photoArea,
            images.length,
            page.gap,
            story: style == 'story',
          );
          break;
        default:
          rects = _gridRects(
            page.photoArea,
            images.length,
            page.gap,
            preferredRatio: style == 'polaroid' ? 0.84 : 1,
          );
      }
      final random = _layoutRandom(
        options,
        style == 'polaroid' ? 0x1205 : 0x1260,
      );
      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        final slot = rects[index];
        final transform = _transformAt(options, index);
        if (style == 'polaroid' || style == 'scatter') {
          final angle =
              (index.isEven ? -1 : 1) * (0.018 + random.nextDouble() * 0.035);
          final ratio = style == 'polaroid'
              ? 0.84
              : (image.width / image.height).clamp(0.6, 1.6).toDouble();
          final card = _fitRotatedCard(
            slot.deflate(page.gap * 0.3),
            ratio,
            angle,
          );
          canvas.save();
          canvas.translate(card.center.dx, card.center.dy);
          canvas.rotate(angle);
          final local = Rect.fromCenter(
            center: Offset.zero,
            width: card.width,
            height: card.height,
          );
          if (style == 'polaroid') {
            _drawPolaroidPhoto(
              canvas,
              image,
              local,
              index,
              decor,
              page.typeScale,
              transform,
            );
          } else {
            _drawFrameImage(
              canvas,
              image,
              local,
              decor,
              radius: 10 * page.typeScale,
              transform: transform,
            );
          }
          canvas.restore();
        } else {
          _drawFrameImage(
            canvas,
            image,
            slot,
            decor,
            radius: 14 * page.typeScale,
            transform: transform,
          );
        }
      }
    }
    _drawFooter(
      canvas,
      page.size.width,
      page.size.height,
      decor,
      typeScale: page.typeScale,
    );
    _drawSelectedStickers(
      canvas,
      page.size.width,
      page.size.height,
      options.stickers,
      stickerImages,
      decor,
      options,
    );
    return page.size;
  }
}
