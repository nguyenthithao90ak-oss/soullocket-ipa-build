import 'dart:io';

class HomeStartupMediaCache {
  HomeStartupMediaCache._();

  static final Map<String, File> _files = <String, File>{};

  static String normalizeUrl(String url) => url.trim();

  static void saveFile(String url, File file) {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) return;
    _files[normalizedUrl] = file;
  }

  static File? getFile(String url) {
    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) return null;
    return _files[normalizedUrl];
  }
}
