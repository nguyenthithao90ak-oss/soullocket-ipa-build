// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension CountdownHeroCardExt on _CountdownModeIndependentScreenState {
  Widget _buildHeroCard(
    BuildContext context,
    _CountdownModeThemeData themeData,
    _CountdownModeStyleData styleData,
    BoxConstraints viewportConstraints,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final size = privateSpaceDialSize(
        constraints.maxWidth - 16,
        _countdownSizePx,
      );
      final value = _anchorDate == null
          ? '--'
          : _daysSince(_anchorDate!).toString();
      final basic = {
        'default',
        'plain',
        'rose_wave',
        '',
      }.contains(_countdownStyleKey);
      return Column(
        children: [
          if (basic)
            PrivateSpaceDial(
              value: value,
              topLabel: _topLabel(),
              bottomLabel: _bottomLabel(),
              size: size,
              dark: themeData.isDark,
              fontKey: _fontKey,
              transparent: _transparentMode,
              onTop: () => _editCountdownLabel(editTopLabel: true),
              onBottom: () => _editCountdownLabel(editTopLabel: false),
              onDate: _pickAnchorDate,
            )
          else
            SizedBox(
              width: size,
              height: size,
              child: FittedBox(
                child: MediaQuery.withNoTextScaling(
                  child: _CountdownModeCircle(
                    size: 320,
                    value: value,
                    topLabel: _topLabel(),
                    bottomLabel: _bottomLabel(),
                    styleData: styleData,
                    fontKey: _fontKey,
                    styleKey: _countdownStyleKey,
                    countdownShapeKey: UiPrefs.notifier.value.countdownShapeKey,
                    transparentMode: _transparentMode,
                    enableMotion: !MediaQuery.disableAnimationsOf(context),
                    onTopTap: () => _editCountdownLabel(editTopLabel: true),
                    onValueTap: _pickAnchorDate,
                    onBottomTap: () => _editCountdownLabel(editTopLabel: false),
                  ),
                ),
              ),
            ),
          if (_anchorDate != null) ...[
            const SizedBox(height: 18),
            _buildLoveTimeCounters(),
          ],
        ],
      );
    },
  );
}
