import 'package:firebase_database/firebase_database.dart';

/// ============================================================
///  HabitsService — GRA (Phase 37)
///  Theo Dõi Thói Quen Hàng Ngày — Shared Habit Tracker
///
///  Logic theo web gốc: core-habits-draw.js
///  - Thêm/Xóa thói quen vào Firebase
///  - Điểm danh thói quen (toggle hôm nay)
///  - Tính chuỗi liên tiếp (current streak)
///  - Tổng số ngày đã hoàn thành
/// ============================================================

class HabitsService {
  static final HabitsService _instance = HabitsService._internal();
  factory HabitsService() => _instance;
  HabitsService._internal();

  final _db = FirebaseDatabase.instance;

  // ─────────────────────────────────────────────────────────────
  // 1. QUẢN LÝ THÓI QUEN
  // ─────────────────────────────────────────────────────────────

  /// Thêm thói quen mới
  Future<String?> addHabit({
    required String houseId,
    required String name,
    required String creatorName,
  }) async {
    final ref = _db.ref('houses/$houseId/habits').push();
    await ref.set({
      'name': name.trim(),
      'creator': creatorName,
      'ts': ServerValue.timestamp,
      'completed_dates': {},
    });
    return ref.key;
  }

  /// Xóa thói quen
  Future<void> deleteHabit(String houseId, String habitId) async {
    await _db.ref('houses/$houseId/habits/$habitId').remove();
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ĐIỂM DANH HÀNG NGÀY
  // ─────────────────────────────────────────────────────────────

  /// Đổi trạng thái điểm danh hôm nay (toggle on/off)
  Future<void> toggleTodayCompletion(String houseId, String habitId) async {
    final todayKey = _getDateKey(DateTime.now());
    final ref = _db.ref('houses/$houseId/habits/$habitId');

    await ref.runTransaction((Object? current) {
      if (current == null) return Transaction.abort();
      final data = Map<String, dynamic>.from(current as Map);
      final completedDates = data['completed_dates'] is Map
          ? Map<String, dynamic>.from(data['completed_dates'] as Map)
          : <String, dynamic>{};

      // Toggle
      if (completedDates[todayKey] == true) {
        completedDates[todayKey] = false;
      } else {
        completedDates[todayKey] = true;
      }
      data['completed_dates'] = completedDates;
      return Transaction.success(data);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 3. STREAM DANH SÁCH THÓI QUEN (REALTIME)
  // ─────────────────────────────────────────────────────────────

  Stream<List<HabitData>> streamHabits(String houseId) {
    return _db
        .ref('houses/$houseId/habits')
        .limitToLast(30)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <HabitData>[];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        map['id'] = e.key.toString();
        return HabitData.fromMap(map);
      }).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 4. TÍNH STREAK VÀ THỐNG KÊ
  // ─────────────────────────────────────────────────────────────

  /// Tính chuỗi liên tiếp hiện tại (theo web gốc)
  static int calculateCurrentStreak(Map<String, dynamic> completedDates) {
    if (completedDates.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final key = _getDateKey(d);

      if (completedDates[key] == true) {
        streak++;
      } else if (i == 0) {
        // Bỏ qua hôm nay nếu chưa điểm danh (không phá chuỗi)
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Tổng số ngày đã hoàn thành
  static int calculateTotalCompleted(Map<String, dynamic> completedDates) {
    return completedDates.values.where((v) => v == true).length;
  }

  /// Kiểm tra đã điểm danh hôm nay chưa
  static bool isDoneToday(Map<String, dynamic> completedDates) {
    return completedDates[_getDateKey(DateTime.now())] == true;
  }

  // ─────────────────────────────────────────────────────────────
  // 5. HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Format ngày theo web gốc: d-m-yyyy (không có số 0 đệm)
  static String _getDateKey(DateTime d) {
    return '${d.day}-${d.month}-${d.year}';
  }
}

// ─── MODEL ──────────────────────────────────────────────────────────────────

class HabitData {
  final String id;
  final String name;
  final String creator;
  final int ts;
  final Map<String, dynamic> completedDates;

  HabitData({
    required this.id,
    required this.name,
    required this.creator,
    required this.ts,
    required this.completedDates,
  });

  bool get isDoneToday => HabitsService.isDoneToday(completedDates);
  int get currentStreak => HabitsService.calculateCurrentStreak(completedDates);
  int get totalCompleted =>
      HabitsService.calculateTotalCompleted(completedDates);

  factory HabitData.fromMap(Map<String, dynamic> map) {
    final cd = map['completed_dates'];
    return HabitData(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      creator: map['creator']?.toString() ?? '',
      ts: (map['ts'] as num?)?.toInt() ?? 0,
      completedDates:
          cd is Map ? Map<String, dynamic>.from(cd) : <String, dynamic>{},
    );
  }
}
