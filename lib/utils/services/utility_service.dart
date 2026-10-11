import 'package:flutter/foundation.dart'
    show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_service.dart';
import 'offline_cache_service.dart';
import '../../models/house_settings.dart';

class UtilityLayoutSnapshot {
  const UtilityLayoutSnapshot({
    required this.pinnedApps,
    required this.recentApps,
  });

  final List<UtilityApp> pinnedApps;
  final List<UtilityApp> recentApps;
}

class UtilityAccountSnapshot {
  const UtilityAccountSnapshot({
    required this.houseId,
    required this.relationshipMode,
    required this.name,
  });

  final String houseId;
  final String? relationshipMode;
  final String? name;
}

/// Nhóm hiển thị trên trang Tiện ích.
enum UtilityCategory { memories, together, care, fun, other }

class UtilityApp {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final String id;
  final bool isTool;

  UtilityApp({
    required this.title,
    required this.icon,
    required this.colors,
    required this.id,
    this.isTool = false,
  });

  String get localizedTitle => L10nService().translate(title);
}

class UtilityService {
  /// Đọc cùng một snapshot trước frame đầu, tránh chèn shortcut sau khi vẽ lưới.
  UtilityLayoutSnapshot readLayout(SharedPreferences prefs) {
    List<UtilityApp> appsForIds(Iterable<String> ids) => ids
        .map((id) => _visibleAppsById[id])
        .whereType<UtilityApp>()
        .toList(growable: false);
    return UtilityLayoutSnapshot(
      pinnedApps: appsForIds(
        _sanitizeAppIds(prefs.getStringList(_pinnedAppsPrefKey) ?? []),
      ),
      recentApps: appsForIds(
        _sanitizeAppIds(
          prefs.getStringList(_recentAppsPrefKey) ?? [],
        ).take(_maxRecentApps),
      ),
    );
  }

  /// Chỉ dùng cache của đúng phiên hiện tại; đây không phải kiểm tra quyền.
  static UtilityAccountSnapshot? cachedAccount(
    SharedPreferences prefs,
    String? uid,
  ) {
    if (uid == null || prefs.getString('il_auth_uid') != uid) return null;
    final houseId = prefs.getString('il_house_id')?.trim();
    if (houseId == null || houseId.isEmpty) return null;
    String? mode;
    String? name;
    for (final key in [
      'home_settings_$houseId',
      'utilities_settings_$houseId',
    ]) {
      final cached = OfflineCacheService.loadCacheSync(key);
      if (cached is Map) {
        mode ??= HouseSettings.inferRelationshipModeFromSettingsMap(cached);
        final cachedName = cached['nameU1']?.toString().trim();
        if (cachedName != null && cachedName.isNotEmpty) name ??= cachedName;
      }
    }
    final storedMode = prefs.getString('il_rel_mode');
    return UtilityAccountSnapshot(
      houseId: houseId,
      relationshipMode:
          mode ??
          (storedMode == 'single' || storedMode == 'couple'
              ? storedMode
              : null),
      name: name,
    );
  }

  static const String _pinnedAppsPrefKey = 'il_pinned_utility_ids';
  static const String _recentAppsPrefKey = 'il_recent_utility_ids';
  static const int _maxRecentApps = 6;
  static const Set<String> _coupleOnlyIds = {
    'voice',
    'finance',
    'capsule',
    'calendar',
    'cinema',
    'surprise_maker',
  };
  /// Tiện ích dành cho tài khoản Pro: vẫn hiện cho mọi người kèm nhãn VIP;
  /// tài khoản thường mở ra sẽ thấy lời mời nâng cấp. Server chặn riêng
  /// (functions/index.js), đây chỉ là lớp hiển thị.
  static const Set<String> _proOnlyIds = {'friendly_chat'};

  /// Trạng thái Pro do PurchaseService cập nhật; null = chưa xác minh.
  static final ValueNotifier<bool?> proAccess = ValueNotifier<bool?>(null);

