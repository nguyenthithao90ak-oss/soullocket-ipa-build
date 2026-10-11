import 'dart:io';

import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

import 'storage_upload_queue.dart';

typedef StorageVideoCompressor = Future<String?> Function(String path);

class StorageVideoOptimizationResult {
  final XFile videoFile;
  final bool isOptimized;
  final double sizeMb;
  final String? warningMessage;
  final int originalSizeBytes;
  final int savedBytes;
  final String? temporaryPath;

  const StorageVideoOptimizationResult({
    required this.videoFile,
    required this.isOptimized,
    required this.sizeMb,
    this.warningMessage,
    this.originalSizeBytes = 0,
    this.savedBytes = 0,
    this.temporaryPath,
  });
}

class StorageVideoOptimizer {
  const StorageVideoOptimizer({this.compressor});

  final StorageVideoCompressor? compressor;

  static final _compressionQueue = StorageUploadQueue();

  /// Giới hạn dung lượng Video tối đa khuyến nghị (35 MB)
  static const double maxRecommendedVideoSizeMb = 35.0;

  /// Giới hạn tối đa cứng cho video tải lên (50 MB)
  static const double maxHardVideoSizeMb = 50.0;

  static const int targetFrameRate = 30;
  static const Duration compressionTimeout = Duration(minutes: 5);

  /// Kiểm tra và kiểm soát an toàn dung lượng video trước khi tải lên kho R2/Storage
  static Future<StorageVideoOptimizationResult> prepareVideoForUpload(
    XFile file, {
    StorageVideoCompressor? compressor,
  }) => StorageVideoOptimizer(compressor: compressor).prepare(file);

  Future<StorageVideoOptimizationResult> prepare(XFile file) async {
    final originalBytes = await file.length();
    if (kIsWeb || file.path.isEmpty || originalBytes <= 0) {
      return _result(file, originalBytes);
    }

    String? outputPath;
    try {
      outputPath = await _compressionQueue.run(
        () => (compressor ?? _compressNative)(
          file.path,
        ).timeout(compressionTimeout),
      );
      if (outputPath != null) {
        final output = File(outputPath);
        final outputBytes = await output.exists() ? await output.length() : 0;
        if (output.path != file.path &&
            outputBytes > 0 &&
            outputBytes < originalBytes) {
          final optimized = XFile(output.path, mimeType: 'video/mp4');
          return _result(
            optimized,
            outputBytes,
            originalSizeBytes: originalBytes,
            temporaryPath: output.path,
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[StorageVideoOptimizer] Compression fallback: ${e.runtimeType}',
      );
    }

    if (outputPath != null && outputPath != file.path) {
      try {
        final output = File(outputPath);
        if (await output.exists()) await output.delete();
      } catch (_) {}
    }

    return _result(file, originalBytes);
  }

  Future<String?> _compressNative(String path) async {
    try {
      final info = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.Res1920x1080Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: targetFrameRate,
      ).timeout(compressionTimeout);
      return info?.file?.path;
    } catch (_) {
      try {
        await VideoCompress.cancelCompression();
      } finally {
        // ignore: invalid_use_of_protected_member
        VideoCompress.setProcessingStatus(false);
      }
      return null;
    }
  }

  StorageVideoOptimizationResult _result(
    XFile file,
    int bytes, {
    int? originalSizeBytes,
    String? temporaryPath,
  }) {
    final original = originalSizeBytes ?? bytes;
    final sizeMb = bytes / (1024 * 1024);
    if (sizeMb > maxHardVideoSizeMb) {
      throw UiCopyException('copy_6d8531b0bda3', {
        'value1': sizeMb.toStringAsFixed(1),
        'value2': maxHardVideoSizeMb.toInt(),
      });
    }
    String? warning;
    if (sizeMb > maxRecommendedVideoSizeMb) {
      warning = UiCopy.text('copy_9da52327c5ce', {
        'value1': sizeMb.toStringAsFixed(1),
      });
      debugPrint('[StorageVideoOptimizer] Warning: $warning');
    }
    return StorageVideoOptimizationResult(
      videoFile: file,
      isOptimized: bytes < original,
      sizeMb: sizeMb,
      warningMessage: warning,
      originalSizeBytes: original,
      savedBytes: (original - bytes).clamp(0, original),
      temporaryPath: temporaryPath,
    );
  }
}
