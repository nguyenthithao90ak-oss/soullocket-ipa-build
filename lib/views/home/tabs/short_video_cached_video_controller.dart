import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../../../utils/app_cache_manager.dart';

/// Tạo controller từ file cache trên nền tảng có hệ thống file.
///
/// Bản web dùng implementation thay thế để tránh kéo dart:io vào bundle.
Future<VideoPlayerController?> createCachedVideoController(
  String mediaUrl, {
  BaseCacheManager? cacheManager,
}) async {
  final url = mediaUrl.trim();
  if (url.isEmpty) return null;
  final cache = cacheManager ?? AppCacheManager.instance;
  // Chỉ tra cứu cache ở đây; cache miss để tầng gọi phát URL ngay.
  final fileInfo = await cache
      .getFileFromCache(url)
      .timeout(const Duration(milliseconds: 400), onTimeout: () => null);
  final File? file = fileInfo?.file;
  if (file == null || !await file.exists() || await file.length() == 0) {
    return null;
  }
  return VideoPlayerController.file(file);
}
