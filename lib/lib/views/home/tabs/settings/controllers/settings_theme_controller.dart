import 'dart:async';

import 'package:flutter/foundation.dart';

typedef SettingsThemeSaveCallback = Future<void> Function(
  SettingsThemeDraft draft,
);

@immutable
class SettingsChoiceOption {
  final String label;
  final String value;
  final bool locked;
  final String? note;

  const SettingsChoiceOption({
    required this.label,
    required this.value,
    this.locked = false,
    this.note,
  });
}

@immutable
class SettingsThemeAnniversaryDraft {
  final String name;
  final DateTime? date;

  const SettingsThemeAnniversaryDraft({
    this.name = '',
    this.date,
  });

  static const Object _sentinel = Object();

  SettingsThemeAnniversaryDraft copyWith({
    String? name,
    Object? date = _sentinel,
  }) {
    return SettingsThemeAnniversaryDraft(
      name: name ?? this.name,
      date: identical(date, _sentinel) ? this.date : date as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SettingsThemeAnniversaryDraft &&
            other.name == name &&
            other.date == date;
  }

  @override
  int get hashCode => Object.hash(name, date);
}

@immutable
class SettingsThemeMusicDraft {
  final bool autoplay;
  final String link;
  final String title;
  final String type;

  const SettingsThemeMusicDraft({
    this.autoplay = true,
    this.link = '',
    this.title = '',
    this.type = 'audio',
  });

  SettingsThemeMusicDraft copyWith({
    bool? autoplay,
    String? link,
    String? title,
    String? type,
  }) {
    return SettingsThemeMusicDraft(
      autoplay: autoplay ?? this.autoplay,
      link: link ?? this.link,
      title: title ?? this.title,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SettingsThemeMusicDraft &&
            other.autoplay == autoplay &&
            other.link == link &&
            other.title == title &&
            other.type == type;
  }

  @override
  int get hashCode => Object.hash(autoplay, link, title, type);
}

@immutable
class SettingsThemeDraft {
  final String themeKey;
  final String effectKey;
  final double countdownSizePx;
  final String avatarFrameKey;
  final String countdownStyleKey;
  final String fontKey;
  final String homeBlockToneKey;
  final String graphicsQualityKey;
  final String widgetThemeKey;
  final String customBackgroundUrl;
  final bool transparentMode;
  final bool liteMode;
  final bool showDiaryOnWidget;
  final bool widgetHeartAnimated;
  final String widgetHeartStyleKey;
  final String widgetHeartColorKey;
  final String widgetPreviewSizeKey;
  final String widgetDiaryLayoutKey;
  final String widgetSeasonModeKey;
  final SettingsThemeAnniversaryDraft anniversaryDraft;
  final SettingsThemeMusicDraft musicDraft;

  const SettingsThemeDraft({
    this.themeKey = 'theme-pink-glow',
    this.effectKey = 'auto',
    this.countdownSizePx = 260,
    this.avatarFrameKey = 'circle',
    this.countdownStyleKey = 'default',
    this.fontKey = 'quicksand',
    this.homeBlockToneKey = 'theme',
    this.graphicsQualityKey = 'balanced',
    this.widgetThemeKey = 'pink',
    this.customBackgroundUrl = '',
    this.transparentMode = false,
    this.liteMode = false,
    this.showDiaryOnWidget = true,
    this.widgetHeartAnimated = true,
    this.widgetHeartStyleKey = '❤️',
    this.widgetHeartColorKey = 'rose',
    this.widgetPreviewSizeKey = 'medium',
    this.widgetDiaryLayoutKey = 'single',
    this.widgetSeasonModeKey = 'auto',
    this.anniversaryDraft = const SettingsThemeAnniversaryDraft(),
    this.musicDraft = const SettingsThemeMusicDraft(),
  });

  static const Object _sentinel = Object();

