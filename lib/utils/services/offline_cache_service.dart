import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      try {
        _hiveBox = await Hive.openBox('offline_cache');
      } catch (e) {
        debugPrint('OfflineCacheService: Hive openBox error: $e');
      }

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
          debugPrint(
              'OfflineCacheService: Migrated ${keysToMigrate.length} items to Hive.');
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

// ─────────────────────────────────────────────
// Offline Sync Queue — Lưu các lệnh ghi RTDB
// khi offline, tự đồng bộ khi có mạng lại.
// ─────────────────────────────────────────────

/// Một lệnh ghi Firebase RTDB đang chờ đồng bộ.
class _SyncTask {
  final String path;
  final Map<String, dynamic>? data; // null = xóa (delete)
  final bool isDelete;
  final int timestamp;

  _SyncTask({
    required this.path,
    this.data,
    this.isDelete = false,
    required this.timestamp,
  });

  factory _SyncTask.fromJson(Map<String, dynamic> json) => _SyncTask(
        path: json['path'] as String,
        data: json['data'] != null
            ? Map<String, dynamic>.from(json['data'] as Map)
            : null,
        isDelete: json['isDelete'] as bool? ?? false,
        timestamp: json['timestamp'] as int,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'data': data,
        'isDelete': isDelete,
        'timestamp': timestamp,
      };
}

/// Service quản lý hàng đợi đồng bộ offline cho Firebase Realtime Database.
///
/// Sử dụng:
/// ```dart
/// // Ghi dữ liệu — tự quyết định online/offline
/// await OfflineSyncQueue.instance.write('houses/abc123/settings', {'theme': 'dark'});
///
/// // Khởi động listener mạng (gọi 1 lần khi app start)
/// OfflineSyncQueue.instance.startListening();
/// ```
class OfflineSyncQueue {
  static final OfflineSyncQueue instance = OfflineSyncQueue._();
  OfflineSyncQueue._();

  static const String _hiveBoxName = 'offline_sync_queue';
  static const String _queueKey = 'pending_tasks';
  static const int _maxQueueSize = 200;

  Box? _box;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  /// Khởi động listener theo dõi kết nối mạng.
  /// Gọi 1 lần duy nhất trong `main()` hoặc bootstrap của app.
  Future<void> startListening() async {
    _box = await Hive.openBox(_hiveBoxName);

    // Thử sync ngay khi start (trường hợp app khởi động lại khi đang có mạng)
    _trySyncNow();

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint(
            '[SyncQueue] Phát hiện có mạng — bắt đầu đồng bộ hàng đợi...');
        _trySyncNow();
      }
    });
  }

  /// Dừng listener (gọi khi dispose app nếu cần).
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Ghi dữ liệu lên Firebase RTDB.
  /// Nếu online: ghi thẳng lên Firebase.
  /// Nếu offline: đưa vào hàng đợi, tự đồng bộ khi có mạng.
  Future<void> write(String path, Map<String, dynamic> data) async {
    final isOnline = await _checkConnectivity();
    if (isOnline) {
      try {
        await FirebaseDatabase.instance.ref(path).update(data);
        debugPrint('[SyncQueue] Ghi online thành công: $path');
        return;
      } catch (e) {
        debugPrint(
            '[SyncQueue] Ghi online thất bại ($path), đẩy vào hàng đợi: $e');
      }
    }
    await _enqueue(_SyncTask(
      path: path,
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Đưa một task vào hàng đợi Hive.
  Future<void> _enqueue(_SyncTask task) async {
    await _ensureBox();
    final raw = _box!.get(_queueKey);
    final List<dynamic> current =
        raw != null ? List<dynamic>.from(jsonDecode(raw as String)) : [];

    if (current.length >= _maxQueueSize) {
      // Xóa task cũ nhất để nhường chỗ
      current.removeAt(0);
      debugPrint('[SyncQueue] Hàng đợi đầy, xóa task cũ nhất.');
    }

    current.add(task.toJson());
    await _box!.put(_queueKey, jsonEncode(current));
    debugPrint(
        '[SyncQueue] Đã thêm vào hàng đợi: ${task.path} (tổng: ${current.length})');
  }

  /// Lấy số lượng task đang chờ trong hàng đợi.
  Future<int> get pendingCount async {
    await _ensureBox();
    final raw = _box!.get(_queueKey);
    if (raw == null) return 0;
    final list = List<dynamic>.from(jsonDecode(raw as String));
    return list.length;
  }

  /// Thực hiện đồng bộ toàn bộ hàng đợi lên Firebase.
  Future<void> _trySyncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _ensureBox();
      final raw = _box!.get(_queueKey);
      if (raw == null) return;

      final List<dynamic> tasks = List<dynamic>.from(jsonDecode(raw as String));
      if (tasks.isEmpty) return;

      debugPrint('[SyncQueue] Bắt đầu đồng bộ ${tasks.length} task(s)...');
      final List<dynamic> failed = [];

      for (final taskJson in tasks) {
        final task =
            _SyncTask.fromJson(Map<String, dynamic>.from(taskJson as Map));
        try {
          if (task.isDelete) {
            await FirebaseDatabase.instance.ref(task.path).remove();
          } else if (task.data != null) {
            await FirebaseDatabase.instance.ref(task.path).update(task.data!);
          }
          debugPrint('[SyncQueue] ✓ Đồng bộ thành công: ${task.path}');
        } catch (e) {
          debugPrint('[SyncQueue] ✗ Thất bại khi đồng bộ ${task.path}: $e');
          failed.add(taskJson); // Giữ lại để thử lại sau
        }
      }

      // Lưu lại những task thất bại
      if (failed.isEmpty) {
        await _box!.delete(_queueKey);
        debugPrint('[SyncQueue] Hoàn tất — hàng đợi đã trống.');
      } else {
        await _box!.put(_queueKey, jsonEncode(failed));
        debugPrint(
            '[SyncQueue] Còn ${failed.length} task(s) thất bại, sẽ thử lại sau.');
      }
    } catch (e) {
      debugPrint('[SyncQueue] Lỗi khi đồng bộ hàng đợi: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureBox() async {
    _box ??= await Hive.openBox(_hiveBoxName);
  }
}
