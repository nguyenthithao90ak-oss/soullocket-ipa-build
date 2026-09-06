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
        _showToast(context.tr('home_tinchnykhn_b04ead'));
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
          _showToast(context.tr('ios_widget_pin_guide'), success: true);
          return;
        }
        final supported = await HomeWidget.isRequestPinWidgetSupported();
        if (!mounted) return;
        if (supported != true) {
          _showToast(context.tr('widget_err_not_supported'));
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
          WidgetStudioPreviewStage(
            title: context.tr('home_xemtrcwidg_189f43'),
            themeName: config.smartThemeLabel,
            child: _buildWidgetPreview(),
          ),
          const SizedBox(height: 16),
          if (Theme.of(context).platform != TargetPlatform.iOS) ...[
            _buildWidgetPanelTabBar(),
            const SizedBox(height: 14),
          ],
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
          ] else ...[
            _buildWidgetSectionCard(
              icon: Icons.palette_outlined,
              title: context.tr('theme_widget_bg'),
              subtitle: null,
              iconGradient: const [Color(0xFFFF9A9E), Color(0xFFFECF6A)],
              child: _buildWidgetThemeSwatchGrid(config),
            ),
          ],
          if (_widgetPanelTabKey == WidgetService.defaultWidgetStyleKey) ...[
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
                  const SizedBox(height: 14),
                  Text(
                    context.tr('home_mutritim_6406c9'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF243041),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildThemeDropdownField(
                    value: _widgetHeartColorKey,
                    options: config.heartColorOptions,
                    onChanged: (value) async =>
                        _handleWidgetHeartColorChanged(value),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE5ECF4)),
                  const SizedBox(height: 14),
                  _buildWidgetToggleTile(
                    icon: Icons.photo_library_outlined,
                    title: context.tr('widget_show_diary_photos'),
                    subtitle: null,
                    value: _showDiaryOnWidget,
                    accentColor: const Color(0xFF0EA5C6),
                    onChanged: _handleWidgetDiaryVisibilityChanged,
                  ),
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
            subtitle: context.tr('add_widget_desc'),
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
    // Map themeKey -> (gradient colors, label)
    final swatches = <(String, List<Color>, String)>[
      (
        'pink',
        [const Color(0xFFFFB6CA), const Color(0xFFFF7098)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'pink',
              orElse: () => (context.tr('p7_color_pink'), 'pink'),
            )
            .$1,
      ),
      (
        'white',
        [const Color(0xFFF8F8F8), const Color(0xFFE8EDF5)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'white',
              orElse: () => (context.tr('p7_color_white'), 'white'),
            )
            .$1,
      ),
      (
        'dark',
        [const Color(0xFF3A3A4A), const Color(0xFF1C1C2E)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'dark',
              orElse: () => (context.tr('p7_color_dark'), 'dark'),
            )
            .$1,
      ),
      (
        'blue',
        [const Color(0xFF90CAF9), const Color(0xFF1565C0)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'blue',
              orElse: () => (context.tr('p7_color_blue'), 'blue'),
            )
            .$1,
      ),
      (
        'orange',
        [const Color(0xFFFFCC80), const Color(0xFFEF6C00)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'orange',
              orElse: () => (context.tr('p7_color_orange'), 'orange'),
            )
            .$1,
      ),
      (
        'purple',
        [const Color(0xFFCE93D8), const Color(0xFF6A1B9A)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'purple',
              orElse: () => (context.tr('p7_color_purple'), 'purple'),
            )
            .$1,
      ),
      (
        'green',
        [const Color(0xFFA5D6A7), const Color(0xFF2E7D32)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'green',
              orElse: () => (context.tr('p7_color_green'), 'green'),
            )
            .$1,
      ),
      (
        'red',
        [const Color(0xFFEF9A9A), const Color(0xFFB71C1C)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'red',
              orElse: () => (context.tr('p7_color_red'), 'red'),
            )
            .$1,
      ),
      if (AppConfig.isPurchaseEnabled) ...[
        (
          'premium',
          [const Color(0xFFFBC2EB), const Color(0xFFA6C1EE)],
          config.themeOptions
              .firstWhere(
                (o) => o.$2 == 'premium',
                orElse: () => (context.tr('p7_theme_aurora'), 'premium'),
              )
              .$1,
        ),
        (
          'cosmic',
          [const Color(0xFF0F0C20), const Color(0xFFFFD700)],
          config.themeOptions
              .firstWhere(
                (o) => o.$2 == 'cosmic',
                orElse: () => (context.tr('p7_theme_cosmic'), 'cosmic'),
              )
              .$1,
        ),
      ],
    ];

    final currentKey = _draftWidgetThemeKey ?? 'pink';

    return WidgetStudioThemePicker(
      selectedId: currentKey,
      onChanged: (themeKey) {
        unawaited(_handleWidgetThemeChanged(themeKey));
      },
      options: swatches
          .map(
            (swatch) => WidgetStudioThemeOption(
              id: swatch.$1,
              label: swatch.$3,
              colors: swatch.$2,
              icon: _widgetThemeSwatchIcon(swatch.$1),
            ),
          )
          .toList(growable: false),
    );
  }
}
