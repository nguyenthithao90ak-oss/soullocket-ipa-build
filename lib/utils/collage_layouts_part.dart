part of 'collage_generator.dart';

Size _drawGridCollage(
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

Size _drawMasonryCollage(
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

Size _drawPolaroidCollage(
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

Size _drawScatterCollage(
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

Size _drawStoryCollage(
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

Size _drawPosterCollage(
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

Size _drawHeartCollage(
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
  // Phân bố đều dọc đường cong trái tim để giữ rõ hình
  final steps = max(n, 24);
  final double stepSize = (pi * 2.0) / steps;
  final double startOffset = random.nextDouble() * stepSize;

  Offset getHeartPoint(
      double t, double scale, double offsetX, double offsetY) {
    final double x = 16 * pow(sin(t), 3).toDouble();
    final double y =
        13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t);
    return Offset(x * scale + offsetX, -y * scale + offsetY);
  }

  for (int i = 0; i < n; i++) {
    canvas.save();
    // Phân bố đều theo i, thêm nhiễu nhẹ cho tự nhiên
    final double baseT = startOffset + i * stepSize;
    final double t = baseT + (random.nextDouble() - 0.5) * stepSize * 0.3;
    // Ảnh phía dưới (đáy tim) to hơn, phía trên nhỏ hơn
    final double normalizedPos = (sin(t) + 1.0) / 2.0;
    final double photoScale = 28.0 + normalizedPos * 10.0;
    final Offset pt = getHeartPoint(
      t,
      photoScale,
      contentWidth / 2,
      contentHeight / 2 + 180,
    );

    final double jx = (random.nextDouble() - 0.5) * 16;
    final double jy = (random.nextDouble() - 0.5) * 16;

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
