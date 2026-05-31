import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================
///  TimeCapsuleService — Gra (Logic/Data)
///  Hòm Thời Gian - Đóng Cọc Tương Lai (Phase 13)
///
///  Chức năng:
///  1. Lưu trữ bức thư/hình ảnh có gắn Unix Timestamp mở khóa ở thì Tương lai.
///  2. Validate Server-side từ Firebase Rules đảm bảo không ai
///     có thể "Hack" hay đọc trộm được trước TimeUnlock.
///  3. Kiểm tra xem Capsule đã trồi lên mặt đất chưa để UI đập hộp.
/// ============================================================
class TimeCapsuleService {
  static final TimeCapsuleService _instance = TimeCapsuleService._internal();
  factory TimeCapsuleService() => _instance;
  TimeCapsuleService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Chôn một hộp thời gian mới xuống cát Firebase
  Future<void> buryTimeCapsule({
    required String houseId,
    required String title,
    required String message,
    required String? imageUrl,
    required DateTime unlockDate,
  }) async {
    final uid = _auth.currentUser?.uid;
    final normalizedHouseId = houseId.trim();
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    if (uid == null) throw Exception('Chưa đăng nhập!');
    if (normalizedHouseId.isEmpty) throw Exception('Thiếu mã nhà để chôn hòm.');
    if (normalizedTitle.isEmpty || normalizedMessage.isEmpty) {
      throw Exception('Hãy nhập tiêu đề và lời nhắn cho hòm thời gian.');
    }

    final capsuleRef = _db.ref('houses/$normalizedHouseId/time_capsules').push();

    // Dữ liệu được niêm phong
    await capsuleRef.set({
      'id': capsuleRef.key,
      'sender_uid': uid,
      'title': normalizedTitle,
      'content': normalizedMessage,
      'image_url': imageUrl?.trim(),
      'buried_at': ServerValue.timestamp, // Bắt đầu chôn
      'unlock_time_ms':
          unlockDate.millisecondsSinceEpoch, // Chờ tới ngày này mới cho mở
      'is_opened': false,
    });
  }

  /// Trae chỉ việc móc Stream này ra để hiện Hộp chưa mở trên bãi biển
  Stream<List<Map<String, dynamic>>> listenToCapsules(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }
    return _db
        .ref('houses/$normalizedHouseId/time_capsules')
        .orderByChild('unlock_time_ms')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries
          .map((e) => Map<String, dynamic>.from(e.value))
          .toList();
    });
  }

  /// Lấy danh sách các rương chưa mở (Dùng cho check notification)
  Future<List<Map<String, dynamic>>> getUnopenedCapsules(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return [];
    try {
      final snap = await _db.ref('houses/$normalizedHouseId/time_capsules').get();
      if (!snap.exists) return [];

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      return data.entries
          .map((e) => Map<String, dynamic>.from(e.value))
          .where((c) => c['is_opened'] == false)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Khui rương (Logic check Time)
  Future<Map<String, dynamic>> openCapsule(
      String houseId, Map<String, dynamic> capsule) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      throw Exception('Thiếu mã nhà để mở hòm.');
    }
    final int unlockTime = (capsule['unlock_time_ms'] as num?)?.toInt() ?? 0;
    final bool isOpened = capsule['is_opened'] == true;
    final int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (isOpened) return capsule; // Rương đã từng bị khui

    if (currentTime < unlockTime) {
      // Logic Backend kiểm định: Rương chưa "chín", đập hộp sẽ bị Server đá văng
      throw Exception(
          'Hòm Thời Gian chưa đến ngày mở. Bạn quay lại đúng ngày mở nhé.');
    }

    // Gắn mộc "Đã Khui" lên Firebase
    final cid = capsule['id']?.toString().trim() ?? '';
    if (cid.isEmpty) {
      throw Exception('Thiếu mã hòm thời gian.');
    }
    await _db.ref('houses/$normalizedHouseId/time_capsules/$cid').update({
      'is_opened': true,
      'opened_at': ServerValue.timestamp,
    });

    capsule['is_opened'] = true;
    return capsule; // Trả về Nội dung Ký ức
  }
}
