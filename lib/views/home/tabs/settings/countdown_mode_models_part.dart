part of '../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

enum _CountdownModeMenuAction { appearance, exit }

enum _CountdownModeSettingsAction {
  save,
  requestDeleteSpace,
  acceptDeleteSpace,
  backToSpaces,
  exit,
}

class _CountdownModeSettingsResult {
  const _CountdownModeSettingsResult({
    required this.action,
    required this.singleMode,
    required this.anchorDate,
    required this.themeKey,
    required this.styleKey,
    required this.frameKey,
    required this.fontKey,
    required this.transparentMode,
    required this.sizePx,
    required this.topLabel,
    required this.bottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avatarUrl1,
    required this.avatarUrl2,
    required this.customBackgroundUrl,
    required this.centerIconType,
  });

  final _CountdownModeSettingsAction action;
  final bool singleMode;
  final DateTime? anchorDate;
  final String themeKey;
  final String styleKey;
  final String frameKey;
  final String fontKey;
  final bool transparentMode;
  final double sizePx;
  final String topLabel;
  final String bottomLabel;
  final String nameU1;
  final String nameU2;
  final String avatarUrl1;
  final String avatarUrl2;
  final String customBackgroundUrl;
  final String centerIconType;
}

class _CountdownSpaceSnapshot {
  const _CountdownSpaceSnapshot({
    required this.singleMode,
    required this.anchorDate,
    required this.themeKey,
    required this.styleKey,
    required this.frameKey,
    required this.fontKey,
    required this.transparentMode,
    required this.sizePx,
    required this.topLabel,
    required this.bottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avatarUrl1,
    required this.avatarUrl2,
    required this.customBackgroundUrl,
    required this.centerIconType,
    required this.updatedAtMs,
  });

  final bool singleMode;
  final DateTime? anchorDate;
  final String themeKey;
  final String styleKey;
  final String frameKey;
  final String fontKey;
  final bool transparentMode;
  final double sizePx;
  final String topLabel;
  final String bottomLabel;
  final String nameU1;
  final String nameU2;
  final String avatarUrl1;
  final String avatarUrl2;
  final String customBackgroundUrl;
  final String centerIconType;
  final int updatedAtMs;
}

class _CountdownSpaceAddResult {
  const _CountdownSpaceAddResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

extension _SettingsTabCountdownModeScreen on _SettingsTabState {
  Future<void> _openCountdownMode() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CountdownModeIndependentScreen(
          currentHouseId: _houseId,
          isVipActive: _isVipActive,
          loveDate: _loveDate,
          birthDate: _dobU1,
          relationshipMode: _relationshipMode,
          fallbackTopLabel: _autoReplyCtrl.text.trim(),
          fallbackBottomLabel: _loveUnitCtrl.text.trim(),
          nameU1: _nameU1.trim(),
          nameU2: _nameU2.trim(),
          avatarUrl1: _avatarUrl1.trim(),
          avatarUrl2: _avatarUrl2.trim(),
        ),
      ),
    );
  }
}
