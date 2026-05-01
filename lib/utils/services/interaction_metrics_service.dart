import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InteractionMetricsService {
  InteractionMetricsService({
    DatabaseReference? dbRef,
  }) : _dbRef = dbRef ?? FirebaseDatabase.instance.ref();

  static const Duration _appOpenCooldown = Duration(seconds: 90);
  static const Duration _diaryViewCooldown = Duration(seconds: 45);
  static const String _prefsPrefix = 'il_interaction_metric_gate_v1';

  final DatabaseReference _dbRef;

  Future<void> recordAppOpen({
    required String houseId,
    required String role,
  }) {
    return _recordMetric(
      houseId: houseId,
      role: role,
      metricKey: 'app_open',
      cooldown: _appOpenCooldown,
    );
  }

  Future<void> recordDiaryView({
    required String houseId,
    required String role,
  }) {
    return _recordMetric(
      houseId: houseId,
      role: role,
      metricKey: 'diary_views',
      cooldown: _diaryViewCooldown,
    );
  }

  Future<void> _recordMetric({
    required String houseId,
    required String role,
    required String metricKey,
    required Duration cooldown,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = _normalizeRole(role);
    if (normalizedHouseId.isEmpty || normalizedRole == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final gateKey =
        '$_prefsPrefix|$metricKey|$normalizedHouseId|$normalizedRole';
    final lastTrackedAt = prefs.getInt(gateKey) ?? 0;
    if (now - lastTrackedAt < cooldown.inMilliseconds) {
      return;
    }

    final updates = <String, Object?>{
      'houses/$normalizedHouseId/metrics/$metricKey/$normalizedRole':
          ServerValue.increment(1),
      'houses/$normalizedHouseId/metrics/${metricKey}_updated_at':
          ServerValue.timestamp,
      'houses/$normalizedHouseId/metrics/${metricKey}_updated_at_by_role/$normalizedRole':
          ServerValue.timestamp,
      'houses/$normalizedHouseId/metrics/last_active_at/$normalizedRole':
          ServerValue.timestamp,
    };
    await _dbRef.update(updates);
    await prefs.setInt(gateKey, now);
  }

  String? _normalizeRole(String? role) {
    final value = role?.trim();
    if (value == 'user1' || value == 'user2') {
      return value;
    }
    return null;
  }
}
