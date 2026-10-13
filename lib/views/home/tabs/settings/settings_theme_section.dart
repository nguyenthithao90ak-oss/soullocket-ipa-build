// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../settings_tab.dart';

const CropAspectRatio _themeBackgroundAspectRatio = CropAspectRatio(
  ratioX: 9,
  ratioY: 16,
);
const CropAspectRatioPresetData _themeBackgroundAspectRatioPreset =
    _ThemeBackgroundAspectRatioPreset();

class _ThemeBackgroundAspectRatioPreset implements CropAspectRatioPresetData {
  const _ThemeBackgroundAspectRatioPreset();

  @override
  String get name => 'house_background_9x16';

  @override
  (int ratioX, int ratioY)? get data => (9, 16);
}

class _ThemePreviewCountdownVisual {
  final BoxDecoration outerDecoration;
  final BoxDecoration innerDecoration;
  final List<Color> numberGradient;
  final Color topLabelColor;
  final Color bottomLabelColor;
  final List<Shadow> labelShadows;
  final List<Shadow> numberShadows;
  final String backdropType;

  const _ThemePreviewCountdownVisual({
    required this.outerDecoration,
    required this.innerDecoration,
    required this.numberGradient,
    required this.topLabelColor,
    required this.bottomLabelColor,
    required this.labelShadows,
    required this.numberShadows,
    required this.backdropType,
  });
}

// Shell-ready extraction targets live outside the locked part graph:
// - controllers/settings_theme_controller.dart
// - theme/theme_panel.dart
// - theme/theme_preview_builder.dart
// - theme/theme_background_actions.dart
// - theme/anniversary_panel.dart
// - theme/music_panel.dart
class _ThemePanelConfig {
  final List<(String, String)> themes;
  final List<(String, String)> effects;
  final List<(String, String)> avatarFrames;
  final List<(String, String, bool)> countdownStyles;
  final List<SLFontOption> fonts;
  final List<(String, String)> languages;
  final List<(String, String)> homeTones;
  final List<(String, String)> graphicsOptions;
  final List<(String, String)> widgetThemes;

  const _ThemePanelConfig({
    required this.themes,
    required this.effects,
    required this.avatarFrames,
    required this.countdownStyles,
    required this.fonts,
    required this.languages,
    required this.homeTones,
    required this.graphicsOptions,
    required this.widgetThemes,
  });
}

class _ThemePanelSelection {
  final String themeKey;
  final String effectKey;
  final String avatarFrameKey;
  final String countdownStyleKey;
  final bool hasCountdownAdPass;
  final String fontKey;
  final String languageKey;
  final String homeToneKey;
  final String graphicsKey;
  final String widgetThemeKey;
  final double countdownSize;
  final String previewBackground;

  const _ThemePanelSelection({
    required this.themeKey,
    required this.effectKey,
    required this.avatarFrameKey,
    required this.countdownStyleKey,
    required this.hasCountdownAdPass,
    required this.fontKey,
    required this.languageKey,
    required this.homeToneKey,
    required this.graphicsKey,
    required this.widgetThemeKey,
    required this.countdownSize,
    required this.previewBackground,
  });
}

extension _SettingsTabThemeSection on _SettingsTabState {
  String _resolveAllowedAvatarFrameKey(String frameKey) {
    final normalized = frameKey.trim().isEmpty ? 'off' : frameKey.trim();
    if (!_isVipActive && normalized == 'vip') {
      return 'glass';
    }
    return normalized;
  }

  bool _isVipFrameLocked(String frameKey) {
    return frameKey == 'vip' && !_isVipActive;
  }

  void _handleAvatarFrameSelection(String frameKey) {
    if (_isVipFrameLocked(frameKey)) {
      _showToast(context.tr('home_lachnnyang_d9f089'), success: false);
      return;
    }
    _updateThemeDraft(
      () => _draftAvatarFrameKey = _resolveAllowedAvatarFrameKey(frameKey),
    );
  }

