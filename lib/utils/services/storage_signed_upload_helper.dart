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
}

class StorageSignedUploadHelper {
  const StorageSignedUploadHelper();

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
          final tempDir = await getTemporaryDirectory();
          tempCompressedPath = p.join(
            tempDir.path,
            '${request.tempPrefix}_${nowMs}_${DateTime.now().microsecondsSinceEpoch}.webp',
          );

          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            request.file.path,
            tempCompressedPath,
            minWidth: request.minWidth,
            minHeight: request.minHeight,
            quality: request.quality,
            format: CompressFormat.webp,
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
        final session =
            await request.sessionBuilder(finalContentType, preferredFileName);
        final headers = stringMapFromDynamicMap(session['headers']);
        headers.putIfAbsent('Content-Type', () => finalContentType);

        await uploadBytesToSignedUrl(
          uploadUrl: session['uploadUrl'].toString(),
          bytes: uploadBytes,
          headers: headers,
        );

        final blurHash = await BlurHashHelper.generateBlurHashFromBytes(uploadBytes);
        final sessionWithBlur = Map<String, dynamic>.from(session);
        if (blurHash != null) {
          sessionWithBlur['blurHash'] = blurHash;
        }

        return request.mapResult(sessionWithBlur);
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
