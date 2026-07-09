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
}