  _ThemePanelConfig _buildThemePanelConfig() {
    return _ThemePanelConfig(
      themes: [
        (context.tr('theme_auto_season'), 'theme-auto'),
        (context.tr('home_snghngmcnh_17c1e3'), 'theme-pink-glow'),
        (context.tr('home_ngin_bcef46'), 'theme-default'),
        (context.tr('theme_sunset'), 'theme-sunset'),
        (context.tr('theme_ocean'), 'theme-ocean'),
        (context.tr('theme_night'), 'theme-night'),
        (context.tr('theme_dark'), 'theme-dark'),
        (context.tr('theme_mystic_dark'), 'theme-mystic-dark'),
        (context.tr('home_ttch_324e9a'), 'off'),
      ],
      effects: [
        (context.tr('effect_auto_season'), 'auto'),
        (context.tr('effect_sparkles'), 'sparkles'),
        (context.tr('effect_stars'), 'stars'),
        (context.tr('effect_hearts'), 'hearts'),
        (context.tr('effect_meteors'), 'meteors'),
        (context.tr('effect_bubbles'), 'bubbles'),
        (context.tr('effect_snow'), 'snow'),
        (context.tr('effect_leaves'), 'leaves'),
        (context.tr('effect_off'), 'off'),
      ],
      avatarFrames: [
        (context.tr('home_ttkhngckhu_37eb33'), 'off'),
        for (final key in KeepsakePalette.newStyleKeys)
          (context.tr('keepsake_$key'), key),
        (context.tr('frame_circle'), 'circle'),
        (context.tr('frame_rounded'), 'rounded'),
        (context.tr('p7_frame_squircle'), 'squircle'),
        (context.tr('frame_pearl'), 'pearl'),
        (context.tr('frame_glass'), 'glass'),
        if (AppConfig.isPurchaseEnabled)
          (
            _isVipActive
                ? context.tr('frame_vip')
                : '${context.tr('frame_vip')} 🔒',
            'vip',
          ),
      ],
      countdownStyles: [
        (context.tr('countdown_love_letter'), 'default', false),
        for (final key in KeepsakePalette.newStyleKeys)
          (context.tr('countdown_$key'), key, false),
        (context.tr('countdown_floating_hearts'), 'floating_hearts', true),
        (context.tr('countdown_glass'), 'glass', false),
        (context.tr('countdown_glow'), 'glow', false),
        (context.tr('countdown_candy'), 'candy', false),
        (context.tr('countdown_galaxy'), 'galaxy', true),
        (context.tr('countdown_aurora'), 'aurora', true),
        (context.tr('countdown_crystal'), 'crystal', true),
        (context.tr('countdown_fireworks'), 'fireworks', true),
        (context.tr('countdown_lava'), 'lava', true),
      ],
      fonts: SLTheme.cleanFontOptions,
      languages: [
        for (final option in _settingsLanguageOptions)
          (option.title, option.code),
      ],
      homeTones: [
        (context.tr('tone_theme'), 'theme'),
        (context.tr('tone_mist'), 'mist'),
        (context.tr('tone_rose'), 'rose'),
        (context.tr('tone_glass'), 'glass'),
      ],
      graphicsOptions: [
        (context.tr('graphics_low'), 'low'),
        (context.tr('countdown_default'), 'balanced'),
        (context.tr('graphics_high'), 'high'),
      ],
      widgetThemes: [
        (context.tr('widget_pink'), 'pink'),
        (context.tr('theme_dark'), 'dark'),
        (context.tr('widget_white'), 'white'),
        (context.tr('widget_blue'), 'blue'),
        (context.tr('widget_orange'), 'orange'),
        (context.tr('widget_purple'), 'purple'),
        (context.tr('theme_ocean'), 'green'),
        (context.tr('widget_red'), 'red'),
        if (AppConfig.isPurchaseEnabled)
          (
            _isVipActive
                ? context.tr('p7_aurora_pro')
                : context.tr('p7_aurora_pro_locked'),
            'premium',
          ),
      ],
    );
  }

