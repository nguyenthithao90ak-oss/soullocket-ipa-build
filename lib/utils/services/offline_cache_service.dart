// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'offline_cache_policy.dart';

dynamic _decodeJson(String source) => jsonDecode(source);

String _encodeCachePayload(Map<String, dynamic> payload) => jsonEncode(payload);

Map<String, dynamic>? _decodeCachePayload(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}

const OfflineCachePolicy _offlineCachePolicy = OfflineCachePolicy();

Map<String, dynamic>? _resolveCachePayload(String? raw) {
  if (raw == null) {
    return null;
  }
  final payload = _decodeCachePayload(raw);
  if (payload == null) {
    return null;
  }
  final int ts = payload['ts'] ?? 0;
  if (_offlineCachePolicy.isExpired(ts)) {
    return null;
  }
  return payload;
}

class OfflineCacheService {
  static const String _prefix = 'il_offline_cache_';
  static const int _maxCacheAgeMs = OfflineCachePolicy.maxCacheAgeMs; // 7 ngày
  static const String _dbName = 'soullocket_offline_cache.db';
  static const String _cacheTable = 'offline_cache_entries';

  static SharedPreferences? _prefsInstance;
  static Database? _dbInstance;
  static Future<Database?>? _dbFuture;

  // Cho phép truyền thẳng prefs đã lấy từ main() vào để giảm thời gian await
  static void initSync(SharedPreferences prefs) {
    _prefsInstance = prefs;
  }

  static SharedPreferences? getPrefsSync() => _prefsInstance;

  static Future<void> ensureWarmCache() async {
    await _getPrefs();
  }

  static int get maxCacheAgeMs => _maxCacheAgeMs;

  static String storageKey(String key) => _storageKey(key);

  static Future<List<String>> listStoredKeys() async {
    final prefs = await _getPrefs();
    return prefs
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false)
      ..sort();
  }

  static String _storageKey(String key) => '$_prefix$key';

  static bool _shouldUseDatabase(String key) =>
      _offlineCachePolicy.shouldUseDatabase(key);

  static Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ??= await SharedPreferences.getInstance();
  }

  static Future<Database?> _getDatabase() async {
    if (kIsWeb) return null;
    if (_dbInstance != null) return _dbInstance;
    if (_dbFuture != null) return _dbFuture!;
    _dbFuture = _openDatabase();
    final db = await _dbFuture!;
    _dbInstance = db;
    _dbFuture = null;
    return db;
  }

  static Future<Database?> _openDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final db = await openDatabase(
        p.join(dbPath, _dbName),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_cacheTable (
              cache_key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              ts INTEGER NOT NULL
            )
          ''');
        },
      );
      return db;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCacheToDatabase(
    String key,
    String encodedPayload,
    int timestamp,
  ) async {
    final db = await _getDatabase();
    if (db == null) return;
    await db.insert(
      _cacheTable,
      {
        'cache_key': key,
        'payload': encodedPayload,
        'ts': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> _loadRawCacheFromDatabase(String key) async {
    final db = await _getDatabase();
    if (db == null) return null;
    final rows = await db.query(
      _cacheTable,
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload'] as String?;
  }

  static Future<void> _removeCacheFromDatabase(String key) async {
    final db = await _getDatabase();
    if (db == null) return;
    await db.delete(
      _cacheTable,
      where: 'cache_key = ?',
      whereArgs: [key],
    );
  }

  static dynamic decodeJsonSync(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }

  // Lưu dữ liệu vào cache
  static Future<void> saveCache(String key, dynamic data) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'ts': ts,
        'data': data,
      };
      final encoded = await compute(_encodeCachePayload, payload);
      if (_shouldUseDatabase(key)) {
        await _saveCacheToDatabase(key, encoded, ts);
        final prefs = _prefsInstance;
        if (prefs != null) {
          await prefs.remove(_storageKey(key));
        }
        return;
      }
      final prefs = await _getPrefs();
      await prefs.setString(_storageKey(key), encoded);
    } catch (_) {}
  }

  // Đọc dữ liệu từ cache đồng bộ (nếu prefs đã được init)
  static dynamic loadCacheSync(String key) {
    try {
      final prefs = getPrefsSync();
      if (prefs == null) return null;
      final raw = prefs.getString(_storageKey(key));
      if (raw == null) return null;

      final payload = _resolveCachePayload(raw);
      if (payload == null) {
        prefs.remove(_storageKey(key));
        return null;
      }

      return payload['data'];
    } catch (e) {
      return null;
    }
  }

  // Đọc dữ liệu từ cache
  static Future<dynamic> loadCache(String key) async {
    try {
      String? raw;
      if (_shouldUseDatabase(key)) {
        raw = await _loadRawCacheFromDatabase(key);
      }
      raw ??= (await _getPrefs()).getString(_storageKey(key));
      if (raw == null) return null;

      final payload = await compute(_resolveCachePayload, raw);
      if (payload == null) {
        await removeCache(key);
        return null;
      }

      if (_shouldUseDatabase(key)) {
        final prefs = _prefsInstance;
        if (prefs != null && prefs.containsKey(_storageKey(key))) {
          unawaited(prefs.remove(_storageKey(key)));
        }
      }

      return payload['data'];
    } catch (_) {
      return null;
    }
  }

  // Xoá cache cụ thể
  static Future<void> removeCache(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey(key));
    if (_shouldUseDatabase(key)) {
      await _removeCacheFromDatabase(key);
    }
  }

  // Xoá toàn bộ cache
  static Future<void> clearAllCache() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (String key in keys) {
      await prefs.remove(key);
    }
    final db = await _getDatabase();
    if (db != null) {
      await db.delete(_cacheTable);
    }
  }
}
