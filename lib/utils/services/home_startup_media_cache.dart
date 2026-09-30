import 'dart:io';

import 'storage/resolved_file_cache.dart';

class HomeStartupMediaCache {
  HomeStartupMediaCache._();

  static final _files = ResolvedFileCache(
    maxEntries: 24,
    ttl: const Duration(hours: 18),
  );

  static String normalizeUrl(String url) => url.trim();
  static void saveFile(String url, File file) => _files.put(url, file);
  static File? getFile(String url) => _files.get(url);
  static void clear() => _files.clear();
}