  _ThemePanelSelection _resolveThemePanelSelection(
    UiPrefsState ui,
    _ThemePanelConfig config,
  ) {
    final themeKey =
        config.themes.any((item) => item.$2 == (_draftThemeKey ?? ui.themeKey))
        ? (_draftThemeKey ?? ui.themeKey)
        : config.themes.first.$2;
    final effectKey =
        config.effects.any(
          (item) => item.$2 == (_draftEffectKey ?? ui.fallingEffectKey),
        )
        ? (_draftEffectKey ?? ui.fallingEffectKey)
        : config.effects.first.$2;
    final currentFrameKey = _draftAvatarFrameKey ?? ui.avatarFrameKey;
    final rawAvatarFrameKey =
        (config.avatarFrames.any((item) => item.$2 == currentFrameKey) ||
            currentFrameKey.startsWith('sticker_'))
        ? currentFrameKey
        : config.avatarFrames.first.$2;
    final countdownStyleKey =
        config.countdownStyles.any(
          (item) =>
              item.$2 == (_draftCountdownStyleKey ?? ui.countdownStyleKey),
        )
        ? (_draftCountdownStyleKey ?? ui.countdownStyleKey)
        : config.countdownStyles.first.$2;
    final fontKey =
        config.fonts.any((item) => item.key == (_draftFontKey ?? ui.fontKey))
        ? (_draftFontKey ?? ui.fontKey)
        : config.fonts.first.key;
    final languageKey =
        config.languages.any((item) => item.$2 == L10nService().localeCode)
        ? L10nService().localeCode
        : config.languages.first.$2;
    final homeToneKey =
        config.homeTones.any(
          (item) => item.$2 == (_draftHomeBlockToneKey ?? ui.homeBlockToneKey),
        )
        ? (_draftHomeBlockToneKey ?? ui.homeBlockToneKey)
        : config.homeTones.first.$2;
    final graphicsKey =
        config.graphicsOptions.any(
          (item) =>
              item.$2 == (_draftGraphicsQualityKey ?? ui.graphicsQualityKey),
        )
        ? (_draftGraphicsQualityKey ?? ui.graphicsQualityKey)
        : UiPrefs.getAutoGraphicsQuality();
    final widgetThemeKey =
        config.widgetThemes.any(
          (item) => item.$2 == (_draftWidgetThemeKey ?? 'pink'),
        )
        ? (_draftWidgetThemeKey ?? 'pink')
        : config.widgetThemes.first.$2;

    return _ThemePanelSelection(
      themeKey: themeKey,
      effectKey: effectKey,
      avatarFrameKey: _resolveAllowedAvatarFrameKey(rawAvatarFrameKey),
      countdownStyleKey: countdownStyleKey,
      hasCountdownAdPass: _hasActiveCountdownAdUnlock(),
      fontKey: fontKey,
      languageKey: languageKey,
      homeToneKey: homeToneKey,
      graphicsKey: graphicsKey,
      widgetThemeKey: widgetThemeKey,
      countdownSize: (_draftCountdownSizePx ?? ui.countdownSizePx)
          .clamp(200.0, UiPrefs.maxCountdownSizePx)
          .toDouble(),
      previewBackground: (_draftCustomBackgroundUrl ?? ui.customBackgroundUrl)
          .trim(),
    );
  }

  Widget _buildThemeHeader(BuildContext context, {bool showBack = true}) {
    return AppearancePanelHeader(
      onBack: showBack ? () => Navigator.pop(context) : null,
    );
  }

