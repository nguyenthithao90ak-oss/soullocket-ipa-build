import 'dart:io';

import 'package:flutter/foundation.dart';

class HomeStartupMediaCache {
  HomeStartupMediaCache._();

  static final Map<String, File> _files = <String, File>{};

  static String normalizeUrl(String url) => url.trim();

  static void saveFile(String url, File file) {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) return;
    if (file.existsSync() && file.lengthSync() > 0) {
      _files[normalizedUrl] = file;
    }
  }

  static File? getFile(String url) {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) return null;
    final file = _files[normalizedUrl];
    if (file != null && file.existsSync()) {
      if (file.lengthSync() == 0) {
        try {
          file.deleteSync();
        } catch (error) {
          debugPrint('[HomeMediaCache] Không xóa được file rỗng: $error');
        }
        _files.remove(normalizedUrl);
        return null;
      }
      return file;
    }
    return null;
  }
}
