import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../app_error_mapper.dart';
typedef StorageRefPathNormalizer = String Function(String storagePath);

class StorageDeleteHelper {
  const StorageDeleteHelper();

  Future<bool> deleteFileByPath({
    required FirebaseStorage storage,
    required String storagePath,
    required StorageRefPathNormalizer normalizeStorageRefPath,
  }) async {
    final normalizedPath = normalizeStorageRefPath(storagePath);
    if (normalizedPath.isEmpty) {
      return true;
    }

    try {
      await storage.ref().child(normalizedPath).delete();
      return true;
    } on FirebaseException catch (error) {
      if (error.code.trim().toLowerCase() == 'object-not-found') {
        return true;
      }
      debugPrint('Failed to delete storage file $normalizedPath: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể xóa tệp lưu trữ.',
      ).message}');
      return false;
    } catch (e) {
      debugPrint('Failed to delete storage file $normalizedPath: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xóa tệp lưu trữ.',
      ).message}');
      return false;
    }
  }

  Future<bool> deleteLocalFile(String path) async {
    if (kIsWeb) {
      return false;
    }

    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return true;
    }

    try {
      final file = File(normalizedPath);
      if (!await file.exists()) {
        return true;
      }
      await file.delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete local file $normalizedPath: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xóa tệp cục bộ.',
      ).message}');
      return false;
    }
  }

  Future<bool> deleteImageByUrl({
    required FirebaseStorage storage,
    required String url,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return true;
    }

    try {
      final ref = storage.refFromURL(normalizedUrl);
      await ref.delete();
      return true;
    } on FirebaseException catch (error) {
      if (error.code.trim().toLowerCase() == 'object-not-found') {
        return true;
      }
      debugPrint(
        'Failed to delete storage file from URL $normalizedUrl: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể xóa tệp từ URL.',
        ).message}',
      );
      return false;
    } catch (e) {
      debugPrint('Failed to delete storage file from URL $normalizedUrl: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xóa tệp từ URL.',
      ).message}');
      return false;
    }
  }
}
