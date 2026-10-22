// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension StylesEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorStyles(
    BuildContext context,
    _CountdownModeThemeData themeData,
  ) {
    final palette = SLSettingsPalette.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    final onAccent = palette.isDark ? palette.canvas : Colors.white;
    return [
      _sectionCard(
        icon: Icons.event_available_rounded,
        title: context.tr('p7_countdown_time_style_title'),
        subtitle: context.tr('p7_countdown_time_style_subtitle'),
        iconGradient: const [Color(0xFF14B8A6), Color(0xFF06B6D4)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  selected: _singleMode,
                  label: Text(context.tr('home_cnhn_9d6cf4')),
                  labelStyle: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: _singleMode ? onAccent : palette.inkSecondary,
                  ),
                  selectedColor: palette.accent,
                  checkmarkColor: onAccent,
                  onSelected: (_) => _safeSetState(() => _singleMode = true),
                ),
                ChoiceChip(
                  selected: !_singleMode,
                  label: Text(context.tr('home_cpi_d525b0')),
                  labelStyle: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: !_singleMode ? onAccent : palette.inkSecondary,
                  ),
                  selectedColor: palette.accent,
                  checkmarkColor: onAccent,
                  onSelected: (_) => _safeSetState(() => _singleMode = false),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(context.tr('countdown_today')),
                  onPressed: () {
                    final now = DateTime.now();
                    _safeSetState(() {
                      _anchorDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                ActionChip(
                  label: Text(context.tr('countdown_default_love_date')),
                  onPressed: () {
                    final parsed = DateInputUtils.parse(
                      widget.anchorDate == null
                          ? ''
                          : DateInputUtils.formatIsoDate(widget.anchorDate!),
                    );
                    if (parsed == null) return;
                    _safeSetState(() {
                      _anchorDate = DateTime(
                        parsed.year,
                        parsed.month,
                        parsed.day,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('home_ngymchinti_2f583e'),
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: palette.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _anchorDate == null
                            ? context.tr('home_chachn_cf29c8')
                            : DateInputUtils.formatDisplayDate(_anchorDate!),
                        style: SLTheme.quicksand(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickAnchorDate,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(context.tr('home_chnngy_d2cce5')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];
  }
}