  SettingsThemeDraft copyWith({
    String? themeKey,
    String? effectKey,
    double? countdownSizePx,
    String? avatarFrameKey,
    String? countdownStyleKey,
    String? fontKey,
    String? homeBlockToneKey,
    String? graphicsQualityKey,
    String? widgetThemeKey,
    Object? customBackgroundUrl = _sentinel,
    bool? transparentMode,
    bool? liteMode,
    bool? showDiaryOnWidget,
    bool? widgetHeartAnimated,
    String? widgetHeartStyleKey,
    String? widgetHeartColorKey,
    String? widgetPreviewSizeKey,
    String? widgetDiaryLayoutKey,
    String? widgetSeasonModeKey,
    SettingsThemeAnniversaryDraft? anniversaryDraft,
    SettingsThemeMusicDraft? musicDraft,
  }) {
    return SettingsThemeDraft(
      themeKey: themeKey ?? this.themeKey,
      effectKey: effectKey ?? this.effectKey,
      countdownSizePx: countdownSizePx ?? this.countdownSizePx,
      avatarFrameKey: avatarFrameKey ?? this.avatarFrameKey,
      countdownStyleKey: countdownStyleKey ?? this.countdownStyleKey,
      fontKey: fontKey ?? this.fontKey,
      homeBlockToneKey: homeBlockToneKey ?? this.homeBlockToneKey,
      graphicsQualityKey: graphicsQualityKey ?? this.graphicsQualityKey,
      widgetThemeKey: widgetThemeKey ?? this.widgetThemeKey,
      customBackgroundUrl: identical(customBackgroundUrl, _sentinel)
          ? this.customBackgroundUrl
          : (customBackgroundUrl as String? ?? ''),
      transparentMode: transparentMode ?? this.transparentMode,
      liteMode: liteMode ?? this.liteMode,
      showDiaryOnWidget: showDiaryOnWidget ?? this.showDiaryOnWidget,
      widgetHeartAnimated: widgetHeartAnimated ?? this.widgetHeartAnimated,
      widgetHeartStyleKey: widgetHeartStyleKey ?? this.widgetHeartStyleKey,
      widgetHeartColorKey: widgetHeartColorKey ?? this.widgetHeartColorKey,
      widgetPreviewSizeKey: widgetPreviewSizeKey ?? this.widgetPreviewSizeKey,
      widgetDiaryLayoutKey: widgetDiaryLayoutKey ?? this.widgetDiaryLayoutKey,
      widgetSeasonModeKey: widgetSeasonModeKey ?? this.widgetSeasonModeKey,
      anniversaryDraft: anniversaryDraft ?? this.anniversaryDraft,
      musicDraft: musicDraft ?? this.musicDraft,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SettingsThemeDraft &&
            other.themeKey == themeKey &&
            other.effectKey == effectKey &&
            other.countdownSizePx == countdownSizePx &&
            other.avatarFrameKey == avatarFrameKey &&
            other.countdownStyleKey == countdownStyleKey &&
            other.fontKey == fontKey &&
            other.homeBlockToneKey == homeBlockToneKey &&
            other.graphicsQualityKey == graphicsQualityKey &&
            other.widgetThemeKey == widgetThemeKey &&
            other.customBackgroundUrl == customBackgroundUrl &&
            other.transparentMode == transparentMode &&
            other.liteMode == liteMode &&
            other.showDiaryOnWidget == showDiaryOnWidget &&
            other.widgetHeartAnimated == widgetHeartAnimated &&
            other.widgetHeartStyleKey == widgetHeartStyleKey &&
            other.widgetHeartColorKey == widgetHeartColorKey &&
            other.widgetPreviewSizeKey == widgetPreviewSizeKey &&
            other.widgetDiaryLayoutKey == widgetDiaryLayoutKey &&
            other.widgetSeasonModeKey == widgetSeasonModeKey &&
            other.anniversaryDraft == anniversaryDraft &&
            other.musicDraft == musicDraft;
  }

  @override
  int get hashCode => Object.hashAll([
        themeKey,
        effectKey,
        countdownSizePx,
        avatarFrameKey,
        countdownStyleKey,
        fontKey,
        homeBlockToneKey,
        graphicsQualityKey,
        widgetThemeKey,
        customBackgroundUrl,
        transparentMode,
        liteMode,
        showDiaryOnWidget,
        widgetHeartAnimated,
        widgetHeartStyleKey,
        widgetHeartColorKey,
        widgetPreviewSizeKey,
        widgetDiaryLayoutKey,
        widgetSeasonModeKey,
        anniversaryDraft,
        musicDraft,
      ]);
}

class SettingsThemeController extends ChangeNotifier {
  SettingsThemeController({
    required SettingsThemeDraft initialDraft,
    this.onAutosave,
    this.autosaveDelay = const Duration(milliseconds: 500),
  })  : _draft = initialDraft,
        _savedDraft = initialDraft;

  final SettingsThemeSaveCallback? onAutosave;
  final Duration autosaveDelay;

  SettingsThemeDraft _draft;
  SettingsThemeDraft _savedDraft;
  Timer? _autosaveTimer;
  bool _isSaving = false;
  bool _isUploadingBackground = false;

  SettingsThemeDraft get draft => _draft;
  bool get isSaving => _isSaving;
  bool get isUploadingBackground => _isUploadingBackground;
  bool get isDirty => _draft != _savedDraft;

  void replaceDraft(
    SettingsThemeDraft nextDraft, {
    bool markClean = false,
    bool notify = true,
  }) {
    _draft = nextDraft;
    if (markClean) {
      _savedDraft = nextDraft;
      _autosaveTimer?.cancel();
    }
    if (notify) {
      notifyListeners();
    }
  }

