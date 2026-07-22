import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

class SyncQueueSummary {
  final int pendingCount;
  final int syncingCount;
  final int failedCount;
  final int syncedCount;

  const SyncQueueSummary({
    required this.pendingCount,
    required this.syncingCount,
    required this.failedCount,
    required this.syncedCount,
  });

  int get activeCount => pendingCount + syncingCount + failedCount;
  bool get hasUnsyncedData => activeCount > 0;
}

class _MemoryCacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _MemoryCacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Hỗ trợ read-through cache: lưu snapshot từ Firebase Realtime vào local SQLite
/// mỗi khi có dữ liệu mới. Khi app offline hoặc load lại, ưu tiên đọc từ cache local
/// trước, sau đó mới gọi Firebase. Giúp giảm 50-70% Firebase reads.
class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static const _databaseName = 'soullocket_offline.db';
  static const _databaseVersion = 4; // nâng lên v4 để tạo indexes cho SQLite
  static const _queueStatusPending = 'pending';
  static const _queueStatusSyncing = 'syncing';
  static const _queueStatusFailed = 'failed';
  static const _queueStatusSynced = 'synced';
  static const int _retryBaseDelayMs = 30000;
  static const int _retryMaxDelayMs = 300000;
  static const int _maxRetryCount = 6;

  final StreamController<SyncQueueSummary> _queueController =
      StreamController<SyncQueueSummary>.broadcast();

  Database? _db;
  Future<void>? _initializing;
  bool _isSyncing = false;
  SyncQueueSummary? _lastQueueSummary;

  // RAM cache nhanh cho read-through — giới hạn 100 entries
  static final Map<String, _MemoryCacheEntry> _readCache = {};
  static const int _readCacheMaxSize = 100;
  static const Duration _defaultCacheTtl = Duration(minutes: 15);

  Stream<SyncQueueSummary> get queueSummaryStream => _queueController.stream;

  Future<void> initialize() async {
    if (_db != null || kIsWeb) {
      return;
    }
    if (_initializing != null) {
      await _initializing;
      return;
    }

    final task = _openDatabase();
    _initializing = task;
    try {
      await task;
      // Dọn 1 lần cache quá hạn khi khởi tạo (không cần timer —
      // các lần get/set sau sẽ tự dọn entry hết hạn khi gặp)
      await purgeExpiredCache();
    } finally {
      if (identical(_initializing, task)) {
        _initializing = null;
      }
    }
  }

  Future<void> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }
      },
    );

    await _publishQueueSummary();
    unawaited(syncPendingData());
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        houseId TEXT,
        text TEXT,
        senderId TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE diaries (
        id TEXT PRIMARY KEY,
        houseId TEXT,
        content TEXT,
        mood TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        path TEXT,
        action TEXT,
        payload TEXT,
        timestamp INTEGER,
        operationId TEXT,
        entityType TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastError TEXT,
        createdAt INTEGER,
        syncedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE cache_entries (
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    final indexes = <String>[
      'CREATE INDEX IF NOT EXISTS idx_messages_house_time ON messages (houseId, timestamp DESC);',
      'CREATE INDEX IF NOT EXISTS idx_diaries_house_time ON diaries (houseId, timestamp DESC);',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status, createdAt);',
      'CREATE INDEX IF NOT EXISTS idx_cache_entries_expires ON cache_entries (expires_at);',
    ];
    for (final statement in indexes) {
      try {
        await db.execute(statement);
      } catch (e) {
        debugPrint('[LocalDatabaseService] Index creation info: $e');
      }
    }
  }

  Future<void> _upgradeToV2(Database db) async {
    final statements = <String>[
      'ALTER TABLE sync_queue ADD COLUMN operationId TEXT',
      'ALTER TABLE sync_queue ADD COLUMN entityType TEXT',
      "ALTER TABLE sync_queue ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
      'ALTER TABLE sync_queue ADD COLUMN retryCount INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE sync_queue ADD COLUMN lastError TEXT',
      'ALTER TABLE sync_queue ADD COLUMN createdAt INTEGER',
      'ALTER TABLE sync_queue ADD COLUMN syncedAt INTEGER',
    ];

    for (final statement in statements) {
      try {
        await db.execute(statement);
      } catch (_) {}
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      '''
      UPDATE sync_queue
      SET
        operationId = COALESCE(operationId, id),
        entityType = COALESCE(entityType, 'generic'),
        status = COALESCE(status, ?),
        retryCount = COALESCE(retryCount, 0),
        createdAt = COALESCE(createdAt, timestamp, ?)
      ''',
      [_queueStatusPending, now],
    );
  }

  Future<void> _upgradeToV3(Database db) async {
    final statements = <String>[
      '''
      CREATE TABLE IF NOT EXISTS cache_entries (
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL DEFAULT 0
      )
      ''',
    ];
    for (final statement in statements) {
      try {
        await db.execute(statement);
      } catch (_) {}
    }
  }

  Future<void> _upgradeToV4(Database db) async {
    await _createIndexes(db);
  }

  // ───────────────────────────────────────────────────────────
  // Read-through cache: ưu tiên local → fallback Firebase
  // ───────────────────────────────────────────────────────────

  /// Lưu cache entry vào cả RAM (nhanh) và SQLite (bền).
  Future<void> setCacheEntry(String key, dynamic data, {Duration? ttl}) async {
    final resolvedTtl = ttl ?? _defaultCacheTtl;
    // RAM — LRU eviction nếu quá tải
    if (_readCache.length >= _readCacheMaxSize) {
      String? oldestKey;
      DateTime? oldestTime;
      for (final entry in _readCache.entries) {
        if (oldestTime == null || entry.value.expiresAt.isBefore(oldestTime)) {
          oldestTime = entry.value.expiresAt;
          oldestKey = entry.key;
        }
      }
      if (oldestKey != null) _readCache.remove(oldestKey);
    }
    _readCache[key] = _MemoryCacheEntry(
      data: data,
      expiresAt: DateTime.now().add(resolvedTtl),
    );
    // SQLite
    final db = await _requireDatabase();
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'cache_entries',
      {
        'cache_key': key,
        'data': jsonEncode(data),
        'cached_at': now,
        'expires_at': now + resolvedTtl.inMilliseconds,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Đọc từ cache (RAM → SQLite). Trả về null nếu miss.
  Future<dynamic> getCacheEntry(String key) async {
    // 1. RAM cache trước
    final ramEntry = _readCache[key];
    if (ramEntry != null && !ramEntry.isExpired) {
      return ramEntry.data;
    }
    if (ramEntry != null) _readCache.remove(key);

    // 2. SQLite cache
    final db = await _requireDatabase();
    if (db == null) return null;
    final rows = await db.query(
      'cache_entries',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final expiresAt = row['expires_at'] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiresAt > 0 && now > expiresAt) {
      await db
          .delete('cache_entries', where: 'cache_key = ?', whereArgs: [key]);
      return null;
    }

    final raw = row['data'] as String?;
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      // RAM warm-up
      _readCache[key] = _MemoryCacheEntry(
        data: data,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
      );
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Xoá cache entry
  Future<void> clearCacheEntry(String key) async {
    _readCache.remove(key);
    final db = await _requireDatabase();
    if (db == null) return;
    await db.delete('cache_entries', where: 'cache_key = ?', whereArgs: [key]);
  }

  /// Xoá toàn bộ cache cũ (quá hạn)
  Future<void> purgeExpiredCache() async {
    final db = await _requireDatabase();
    if (db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete('cache_entries',
        where: 'expires_at > 0 AND expires_at < ?', whereArgs: [now]);
    // Xoá luôn RAM entries hết hạn
    _readCache.removeWhere((_, entry) => entry.isExpired);
  }

  Future<Database?> _requireDatabase() async {
    if (kIsWeb) return null;
    if (_db == null) {
      await initialize();
    }
    return _db;
  }

  Future<void> cacheMessage(
    String houseId,
    Map<String, dynamic> msgData,
  ) async {
    final db = await _requireDatabase();
    if (db == null) return;

    await db.insert(
      'messages',
      {
        'id': msgData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'houseId': houseId,
        'text': msgData['text'] ?? '',
        'senderId': msgData['senderId'] ?? '',
        'timestamp':
            msgData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String houseId) async {
    final db = await _requireDatabase();
    if (db == null) return const <Map<String, dynamic>>[];
    return db.query(
      'messages',
      where: 'houseId = ?',
      whereArgs: [houseId],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  Future<void> enqueueSync(
    String path,
    String action,
    String payload, {
    String? operationId,
    String? entityType,
  }) async {
    final db = await _requireDatabase();
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedId = (operationId?.trim().isNotEmpty ?? false)
        ? operationId!.trim()
        : '$now';
    await db.insert(
      'sync_queue',
      {
        'id': resolvedId,
        'path': path,
        'action': action.toUpperCase(),
        'payload': payload,
        'timestamp': now,
        'operationId': resolvedId,
        'entityType': (entityType ?? 'generic').trim(),
        'status': _queueStatusPending,
        'retryCount': 0,
        'lastError': null,
        'createdAt': now,
        'syncedAt': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _publishQueueSummary();
    unawaited(syncPendingData());
  }

  Future<SyncQueueSummary> getQueueSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastQueueSummary != null) {
      return _lastQueueSummary!;
    }

    final db = await _requireDatabase();
    if (db == null) {
      _lastQueueSummary = const SyncQueueSummary(
        pendingCount: 0,
        syncingCount: 0,
        failedCount: 0,
        syncedCount: 0,
      );
      return _lastQueueSummary!;
    }

    Future<int> countStatus(String status) async {
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM sync_queue WHERE status = ?',
        [status],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }

    final summary = SyncQueueSummary(
      pendingCount: await countStatus(_queueStatusPending),
      syncingCount: await countStatus(_queueStatusSyncing),
      failedCount: await countStatus(_queueStatusFailed),
      syncedCount: await countStatus(_queueStatusSynced),
    );
    _lastQueueSummary = summary;
    return summary;
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) {
      return;
    }

    final db = await _requireDatabase();
    if (db == null) return;

    final queue = await db.query(
      'sync_queue',
      where: 'status IN (?, ?)',
      whereArgs: [_queueStatusPending, _queueStatusFailed],
      orderBy: 'createdAt ASC, timestamp ASC',
    );
    if (queue.isEmpty) {
      await _publishQueueSummary();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await _publishQueueSummary();
      return;
    }

    _isSyncing = true;
    final fbDb = FirebaseDatabase.instance;

    try {
      var shouldStopProcessing = false;
      for (final task in queue) {
        if (shouldStopProcessing) {
          break;
        }

        final id = task['id'] as String;
        final taskPath = task['path'] as String;
        final action = (task['action'] as String).toUpperCase();
        final payloadStr = task['payload'] as String;
        final retryCount = (task['retryCount'] as int?) ?? 0;
        final status = task['status']?.toString() ?? _queueStatusPending;
        final lastAttemptAt = (task['timestamp'] as int?) ?? 0;
        if (retryCount >= _maxRetryCount) {
          continue;
        }
        if (status == _queueStatusFailed &&
            !_shouldRetryFailedTask(retryCount, lastAttemptAt)) {
          continue;
        }

        await db.update(
          'sync_queue',
          {
            'status': _queueStatusSyncing,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await _publishQueueSummary();

        try {
          final dynamic data =
              payloadStr.isEmpty ? null : json.decode(payloadStr);

          switch (action) {
            case 'SET':
              await fbDb.ref(taskPath).set(data);
              break;
            case 'UPDATE':
              await fbDb
                  .ref(taskPath)
                  .update(Map<String, dynamic>.from(data as Map));
              break;
            case 'PUSH':
              await fbDb.ref(taskPath).push().set(data);
              break;
            case 'DELETE':
              await fbDb.ref(taskPath).remove();
              break;
            default:
              throw StateError('Unknown sync action: $action');
          }

          await db.update(
            'sync_queue',
            {
              'status': _queueStatusSynced,
              'lastError': null,
              'syncedAt': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          debugPrint('[SyncQueue] Synced $action -> $taskPath');
        } catch (e) {
          final nextRetryCount = retryCount + 1;
          final retryable = _isRetryableError(e);
          final reachedRetryLimit = nextRetryCount >= _maxRetryCount;
          await db.update(
            'sync_queue',
            {
              'status': _queueStatusFailed,
              'retryCount': nextRetryCount,
              'lastError': AppErrorMapper.cleanMessage(e),
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          debugPrint(
              '[SyncQueue] Failed $action -> $taskPath: ${AppErrorMapper.cleanMessage(e)}');
          if (!retryable || reachedRetryLimit) {
            shouldStopProcessing = _isBlockingQueueError(e);
          }
        } finally {
          await _publishQueueSummary();
        }
      }

      await _purgeOldSyncedRows(db);
    } finally {
      _isSyncing = false;
      await _publishQueueSummary();
    }
  }

  bool _shouldRetryFailedTask(int retryCount, int lastAttemptAt) {
    if (retryCount <= 0 || lastAttemptAt <= 0) {
      return true;
    }
    final multiplier = retryCount > 10 ? 10 : retryCount;
    final delayMs = (_retryBaseDelayMs * multiplier).clamp(
      _retryBaseDelayMs,
      _retryMaxDelayMs,
    );
    return DateTime.now().millisecondsSinceEpoch - lastAttemptAt >= delayMs;
  }

  bool _isRetryableError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission-denied') ||
        normalized.contains('permission denied') ||
        normalized.contains('invalid-argument') ||
        normalized.contains('invalid argument') ||
        normalized.contains('unauthenticated') ||
        normalized.contains('app check') ||
        normalized.contains('too many attempts')) {
      return false;
    }
    return normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('timeout') ||
        normalized.contains('unavailable') ||
        normalized.contains('disconnected') ||
        normalized.contains('connection');
  }

  bool _isBlockingQueueError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('unauthenticated') ||
        normalized.contains('permission-denied') ||
        normalized.contains('permission denied') ||
        normalized.contains('app check');
  }

  Future<void> _purgeOldSyncedRows(Database db) async {
    final syncedRows = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [_queueStatusSynced],
      orderBy: 'syncedAt DESC',
    );
    if (syncedRows.length <= 120) {
      return;
    }

    final overflow = syncedRows.skip(120);
    for (final row in overflow) {
      await db.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _publishQueueSummary() async {
    if (_queueController.isClosed) {
      return;
    }
    _lastQueueSummary = null;
    _queueController.add(await getQueueSummary(forceRefresh: true));
  }
}
