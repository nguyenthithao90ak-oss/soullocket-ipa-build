import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_cache_manager.dart';

class WallpaperLuminanceService {
  static final WallpaperLuminanceService instance =
      WallpaperLuminanceService._internal();

  WallpaperLuminanceService._internal();

  final Map<String, bool> _cache = <String, bool>{};
  final Set<String> _inFlight = <String>{};
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  bool? getCachedIsLight(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return null;
    return _cache[normalized];
  }

  void analyzeWallpaper(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty || _cache.containsKey(normalized)) return;

    final ImageProvider provider;
    if (normalized.startsWith('http://') ||
        normalized.startsWith('https://')) {
      provider = CachedNetworkImageProvider(
        normalized,
        cacheManager: AppCacheManager.instance,
      );
    } else if (kIsWeb) {
      provider = NetworkImage(normalized);
    } else {
      provider = FileImage(File(normalized));
    }
    analyzeProvider(normalized, provider);
  }

  /// Phân tích chính provider đang dùng để render nền, tránh tải lại ảnh R2
  /// bằng URL gốc chưa ký. [key] là URL nền ổn định dùng để tra cache.
  void analyzeProvider(String key, ImageProvider provider) {
    final normalized = key.trim();
    if (normalized.isEmpty ||
        _cache.containsKey(normalized) ||
        !_inFlight.add(normalized)) {
      return;
    }
    unawaited(_analyze(normalized, provider));
  }

  Future<bool> _analyze(String url, ImageProvider provider) async {
    try {
      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      final Completer<ui.Image> completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (dynamic error, StackTrace? stackTrace) {
          completer.completeError(error);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);

      final ui.Image image;
      try {
        image = await completer.future.timeout(const Duration(seconds: 4));
      } finally {
        // Timeout/error không được để listener giữ stream sống lâu hơn cần
        // thiết; callback thành công cũng có thể đã tự remove trước đó.
        stream.removeListener(listener);
      }

      // Thu nhỏ về 16x16 để tính toán độ sáng cực nhanh
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..filterQuality = .low,
      );
      final picture = recorder.endRecording();
      final smallImg = await picture.toImage(16, 16);
      final byteData = await smallImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      smallImg.dispose();

      if (byteData == null) {
        _cache[url] = true;
        changeNotifier.value++;
        return true;
      }

      final buffer = byteData.buffer.asUint8List();
      double totalLuminance = 0;
      int count = 0;

      for (int i = 0; i < buffer.length; i += 4) {
        final r = buffer[i];
        final g = buffer[i + 1];
        final b = buffer[i + 2];
        final a = buffer[i + 3];

        if (a > 50) {
          final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
          totalLuminance += lum;
          count++;
        }
      }

      final avgLuminance = count > 0 ? (totalLuminance / count) : 0.5;
      final isLight = avgLuminance >= 0.48;

      _cache[url] = isLight;
      changeNotifier.value++;
      return isLight;
    } catch (_) {
      _cache[url] = true;
      changeNotifier.value++;
      return true;
    } finally {
      _inFlight.remove(url);
    }
  }
}
