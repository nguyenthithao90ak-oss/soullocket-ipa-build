import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import '../cloudflare_r2_service.dart';

class StorageDeleteHelper {
  const StorageDeleteHelper();

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
      debugPrint(
        'Failed to delete local file $normalizedPath: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể xóa tệp cục bộ.').message}',
      );
      return false;
    }
  }

  Future<bool> deleteImageByUrl({required String url}) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return true;
    }

    try {
      CloudflareR2Service.instance.init();
      if (CloudflareR2Service.instance.isR2Url(normalizedUrl)) {
        return await CloudflareR2Service.instance.deleteFile(normalizedUrl);
      }
      return false;
    } catch (e) {
      debugPrint('Failed to delete R2 file: ${e.runtimeType}');
      return false;
    }
  }
}
