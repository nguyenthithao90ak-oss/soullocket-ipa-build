import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';
import 'storage/resolved_file_cache.dart';

class HomeStartupMediaCache {
  HomeStartupMediaCache._();

  // Hạn tính theo ngày file được tải về máy. Ảnh Home (avatar/nền) gắn với
  // URL, đổi ảnh là đổi URL, nên file cũ của cùng URL vẫn đúng ảnh. Hạn 18 giờ
  // trước đây loại hầu hết avatar lâu ngày, khiến Home nháy avatar mặc định.
  static final _files = ResolvedFileCache(
    maxEntries: 24,
    ttl: const Duration(days: 30),
  );

  /// Ghi nhớ URL → đường dẫn file qua các lần mở app: lần sau đọc được ngay
  /// (đồng bộ) mà không chờ cache manager mở cơ sở dữ liệu (~1 giây).
  static const _prefsKey = 'home_startup_media_paths_v1';
  static const _maxRemembered = 24;

  @visibleForTesting
  static SharedPreferences? Function() prefsProvider =
      OfflineCacheService.getPrefsSync;

  static String normalizeUrl(String url) => url.trim();

  static void saveFile(String url, File file) {
    _files.put(url, file);
    if (_files.get(url) != null) _remember(url.trim(), file.path);
  }

  static File? getFile(String url) {
    final key = url.trim();
    final file = _files.get(key);
    if (file != null || key.isEmpty) return file;
    final path = _readRemembered()[key];
    if (path == null || path.isEmpty) return null;
    // put() tự bỏ qua file đã bị xóa, rỗng hoặc quá hạn.
    _files.put(key, File(path));
    return _files.get(key);
  }

  static void clear() => _files.clear();

  static Map<String, String> _readRemembered() {
    try {
      final raw = prefsProvider()?.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (error) {
      debugPrint('[HomeStartupMediaCache] read failed: $error');
      return const {};
    }
  }

  static void _remember(String url, String path) {
    final prefs = prefsProvider();
    if (prefs == null || url.isEmpty) return;
    final current = Map<String, String>.of(_readRemembered());
    if (current[url] == path) return;
    // Giữ thứ tự mới nhất ở cuối, chỉ nhớ một số ít ảnh Home gần đây.
    current
      ..remove(url)
      ..[url] = path;
    while (current.length > _maxRemembered) {
      current.remove(current.keys.first);
    }
    prefs.setString(_prefsKey, jsonEncode(current)).catchError((Object error) {
      debugPrint('[HomeStartupMediaCache] save failed: $error');
      return false;
    });
  }
}
