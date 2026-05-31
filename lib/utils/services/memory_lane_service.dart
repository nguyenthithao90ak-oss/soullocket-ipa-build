import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  MemoryLaneService — Gra (Phase 30 Backend)
///  Lõi tự động tổng hợp kỷ niệm hàng năm (Timeline Aggregator)
/// ============================================================
class MemoryLaneService {
  static final MemoryLaneService _instance = MemoryLaneService._internal();
  factory MemoryLaneService() => _instance;
  MemoryLaneService._internal();

  final _db = FirebaseDatabase.instance;

  /// Lấy toàn bộ dữ liệu quan trọng để gen Timeline
  Future<List<Map<String, dynamic>>> fetchUnifiedTimeline(
      String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return [];
    List<Map<String, dynamic>> timeline = [];

    // 1. Phách từ Nhật ký (Diary)
    final diarySnap = await _db.ref('houses/$normalizedHouseId/diary').get();
    if (diarySnap.exists) {
      final data = Map<dynamic, dynamic>.from(diarySnap.value as Map);
      data.forEach((k, v) {
        if (v is Map) {
          timeline.add({...Map<String, dynamic>.from(v), 'type': 'diary'});
        }
      });
    }

    // 2. Phách từ Album ảnh (Album)
    final albumSnap = await _db.ref('houses/$normalizedHouseId/album').get();
    if (albumSnap.exists) {
      final data = Map<dynamic, dynamic>.from(albumSnap.value as Map);
      data.forEach((k, v) {
        if (v is Map) {
          timeline.add({...Map<String, dynamic>.from(v), 'type': 'photo'});
        }
      });
    }

    // Sắp xếp theo thời gian
    timeline
        .sort((a, b) => _asTimestamp(b['ts']).compareTo(_asTimestamp(a['ts'])));
    return timeline;
  }

  int _asTimestamp(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
