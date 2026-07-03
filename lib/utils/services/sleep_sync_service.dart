import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================
///  SleepSyncService (Fullstack Phase 19)
///  Lõi Đo Giấc Ngủ & Báo Thức Đôi
/// ============================================================
class SleepSyncService {
  static final SleepSyncService _instance = SleepSyncService._internal();
  factory SleepSyncService() => _instance;
  SleepSyncService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Kích hoạt "Tính năng Đi ngủ" - Điện thoại chuyển sang màn hình đen
  Future<void> goToSleep(String houseId) async {
    final uid = _auth.currentUser?.uid;
    final normalizedHouseId = houseId.trim();
    if (uid == null || normalizedHouseId.isEmpty) return;

    await _db.ref('houses/$normalizedHouseId/sleep_sync/$uid').set({
      'isSleeping': true,
      'sleptAt': ServerValue.timestamp,
      'wokeUpAt': null,
    });
  }

  /// Sáng dậy tắt báo thức
  Future<void> wakeUp(String houseId) async {
    final uid = _auth.currentUser?.uid;
    final normalizedHouseId = houseId.trim();
    if (uid == null || normalizedHouseId.isEmpty) return;

    await _db.ref('houses/$normalizedHouseId/sleep_sync/$uid').update({
      'isSleeping': false,
      'wokeUpAt': ServerValue.timestamp,
    });
  }

  /// Đặt giờ gửi báo thức cho người kia
  Future<void> setAlarmForPartner(
      String houseId, String partnerUid, DateTime alarmTime) async {
    final normalizedHouseId = houseId.trim();
    final normalizedPartnerUid = partnerUid.trim();
    if (normalizedHouseId.isEmpty || normalizedPartnerUid.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/alarms/$normalizedPartnerUid').set({
      'alarmTimeMs': alarmTime.millisecondsSinceEpoch,
      'isActive': true,
      'message': 'Bé ơi dậy đi, tới giờ rồi nè! ☀️'
    });
  }

  /// Lắng nghe trạng thái ngủ của 2 người
  Stream<Map<dynamic, dynamic>?> listenToSleepState(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<Map<dynamic, dynamic>?>.value(null);
    }
    return _db.ref('houses/$normalizedHouseId/sleep_sync').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }
}
