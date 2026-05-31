import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

import 'offline_cache_service.dart';

/// ============================================================
///  ThemeSettingsService — Gra (Phase 25 Backend)
///  Lõi Cấu Hình Áo Mới (Themes, Avatars, Màu Sắc)
/// ============================================================
class ThemeSettingsService {
  static final ThemeSettingsService _instance =
      ThemeSettingsService._internal();
  factory ThemeSettingsService() => _instance;
  ThemeSettingsService._internal();

  final _db = FirebaseDatabase.instance;

  /// Áp dụng nhanh Màu sắc Không cần tải lại trang (Lưu RAM/SharedPreferences)
  Future<void> saveLocalTheme(String themeColorHex, bool isDarkMode) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString('app_primary_color', themeColorHex.trim());
    await prefs.setBool('app_is_dark', isDarkMode);

    debugPrint(
        "🎨 Hệ thống đã kích hoạt Cấu hình Màu Mới (RAM Local) ngay tức khắc!");
  }

  Map<String, dynamic>? getLocalThemeSync(SharedPreferences prefs) {
    return {
      'color': prefs.getString('app_primary_color') ?? '#E94057',
      'isDark': prefs.getBool('app_is_dark') ?? false,
    };
  }

  /// Đồng bộ màu sắc này qua máy của Đối phương!
  Future<void> uploadThemeToPartner(
      String houseId, String avatarFrameUrl, String themeColorHex) async {
    final normalizedHouseId = houseId.trim();
    final normalizedThemeColorHex = themeColorHex.trim();
    if (normalizedHouseId.isEmpty || normalizedThemeColorHex.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/ui_settings').set({
      'primaryThemeHex': normalizedThemeColorHex,
      'coupleAvatarFrame': avatarFrameUrl.trim(),
      'updatedAt': ServerValue.timestamp,
    });
  }

  /// Gọi ở initState MyApp để bắt Giao diện phải đổi màu theo Ý của Đối Phương
  Stream<Map<dynamic, dynamic>?> listenToPartnerThemeChanges(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<Map<dynamic, dynamic>?>.value(null);
    }
    return _db.ref('houses/$normalizedHouseId/ui_settings').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }
}
