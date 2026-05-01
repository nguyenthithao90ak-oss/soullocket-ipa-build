part of '../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

extension _CountdownModeSnapshotCodec on _CountdownModeIndependentScreenState {
  bool _hasLocalCountdownStyleAccess(String styleKey) {
    return widget.isVipActive ||
        !_CountdownModeIndependentScreenState._isPremiumCountdownStyleKey(
          styleKey,
        ) ||
        _unlockedCountdownStyleKeys.contains(styleKey.trim().toLowerCase());
  }

  String _sanitizeCountdownSpaceStyle(String styleKey) {
    return _CountdownModeIndependentScreenState._safeCountdownStyleKey(
      styleKey: styleKey,
      isVipActive: widget.isVipActive,
      hasAdUnlock: _hasLocalCountdownStyleAccess(styleKey),
    );
  }

  _CountdownSpaceSnapshot _sanitizeSnapshot(_CountdownSpaceSnapshot snapshot) {
    return _CountdownSpaceSnapshot(
      singleMode: snapshot.singleMode,
      anchorDate: snapshot.anchorDate,
      themeKey: snapshot.themeKey,
      styleKey: _sanitizeCountdownSpaceStyle(snapshot.styleKey),
      frameKey: snapshot.frameKey,
      fontKey: snapshot.fontKey,
      transparentMode: snapshot.transparentMode,
      sizePx: snapshot.sizePx,
      topLabel: snapshot.topLabel,
      bottomLabel: snapshot.bottomLabel,
      nameU1: snapshot.nameU1,
      nameU2: snapshot.nameU2,
      avatarUrl1: snapshot.avatarUrl1,
      avatarUrl2: snapshot.avatarUrl2,
      customBackgroundUrl: snapshot.customBackgroundUrl,
      centerIconType: snapshot.centerIconType,
    );
  }

  Map<String, dynamic> _snapshotToSerializedMap(
    _CountdownSpaceSnapshot snapshot,
  ) {
    return <String, dynamic>{
      'singleMode': snapshot.singleMode,
      'anchorDate': snapshot.anchorDate == null
          ? ''
          : DateInputUtils.formatIsoDate(snapshot.anchorDate!),
      'themeKey': snapshot.themeKey,
      'styleKey': _sanitizeCountdownSpaceStyle(snapshot.styleKey),
      'frameKey': snapshot.frameKey,
      'fontKey': snapshot.fontKey,
      'transparentMode': snapshot.transparentMode,
      'sizePx': snapshot.sizePx,
      'topLabel': snapshot.topLabel,
      'bottomLabel': snapshot.bottomLabel,
      'nameU1': snapshot.nameU1,
      'nameU2': snapshot.nameU2,
      'avatarUrl1': snapshot.avatarUrl1,
      'avatarUrl2': snapshot.avatarUrl2,
      'customBackgroundUrl': snapshot.customBackgroundUrl,
      'centerIconType': snapshot.centerIconType,
    };
  }

  _CountdownSpaceSnapshot _snapshotFromSerializedMap(
    Map<String, dynamic> data, {
    required String scope,
  }) {
    final fallback = _spaceSnapshots[scope] ??
        _spaceSnapshots[_selfSpaceHouseId] ??
        _captureCurrentSnapshot();
    final rawAnchorDate =
        (data['anchorDate'] ?? data['anchor_date'] ?? '').toString().trim();
    final parsedAnchorDate =
        rawAnchorDate.isEmpty ? null : DateInputUtils.parse(rawAnchorDate);

    return _CountdownSpaceSnapshot(
      singleMode:
          _readSerializedBool(data['singleMode'] ?? data['single_mode']) ??
              fallback.singleMode,
      anchorDate: parsedAnchorDate ?? fallback.anchorDate,
      themeKey: (data['themeKey'] ?? data['theme_key'] ?? fallback.themeKey)
          .toString()
          .trim(),
      styleKey: _sanitizeCountdownSpaceStyle(
        (data['styleKey'] ?? data['style_key'] ?? fallback.styleKey)
            .toString()
            .trim(),
      ),
      frameKey: (data['frameKey'] ?? data['frame_key'] ?? fallback.frameKey)
          .toString()
          .trim(),
      fontKey: (data['fontKey'] ?? data['font_key'] ?? fallback.fontKey)
          .toString()
          .trim(),
      transparentMode: _readSerializedBool(
            data['transparentMode'] ?? data['transparent_mode'],
          ) ??
          fallback.transparentMode,
      sizePx: (_readSerializedDouble(data['sizePx'] ?? data['size_px']) ??
              fallback.sizePx)
          .clamp(200.0, UiPrefs.maxCountdownSizePx)
          .toDouble(),
      topLabel: (data['topLabel'] ?? data['top_label'] ?? fallback.topLabel)
          .toString(),
      bottomLabel:
          (data['bottomLabel'] ?? data['bottom_label'] ?? fallback.bottomLabel)
              .toString(),
      nameU1: (data['nameU1'] ?? data['name_u1'] ?? fallback.nameU1).toString(),
      nameU2: (data['nameU2'] ?? data['name_u2'] ?? fallback.nameU2).toString(),
      avatarUrl1:
          (data['avatarUrl1'] ?? data['avatar_1'] ?? fallback.avatarUrl1)
              .toString(),
      avatarUrl2:
          (data['avatarUrl2'] ?? data['avatar_2'] ?? fallback.avatarUrl2)
              .toString(),
      customBackgroundUrl: (data['customBackgroundUrl'] ??
              data['custom_background_url'] ??
              data['bg_url'] ??
              fallback.customBackgroundUrl)
          .toString(),
      centerIconType: (data['centerIconType'] ??
              data['center_icon_type'] ??
              fallback.centerIconType)
          .toString(),
    );
  }

