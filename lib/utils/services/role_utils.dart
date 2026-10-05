import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

class RoleUtils {
  static final ValueNotifier<String?> roleNotifier =
      ValueNotifier<String?>(null);

  /// Phát tín hiệu khi phát hiện 2 thiết bị đang dùng cùng vai.
  /// PresenceService sẽ set true; HomeScreen lắng nghe để hiện thông báo nhẹ.
  static final ValueNotifier<bool> duplicateRoleNotifier =
      ValueNotifier<bool>(false);

  static String normalize(String? value) {
    return value?.trim() == 'user2' ? 'user2' : 'user1';
  }

  static String? normalizeNullable(String? value) {
    final role = value?.trim();
    if (role == 'user1' || role == 'user2') {
      return role;
    }
    return null;
  }

  static Future<String> currentRole() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return normalize(prefs.getString('il_role'));
  }

  static String currentRoleSync({String? fallback}) {
    final prefs = OfflineCacheService.getPrefsSync();
    return normalize(prefs?.getString('il_role') ?? fallback);
  }

  /// `houses/{houseId}/settings/genderSwapped == true` nghĩa là chỗ user1 là
  /// Nữ, user2 là Nam. Chỉ đổi nhãn hiển thị; dữ liệu và quyền vẫn theo chỗ.
  static bool readGenderSwapped(Object? settings) =>
      settings is Map && settings['genderSwapped'] == true;

  static bool isFemaleRole(String? role, {bool genderSwapped = false}) {
    final isUser2 = normalize(role) == 'user2';
    return genderSwapped ? !isUser2 : isUser2;
  }

  /// Khóa i18n của tên mặc định "Bạn Nam"/"Bạn Nữ" cho một chỗ.
  static String defaultNameKey(String? role, {bool genderSwapped = false}) =>
      isFemaleRole(role, genderSwapped: genderSwapped)
      ? 'home_bnn_babaec'
      : 'home_bnnam_123ef2';
}
