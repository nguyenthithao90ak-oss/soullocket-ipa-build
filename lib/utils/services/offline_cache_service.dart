import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static SharedPreferences? _cachedPrefs;
  static Future<void>? _initializingPrefs;

  OfflineCacheService._internal();

  static SharedPreferences? getPrefsSync() => _cachedPrefs;

  static Future<SharedPreferences> getPrefs() async {
    await initialize();
    return _cachedPrefs!;
  }

  static Future<void> initialize() async {
    if (_cachedPrefs != null) {
      return;
    }
    if (_initializingPrefs != null) {
      await _initializingPrefs;
      return;
    }

    final task = SharedPreferences.getInstance().then((prefs) {
      _cachedPrefs = prefs;
    });
    _initializingPrefs = task;
    try {
      await task;
    } finally {
      if (identical(_initializingPrefs, task)) {
        _initializingPrefs = null;
      }
    }
  }

  static Future<void> saveCache(String key, dynamic data) async {
    final cacheKey = _cacheKey(key);
    final prefs = await getPrefs();
    await prefs.setString(cacheKey, jsonEncode(data));
  }

  static Future<dynamic> loadCache(String key) async {
    final cacheKey = _cacheKey(key);
    final prefs = await getPrefs();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      await prefs.remove(cacheKey);
      return null;
    }
  }

  static dynamic loadCacheSync(String key) {
    final cacheKey = _cacheKey(key);
    final raw = _cachedPrefs?.getString(cacheKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      _cachedPrefs?.remove(cacheKey);
      return null;
    }
  }

  static String _cacheKey(String key) {
    return 'offline_cache_${key.trim()}';
  }

  static Future<void> clearAllCache() async {
    final prefs = await getPrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith('offline_cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
