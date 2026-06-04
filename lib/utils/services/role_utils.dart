import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

class RoleUtils {
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
}
