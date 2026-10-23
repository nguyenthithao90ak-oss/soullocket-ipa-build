import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef StorageImageCompressor = Future<XFile?> Function(
  String source,
  String destination, {
  required int minWidth,
  required int minHeight,
  required int quality,
});

class StoragePreparedImage {
  const StoragePreparedImage(this.file, this.contentType, {this.temporaryPath});

  final XFile file;
  final String contentType;
  final String? temporaryPath;
}

/// Nén đúng một lần từ nguồn; chỉ đổi MIME khi bản WebP thực sự nhỏ hơn.
class StorageImageOptimizer {
  const StorageImageOptimizer({this.compressor, this.temporaryDirectory});

  final StorageImageCompressor? compressor;
  final Future<Directory> Function()? temporaryDirectory;

  Future<StoragePreparedImage> prepare(
    XFile source, {
    required String contentType,
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    final original = StoragePreparedImage(source, contentType);
    if (kIsWeb ||
        source.path.isEmpty ||
        !contentType.startsWith('image/') ||
        contentType == 'image/gif') {
      return original;
    }

    String? targetPath;
    var keepOutput = false;
    try {
      final originalBytes = await source.length();
      if (originalBytes <= 0) return original;
      final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
      targetPath = p.join(
        directory.path,
        'sl_image_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}.webp',
      );
      final compressed = await (compressor ?? _compress)(
        source.path,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );
      if (compressed == null || !p.equals(compressed.path, targetPath)) {
        return original;
      }
      final compressedBytes = await compressed.length();
      if (compressedBytes <= 0 || compressedBytes >= originalBytes) {
        return original;
      }
      keepOutput = true;
      return StoragePreparedImage(
        compressed,
        'image/webp',
        temporaryPath: targetPath,
      );
    } catch (error) {
      debugPrint('[StorageImageOptimizer] Giữ ảnh gốc: ${error.runtimeType}');
      return original;
    } finally {
      if (!keepOutput && targetPath != null) {
        try {
          final temporary = File(targetPath);
          if (await temporary.exists()) await temporary.delete();
        } catch (_) {
          // Dọn cache không được biến ảnh gốc hợp lệ thành lỗi upload.
        }
      }
    }
  }

  static int _sequence = 0;

  static Future<XFile?> _compress(
    String source,
    String destination, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) => FlutterImageCompress.compressAndGetFile(
    source,
    destination,
    minWidth: minWidth,
    minHeight: minHeight,
    quality: quality,
    format: CompressFormat.webp,
  );
}
