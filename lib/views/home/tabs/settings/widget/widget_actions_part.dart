part of '../../settings_tab.dart';

extension _SettingsTabWidgetActionsPart on _SettingsTabState {
  Future<void> _persistWidgetPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = _auth.currentUser?.uid;
    final draft = SettingsWidgetDraft(
      draftWidgetThemeKey: _draftWidgetThemeKey,
      widgetStyleKey: _widgetStyleKey,
      showDiaryOnWidget: _showDiaryOnWidget,
      widgetHeartAnimated: _widgetHeartAnimated,
      widgetHeartStyleKey: _widgetHeartStyleKey,
      widgetHeartColorKey: _widgetHeartColorKey,
      widgetPreviewSizeKey: _widgetPreviewSizeKey,
      widgetDiaryLayoutKey: _widgetDiaryLayoutKey,
      widgetStickerKey: _widgetStickerKey,
      widgetPhotoFrameKey: _widgetPhotoFrameKey,
      widgetSeasonModeKey: _widgetSeasonModeKey,
    );
    await _settingsWidgetController.persistWidgetPrefs(
      prefs: prefs,
      currentUid: currentUid,
      houseId: _houseId,
      draft: draft,
    );
  }

  Future<void> _persistAndSyncWidgetAppearance() async {
    await _persistWidgetPrefs();
    await _syncWidgetAppearanceDraft();
    if (mounted) setState(() => _widgetMediaRevision++);
  }

  Future<void> _updateWidgetAppearanceDraft(VoidCallback updateFn) async {
    setState(updateFn);
    _widgetAppearanceSaveQueue = _widgetAppearanceSaveQueue
        .then((_) async {
          if (mounted) await _persistAndSyncWidgetAppearance();
        })
        .catchError((Object error) {
          debugPrint('Widget appearance save failed: $error');
          if (mounted) _showToast(context.tr('home_chathcpnht_1f5871'));
        });
    await _widgetAppearanceSaveQueue;
  }

  Future<void> _handleWidgetThemeChanged(String value) async {
    _updateThemeDraft(() => _draftWidgetThemeKey = value);
    await _persistAndSyncWidgetAppearance();
  }

  Future<void> _handleWidgetPanelTabChanged(String value) async {
    final normalizedStyle = WidgetService.normalizeWidgetStyleKey(value);
    await _updateWidgetAppearanceDraft(() {
      _widgetPanelTabKey = normalizedStyle;
      _widgetStyleKey = normalizedStyle;
    });
  }

  Future<void> _handleWidgetHeartStyleChanged(String value) async {
    await _updateWidgetAppearanceDraft(() {
      _widgetHeartStyleKey = _normalizeWidgetHeartStyleKey(value);
      _widgetStickerKey = 'none';
      _showDiaryOnWidget = false;
    });
  }

  Future<void> _handleWidgetStickerChanged(String value) async {
    await _updateWidgetAppearanceDraft(() {
      _widgetStickerKey = WidgetAppearance.normalizeSticker(value);
      _showDiaryOnWidget = false;
    });
  }

  Future<void> _handleWidgetDiaryVisibilityChanged(bool value) async {
    await _updateWidgetAppearanceDraft(() {
      _showDiaryOnWidget = value;
    });
  }
}
