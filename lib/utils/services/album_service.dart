import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/models/album_item.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'daily_quest_service.dart';
import 'offline_cache_service.dart';
import 'purchase_service.dart';

class AlbumService {
  static final AlbumService _instance = AlbumService._internal();

  factory AlbumService() => _instance;
  AlbumService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static const int totalCapFree = 365;
  static const int totalCapPro = 1000;
  static const int totalCapLifetimeVip = 1500;
  static const int dailyLimitFree = 10;
  static const int dailyLimitPro = 30;
  static const int trashExpiryMs = 3 * 24 * 60 * 60 * 1000;
  static const int albumStreamPageSize = 120;

  static const Map<String, Map<String, String>> _holidayMap = {
    '01-01': {'icon': '🎆', 'text': 'Tet Duong lich'},
    '02-14': {'icon': '💘', 'text': 'Valentine'},
    '03-08': {'icon': '🌷', 'text': 'Quoc te Phu nu'},
    '04-30': {'icon': '🇻🇳', 'text': 'Giai phong mien Nam'},
    '05-01': {'icon': '🛠️', 'text': 'Quoc te Lao dong'},
    '06-01': {'icon': '🧸', 'text': 'Quoc te Thieu nhi'},
    '10-20': {'icon': '💐', 'text': 'Phu nu Viet Nam'},
    '11-20': {'icon': '📚', 'text': 'Nha giao Viet Nam'},
    '12-24': {'icon': '🎄', 'text': 'Giang sinh'},
    '12-31': {'icon': '✨', 'text': 'Cuoi nam'},
  };

  DatabaseReference _albumCountRef(String houseId) =>
      _dbRef.child('houses/$houseId/albumCount');

  Future<void> migrateAlbumCounter(String houseId) async {
    final trimmedHouseId = houseId.trim();
    if (trimmedHouseId.isEmpty) return;

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final migrationKey = 'album_counter_migrated_$trimmedHouseId';
    if (prefs.getBool(migrationKey) == true) return;

    final snap = await _dbRef.child('houses/$trimmedHouseId/album').get();
    if (!snap.exists) {
      await _albumCountRef(trimmedHouseId).set(0);
      await prefs.setBool(migrationKey, true);
      return;
    }

    final count = snap.value is Map ? (snap.value as Map).length : 0;
    await _albumCountRef(trimmedHouseId).set(count);
    await prefs.setBool(migrationKey, true);
  }

  Future<int> _getAlbumCount(String houseId) async {
    final countSnap = await _albumCountRef(houseId).get();
    final storedCount = (countSnap.value as num?)?.toInt();
    if (storedCount != null && storedCount >= 0) {
      return storedCount;
    }

    final albumSnap = await _dbRef.child('houses/$houseId/album').get();
    final fallbackCount = albumSnap.exists && albumSnap.value is Map
        ? (albumSnap.value as Map).length
        : 0;
    await _albumCountRef(houseId).set(fallbackCount);
    return fallbackCount;
  }

  Future<void> _changeAlbumCount(String houseId, int delta) async {
    if (delta == 0) return;
    await _albumCountRef(houseId).runTransaction((current) {
      final next = ((current as num?)?.toInt() ?? 0) + delta;
      return Transaction.success(next < 0 ? 0 : next);
    });
  }

  List<Map<String, String>> getDateHighlights(
    int timestamp, {
    DateTime? anniversaryDate,
    bool includeSpecialDays = true,
  }) {
    if (!includeSpecialDays) return const <Map<String, String>>[];

    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final mmdd =
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final tags = <Map<String, String>>[];

    if (_holidayMap.containsKey(mmdd)) {
      tags.add(_holidayMap[mmdd]!);
    }

    if (anniversaryDate != null &&
        d.month == anniversaryDate.month &&
        d.day == anniversaryDate.day) {
      if (d.year == anniversaryDate.year) {
        tags.add({'icon': '💝', 'text': 'Ngày bắt đầu yêu'});
      } else if (d.year > anniversaryDate.year) {
        final years = d.year - anniversaryDate.year;
        tags.add({'icon': '💍', 'text': 'Kỷ niệm $years năm yêu nhau'});
      }
    }

    return tags.take(3).toList();
  }

  Future<UploadGuardResult> checkUploadGuard({
    required String houseId,
    required VipAccessInfo access,
    required int fileCount,
    bool enforceLocalDailyLimit = true,
  }) async {
    final dailyLimit = access.dailyMemoryUploadLimit;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final today = DateTime.now().toLocal().toString().substring(0, 10);
    final todayKey = 'album_up_$today';
    final uploadedToday = prefs.getInt(todayKey) ?? 0;
    final currentTotal = await _getAlbumCount(houseId);

    final currentTotalCap = access.isVip
        ? (access.isLifetime ? totalCapLifetimeVip : totalCapPro)
        : totalCapFree;

    if (currentTotal >= currentTotalCap) {
      return UploadGuardResult.totalCapReached(currentTotal, currentTotalCap);
    }

    if (enforceLocalDailyLimit && uploadedToday >= dailyLimit) {
      return UploadGuardResult.dailyLimitReached(dailyLimit, access.isVip);
    }

    final remaining = dailyLimit - uploadedToday;
    if (enforceLocalDailyLimit && fileCount > remaining) {
      return UploadGuardResult.exceedsRemaining(remaining);
    }

    return UploadGuardResult.ok(uploadedToday, dailyLimit, todayKey);
  }

