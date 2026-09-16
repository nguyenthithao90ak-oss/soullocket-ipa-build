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
  });

  final String houseId;
  final String relationshipMode;
  final String role;
  final String name1;
  final String name2;
  final String avatar1;
  final String avatar2;

  static SettingsInitialIdentity? restore({
    required SharedPreferences prefs,
    required String? uid,
    required dynamic Function(String key) readCache,
  }) {
    if (uid == null || uid.isEmpty || prefs.getString('il_auth_uid') != uid) {
      return null;
    }
    final houseId = prefs.getString('il_house_id')?.trim() ?? '';
    if (houseId.isEmpty) return null;
    final data = readCache('home_settings_$houseId');
    if (data is! Map || data.isEmpty) return null;
    final mode = data['relationshipMode']?.toString().trim().toLowerCase();
    if (mode != 'single' && mode != 'couple') return null;
    final role = prefs.getString('il_role');
    // Không đoán vai khi thiếu dữ liệu: tránh hiện nhầm avatar người kia.
    if (mode == 'couple' && role != 'user1' && role != 'user2') return null;
    return SettingsInitialIdentity(
      houseId: houseId,
      relationshipMode: mode!,
      role: mode == 'single' ? 'user1' : role!,
      name1: data['nameU1']?.toString() ?? '',
      name2: data['nameU2']?.toString() ?? '',
      avatar1: data['avtUser1']?.toString() ?? '',
      avatar2: data['avtUser2']?.toString() ?? '',
    );
  }
}
