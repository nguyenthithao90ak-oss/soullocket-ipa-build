import 'package:flutter/foundation.dart' show kDebugMode, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../views/utilities/utilities_config.dart';
import 'l10n_service.dart';

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
  static const String _customOrderPrefKey = 'il_utility_order';
  static const String _pinnedAppsPrefKey = 'il_pinned_utility_ids';
  static const String _recentAppsPrefKey = 'il_recent_utility_ids';
  static const int _maxRecentApps = 6;
  static final List<String> _defaultOrder = [
    ...utilitiesHubDefaultOrder,
    ...allApps.map((UtilityApp app) => app.id),
  ];
  static const Set<String> _coupleOnlyIds = {
    'voice',
    'wish',
    'finance',
    'capsule',
    'calendar',
    'cinema',
    'gift',
    'love_card',
  };
  static const Set<String> _debugOnlyIds = {
    'sticker_library',
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

  static final List<UtilityApp> allApps = [
    UtilityApp(
      id: 'giftcode',
      title: 'utility_title_giftcode',
      icon: Icons.confirmation_number_rounded,
      colors: [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
    ),
    UtilityApp(
      id: 'voice',
      title: 'utility_title_voice',
      icon: Icons.mic_none_rounded,
      colors: [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      isTool: true,
    ),
    UtilityApp(
      id: 'bucket',
      title: 'utility_title_bucket',
      icon: Icons.auto_awesome_motion_rounded,
      colors: [const Color(0xFFF7971E), const Color(0xFFFFD200)],
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
      isTool: true,
    ),
    UtilityApp(
      id: 'history',
      title: 'utility_title_history',
      icon: Icons.history_rounded,
      colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
      isTool: true,
    ),
    UtilityApp(
      id: 'wish',
      title: 'utility_title_wish',
      icon: Icons.auto_awesome_rounded,
      colors: [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
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
      id: 'sticker_library',
      title: 'Kho sticker',
      icon: Icons.emoji_emotions_rounded,
      colors: [const Color(0xFFFF8FB7), const Color(0xFF8E7BFF)],
      isTool: true,
    ),
    UtilityApp(
      id: 'wheel',
      title: 'utility_title_wheel',
      icon: Icons.incomplete_circle_rounded,
      colors: [const Color(0xFFFC4A1A), const Color(0xFFF7B733)],
    ),
    UtilityApp(
      id: 'gift',
      title: 'utility_title_gift',
      icon: Icons.redeem_rounded,
      colors: [const Color(0xFF00B09B), const Color(0xFF96C93D)],
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
      id: 'calculator',
      title: 'utility_title_calculator',
      icon: Icons.calculate_rounded,
      colors: [const Color(0xFF5C6BC0), const Color(0xFF8E99F3)],
      isTool: true,
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
      id: 'age_zodiac',
      title: 'utility_title_age_zodiac',
      icon: Icons.brightness_3_rounded,
      colors: [const Color(0xFFCE93D8), const Color(0xFFAB47BC)],
    ),
    UtilityApp(
      id: 'love_card',
      title: 'utility_title_love_card',
      icon: Icons.style_rounded,
      colors: [const Color(0xFFE94057), const Color(0xFFF27185)],
    ),
    UtilityApp(
      id: 'creative_diary',
      title: 'utility_title_creative_diary',
      icon: Icons.menu_book_rounded,
      colors: [const Color(0xFF4CAF50), const Color(0xFF1B5E20)],
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

  List<String> _completeOrder(Iterable<String> rawIds) {
    final order = _sanitizeAppIds(rawIds);
    final seen = order.toSet();
    for (final appId in _defaultOrder) {
      if (!_allAppIds.contains(appId) ||
          !isUtilityVisibleInCurrentBuild(appId)) {
        continue;
      }
      if (seen.add(appId)) {
        order.add(appId);
      }
    }
    return order;
  }

  Future<List<String>> getCustomOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_customOrderPrefKey) ?? const <String>[];
    final order = _completeOrder(stored);
    if (stored.isNotEmpty && order.length != stored.length) {
      await prefs.setStringList(_customOrderPrefKey, _sanitizeAppIds(stored));
    }
    return order;
  }

  Future<void> saveCustomOrder(Iterable<String> appIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customOrderPrefKey, _sanitizeAppIds(appIds));
  }

  Future<void> clearCustomOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customOrderPrefKey);
  }

  Future<List<String>> getPinnedAppIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_pinnedAppsPrefKey) ?? const <String>[];
    final sanitized = _sanitizeAppIds(stored);
    if (sanitized.length != stored.length) {
      await prefs.setStringList(_pinnedAppsPrefKey, sanitized);
    }
    return sanitized;
  }

  Future<void> togglePinApp(String appId) async {
    final normalizedId = appId.trim();
    if (normalizedId.isEmpty) return;
    if (!isUtilityVisibleInCurrentBuild(normalizedId)) return;

    if (!_allAppIds.contains(normalizedId)) return;

    final prefs = await SharedPreferences.getInstance();
    final current = _sanitizeAppIds(
      prefs.getStringList(_pinnedAppsPrefKey) ?? const <String>[],
    );

    if (current.contains(normalizedId)) {
      current.removeWhere((id) => id == normalizedId);
    } else {
      current.add(normalizedId);
    }

    await prefs.setStringList(_pinnedAppsPrefKey, current);
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
    final prefs = await SharedPreferences.getInstance();
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

    final prefs = await SharedPreferences.getInstance();
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

