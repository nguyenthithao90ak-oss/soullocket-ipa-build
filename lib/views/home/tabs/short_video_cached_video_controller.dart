import 'dart:io';

import 'package:flutter/foundation.dart';
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

Future<void>? _activeReplayCache;

/// Cache nền sau khi phát ổn định, tối đa một file để không tranh băng thông
/// khi người dùng lướt nhanh qua nhiều video. Không chặn lần phát đầu.
Future<void> cacheVideoForReplay(
  String mediaUrl, {
  BaseCacheManager? cacheManager,
}) async {
  final url = mediaUrl.trim();
  if (url.isEmpty || _activeReplayCache != null) return;
  final cache = cacheManager ?? AppCacheManager.instance;
  final operation = () async {
    try {
      await cache.getSingleFile(url);
    } catch (error) {
      debugPrint('[ShortVideo] Replay cache skipped: ${error.runtimeType}');
    }
  }();
  _activeReplayCache = operation;
  try {
    await operation;
  } finally {
    if (identical(_activeReplayCache, operation)) _activeReplayCache = null;
  }
}
