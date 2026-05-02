import 'dart:typed_data';
import 'package:blurhash/blurhash.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

class BlurHashHelper {
  /// Generates a BlurHash from an image file path.
  /// Compresses the image first to a very small size to speed up generation.
  static Future<String?> generateBlurHash(String filePath) async {
    try {
      // 1. Compress image to a very small version (e.g. 32x32) for BlurHash
      final Uint8List? smallImageBytes = await FlutterImageCompress.compressWithFile(
        filePath,
        minWidth: 32,
        minHeight: 32,
        quality: 80,
      );

      if (smallImageBytes == null) return null;

      // 2. Decode bytes to get pixel data
      final img.Image? image = img.decodeImage(smallImageBytes);
      if (image == null) return null;

      // 3. Generate BlurHash
      final String hash = await BlurHash.encode(image, 4, 3);
      return hash;
    } catch (e) {
      print('Error generating BlurHash: $e');
      return null;
    }
  }

  /// Generates BlurHash from raw bytes
  static Future<String?> generateBlurHashFromBytes(Uint8List bytes) async {
    try {
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize for performance if needed
      final img.Image smallImage = img.copyResize(image, width: 32, height: 32);
      
      final String hash = await BlurHash.encode(smallImage, 4, 3);
      return hash;
    } catch (e) {
      print('Error generating BlurHash from bytes: $e');
      return null;
    }
  }
}
