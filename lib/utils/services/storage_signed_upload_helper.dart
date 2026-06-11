import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'blurhash_helper.dart';
import 'storage_upload_result.dart';

typedef StorageSignedSessionBuilder = Future<Map<String, dynamic>> Function(
  String contentType,
  String preferredFileName,
);

typedef StorageSignedResultMapper = StorageUploadResult Function(
  Map<String, dynamic> session,
);

typedef StorageContentTypeDetector = String Function(
  String fileNameOrPath, {
  String fallback,
});

typedef StorageCurrentUidEnsurer = void Function();
typedef StorageStringMapBuilder = Map<String, String> Function(Object? value);
typedef StorageSignedUploadExecutor = Future<void> Function({
  required String uploadUrl,
  required Uint8List bytes,
  required Map<String, String> headers,
  ValueChanged<double>? onProgress,
});

class StorageSignedUploadRequest {
  const StorageSignedUploadRequest({
    required this.file,
    required this.sessionBuilder,
    required this.minWidth,
    required this.minHeight,
    required this.quality,
    required this.tempPrefix,
    required this.errorLabel,
    required this.errorMessage,
    required this.mapResult,
    this.onProgress,
  });

  final XFile file;
  final StorageSignedSessionBuilder sessionBuilder;
  final int minWidth;
  final int minHeight;
  final int quality;
  final String tempPrefix;
  final String errorLabel;
  final String errorMessage;
  final StorageSignedResultMapper mapResult;
  final ValueChanged<double>? onProgress;
}

class StorageSignedUploadHelper {
  const StorageSignedUploadHelper();

  Future<T> _runWithSmoothProgress<T>(
    Future<T> Function() task,
    double start,
    double end,
    Duration expectedDuration,
    ValueChanged<double>? onProgress,
  ) async {
    if (onProgress == null) return task();

    bool isDone = false;
    final tick = const Duration(milliseconds: 50);
    double current = start;
    final step = (end - start) / (expectedDuration.inMilliseconds / tick.inMilliseconds);
    
    final timer = Timer.periodic(tick, (t) {
      if (isDone) {
        t.cancel();
        return;
      }
      current += step;
      if (current >= end) {
        current = end - 0.01;
      }
      onProgress(current);
    });

    try {
      return await task();
    } finally {
      isDone = true;
      timer.cancel();
      onProgress(end);
    }
  }

  Future<StorageUploadResult?> uploadSignedImageWithCompression({
    required StorageSignedUploadRequest request,
    required StorageCurrentUidEnsurer requireCurrentUid,
    required StorageContentTypeDetector detectContentType,
    required StorageStringMapBuilder stringMapFromDynamicMap,
    required StorageSignedUploadExecutor uploadBytesToSignedUrl,
  }) async {
    try {
      requireCurrentUid();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final originalFileName =
          request.file.name.isNotEmpty ? request.file.name : request.file.path;
      String fileExtension = p.extension(originalFileName).toLowerCase();
      XFile uploadFile = request.file;
      String? tempCompressedPath;

      String finalContentType = detectContentType(
        originalFileName,
        fallback: 'image/webp',
      );

      if (!kIsWeb && request.file.path.isNotEmpty && fileExtension != '.gif') {
        try {
          if (request.onProgress != null) request.onProgress!(0.02);
          final tempDir = await getTemporaryDirectory();
          tempCompressedPath = p.join(
            tempDir.path,
            '${request.tempPrefix}_${nowMs}_${DateTime.now().microsecondsSinceEpoch}.webp',
          );

          final compressedFile = await _runWithSmoothProgress(
            () => FlutterImageCompress.compressAndGetFile(
              request.file.path,
              tempCompressedPath!,
              minWidth: request.minWidth,
              minHeight: request.minHeight,
              quality: request.quality,
              format: CompressFormat.webp,
            ),
            0.02,
            0.15,
            const Duration(milliseconds: 500),
            request.onProgress,
          );

          if (compressedFile != null) {
            uploadFile = compressedFile;
            fileExtension = '.webp';
            finalContentType = 'image/webp';
          } else {
            tempCompressedPath = null;
          }
        } catch (compressError) {
          debugPrint(
              '${request.errorLabel} compression failed: $compressError');
          tempCompressedPath = null;
        }
      }

      if (fileExtension.isEmpty) {
        fileExtension = p.extension(uploadFile.name).toLowerCase();
      }
      if (fileExtension.isEmpty) {
        fileExtension = '.jpg';
      }

      try {
        final uploadBytes = await uploadFile.readAsBytes();
        final preferredFileName = p.basename(
          uploadFile.name.isNotEmpty ? uploadFile.name : '$nowMs$fileExtension',
        );

        final session = await _runWithSmoothProgress(
          () => request.sessionBuilder(finalContentType, preferredFileName),
          0.15,
          0.35,
          const Duration(milliseconds: 1000),
          request.onProgress,
        );

        final headers = stringMapFromDynamicMap(session['headers']);
        headers.putIfAbsent('Content-Type', () => finalContentType);

        await uploadBytesToSignedUrl(
          uploadUrl: session['uploadUrl'].toString(),
          bytes: uploadBytes,
          headers: headers,
          onProgress: request.onProgress != null 
              ? (p) => request.onProgress!(0.35 + (p * 0.40))
              : null,
        );

        if (request.onProgress != null) request.onProgress!(0.75);

        final blurHash = await BlurHashHelper.generateBlurHashFromBytes(uploadBytes);
        final sessionWithBlur = Map<String, dynamic>.from(session);
        if (blurHash != null) {
          sessionWithBlur['blurHash'] = blurHash;
        }

        final result = await _runWithSmoothProgress(
          () async => request.mapResult(sessionWithBlur),
          0.75,
          0.99,
          const Duration(milliseconds: 1200),
          request.onProgress,
        );

        if (request.onProgress != null) request.onProgress!(1.0);

        return result;
      } finally {
        if (tempCompressedPath != null) {
          final tempFile = File(tempCompressedPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('${request.errorLabel} upload failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: request.errorMessage,
      ).message}');
      throw Exception(request.errorMessage);
    }
  }
}
