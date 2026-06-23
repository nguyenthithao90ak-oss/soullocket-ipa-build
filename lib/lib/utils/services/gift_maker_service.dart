import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_history_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'offline_cache_service.dart';

/// ============================================================
///  GiftMakerService — GRA (Phase 34)
///  Làm Quà Bất Ngờ — Gift Maker Feature
///
///  Logic theo web gốc: gift-maker-core.js
///  - 9 loại quà: gift_box, love_letter, surprise_egg,
///    bubble_wrap, scratch_reveal, happy_birthday,
///    your_heart, lovely_turkey, moon_wish
///  - Tạo link quà lưu Firebase hoặc local token
///  - Người nhận mở link → trải qua animation mở quà
/// ============================================================

/// 9 loại quà theo web gốc
enum GiftType {
  giftBox, // 🎁 Hộp quà rung lắc 8 lần chạm
  loveLetter, // 💌 Phong thư ảo
  surpriseEgg, // 🥚 Trứng bất ngờ 10 lần chạm
  bubbleWrap, // 🫧 Bóp bong bóng 12 cái
  scratchReveal, // 🪙 Cào lớp phủ để xem
  happyBirthday, // 🎂 Thiệp sinh nhật
  yourHeart, // ❤️ Hiệu ứng trái tim
  lovelyTurkey, // 🦃 Thiệp vui nhộn
  moonWish, // 🌙 Lời chúc dưới ánh trăng
}

