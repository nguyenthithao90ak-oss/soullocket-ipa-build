import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static SharedPreferences? _cachedPrefs;
  static Box? _hiveBox;
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
    if (_cachedPrefs != null && _hiveBox != null) {
      return;
    }
    if (_initializingPrefs != null) {
      await _initializingPrefs;
      return;
    }

    final task = () async {
      _cachedPrefs = await SharedPreferences.getInstance();
      _hiveBox = await Hive.openBox('offline_cache');
      
      // MIGRATION: Copy các dữ liệu đệm nặng (offline_cache_) từ SharedPreferences sang Hive
      final prefs = _cachedPrefs!;
      const migrationKey = 'hive_migration_done';
      if (!(prefs.getBool(migrationKey) ?? false)) {
        try {
          final keysToMigrate = prefs
              .getKeys()
              .where((k) => k.startsWith('offline_cache_'))
              .toList();
          for (final k in keysToMigrate) {
            final raw = prefs.getString(k);
            if (raw != null) {
              await _hiveBox!.put(k, raw);
            }
            await prefs.remove(k);
          }
          await prefs.setBool(migrationKey, true);
          debugPrint('OfflineCacheService: Migrated ${keysToMigrate.length} items to Hive.');
        } catch (e) {
          debugPrint('OfflineCacheService: Migration error: $e');
        }
      }
    }();
    
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
    await initialize(); // Đảm bảo đã khởi tạo
    final raw = jsonEncode(data);
    await _hiveBox?.put(cacheKey, raw);
  }

  static Future<dynamic> loadCache(String key) async {
    final cacheKey = _cacheKey(key);
    await initialize();
    final raw = _hiveBox?.get(cacheKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      await _hiveBox?.delete(cacheKey);
      return null;
    }
  }

  static dynamic loadCacheSync(String key) {
    final cacheKey = _cacheKey(key);
    final raw = _hiveBox?.get(cacheKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      _hiveBox?.delete(cacheKey);
      return null;
    }
  }

  static String _cacheKey(String key) {
    return 'offline_cache_${key.trim()}';
  }

  static Future<void> deleteCache(String key) async {
    final cacheKey = _cacheKey(key);
    await initialize();
    await _hiveBox?.delete(cacheKey);
  }

  static Future<void> clearAllCache() async {
    clearAllMemoryCache();
    await initialize();
    await _hiveBox?.clear();
  }
}

class _MemoryCacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _MemoryCacheEntry({required this.data, required this.expiresAt});
}