  bool? _readSerializedBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final raw = value?.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1') {
      return true;
    }
    if (raw == 'false' || raw == '0') {
      return false;
    }
    return null;
  }

  double? _readSerializedDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().trim() ?? '');
  }

  _CountdownSpaceSnapshot _captureCurrentSnapshot() {
    return _CountdownSpaceSnapshot(
      singleMode: _singleMode,
      anchorDate: _anchorDate,
      themeKey: _themeKey,
      styleKey: _sanitizeCountdownSpaceStyle(_countdownStyleKey),
      frameKey: _avatarFrameKey,
      fontKey: _fontKey,
      transparentMode: _transparentMode,
      sizePx: _countdownSizePx,
      topLabel: _topLabelText,
      bottomLabel: _bottomLabelText,
      nameU1: _nameU1,
      nameU2: _nameU2,
      avatarUrl1: _avatarUrl1,
      avatarUrl2: _avatarUrl2,
      customBackgroundUrl: _customBackgroundUrl,
      centerIconType: _centerIconType,
    );
  }

  void _applySnapshot(_CountdownSpaceSnapshot snapshot) {
    _singleMode = snapshot.singleMode;
    _anchorDate = snapshot.anchorDate;
    _themeKey = snapshot.themeKey;
    _countdownStyleKey = _sanitizeCountdownSpaceStyle(snapshot.styleKey);
    _avatarFrameKey = snapshot.frameKey;
    _fontKey = snapshot.fontKey;
    _transparentMode = snapshot.transparentMode;
    _countdownSizePx = snapshot.sizePx;
    _topLabelText = snapshot.topLabel;
    _bottomLabelText = snapshot.bottomLabel;
    _nameU1 = snapshot.nameU1;
    _nameU2 = snapshot.nameU2;
    _avatarUrl1 = snapshot.avatarUrl1;
    _avatarUrl2 = snapshot.avatarUrl2;
    _customBackgroundUrl = snapshot.customBackgroundUrl;
    _centerIconType = snapshot.centerIconType;
  }

  _CountdownSpaceSnapshot _snapshotFromPrefs(
    SharedPreferences prefs, {
    required String scope,
  }) {
    final ui = UiPrefs.notifier.value;
    final defaultSingleMode = widget.relationshipMode.trim() == 'single';
    final defaultTopLabel = defaultSingleMode
        ? (ui.countdownTopLabel.trim().isNotEmpty
            ? ui.countdownTopLabel.trim()
            : 'TUỔI CỦA TÔI')
        : (widget.fallbackTopLabel.trim().isNotEmpty
            ? widget.fallbackTopLabel.trim()
            : 'Yêu nhau');
    final defaultBottomLabel = defaultSingleMode
        ? (ui.countdownBottomLabel.trim().isNotEmpty
            ? ui.countdownBottomLabel.trim()
            : 'NGÀY TUỔI')
        : (widget.fallbackBottomLabel.trim().isNotEmpty
            ? widget.fallbackBottomLabel.trim()
            : 'ngày');
    final defaultNameU1 =
        widget.nameU1.trim().isEmpty ? 'Bạn' : widget.nameU1.trim();
    final defaultNameU2 =
        widget.nameU2.trim().isEmpty ? 'Người ấy' : widget.nameU2.trim();
    final defaultThemeKey =
        ui.themeKey.trim().isEmpty ? 'theme-auto' : ui.themeKey.trim();
    final defaultStyleKey = ui.countdownStyleKey.trim().isEmpty
        ? 'default'
        : ui.countdownStyleKey.trim();
    final defaultFrameKey =
        ui.avatarFrameKey.trim().isEmpty ? 'circle' : ui.avatarFrameKey.trim();
    final rawDate =
        prefs.getString(_prefKey('anchor_date', scope: scope)) ?? '';
    final parsedDate = DateInputUtils.parse(rawDate) ??
        _resolveInitialAnchorDate(defaultSingleMode);

    return _CountdownSpaceSnapshot(
      singleMode: prefs.getBool(_prefKey('single_mode', scope: scope)) ??
          defaultSingleMode,
      anchorDate: parsedDate,
      themeKey: prefs.getString(_prefKey('theme_key', scope: scope)) ??
          defaultThemeKey,
      styleKey: _sanitizeCountdownSpaceStyle(
        prefs.getString(_prefKey('style_key', scope: scope)) ?? defaultStyleKey,
      ),
      frameKey: prefs.getString(_prefKey('avatar_frame_key', scope: scope)) ??
          defaultFrameKey,
      fontKey: prefs.getString(_prefKey('font_key', scope: scope)) ??
          SLTheme.normalizeFontKey(ui.fontKey),
      transparentMode: prefs.getBool(
            _prefKey('transparent_mode', scope: scope),
          ) ??
          ui.transparentMode,
      sizePx: (prefs.getDouble(_prefKey('size_px', scope: scope)) ??
              UiPrefs.maxCountdownSizePx)
          .clamp(200.0, UiPrefs.maxCountdownSizePx)
          .toDouble(),
      topLabel: prefs.getString(_prefKey('top_label', scope: scope)) ??
          defaultTopLabel,
      bottomLabel: prefs.getString(_prefKey('bottom_label', scope: scope)) ??
          defaultBottomLabel,
      nameU1:
          prefs.getString(_prefKey('name_u1', scope: scope)) ?? defaultNameU1,
      nameU2:
          prefs.getString(_prefKey('name_u2', scope: scope)) ?? defaultNameU2,
      avatarUrl1: prefs.getString(_prefKey('avatar_1', scope: scope)) ??
          widget.avatarUrl1.trim(),
      avatarUrl2: prefs.getString(_prefKey('avatar_2', scope: scope)) ??
          widget.avatarUrl2.trim(),
      customBackgroundUrl: prefs.getString(_prefKey('bg_url', scope: scope)) ??
          ui.customBackgroundUrl.trim(),
      centerIconType:
          prefs.getString(_prefKey('center_icon_type', scope: scope)) ??
              'heart',
    );
  }

  _CountdownSpaceSnapshot _spaceSnapshotFor(String scope) {
    return _spaceSnapshots[scope] ?? _captureCurrentSnapshot();
  }

  void _seedDefaults() {
    final ui = UiPrefs.notifier.value;
    _singleMode = widget.relationshipMode.trim() == 'single';
    _anchorDate = _resolveInitialAnchorDate(_singleMode);
    _topLabelText = _singleMode
        ? (ui.countdownTopLabel.trim().isNotEmpty
            ? ui.countdownTopLabel.trim()
            : 'TUỔI CỦA TÔI')
        : (widget.fallbackTopLabel.trim().isNotEmpty
            ? widget.fallbackTopLabel.trim()
            : 'Yêu nhau');
    _bottomLabelText = _singleMode
        ? (ui.countdownBottomLabel.trim().isNotEmpty
            ? ui.countdownBottomLabel.trim()
            : 'NGÀY TUỔI')
        : (widget.fallbackBottomLabel.trim().isNotEmpty
            ? widget.fallbackBottomLabel.trim()
            : 'ngày');
    _nameU1 = widget.nameU1.trim().isEmpty ? 'Bạn' : widget.nameU1.trim();
    _nameU2 = widget.nameU2.trim().isEmpty ? 'Người ấy' : widget.nameU2.trim();
    _avatarUrl1 = widget.avatarUrl1.trim();
    _avatarUrl2 = widget.avatarUrl2.trim();
    _themeKey = ui.themeKey.trim().isEmpty ? 'theme-auto' : ui.themeKey.trim();
    _countdownStyleKey = ui.countdownStyleKey.trim().isEmpty
        ? 'default'
        : ui.countdownStyleKey.trim();
    _centerIconType = 'heart';
    _fontKey = SLTheme.normalizeFontKey(ui.fontKey);
    _avatarFrameKey =
        ui.avatarFrameKey.trim().isEmpty ? 'circle' : ui.avatarFrameKey.trim();
    _transparentMode = ui.transparentMode;
    _countdownSizePx = UiPrefs.maxCountdownSizePx;
    _customBackgroundUrl = ui.customBackgroundUrl.trim();
    _spaceSnapshots[_selfSpaceHouseId] = _captureCurrentSnapshot();
  }
}
