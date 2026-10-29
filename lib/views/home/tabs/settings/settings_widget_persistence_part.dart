// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../settings_tab.dart';

extension _SettingsTabWidgetPersistence on _SettingsTabState {
  Future<List<String>?> _loadWidgetDiaryUrls({int limit = 12}) async {
    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      return const <String>[];
    }
    try {
      // Cùng truy vấn với Home: đọc qua listener ngắn để dùng lại bộ nhớ đệm RTDB.
      final snapshots = await Future.wait([
        readQuerySettled(
          _dbRef
              .child('houses/$houseId/memories')
              .orderByChild('ts')
              .limitToLast(24),
          timeout: const Duration(seconds: 4),
        ),
        readQuerySettled(
          _dbRef.child('houses/$houseId/diary').limitToLast(24),
          timeout: const Duration(seconds: 4),
        ),
      ]);
      return collectWidgetDiaryImageSources(
        houseId: houseId,
        snapshots: snapshots.map((snapshot) => snapshot.value),
        limit: limit,
      );
    } catch (_) {
      // Lỗi mạng không có nghĩa album rỗng: giữ ảnh native đã đồng bộ.
      return null;
    }
  }

  Future<void> _syncWidgetAppearanceDraft() async {
    if (kIsWeb) return;
    final uid = _auth.currentUser?.uid;
    final houseId = _houseId;
    final widgetThemeKey = _draftWidgetThemeKey ?? 'pink';
    final diaryImageUrls = _showDiaryOnWidget
        ? await _loadWidgetDiaryUrls()
        : const <String>[];
    if (!mounted || _auth.currentUser?.uid != uid || _houseId != houseId) return;
    await WidgetService.updateWidgetAppearance(
      bgTheme: widgetThemeKey,
      widgetStyleKey: _widgetStyleKey,
      showDiaryOnWidget: _showDiaryOnWidget,
      heartAnimated: _widgetHeartAnimated,
      heartMotionIntervalMinutes: _widgetMotionIntervalMinutes,
      heartStyleKey: _widgetHeartStyleKey,
      heartColorKey: _widgetHeartColorKey,
      diaryLayoutKey: _widgetDiaryLayoutKey,
      widgetStickerKey: _widgetStickerKey,
      photoFrameKey: _widgetPhotoFrameKey,
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
      'il_widget_use_custom_event_$accountKey',
      _useCustomWidgetEvent,
    );
    await prefs.setString(
      'il_widget_custom_event_title_$accountKey',
      _customWidgetEventTitleCtrl.text,
    );
    await prefs.setString(
      'il_widget_custom_event_date_$accountKey',
      _customWidgetEventDateCtrl.text,
    );
    await prefs.setString(
      'il_widget_custom_event_color_$accountKey',
      _customWidgetEventColorHex,
    );

    // Also save under non-account specific keys for WidgetService to read directly
    await prefs.setBool('widget_use_custom_event', _useCustomWidgetEvent);
    await prefs.setString(
      'widget_custom_event_title',
      _customWidgetEventTitleCtrl.text,
    );
    await prefs.setString(
      'widget_custom_event_date',
      _customWidgetEventDateCtrl.text,
    );
    await prefs.setString(
      'widget_custom_event_color',
      _customWidgetEventColorHex,
    );

    // Trigger widget preview tick to rebuild preview
    _widgetPreviewTickNotifier.value = _widgetPreviewTickNotifier.value + 1;

    // Sync widget data
    final houseId = _houseId ?? '';
    if (houseId.isNotEmpty) {
      await WidgetService.syncSoulEventWidgetData(houseId: houseId);
    }
  }
}