  void updateDraft(
    SettingsThemeDraft Function(SettingsThemeDraft current) updater, {
    bool autosave = true,
  }) {
    final nextDraft = updater(_draft);
    if (nextDraft == _draft) {
      return;
    }
    _draft = nextDraft;
    notifyListeners();
    if (autosave) {
      _scheduleAutosave();
    }
  }

  void markClean([SettingsThemeDraft? persistedDraft]) {
    _savedDraft = persistedDraft ?? _draft;
    _autosaveTimer?.cancel();
    notifyListeners();
  }

  void setSaving(bool value) {
    if (_isSaving == value) return;
    _isSaving = value;
    notifyListeners();
  }

  void setUploadingBackground(bool value) {
    if (_isUploadingBackground == value) return;
    _isUploadingBackground = value;
    notifyListeners();
  }

  void setThemeKey(String value) =>
      updateDraft((draft) => draft.copyWith(themeKey: value));

  void setEffectKey(String value) =>
      updateDraft((draft) => draft.copyWith(effectKey: value));

  void setCountdownSize(double value) => updateDraft(
        (draft) => draft.copyWith(countdownSizePx: value),
      );

  void setAvatarFrameKey(String value) =>
      updateDraft((draft) => draft.copyWith(avatarFrameKey: value));

  void setCountdownStyleKey(String value) =>
      updateDraft((draft) => draft.copyWith(countdownStyleKey: value));

  void setFontKey(String value) =>
      updateDraft((draft) => draft.copyWith(fontKey: value));

  void setHomeBlockToneKey(String value) =>
      updateDraft((draft) => draft.copyWith(homeBlockToneKey: value));

  void setGraphicsQualityKey(String value) =>
      updateDraft((draft) => draft.copyWith(graphicsQualityKey: value));

  void setWidgetThemeKey(String value) =>
      updateDraft((draft) => draft.copyWith(widgetThemeKey: value));

  void setCustomBackgroundUrl(String? value) => updateDraft(
        (draft) => draft.copyWith(customBackgroundUrl: value ?? ''),
      );

  void setTransparentMode(bool value) =>
      updateDraft((draft) => draft.copyWith(transparentMode: value));

  void setLiteMode(bool value) =>
      updateDraft((draft) => draft.copyWith(liteMode: value));

  void setShowDiaryOnWidget(bool value) =>
      updateDraft((draft) => draft.copyWith(showDiaryOnWidget: value));

  void setWidgetHeartAnimated(bool value) =>
      updateDraft((draft) => draft.copyWith(widgetHeartAnimated: value));

  void setWidgetHeartStyleKey(String value) =>
      updateDraft((draft) => draft.copyWith(widgetHeartStyleKey: value));

  void setWidgetHeartColorKey(String value) =>
      updateDraft((draft) => draft.copyWith(widgetHeartColorKey: value));

  void setWidgetPreviewSizeKey(String value) =>
      updateDraft((draft) => draft.copyWith(widgetPreviewSizeKey: value));

  void setWidgetDiaryLayoutKey(String value) =>
      updateDraft((draft) => draft.copyWith(widgetDiaryLayoutKey: value));

  void setWidgetSeasonModeKey(String value) =>
      updateDraft((draft) => draft.copyWith(widgetSeasonModeKey: value));

  void setAnniversaryName(String value) => updateDraft(
        (draft) => draft.copyWith(
          anniversaryDraft: draft.anniversaryDraft.copyWith(name: value),
        ),
      );

  void setAnniversaryDate(DateTime? value) => updateDraft(
        (draft) => draft.copyWith(
          anniversaryDraft: draft.anniversaryDraft.copyWith(date: value),
        ),
      );

  void setMusicAutoplay(bool value) => updateDraft(
        (draft) => draft.copyWith(
          musicDraft: draft.musicDraft.copyWith(autoplay: value),
        ),
      );

  void setMusicLink(String value) => updateDraft(
        (draft) => draft.copyWith(
          musicDraft: draft.musicDraft.copyWith(link: value),
        ),
        autosave: false,
      );

  void setMusicMeta({
    String? title,
    String? type,
    String? link,
  }) {
    updateDraft(
      (draft) => draft.copyWith(
        musicDraft: draft.musicDraft.copyWith(
          title: title,
          type: type,
          link: link,
        ),
      ),
      autosave: false,
    );
  }

  Future<void> saveNow() async {
    final saveCallback = onAutosave;
    if (saveCallback == null || _isSaving) {
      return;
    }
    _autosaveTimer?.cancel();
    _isSaving = true;
    notifyListeners();
    try {
      await saveCallback(_draft);
      _savedDraft = _draft;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _scheduleAutosave() {
    if (onAutosave == null) {
      return;
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, () {
      unawaited(saveNow());
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
