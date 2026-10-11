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

/// Ưu tiên bản prefs; thiếu House thì dùng bản trong bộ nhớ bảo mật nếu bản đó
/// thuộc đúng UID đang đăng nhập (một số luồng chỉ còn giữ ở đây).
Future<SleepTrackingScope?> resolveSleepTrackingScope({
  required String? uid,
  required String? house,
  required String? cachedUid,
  required String? role,
  required Future<String?> Function() secureHouse,
  required Future<String?> Function() secureUid,
  required Future<String?> Function() secureRole,
}) async {
  if (uid == null || uid.isEmpty) return null;
  var resolvedHouse = house, resolvedUid = cachedUid, resolvedRole = role;
  if (resolvedHouse == null || resolvedHouse.trim().isEmpty) {
    resolvedHouse = await secureHouse();
    resolvedUid = await secureUid();
    if (resolvedUid != uid) return null;
  }
  if (sleepRole(resolvedRole?.trim()) == null) {
    resolvedRole = await secureRole();
  }
  return SleepTrackingScope.fromCache(
    uid: uid,
    cachedUid: resolvedUid,
    house: resolvedHouse,
    role: resolvedRole,
  );
}
