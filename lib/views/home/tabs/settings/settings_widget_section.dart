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
      ('Xanh lam', 'blue'),
      (context.tr('home_camnng_da76a5'), 'orange'),
      (context.tr('home_tmmng_9db47d'), 'purple'),
      (context.tr('home_xanhngc_49b55b'), 'green'),
      (context.tr('home_m_720483'), 'red'),
      if (AppConfig.isPurchaseEnabled) ...[
        ('Aurora', 'premium'),
        ('Vũ trụ', 'cosmic'),
      ],
    ];
    final heartColorOptions = [
      (context.tr('home_hngrose_ee75eb'), 'rose'),
      (context.tr('home_ruby_cb8e85'), 'ruby'),
      (context.tr('home_tmviolet_19bc69'), 'violet'),
      ('Xanh ocean', 'ocean'),
      (context.tr('home_honghn_ab7dad'), 'sunset'),
      ('Gold', 'gold'),
      ('Tắt / Trong suốt', 'none'),
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
          orElse: () => ('Pink', 'pink'),
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
    final items = <(String, String, IconData)>[
      (
        WidgetService.defaultWidgetStyleKey,
        context.tr('home_mcnh_a57a8e'),
        Icons.widgets_rounded,
      ),
      ('countdown', context.tr('home_mngy_5500cb'), Icons.timer_outlined),
      (
        'soulevent',
        L10nService().translate('Kỷ niệm'),
        Icons.celebration_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SLColors.bgMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SLColors.border, width: 1),
      ),
      child: Row(
        children: items
            .map((item) {
              final isSelected = _widgetPanelTabKey == item.$1;

              return Expanded(
                child: GestureDetector(
                  onTap: () => unawaited(_handleWidgetPanelTabChanged(item.$1)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [SLColors.primary, SLColors.accentPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: SLColors.primary.withValues(alpha: 0.26),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: SLColors.accentPink.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : const [],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Decorative sparkle for selected tab
                        if (isSelected)
                          Positioned(
                            top: -2,
                            right: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.$3,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : SLColors.textSecond,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.$2,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 11.8,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : SLColors.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildWidgetPanel({bool hideBackButton = false}) {
    final config = _buildWidgetPanelConfig();
    final themeOptions = [
      (context.tr('home_hngngt_6a8c4a'), 'pink'),
      (context.tr('home_tihini_18f563'), 'dark'),
      (context.tr('home_trngtinh_2fff95'), 'white'),
      ('Xanh lam', 'blue'),
      (context.tr('home_camnng_da76a5'), 'orange'),
      (context.tr('home_tmmng_9db47d'), 'purple'),
      (context.tr('home_xanhngc_49b55b'), 'green'),
      (context.tr('home_m_720483'), 'red'),
      if (AppConfig.isPurchaseEnabled) ...[
        ('Aurora', 'premium'),
        ('Vũ trụ', 'cosmic'),
      ],
    ];
    final heartColorOptions = [
      (context.tr('home_hngrose_ee75eb'), 'rose'),
      (context.tr('home_ruby_cb8e85'), 'ruby'),
      (context.tr('home_tmviolet_19bc69'), 'violet'),
      ('Xanh ocean', 'ocean'),
      (context.tr('home_honghn_ab7dad'), 'sunset'),
      ('Gold', 'gold'),
      ('Tắt / Trong suốt', 'none'),
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
          orElse: () => ('Pink', 'pink'),
        )
        .$1;
    final smartSeasonLabel = smartSeasonKey == 'none'
        ? context.tr('home_tngphimu_c549ba')
        : WidgetService.seasonLabel(smartSeasonKey);

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

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'widget',
      title: context.tr('widget_utility'),
      borderColor: const Color(0xFF80DEEA),
      flatMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              context.tr('home_xemtrcwidg_189f43'),
              style: SLTheme.quicksand(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1F2A37),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildWidgetPreview(),
          const SizedBox(height: 14),
          if (Theme.of(context).platform != TargetPlatform.iOS) ...[
            _buildWidgetPanelTabBar(),
            const SizedBox(height: 14),
          ],
          if (_widgetPanelTabKey == 'soulevent') ...[
            _buildWidgetSectionCard(
              icon: Icons.info_outline_rounded,
              title: L10nService().translate('Cấu hình Sự kiện'),
              subtitle: null,
              iconGradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  L10nService().translate(
                    'Màu sắc và chủ đề của Tiện ích được lấy trực tiếp từ sự kiện bạn chọn ghim hoặc sự kiện gần nhất trong danh sách Sự Kiện & Kỷ Niệm.',
                  ),
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
              title: L10nService().translate('Tiện ích Sự kiện & Kỷ niệm'),
              subtitle: L10nService().translate(
                'Đếm ngược các sự kiện quan trọng của 2 bạn',
              ),
              iconGradient: const [Color(0xFFF472B6), Color(0xFFEC4899)],
              child: Text(
                L10nService().translate(
                  'Hiển thị sự kiện tiếp theo (ví dụ: ngày sinh nhật, chuyến đi, ngày kỷ niệm yêu...) trực tiếp trên màn hình chính.',
                ),
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

  /// Decorative emoji accent for each widget theme swatch.
  String _widgetThemeSwatchEmoji(String key) {
    switch (key) {
      case 'pink':
        return '🌸';
      case 'white':
        return '❄️';
      case 'dark':
        return '🌙';
      case 'blue':
        return '🌊';
      case 'orange':
        return '🌅';
      case 'purple':
        return '✨';
      case 'green':
        return '🍀';
      case 'red':
        return '🔥';
      case 'premium':
        return '💎';
      case 'cosmic':
        return '🌌';
      default:
        return '🎨';
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
            .firstWhere((o) => o.$2 == 'pink', orElse: () => ('Hồng', 'pink'))
            .$1,
      ),
      (
        'white',
        [const Color(0xFFF8F8F8), const Color(0xFFE8EDF5)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'white',
              orElse: () => ('Trắng', 'white'),
            )
            .$1,
      ),
      (
        'dark',
        [const Color(0xFF3A3A4A), const Color(0xFF1C1C2E)],
        config.themeOptions
            .firstWhere((o) => o.$2 == 'dark', orElse: () => ('Tối', 'dark'))
            .$1,
      ),
      (
        'blue',
        [const Color(0xFF90CAF9), const Color(0xFF1565C0)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'blue',
              orElse: () => ('Xanh lam', 'blue'),
            )
            .$1,
      ),
      (
        'orange',
        [const Color(0xFFFFCC80), const Color(0xFFEF6C00)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'orange',
              orElse: () => ('Cam', 'orange'),
            )
            .$1,
      ),
      (
        'purple',
        [const Color(0xFFCE93D8), const Color(0xFF6A1B9A)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'purple',
              orElse: () => ('Tím', 'purple'),
            )
            .$1,
      ),
      (
        'green',
        [const Color(0xFFA5D6A7), const Color(0xFF2E7D32)],
        config.themeOptions
            .firstWhere(
              (o) => o.$2 == 'green',
              orElse: () => ('Xanh lá', 'green'),
            )
            .$1,
      ),
      (
        'red',
        [const Color(0xFFEF9A9A), const Color(0xFFB71C1C)],
        config.themeOptions
            .firstWhere((o) => o.$2 == 'red', orElse: () => ('Đỏ', 'red'))
            .$1,
      ),
      if (AppConfig.isPurchaseEnabled) ...[
        (
          'premium',
          [const Color(0xFFFBC2EB), const Color(0xFFA6C1EE)],
          config.themeOptions
              .firstWhere(
                (o) => o.$2 == 'premium',
                orElse: () => ('Aurora', 'premium'),
              )
              .$1,
        ),
        (
          'cosmic',
          [const Color(0xFF0F0C20), const Color(0xFFFFD700)],
          config.themeOptions
              .firstWhere(
                (o) => o.$2 == 'cosmic',
                orElse: () => ('Vũ trụ', 'cosmic'),
              )
              .$1,
        ),
      ],
    ];

    final currentKey = _draftWidgetThemeKey ?? 'pink';

    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: swatches.map((swatch) {
        final key = swatch.$1;
        final colors = swatch.$2;
        final label = swatch.$3;
        final isSelected = currentKey == key;
        final themeIcon = _widgetThemeSwatchIcon(key);
        final themeEmoji = _widgetThemeSwatchEmoji(key);
        final isDarkTheme = key == 'dark';
        final iconColor = isDarkTheme
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.85);

        return GestureDetector(
          onTap: () async => _handleWidgetThemeChanged(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? colors.last.withValues(alpha: 0.90)
                    : const Color(0xFFE0E7EF),
                width: isSelected ? 2.2 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.38),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color preview area with decorative icon + emoji
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.first,
                          Color.lerp(colors.first, colors.last, 0.5)!,
                          colors.last,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Subtle decorative pattern overlay
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Icon(
                            themeIcon,
                            size: 28,
                            color: isDarkTheme
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                        // Bottom-left small decorative dot
                        Positioned(
                          bottom: 4,
                          left: 6,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        // White curved wave overlay for normal swatches
                        if (key != 'premium' && key != 'cosmic')
                          Positioned(
                            bottom: -22,
                            left: -10,
                            right: -10,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.elliptical(50, 15),
                                ),
                              ),
                            ),
                          ),
                        // Center content
                        Center(
                          child: isSelected
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.last.withValues(
                                              alpha: 0.30,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: colors.last,
                                      ),
                                    ),
                                  ],
                                )
                              : Icon(themeIcon, size: 20, color: iconColor),
                        ),
                        // Shimmer dot for selected state
                        if (isSelected)
                          Positioned(
                            top: 5,
                            left: 6,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.90),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Label area with emoji + gradient tint
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [
                                colors.first.withValues(alpha: 0.08),
                                Colors.white,
                              ]
                            : [Colors.white, Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Text(themeEmoji, style: const TextStyle(fontSize: 9)),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 10.4,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: isSelected
                                  ? colors.last
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
