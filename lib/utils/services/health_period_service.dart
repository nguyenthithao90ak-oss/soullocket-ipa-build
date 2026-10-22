import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../calendar/calendar_civil_date.dart';
import '../health_data_privacy.dart';

/// ============================================================
///  HealthPeriodService — Gra (Logic/Data)
///  Tính Toán Chu Kỳ Tình Yêu / Ngày Dâu (Phase 15)
///
///  Chức năng:
///  1. Ghi nhận ngày bắt đầu/kết thúc chu kỳ.
///  2. Toán học cơ bản tính toán Ngày rụng dâu tiếp theo (Trung bình 28 ngày).
///  3. Lõi kích hoạt Push Notification báo cho Chàng Trai chuẩn bị tâm lý.
/// ============================================================
class HealthPeriodService {
  static final HealthPeriodService _instance = HealthPeriodService._internal();
  factory HealthPeriodService() => _instance;
  HealthPeriodService._internal();

  final _db = FirebaseDatabase.instance;

  // Hằng số y khoa mặc định
  static const int defaultCycleLength = 28; // Chu kỳ chuNẩn 28 ngày
  static const int pmsWarningDays = 3; // Cảnh báo trước 3 ngày tới tháng

  /// Khi bạn Nữ nhập Cột mốc "Ngày Rụng Dâu"
  Future<void> logPeriodStart(
    String houseId,
    DateTime startDate, {
    bool shareWithPartner = false,
    Map<String, dynamic>? cycleData,
  }) async {
    final ref = _db.ref('houses/$houseId/health_period');

    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || ownerUid.isEmpty) {
      throw StateError('Cần đăng nhập để lưu dữ liệu sức khỏe.');
    }
    if (cycleData != null && cycleData['ownerUid'] != ownerUid) {
      throw StateError('Phiên lưu dữ liệu sức khỏe đã thay đổi.');
    }
    final historyKey = ref.child('history').push().key;
    if (historyKey == null || historyKey.isEmpty) {
      throw StateError('Không tạo được mốc chu kỳ.');
    }

    // Tính toán trạm dừng chân tiếp theo
    final nextPredictedDate =
        CalendarCivilDate.addDays(startDate, defaultCycleLength);

    // Cập nhật lên Cổng Chính (Home) để Trae bắt vẽ Giọt Nước
    final periodUpdate = <String, dynamic>{
      'ownerUid': ownerUid,
      'shareWithPartner': shareWithPartner,
      'history/$historyKey': {
        'start_date_ms': startDate.millisecondsSinceEpoch,
        'logged_at': ServerValue.timestamp,
      },
      'last_period_ms': startDate.millisecondsSinceEpoch,
      'next_predicted_ms': nextPredictedDate.millisecondsSinceEpoch,
    };
    if (cycleData == null) {
      await ref.update(periodUpdate);
    } else {
      // Một lần update nguyên tử: rules từ chối node nào thì không lưu dở node kia.
      await _db.ref('houses/$houseId').update({
        'health_cycle': cycleData,
        for (final entry in periodUpdate.entries)
          'health_period/${entry.key}': entry.value,
      });
    }

    // 🔴 Gọi Background Function Firebase để tự động lên lịch báo thức...
    if (shareWithPartner) {
      _scheduleNotificationsForBoyfriend(nextPredictedDate);
    }
  }

  /// Hàm lắng nghe chu kỳ (Để Trae vẽ Widgets Nhắc Nhở)
  Stream<Map<dynamic, dynamic>?> listenToCycleData(String houseId) {
    return _db.ref('houses/$houseId/health_period').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      if (!canDisplayHealthData(event.snapshot.value, FirebaseAuth.instance.currentUser?.uid)) return null;
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }

  /// Bộ máy Báo Động (Mock Cloud Function Queue)
  Future<void> _scheduleNotificationsForBoyfriend(
      DateTime nextPredictedDate) async {
    debugPrint(
        '💌 [Cloud Task Queue] Đã lên lịch tự động: Ngày PMS (âm $pmsWarningDays ngày) sẽ Push cho bạn Trai.');
    debugPrint(
        '📱 Message: Cảnh báo bão đổ bộ! Hãy chuẩn bị trà sữa và hoa dỗ dành Tình yêu!');

    // Trigger mock notification via NotificationService if it's within a few days
    final now = DateTime.now();
    final pmsDate = CalendarCivilDate.addDays(nextPredictedDate, -pmsWarningDays);
    final diffDays = CalendarCivilDate.daysBetween(now, pmsDate);

    // Just a mock debug log, in production this would be sent to Firebase Cloud Functions Queue
    debugPrint('Scheduled PMS Notification for $pmsDate (in $diffDays days)');
  }
}
