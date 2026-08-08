import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageVideoOptimizationResult {
  final XFile videoFile;
  final bool isOptimized;
  final double sizeMb;
  final String? warningMessage;

  const StorageVideoOptimizationResult({
    required this.videoFile,
    required this.isOptimized,
    required this.sizeMb,
    this.warningMessage,
  });
}

class StorageVideoOptimizer {
  const StorageVideoOptimizer();

  /// Giới hạn dung lượng Video tối đa khuyến nghị (35 MB)
  static const double maxRecommendedVideoSizeMb = 35.0;

  /// Giới hạn tối đa cứng cho video tải lên (50 MB)
  static const double maxHardVideoSizeMb = 50.0;

  /// Kiểm tra và kiểm soát an toàn dung lượng video trước khi tải lên kho R2/Storage
  static Future<StorageVideoOptimizationResult> prepareVideoForUpload(
    XFile file,
  ) async {
    try {
      final length = await file.length();
      final sizeMb = length / (1024 * 1024);

      if (sizeMb > maxHardVideoSizeMb) {
        throw Exception(
          'Video quá lớn (${sizeMb.toStringAsFixed(1)} MB). Vui lòng chọn video ngắn hơn hoặc dưới ${maxHardVideoSizeMb.toInt()} MB.',
        );
      }

      String? warning;
      if (sizeMb > maxRecommendedVideoSizeMb) {
        warning =
            'Video của bạn khá nặng (${sizeMb.toStringAsFixed(1)} MB). Việc tải lên có thể mất nhiều thời gian hơn.';
        debugPrint('[StorageVideoOptimizer] Warning: $warning');
      }

      return StorageVideoOptimizationResult(
        videoFile: file,
        isOptimized: sizeMb <= maxRecommendedVideoSizeMb,
        sizeMb: sizeMb,
        warningMessage: warning,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      return StorageVideoOptimizationResult(
        videoFile: file,
        isOptimized: true,
        sizeMb: 0,
      );
    }
  }
}