  Widget _buildThemePanel({bool hideBackButton = false}) {
    final config = _buildThemePanelConfig();
    final themes = config.themes;
    final effects = config.effects;
    final avatarFrames = config.avatarFrames;
    final countdownStyles = config.countdownStyles;
    final fonts = config.fonts;
    final languages = config.languages;
    final homeTones = config.homeTones;
    final graphicsOptions = config.graphicsOptions;
    final widgetThemes = config.widgetThemes;

    final ui = UiPrefs.notifier.value;
    final selection = _resolveThemePanelSelection(ui, config);
    _localCountdownSize = selection.countdownSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideBackButton)
          _buildThemeHeader(context, showBack: !hideBackButton),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview sống động: phản ánh ngay theme, hiệu ứng, khung và font
              // hiện tại trước khi người dùng mở từng nhóm điều chỉnh.
              _buildThemeHomeLikePreviewCard(
                selection.previewBackground,
                themeKey: selection.themeKey,
                effectKey: selection.effectKey,
                graphicsKey: selection.graphicsKey,
              ),
              // 1. Hình nền & Hiệu ứng
              AppearanceSectionCard(
                icon: Icons.palette_rounded,
                accentColor: SLSettingsColors.rose,
                artKind: AppearanceArtKind.palette,
                title: context.tr('theme_bg_effect_title'),
                description: context.tr('theme_bg_effect_desc'),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(context.tr('p7_home_background_color')),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SLSettingsNotice(
                        tone: SLSettingsTone.info,
                        icon: Icons.image_outlined,
                        message: context.tr('p7_default_image_background_note'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel(context.tr('theme_falling_effect')),
                    AppearanceEffectGrid(
                      value: selection.effectKey,
                      options: config.effects,
                      onChanged: (value) =>
                          _updateThemeDraft(() => _draftEffectKey = value),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<UiPrefsState>(
                      key: const ValueKey('ui-action-sound-toggle'),
                      valueListenable: UiPrefs.notifier,
                      builder: (context, prefs, _) => AppearanceToggleRow(
                        icon: Icons.music_note_rounded,
                        accentColor: SLSettingsColors.rose,
                        label: context.tr('touch_sound'),
                        subtitle: context.tr('ui_action_sound_subtitle'),
                        value: prefs.touchSound,
                        onChanged: (enabled) async {
                          try {
                            await UiPrefs.setTouchSound(enabled);
                            if (!mounted) return;
                            _touchSound = UiPrefs.notifier.value.touchSound;
                          } catch (_) {
                            if (!mounted) return;
                            _showToast(
                              this.context.tr('legacy_save_failed'),
                              success: false,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<UiPrefsState>(
                      key: const ValueKey('home-companion-toggle'),
                      valueListenable: UiPrefs.notifier,
                      builder: (context, prefs, _) => AppearanceToggleRow(
                        icon: Icons.pets_rounded,
                        accentColor: SLSettingsColors.rose,
                        label: context.tr('home_companion_setting_title'),
                        subtitle: context.tr('home_companion_setting_subtitle'),
                        value: prefs.homeCompanionEnabled,
                        onChanged: (enabled) async {
                          try {
                            await UiPrefs.setHomeCompanionEnabled(enabled);
                          } catch (_) {
                            if (!mounted) return;
                            _showToast(
                              this.context.tr('legacy_save_failed'),
                              success: false,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<UiPrefsState>(
                      key: const ValueKey('home-companion-sound-toggle'),
                      valueListenable: UiPrefs.notifier,
                      builder: (context, prefs, _) => AppearanceToggleRow(
                        icon: Icons.volume_down_rounded,
                        accentColor: SLSettingsColors.rose,
                        label: context.tr('home_companion_sound_title'),
                        subtitle: context.tr('home_companion_sound_subtitle'),
                        value: prefs.homeCompanionSoundEnabled,
                        onChanged: (enabled) async {
                          try {
                            await UiPrefs.setHomeCompanionSoundEnabled(enabled);
                          } catch (_) {
                            if (!mounted) return;
                            _showToast(
                              this.context.tr('legacy_save_failed'),
                              success: false,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradientBtn(
                            label: _isUploadingThemeBackground
                                ? (_themeUploadProgress != null
                                      ? context
                                            .tr('theme_uploading_pct')
                                            .replaceAll(
                                              '{pct}',
                                              (_themeUploadProgress! * 100)
                                                  .toInt()
                                                  .toString(),
                                            )
                                      : context.tr('theme_uploading_img'))
                                : context.tr('theme_upload_web_bg'),
                            gradient: const [],
                            icon: Icons.upload_rounded,
                            loading: _isUploadingThemeBackground,
                            onTap: _isUploadingThemeBackground
                                ? () {}
                                : _pickThemeBackgroundImage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGradientBtn(
                            label: context.tr('theme_remove_bg'),
                            gradient: const [],
                            icon: Icons.hide_image_outlined,
                            variant: SLSettingsButtonVariant.danger,
                            onTap: _clearThemeBackgroundImage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 2. Khung & Kích thước
              AppearanceSectionCard(
                icon: Icons.aspect_ratio_rounded,
                accentColor: SLSettingsColors.sky,
                artKind: AppearanceArtKind.frames,
                title: context.tr('appearance_frame_title'),
                description: context.tr('theme_frame_size_desc'),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SliderWithLabel(
                      initialValue:
                          _localCountdownSize ??
                          UiPrefs.notifier.value.countdownSizePx,
                      min: 200,
                      max: UiPrefs.maxCountdownSizePx,
                      onChanged: (value) {
                        _draftCountdownSizePx = value;
                      },
                      onChangeEnd: (value) {
                        _updateThemeDraft(
                          () => _draftCountdownSizePx = value,
                          syncPreview: true,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildLabel(context.tr('theme_frame_type')),
                    const SizedBox(height: 8),
                    _buildAvatarFrameStrip(selection.avatarFrameKey),
                    const SizedBox(height: 12),
                    _buildLabel(context.tr('theme_countdown_style')),
                    const SizedBox(height: 10),
                    _buildCountdownStyleStrip(
                      selection.countdownStyleKey,
                      selection.hasCountdownAdPass,
                    ),
                    const SizedBox(height: 12),
                    _buildLabel(context.tr('theme_home_block_tone')),
                    const SizedBox(height: 8),
                    _buildThemeDropdownField(
                      value: selection.homeToneKey,
                      options: config.homeTones,
                      onChanged: (value) => _updateThemeDraft(
                        () => _draftHomeBlockToneKey = value,
                      ),
                    ),
                  ],
                ),
              ),
              // 3. Font chữ & Ngôn ngữ
              AppearanceSectionCard(
                icon: Icons.font_download_rounded,
                accentColor: SLSettingsColors.violet,
                artKind: AppearanceArtKind.typography,
                title: context.tr('appearance_font_title'),
                description: context.tr('theme_font_lang_desc'),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(context.tr('lang_label')),
                    _buildThemeDropdownField(
                      value: selection.languageKey,
                      options: config.languages,
                      onChanged: (value) {
                        // Tránh khựng UI: Đợi menu dropdown đóng mượt mà xong (300ms) rồi mới load tệp JSON ngôn ngữ nặng
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          () async {
                            await L10nService().setLocale(value);
                            if (!mounted) return;
                            setState(() {});
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildLabel(context.tr('font_label')),
                    _buildThemeFontDropdownField(
                      value: selection.fontKey,
                      fonts: config.fonts,
                      onChanged: (value) =>
                          _updateThemeDraft(() => _draftFontKey = value),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SLSettingsColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          SLSettingsRadius.control,
                        ),
                        border: Border.all(color: SLSettingsColors.border),
                      ),
                      child: Text(
                        context.tr('theme_font_desc'),
                        style: _themeFontStyle(
                          selection.fontKey,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SLSettingsColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 4. Thêm kỷ niệm
              AppearanceSectionCard(
                icon: Icons.calendar_month_rounded,
                accentColor: SLSettingsColors.amber,
                artKind: AppearanceArtKind.calendar,
                title: context.tr('theme_add_new_memory'),
                description: context.tr('theme_memory_desc'),

                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInput(
                            _anniversaryNameCtrl,
                            '${context.tr('home_tnknim_c9204b')} — ${context.tr('home_vdngyyunha_5849f3')}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _anniversaryDateCtrl,
                                  keyboardType: TextInputType.datetime,
                                  inputFormatters: const [
                                    FlexibleDateInputFormatter(),
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onChanged: (value) {
                                    _draftAnniversaryDate =
                                        DateInputUtils.parse(
                                          value,
                                          firstYear: 2020,
                                          lastYear: 2100,
                                        );
                                    if (_anniversaryDateErrorText != null) {
                                      setState(() {
                                        _anniversaryDateErrorText = null;
                                      });
                                    }
                                  },
                                  onEditingComplete: () {
                                    final validationError =
                                        DateInputUtils.validationError(
                                          _anniversaryDateCtrl.text,
                                          firstYear: 2020,
                                          lastYear: 2100,
                                        );
                                    if (validationError != null) {
                                      setState(() {
                                        _anniversaryDateErrorText =
                                            validationError;
                                      });
                                      return;
                                    }
                                    final parsed = DateInputUtils.parse(
                                      _anniversaryDateCtrl.text,
                                      firstYear: 2020,
                                      lastYear: 2100,
                                    );
                                    if (parsed == null) return;
                                    _draftAnniversaryDate = parsed;
                                    _anniversaryDateErrorText = null;
                                    _anniversaryDateCtrl.text =
                                        DateInputUtils.formatDisplayDate(
                                          parsed,
                                        );
                                    _anniversaryDateCtrl
                                        .selection = TextSelection.collapsed(
                                      offset: _anniversaryDateCtrl.text.length,
                                    );
                                  },
                                  decoration: slSettingsInputDecoration(
                                    hint: DateInputUtils.formatHint(),
                                    errorText: _anniversaryDateErrorText,
                                    prefixIcon: const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(
                                        Icons.event_rounded,
                                        size: 20,
                                      ),
                                      color: SLSettingsColors.accentStrong,
                                      onPressed: _pickAnniversaryDate,
                                    ),
                                  ),
                                  style: slSettingsInputTextStyle(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SLSettingsButton(
                                label: context.tr('home_thm_d9cb42'),
                                icon: Icons.add_rounded,
                                expand: false,
                                onPressed: _addCustomAnniversary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildThemeEventPreview(),
                  ],
                ),
              ),
              // 5. Hiệu năng & Quyền hạn — ít dùng nhất, để cuối
              AppearanceSectionCard(
                icon: Icons.settings_suggest_rounded,
                accentColor: SLSettingsColors.sage,
                artKind: AppearanceArtKind.performance,
                title: context.tr('theme_perf_title'),
                description: context.tr('theme_perf_desc'),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trong suốt
                    _SettingsToggleRow(
                      icon: Icons.blur_on_rounded,
                      iconColor: SLSettingsColors.accent,
                      label: context.tr('home_trongsut_38b9d1'),
                      useCheckbox: true,
                      checkValue: _draftTransparentMode ?? ui.transparentMode,
                      onCheckChanged: (v) => _updateThemeDraft(
                        () => _draftTransparentMode = v ?? false,
                      ),
                    ),
                    // Chế độ đơn giản hóa
                    _SettingsToggleRow(
                      icon: Icons.bolt_rounded,
                      iconColor: SLSettingsColors.amber,
                      label: context.tr('theme_lite_mode_title'),
                      switchValue: _draftLiteMode,
                      onSwitchChanged: (v) =>
                          _updateThemeDraft(() => _draftLiteMode = v),
                    ),
                    const SizedBox(height: 14),
                    // Chất lượng đồ họa
                    Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 17,
                          color: SLSettingsColors.inkSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('theme_graphics_quality'),
                          style: SLSettingsText.body(SLSettingsColors.ink),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _updateThemeDraft(
                            () => _draftGraphicsQualityKey = 'auto',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_draftGraphicsQualityKey ??
                                          ui.graphicsQualityKey) ==
                                      'auto'
                                  ? SLSettingsColors.accentSoft
                                  : SLSettingsColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              context.tr('theme_graphics_auto'),
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color:
                                    (_draftGraphicsQualityKey ??
                                            ui.graphicsQualityKey) ==
                                        'auto'
                                    ? SLSettingsColors.accentStrong
                                    : SLSettingsColors.inkSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: graphicsOptions.map((item) {
                        final selected = selection.graphicsKey == item.$2;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _updateThemeDraft(
                              () => _draftGraphicsQualityKey = item.$2,
                            ),
                            child: Container(
                              margin: EdgeInsets.only(
                                right: item == graphicsOptions.last ? 0 : 8,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? SLSettingsColors.accent
                                    : SLSettingsColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  SLSettingsRadius.control - 2,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? SLSettingsColors.accent
                                      : SLSettingsColors.border,
                                ),
                              ),
                              child: Text(
                                item.$1,
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : SLSettingsColors.inkSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIPanel({bool hideBackButton = false}) {
    return const SizedBox.shrink();
  }
}

/// Slider with label — tách riêng StatefulWidget để tránh rebuild toàn panel khi kéo.
class _SliderWithLabel extends StatefulWidget {
  final double initialValue;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderWithLabel({
    required this.initialValue,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_SliderWithLabel> createState() => _SliderWithLabelState();
}

class _SliderWithLabelState extends State<_SliderWithLabel> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void didUpdateWidget(_SliderWithLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10nScope.of(context).format('ui_home_value1_value2_px_419aad', {
            'value1': context.tr('theme_countdown_size'),
            'value2': _value.round(),
          }),
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SLSettingsColors.inkSecondary,
          ),
        ),
        Slider(
          value: _value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          activeColor: SLSettingsColors.accent,
          inactiveColor: SLSettingsColors.accentSoft,
          onChanged: (value) {
            setState(() => _value = value);
            widget.onChanged(value);
          },
          onChangeEnd: widget.onChangeEnd,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => widget.onChangeEnd(_value),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              context.tr('theme_save_size'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
            style: TextButton.styleFrom(
              foregroundColor: SLSettingsColors.accentStrong,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