  static void setProAccess(bool? value) {
    if (proAccess.value == value) return;
    proAccess.value = value;
  }

  static bool isProOnly(String id) => _proOnlyIds.contains(id.trim());

  static final Set<String> _allAppIds = allApps
      .map((UtilityApp app) => app.id)
      .toSet();
  static final Map<String, UtilityApp> _visibleAppsById = {
    for (final UtilityApp app in allApps)
      if (isUtilityVisibleInCurrentBuild(app.id)) app.id: app,
  };

  static String normalizeRelationshipMode(String? relationshipMode) {
    final mode = relationshipMode?.trim().toLowerCase();
    return mode == 'couple' ? 'couple' : 'single';
  }

  static bool isCoupleOnly(String id) => _coupleOnlyIds.contains(id);

  static bool isUtilityVisibleInCurrentBuild(String id) {
    // Giftcode đã chuyển vào Cài đặt Android, không còn là một tiện ích.
    if (id == 'giftcode') return false;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        id == 'soul_events') {
      return false;
    }
    return true;
  }

  static bool isUtilityAllowed(String id, String? relationshipMode) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || !isUtilityVisibleInCurrentBuild(normalizedId)) {
      return false;
    }
    final mode = normalizeRelationshipMode(relationshipMode);
    if (mode == 'single' && isCoupleOnly(normalizedId)) return false;
    return true;
  }

  static String blockedMessageForMode(String id, String? relationshipMode) {
    if (isUtilityAllowed(id, relationshipMode)) {
      return '';
    }
    if (isCoupleOnly(id)) {
      return L10nService().translate('utility_couple_mode_blocked');
    }
    return L10nService().translate('utility_mode_blocked');
  }

  static List<UtilityApp> appsForMode(String? relationshipMode) {
    return _visibleAppsById.values
        .where((app) => isUtilityAllowed(app.id, relationshipMode))
        .toList(growable: false);
  }

  /// Thứ tự trong từng nhóm; ô đầu tiên của nhóm "together" là ô lớn.
  static const Map<UtilityCategory, List<String>> categoryAppIds = {
    UtilityCategory.memories: [
      'local_album',
      'collage',
      'cinema',
      'creative_diary',
      'surprise_maker',
      'capsule',
      'soul_events',
    ],
    UtilityCategory.together: [
      'calendar',
      'note',
      'finance',
      'voice',
      'couple_connect',
    ],
    UtilityCategory.care: ['habit', 'health', 'sleep_tracker'],
    UtilityCategory.fun: ['tarot', 'wheel', 'drawing', 'friendly_chat'],
    UtilityCategory.other: ['vault', 'diary_export', 'store'],
  };

  static UtilityCategory categoryOf(String id) {
    for (final entry in categoryAppIds.entries) {
      if (entry.value.contains(id)) return entry.key;
    }
    return UtilityCategory.other;
  }

  /// Tiện ích được phép theo chế độ, gom theo nhóm; bỏ nhóm rỗng.
  static Map<UtilityCategory, List<UtilityApp>> appsByCategory(
    String? relationshipMode,
  ) {
    final allowed = {
      for (final app in appsForMode(relationshipMode)) app.id: app,
    };
    final result = <UtilityCategory, List<UtilityApp>>{
      for (final category in UtilityCategory.values) category: <UtilityApp>[],
    };
    for (final category in UtilityCategory.values) {
      for (final id in categoryAppIds[category] ?? const <String>[]) {
        final app = allowed.remove(id);
        if (app != null) result[category]!.add(app);
      }
    }
    // Tiện ích mới chưa được xếp nhóm vẫn hiện ở "Khác".
    result[UtilityCategory.other]!.addAll(allowed.values);
    result.removeWhere((_, apps) => apps.isEmpty);
    return result;
  }

  /// Tăng mỗi khi danh sách ghim đổi để trang Nhà tải lại.
  static final ValueNotifier<int> pinnedAppsRevision = ValueNotifier<int>(0);

  static final List<UtilityApp> allApps = [
    UtilityApp(
      id: 'local_album',
      title: 'util_luunhtbit_6f4b4a',
      icon: Icons.photo_library_rounded,
      colors: [const Color(0xFF7C4DFF), const Color(0xFF448AFF)],
    ),
    UtilityApp(
      id: 'soul_events',
      title: 'copy_fc725e371ce1',
      icon: Icons.event_note_rounded,
      colors: [const Color(0xFFFF4D94), const Color(0xFFFF8C42)],
    ),
    UtilityApp(
      id: 'voice',
      title: 'utility_title_voice',
      icon: Icons.mic_none_rounded,
      colors: [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      isTool: true,
    ),
    UtilityApp(
      id: 'note',
      title: 'utility_title_note',
      icon: Icons.description_rounded,
      colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    ),
    UtilityApp(
      id: 'friendly_chat',
      title: 'utility_title_friendly_chat',
      icon: Icons.smart_toy_rounded,
      colors: [const Color(0xFFD81B60), const Color(0xFFFF8FB7)],
      isTool: false,
    ),
    UtilityApp(
      id: 'capsule',
      title: 'utility_title_capsule',
      icon: Icons.mark_as_unread_rounded,
      colors: [const Color(0xFFB224EF), const Color(0xFF7579FF)],
    ),
    UtilityApp(
      id: 'finance',
      title: 'utility_title_finance',
      icon: Icons.account_balance_wallet_rounded,
      colors: [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
    ),
    UtilityApp(
      id: 'habit',
      title: 'utility_title_habit',
      icon: Icons.task_alt_rounded,
      colors: [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
    ),
    UtilityApp(
      id: 'drawing',
      title: 'utility_title_drawing',
      icon: Icons.brush_rounded,
      colors: [const Color(0xFFFF7AAE), const Color(0xFFD81B60)],
    ),
    UtilityApp(
      id: 'wheel',
      title: 'utility_title_wheel',
      icon: Icons.incomplete_circle_rounded,
      colors: [const Color(0xFFFC4A1A), const Color(0xFFF7B733)],
    ),
    UtilityApp(
      id: 'surprise_maker',
      title: 'copy_acc31b27dfe9',
      icon: Icons.favorite_rounded,
      colors: [const Color(0xFFFF758C), const Color(0xFFFF7EB3)],
    ),
    UtilityApp(
      id: 'diary_export',
      title: 'utility_title_diary_export',
      icon: Icons.language_rounded,
      colors: [const Color(0xFF5DA9FF), const Color(0xFF7C4DFF)],
      isTool: true,
    ),
    UtilityApp(
      id: 'vault',
      title: 'utility_title_vault',
      icon: Icons.enhanced_encryption_rounded,
      colors: [const Color(0xFF1F1C2C), const Color(0xFF928DAB)],
    ),
    UtilityApp(
      id: 'cinema',
      title: 'utility_title_cinema',
      icon: Icons.movie_filter_rounded,
      colors: [const Color(0xFFE53935), const Color(0xFFE35D5B)],
    ),
    UtilityApp(
      id: 'calendar',
      title: 'utility_title_calendar',
      icon: Icons.calendar_today_rounded,
      colors: [const Color(0xFF3A1C71), const Color(0xFFD76D77)],
    ),
    UtilityApp(
      id: 'tarot',
      title: 'utility_title_tarot',
      icon: Icons.auto_awesome_rounded,
      colors: [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
    ),
    UtilityApp(
      id: 'collage',
      title: 'utility_title_collage',
      icon: Icons.auto_awesome_mosaic_rounded,
      colors: [const Color(0xFFFF9A9E), const Color(0xFFFECFEF)],
    ),
    UtilityApp(
      id: 'store',
      title: 'utility_title_store',
      icon: Icons.shopping_bag_rounded,
      colors: [const Color(0xFFFFC107), const Color(0xFFFF9800)],
    ),
    UtilityApp(
      id: 'creative_diary',
      title: 'utility_title_creative_diary',
      icon: Icons.menu_book_rounded,
      colors: [const Color(0xFF4CAF50), const Color(0xFF1B5E20)],
    ),
    UtilityApp(
      id: 'health',
      title: 'health',
      icon: Icons.health_and_safety_rounded,
      colors: [const Color(0xFFFF80AB), const Color(0xFFF06292)],
    ),
    UtilityApp(
      id: 'sleep_tracker',
      title: 'copy_e0f3f270aa01',
      icon: Icons.bedtime_rounded,
      colors: [const Color(0xFF5E35B1), const Color(0xFF3949AB)],
    ),
    UtilityApp(
      id: 'couple_connect',
      title: 'home_qunllinkt_df5d77',
      icon: Icons.link_rounded,
      colors: [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
      isTool: true,
    ),
  ];

  List<String> _sanitizeAppIds(Iterable<String> rawIds) {
    final sanitized = <String>[];
    final seen = <String>{};
    for (final rawId in rawIds) {
      final normalizedId = rawId.trim();
      if (normalizedId.isEmpty || !_allAppIds.contains(normalizedId)) {
        continue;
      }
      if (!isUtilityVisibleInCurrentBuild(normalizedId)) {
        continue;
      }
      if (seen.add(normalizedId)) {
        sanitized.add(normalizedId);
      }
    }
    return sanitized;
  }

  Future<List<String>> getPinnedAppIds() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_pinnedAppsPrefKey) ?? const <String>[];
    final sanitized = _sanitizeAppIds(stored);
    if (sanitized.length != stored.length) {
      await prefs.setStringList(_pinnedAppsPrefKey, sanitized);
    }
    return sanitized;
  }

  /// Trả về trạng thái ghim sau khi đổi.
  Future<bool> togglePinApp(String appId) async {
    final normalizedId = appId.trim();
    if (normalizedId.isEmpty) return false;
    if (!isUtilityVisibleInCurrentBuild(normalizedId)) return false;

    if (!_allAppIds.contains(normalizedId)) return false;

    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final current = _sanitizeAppIds(
      prefs.getStringList(_pinnedAppsPrefKey) ?? const <String>[],
    );

    final wasPinned = current.contains(normalizedId);
    if (wasPinned) {
      current.removeWhere((id) => id == normalizedId);
    } else {
      current.add(normalizedId);
    }

    await prefs.setStringList(_pinnedAppsPrefKey, current);
    pinnedAppsRevision.value++;
    return !wasPinned;
  }

  Future<List<UtilityApp>> getPinnedApps() async {
    final pinnedIds = await getPinnedAppIds();
    if (pinnedIds.isEmpty) return const <UtilityApp>[];

    return pinnedIds
        .map((id) => _visibleAppsById[id])
        .whereType<UtilityApp>()
        .toList(growable: false);
  }

  Future<List<String>> getRecentAppIds() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentAppsPrefKey) ?? const <String>[];
    final sanitized = _sanitizeAppIds(stored).take(_maxRecentApps).toList();
    if (sanitized.length != stored.length) {
      await prefs.setStringList(_recentAppsPrefKey, sanitized);
    }
    return sanitized;
  }

  Future<void> markAppAsRecentlyUsed(String appId) async {
    final normalizedId = appId.trim();
    if (normalizedId.isEmpty) return;
    if (!isUtilityVisibleInCurrentBuild(normalizedId)) return;

    if (!_allAppIds.contains(normalizedId)) return;

    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final current = await getRecentAppIds();
    current.removeWhere((id) => id == normalizedId);
    current.insert(0, normalizedId);
    final limited = current.take(_maxRecentApps).toList(growable: false);
    await prefs.setStringList(_recentAppsPrefKey, limited);
  }

  Future<List<UtilityApp>> getRecentApps() async {
    final recentIds = await getRecentAppIds();
    if (recentIds.isEmpty) return const <UtilityApp>[];

    return recentIds
        .map((id) => _visibleAppsById[id])
        .whereType<UtilityApp>()
        .toList(growable: false);
  }
}
