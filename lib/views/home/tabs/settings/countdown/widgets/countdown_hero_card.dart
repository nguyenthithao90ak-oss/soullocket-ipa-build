// ignore_for_file: library_private_types_in_public_api, dead_code
part of '../../../settings_tab.dart';

extension CountdownHeroCardExt on _CountdownModeIndependentScreenState {
  Widget _buildHeroCard(
    BuildContext context,
    _CountdownModeThemeData themeData,
    _CountdownModeStyleData styleData,
    BoxConstraints viewportConstraints,
  ) {
    final responsiveCircleMax = (viewportConstraints.maxWidth - 44)
        .clamp(280.0, UiPrefs.maxCountdownSizePx);
    final circleSize = (_countdownSizePx < responsiveCircleMax
            ? _countdownSizePx
            : responsiveCircleMax)
        .clamp(280.0, UiPrefs.maxCountdownSizePx)
        .roundToDouble();
    final value =
        _anchorDate == null ? '--' : _daysSince(_anchorDate!).toString();
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);
    final isAccepted = _acceptedSpaceHouseIds
        .contains(_openedSpaceHouseId ?? _selfSpaceHouseId);
    final statusColor =
        isAccepted ? const Color(0xFF4BA7FF) : const Color(0xFFFFB74D);

    return Column(
      children: [
        if (false)
          Text(
            _spaceTitle(_openedSpaceHouseId ?? _selfSpaceHouseId),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
        if (false) const SizedBox(height: 8),
        if (false)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.22)),
            ),
            child: Text(
              isAccepted
                  ? context.tr('home_ghpni_369328')
                  : context.tr('home_chghpni_0a2955'),
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
        const SizedBox(height: 18),
        Column(
          children: [
            Center(
              child: SizedBox(
                width: circleSize,
                height: circleSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _CountdownModeCircle(
                      size: circleSize,
                      value: value,
                      topLabel: _topLabel(),
                      bottomLabel: _bottomLabel(),
                      styleData: styleData,
                      fontKey: _fontKey,
                      styleKey: _countdownStyleKey,
                      transparentMode: _transparentMode,
                      enableMotion: true,
                      onTopTap: () => _editCountdownLabel(
                        editTopLabel: true,
                      ),
                      onValueTap: _pickAnchorDate,
                      onBottomTap: () => _editCountdownLabel(
                        editTopLabel: false,
                      ),
                    ),
                    if (_countdownStyleKey == 'floating_hearts')
                      FloatingHeartsRingOverlay(size: circleSize),
                  ],
                ),
              ),
            ),
            if (_anchorDate != null) const SizedBox(height: 16),
            if (_anchorDate != null) _buildLoveTimeCounters(),
          ],
        ),
        if (false) const SizedBox(height: 16),
        if (false)
          Text(
            _caption(context),
            textAlign: TextAlign.center,
            style: SLTheme.textStyleForKey(
              _fontKey,
              color: subtitleColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        if (false) const SizedBox(height: 10),
        if (false)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: themeData.isDark ? 0.08 : 0.56),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white
                    .withValues(alpha: themeData.isDark ? 0.10 : 0.86),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_calendar_rounded,
                  size: 16,
                  color: Color(0xFFD94C86),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.tr('home_chmvovngms_d76e82'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  
}
