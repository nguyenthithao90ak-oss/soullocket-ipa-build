import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../utils/services/offline_cache_service.dart';
import 'pairing_shortcut_state.dart';

class PairingDisplayCache {
  static String cacheKey(String uid, String houseId) =>
      'pairing_display_${uid}_$houseId';

  static PairingShortcutState restore({
    required String? uid,
    required String houseId,
    required SharedPreferences? prefs,
    dynamic Function(String key)? readCache,
  }) {
    if (uid == null ||
        uid.isEmpty ||
        houseId.isEmpty ||
        prefs?.getString('il_auth_uid') != uid ||
        prefs?.getString('il_house_id') != houseId) {
      return PairingShortcutState();
    }
    final read =
        readCache ??
        (key) =>
            OfflineCacheService.getMemoryCache(key) ??
            OfflineCacheService.loadCacheSync(key);
    final saved = read(cacheKey(uid, houseId));
    final scoped =
        saved is Map && saved['uid'] == uid && saved['houseId'] == houseId;
    if (scoped && saved['paired'] is bool && saved['settings'] is Map) {
      return PairingShortcutState(cachedSnapshot: saved);
    }
    final fallback = read('home_settings_$houseId');
    return PairingShortcutState(
      cachedSnapshot: scoped ? saved : null,
      cachedSettings: fallback is Map ? fallback : null,
    );
  }

  static Future<void> remember({
    required String uid,
    required String houseId,
    required PairingShortcutState state,
  }) async {
    if (!state.confirmed) return;
    final prefs = OfflineCacheService.getPrefsSync();
    if (prefs?.getString('il_auth_uid') != uid ||
        prefs?.getString('il_house_id') != houseId) {
      return;
    }
    final data = state.toCache();
    if (data == null) return;
    final snapshot = {...data, 'uid': uid, 'houseId': houseId};
    final key = cacheKey(uid, houseId);
    OfflineCacheService.setMemoryCache(key, snapshot, const Duration(hours: 8));
    await OfflineCacheService.saveCache(key, snapshot);
  }
}
