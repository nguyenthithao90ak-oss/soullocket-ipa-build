import 'dart:typed_data';

import 'package:image/image.dart' as img;

class CustomMoodStickerImage {
  const CustomMoodStickerImage(this.bytes, this.contentType, this.extension);

  final Uint8List bytes;
  final String contentType;
  final String extension;

  static const maxDimension = 512;
  static const maxBytes = 500 * 1024;
  static const maxInputBytes = 15 * 1024 * 1024;

  static CustomMoodStickerImage encode(Uint8List bytes) {
    try {
      return _encode(bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('invalid-image');
    }
  }

  static CustomMoodStickerImage _encode(Uint8List bytes) {
    if (bytes.length < 16) throw const FormatException('invalid-image');
    if (bytes.length > maxInputBytes) {
      throw const FormatException('image-too-large');
    }
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null) throw const FormatException('invalid-image');
    if (info.width * info.height > 24000000) {
      throw const FormatException('image-too-large');
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw const FormatException('invalid-image');
    var image = img.bakeOrientation(decoded);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxDimension) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxDimension : null,
        height: image.height > image.width ? maxDimension : null,
        interpolation: img.Interpolation.average,
      );
    }
    final transparent = image.hasAlpha;
    for (var attempt = 0; attempt < 5; attempt++) {
      final clean = img.Image(
        width: image.width,
        height: image.height,
        numChannels: transparent ? 4 : 3,
      );
      img.compositeImage(clean, image, blend: img.BlendMode.direct);
      final encoded = transparent
          ? img.encodePng(clean)
          : img.encodeJpg(clean, quality: 80);
      if (encoded.length <= maxBytes) {
        return CustomMoodStickerImage(
          Uint8List.fromList(encoded),
          transparent ? 'image/png' : 'image/jpeg',
          transparent ? 'png' : 'jpg',
        );
      }
      image = img.copyResize(
        image,
        width: (image.width * 0.8).round().clamp(1, maxDimension),
        height: (image.height * 0.8).round().clamp(1, maxDimension),
        interpolation: img.Interpolation.average,
      );
    }
    throw const FormatException('image-too-large');
  }
}
