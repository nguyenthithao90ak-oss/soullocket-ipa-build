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

  Widget _buildWidgetPanelTabBar() {
    return WidgetStudioSegmentedControl(
      selectedId: _widgetPanelTabKey,
      onChanged: (styleKey) {
        unawaited(_handleWidgetPanelTabChanged(styleKey));
      },
      items: [
        WidgetStudioTab(
          id: WidgetService.defaultWidgetStyleKey,
          label: context.tr('home_mcnh_a57a8e'),
          icon: Icons.widgets_rounded,
        ),
        WidgetStudioTab(
          id: 'countdown',
          label: context.tr('home_mngy_5500cb'),
          icon: Icons.timer_outlined,
        ),
        WidgetStudioTab(
          id: 'soulevent',
          label: context.tr('p7_widget_tab_memories'),
          icon: Icons.celebration_rounded,
        ),
      ],
    );
  }

  Widget _buildWidgetPanel({bool hideBackButton = false}) {
    final config = _buildWidgetPanelConfig();

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
        if (_widgetPanelTabKey == 'soulevent') {
          final houseId = _houseId ?? '';
          if (houseId.isNotEmpty) {
            await WidgetService.syncSoulEventWidgetData(houseId: houseId);
          }
          await WidgetService.requestPinSoulEventWidget();
        } else {
          await _persistAndSyncWidgetAppearance();
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
                _buildWidgetPreview(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr('widget_utility_examples'),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('widget_utility_examples_hint'),
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    color: SLColors.textMedium,
                  ),
                ),
                const SizedBox(height: 10),
                WidgetUtilityGallery(
                  sizeKey: _widgetPreviewSizeKey,
                  themeKey: _draftWidgetThemeKey ?? 'pink',
                  animated: _widgetHeartAnimated,
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
                    color: const Color(0xFF8E6A76),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildWidgetPanelTabBar(),
          const SizedBox(height: 14),
          if (_widgetPanelTabKey == 'soulevent') ...[
            _buildWidgetSectionCard(
              icon: Icons.info_outline_rounded,
              title: context.tr('p7_event_widget_config'),
              subtitle: null,
              iconGradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.tr('p7_event_widget_config_desc'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildWidgetSectionCard(
            icon: Icons.palette_outlined,
            title: context.tr('theme_widget_bg'),
            subtitle: null,
            iconGradient: const [Color(0xFFFF9A9E), Color(0xFFFECF6A)],
            child: _buildWidgetThemeSwatchGrid(config),
          ),
          const SizedBox(height: 14),
          _buildWidgetSectionCard(
            icon: Icons.auto_awesome_rounded,
            title: context.tr('widget_gentle_motion'),
            subtitle: null,
            iconGradient: const [Color(0xFF9A79C6), Color(0xFFC5B0DF)],
            child: WidgetContentToggle(
              icon: Icons.auto_awesome_rounded,
              title: context.tr('widget_gentle_motion'),
              subtitle: context.tr(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? 'widget_ios_motion_hint'
                    : 'widget_motion_keeps_choice',
              ),
              value: _widgetHeartAnimated,
              accent: const Color(0xFF9A79C6),
              onChanged: (value) => unawaited(
                _updateWidgetAppearanceDraft(
                  () => _widgetHeartAnimated = value,
                ),
              ),
            ),
          ),
          if (_widgetPanelTabKey != 'soulevent') ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.favorite_rounded,
              title: context.tr('home_tritimvnid_67f35f'),
              subtitle: null,
              iconGradient: const [Color(0xFFFF86A8), Color(0xFFFF5B8A)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('home_kiutritim_87a57e'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF243041),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWidgetHeartStylePicker(),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('widget_center_selection_hint'),
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      color: const Color(0xFF8E6A76),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE5ECF4)),
                  const SizedBox(height: 14),
                  if (_widgetPanelTabKey != 'countdown')
                    WidgetContentToggle(
                      icon: Icons.photo_library_outlined,
                      title: context.tr('widget_show_diary_photos'),
                      subtitle: context.tr('widget_diary_content_hint'),
                      value: _showDiaryOnWidget,
                      accent: const Color(0xFF8A78B4),
                      onChanged: _handleWidgetDiaryVisibilityChanged,
                    ),
                  if (_showDiaryOnWidget &&
                      _widgetPanelTabKey != 'countdown') ...[
                    const SizedBox(height: 12),
                    Text(
                      context.tr('widget_photo_layout'),
                      style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    WidgetPhotoLayoutPicker(
                      selectedKey: _widgetDiaryLayoutKey,
                      labels: {
                        for (final item in config.diaryLayoutOptions)
                          item.$2: item.$1,
                      },
                      onChanged: (key) => unawaited(
                        _updateWidgetAppearanceDraft(
                          () => _widgetDiaryLayoutKey = key,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('widget_photo_frame'),
                      style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    WidgetPhotoFramePicker(
                      selectedKey: _widgetPhotoFrameKey,
                      labels: {
                        for (final key in WidgetAppearance.photoFrameKeys)
                          key: context.tr('widget_frame_$key'),
                      },
                      onChanged: (key) => unawaited(
                        _updateWidgetAppearanceDraft(
                          () => _widgetPhotoFrameKey = key,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('widget_photo_sync_hint'),
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        color: const Color(0xFF8E6A76),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_widgetPanelTabKey != 'soulevent') ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.auto_awesome_rounded,
              title: context.tr('widget_sticker_collection'),
              subtitle: context.tr('widget_sticker_choice_hint'),
              iconGradient: const [Color(0xFFAB8BD1), Color(0xFFF1A9B7)],
              child: _buildWidgetStickerPicker(),
            ),
          ],
          if (_widgetPanelTabKey == 'countdown') ...[
            const SizedBox(height: 14),
            _buildWidgetSectionCard(
              icon: Icons.timer_rounded,
              title: context.tr('home_widgetmngy_92c2bc'),
              subtitle: context.tr('home_chnyutinsn_20a566'),
              iconGradient: const [Color(0xFFFFB84D), Color(0xFFFF7A59)],
              child: Text(
                context
                    .tr('widget_using_style')
                    .replaceAll('{style}', _widgetStyleLabel(_widgetStyleKey)),
                style: SLTheme.quicksand(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  color: SLColors.textMedium,
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
              iconGradient: const [Color(0xFFF472B6), Color(0xFFEC4899)],
              child: Text(
                context.tr('p7_event_widget_desc'),
                style: SLTheme.quicksand(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  color: SLColors.textMedium,
                  height: 1.45,
                ),
              ),
            ),
          ],
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
            iconGradient: const [Color(0xFF14B8A6), Color(0xFF06B6D4)],
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
                      gradient: const [Color(0xFFFF7898), Color(0xFFD81B60)],
                      onTap: handleRefreshWidget,
                    );
                    if (!showPinButton) {
                      return updateButton;
                    }
                    final addButton = _buildGradientBtn(
                      label: context.tr('add_widget'),
                      gradient: const [Color(0xFF10C8E6), Color(0xFF0E9EB0)],
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5FBFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCAEAF3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0EA5C6,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF0B7285),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('home_hngdnios_522391'),
                                style: SLTheme.quicksand(
                                  fontSize: 12.6,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0B7285),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('widget_ios_guide'),
                                style: SLTheme.quicksand(
                                  fontSize: 11.8,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF667085),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
}
