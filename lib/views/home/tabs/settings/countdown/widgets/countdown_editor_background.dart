// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension BackgroundEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorBackground(
    BuildContext context,
    _CountdownModeThemeData themeData,
  ) {
    return [
      _sectionCard(
        icon: Icons.palette_rounded,
        title: L10nService().translate('home_giaodinvng_2311dc'),
        subtitle: context.tr('home_kiuhinthny_15f695'),
        iconGradient: const [Color(0xFFFF9A9E), Color(0xFFFECF6A)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('home_ch_f5d6a5'),
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8A5B76),
              ),
            ),
            const SizedBox(height: 10),
            _buildCountdownThemeSwatchGrid(),
            const SizedBox(height: 16),
            _CountdownModeSheetDropdown(
              label: _isUnlockingCountdownStyle
                  ? context.tr('home_angmkhakiu_38c380')
                  : context.tr('home_kiuvngm_96b8db'),
              value: _styleKey,
              options: _CountdownModeEditorScreenState._countdownStyleOptions
                  .map((entry) {
                    final locked =
                        !widget.isVipActive &&
                        _CountdownModeIndependentScreenState._isPremiumCountdownStyleKey(
                          entry.value,
                        ) &&
                        !_unlockedStyles.contains(entry.value);
                    return MapEntry(
                      locked
                          ? '${entry.key} • ${context.tr('p7_ad_label')}'
                          : entry.key,
                      entry.value,
                    );
                  })
                  .toList(growable: false),
              onChanged: (value) =>
                  unawaited(_handleCountdownStyleSelection(value)),
            ),
            const SizedBox(height: 12),
            _CountdownModeSheetDropdown(
              label: context.tr('p7_avatar_frame'),
              value: _frameKey,
              options: _CountdownModeEditorScreenState._avatarFrameOptions,
              onChanged: (value) => _safeSetState(() => _frameKey = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fontKey,
              isExpanded: true,
              dropdownColor: const Color(0xFF162136),
              iconEnabledColor: Colors.white70,
              decoration: _fieldDecoration(
                label: context.tr('home_phngch_9b3aa7'),
                dark: true,
              ),
              style: SLTheme.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              items: SLTheme.cleanFontOptions
                  .map(
                    (font) => DropdownMenuItem<String>(
                      value: font.key,
                      child: Text(
                        font.label,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _safeSetState(() => _fontKey = value);
                }
              },
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              value: _transparentMode,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: const Color(0xFFD81B60),
              title: Text(
                context.tr('home_knhm_33b8ab'),
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243041),
                ),
              ),
              subtitle: Text(
                context.tr('home_gicmgictro_a2b87f'),
                style: SLTheme.quicksand(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7C6D76),
                ),
              ),
              onChanged: (value) =>
                  _safeSetState(() => _transparentMode = value),
            ),
            const SizedBox(height: 6),
            StatefulBuilder(
              builder: (context, setStateSlider) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context
                          .tr('p7_countdown_size_label')
                          .replaceAll('{size}', _sizePx.round().toString()),
                      style: SLTheme.quicksand(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8A5B76),
                      ),
                    ),
                    Slider(
                      min: 200,
                      max: UiPrefs.maxCountdownSizePx,
                      activeColor: const Color(0xFFD81B60),
                      inactiveColor: const Color(0xFFF2C3D7),
                      value: _sizePx.clamp(200.0, UiPrefs.maxCountdownSizePx),
                      onChanged: (value) {
                        setStateSlider(() {
                          _sizePx = value;
                        });
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_buildResult(_CountdownModeSettingsAction.save)),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          context.tr('p7_save_countdown_size'),
                          style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
    ];
  }
}