  Future<void> incrementDailyCount(String todayKey, int count) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final prev = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, prev + count);
  }

  Stream<List<AlbumItem>> streamAlbum(String houseId) {
    return _dbRef
        .child('houses/$houseId/album')
        .orderByChild('ts')
        .limitToLast(albumStreamPageSize)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return <AlbumItem>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <AlbumItem>[];

      final items = <AlbumItem>[];
      raw.forEach((key, value) {
        if (value is Map) {
          try {
            items.add(AlbumItem.fromJson(key.toString(), value));
          } catch (_) {}
        }
      });
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    }).handleError((error) {
      final code = (error as dynamic).code?.toString();
      if (code == 'permission-denied') {
        debugPrint('Album stream permission denied for house $houseId');
        return;
      }
      throw error;
    });
  }

  Future<List<AlbumItem>> fetchAlbumPage(
    String houseId, {
    int limit = 30,
    int? endBeforeTs,
  }) async {
    Query query = _dbRef.child('houses/$houseId/album').orderByChild('ts');
    if (endBeforeTs != null) {
      query = query.endAt(endBeforeTs - 1);
    }
    DataSnapshot snapshot;
    try {
      snapshot = await query.limitToLast(limit).get();
    } catch (error) {
      final code = (error as dynamic).code?.toString();
      if (code == 'permission-denied') {
        debugPrint('Album page permission denied for house $houseId');
        return const <AlbumItem>[];
      }
      rethrow;
    }
    if (!snapshot.exists || snapshot.value == null) {
      return const <AlbumItem>[];
    }
    final raw = snapshot.value;
    if (raw is! Map) {
      return const <AlbumItem>[];
    }

    final items = <AlbumItem>[];
    raw.forEach((key, value) {
      if (value is Map) {
        try {
          items.add(AlbumItem.fromJson(key.toString(), value));
        } catch (_) {}
      }
    });
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<String> addAlbumItem({
    required String houseId,
    required String url,
    required String role,
    required String authorName,
    String caption = '',
    String thumbUrl = '',
    String type = 'image',
  }) async {
    if (url.trim().isEmpty) throw 'URL không được để trống.';

    final now = DateTime.now().millisecondsSinceEpoch;
    final newRef = _dbRef.child('houses/$houseId/album').push();

    await newRef.set({
      'url': url.trim(),
      'thumbUrl': thumbUrl,
      'caption': caption.trim(),
      'role': role,
      'authorName': authorName,
      'ts': now,
      'timestamp': now,
      'type': type,
      'likes': 0,
    });
    await _changeAlbumCount(houseId, 1);

    // Record daily quest progress
    DailyQuestService().recordProgress('diary_entry');

    return newRef.key!;
  }

  Future<void> moveToTrash({
    required String houseId,
    required String itemId,
  }) async {
    final snap = await _dbRef.child('houses/$houseId/album/$itemId').get();
    if (!snap.exists) throw 'Ảnh không tồn tại.';

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = Map<String, dynamic>.from(snap.value as Map);
    data['deletedAt'] = now;
    data['purgeAt'] = now + trashExpiryMs;
    data['id'] = itemId;

    await _dbRef.child('houses/$houseId/album_trash/$itemId').set(data);
    await _dbRef.child('houses/$houseId/album/$itemId').remove();
    await _changeAlbumCount(houseId, -1);
  }

  Future<void> deleteForever({
    required String houseId,
    required String itemId,
  }) async {
    final snap = await _dbRef.child('houses/$houseId/album/$itemId').get();
    if (!snap.exists) return;
    await _dbRef.child('houses/$houseId/album/$itemId').remove();
    await _changeAlbumCount(houseId, -1);
  }

  Stream<List<Map<String, dynamic>>> streamTrash(String houseId) {
    return _dbRef.child('houses/$houseId/album_trash').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = event.snapshot.value;
      if (raw is! Map) return [];

      final now = DateTime.now().millisecondsSinceEpoch;
      final items = <Map<String, dynamic>>[];
      raw.forEach((key, value) {
        if (value is Map) {
          final item = Map<String, dynamic>.from(value);
          item['id'] = key;
          final purgeAt = item['purgeAt'] as int? ?? 0;
          if (purgeAt > now) {
            items.add(item);
          }
        }
      });
      items.sort((a, b) =>
          (b['deletedAt'] as int? ?? 0).compareTo(a['deletedAt'] as int? ?? 0));
      return items;
    });
  }

  Future<void> cleanupExpiredTrash(String houseId) async {
    try {
      final snap = await _dbRef.child('houses/$houseId/album_trash').get();
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{};

      raw.forEach((key, value) {
        if (value is Map) {
          final purgeAt = value['purgeAt'] as int? ?? 0;
          if (purgeAt <= now) {
            updates[key.toString()] = null;
          }
        }
      });

      if (updates.isNotEmpty) {
        await _dbRef.child('houses/$houseId/album_trash').update(updates);
      }
    } catch (_) {}
  }

  Future<void> restoreFromTrash({
    required String houseId,
    required String itemId,
  }) async {
    final snap =
        await _dbRef.child('houses/$houseId/album_trash/$itemId').get();
    if (!snap.exists) throw 'Không tìm thấy ảnh trong thùng rác.';

    final data = Map<String, dynamic>.from(snap.value as Map);
    data.remove('deletedAt');
    data.remove('purgeAt');

    final now = DateTime.now().millisecondsSinceEpoch;
    data['ts'] = data['ts'] ?? now;

    await _dbRef.child('houses/$houseId/album').push().set(data);
    await _dbRef.child('houses/$houseId/album_trash/$itemId').remove();
    await _changeAlbumCount(houseId, 1);
  }

  Future<void> deleteTrashForever({
    required String houseId,
    required String itemId,
  }) async {
    await _dbRef.child('houses/$houseId/album_trash/$itemId').remove();
  }

  Future<void> toggleLike({
    required String houseId,
    required String itemId,
    required bool currentLiked,
  }) async {
    final ref = _dbRef.child('houses/$houseId/album/$itemId/likes');
    await ref.set(ServerValue.increment(currentLiked ? -1 : 1));
  }

  Future<void> updateCaption({
    required String houseId,
    required String itemId,
    required String newCaption,
  }) async {
    await _dbRef.child('houses/$houseId/album/$itemId').update({
      'caption': newCaption.trim(),
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<AlbumItem>> fetchAlbum(String houseId, {int limit = 60}) async {
    final snap = await _dbRef
        .child('houses/$houseId/album')
        .orderByChild('ts')
        .limitToLast(limit)
        .get();

    if (!snap.exists || snap.value == null) return [];
    final raw = snap.value;
    if (raw is! Map) return [];

    final items = <AlbumItem>[];
    raw.forEach((key, value) {
      if (value is Map) {
        try {
          items.add(AlbumItem.fromJson(key.toString(), value));
        } catch (_) {}
      }
    });
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  static String formatTrashRemain(int purgeAt) {
    final leftMs = purgeAt - DateTime.now().millisecondsSinceEpoch;
    if (leftMs <= 0) return 'Sắp tự xóa';
    final totalHours = (leftMs / (1000 * 60 * 60)).ceil();
    if (totalHours >= 24) {
      final days = (totalHours / 24).ceil();
      return 'Tự xóa sau $days ngày';
    }
    return 'Tự xóa sau $totalHours giờ';
  }
}

class UploadGuardResult {
  final bool canUpload;
  final String? errorTitle;
  final String? errorMessage;
  final String? todayKey;
  final int uploadedToday;
  final int dailyLimit;

  const UploadGuardResult._({
    required this.canUpload,
    this.errorTitle,
    this.errorMessage,
    this.todayKey,
    this.uploadedToday = 0,
    this.dailyLimit = 5,
  });

  factory UploadGuardResult.ok(
    int uploadedToday,
    int dailyLimit,
    String? todayKey,
  ) =>
      UploadGuardResult._(
        canUpload: true,
        uploadedToday: uploadedToday,
        dailyLimit: dailyLimit,
        todayKey: todayKey,
      );

  factory UploadGuardResult.totalCapReached(int total, int totalCap) =>
      UploadGuardResult._(
        canUpload: false,
        errorTitle: 'Kho đã đầy',
        errorMessage:
            'Kho của bạn đã đầy ($total/$totalCap ảnh). Vui lòng xóa bớt ảnh cũ để lưu thêm!',
      );

  factory UploadGuardResult.dailyLimitReached(int limit, bool isPro) =>
      UploadGuardResult._(
        canUpload: false,
        errorTitle: 'Hết lượt hôm nay',
        errorMessage: isPro
            ? 'Bạn đã dùng hết $limit lượt tải ảnh hôm nay. Đợi sau 00h nhé!'
            : AppConfig.isPurchaseEnabled
                ? 'Bạn đã dùng hết $limit lượt hôm nay. Nâng cấp PRO để tải 30 ảnh/ngày!'
                : 'Bạn đã dùng hết $limit lượt hôm nay. Đợi sau 00h nhé!',
      );

  factory UploadGuardResult.exceedsRemaining(int remaining) =>
      UploadGuardResult._(
        canUpload: false,
        errorTitle: 'Quá số lượng',
        errorMessage: 'Bạn chỉ còn $remaining lượt tải ảnh hôm nay.',
      );
}
