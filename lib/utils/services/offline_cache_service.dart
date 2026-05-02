import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class OfflineCacheService {
  static final OfflineCacheService instance = OfflineCacheService._internal();
  static Database? _database;

  OfflineCacheService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'offline_cache.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for Chat caching
    await db.execute('''
      CREATE TABLE chat_cache (
        id TEXT PRIMARY KEY,
        house_id TEXT,
        payload TEXT,
        updated_at INTEGER
      )
    ''');

    // Table for Diary caching
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

  Future<void> cacheData(String table, String id, String houseId, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      table,
      {
        'id': id,
        'house_id': houseId,
        'payload': data.toString(), // Simplify for now, usually use jsonEncode
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedData(String table, String houseId) async {
    final db = await database;
    return await db.query(
      table,
      where: 'house_id = ?',
      whereArgs: [houseId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> clearCache(String table, {String? houseId}) async {
    final db = await database;
    if (houseId != null) {
      await db.delete(table, where: 'house_id = ?', whereArgs: [houseId]);
    } else {
      await db.delete(table);
    }
  }
}
