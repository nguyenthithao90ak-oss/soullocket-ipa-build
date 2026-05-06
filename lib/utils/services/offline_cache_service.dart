import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static Database? _database;
  static SharedPreferences? _cachedPrefs;
  static Future<void>? _initializingPrefs;
  static const int _defaultSchemaVersion = 1;
  static const int _retryBaseDelayMs = 30000;
  static const int _retryMaxDelayMs = 300000;
  static const int _maxRetryCount = 6;
  static bool _isSyncing = false;
  static const String _queueStatusPending = 'pending';
  static const String _queueStatusSyncing = 'syncing';
  static const String _queueStatusSynced = 'synced';
  static const String _queueStatusFailed = 'failed';
  static final StreamController<Map<String, dynamic>> _queueController = StreamController<Map<String, dynamic>>.broadcast();
  static Map<String, dynamic>? _lastQueueSummary;

  OfflineCacheService._internal();

  static SharedPreferences? getPrefsSync() => _cachedPrefs;

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

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database?> _requireDatabase() async {
    try {
      return await database;
    } catch (e) {
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'offline_cache.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              path TEXT,
              action TEXT,
              payload TEXT,
              status TEXT,
              createdAt INTEGER,
              timestamp INTEGER,
              retryCount INTEGER,
              lastError TEXT,
              syncedAt INTEGER
            )
          ''');
        }
      }
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_cache (
        id TEXT PRIMARY KEY,
        house_id TEXT,
        payload TEXT,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE diary_cache (
        id TEXT PRIMARY KEY,
        house_id TEXT,
        payload TEXT,
        updated_at INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        path TEXT,
        action TEXT,
        payload TEXT,
        status TEXT,
        createdAt INTEGER,
        timestamp INTEGER,
        retryCount INTEGER,
        lastError TEXT,
        syncedAt INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_chat_house ON chat_cache (house_id)');
    await db.execute('CREATE INDEX idx_diary_house ON diary_cache (house_id)');
  }

  static Future<void> syncPendingData() async {
    if (_isSyncing) {
      return;
    }

    final db = await instance._requireDatabase();
    if (db == null) return;

    final queue = await db.query(
      'sync_queue',
      where: 'status IN (?, ?)',
      whereArgs: [_queueStatusPending, _queueStatusFailed],
      orderBy: 'createdAt ASC, timestamp ASC',
    );
    if (queue.isEmpty) {
      await instance._publishQueueSummary();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await instance._publishQueueSummary();
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
            !instance._shouldRetryFailedTask(retryCount, lastAttemptAt)) {
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
        await instance._publishQueueSummary();

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
          final retryable = instance._isRetryableError(e);
          final reachedRetryLimit = nextRetryCount >= _maxRetryCount;
          await db.update(
            'sync_queue',
            {
              'status': _queueStatusFailed,
              'retryCount': nextRetryCount,
              'lastError': e.toString(),
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          debugPrint('[SyncQueue] Failed $action -> $taskPath: $e');
          if (!retryable || reachedRetryLimit) {
            shouldStopProcessing = instance._isBlockingQueueError(e);
          }
        } finally {
          await instance._publishQueueSummary();
        }
      }

      await instance._purgeOldSyncedRows(db);
    } finally {
      _isSyncing = false;
      await instance._publishQueueSummary();
    }
  }

  Future<void> cacheData(
    String table,
    String id,
    String houseId,
    Map<String, dynamic> data, {
    String source = 'local',
    int schemaVersion = _defaultSchemaVersion,
    int? staleAfterMs,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      table,
      {
        'id': id,
        'house_id': houseId,
        'payload': jsonEncode({
          'data': data,
          'meta': {
            'cachedAt': now,
            'updatedAt': now,
            'source': source,
            'schemaVersion': schemaVersion,
            'staleAfterMs': staleAfterMs,
          },
        }),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedData(
    String table,
    String houseId,
  ) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'house_id = ?',
      whereArgs: [houseId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_decodeCacheRow).toList();
  }

  Future<void> clearCache(String table, {String? houseId}) async {
    final db = await database;
    if (houseId != null) {
      await db.delete(table, where: 'house_id = ?', whereArgs: [houseId]);
    } else {
      await db.delete(table);
    }
  }

  static Future<void> saveCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_cache_$key', jsonEncode(data));
  }

  static Future<dynamic> loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_cache_$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static dynamic loadCacheSync(String key) {
    final raw = _cachedPrefs?.getString('offline_cache_$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeCacheRow(Map<String, Object?> row) {
    final payloadRaw = row['payload']?.toString() ?? '';
    final updatedAt = (row['updated_at'] as int?) ?? 0;
    Map<String, dynamic>? decodedPayload;
    if (payloadRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(payloadRaw);
        if (parsed is Map<String, dynamic>) {
          decodedPayload = parsed;
        }
      } catch (_) {}
    }

    final meta = decodedPayload?['meta'];
    final resolvedMeta = meta is Map<String, dynamic>
        ? Map<String, dynamic>.from(meta)
        : <String, dynamic>{
            'cachedAt': updatedAt,
            'updatedAt': updatedAt,
            'source': 'legacy',
            'schemaVersion': _defaultSchemaVersion,
          };
    final data = decodedPayload?['data'];

    return {
      'id': row['id'],
      'house_id': row['house_id'],
      'payload': data ?? payloadRaw,
      'data': data,
      'meta': resolvedMeta,
      'updated_at': updatedAt,
      'is_stale': _isCacheStale(resolvedMeta, updatedAt),
    };
  }

  bool _isCacheStale(Map<String, dynamic> meta, int fallbackUpdatedAt) {
    final staleAfterMs = meta['staleAfterMs'];
    if (staleAfterMs is! int || staleAfterMs <= 0) {
      return false;
    }
    final updatedAt = (meta['updatedAt'] as int?) ?? fallbackUpdatedAt;
    if (updatedAt <= 0) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch - updatedAt >= staleAfterMs;
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
    final summary = await getQueueSummary(forceRefresh: true);
    _queueController.add(summary);
  }

  Future<Map<String, dynamic>> getQueueSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastQueueSummary != null) return _lastQueueSummary!;
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE status != ?', [_queueStatusSynced])) ?? 0;
    _lastQueueSummary = {'pendingCount': count};
    return _lastQueueSummary!;
  }

  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('offline_cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    await _database?.close();
    _database = null;
  }
}
