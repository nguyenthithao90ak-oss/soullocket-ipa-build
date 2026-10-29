// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../settings_tab.dart';

// Shell-ready extraction target for shared draft state:
// - controllers/settings_theme_controller.dart
class _WidgetPanelConfig {
  final List<(String, String)> themeOptions;
  final List<(String, String)> heartColorOptions;
  final List<(String, String)> previewSizeOptions;
  final List<(String, String)> diaryLayoutOptions;
  final List<(String, String)> seasonModeOptions;
  final String smartSeasonKey;
  final List<Color> smartHeartPalette;
  final Color smartAccentColor;
  final Color smartSurfaceColor;
  final String smartThemeLabel;
  final String smartSeasonLabel;

  const _WidgetPanelConfig({
    required this.themeOptions,
    required this.heartColorOptions,
    required this.previewSizeOptions,
    required this.diaryLayoutOptions,
    required this.seasonModeOptions,
    required this.smartSeasonKey,
    required this.smartHeartPalette,
    required this.smartAccentColor,
    required this.smartSurfaceColor,
    required this.smartThemeLabel,
    required this.smartSeasonLabel,
  });
}

extension _SettingsTabWidgetSection on _SettingsTabState {
  _WidgetPanelConfig _buildWidgetPanelConfig() {
    final themeOptions = [
      (context.tr('home_hngngt_6a8c4a'), 'pink'),
      (context.tr('home_tihini_18f563'), 'dark'),
      (context.tr('home_trngtinh_2fff95'), 'white'),
      (context.tr('p7_color_blue'), 'blue'),
      (context.tr('home_camnng_da76a5'), 'orange'),
      (context.tr('home_tmmng_9db47d'), 'purple'),
      (context.tr('home_xanhngc_49b55b'), 'green'),
      (context.tr('home_m_720483'), 'red'),
      if (AppConfig.isPurchaseEnabled) ...[
        (context.tr('p7_theme_aurora'), 'premium'),
        (context.tr('p7_theme_cosmic'), 'cosmic'),
        (
          '${context.tr('home_decor_background_weather_premium')}${_isVipActive ? '' : ' 🔒'}',
          'weather_premium',
        ),
      ],
    ];
    final heartColorOptions = [
      (context.tr('home_hngrose_ee75eb'), 'rose'),
      (context.tr('home_ruby_cb8e85'), 'ruby'),
      (context.tr('home_tmviolet_19bc69'), 'violet'),
      (context.tr('p7_heart_ocean'), 'ocean'),
      (context.tr('home_honghn_ab7dad'), 'sunset'),
      (context.tr('p7_color_gold'), 'gold'),
      (context.tr('p7_transparent_off'), 'none'),
    ];
    final previewSizeOptions = _widgetPreviewSizeKeys
        .map((key) => (_widgetPreviewSizeLabel(key), key))
        .toList(growable: false);
    final diaryLayoutOptions = _widgetDiaryLayoutKeys
        .map((key) => (_widgetDiaryLayoutLabel(key), key))
        .toList(growable: false);
    final seasonModeOptions = _widgetSeasonModeKeys
        .map((key) => (_widgetSeasonModeLabel(key), key))
        .toList(growable: false);
    final smartSeasonKey = _resolvedWidgetSeasonKey();
    final smartSeasonPalette = _widgetSeasonPalette(smartSeasonKey);
    final smartHeartPalette = _widgetHeartPalette(_widgetHeartColorKey);
    final smartAccentColor = smartSeasonKey == 'none'
        ? smartHeartPalette.first
        : smartSeasonPalette.first;
    final smartSurfaceColor = smartSeasonKey == 'none'
        ? smartHeartPalette.last
        : smartSeasonPalette.last;
    final smartThemeLabel = themeOptions
        .firstWhere(
          (item) => item.$2 == (_draftWidgetThemeKey ?? 'pink'),
          orElse: () => (context.tr('p7_color_pink'), 'pink'),
        )
        .$1;
    final smartSeasonLabel = smartSeasonKey == 'none'
        ? context.tr('home_tngphimu_c549ba')
        : WidgetService.seasonLabel(smartSeasonKey);

    return _WidgetPanelConfig(
      themeOptions: themeOptions,
      heartColorOptions: heartColorOptions,
      previewSizeOptions: previewSizeOptions,
      diaryLayoutOptions: diaryLayoutOptions,
      seasonModeOptions: seasonModeOptions,
      smartSeasonKey: smartSeasonKey,
      smartHeartPalette: smartHeartPalette,
      smartAccentColor: smartAccentColor,
      smartSurfaceColor: smartSurfaceColor,
      smartThemeLabel: smartThemeLabel,
      smartSeasonLabel: smartSeasonLabel,
    );
  }

