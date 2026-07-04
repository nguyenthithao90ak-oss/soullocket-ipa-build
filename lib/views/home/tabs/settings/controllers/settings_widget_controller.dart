import 'package:shared_preferences/shared_preferences.dart';

class SettingsWidgetDraft {
  final String? draftWidgetThemeKey;
  final String widgetStyleKey;
  final bool showDiaryOnWidget;
  final bool widgetHeartAnimated;
  final String widgetHeartStyleKey;
  final String widgetHeartColorKey;
  final String widgetPreviewSizeKey;
  final String widgetDiaryLayoutKey;
  final String widgetSeasonModeKey;

  const SettingsWidgetDraft({
    required this.draftWidgetThemeKey,
    required this.widgetStyleKey,
    required this.showDiaryOnWidget,
    required this.widgetHeartAnimated,
    required this.widgetHeartStyleKey,
    required this.widgetHeartColorKey,
    required this.widgetPreviewSizeKey,
    required this.widgetDiaryLayoutKey,
    required this.widgetSeasonModeKey,
  });
}

class SettingsWidgetController {
  const SettingsWidgetController();

  Future<void> persistWidgetPrefs({
    required SharedPreferences prefs,
    required String? currentUid,
    required String? houseId,
    required SettingsWidgetDraft draft,
  }) async {
    final uidKey = currentUid ?? 'guest';
    final houseIdKey = houseId ?? 'local';
    final accountKey = '${uidKey}_$houseIdKey';

    await prefs.setString(
      'il_widget_theme_$accountKey',
      draft.draftWidgetThemeKey ?? 'pink',
    );
    await prefs.setString('il_widget_style_$accountKey', draft.widgetStyleKey);
    await prefs.setBool(
        'il_widget_show_diary_$accountKey', draft.showDiaryOnWidget);
    await prefs.setBool(
      'il_widget_heart_animated_$accountKey',
      draft.widgetHeartAnimated,
    );
    await prefs.setString(
      'il_widget_heart_style_$accountKey',
      draft.widgetHeartStyleKey,
    );
    await prefs.setString(
      'il_widget_heart_color_$accountKey',
      draft.widgetHeartColorKey,
    );
    await prefs.setString(
      'il_widget_preview_size_$accountKey',
      draft.widgetPreviewSizeKey,
    );
    await prefs.setString(
      'il_widget_diary_layout_$accountKey',
      draft.widgetDiaryLayoutKey,
    );
    await prefs.setString(
      'il_widget_season_mode_$accountKey',
      draft.widgetSeasonModeKey,
    );
  }
}
