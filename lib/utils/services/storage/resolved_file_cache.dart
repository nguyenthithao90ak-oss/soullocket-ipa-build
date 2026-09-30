import 'dart:io';

import 'package:flutter/foundation.dart';

/// Chỉ giữ tham chiếu tệp có giới hạn; không xóa dữ liệu gốc khi tệp lỗi.
class ResolvedFileCache {
  ResolvedFileCache({this.maxEntries = 100, required this.ttl})
    : assert(maxEntries > 0);

  final int maxEntries;
  final Duration ttl;
  final Map<String, File> _files = {};

  bool _usable(File file) {
    if (kIsWeb) return false;
    try {
      final stat = file.statSync();
      return stat.type == FileSystemEntityType.file &&
          stat.size > 0 &&
          DateTime.now().difference(stat.modified) <= ttl;
    } on FileSystemException {
      return false;
    }
  }

  File? get(String url) {
    final key = url.trim();
    final file = _files.remove(key);
    if (file == null || !_usable(file)) return null;
    _files[key] = file;
    return file;
  }

  void put(String url, File file) {
    final key = url.trim();
    if (key.isEmpty) return;
    _files.remove(key);
    if (!_usable(file)) return;
    _files[key] = file;
    while (_files.length > maxEntries) {
      _files.remove(_files.keys.first);
    }
  }

  void clear() => _files.clear();
}
