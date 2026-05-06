import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static Database? _database;
  static SharedPreferences? _cachedPrefs;
  static Future<void>? _initializingPrefs;
  static const int _defaultSchemaVersion = 1;

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

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'offline_cache.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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

    await db.execute('CREATE INDEX idx_chat_house ON chat_cache (house_id)');
    await db.execute('CREATE INDEX idx_diary_house ON diary_cache (house_id)');
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
    _cachedPrefs = prefs;
    await prefs.setString('offline_cache_$key', jsonEncode(data));
  }

  static Future<dynamic> loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
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

  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final keys = prefs.getKeys().where((k) => k.startsWith('offline_cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    await _database?.close();
    _database = null;
  }
}
