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
  }

  Future<void> _updateWidgetAppearanceDraft(VoidCallback updateFn) async {
    setState(updateFn);
    await _persistAndSyncWidgetAppearance();
  }

  Future<void> _openPremiumStoreFromWidgetPanel() async {
    if (!AppConfig.isPurchaseEnabled) {
      _showToast(context.tr('home_mcnyangtmn_fdd99c'), success: false);
      return;
    }

    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      _showToast(context.tr('home_hyvonhtrck_c33334'), success: false);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumStoreScreen(
          houseId: houseId,
          myName: _nameU1.trim().isEmpty
              ? context.tr('home_bn_1fd75b')
              : _nameU1.trim(),
        ),
      ),
    );
    await _loadVipStatus();
  }

  Future<void> _handleWidgetThemeChanged(String value) async {
    if ((value == 'premium' || value == 'cosmic') && !_isVipActive) {
      if (!AppConfig.isPurchaseEnabled) {
        _showToast(
          context.tr('home_lachnnyang_d9f089'),
          success: false,
        );
        return;
      }
      _showToast(
        context.tr('home_lachnnycha_2b9ddb'),
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
