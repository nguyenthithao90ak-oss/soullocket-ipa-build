import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot chỉ phục vụ khung hình đầu; không thay thế kiểm tra quyền từ server.
class SettingsInitialIdentity {
  const SettingsInitialIdentity({
    required this.houseId,
    required this.relationshipMode,
    required this.role,
    required this.name1,
    required this.name2,
    required this.avatar1,
    required this.avatar2,
    this.vipBadge = false,
  });

  final String houseId;
  final String relationshipMode;
  final String role;
  final String name1;
  final String name2;
  final String avatar1;
  final String avatar2;

  /// Chỉ để hiện huy hiệu PRO ở khung đầu; không mở khóa tính năng VIP.
  final bool vipBadge;

  /// Khóa theo UID, houseId/role nằm trong snapshot: `il_house_id` và
  /// `il_auth_uid` có thể chỉ còn trong secure storage (đọc bất đồng bộ), nên
  /// không thể dùng chúng làm điều kiện bắt buộc cho khung hình đầu.
  static String cacheKey(String uid) => 'settings_identity_$uid';

  Map<String, dynamic> toCache(String uid) => {
    'uid': uid,
    'houseId': houseId,
    'relationshipMode': relationshipMode,
    'role': role,
    'nameU1': name1,
    'nameU2': name2,
    'avtUser1': avatar1,
    'avtUser2': avatar2,
    'vipBadge': vipBadge,
  };

  /// [houseId]/[role] là giá trị đã resolve cho đúng [uid] (ví dụ từ secure
  /// storage). Khi bỏ trống, chỉ dùng prefs nếu `il_auth_uid` khớp [uid].
  static SettingsInitialIdentity? restore({
    required SharedPreferences prefs,
    required String? uid,
    required dynamic Function(String key) readCache,
    String? houseId,
    String? role,
  }) {
    if (uid == null || uid.isEmpty) return null;
    final sameAccount = prefs.getString('il_auth_uid') == uid;
    final hintedHouseId =
        houseId?.trim() ??
        (sameAccount ? prefs.getString('il_house_id')?.trim() ?? '' : '');
    // Vai lệch với gợi ý thì bỏ snapshot, tránh hiện nhầm avatar người kia.
    final hintedRole =
        _validRole(role) ?? _validRole(prefs.getString('il_role'));

    final saved = readCache(cacheKey(uid));
    if (saved is Map && saved['uid'] == uid) {
      final identity = _fromMap(
        saved,
        houseId: saved['houseId']?.toString().trim() ?? '',
        role: _validRole(saved['role']?.toString()),
        vipBadge: saved['vipBadge'] == true,
      );
      if (identity != null &&
          (hintedHouseId.isEmpty || identity.houseId == hintedHouseId) &&
          (identity.relationshipMode == 'single' ||
              hintedRole == null ||
              identity.role == hintedRole)) {
        return identity;
      }
    }

    // Chưa từng mở Cài đặt: chỉ dựng từ cache Home khi biết chắc nhà và vai.
    if (hintedHouseId.isEmpty) return null;
    return _fromMap(
      readCache('home_settings_$hintedHouseId'),
      houseId: hintedHouseId,
      role: hintedRole,
    );
  }

  static String? _validRole(String? role) =>
      role == 'user1' || role == 'user2' ? role : null;

  static SettingsInitialIdentity? _fromMap(
    dynamic data, {
    required String houseId,
    required String? role,
    bool vipBadge = false,
  }) {
    if (houseId.isEmpty || data is! Map || data.isEmpty) return null;
    final mode = data['relationshipMode']?.toString().trim().toLowerCase();
    if (mode != 'single' && mode != 'couple') return null;
    // Không đoán vai khi thiếu dữ liệu: tránh hiện nhầm avatar người kia.
    if (mode == 'couple' && role == null) return null;
    return SettingsInitialIdentity(
      houseId: houseId,
      relationshipMode: mode!,
      role: mode == 'single' ? 'user1' : role!,
      name1: data['nameU1']?.toString() ?? '',
      name2: data['nameU2']?.toString() ?? '',
      avatar1: data['avtUser1']?.toString() ?? '',
      avatar2: data['avtUser2']?.toString() ?? '',
      vipBadge: vipBadge,
    );
  }
}
