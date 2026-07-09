import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static SharedPreferences? _cachedPrefs;
  static Future<void>? _initializingPrefs;

  // RAM Cache — giới hạn 50 entries tránh memory leak
  static final Map<String, _MemoryCacheEntry> _memoryCache = {};
  static const int _memoryCacheMaxSize = 50;

  OfflineCacheService._internal();

  /// Đặt dữ liệu vào RAM Cache với thời gian sống (TTL).
  static void setMemoryCache(String key, dynamic data, Duration ttl) {
    if (!_memoryCache.containsKey(key) &&
        _memoryCache.length >= _memoryCacheMaxSize) {
      // LRU eviction: xoá entry sắp hết hạn nhất
      String? oldestKey;
      DateTime? oldestTime;
      for (final entry in _memoryCache.entries) {
        if (oldestTime == null || entry.value.expiresAt.isBefore(oldestTime)) {
          oldestTime = entry.value.expiresAt;
          oldestKey = entry.key;
        }
      }
      if (oldestKey != null) _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = _MemoryCacheEntry(
      data: data,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Lấy dữ liệu từ RAM Cache. Trả về null nếu không có hoặc đã hết hạn.
  static dynamic getMemoryCache(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Xóa RAM Cache cho một key cụ thể.
  static void clearMemoryCache(String key) {
    _memoryCache.remove(key);
  }

  /// Xóa toàn bộ RAM Cache.
  static void clearAllMemoryCache() {
    _memoryCache.clear();
  }

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

  static Future<void> deleteCache(String key) async {
    final cacheKey = _cacheKey(key);
    final prefs = await getPrefs();
    await prefs.remove(cacheKey);
  }

  static Future<void> clearAllCache() async {
    clearAllMemoryCache();
    final prefs = await getPrefs();
    final keys =
        prefs.getKeys().where((k) => k.startsWith('offline_cache_')).toList();
    if (keys.isNotEmpty) {
      await Future.wait(keys.map((key) => prefs.remove(key)));
    }
  }
}

class _MemoryCacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _MemoryCacheEntry({required this.data, required this.expiresAt});
}
