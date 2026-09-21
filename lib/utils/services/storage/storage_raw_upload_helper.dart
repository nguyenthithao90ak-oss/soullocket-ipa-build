import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/cloudflare_r2_service.dart';
import 'storage_media_constants.dart';
import 'storage_upload_result.dart';

typedef StorageVideoUploadRejector =
    void Function({
      required String storagePath,
      required String resolvedContentType,
      String? originalFileName,
    });

typedef StorageUploadCachePurger = Future<void> Function();

class StorageRawUploadHelper {
  const StorageRawUploadHelper();

  Future<String> uploadFileToPath({
    required String storagePath,
    required XFile file,
    required String resolvedContentType,
    required StorageVideoUploadRejector rejectVideoUpload,
    required StorageUploadCachePurger purgeLegacyCache,
    ValueChanged<double>? onProgress,
  }) async => (await uploadFileResult(
    storagePath: storagePath,
    file: file,
    resolvedContentType: resolvedContentType,
    rejectVideoUpload: rejectVideoUpload,
    purgeLegacyCache: purgeLegacyCache,
    onProgress: onProgress,
  )).downloadUrl;

  Future<StorageUploadResult> uploadFileResult({
    required String storagePath,
    required XFile file,
    required String resolvedContentType,
    required StorageVideoUploadRejector rejectVideoUpload,
    required StorageUploadCachePurger purgeLegacyCache,
    Future<void> Function(int bytes)? beforeUpload,
    ValueChanged<double>? onProgress,
  }) async {
    rejectVideoUpload(
      storagePath: storagePath,
      resolvedContentType: resolvedContentType,
      originalFileName: file.name,
    );
    await purgeLegacyCache();
    // Ảnh đã được xử lý ở StorageService. Không nén lần hai hay đổi tên container.
    return CloudflareR2Service.instance.uploadMedia(
      file,
      folderPath: p.dirname(storagePath).replaceAll('\\', '/'),
      storagePathOverride: storagePath,
      contentType: resolvedContentType,
      beforeUpload: beforeUpload,
      onProgress: onProgress,
    );
  }

  Future<String> uploadMusicFileToPath({
    required String storagePath,
    required XFile file,
    required String resolvedContentType,
    required bool Function(String fileNameOrPath) isSupportedMusicFileName,
    required StorageUploadCachePurger purgeLegacyCache,
  }) async {
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    final sourceName = originalFileName.isNotEmpty
        ? originalFileName
        : storagePath;
    if (!isSupportedMusicFileName(sourceName)) {
      throw Exception('Chỉ hỗ trợ MP3, M4A, AAC, WAV, OGG, FLAC hoặc MP4.');
    }

    final fileSize = await file.length();
    if (fileSize > storageMaxMusicUploadBytes) {
      throw Exception('File nhạc vượt quá 20MB. Hãy chọn file nhỏ hơn.');
    }

    await purgeLegacyCache();

    try {
      CloudflareR2Service.instance.init();

      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(
        tempDir.path,
        'r2_music_upload_${DateTime.now().microsecondsSinceEpoch}.mp3',
      );
      final tempFile = File(tempPath);

      try {
        if (!kIsWeb && file.path.isNotEmpty) {
          await File(file.path).copy(tempPath);
        } else {
          final fileBytes = await file.readAsBytes();
          await tempFile.writeAsBytes(fileBytes);
        }

        final r2Url = await CloudflareR2Service.instance.uploadFile(
          tempFile,
          folderPath: p.dirname(storagePath).replaceAll('\\', '/'),
          storagePathOverride: storagePath,
        );
        if (r2Url == null || r2Url.isEmpty) {
          throw Exception('R2 upload failed.');
        }
        return r2Url;
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint(
        'Lỗi khi upload file nhạc $storagePath: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không tải file nhạc lên đám mây được.').message}',
      );
      throw Exception(
        'Không tải file nhạc lên đám mây được: hãy kiểm tra kết nối mạng, định dạng file và quyền truy cập tệp.',
      );
    }
  }

  Future<String> saveMusicFileLocally({
    required XFile file,
    required bool Function(String fileNameOrPath) isSupportedMusicFileName,
  }) async {
    if (kIsWeb) {
      throw Exception('Trình duyệt hiện chưa hỗ trợ lưu nhạc cục bộ bền vững.');
    }

    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    final sourceName = originalFileName.isNotEmpty ? originalFileName : 'music';
    if (!isSupportedMusicFileName(sourceName)) {
      throw Exception('Chỉ hỗ trợ MP3, M4A, AAC, WAV, OGG, FLAC hoặc MP4.');
    }

    final fileSize = await file.length();
    if (fileSize > storageMaxMusicUploadBytes) {
      throw Exception('File nhạc vượt quá 20MB. Hãy chọn file nhỏ hơn.');
    }

    final extension = p.extension(sourceName).toLowerCase();
    final rawBaseName = p.basenameWithoutExtension(sourceName).trim();
    final safeBaseName = rawBaseName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final normalizedBaseName = safeBaseName.isEmpty ? 'music' : safeBaseName;

    final appDir = await getApplicationSupportDirectory();
    final musicDir = Directory(p.join(appDir.path, 'music'));
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }

    final targetPath = p.join(
      musicDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$normalizedBaseName$extension',
    );

    if (file.path.isNotEmpty) {
      final sourceFile = File(file.path);
      if (sourceFile.path != targetPath) {
        await sourceFile.copy(targetPath);
      }
      return targetPath;
    }

    final fileBytes = await file.readAsBytes();
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(fileBytes, flush: true);
    return targetPath;
  }

  Future<String> uploadBytesToPath({
    required String storagePath,
    required Uint8List fileBytes,
    required String resolvedContentType,
    required String originalFileName,
    required StorageVideoUploadRejector rejectVideoUpload,
    required StorageUploadCachePurger purgeLegacyCache,
  }) => uploadFileToPath(
    storagePath: storagePath,
    file: XFile.fromData(
      fileBytes,
      name: originalFileName,
      mimeType: resolvedContentType,
    ),
    resolvedContentType: resolvedContentType,
    rejectVideoUpload: rejectVideoUpload,
    purgeLegacyCache: purgeLegacyCache,
  );
}
