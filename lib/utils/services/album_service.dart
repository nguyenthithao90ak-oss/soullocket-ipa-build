import 'package:firebase_database/firebase_database.dart' hide Query, Transaction;
import 'package:firebase_database/firebase_database.dart' as rtdb show Transaction;
import 'package:cloud_firestore/cloud_firestore.dart';
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
      return rtdb.Transaction.success(next < 0 ? 0 : next);
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
    return FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .orderBy('ts', descending: true)
        .limit(albumStreamPageSize)
        .snapshots()
        .map((event) {
      final items = <AlbumItem>[];
      for (var doc in event.docs) {
        try {
          items.add(AlbumItem.fromJson(doc.id, doc.data()));
        } catch (_) {}
      }
      return items;
    });
  }

  Future<List<AlbumItem>> fetchAlbumPage(
    String houseId, {
    int limit = 30,
    int? endBeforeTs,
  }) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .orderBy('ts', descending: true)
        .limit(limit);

    if (endBeforeTs != null) {
      query = query.where('ts', isLessThan: endBeforeTs);
    }

    final snap = await query.get();
    final items = <AlbumItem>[];
    for (var doc in snap.docs) {
      try {
        items.add(AlbumItem.fromJson(doc.id, doc.data()));
      } catch (_) {}
    }
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
    final data = {
      'url': url.trim(),
      'thumbUrl': thumbUrl,
      'caption': caption.trim(),
      'role': role,
      'authorName': authorName,
      'ts': now,
      'timestamp': now,
      'type': type,
      'likes': 0,
    };

    final docRef = await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .add(data);

    await _changeAlbumCount(houseId, 1);

    // Record daily quest progress
    DailyQuestService().recordProgress('diary_entry');

    return docRef.id;
  }

  Future<void> moveToTrash({
    required String houseId,
    required String itemId,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .doc(itemId);
    final snap = await docRef.get();
    if (!snap.exists) throw 'Ảnh không tồn tại.';

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = Map<String, dynamic>.from(snap.data()!);
    data['deletedAt'] = now;
    data['purgeAt'] = now + trashExpiryMs;
    data['id'] = itemId;

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .collection('album_trash')
          .doc(itemId),
      data,
    );
    batch.delete(docRef);
    await batch.commit();

    await _changeAlbumCount(houseId, -1);
  }

  Future<void> deleteForever({
    required String houseId,
    required String itemId,
  }) async {
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .doc(itemId)
        .delete();
    await _changeAlbumCount(houseId, -1);
  }

  Stream<List<Map<String, dynamic>>> streamTrash(String houseId) {
    return FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album_trash')
        .snapshots()
        .map((event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final items = <Map<String, dynamic>>[];
      for (var doc in event.docs) {
        final item = Map<String, dynamic>.from(doc.data());
        item['id'] = doc.id;
        final purgeAt = item['purgeAt'] as int? ?? 0;
        if (purgeAt > now) {
          items.add(item);
        }
      }
      items.sort((a, b) =>
          (b['deletedAt'] as int? ?? 0).compareTo(a['deletedAt'] as int? ?? 0));
      return items;
    });
  }

  Future<void> cleanupExpiredTrash(String houseId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .collection('album_trash')
          .get();

      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in snap.docs) {
        final purgeAt = doc.data()['purgeAt'] as int? ?? 0;
        if (purgeAt <= now) {
          batch.delete(doc.reference);
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (_) {}
  }

  Future<void> restoreFromTrash({
    required String houseId,
    required String itemId,
  }) async {
    final trashRef = FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album_trash')
        .doc(itemId);
    final snap = await trashRef.get();
    if (!snap.exists) throw 'Không tìm thấy ảnh trong thùng rác.';

    final data = Map<String, dynamic>.from(snap.data()!);
    data.remove('deletedAt');
    data.remove('purgeAt');

    final now = DateTime.now().millisecondsSinceEpoch;
    data['ts'] = data['ts'] ?? now;

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .collection('album')
          .doc(itemId),
      data,
    );
    batch.delete(trashRef);
    await batch.commit();

    await _changeAlbumCount(houseId, 1);
  }

  Future<void> deleteTrashForever({
    required String houseId,
    required String itemId,
  }) async {
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album_trash')
        .doc(itemId)
        .delete();
  }

  Future<void> toggleLike({
    required String houseId,
    required String itemId,
    required bool currentLiked,
  }) async {
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .doc(itemId)
        .update({
      'likes': FieldValue.increment(currentLiked ? -1 : 1),
    });
  }

  Future<void> updateCaption({
    required String houseId,
    required String itemId,
    required String newCaption,
  }) async {
    await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .doc(itemId)
        .update({
      'caption': newCaption.trim(),
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<AlbumItem>> fetchAlbum(String houseId, {int limit = 60}) async {
    final snap = await FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('album')
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();

    final items = <AlbumItem>[];
    for (var doc in snap.docs) {
      try {
        items.add(AlbumItem.fromJson(doc.id, doc.data()));
      } catch (_) {}
    }
    return items;
  }

  // ── SCRIPT MIGRATION TỰ ĐỘNG ──────────────────────────────────────────
  Future<void> migrateAlbumFromRTDB(String houseId) async {
    final snap = await _dbRef.child('houses/$houseId/album').get();
    if (!snap.exists || snap.value == null) return;

    final raw = snap.value;
    if (raw is! Map) return;

    final batch = FirebaseFirestore.instance.batch();
    int count = 0;

    raw.forEach((key, value) {
      if (value is Map) {
        final docRef = FirebaseFirestore.instance
            .collection('houses')
            .doc(houseId)
            .collection('album')
            .doc(key.toString());
        batch.set(docRef, Map<String, dynamic>.from(value), SetOptions(merge: true));
        count++;
      }
    });

    if (count > 0) {
      await batch.commit();
      // Optional: Delete from RTDB after migration
      // await _dbRef.child('houses/$houseId/album').remove();
    }
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
