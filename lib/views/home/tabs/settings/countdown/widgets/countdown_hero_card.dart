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
        constraints.maxWidth - 34,
        _countdownSizePx,
      );
      final value = _anchorDate == null
          ? '--'
          : _daysSince(_anchorDate!).toString();
      return Theme(
        data: Theme.of(context).copyWith(
          brightness: themeData.isDark ? Brightness.dark : Brightness.light,
        ),
        child: Column(
          children: [
            // Dựng ở cỡ thật để giữ vùng chạm 48dp và hỗ trợ chữ hệ thống lớn.
            _CountdownModeCircle(
              size: size,
              value: value,
              topLabel: _topLabel(),
              bottomLabel: _bottomLabel(),
              styleData: styleData,
              fontKey: _fontKey,
              styleKey: _countdownStyleKey,
              countdownShapeKey: UiPrefs.notifier.value.countdownShapeKey,
              transparentMode: _transparentMode,
              enableMotion: !UiPrefs.notifier.value.liteMode,
              onTopTap: () => _editCountdownLabel(editTopLabel: true),
              onValueTap: _pickAnchorDate,
              onBottomTap: () => _editCountdownLabel(editTopLabel: false),
            ),
            if (_anchorDate != null) ...[
              const SizedBox(height: 18),
              _buildLoveTimeCounters(),
            ],
          ],
        ),
      );
    },
  );
}
