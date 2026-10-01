import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'storage/private_image_disk_cache.dart';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static SharedPreferences? _cachedPrefs;
  static Box? _hiveBox;
  static Future<void>? _initializingPrefs;
  static Future<void> _cacheWork = Future<void>.value();
  static int _cacheGeneration = 0;

  static Future<T> _serializeCache<T>(Future<T> Function() action) {
    final task = _cacheWork.then((_) => action());
    _cacheWork = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

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
      if (_hiveBox != null && !(prefs.getBool(migrationKey) ?? false)) {
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
            'OfflineCacheService: Migrated ${keysToMigrate.length} items to Hive.',
          );
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

  static Future<void> saveCache(String key, dynamic data) {
    final generation = _cacheGeneration;
    final raw = jsonEncode(data);
    return _serializeCache(() async {
      await initialize();
      if (generation != _cacheGeneration) return;
      final cacheKey = _cacheKey(key);
      if (_hiveBox != null) {
        await _hiveBox!.put(cacheKey, raw);
      } else {
        // Không báo lưu thành công khi Hive chưa mở được.
        final saved = await _cachedPrefs!.setString(cacheKey, raw);
        if (!saved) throw StateError('Unable to persist offline cache');
      }
    });
  }

  static Future<dynamic> loadCache(String key) async {
    final generation = _cacheGeneration;
    await initialize();
    if (generation != _cacheGeneration) return null;
    return loadCacheSync(key);
  }

  static dynamic loadCacheSync(String key) {
    final cacheKey = _cacheKey(key);
    final raw = _hiveBox?.get(cacheKey) ?? _cachedPrefs?.getString(cacheKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      // Không xóa bất đồng bộ ở đây vì có thể ghi đè bản hợp lệ vừa lưu.
      return null;
    }
  }

  static String _cacheKey(String key) => 'offline_cache_${key.trim()}';

  static Future<void> deleteCache(String key) => _serializeCache(() async {
    await initialize();
    await _hiveBox?.delete(_cacheKey(key));
    await _cachedPrefs?.remove(_cacheKey(key));
  });

  static Future<void> clearAllCache() {
    _cacheGeneration++;
    clearAllMemoryCache();
    final privateImages = PrivateImageDiskCache.clearIfInitialized();
    return _serializeCache(() async {
      await privateImages;
      await initialize();
      await _hiveBox?.clear();
      final prefs = _cachedPrefs!;
      for (final key
          in prefs
              .getKeys()
              .where((key) => key.startsWith('offline_cache_'))
              .toList()) {
        await prefs.remove(key);
      }
    });
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
  final String? ownerUid;
  final String path;
  final Map<String, dynamic>? data; // null = xóa (delete)
  final bool isDelete;
  final int timestamp;

  _SyncTask({
    required this.path,
    this.ownerUid,
    this.data,
    this.isDelete = false,
    required this.timestamp,
  });

  factory _SyncTask.fromJson(Map<String, dynamic> json) => _SyncTask(
    path: json['path'] as String,
    ownerUid: json['ownerUid'] as String?,
    data: json['data'] != null
        ? Map<String, dynamic>.from(json['data'] as Map)
        : null,
    isDelete: json['isDelete'] as bool? ?? false,
    timestamp: json['timestamp'] as int,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'ownerUid': ownerUid,
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
  OfflineSyncQueue._()
    : _uidForTesting = null,
      _sendForTesting = null,
      _onlineForTesting = null;

  @visibleForTesting
  OfflineSyncQueue.forTesting(
    Box box, {
    required String? Function() currentUid,
    required Future<void> Function(String, Map<String, dynamic>?) send,
    required Future<bool> Function() isOnline,
  }) : _box = box,
       _uidForTesting = currentUid,
       _sendForTesting = send,
       _onlineForTesting = isOnline;

  final String? Function()? _uidForTesting;
  final Future<void> Function(String, Map<String, dynamic>?)? _sendForTesting;
  final Future<bool> Function()? _onlineForTesting;
  String? get _currentUid => _uidForTesting != null
      ? _uidForTesting()
      : FirebaseAuth.instance.currentUser?.uid;

  Future<void> _send(String path, Map<String, dynamic>? data) async {
    if (_sendForTesting != null) return _sendForTesting(path, data);
    final ref = FirebaseDatabase.instance.ref(path);
    if (data == null) {
      await ref.remove();
    } else {
      await ref.update(data);
    }
  }

  @visibleForTesting
  Future<void> syncForTesting() => _trySyncNow();

  static const String _hiveBoxName = 'offline_sync_queue';
  static const String _queueKey = 'pending_tasks';
  static const int _maxQueueSize = 200;

  Box? _box;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  Future<void>? _starting;
  Future<void> _queueWork = Future<void>.value();

  // Tuần tự hóa đọc/sửa/ghi Hive để không ghi đè lệnh mới khi đang sync.
  Future<T> _withQueueLock<T>(Future<T> Function() work) {
    final task = _queueWork.then((_) => work());
    _queueWork = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  /// Khởi động listener theo dõi kết nối mạng.
  /// Gọi 1 lần duy nhất trong `main()` hoặc bootstrap của app.
  Future<void> startListening() async {
    if (_connectivitySub != null) return;
    if (_starting != null) return _starting;
    final task = _startListening();
    _starting = task;
    try {
      await task;
    } finally {
      _starting = null;
    }
  }

  Future<void> _startListening() async {
    await _ensureBox();

    // Thử sync ngay khi start (trường hợp app khởi động lại khi đang có mạng)
    _trySyncNow();

    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint(
          '[SyncQueue] Phát hiện có mạng — bắt đầu đồng bộ hàng đợi...',
        );
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
    final ownerUid = _currentUid;
    if (ownerUid == null) throw StateError('Authentication required for sync');
    final isOnline = await _checkConnectivity();
    if (_currentUid != ownerUid) {
      throw StateError('Account changed during enqueue');
    }
    if (isOnline) {
      try {
        await _send(path, data);
        debugPrint('[SyncQueue] Ghi online thành công: $path');
        return;
      } catch (e) {
        debugPrint(
          '[SyncQueue] Ghi online thất bại ($path), đẩy vào hàng đợi: $e',
        );
      }
    }
    await _enqueue(
      _SyncTask(
        path: path,
        ownerUid: ownerUid,
        data: data,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Đưa một task vào hàng đợi Hive.
  Future<void> _enqueue(_SyncTask task) => _withQueueLock(() async {
    await _ensureBox();
    final raw = _box!.get(_queueKey);
    final List<dynamic> current = raw != null
        ? List<dynamic>.from(jsonDecode(raw as String))
        : [];

    if (current.length >= _maxQueueSize) {
      // Không âm thầm bỏ dữ liệu chưa gửi khi hàng đợi đầy.
      throw StateError('Offline sync queue is full');
    }

    current.add(task.toJson());
    await _box!.put(_queueKey, jsonEncode(current));
    debugPrint(
      '[SyncQueue] Đã thêm vào hàng đợi: ${task.path} (tổng: ${current.length})',
    );
  });

  /// Lấy số lượng task đang chờ trong hàng đợi.
  Future<int> get pendingCount async {
    await _ensureBox();
    final raw = _box!.get(_queueKey);
    if (raw == null) return 0;
    final list = List<dynamic>.from(jsonDecode(raw as String));
    final uid = _currentUid;
    return uid == null
        ? 0
        : list.where((item) => item is Map && item['ownerUid'] == uid).length;
  }

  /// Thực hiện đồng bộ toàn bộ hàng đợi lên Firebase.
  Future<void> _trySyncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final ownerUid = _currentUid;
      if (ownerUid == null) return;
      final tasks = await _withQueueLock(() async {
        await _ensureBox();
        final raw = _box!.get(_queueKey);
        return raw == null
            ? <dynamic>[]
            : List<dynamic>.from(jsonDecode(raw as String));
      });
      for (final taskJson in tasks) {
        if (_currentUid != ownerUid) break;
        try {
          final task = _SyncTask.fromJson(
            Map<String, dynamic>.from(taskJson as Map),
          );
          // Giữ dữ liệu cũ không rõ chủ để khôi phục thủ công, không tự gán chủ mới.
          if (task.ownerUid != ownerUid) continue;
          if (_currentUid != ownerUid) break;
          if (!task.isDelete && task.data == null) continue;
          await _send(task.path, task.isDelete ? null : task.data);
          // Chỉ xóa đúng lệnh đã gửi, giữ các lệnh mới thêm trong lúc chờ mạng.
          await _withQueueLock(() async {
            final raw = _box!.get(_queueKey);
            final current = raw == null
                ? <dynamic>[]
                : List<dynamic>.from(jsonDecode(raw as String));
            final encoded = jsonEncode(taskJson);
            final index = current.indexWhere(
              (entry) => jsonEncode(entry) == encoded,
            );
            if (index >= 0) current.removeAt(index);
            if (current.isEmpty) {
              await _box!.delete(_queueKey);
            } else {
              await _box!.put(_queueKey, jsonEncode(current));
            }
          });
        } catch (_) {
          debugPrint(
            '[SyncQueue] Không đồng bộ được lệnh, giữ lại trên thiết bị.',
          );
          break;
        }
      }
    } catch (_) {
      debugPrint('[SyncQueue] Không đọc được hàng đợi đồng bộ.');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      if (_onlineForTesting != null) return _onlineForTesting();
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