  Widget _buildWidgetPanel({bool hideBackButton = false}) {
    final config = _buildWidgetPanelConfig();
    final selectedTemplate = WidgetStudioTemplate.fromId(_widgetPanelTabKey);

    Future<void> handlePinWidget() async {
      if (kIsWeb) {
        await showAppHelpArticle(context, 'widget');
        return;
      }
      try {
        if (Theme.of(context).platform == TargetPlatform.iOS) {
          if (_widgetPanelTabKey == 'soulevent') {
            final houseId = _houseId ?? '';
            if (houseId.isNotEmpty) {
              await WidgetService.syncSoulEventWidgetData(houseId: houseId);
            }
          } else {
            await _persistAndSyncWidgetAppearance();
          }
          if (!mounted) return;
          await showAppHelpArticle(context, 'widget');
          return;
        }
        final supported = await HomeWidget.isRequestPinWidgetSupported();
        if (!mounted) return;
        if (supported != true) {
          _showToast(context.tr('widget_err_not_supported'));
          await showAppHelpArticle(context, 'widget');
          return;
        }
        await _persistAndSyncWidgetAppearance();
        switch (selectedTemplate) {
          case WidgetStudioTemplate.event:
            await WidgetService.requestPinSoulEventWidget();
          case WidgetStudioTemplate.cycle:
            await WidgetService.requestPinCycleWidget();
          case WidgetStudioTemplate.calendar:
            await WidgetService.requestPinCalendarWidget();
          case WidgetStudioTemplate.sleep:
            await WidgetService.requestPinSleepWidget();
          case WidgetStudioTemplate.classic:
          case WidgetStudioTemplate.countdown:
            await WidgetService.requestPinWidget();
        }
        if (!mounted) return;
        _showToast(context.tr('widget_pin_req_sent'), success: true);
      } catch (_) {
        if (!mounted) return;
        _showToast(context.tr('home_chathghimw_8f0d01'));
      }
    }

    Future<void> handleRefreshWidget() async {
      if (kIsWeb) {
        _showToast(context.tr('home_tinchnykhn_b04ead'));
        return;
      }
      try {
        if (_widgetPanelTabKey == 'soulevent') {
          final houseId = _houseId ?? '';
          if (houseId.isNotEmpty) {
            await WidgetService.syncSoulEventWidgetData(houseId: houseId);
          }
        } else {
          WidgetService.invalidateRuntimeCache();
          await _persistAndSyncWidgetAppearance();
        }
        if (!mounted) return;
        setState(() => _widgetMediaRevision++);
        _showToast(context.tr('widget_updated_success'), success: true);
      } catch (_) {
        if (!mounted) return;
        _showToast(context.tr('home_chathcpnht_1f5871'));
      }
    }

    // Bố cục mới gom các lựa chọn theo đúng thứ tự người dùng cần làm:
    // chọn loại → xem trước → tùy chỉnh → thêm vào màn hình. Phần UI cũ bên
    // dưới được giữ lại tạm thời để không làm mất các callback/logic đồng bộ
    // trong lúc chuyển đổi, nhưng không còn được dựng.
    return _buildSimpleWidgetPanel(
      config: config,
      selectedTemplate: selectedTemplate,
      onPin: handlePinWidget,
      onRefresh: handleRefreshWidget,
      hideBackButton: hideBackButton,
    );

    final isStandalone = Navigator.of(context).canPop();

    return WidgetStudioPanel(
      title: context.tr('widget_utility'),
      onBack: !hideBackButton && isStandalone
          ? () => Navigator.of(context).pop()
          : null,
      onClose: !isStandalone ? () => _togglePanel('widget') : null,
      leading: ValueListenableBuilder<UiPrefsState>(
        valueListenable: UiPrefs.notifier,
        builder: (context, ui, _) =>
            SoulLocketBrandMark(styleKey: ui.brandMarkKey, size: 22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHelpButton(articleId: 'widget'),
          WidgetStudioPreviewStage(
            title: context.tr('home_xemtrcwidg_189f43'),
            themeName: config.smartThemeLabel,
            child: Column(
              children: [
                WidgetUtilityGallery(
                  sizeKey: _widgetPreviewSizeKey,
                  themeKey: _draftWidgetThemeKey ?? 'pink',
                  animated: _widgetHeartAnimated,
                  selectedId: selectedTemplate.id,
                  onChanged: (id) =>
                      unawaited(_handleWidgetPanelTabChanged(id)),
                  previewBuilder: (_) => _buildWidgetPreview(),
                ),
                const SizedBox(height: 14),
                WidgetStudioSegmentedControl(
                  selectedId: _widgetPreviewSizeKey,
                  onChanged: (key) {
                    setState(() => _widgetPreviewSizeKey = key);
                    unawaited(_persistWidgetPrefs());
                  },
                  items: config.previewSizeOptions
                      .map(
                        (item) => WidgetStudioTab(
                          id: item.$2,
                          label: item.$1,
                          icon: item.$2 == 'small'
                              ? Icons.crop_square
                              : item.$2 == 'large'
                              ? Icons.fullscreen
                              : Icons.aspect_ratio,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? 'ios_widget_pin_guide'
                        : 'widget_preview_resize_hint',
                  ),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    color: SLSettingsColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_widgetPanelTabKey == 'soulevent') ...[
            _buildWidgetSectionCard(
              icon: Icons.info_outline_rounded,
              title: context.tr('p7_event_widget_config'),
              subtitle: null,
              iconGradient: const [SLSettingsColors.sky],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.tr('p7_event_widget_config_desc'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SLSettingsColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          WidgetStudioDisclosure(
            title: context.tr('widget_utility'),
            subtitle: context.tr('widget_preview_resize_hint'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const SizedBox(height: 14),
          _buildWidgetSectionCard(
            icon: Icons.palette_outlined,
            title: context.tr('theme_widget_bg'),
            subtitle: null,
            iconGradient: const [SLSettingsColors.coral],
            child: _buildWidgetThemeSwatchGrid(config),
          ),
          const SizedBox(height: 14),
          _buildWidgetSectionCard(
            icon: Icons.auto_awesome_rounded,
            title: context.tr('widget_gentle_motion'),
            subtitle: null,
            iconGradient: const [SLSettingsColors.violet],
            child: WidgetContentToggle(
              icon: Icons.auto_awesome_rounded,
              title: context.tr('widget_gentle_motion'),
              subtitle: context.tr(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? 'widget_ios_motion_hint'
                    : 'widget_motion_keeps_choice',
              ),
              value: _widgetHeartAnimated,
              accent: SLSettingsColors.violet,
              onChanged: (value) => unawaited(
                _updateWidgetAppearanceDraft(
                  () => _widgetHeartAnimated = value,
                ),
              ),
            ),
          ),
          if (selectedTemplate.usesCoupleStyle) ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.favorite_rounded,
              title: context.tr('home_tritimvnid_67f35f'),
              subtitle: null,
              iconGradient: const [SLSettingsColors.rose],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('home_kiutritim_87a57e'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: SLSettingsColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWidgetHeartStylePicker(),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('widget_center_selection_hint'),
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      color: SLSettingsColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: SLSettingsColors.divider),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
          if (selectedTemplate.usesCoupleStyle) ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.auto_awesome_rounded,
              title: context.tr('widget_sticker_collection'),
              subtitle: context.tr('widget_sticker_choice_hint'),
              iconGradient: const [SLSettingsColors.violet],
              child: _buildWidgetStickerPicker(),
            ),
          ],
          if (selectedTemplate.usesCoupleStyle) ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.photo_library_outlined,
              title: context.tr('widget_show_diary_photos'),
              subtitle: context.tr('widget_photo_sync_hint'),
              iconGradient: const [SLSettingsColors.sky],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WidgetContentToggle(
                    icon: Icons.photo_outlined,
                    title: context.tr('widget_show_diary_photos'),
                    subtitle: context.tr('widget_diary_content_hint'),
                    value: _showDiaryOnWidget,
                    accent: SLSettingsColors.sky,
                    onChanged: (value) => unawaited(
                      _handleWidgetDiaryVisibilityChanged(value),
                    ),
                  ),
                  if (_showDiaryOnWidget) ...[
                    const SizedBox(height: 14),
                    Text(
                      context.tr('widget_photo_layout'),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: SLSettingsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    WidgetPhotoLayoutPicker(
                      selectedKey: _widgetDiaryLayoutKey,
                      labels: {
                        for (final option in config.diaryLayoutOptions)
                          option.$2: option.$1,
                      },
                      onChanged: (value) => unawaited(
                        _updateWidgetAppearanceDraft(
                          () => _widgetDiaryLayoutKey = value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('widget_photo_frame'),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: SLSettingsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    WidgetPhotoFramePicker(
                      selectedKey: _widgetPhotoFrameKey,
                      labels: {
                        'rounded': context.tr('widget_frame_rounded'),
                        'heart': context.tr('widget_frame_heart'),
                        'polaroid': context.tr('widget_frame_polaroid'),
                      },
                      onChanged: (value) => unawaited(
                        _updateWidgetAppearanceDraft(
                          () => _widgetPhotoFrameKey = value,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_widgetPanelTabKey == 'countdown') ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.timer_rounded,
              title: context.tr('home_widgetmngy_92c2bc'),
              subtitle: context.tr('home_chnyutinsn_20a566'),
              iconGradient: const [SLSettingsColors.amber],
              child: Text(
                context
                    .tr('widget_using_style')
                    .replaceAll('{style}', _widgetStyleLabel(_widgetStyleKey)),
                style: SLTheme.quicksand(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  color: SLSettingsColors.inkSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (_widgetPanelTabKey == 'soulevent') ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.celebration_rounded,
              title: context.tr('p7_event_widget_title'),
              subtitle: context.tr('p7_event_widget_subtitle'),
              iconGradient: const [SLSettingsColors.rose],
              child: Text(
                context.tr('p7_event_widget_desc'),
                style: SLTheme.quicksand(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  color: SLSettingsColors.inkSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],

              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildWidgetSectionCard(
            icon: Icons.add_to_home_screen_rounded,
            title: Theme.of(context).platform == TargetPlatform.iOS
                ? '${context.tr('settings_widget_label')}:'
                : context.tr('android_real_widget'),
            subtitle: context.tr(
              Theme.of(context).platform == TargetPlatform.iOS
                  ? 'ios_widget_pin_guide'
                  : 'add_widget_desc',
            ),
            iconGradient: const [SLSettingsColors.teal],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useColumn = constraints.maxWidth < 330;
                    final showPinButton =
                        Theme.of(context).platform != TargetPlatform.iOS;
                    final updateButton = _buildGradientBtn(
                      label: context.tr('update_widget'),
                      gradient: const [],
                      icon: Icons.refresh_rounded,
                      variant: showPinButton
                          ? SLSettingsButtonVariant.tonal
                          : SLSettingsButtonVariant.primary,
                      onTap: handleRefreshWidget,
                    );
                    if (!showPinButton) {
                      return updateButton;
                    }
                    final addButton = _buildGradientBtn(
                      label: context.tr('add_widget'),
                      gradient: const [],
                      icon: Icons.add_to_home_screen_rounded,
                      onTap: handlePinWidget,
                    );
                    if (useColumn) {
                      return Column(
                        children: [
                          addButton,
                          const SizedBox(height: 10),
                          updateButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: addButton),
                        const SizedBox(width: 12),
                        Expanded(child: updateButton),
                      ],
                    );
                  },
                ),
                if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                  const SizedBox(height: 12),
                  SLSettingsNotice(
                    tone: SLSettingsTone.info,
                    title: context.tr('home_hngdnios_522391'),
                    message: context.tr('widget_ios_guide'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Decorative icon for each widget theme swatch.
  IconData _widgetThemeSwatchIcon(String key) {
    switch (key) {
      case 'pink':
        return Icons.favorite_rounded;
      case 'white':
        return Icons.ac_unit_rounded;
      case 'dark':
        return Icons.dark_mode_rounded;
      case 'blue':
        return Icons.waves;
      case 'orange':
        return Icons.wb_sunny_rounded;
      case 'purple':
        return Icons.auto_awesome_rounded;
      case 'green':
        return Icons.eco_rounded;
      case 'red':
        return Icons.local_fire_department_rounded;
      case 'premium':
        return Icons.brightness_auto_rounded;
      case 'cosmic':
        return Icons.star_rounded;
      case 'weather_premium':
        return Icons.cloud_outlined;
      default:
        return Icons.palette_rounded;
    }
  }

  /// Color swatch grid for widget background theme selection.
  Widget _buildWidgetThemeSwatchGrid(_WidgetPanelConfig config) {
    return WidgetStudioThemePicker(
      selectedId: _draftWidgetThemeKey ?? 'pink',
      onChanged: (key) => unawaited(_handleWidgetThemeChanged(key)),
      options: config.themeOptions
          .map(
            (item) => WidgetStudioThemeOption(
              id: item.$2,
              label: item.$1,
              colors: _widgetPreviewThemeSpec(item.$2).colors,
              icon: _widgetThemeSwatchIcon(item.$2),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildSimpleWidgetPanel({
    required _WidgetPanelConfig config,
    required WidgetStudioTemplate selectedTemplate,
    required Future<void> Function() onPin,
    required Future<void> Function() onRefresh,
    required bool hideBackButton,
  }) {
    final isStandalone = Navigator.of(context).canPop();
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final descriptionKey = isIos || kIsWeb
        ? 'settings_widget_desc_web'
        : 'settings_widget_desc_mobile';

    Widget compactExpansion({
      required String title,
      String? subtitle,
      required Widget child,
      Widget? leading,
    }) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: leading,
          title: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: SLSettingsColors.ink,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SLSettingsColors.inkSecondary,
                  ),
                ),
          children: [child],
        ),
      );
    }

    final selectedTheme = config.smartThemeLabel;
    final selectedSize = config.previewSizeOptions
        .firstWhere(
          (item) => item.$2 == _widgetPreviewSizeKey,
          orElse: () => config.previewSizeOptions.first,
        )
        .$1;

    return WidgetStudioPanel(
      title: context.tr('widget_utility'),
      onBack: !hideBackButton && isStandalone
          ? () => Navigator.of(context).pop()
          : null,
      onClose: !isStandalone ? () => _togglePanel('widget') : null,
      leading: ValueListenableBuilder<UiPrefsState>(
        valueListenable: UiPrefs.notifier,
        builder: (context, ui, _) =>
            SoulLocketBrandMark(styleKey: ui.brandMarkKey, size: 22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppHelpButton(articleId: 'widget'),
          WidgetStudioSection(
            icon: Icons.touch_app_rounded,
            accent: SLSettingsColors.teal,
            title: context.tr('settings_widget_label'),
            subtitle: context.tr(descriptionKey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WidgetUtilityGallery(
                  sizeKey: _widgetPreviewSizeKey,
                  themeKey: _draftWidgetThemeKey ?? 'pink',
                  animated: _widgetHeartAnimated,
                  selectedId: selectedTemplate.id,
                  onChanged: (id) =>
                      unawaited(_handleWidgetPanelTabChanged(id)),
                  previewBuilder: (_) => _buildWidgetPreview(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.photo_size_select_small_rounded,
                      size: 18,
                      color: SLSettingsColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedSize,
                        style: SLTheme.quicksand(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: SLSettingsColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                WidgetStudioSegmentedControl(
                  selectedId: _widgetPreviewSizeKey,
                  onChanged: (key) {
                    setState(() => _widgetPreviewSizeKey = key);
                    unawaited(_persistWidgetPrefs());
                  },
                  items: config.previewSizeOptions
                      .map(
                        (item) => WidgetStudioTab(
                          id: item.$2,
                          label: item.$1,
                          icon: item.$2 == 'small'
                              ? Icons.crop_square
                              : item.$2 == 'large'
                              ? Icons.fullscreen
                              : Icons.aspect_ratio,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    isIos ? 'ios_widget_pin_guide' : 'widget_preview_resize_hint',
                  ),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    color: SLSettingsColors.inkSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WidgetStudioSection(
            icon: Icons.palette_outlined,
            accent: SLSettingsColors.coral,
            title: context.tr('theme_widget_bg'),
            subtitle: selectedTheme,
            child: compactExpansion(
              title: selectedTheme,
              subtitle: context.tr('theme_widget_bg'),
              leading: Icon(
                Icons.palette_outlined,
                color: SLSettingsColors.coral,
                size: 20,
              ),
              child: _buildWidgetThemeSwatchGrid(config),
            ),
          ),
          if (selectedTemplate.usesCoupleStyle) ...[
            const SizedBox(height: 12),
            WidgetStudioSection(
              icon: Icons.favorite_rounded,
              accent: SLSettingsColors.rose,
              title: context.tr('home_tritimvnid_67f35f'),
              subtitle: context.tr('widget_center_selection_hint'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WidgetContentToggle(
                    icon: Icons.auto_awesome_rounded,
                    title: context.tr('widget_gentle_motion'),
                    subtitle: context.tr(
                      isIos ? 'widget_ios_motion_hint' : 'widget_motion_keeps_choice',
                    ),
                    value: _widgetHeartAnimated,
                    accent: SLSettingsColors.violet,
                    onChanged: (value) => unawaited(
                      _updateWidgetAppearanceDraft(
                        () => _widgetHeartAnimated = value,
                      ),
                    ),
                  ),
                  if (_widgetHeartAnimated) ...[
                    const SizedBox(height: 10),
                    WidgetMotionIntervalPicker(
                      selectedMinutes: _widgetMotionIntervalMinutes,
                      isIos: isIos,
                      title: context.tr('widget_motion_interval_title'),
                      optionLabel: (minutes) => context
                          .tr('widget_motion_interval_option')
                          .replaceAll('{minutes}', minutes.toString()),
                      onChanged: (minutes) => unawaited(
                        _updateWidgetAppearanceDraft(
                          () => _widgetMotionIntervalMinutes = minutes,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  compactExpansion(
                    title: context.tr('home_kiutritim_87a57e'),
                    subtitle: context.tr('widget_center_selection_hint'),
                    leading: const Icon(
                      Icons.favorite_border_rounded,
                      color: SLSettingsColors.rose,
                    ),
                    child: _buildWidgetHeartStylePicker(),
                  ),
                  compactExpansion(
                    title: context.tr('widget_sticker_collection'),
                    subtitle: context.tr('widget_sticker_choice_hint'),
                    leading: const Icon(
                      Icons.auto_awesome_rounded,
                      color: SLSettingsColors.violet,
                    ),
                    child: _buildWidgetStickerPicker(),
                  ),
                  compactExpansion(
                    title: context.tr('widget_show_diary_photos'),
                    subtitle: context.tr('widget_photo_sync_hint'),
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: SLSettingsColors.sky,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WidgetContentToggle(
                          icon: Icons.photo_outlined,
                          title: context.tr('widget_show_diary_photos'),
                          subtitle: context.tr('widget_diary_content_hint'),
                          value: _showDiaryOnWidget,
                          accent: SLSettingsColors.sky,
                          onChanged: (value) => unawaited(
                            _handleWidgetDiaryVisibilityChanged(value),
                          ),
                        ),
                        if (_showDiaryOnWidget) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.tr('widget_photo_layout'),
                            style: SLTheme.quicksand(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: SLSettingsColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          WidgetPhotoLayoutPicker(
                            selectedKey: _widgetDiaryLayoutKey,
                            labels: {
                              for (final option in config.diaryLayoutOptions)
                                option.$2: option.$1,
                            },
                            onChanged: (value) => unawaited(
                              _updateWidgetAppearanceDraft(
                                () => _widgetDiaryLayoutKey = value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr('widget_photo_frame'),
                            style: SLTheme.quicksand(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: SLSettingsColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          WidgetPhotoFramePicker(
                            selectedKey: _widgetPhotoFrameKey,
                            labels: {
                              'rounded': context.tr('widget_frame_rounded'),
                              'heart': context.tr('widget_frame_heart'),
                              'polaroid': context.tr('widget_frame_polaroid'),
                            },
                            onChanged: (value) => unawaited(
                              _updateWidgetAppearanceDraft(
                                () => _widgetPhotoFrameKey = value,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          WidgetStudioSection(
            icon: Icons.add_to_home_screen_rounded,
            accent: SLSettingsColors.teal,
            title: isIos
                ? context.tr('settings_widget_label')
                : context.tr('android_real_widget'),
            subtitle: context.tr('add_widget_desc'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final updateButton = _buildGradientBtn(
                      label: context.tr('update_widget'),
                      gradient: const [],
                      icon: Icons.refresh_rounded,
                      variant: isIos
                          ? SLSettingsButtonVariant.primary
                          : SLSettingsButtonVariant.tonal,
                      onTap: onRefresh,
                    );
                    if (isIos) return updateButton;
                    final addButton = _buildGradientBtn(
                      label: context.tr('add_widget'),
                      gradient: const [],
                      icon: Icons.add_to_home_screen_rounded,
                      onTap: onPin,
                    );
                    if (constraints.maxWidth < 330) {
                      return Column(
                        children: [
                          addButton,
                          const SizedBox(height: 8),
                          updateButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: addButton),
                        const SizedBox(width: 10),
                        Expanded(child: updateButton),
                      ],
                    );
                  },
                ),
                if (isIos) ...[
                  const SizedBox(height: 10),
                  SLSettingsNotice(
                    tone: SLSettingsTone.info,
                    title: context.tr('home_hngdnios_522391'),
                    message: context.tr('widget_ios_guide'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