class GiftMakerService {
  static final GiftMakerService _instance = GiftMakerService._internal();
  factory GiftMakerService() => _instance;
  GiftMakerService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  Future<String> _resolvedActivityRole() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final role = (prefs.getString('il_role') ?? 'user1').trim();
    return role == 'user2' ? 'user2' : 'user1';
  }

  String _timelineGiftLabel(String rawType) {
    switch (giftTypeFromString(rawType)) {
      case GiftType.giftBox:
        return 'hộp quà bất ngờ';
      case GiftType.loveLetter:
        return 'phong thư yêu thương';
      case GiftType.surpriseEgg:
        return 'quả trứng bất ngờ';
      case GiftType.bubbleWrap:
        return 'gói bong bóng';
      case GiftType.scratchReveal:
        return 'tấm quà cào mở';
      case GiftType.happyBirthday:
        return 'thiệp sinh nhật';
      case GiftType.yourHeart:
        return 'trái tim yêu thương';
      case GiftType.lovelyTurkey:
        return 'thiệp vui nhộn';
      case GiftType.moonWish:
        return 'lời chúc dưới trăng';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. TẠO QUÀ
  // ─────────────────────────────────────────────────────────────

  /// Tạo quà và lưu lên Firebase. Trả về gift_id hoặc null nếu lỗi.
  Future<String?> createGift({
    required String houseId,
    required String senderName,
    required String message,
    required GiftType giftType,
    String? imageUrl,
    String? toHouseId,
  }) async {
    final uid = _auth.currentUser?.uid;

    final normalizedHouseId = houseId.trim();
    final normalizedSenderName = senderName.trim();
    final normalizedMessage = message.trim();
    final normalizedImageUrl = imageUrl?.trim() ?? '';
    final normalizedToHouseId = toHouseId?.trim() ?? '';
    if (normalizedHouseId.isEmpty || normalizedMessage.isEmpty) return null;

    final giftData = {
      'fromHouseId': normalizedHouseId,
      'fromName': normalizedSenderName,
      'toHouseId': normalizedToHouseId,
      'msg': normalizedMessage,
      'imageUrl': normalizedImageUrl,
      'ts': ServerValue.timestamp,
      'status': 'new',
      'giftType': _giftTypeToString(giftType),
      'features': _giftFeatures(giftType),
    };

    try {
      // Lưu trong house của người gửi
      final ref = _db.ref('houses/$normalizedHouseId/gift_links').push();
      await ref.set(giftData);
      final giftId = ref.key;
      if (giftId == null || giftId.isEmpty) {
        return null;
      }

      // Mirror global giúp deeplink mở ổn định theo id, không phụ thuộc house hiện tại.
      try {
        await _db.ref('gift_links/$giftId').set({
          ...giftData,
          'giftId': giftId,
        });
      } catch (e) {
        debugPrint('Warning: Could not save global gift link: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể lưu liên kết quà toàn cục.',
        ).message}');
      }

      // Nếu gửi cho người khác, lưu thêm vào house người nhận
      if (normalizedToHouseId.isNotEmpty) {
        try {
          await _db.ref('houses/$normalizedToHouseId/received_gifts/$giftId').set({
            ...giftData,
            'giftId': giftId,
            'status': 'pending',
          });
        } catch (e) {
          debugPrint('Warning: Could not save to received_gifts: ${AppErrorMapper.resolve(
            e,
            fallbackMessage: 'Không thể lưu quà vào nhà người nhận.',
          ).message}');
        }
      }

      // Lưu vào gift_feed của người gửi
      if (uid != null) {
        try {
          await _db.ref('gift_feed_sender/$uid').push().set({
            'giftId': giftId,
            'fromHouseId': normalizedHouseId,
            'fromName': normalizedSenderName,
            'preview': normalizedMessage.length > 80
                ? '${normalizedMessage.substring(0, 80)}...'
                : normalizedMessage,
            'ts': ServerValue.timestamp,
            'giftType': _giftTypeToString(giftType),
            'direction': 'sent',
          });
        } catch (e) {
          debugPrint('Warning: Could not save to gift_feed_sender: ${AppErrorMapper.resolve(
            e,
            fallbackMessage: 'Không thể lưu lịch sử quà đã gửi.',
          ).message}');
        }
      }

      return giftId;
    } catch (e) {
      debugPrint('Error creating gift: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể tạo quà lúc này.',
      ).message}');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ĐỌC QUÀ
  // ─────────────────────────────────────────────────────────────

  /// Lấy thống tin 1 món quà theo ID
  Future<GiftData?> getGift({
    required String houseId,
    required String giftId,
  }) async {
    try {
      final normalizedHouseId = houseId.trim();
      final normalizedGiftId = giftId.trim();
      if (normalizedGiftId.isEmpty) return null;
      // Thử lấy từ house của người gửi
      var snap = normalizedHouseId.isEmpty
          ? await _db.ref('gift_links/$normalizedGiftId').get()
          : await _db.ref('houses/$normalizedHouseId/gift_links/$normalizedGiftId').get();
      if (!snap.exists) {
        // Thử lấy từ gift_links global
        snap = await _db.ref('gift_links/$normalizedGiftId').get();
      }
      if (!snap.exists || snap.value is! Map) return null;

      final data = Map<String, dynamic>.from(snap.value as Map);
      data['giftId'] = normalizedGiftId;
      return GiftData.fromMap(data);
    } catch (e) {
      debugPrint('Error getting gift: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể đọc dữ liệu quà.',
      ).message}');
      return null;
    }
  }

  /// Stream quà nhận được (cho người nhận xem)
  Future<GiftData?> resolveGiftLink({
    required String giftId,
    String? senderHouseId,
    String? receiverHouseId,
    GiftData? fallbackGift,
  }) async {
    final normalizedGiftId = giftId.trim();
    if (normalizedGiftId.isEmpty) return fallbackGift;
    final paths = <String>[
      if (senderHouseId != null && senderHouseId.trim().isNotEmpty)
        'houses/${senderHouseId.trim()}/gift_links/$normalizedGiftId',
      if (receiverHouseId != null && receiverHouseId.trim().isNotEmpty)
        'houses/${receiverHouseId.trim()}/received_gifts/$normalizedGiftId',
      if (receiverHouseId != null && receiverHouseId.trim().isNotEmpty)
        'houses/${receiverHouseId.trim()}/gift_links/$normalizedGiftId',
      'gift_links/$normalizedGiftId',
    ];

    for (final path in paths) {
      try {
        final snap = await _db.ref(path).get();
        if (!snap.exists || snap.value is! Map) continue;

        final data = Map<String, dynamic>.from(snap.value as Map);
        data['giftId'] = normalizedGiftId;
        data['imageUrl'] ??= data['img'] ?? '';
        data['msg'] ??= data['message'] ?? '';
        data['status'] ??= 'new';
        return GiftData.fromMap(data);
      } catch (e) {
        debugPrint('Could not resolve gift link from $path: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể đọc liên kết quà.',
        ).message}');
      }
    }

    return fallbackGift;
  }

  Stream<List<GiftData>> streamReceivedGifts(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<GiftData>>.value(const <GiftData>[]);
    }
    return _db
        .ref('houses/$normalizedHouseId/received_gifts')
        .orderByChild('ts')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return <GiftData>[];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries.where((e) => e.value is Map).map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        map['giftId'] = e.key.toString();
        return GiftData.fromMap(map);
      }).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
    }).asBroadcastStream();
  }

  /// Stream quà đã tạo (lịch sử của người gửi)
  Stream<List<GiftData>> streamSentGifts(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<GiftData>>.value(const <GiftData>[]);
    }
    return _db
        .ref('houses/$normalizedHouseId/gift_links')
        .orderByChild('ts')
        .limitToLast(30)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return <GiftData>[];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries.where((e) => e.value is Map).map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        map['giftId'] = e.key.toString();
        return GiftData.fromMap(map);
      }).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
    }).asBroadcastStream();
  }

  // ─────────────────────────────────────────────────────────────
  // 3. MỞ QUÀ (ĐÁNH DẤU ĐÃ XEM)
  // ─────────────────────────────────────────────────────────────

  Future<void> markGiftOpened({
    required String receiverHouseId,
    required String giftId,
    String? senderHouseId,
  }) async {
    final normalizedReceiverHouseId = receiverHouseId.trim();
    final normalizedGiftId = giftId.trim();
    if (normalizedReceiverHouseId.isEmpty || normalizedGiftId.isEmpty) return;
    String openedGiftLabel = 'món quà bất ngờ';
    try {
      final existing = await _db
          .ref('houses/$normalizedReceiverHouseId/received_gifts/$normalizedGiftId')
          .get();
      if (existing.exists && existing.value is Map) {
        final data = Map<dynamic, dynamic>.from(existing.value as Map);
        if ((data['status'] ?? '').toString().trim().toLowerCase() ==
            'opened') {
          return;
        }
        final giftType = (data['giftType'] ?? '').toString().trim();
        if (giftType.isNotEmpty) {
          openedGiftLabel = _timelineGiftLabel(giftType);
        }
      }
    } catch (_) {}

    const openedAt = ServerValue.timestamp;
    final updates = <String, Object?>{
      'houses/$normalizedReceiverHouseId/received_gifts/$normalizedGiftId/status': 'opened',
      'houses/$normalizedReceiverHouseId/received_gifts/$normalizedGiftId/openedAt': openedAt,
      'gift_links/$normalizedGiftId/status': 'opened',
      'gift_links/$normalizedGiftId/openedAt': openedAt,
    };

    if (senderHouseId != null && senderHouseId.trim().isNotEmpty) {
      final senderId = senderHouseId.trim();
      updates['houses/$senderId/gift_links/$normalizedGiftId/status'] = 'opened';
      updates['houses/$senderId/gift_links/$normalizedGiftId/openedAt'] = openedAt;
    }

    await _db.ref().update(updates);
    try {
      final role = await _resolvedActivityRole();
      await ActivityHistoryService.instance.add(
        'đã mở $openedGiftLabel',
        houseId: normalizedReceiverHouseId,
        role: role,
      );
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // 5. HELPERS
  // ─────────────────────────────────────────────────────────────

  static String _giftTypeToString(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return 'gift_box';
      case GiftType.loveLetter:
        return 'love_letter';
      case GiftType.surpriseEgg:
        return 'surprise_egg';
      case GiftType.bubbleWrap:
        return 'bubble_wrap';
      case GiftType.scratchReveal:
        return 'scratch_reveal';
      case GiftType.happyBirthday:
        return 'happy_birthday';
      case GiftType.yourHeart:
        return 'your_heart';
      case GiftType.lovelyTurkey:
        return 'lovely_turkey';
      case GiftType.moonWish:
        return 'moon_wish';
    }
  }

  static GiftType giftTypeFromString(String s) {
    switch (s) {
      case 'love_letter':
        return GiftType.loveLetter;
      case 'surprise_egg':
        return GiftType.surpriseEgg;
      case 'bubble_wrap':
        return GiftType.bubbleWrap;
      case 'scratch_reveal':
        return GiftType.scratchReveal;
      case 'happy_birthday':
        return GiftType.happyBirthday;
      case 'your_heart':
        return GiftType.yourHeart;
      case 'lovely_turkey':
        return GiftType.lovelyTurkey;
      case 'moon_wish':
        return GiftType.moonWish;
      default:
        return GiftType.giftBox;
    }
  }

  static String giftEmoji(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return '🎁';
      case GiftType.loveLetter:
        return '💌';
      case GiftType.surpriseEgg:
        return '🥚';
      case GiftType.bubbleWrap:
        return '🫧';
      case GiftType.scratchReveal:
        return '🪙';
      case GiftType.happyBirthday:
        return '🎂';
      case GiftType.yourHeart:
        return '❤️';
      case GiftType.lovelyTurkey:
        return '🦃';
      case GiftType.moonWish:
        return '🌙';
    }
  }

  static String giftLabel(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return 'Gift box';
      case GiftType.loveLetter:
        return 'Love letter';
      case GiftType.surpriseEgg:
        return 'Surprise egg';
      case GiftType.bubbleWrap:
        return 'Bubble wrap';
      case GiftType.scratchReveal:
        return 'Scratch-to-reveal';
      case GiftType.happyBirthday:
        return 'Happy birthday';
      case GiftType.yourHeart:
        return 'Your heart';
      case GiftType.lovelyTurkey:
        return 'Lovely turkey';
      case GiftType.moonWish:
        return 'Moon wish';
    }
  }

  static String giftNote(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return 'Hộp quà rung lắc, mở nhiều lần rồi hiện thông điệp.';
      case GiftType.loveLetter:
        return 'Phong thư ảo, bấm để rút thư ra đọc.';
      case GiftType.surpriseEgg:
        return 'Trứng bất ngờ cần chạm nhiều lần để nở.';
      case GiftType.bubbleWrap:
        return 'Bóp bong bóng trước khi nhận quà.';
      case GiftType.scratchReveal:
        return 'Cào lớp phủ để xem nội dung ẩn.';
      case GiftType.happyBirthday:
        return 'Thiệp sinh nhật mở trực tiếp kèm lời chúc.';
      case GiftType.yourHeart:
        return 'Hiệu ứng trái tim mở quà nhanh.';
      case GiftType.lovelyTurkey:
        return 'Thiệp vui nhộn theo chủ đề.';
      case GiftType.moonWish:
        return 'Lời chúc dưới ánh trăng.';
    }
  }

  static Map<String, dynamic> _giftFeatures(GiftType type) {
    switch (type) {
      case GiftType.giftBox:
        return {
          'giftBox': true,
          'letter': false,
          'scratch': false,
          'bubble': false
        };
      case GiftType.loveLetter:
        return {
          'giftBox': false,
          'letter': true,
          'scratch': false,
          'bubble': false
        };
      case GiftType.surpriseEgg:
        return {
          'giftBox': true,
          'letter': false,
          'scratch': false,
          'bubble': true
        };
      case GiftType.bubbleWrap:
        return {
          'giftBox': false,
          'letter': false,
          'scratch': false,
          'bubble': true
        };
      case GiftType.scratchReveal:
        return {
          'giftBox': false,
          'letter': false,
          'scratch': true,
          'bubble': false
        };
      default:
        return {
          'giftBox': false,
          'letter': false,
          'scratch': false,
          'bubble': false
        };
    }
  }

  /// Số lần chạm cần thiết để mở quà theo loại
  static int tapCountFor(GiftType type) {
    switch (type) {
      case GiftType.surpriseEgg:
        return 10;
      case GiftType.giftBox:
        return 8;
      default:
        return 0;
    }
  }

  /// Số bong bóng cần bóp
  static int bubbleCountFor(GiftType type) {
    return (type == GiftType.bubbleWrap || type == GiftType.surpriseEgg)
        ? 12
        : 0;
  }
  Future<void> deleteGiftLink({
    required String houseId,
    required String giftId,
  }) async {
    try {
      final normalizedHouseId = houseId.trim();
      final normalizedGiftId = giftId.trim();
      if (normalizedHouseId.isEmpty || normalizedGiftId.isEmpty) return;
      await _db.ref('houses/$normalizedHouseId/gift_links/$normalizedGiftId').remove();
      await _db.ref('gift_links/$normalizedGiftId').remove();

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        try {
          final feedSnap = await _db
              .ref('gift_feed_sender/$uid')
              .orderByChild('giftId')
              .equalTo(normalizedGiftId)
              .get();
          if (feedSnap.exists && feedSnap.value is Map) {
            final data = Map<dynamic, dynamic>.from(feedSnap.value as Map);
            for (final key in data.keys) {
              await _db.ref('gift_feed_sender/$uid/$key').remove();
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting gift link: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xóa liên kết quà.',
      ).message}');
      rethrow;
    }
  }

}

