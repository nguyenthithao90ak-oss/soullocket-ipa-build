import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'storage_media_constants.dart';

typedef StorageVideoUploadRejector = void Function({
  required String storagePath,
  required String resolvedContentType,
  String? originalFileName,
});

typedef StorageUploadCachePurger = Future<void> Function();

typedef StorageRefBuilder = Reference Function(String storagePath);

class StorageRawUploadHelper {
  const StorageRawUploadHelper();

  Future<String> uploadFileToPath({
    required String storagePath,
    required XFile file,
    required String resolvedContentType,
    required StorageVideoUploadRejector rejectVideoUpload,
    required StorageUploadCachePurger purgeLegacyCache,
    required StorageRefBuilder buildStorageRef,
    ValueChanged<double>? onProgress,
  }) async {
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    rejectVideoUpload(
      storagePath: storagePath,
      resolvedContentType: resolvedContentType,
      originalFileName:
          originalFileName.isNotEmpty ? originalFileName : storagePath,
    );
    final metadata = SettableMetadata(
      contentType: resolvedContentType,
      cacheControl: storageImmutableCacheControl,
    );

    await purgeLegacyCache();

    try {
      final ref = buildStorageRef(storagePath);
      TaskSnapshot uploadTask;

      if (!kIsWeb && file.path.isNotEmpty) {
        if (_isImageContentType(resolvedContentType)) {
          final compressed = await _compressImageFile(
            File(file.path),
            resolvedContentType,
          );
          uploadTask = await _retryUpload(
            () {
              final task = ref.putData(compressed, metadata);
              if (onProgress != null) {
                task.snapshotEvents.listen((event) {
                  if (event.totalBytes > 0) {
                    onProgress(event.bytesTransferred / event.totalBytes);
                  }
                });
              }
              return task;
            },
          );
        } else {
          uploadTask = await _retryUpload(
            () {
              final task = ref.putFile(File(file.path), metadata);
              if (onProgress != null) {
                task.snapshotEvents.listen((event) {
                  if (event.totalBytes > 0) {
                    onProgress(event.bytesTransferred / event.totalBytes);
                  }
                });
              }
              return task;
            },
          );
        }
      } else {
        final fileBytes = await file.readAsBytes();
        final dataToUpload = _isImageContentType(resolvedContentType)
            ? await _compressImageBytes(fileBytes, resolvedContentType)
            : fileBytes;
        uploadTask = await _retryUpload(
          () {
            final task = ref.putData(dataToUpload, metadata);
            if (onProgress != null) {
              task.snapshotEvents.listen((event) {
                if (event.totalBytes > 0) {
                  onProgress(event.bytesTransferred / event.totalBytes);
                }
              });
            }
            return task;
          },
        );
      }

      return uploadTask.ref.getDownloadURL();
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

  bool _shouldRetryUploadError(Object error) {
    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      return code == 'retry-limit-exceeded' ||
          code == 'unknown' ||
          code == 'unavailable';
    }
    if (error is SocketException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('network') ||
        text.contains('unavailable') ||
        text.contains('deadline') ||
        text.contains('connection') ||
        text.contains('kết nối') ||
        text.contains('mạng');
  }

  static const Duration _uploadAttemptTimeout = Duration(seconds: 45);

  Future<T> _retryUpload<T>(Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await action().timeout(
          _uploadAttemptTimeout,
          onTimeout: () {
            throw TimeoutException('Storage upload attempt timed out.');
          },
        );
      } catch (error) {
        lastError = error;
        if (attempt >= 2 || !_shouldRetryUploadError(error)) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 420 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('Upload failed.');
  }

  Future<String> uploadMusicFileToPath({
    required String storagePath,
    required XFile file,
    required String resolvedContentType,
    required bool Function(String fileNameOrPath) isSupportedMusicFileName,
    required StorageUploadCachePurger purgeLegacyCache,
    required StorageRefBuilder buildStorageRef,
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

    final metadata = SettableMetadata(
      contentType: resolvedContentType,
      cacheControl: storageImmutableCacheControl,
    );

    await purgeLegacyCache();

    try {
      final ref = buildStorageRef(storagePath);
      TaskSnapshot uploadTask;

      if (!kIsWeb && file.path.isNotEmpty) {
        uploadTask = await _retryUpload(
          () => ref.putFile(File(file.path), metadata),
        );
      } else {
        final fileBytes = await file.readAsBytes();
        uploadTask = await _retryUpload(
          () => ref.putData(fileBytes, metadata),
        );
      }

      return uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Lỗi khi upload file nhạc $storagePath: ${AppErrorMapper.resolve(
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
    required StorageRefBuilder buildStorageRef,
  }) async {
    rejectVideoUpload(
      storagePath: storagePath,
      resolvedContentType: resolvedContentType,
      originalFileName: originalFileName,
    );
    await purgeLegacyCache();

    try {
      final ref = buildStorageRef(storagePath);
      final dataToUpload = _isImageContentType(resolvedContentType)
          ? await _compressImageBytes(fileBytes, resolvedContentType)
          : fileBytes;
      final uploadTask = await _retryUpload(
        () => ref.putData(
          dataToUpload,
          SettableMetadata(
            contentType: resolvedContentType,
            cacheControl: storageImmutableCacheControl,
          ),
        ),
      );

      return uploadTask.ref.getDownloadURL();
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
