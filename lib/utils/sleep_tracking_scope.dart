import 'sleep_tracking_math.dart';

/// Cache chỉ xác định phạm vi; quyền ghi vẫn phải được Firebase xác minh.
class SleepTrackingScope {
  const SleepTrackingScope(this.uid, this.house, this.role);
  final String uid, house, role;
  String get token => sleepConsentScope(uid, house, role);

  static SleepTrackingScope? fromCache({
    required String? uid,
    required String? cachedUid,
    required String? house,
    required String? role,
  }) {
    final normalizedRole = sleepRole(role?.trim());
    final normalizedHouse = house?.trim() ?? '';
    if (uid == null ||
        uid.isEmpty ||
        normalizedHouse.isEmpty ||
        RegExp(r'[.#$\[\]/\\]').hasMatch(normalizedHouse) ||
        normalizedRole == null ||
        (cachedUid != null && cachedUid != uid)) {
      return null;
    }
    return SleepTrackingScope(uid, normalizedHouse, normalizedRole);
  }
}
