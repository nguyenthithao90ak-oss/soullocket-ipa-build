import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/cloudflare_r2_service.dart';
import 'storage_media_constants.dart';

typedef StorageVideoUploadRejector = void Function({
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
  }) async {
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    rejectVideoUpload(
      storagePath: storagePath,
      resolvedContentType: resolvedContentType,
      originalFileName:
          originalFileName.isNotEmpty ? originalFileName : storagePath,
    );

    final fileSize = await file.length();
    final isVideo = resolvedContentType.startsWith('video/');
    final limit = isVideo ? 100 * 1024 * 1024 : 25 * 1024 * 1024;
    if (fileSize > limit) {
      throw Exception(
          'Tệp tải lên vượt quá giới hạn. Vui lòng chọn tệp nhỏ hơn.');
    }

    await purgeLegacyCache();

    try {
      CloudflareR2Service.instance.init();

      final tempDir = await getTemporaryDirectory();
      final ext = _isImageContentType(resolvedContentType)
          ? _imageExtension(resolvedContentType)
          : (resolvedContentType.startsWith('video/') ? '.mp4' : '.bin');
      final tempPath = p.join(tempDir.path,
          'r2_upload_${DateTime.now().microsecondsSinceEpoch}$ext');
      final tempFile = File(tempPath);

      try {
        if (!kIsWeb && file.path.isNotEmpty) {
          if (_isImageContentType(resolvedContentType)) {
            final compressed =
                await _compressImageFile(File(file.path), resolvedContentType);
            await tempFile.writeAsBytes(compressed);
          } else {
            await File(file.path).copy(tempPath);
          }
        } else {
          final fileBytes = await file.readAsBytes();
          final dataToUpload = _isImageContentType(resolvedContentType)
              ? await _compressImageBytes(fileBytes, resolvedContentType)
              : fileBytes;
          await tempFile.writeAsBytes(dataToUpload);
        }

        final r2Url = await CloudflareR2Service.instance.uploadFile(
          tempFile,
          folderPath: p.dirname(storagePath).replaceAll('\\', '/'),
          storagePathOverride: storagePath,
        );
        if (r2Url == null || r2Url.isEmpty) {
          throw Exception(
              'Máy chủ ảnh (R2) không phản hồi. Vui lòng thử lại sau.');
        }
        return r2Url;
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      final msg =
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : null;
      debugPrint('Lỗi upload ảnh: $e');
      throw Exception(msg ??
          'Lỗi tải ảnh lên máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.');
    }
  }

  static const int _compressThresholdBytes = 500 * 1024; // 500 KB
  static const int _compressQuality = 75;
  static const int _compressMaxDimension = 1080;

  bool _isImageContentType(String contentType) {
    final ct = contentType.toLowerCase();
    return ct.startsWith('image/') &&
        (ct.contains('jpeg') ||
            ct.contains('jpg') ||
            ct.contains('png') ||
            ct.contains('webp') ||
            ct.contains('heic') ||
            ct.contains('heif'));
  }

  String _imageExtension(String contentType) {
    final ct = contentType.toLowerCase();
    if (ct.contains('png')) return '.png';
    if (ct.contains('webp')) return '.webp';
    if (ct.contains('gif')) return '.gif';
    if (ct.contains('heic') || ct.contains('heif')) return '.heic';
    return '.jpg';
  }

  /// Nén file ảnh nếu > 500KB. Trả về bytes đã nén (hoặc bytes gốc nếu không cần/lỗi).
  Future<Uint8List> _compressImageFile(
    File file,
    String contentType,
  ) async {
    try {
      final size = await file.length();
      if (size <= _compressThresholdBytes) return await file.readAsBytes();
      final ext = contentType.contains('png')
          ? CompressFormat.png
          : contentType.contains('webp')
              ? CompressFormat.webp
              : CompressFormat.jpeg;
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: _compressMaxDimension,
        minHeight: _compressMaxDimension,
        quality: _compressQuality,
        format: ext,
      );
      if (result == null || result.isEmpty) return await file.readAsBytes();
      debugPrint(
        '[ImageCompress] ${p.basename(file.path)}: ${size ~/ 1024}KB → ${result.length ~/ 1024}KB',
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompress] Lỗi nén file, dùng ảnh gốc: $e');
      return await file.readAsBytes();
    }
  }

  /// Nén bytes ảnh nếu > 500KB. Trả về bytes đã nén (hoặc bytes gốc nếu không cần/lỗi).
  Future<Uint8List> _compressImageBytes(
    Uint8List bytes,
    String contentType,
  ) async {
    try {
      if (bytes.length <= _compressThresholdBytes) return bytes;
      final ext = contentType.contains('png')
          ? CompressFormat.png
          : contentType.contains('webp')
              ? CompressFormat.webp
              : CompressFormat.jpeg;
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _compressMaxDimension,
        minHeight: _compressMaxDimension,
        quality: _compressQuality,
        format: ext,
      );
      if (result.isEmpty) return bytes;
      debugPrint(
        '[ImageCompress] bytes: ${bytes.length ~/ 1024}KB → ${result.length ~/ 1024}KB',
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompress] Lỗi nén bytes, dùng ảnh gốc: $e');
      return bytes;
    }
  }

  Future<String> uploadMusicFileToPath({
    required String storagePath,
    required XFile file,
    required String resolvedContentType,
    required bool Function(String fileNameOrPath) isSupportedMusicFileName,
    required StorageUploadCachePurger purgeLegacyCache,
  }) async {
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    final sourceName =
        originalFileName.isNotEmpty ? originalFileName : storagePath;
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
      final tempPath = p.join(tempDir.path,
          'r2_music_upload_${DateTime.now().microsecondsSinceEpoch}.mp3');
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
          'Lỗi khi upload file nhạc $storagePath: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không tải file nhạc lên đám mây được.',
      ).message}');
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
  }) async {
    rejectVideoUpload(
      storagePath: storagePath,
      resolvedContentType: resolvedContentType,
      originalFileName: originalFileName,
    );
    await purgeLegacyCache();

    try {
      CloudflareR2Service.instance.init();

      final tempDir = await getTemporaryDirectory();
      final ext = _isImageContentType(resolvedContentType)
          ? _imageExtension(resolvedContentType)
          : '.bin';
      final tempPath = p.join(tempDir.path,
          'r2_upload_${DateTime.now().microsecondsSinceEpoch}$ext');
      final tempFile = File(tempPath);

      try {
        final dataToUpload = _isImageContentType(resolvedContentType)
            ? await _compressImageBytes(fileBytes, resolvedContentType)
            : fileBytes;
        await tempFile.writeAsBytes(dataToUpload);

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
      debugPrint('Lỗi khi upload tệp $storagePath: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không tải tệp lên đám mây được.',
      ).message}');
      throw Exception(
        'Không tải tệp lên đám mây được: hãy kiểm tra kết nối mạng, đăng nhập và quyền truy cập tệp.',
      );
    }
  }
}
