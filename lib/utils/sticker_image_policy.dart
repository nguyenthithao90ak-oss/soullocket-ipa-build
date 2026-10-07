import 'package:flutter/painting.dart';

abstract final class StickerImagePolicy {
  static int _cellPixels(double logicalPixels, double devicePixelRatio) {
    final logical = logicalPixels.isFinite && logicalPixels > 0
        ? logicalPixels
        : 72.0;
    final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    final target = (logical * ratio).ceil().clamp(64, 4096);
    var pixels = 64;
    while (pixels < target) {
      pixels *= 2;
    }
    return pixels;
  }

  static ({int width, int height}) decodeSize({
    required Size size,
    required double devicePixelRatio,
    int columns = 1,
    int rows = 1,
  }) => (
    width: (_cellPixels(size.width, devicePixelRatio) * columns.clamp(1, 64))
        .clamp(64, 4096),
    height: (_cellPixels(size.height, devicePixelRatio) * rows.clamp(1, 64))
        .clamp(64, 4096),
  );

  static ResizeImage provider({
    required String assetPath,
    required Size size,
    required double devicePixelRatio,
    int columns = 1,
    int rows = 1,
  }) {
    final budget = decodeSize(
      size: size,
      devicePixelRatio: devicePixelRatio,
      columns: columns,
      rows: rows,
    );
    return ResizeImage(
      AssetImage(assetPath),
      width: budget.width,
      height: budget.height,
      policy: ResizeImagePolicy.fit,
    );
  }
}
