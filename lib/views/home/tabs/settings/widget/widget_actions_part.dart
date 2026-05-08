part of '../../settings_tab.dart';

extension _SettingsTabWidgetActionsPart on _SettingsTabState {
  Future<void> _persistWidgetPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = _auth.currentUser?.uid ?? 'guest';
    final houseIdKey = _houseId ?? 'local';
    final accountKey = '${currentUid}_$houseIdKey';

    await prefs.setString(
      'il_widget_theme_$accountKey',
      _draftWidgetThemeKey ?? 'pink',
    );
    await prefs.setString('il_widget_style_$accountKey', _widgetStyleKey);
    await prefs.setBool('il_widget_show_diary_$accountKey', _showDiaryOnWidget);
    await prefs.setBool(
      'il_widget_heart_animated_$accountKey',
      _widgetHeartAnimated,
    );
    await prefs.setString(
      'il_widget_heart_style_$accountKey',
      _widgetHeartStyleKey,
    );
    await prefs.setString(
      'il_widget_heart_color_$accountKey',
      _widgetHeartColorKey,
    );
    await prefs.setString(
      'il_widget_preview_size_$accountKey',
      _widgetPreviewSizeKey,
    );
    await prefs.setString(
      'il_widget_diary_layout_$accountKey',
      _widgetDiaryLayoutKey,
    );
    await prefs.setString(
      'il_widget_season_mode_$accountKey',
      _widgetSeasonModeKey,
    );
  }

  Future<void> _persistAndSyncWidgetAppearance() async {
    await _persistWidgetPrefs();
    await _syncWidgetAppearanceDraft();
  }

  Future<void> _updateWidgetAppearanceDraft(VoidCallback updateFn) async {
    setState(updateFn);
    await _persistAndSyncWidgetAppearance();
  }

  Future<void> _openPremiumStoreFromWidgetPanel() async {
    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      _showToast('Hãy vào nhà trước khi mở gói PRO.', success: false);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumStoreScreen(
          houseId: houseId,
          myName: _nameU1.trim().isEmpty ? 'Bạn' : _nameU1.trim(),
        ),
      ),
    );
    await _loadVipStatus();
  }

  Future<void> _handleWidgetThemeChanged(String value) async {
    if (value == 'premium' && !_isVipActive) {
      _showToast(
        'Nền Aurora PRO chỉ mở cho tài khoản PRO.',
        success: false,
      );
      await _openPremiumStoreFromWidgetPanel();
      return;
    }
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
    await _updateWidgetAppearanceDraft(
      () => _widgetHeartStyleKey = _normalizeWidgetHeartStyleKey(value),
    );
  }

  Future<void> _handleWidgetHeartColorChanged(String value) async {
    await _updateWidgetAppearanceDraft(() => _widgetHeartColorKey = value);
  }

  Future<void> _handleWidgetDiaryVisibilityChanged(bool value) async {
    await _updateWidgetAppearanceDraft(() {
      _showDiaryOnWidget = value;
      if (value) {
        _widgetHeartAnimated = false;
      }
    });
  }

  Future<void> _handleWidgetHeartAnimatedChanged(bool value) async {
    await _updateWidgetAppearanceDraft(() {
      _widgetHeartAnimated = value;
      if (value) {
        _showDiaryOnWidget = false;
      }
    });
  }

}
