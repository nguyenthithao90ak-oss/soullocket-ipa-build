// ignore_for_file: unused_local_variable
part of '../settings_tab.dart';

const CropAspectRatio _themeBackgroundAspectRatio =
    CropAspectRatio(ratioX: 9, ratioY: 16);
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

  bool _isVipThemeLocked(String themeKey) {
    return themeKey == 'theme-vip-rotate' && !_isVipActive;
  }

  Future<void> _openPremiumStoreFromThemePanel() async {
    if (!AppConfig.isPurchaseEnabled) {
      _showToast(context.tr('home_mcnyangtmn_fdd99c'), success: false);
      return;
    }

    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      _showToast(context.tr('home_hyvonhtrck_c33334'), success: false);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumStoreScreen(
          houseId: houseId,
          myName: _nameU1.trim().isEmpty ? context.tr('home_bn_1fd75b') : _nameU1.trim(),
        ),
      ),
    );
    if (!mounted) return;
    await _loadVipStatus();
  }


  Future<void> _handleThemeSelection(String themeKey) async {
    final customBackgroundUrl = (_draftCustomBackgroundUrl ??
            UiPrefs.notifier.value.customBackgroundUrl)
        .trim();
    if (customBackgroundUrl.isNotEmpty && themeKey != 'off') {
      // Khi người dùng chọn theme mới, ưu tiên áp dụng theme đó ngay.
      // Tự tắt nền ảnh custom để tránh cảm giác "đổi theme không ăn".
      _updateThemeDraft(() {
        _draftCustomBackgroundUrl = '';
        _draftThemeKey = themeKey;
      });
      LegacyWebUi.showNotice(
        context,
        message: context.tr('theme_applied_msg'),
        success: true,
        title: context.tr('theme_applied'),
        icon: Icons.palette_rounded,
      );
      return;
    }

    if (themeKey == 'theme-vip-rotate') {
      await _loadVipStatus();
      if (!mounted) return;

      if (!_isVipActive) {
        LegacyWebUi.showNotice(
          context,
          message: AppConfig.isPurchaseEnabled
              ? context.tr('home_chtinnmi30_57840c')
              : context.tr('home_chtinnmi30_cf7b7c'),
          success: true,
          title: AppConfig.isPurchaseEnabled ? context.tr('home_cnpro_244529') : context.tr('home_chakhdng_9f4400'),
          icon: AppConfig.isPurchaseEnabled
              ? Icons.workspace_premium_rounded
              : Icons.info_outline_rounded,
        );
        return;
      }
    }

    if (_isVipThemeLocked(themeKey)) {
      _showToast(
        AppConfig.isPurchaseEnabled
            ? context.tr('home_chtinnmi30_ae1dc8')
            : context.tr('home_chtinnmi30_cf7b7c'),
        success: false,
      );
      await _openPremiumStoreFromThemePanel();
      return;
    }
    _updateThemeDraft(() => _draftThemeKey = themeKey);
  }

  void _handleAvatarFrameSelection(String frameKey) {
    if (_isVipFrameLocked(frameKey)) {
      _showToast(
        context.tr('home_lachnnyang_d9f089'),
        success: false,
      );
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
        (context.tr('frame_circle'), 'circle'),
        (context.tr('frame_rounded'), 'rounded'),
        ('Squircle', 'squircle'),
        (context.tr('frame_pearl'), 'pearl'),
        (context.tr('frame_glass'), 'glass'),
        if (AppConfig.isPurchaseEnabled)
          (
            _isVipActive
                ? context.tr('frame_vip')
                : '${context.tr('frame_vip')} 🔒',
            'vip'
          ),
      ],
      countdownStyles: [
        (context.tr('countdown_default'), 'default', false),
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
        for (final option in _settingsLanguageOptions) (option.title, option.code),
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
            _isVipActive ? 'Aurora PRO' : 'Aurora PRO 🔒',
            'premium'
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
    final effectKey = config.effects
            .any((item) => item.$2 == (_draftEffectKey ?? ui.fallingEffectKey))
        ? (_draftEffectKey ?? ui.fallingEffectKey)
        : config.effects.first.$2;
    final rawAvatarFrameKey = config.avatarFrames.any(
            (item) => item.$2 == (_draftAvatarFrameKey ?? ui.avatarFrameKey))
        ? (_draftAvatarFrameKey ?? ui.avatarFrameKey)
        : config.avatarFrames.first.$2;
    final countdownStyleKey = config.countdownStyles.any((item) =>
            item.$2 == (_draftCountdownStyleKey ?? ui.countdownStyleKey))
        ? (_draftCountdownStyleKey ?? ui.countdownStyleKey)
        : config.countdownStyles.first.$2;
    final fontKey =
        config.fonts.any((item) => item.key == (_draftFontKey ?? ui.fontKey))
            ? (_draftFontKey ?? ui.fontKey)
            : config.fonts.first.key;
    final languageKey = config.languages
            .any((item) => item.$2 == L10nService().localeCode)
        ? L10nService().localeCode
        : config.languages.first.$2;
    final homeToneKey = config.homeTones.any((item) =>
            item.$2 == (_draftHomeBlockToneKey ?? ui.homeBlockToneKey))
        ? (_draftHomeBlockToneKey ?? ui.homeBlockToneKey)
        : config.homeTones.first.$2;
    final graphicsKey = config.graphicsOptions.any((item) =>
            item.$2 == (_draftGraphicsQualityKey ?? ui.graphicsQualityKey))
        ? (_draftGraphicsQualityKey ?? ui.graphicsQualityKey)
        : UiPrefs.getAutoGraphicsQuality();
    final widgetThemeKey = config.widgetThemes
            .any((item) => item.$2 == (_draftWidgetThemeKey ?? 'pink'))
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
      previewBackground:
          (_draftCustomBackgroundUrl ?? ui.customBackgroundUrl).trim(),
    );
  }
  Widget _buildThemeHeader(BuildContext context, {bool showBack = true}) {
    const borderColor = Color(0xFFFF77A8);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBack) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF85A7), Color(0xFFFF5281)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5281).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('home_quayli_69043b'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              '🎨 ${context.tr('theme_ui').toUpperCase()}',
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD81B60),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
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
        if (!hideBackButton) _buildThemeHeader(context, showBack: !hideBackButton),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // 1. Hình nền & Hiệu ứng — thường dùng nhất
          _ThemeSectionCard(
            icon: Icons.palette_rounded,
            title: context.tr('theme_bg_effect_title'),
            description: context.tr('theme_bg_effect_desc'),
            themeColor: const Color(0xFF9C27B0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(context.tr('theme_falling_effect')),
                const SizedBox(height: 6),
                _buildEffectPresetStrip(selection.effectKey),
                const SizedBox(height: 12),
                _buildLabel(context.tr('theme_home_block_tone')),
                _buildThemeDropdownField(
                  value: selection.homeToneKey,
                  options: config.homeTones,
                  onChanged: (value) =>
                      _updateThemeDraft(() => _draftHomeBlockToneKey = value),
                ),
                const SizedBox(height: 14),
                _buildThemeHomeLikePreviewCard(
                  selection.previewBackground,
                  themeKey: selection.themeKey,
                  effectKey: selection.effectKey,
                  graphicsKey: selection.graphicsKey,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildGradientBtn(
                        label: _isUploadingThemeBackground
                            ? (_themeUploadProgress != null 
                                ? context.tr('theme_uploading_pct').replaceAll('{pct}', (_themeUploadProgress! * 100).toInt().toString())
                                : context.tr('theme_uploading_img'))
                            : context.tr('theme_upload_web_bg'),
                        gradient: const [Color(0xFFFF7EA8), Color(0xFFFF5E92)],
                        onTap: _isUploadingThemeBackground
                            ? () {}
                            : _pickThemeBackgroundImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGradientBtn(
                        label: context.tr('theme_remove_bg'),
                        gradient: const [Color(0xFFFF5B6A), Color(0xFFFF4343)],
                        onTap: _clearThemeBackgroundImage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 2. Khung & Kích thước
          _ThemeSectionCard(
            icon: Icons.aspect_ratio_rounded,
            title: context.tr('theme_frame_size'),
            description: context.tr('theme_frame_size_desc'),
            themeColor: const Color(0xFFFF4D73),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatefulBuilder(
                  builder: (context, setStateSlider) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr('theme_countdown_size')}: ${_localCountdownSize!.round()}px',
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF8A5B76),
                          ),
                        ),
                        Slider(
                          value: _localCountdownSize!,
                          min: 200,
                          max: UiPrefs.maxCountdownSizePx,
                          activeColor: const Color(0xFFD81B60),
                          inactiveColor: const Color(0xFFE6E6E6),
                          onChanged: (value) {
                            setStateSlider(() {
                              _localCountdownSize = value;
                            });
                            
                            _draftCountdownSizePx = value;
                            
                            // Chỉ cập nhật nhẹ preview card trong settings, không gọi _applyThemeDraftToUiPrefsPreview
                            // để tránh lag do rebuild toàn app khi kéo slider.
                            _panelRebuildNotifier.value++;
                          },
                          onChangeEnd: (value) {
                            // Khi thả tay ra mới cập nhật UiPrefs (sync) và đẩy lên mảng draft.
                            _updateThemeDraft(() => _draftCountdownSizePx = value, syncPreview: true);
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              // Lưu thủ công thay vì tự động lưu
                              _saveThemeSettings(silent: false);
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(
                              context.tr('theme_save_size'),
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD81B60),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildLabel(context.tr('theme_frame_type')),
                _buildThemeDropdownField(
                  value: selection.avatarFrameKey,
                  options: config.avatarFrames,
                  onChanged: _handleAvatarFrameSelection,
                ),
                const SizedBox(height: 12),
                _buildLabel(context.tr('theme_countdown_style')),
                _buildThemeDropdownField(
                  value: selection.countdownStyleKey,
                  options: config.countdownStyles.map((s) {
                    final locked = s.$3 &&
                        !_isVipActive &&
                        !selection.hasCountdownAdPass;
                    final label = locked ? '${s.$1} ${context.tr('theme_countdown_label_ad')}' : s.$1;
                    return (label, s.$2);
                  }).toList(),
                  onChanged: (value) => _handleCountdownStyleChange(value),
                ),
                const SizedBox(height: 10),
                _buildCountdownStyleStrip(selection.countdownStyleKey, selection.hasCountdownAdPass),
              ],
            ),
          ),
          // 3. Font chữ & Ngôn ngữ
          _ThemeSectionCard(
            icon: Icons.font_download_rounded,
            title: '${context.tr('font_label')} & ${context.tr('lang_label')}',
            description: context.tr('theme_font_lang_desc'),
            themeColor: const Color(0xFF00C8FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(context.tr('lang_label')),
                _buildThemeDropdownField(
                  value: selection.languageKey,
                  options: config.languages,
                  onChanged: (value) {
                    // Tránh khựng UI: Đợi menu dropdown đóng mượt mà xong (300ms) rồi mới load tệp JSON ngôn ngữ nặng
                    Future.delayed(const Duration(milliseconds: 300), () async {
                      await L10nService().setLocale(value);
                      if (!mounted) return;
                      setState(() {});
                    });
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
                    color: Colors.transparent,
                    border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
                  ),
                  child: Text(
                    context.tr('theme_font_desc'),
                    style: _themeFontStyle(
                      selection.fontKey,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 4. Thêm kỷ niệm
          _ThemeSectionCard(
            icon: Icons.calendar_month_rounded,
            title: context.tr('theme_add_new_memory'),
            description: context.tr('theme_memory_desc'),
            themeColor: const Color(0xFFFF77A8),
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
                                        parsed);
                                _anniversaryDateCtrl.selection =
                                    TextSelection.collapsed(
                                  offset: _anniversaryDateCtrl.text.length,
                                );
                              },
                              decoration: LegacyWebUi.softInputDecoration(
                                hintText: context.tr('home_ngythngnm_a697d0'),
                              ).copyWith(
                                errorText: _anniversaryDateErrorText,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                prefixIcon: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFFD81B60),
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.event_rounded, size: 18),
                                  color: const Color(0xFFD81B60),
                                  padding: EdgeInsets.zero,
                                  onPressed: _pickAnniversaryDate,
                                ),
                              ),
                              style: SLTheme.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF5F4C58),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _addCustomAnniversary,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF5E92), Color(0xFFD81B60)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.tr('home_thm_d9cb42'),
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
          _ThemeSectionCard(
            icon: Icons.settings_suggest_rounded,
            title: context.tr('theme_perf_title'),
            description: context.tr('theme_perf_desc'),
            themeColor: const Color(0xFF0288D1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trong suốt
                _SettingsToggleRow(
                  icon: Icons.blur_on_rounded,
                  iconColor: const Color(0xFFD81B60),
                  label: context.tr('home_trongsut_38b9d1'),
                  useCheckbox: true,
                  checkValue: _draftTransparentMode ?? ui.transparentMode,
                  onCheckChanged: (v) => _updateThemeDraft(
                      () => _draftTransparentMode = v ?? false),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                // Chế độ đơn giản hóa
                _SettingsToggleRow(
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFFF9800),
                  label: context.tr('theme_lite_mode_title'),
                  switchValue: _draftLiteMode,
                  onSwitchChanged: (v) => _updateThemeDraft(
                      () => _draftLiteMode = v),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                // Chất lượng đồ họa
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('theme_graphics_quality'),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _updateThemeDraft(
                        () => _draftGraphicsQualityKey = 'auto',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_draftGraphicsQualityKey ?? ui.graphicsQualityKey) == 'auto'
                              ? const Color(0xFF2877FF)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.tr('theme_graphics_auto'),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: (_draftGraphicsQualityKey ?? ui.graphicsQualityKey) == 'auto'
                                ? Colors.white
                                : const Color(0xFF64748B),
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
                                ? const Color(0xFFFF4D8D)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                // Trung tâm ủy quyền — compact inline row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0277BD).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 16,
                          color: Color(0xFF0277BD),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('theme_permission_center'),
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: _isGrantingPermissions ? null : _requestAllPermissions,
                          icon: _isGrantingPermissions
                              ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_user_rounded, size: 15),
                          label: Text(
                            Platform.isIOS
                                ? context.tr('home_thitlpquyn_942e97')
                                : context.tr('theme_grant_all_perms'),
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  // ignore: unused_element
  Widget _buildAIPanel({bool hideBackButton = false}) {
    return const SizedBox.shrink();
  }
}

class _ThemeSectionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final Color themeColor;

  const _ThemeSectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    required this.themeColor,
  });

  @override
  State<_ThemeSectionCard> createState() => _ThemeSectionCardState();
}

class _ThemeSectionCardState extends State<_ThemeSectionCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.themeColor.withValues(alpha: 0.35),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.themeColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            onExpansionChanged: (expanded) {
              setState(() {
                _isExpanded = expanded;
              });
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.themeColor,
                    widget.themeColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.themeColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: Text(
              widget.title,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
            ),
            subtitle: Text(
              widget.description,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFF94A3B8),
              size: 24,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
