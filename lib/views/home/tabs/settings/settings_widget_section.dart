// ignore_for_file: unused_local_variable, prefer_const_declarations
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
      ('Hồng ngọt', 'pink'),
      ('Tối hiện đại', 'dark'),
      ('Trắng tinh', 'white'),
      ('Xanh lam', 'blue'),
      ('Cam nắng', 'orange'),
      ('Tím mộng', 'purple'),
      ('Xanh ngọc', 'green'),
      ('Đỏ đậm', 'red'),
      (_isVipActive ? 'Aurora PRO' : 'Aurora PRO 🔒', 'premium'),
    ];
    final heartColorOptions = [
      ('Hồng rose', 'rose'),
      ('Đỏ ruby', 'ruby'),
      ('Tím violet', 'violet'),
      ('Xanh ocean', 'ocean'),
      ('Mint', 'mint'),
      ('Hoàng hôn', 'sunset'),
      ('Gold', 'gold'),
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
        ? 'Tự động phối màu'
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
      (WidgetService.defaultWidgetStyleKey, 'Mặc định', Icons.widgets_rounded),
      ('countdown', 'Đếm ngày', Icons.timer_outlined),
      (_widgetPanelTabIconKey, 'Nhận diện', Icons.favorite_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = _widgetPanelTabKey == item.$1;
          final isBrandMarkTab = item.$1 == _widgetPanelTabIconKey;

          return Expanded(
            child: GestureDetector(
              onTap: () => unawaited(_handleWidgetPanelTabChanged(item.$1)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF101828).withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isBrandMarkTab
                        ? ValueListenableBuilder<UiPrefsState>(
                            valueListenable: UiPrefs.notifier,
                            builder: (context, ui, _) => SoulLocketBrandMark(
                              styleKey: ui.brandMarkKey,
                              size: 18,
                            ),
                          )
                        : Icon(
                            item.$3,
                            size: 18,
                            color: isSelected
                                ? const Color(0xFF1F2A37)
                                : const Color(0xFF64748B),
                          ),
                    const SizedBox(height: 5),
                    Text(
                      item.$2,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? const Color(0xFF1F2A37)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildBrandMarkPicker() {
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      builder: (context, ui, _) {
        final selectedKey = SoulLocketBrand.normalizeStyleKey(ui.brandMarkKey);
        return _buildWidgetSectionCard(
          useBrandMarkIcon: true,
          title: 'Icon trong app',
          subtitle:
              'Đổi viền tim và tông màu cho nhận diện hiển thị bên trong app.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: SoulLocketBrand.styles.map((style) {
              final isSelected = selectedKey == style.key;
              return GestureDetector(
                onTap: () => unawaited(UiPrefs.setBrandMarkKey(style.key)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 104,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? style.backgroundColors.first.withOpacity(0.12)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? style.backgroundColors.last.withOpacity(0.9)
                          : const Color(0xFFE4ECF4),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SoulLocketBrandMark(
                        styleKey: style.key,
                        size: 54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        style.label,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 11.2,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF243041),
                          height: 1.2,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Color(0xFF16A34A),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildAppIconShowcase() {
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      builder: (context, ui, _) {
        final style = SoulLocketBrand.styleFor(ui.brandMarkKey);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                style.backgroundColors.first.withOpacity(0.16),
                style.backgroundColors.last.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5ECF4)),
          ),
          child: Column(
            children: [
              SoulLocketBrandMark(
                styleKey: style.key,
                size: 92,
              ),
              const SizedBox(height: 12),
              Text(
                style.label,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1F2A37),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nhận diện hiển thị trong app',
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetPanel({bool hideBackButton = false}) {
    final config = _buildWidgetPanelConfig();
    final themeOptions = [
      ('Hồng ngọt', 'pink'),
      ('Tối hiện đại', 'dark'),
      ('Trắng tinh', 'white'),
      ('Xanh lam', 'blue'),
      ('Cam nắng', 'orange'),
      ('Tím mộng', 'purple'),
      ('Xanh ngọc', 'green'),
      ('Đỏ đậm', 'red'),
      (_isVipActive ? 'Aurora PRO' : 'Aurora PRO 🔒', 'premium'),
    ];
    final heartColorOptions = [
      ('Hồng rose', 'rose'),
      ('Đỏ ruby', 'ruby'),
      ('Tím violet', 'violet'),
      ('Xanh ocean', 'ocean'),
      ('Mint', 'mint'),
      ('Hoàng hôn', 'sunset'),
      ('Gold', 'gold'),
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
        ? 'Tự động phối màu'
        : WidgetService.seasonLabel(smartSeasonKey);

    Future<void> handlePinWidget() async {
      if (kIsWeb) {
        _showToast('Widget Android không hỗ trợ trên Web');
        return;
      }
      try {
        final supported = await HomeWidget.isRequestPinWidgetSupported();
        if (!mounted) return;
        if (supported != true) {
          _showToast(context.tr('widget_err_not_supported'));
          return;
        }
        await _persistAndSyncWidgetAppearance();
        await WidgetService.requestPinWidget();
        if (!mounted) return;
        _showToast(context.tr('widget_pin_req_sent'), success: true);
      } catch (_) {
        if (!mounted) return;
        _showToast('Lỗi: Không thể ghim widget');
      }
    }

    Future<void> handleRefreshWidget() async {
      if (kIsWeb) {
        _showToast('Widget Android không hỗ trợ trên Web');
        return;
      }
      try {
        await _persistAndSyncWidgetAppearance();
        if (!mounted) return;
        _showToast(context.tr('widget_updated_success'), success: true);
      } catch (_) {
        if (!mounted) return;
        _showToast('Lỗi: Không thể cập nhật widget');
      }
    }

    return _buildPanel(
      hideBackButton: hideBackButton,
      id: 'widget',
      title: context.tr('widget_utility'),
      borderColor: const Color(0xFF80DEEA),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFEFF), Color(0xFFF6FAFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4EBF3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101828).withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Xem trước widget',
                  style: SLTheme.quicksand(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1F2A37),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _widgetPanelTabKey == _widgetPanelTabIconKey
                  ? _buildAppIconShowcase()
                  : _buildWidgetPreview(),
              const SizedBox(height: 14),
              _buildWidgetPanelTabBar(),
              const SizedBox(height: 12),
              if (_widgetPanelTabKey == _widgetPanelTabIconKey) ...[
                _buildBrandMarkPicker(),
                const SizedBox(height: 12),
              ],
              if (_widgetPanelTabKey != _widgetPanelTabIconKey)
                _buildWidgetSectionCard(
                  icon: Icons.palette_outlined,
                  title: context.tr('theme_widget_bg'),
                  subtitle: null,
                  iconGradient: const [
                    Color(0xFFFF9A9E),
                    Color(0xFFFECF6A),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThemeDropdownField(
                        value: _draftWidgetThemeKey ?? 'pink',
                        options: config.themeOptions,
                        onChanged: (value) async =>
                            _handleWidgetThemeChanged(value),
                      ),
                    ],
                  ),
                ),
              if (_widgetPanelTabKey != _widgetPanelTabIconKey &&
                  _widgetStyleKey == WidgetService.defaultWidgetStyleKey) ...[
                const SizedBox(height: 12),
                _buildWidgetSectionCard(
                  icon: Icons.favorite_rounded,
                  title: 'Trái tim và nội dung',
                  subtitle: null,
                  iconGradient: const [
                    Color(0xFFFF86A8),
                    Color(0xFFFF5B8A),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kiểu trái tim',
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
                        'Màu trái tim',
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
                      const SizedBox(height: 12),
                      _buildWidgetToggleTile(
                        icon: Icons.favorite_outline_rounded,
                        title: context.tr('widget_animated_heart'),
                        subtitle: null,
                        value: _widgetHeartAnimated,
                        accentColor: const Color(0xFFFF5B8A),
                        onChanged: _handleWidgetHeartAnimatedChanged,
                      ),
                    ],
                  ),
                ),
              ],
              if (_widgetPanelTabKey != _widgetPanelTabIconKey &&
                  _widgetStyleKey == 'countdown') ...[
                const SizedBox(height: 12),
                _buildWidgetSectionCard(
                  icon: Icons.timer_rounded,
                  title: 'Widget đếm ngày',
                  subtitle:
                      'Chế độ này ưu tiên số ngày ở giữa và ngày bắt đầu bên dưới.',
                  iconGradient: const [
                    Color(0xFFFFB84D),
                    Color(0xFFFF7A59),
                  ],
                  child: Text(
                    'Dang dung kieu: ${_widgetStyleLabel(_widgetStyleKey)}',
                    style: SLTheme.quicksand(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF475467),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              if (_widgetPanelTabKey != _widgetPanelTabIconKey)
                const SizedBox(height: 12),
              if (_widgetPanelTabKey != _widgetPanelTabIconKey)
                _buildWidgetSectionCard(
                  icon: Icons.add_to_home_screen_rounded,
                  title: context.tr('android_real_widget'),
                  subtitle: context.tr('add_widget_desc'),
                  iconGradient: const [
                    Color(0xFF14B8A6),
                    Color(0xFF06B6D4),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useColumn = constraints.maxWidth < 330;
                          if (useColumn) {
                            return Column(
                              children: [
                                _buildGradientBtn(
                                  label: context.tr('add_widget'),
                                  gradient: const [
                                    Color(0xFF10C8E6),
                                    Color(0xFF0E9EB0),
                                  ],
                                  onTap: handlePinWidget,
                                ),
                                const SizedBox(height: 10),
                                _buildGradientBtn(
                                  label: context.tr('update_widget'),
                                  gradient: const [
                                    Color(0xFFFF7898),
                                    Color(0xFFD81B60),
                                  ],
                                  onTap: handleRefreshWidget,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: _buildGradientBtn(
                                  label: context.tr('add_widget'),
                                  gradient: const [
                                    Color(0xFF10C8E6),
                                    Color(0xFF0E9EB0),
                                  ],
                                  onTap: handlePinWidget,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGradientBtn(
                                  label: context.tr('update_widget'),
                                  gradient: const [
                                    Color(0xFFFF7898),
                                    Color(0xFFD81B60),
                                  ],
                                  onTap: handleRefreshWidget,
                                ),
                              ),
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
                                  color:
                                      const Color(0xFF0EA5C6).withOpacity(0.12),
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
                                      context.tr('ios_widget'),
                                      style: SLTheme.quicksand(
                                        fontSize: 12.6,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0B7285),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('ios_widget_pending'),
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
        ),
      ),
    );
  }
}
