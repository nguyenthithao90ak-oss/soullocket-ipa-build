import 'dart:io';

import 'package:video_player/video_player.dart';

import '../../../utils/app_cache_manager.dart';

/// Tạo controller từ file cache trên nền tảng có hệ thống file.
///
/// Bản web dùng implementation thay thế để tránh kéo dart:io vào bundle.
Future<VideoPlayerController?> createCachedVideoController(
  String mediaUrl,
) async {
  final fileInfo = await AppCacheManager.instance.getFileFromCache(mediaUrl);
  final File file =
      fileInfo?.file ?? await AppCacheManager.instance.getSingleFile(mediaUrl);
  return VideoPlayerController.file(file);
}
