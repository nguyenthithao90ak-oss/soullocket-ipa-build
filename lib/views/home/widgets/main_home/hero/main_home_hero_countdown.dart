part of '../../../tabs/main_home_tab.dart';

class _MainHomeHeroCountdownSection extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final String? startDate;
  final double circleSize;
  final bool homeShowHouseName;
  final bool showDayCounter;
  final bool showLoveTimeDetail;
  final String countdownStyleKey;
  final bool enableMotion;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final GlobalKey? firstGuideHeroKey;

  const _MainHomeHeroCountdownSection({
    required this.state,
    required this.isSingle,
    required this.houseName,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    required this.startDate,
    required this.circleSize,
    required this.homeShowHouseName,
    required this.showDayCounter,
    required this.showLoveTimeDetail,
    required this.countdownStyleKey,
    required this.enableMotion,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.firstGuideHeroKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The large circle is permanently reserved for the relationship day
        // count. Only the compact time-detail row below may be toggled.
        if (showDayCounter) ...[
          _MainHomeHeroCountdownCircle(
            state: state,
            isSingle: isSingle,
            smartGreeting: smartGreeting,
            circleValue: circleValue,
            circleTopLabel: circleTopLabel,
            circleBottomLabel: circleBottomLabel,
            circleSize: circleSize,
            countdownStyleKey: countdownStyleKey,
            enableMotion: enableMotion,
            onEditStartDate: onEditStartDate,
            onEditTopLabel: onEditTopLabel,
            onEditBottomLabel: onEditBottomLabel,
            firstGuideHeroKey: firstGuideHeroKey,
          ),
          SLSpacing.h16,
        ],
        // `showLoveTimeDetail` means the 3-block hours/minutes/seconds strip.
        if (showLoveTimeDetail)
          _MainHomeHeroCounters(
            state: state,
            startDate: startDate,
          ),
        if (homeShowHouseName)
          _MainHomeHeroBadges(
            houseName: houseName,
          ),
      ],
    );
  }
}

