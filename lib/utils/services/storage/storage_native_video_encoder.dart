import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageVideoSourceInfo {
  const StorageVideoSourceInfo({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.durationMs,
    required this.hasAudio,
  });

  factory StorageVideoSourceInfo.fromMap(Map<dynamic, dynamic> value) {
    num number(String key) => value[key] is num ? value[key] as num : 0;
    return StorageVideoSourceInfo(
      width: number('width').toInt(),
      height: number('height').toInt(),
      frameRate: number('frameRate').toDouble(),
      durationMs: number('durationMs').toDouble(),
      hasAudio: value['hasAudio'] == true,
    );
  }

  /// Kích thước đã áp dụng hướng xoay của camera, không phải kích thước raw.
  final int width;
  final int height;
  final double frameRate;
  final double durationMs;
  final bool hasAudio;
}

class StorageVideoEncodingProfile {
  const StorageVideoEncodingProfile({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.videoBitrate,
    required this.audioBitrate,
  });

  static const int maxFrameRate = 30;
  static const int livePhotoVideoBitrate = 3000000;
  static const int standardVideoBitrate = 5000000;

  factory StorageVideoEncodingProfile.forSource(
    StorageVideoSourceInfo source, {
    required bool isLivePhoto,
  }) {
    if (source.width < 2 ||
        source.height < 2 ||
        !source.durationMs.isFinite ||
        source.durationMs <= 0 ||
        !source.frameRate.isFinite ||
        source.frameRate < 0) {
      throw const FormatException('Invalid video dimensions or duration');
    }
    final longEdge = isLivePhoto ? 1280 : 1920;
    final shortEdge = isLivePhoto ? 720 : 1080;
    final scale = math.min(
      1.0,
      math.min(
        longEdge / math.max(source.width, source.height),
        shortEdge / math.min(source.width, source.height),
      ),
    );
    int even(double size) => math.max(2, (size / 2).floor() * 2);
    final width = even(source.width * scale);
    final height = even(source.height * scale);
    final fps = source.frameRate > 0
        ? math.min(source.frameRate, maxFrameRate.toDouble())
        : maxFrameRate.toDouble();
    final baseBitrate = isLivePhoto
        ? livePhotoVideoBitrate
        : standardVideoBitrate;
    // Giữ ngân sách cho chi tiết; video nhỏ/ít khung hình không cần bitrate
    // của cả khung 720p/1080p. Không phóng lớn nguồn nhỏ để giả tăng độ nét.
    final pixelRatio = width * height / (longEdge * shortEdge);
    final fpsRatio = (fps / maxFrameRate).clamp(0.5, 1.0);
    final bitrate = (baseBitrate * pixelRatio * fpsRatio).round().clamp(
      400000,
      baseBitrate,
    );
    return StorageVideoEncodingProfile(
      width: width,
      height: height,
      frameRate: fps,
      videoBitrate: bitrate,
      audioBitrate: isLivePhoto ? 96000 : 128000,
    );
  }

  final int width;
  final int height;
  final double frameRate;
  final int videoBitrate;
  final int audioBitrate;

  bool canKeepOriginal(StorageVideoSourceInfo source, int bytes) {
    if (bytes <= 0 || source.frameRate <= 0) return false;
    final sourceLongEdge = math.max(source.width, source.height);
    final sourceShortEdge = math.min(source.width, source.height);
    return sourceLongEdge <= math.max(width, height) &&
        sourceShortEdge <= math.min(width, height) &&
        source.frameRate <= maxFrameRate &&
        bytes * 8000 / source.durationMs <=
            videoBitrate + (source.hasAudio ? audioBitrate : 0);
  }
}

/// Cầu nối riêng vì preset của video_compress không nhận bitrate.
class StorageNativeVideoEncoder {
  const StorageNativeVideoEncoder({
    this.channel = const MethodChannel('soullocket/memory_video_encoder'),
    this.temporaryDirectory,
    this.compressionTimeout = const Duration(minutes: 5),
    this.inspectionTimeout = const Duration(seconds: 20),
  });

  final MethodChannel channel;
  final Future<Directory> Function()? temporaryDirectory;
  final Duration compressionTimeout;
  final Duration inspectionTimeout;
  static int _sequence = 0;

  Future<String?> compress(
    String sourcePath, {
    required bool isLivePhoto,
  }) async {
    final requestId = '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
    Map<dynamic, dynamic>? metadata;
    try {
      metadata = await channel
          .invokeMapMethod<dynamic, dynamic>('inspectVideo', {
            'path': sourcePath,
            'requestId': requestId,
          })
          .timeout(inspectionTimeout);
    } on TimeoutException {
      await _cancel('cancelInspection', requestId);
      rethrow;
    }
    if (metadata == null) throw const FormatException('Video metadata missing');
    final source = StorageVideoSourceInfo.fromMap(metadata);
    final profile = StorageVideoEncodingProfile.forSource(
      source,
      isLivePhoto: isLivePhoto,
    );
    if (!isLivePhoto &&
        profile.canKeepOriginal(source, await File(sourcePath).length())) {
      return sourcePath;
    }

    final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
    final outputPath = p.join(directory.path, 'sl_memory_video_$requestId.mp4');
    var accepted = false;
    try {
      final result = await channel
          .invokeMethod<String>('compressVideo', {
            'requestId': requestId,
            'path': sourcePath,
            'outputPath': outputPath,
            'width': profile.width,
            'height': profile.height,
            'frameRate': profile.frameRate,
            'videoBitrate': profile.videoBitrate,
            'audioBitrate': profile.audioBitrate,
            'includeAudio': source.hasAudio,
          })
          .timeout(compressionTimeout);
      if (result == null || !p.equals(result, outputPath)) {
        throw const FormatException('Unexpected video output');
      }
      accepted = true;
      return outputPath;
    } on TimeoutException {
      // Hủy tác vụ native trước khi hàng đợi cho file kế tiếp chạy.
      await _cancel('cancelCompression', requestId);
      rethrow;
    } finally {
      if (!accepted) {
        try {
          final output = File(outputPath);
          if (await output.exists()) await output.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _cancel(String method, String requestId) async {
    try {
      await channel
          .invokeMethod<void>(method, {'requestId': requestId})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Native vẫn giữ guard busy tới khi worker cũ đã dừng.
    }
  }
}
