// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension LabelsEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorLabels(
    BuildContext context,
    _CountdownModeThemeData themeData,
  ) => [
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeData.isDark
              ? [
                  Colors.white.withValues(alpha: .12),
                  Colors.white.withValues(alpha: .06),
                ]
              : [
                  Colors.white.withValues(alpha: .88),
                  Colors.white.withValues(alpha: .64),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: themeData.isDark
              ? Colors.white.withValues(alpha: .18)
              : Colors.white.withValues(alpha: .92),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: themeData.isDark ? .18 : .05),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = privateSpaceDialSize(
            constraints.maxWidth - 12,
            (_sizePx * .8).clamp(200.0, 304.0),
          );
          final value = _anchorDate == null
              ? '--'
              : _daysSince(_anchorDate!).toString();
          return Theme(
            data: Theme.of(context).copyWith(
              brightness: themeData.isDark ? Brightness.dark : Brightness.light,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('home_xemtrckhng_138945'),
                  style: SLTheme.textStyleForKey(
                    _fontKey,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: themeData.foreground.withValues(alpha: .68),
                  ),
                ),
                const SizedBox(height: 8),
                _CountdownModeCircle(
                  size: size,
                  value: value,
                  topLabel: _previewTopLabel(),
                  bottomLabel: _previewBottomLabel(),
                  styleData: _CountdownModeStyleData.resolve(
                    _styleKey,
                    _transparentMode,
                  ),
                  fontKey: _fontKey,
                  styleKey: _styleKey,
                  countdownShapeKey: UiPrefs.notifier.value.countdownShapeKey,
                  transparentMode: _transparentMode,
                  enableMotion: false,
                ),
              ],
            ),
          );
        },
      ),
    ),
    _CountdownModeAvatarCardStatic(
      isSingleMode: _singleMode,
      leftName: _leftCtrl.text.trim(),
      rightName: _rightCtrl.text.trim(),
      leftAvatarUrl: _leftAvatarCtrl.text.trim(),
      rightAvatarUrl: _rightAvatarCtrl.text.trim(),
      avatarFrameKey: _frameKey,
      fontKey: _fontKey,
      foreground: themeData.foreground,
      isDark: themeData.isDark,
      centerIconType: _centerIconType,
    ),
    const SizedBox(height: 22),
  ];
}
