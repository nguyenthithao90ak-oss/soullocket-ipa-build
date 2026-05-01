import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
        uploadTask = await ref.putFile(File(file.path), metadata);
      } else {
        final fileBytes = await file.readAsBytes();
        uploadTask = await ref.putData(fileBytes, metadata);
      }

      return uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Lỗi khi upload tệp $storagePath: $e');
      throw Exception(
        'Không tải tệp lên đám mây được: hãy kiểm tra kết nối mạng, đăng nhập và quyền truy cập tệp.',
      );
    }
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
      throw Exception('File nhạc vượt quá 10MB. Hãy chọn file nhỏ hơn.');
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
        uploadTask = await ref.putFile(File(file.path), metadata);
      } else {
        final fileBytes = await file.readAsBytes();
        uploadTask = await ref.putData(fileBytes, metadata);
      }

      return uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Lỗi khi upload file nhạc $storagePath: $e');
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
      throw Exception('File nhạc vượt quá 10MB. Hãy chọn file nhỏ hơn.');
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
      final uploadTask = await ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: resolvedContentType,
          cacheControl: storageImmutableCacheControl,
        ),
      );

      return uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Lỗi khi upload tệp $storagePath: $e');
      throw Exception(
        'Không tải tệp lên đám mây được: hãy kiểm tra kết nối mạng, đăng nhập và quyền truy cập tệp.',
      );
    }
  }
}