// ─── MODEL ──────────────────────────────────────────────────────────────────

class GiftData {
  final String giftId;
  final String fromHouseId;
  final String fromName;
  final String toHouseId;
  final String message;
  final String imageUrl;
  final int ts;
  final String status;
  final GiftType giftType;
  final Map<String, dynamic> features;

  GiftData({
    required this.giftId,
    required this.fromHouseId,
    required this.fromName,
    required this.toHouseId,
    required this.message,
    required this.imageUrl,
    required this.ts,
    required this.status,
    required this.giftType,
    required this.features,
  });

  bool get isOpened => status == 'opened';

  factory GiftData.fromMap(Map<String, dynamic> map) {
    return GiftData(
      giftId: map['giftId']?.toString() ?? '',
      fromHouseId: map['fromHouseId']?.toString() ?? '',
      fromName: map['fromName']?.toString() ?? '',
      toHouseId: map['toHouseId']?.toString() ?? '',
      message: map['msg']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      ts: _asTimestamp(map['ts']),
      status: map['status']?.toString() ?? 'new',
      giftType: GiftMakerService.giftTypeFromString(
          map['giftType']?.toString() ?? 'gift_box'),
      features: map['features'] is Map
          ? Map<String, dynamic>.from(map['features'] as Map)
          : <String, dynamic>{},
    );
  }

  static int _asTimestamp(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
