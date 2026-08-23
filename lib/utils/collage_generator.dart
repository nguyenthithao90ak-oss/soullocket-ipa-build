import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'collage_layouts_part.dart';
part 'collage_rendering_part.dart';

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
    return byteData!.buffer.asUint8List();
  }
}
