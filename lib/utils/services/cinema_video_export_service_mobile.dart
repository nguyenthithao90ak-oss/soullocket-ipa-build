import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'cinema_video_export_contract.dart';

CinemaVideoExportService createCinemaVideoExportService() =>
    const _MobileCinemaVideoExportService();

class _MobileCinemaVideoExportService implements CinemaVideoExportService {
  const _MobileCinemaVideoExportService();

  @override
  bool get isSupported => true;

  @override
  Future<CinemaVideoExportResult> exportReel({
    required String exportId,
    required List<CinemaVideoFrame> frames,
    required Duration frameDuration,
    required CinemaVideoOverlayConfig overlay,
    CinemaVideoProgressCallback? onProgress,
  }) async {
    if (frames.isEmpty) {
      throw ArgumentError('Không có ảnh để tạo video.');
    }

    onProgress?.call(
      const CinemaVideoExportProgress(
        label: 'Đang chuẩn bị ảnh...',
        value: 0.08,
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final safeId = exportId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final workDir = Directory('${tempDir.path}/cinema_video_$safeId');
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
    await workDir.create(recursive: true);

    final imageListPath = '${workDir.path}/frames.txt';
    final outputPath = '${workDir.path}/soul_locket_$safeId.mp4';
    final frameSeconds = frameDuration.inMilliseconds / 1000.0;
    final listBuffer = StringBuffer();
    String? lastFramePath;

    for (var index = 0; index < frames.length; index += 1) {
      final frame = frames[index];
      final cachedFile = await DefaultCacheManager().getSingleFile(frame.imageUrl);
      final extension = _extensionFor(cachedFile.path);
      final framePath = '${workDir.path}/frame_${index.toString().padLeft(3, '0')}$extension';
      lastFramePath = framePath;
      await cachedFile.copy(framePath);
      listBuffer
        ..writeln("file '${_escapeConcatPath(framePath)}'")
        ..writeln('duration ${frameSeconds.toStringAsFixed(3)}');
      onProgress?.call(
        CinemaVideoExportProgress(
          label: 'Đang tải ảnh ${index + 1}/${frames.length}...',
          value: 0.1 + ((index + 1) / frames.length) * 0.28,
        ),
      );
    }
    if (lastFramePath != null) {
      listBuffer.writeln("file '${_escapeConcatPath(lastFramePath)}'");
    }
    await File(imageListPath).writeAsString(listBuffer.toString());

    onProgress?.call(
      const CinemaVideoExportProgress(
        label: 'Đang dựng video MP4...',
        value: 0.45,
      ),
    );

    final width = overlay.outputSize.width.round();
    final height = overlay.outputSize.height.round();
    final fps = overlay.qualityPreset.fps;
    final crf = overlay.qualityPreset.crfValue;
    final command = <String>[
      '-y',
      '-f concat',
      '-safe 0',
      '-i "${_escapeCommandPath(imageListPath)}"',
      '-vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:black,format=yuv420p"',
      '-r $fps',
      '-c:v libx264',
      '-preset veryfast',
      '-crf $crf',
      '-movflags +faststart',
      '"${_escapeCommandPath(outputPath)}"',
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = (await session.getAllLogsAsString())?.trim() ?? '';
      throw Exception(logs.isEmpty ? 'Không thể tạo video.' : logs);
    }

    final outputFile = File(outputPath);
    final outputSize = await outputFile.length();
    onProgress?.call(
      const CinemaVideoExportProgress(
        label: 'Video đã sẵn sàng.',
        value: 1,
      ),
    );

    return CinemaVideoExportResult(
      outputPath: outputPath,
      frameCount: frames.length,
      duration: Duration(
        milliseconds: (frames.length * frameDuration.inMilliseconds),
      ),
      outputSize: overlay.outputSize,
      estimatedFileSizeBytes: outputSize,
    );
  }

  String _extensionFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  String _escapeConcatPath(String path) => path.replaceAll("'", r"'\''");

  String _escapeCommandPath(String path) => path.replaceAll('"', r'\"');
}
