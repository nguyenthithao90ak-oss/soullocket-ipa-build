import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';

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

  final _auth = FirebaseAuth.instance;

  /// Chôn một hộp thời gian mới xuống cát Firebase
  Future<Map<String, dynamic>> buryTimeCapsule({
    required String houseId,
    required String title,
    required String message,
    String? imageUploadSessionId,
    String? capsuleId,
    required DateTime unlockDate,
  }) async {
    final uid = _auth.currentUser?.uid;
    final normalizedHouseId = houseId.trim();
    if (uid == null) throw Exception('Chưa đăng nhập!');
    if (normalizedHouseId.isEmpty) throw Exception('Thiếu mã nhà để chôn hòm.');
    final response =
        await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
          'createTimeCapsule',
          payload: {
            'houseId': normalizedHouseId,
            'title': title.trim(),
            'content': message.trim(),
            'unlockTimeMs': unlockDate.millisecondsSinceEpoch,
            if (capsuleId != null && capsuleId.trim().isNotEmpty)
              'capsuleId': capsuleId.trim(),
            if (imageUploadSessionId != null &&
                imageUploadSessionId.trim().isNotEmpty)
              'imageUploadSessionId': imageUploadSessionId.trim(),
          },
          requireAppCheck: true,
          throwOriginalException: true,
        );
    return response.data;
  }

  /// Trae chỉ việc móc Stream này ra để hiện Hộp chưa mở trên bãi biển
  Stream<List<Map<String, dynamic>>> listenToCapsules(String houseId) async* {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      yield const [];
      return;
    }
    Future<List<Map<String, dynamic>>> load() async {
      final response =
          await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
            'listTimeCapsules',
            payload: {'houseId': normalizedHouseId},
            requireAppCheck: true,
            throwOriginalException: true,
          );
      final raw = response.data['capsules'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    yield await load();
    yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) => load());
  }

  /// Lấy danh sách các rương chưa mở (Dùng cho check notification)
  Future<List<Map<String, dynamic>>> getUnopenedCapsules(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return [];
    try {
      final response =
          await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
            'listTimeCapsules',
            payload: {'houseId': normalizedHouseId},
            requireAppCheck: true,
            throwOriginalException: true,
          );
      final raw = response.data['capsules'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((c) => c['is_opened'] == false)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Khui rương (Logic check Time)
  Future<Map<String, dynamic>> openCapsule(
    String houseId,
    Map<String, dynamic> capsule,
  ) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      throw Exception('Thiếu mã nhà để mở hòm.');
    }
    // Gắn mộc "Đã Khui" lên Firebase
    final cid = capsule['id']?.toString().trim() ?? '';
    if (cid.isEmpty) {
      throw Exception('Thiếu mã hòm thời gian.');
    }
    final response =
        await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
          'openTimeCapsule',
          payload: {'houseId': normalizedHouseId, 'capsuleId': cid},
          requireAppCheck: true,
          throwOriginalException: true,
        );
    final result = response.data['capsule'];
    if (result is! Map) throw StateError('Time capsule open was not confirmed');
    return Map<String, dynamic>.from(result);
  }

  /// Xóa một hòm thời gian khỏi Firebase
  Future<void> deleteCapsule(String houseId, String capsuleId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedCapsuleId = capsuleId.trim();
    if (normalizedHouseId.isEmpty || normalizedCapsuleId.isEmpty) {
      throw Exception('Thiếu mã nhà hoặc mã hòm để xóa.');
    }
    await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'deleteTimeCapsule',
      payload: {'houseId': normalizedHouseId, 'capsuleId': normalizedCapsuleId},
      requireAppCheck: true,
      throwOriginalException: true,
    );
  }
}