class _MainHomeHeroCountdownCircle extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final double circleSize;
  final String countdownStyleKey;
  final bool enableMotion;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final GlobalKey? firstGuideHeroKey;

  const _MainHomeHeroCountdownCircle({
    required this.state,
    required this.isSingle,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    required this.circleSize,
    required this.countdownStyleKey,
    required this.enableMotion,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.firstGuideHeroKey,
  });

  @override
  Widget build(BuildContext context) {
    final transparentMode = UiPrefs.notifier.value.transparentMode;
    final countdownVisual =
        _CountdownVisualSpec.resolve(countdownStyleKey, transparentMode);
    final labelHeight = (circleSize * 0.15).clamp(38.0, 64.0).toDouble();
    final numberHeight = (circleSize * 0.38).clamp(80.0, 150.0).toDouble();
    final topLabelWidth = circleSize * 0.68;
    final bottomLabelWidth = circleSize * 0.64;
    final numberWidth = circleSize * 0.72;
    final topGap = (circleSize * 0.05).clamp(12.0, 20.0).toDouble();
    final bottomGap = (circleSize * 0.035).clamp(8.0, 16.0).toDouble();

    return KeyedSubtree(
      key: firstGuideHeroKey,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSingle
          ? null
          : () => state._showCountdownCircleHint(
                smartGreeting: smartGreeting,
              ),
      onLongPress: state._showCountdownQuickCustomizeSheet,
      child: _MainHomeHeroCountdownMotionShell(
        size: circleSize,
        styleKey: countdownStyleKey,
        highlightColors: countdownVisual.numberGradient,
        enableMotion: enableMotion,
        child: Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: countdownVisual.outerColor,
            gradient: countdownVisual.outerGradient,
            border: countdownVisual.outerBorder,
            boxShadow: countdownVisual.shadows,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: SLSpacing.all12,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: countdownVisual.innerColor,
                      gradient: countdownVisual.innerGradient,
                      border: countdownVisual.innerBorder,
                    ),
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: state._isScrollingNotifier,
                        builder: (context, isScrolling, child) {
                          return TickerMode(
                            enabled: enableMotion && !isScrolling,
                            child: child!,
                          );
                        },
                        child: _AnimatedWaveBackground(
                          styleKey: countdownStyleKey,
                          enableMotion: enableMotion,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (countdownStyleKey == 'floating_hearts')
                FloatingHeartsRingOverlay(size: circleSize),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: circleSize * 0.16),
                    child: _MainHomeHeroCountdownTapTarget(
                      circleSize: circleSize,
                      onTap: isSingle ? null : onEditTopLabel,
                      onLongPress: state._showCountdownQuickCustomizeSheet,
                      constraints: BoxConstraints(
                        minWidth: topLabelWidth,
                        maxWidth: topLabelWidth,
                        minHeight: labelHeight,
                        maxHeight: labelHeight,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          circleTopLabel,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: state._uiTextStyle(
                            fontSize: (circleSize * 0.075).clamp(16.0, 22.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: countdownVisual.topLabelColor,
                          ).copyWith(
                            shadows: countdownVisual.labelShadows,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: topGap),
                  _MainHomeHeroCountdownTapTarget(
                    circleSize: circleSize,
                    onTap: isSingle ? null : onEditStartDate,
                    onLongPress: state._showCountdownQuickCustomizeSheet,
                    constraints: BoxConstraints(
                      minWidth: numberWidth,
                      maxWidth: numberWidth,
                      minHeight: numberHeight,
                      maxHeight: numberHeight,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shadow Layer (No ShaderMask to prevent blurriness)
                          Text(
                            circleValue,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: state._uiTextStyle(
                              fontSize: (circleSize * 0.36).clamp(56.0, 132.0),
                              fontWeight: FontWeight.w900,
                              color: Colors.transparent, // Only show shadow
                              height: 0.96,
                              letterSpacing: 4.0,
                            ).copyWith(
                              shadows: countdownVisual.numberShadows,
                            ),
                          ),
                          // Gradient Layer with ShaderMask
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: countdownVisual.numberGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              circleValue,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: state._uiTextStyle(
                                fontSize: (circleSize * 0.36).clamp(56.0, 132.0),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 0.96,
                                letterSpacing: 4.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: bottomGap),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: circleSize * 0.18),
                    child: _MainHomeHeroCountdownTapTarget(
                      circleSize: circleSize,
                      onTap: isSingle ? null : onEditBottomLabel,
                      onLongPress: state._showCountdownQuickCustomizeSheet,
                      constraints: BoxConstraints(
                        minWidth: bottomLabelWidth,
                        maxWidth: bottomLabelWidth,
                        minHeight: labelHeight,
                        maxHeight: labelHeight,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          circleBottomLabel,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: state._uiTextStyle(
                            fontSize: (circleSize * 0.082).clamp(17.0, 24.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: countdownVisual.bottomLabelColor,
                          ).copyWith(
                            shadows: countdownVisual.labelShadows,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _MainHomeHeroCountdownMotionShell extends StatelessWidget {
  final double size;
  final String styleKey;
  final List<Color> highlightColors;
  final bool enableMotion;
  final Widget child;

  const _MainHomeHeroCountdownMotionShell({
    required this.size,
    required this.styleKey,
    required this.highlightColors,
    required this.enableMotion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _MainHomeHeroCountdownTapTarget extends StatelessWidget {
  final double circleSize;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BoxConstraints? constraints;

  const _MainHomeHeroCountdownTapTarget({
    required this.circleSize,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.constraints,
  });

  double _countdownTapWidth(double circleSize) =>
      (circleSize * 0.56).clamp(132.0, 240.0);

  double _countdownTapHeight(double circleSize) =>
      (circleSize * 0.16).clamp(46.0, 72.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: constraints ??
            BoxConstraints(
              minWidth: _countdownTapWidth(circleSize),
              minHeight: _countdownTapHeight(circleSize),
            ),
        child: Center(child: child),
      ),
    );
  }
}
