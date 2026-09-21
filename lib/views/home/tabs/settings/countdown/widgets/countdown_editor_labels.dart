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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppearancePanelStyle.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppearancePanelStyle.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
        final size = privateSpaceDialSize(constraints.maxWidth, _sizePx * .6);
          final value = _anchorDate == null
              ? '--'
              : _daysSince(_anchorDate!).toString();
          if ({'default', 'plain', 'rose_wave', ''}.contains(_styleKey)) {
            return PrivateSpaceDial(
              value: value,
              topLabel: _previewTopLabel(),
              bottomLabel: _previewBottomLabel(),
              size: size,
              fontKey: _fontKey,
              transparent: _transparentMode,
            );
          }
          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: FittedBox(
                child: MediaQuery.withNoTextScaling(
                  child: _CountdownModeCircle(
                    size: 320,
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
                ),
              ),
            ),
          );
        },
      ),
    ),
  ];
}
