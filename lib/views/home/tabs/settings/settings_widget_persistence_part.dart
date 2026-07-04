part of '../settings_tab.dart';

extension _SettingsTabWidgetPersistence on _SettingsTabState {
  int _widgetMemorySortValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  List<String> _extractWidgetDiaryUrls(
    dynamic raw, {
    int limit = 5,
  }) {
    if (raw is! Map) return const <String>[];

    final items = <MapEntry<int, String>>[];
    raw.forEach((_, value) {
      if (value is! Map) return;
      final map = value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
      final imageUrl = (map['url'] ?? map['imageUrl'] ?? map['thumbUrl'] ?? '')
          .toString()
          .trim();
      if (imageUrl.isEmpty) return;
      final sortValue = _widgetMemorySortValue(
        map['ts'] ?? map['date'] ?? map['updatedAt'],
      );
      items.add(MapEntry(sortValue, imageUrl));
    });

    items.sort((a, b) => b.key.compareTo(a.key));
    final seen = <String>{};
    return items
        .map((item) => item.value)
        .where((url) => seen.add(url))
        .take(limit)
        .toList(growable: false);
  }

  Future<List<String>> _loadWidgetDiaryUrls({int limit = 5}) async {
    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      return const <String>[];
    }
    try {
      final snapshot =
          await _dbRef.child('houses/$houseId/memories').limitToLast(12).get();
      return _extractWidgetDiaryUrls(snapshot.value, limit: limit);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _syncWidgetAppearanceDraft() async {
    if (kIsWeb) return;
    final widgetThemeKey = _draftWidgetThemeKey ?? 'pink';
    final diaryImageUrls =
        _showDiaryOnWidget ? await _loadWidgetDiaryUrls() : const <String>[];
    await WidgetService.updateWidgetAppearance(
      bgTheme: widgetThemeKey,
      widgetStyleKey: _widgetStyleKey,
      showDiaryOnWidget: _showDiaryOnWidget,
      heartAnimated: _widgetHeartAnimated,
      heartStyleKey: _widgetHeartStyleKey,
      heartColorKey: _widgetHeartColorKey,
      diaryLayoutKey: _widgetDiaryLayoutKey,
      seasonModeKey: _widgetSeasonModeKey,
      loveDate: _loveDate,
      birthday1: _dobU1,
      birthday2: _dobU2,
      diaryImageUrls: diaryImageUrls,
    );
  }

  Future<void> _saveCustomWidgetEventSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = _auth.currentUser?.uid ?? 'guest';
    final houseIdKey = _houseId ?? 'local';
    final accountKey = '${currentUid}_$houseIdKey';

    await prefs.setBool(
        'il_widget_use_custom_event_$accountKey', _useCustomWidgetEvent);
    await prefs.setString('il_widget_custom_event_title_$accountKey',
        _customWidgetEventTitleCtrl.text);
    await prefs.setString('il_widget_custom_event_date_$accountKey',
        _customWidgetEventDateCtrl.text);
    await prefs.setString(
        'il_widget_custom_event_color_$accountKey', _customWidgetEventColorHex);

    // Also save under non-account specific keys for WidgetService to read directly
    await prefs.setBool('widget_use_custom_event', _useCustomWidgetEvent);
    await prefs.setString(
        'widget_custom_event_title', _customWidgetEventTitleCtrl.text);
    await prefs.setString(
        'widget_custom_event_date', _customWidgetEventDateCtrl.text);
    await prefs.setString(
        'widget_custom_event_color', _customWidgetEventColorHex);

    // Trigger widget preview tick to rebuild preview
    _widgetPreviewTickNotifier.value = _widgetPreviewTickNotifier.value + 1;

    // Sync widget data
    final houseId = _houseId ?? '';
    if (houseId.isNotEmpty) {
      await WidgetService.syncSoulEventWidgetData(houseId: houseId);
    }
  }
}
