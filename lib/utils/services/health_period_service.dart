import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
  Future<void> logPeriodStart(String houseId, DateTime startDate) async {
    final ref = _db.ref('houses/$houseId/health_period');

    // Lưu lịch sử
    await ref.child('history').push().set({
      'start_date_ms': startDate.millisecondsSinceEpoch,
      'logged_at': ServerValue.timestamp,
    });

    // Tính toán trạm dừng chân tiếp theo
    final nextPredictedDate =
        startDate.add(const Duration(days: defaultCycleLength));

    // Cập nhật lên Cổng Chính (Home) để Trae bắt vẽ Giọt Nước
    await ref.update({
      'last_period_ms': startDate.millisecondsSinceEpoch,
      'next_predicted_ms': nextPredictedDate.millisecondsSinceEpoch,
    });

    // 🔴 Gọi Background Function Firebase để tự động lên lịch báo thức...
    _scheduleNotificationsForBoyfriend(nextPredictedDate);
  }

  /// Hàm lắng nghe chu kỳ (Để Trae vẽ Widgets Nhắc Nhở)
  Stream<Map<dynamic, dynamic>?> listenToCycleData(String houseId) {
    return _db.ref('houses/$houseId/health_period').onValue.map((event) {
      if (!event.snapshot.exists) return null;
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
    final pmsDate =
        nextPredictedDate.subtract(const Duration(days: pmsWarningDays));
    final diffDays = pmsDate.difference(now).inDays;

    // Just a mock debug log, in production this would be sent to Firebase Cloud Functions Queue
    debugPrint('Scheduled PMS Notification for $pmsDate (in $diffDays days)');
  }
}
