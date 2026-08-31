part of '../../tabs/main_home_tab.dart';

class _ModernHomeBody extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final String? startDate;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final double circleSize;
  final bool homeShowHouseName;
  final String customBackgroundUrl;
  final bool showDayCounter;
  final bool showLoveTimeDetail;
  final String countdownShapeKey;
  final String countdownStyleKey;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final VoidCallback? onOpenSettings;

  const _ModernHomeBody({
    required this.state,
    required this.isSingle,
    required this.houseName,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    this.startDate,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    required this.circleSize,
    required this.homeShowHouseName,
    required this.customBackgroundUrl,
    required this.showDayCounter,
    required this.showLoveTimeDetail,
    required this.countdownShapeKey,
    required this.countdownStyleKey,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final uiState = UiPrefs.notifier.value;
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: uiState,
      isWeb: kIsWeb,
    );

    // Fullscreen layout mode
    if (uiState.homeLayoutKey == 'fullscreen') {
      return _FullscreenHomeBody(
        state: state,
        isSingle: isSingle,
        houseName: houseName,
        showHouseName: homeShowHouseName,
        circleValue: circleValue,
        circleTopLabel: circleTopLabel,
        circleBottomLabel: circleBottomLabel,
        nameU1: nameU1,
        nameU2: nameU2,
        avtUser1: avtUser1,
        avtUser2: avtUser2,
        onOpenSettings: onOpenSettings,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _HomeScrapbookBackdrop(
            hasCustomBackground: customBackgroundUrl.trim().isNotEmpty,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
              constraints.maxWidth,
              compactPadding: 13,
              handsetPadding: 17,
              tabletPadding: 28,
            );
            final contentWidth = SLResponsive.maxContentWidthForWidth(
              constraints.maxWidth,
              handsetMax: 540,
              tabletMax: 700,
              desktopMax: 760,
            );
            final availableContentWidth = min(
              contentWidth,
              max(0, constraints.maxWidth - (horizontalPadding * 2)),
            );
            final responsiveCircleSize = min(
              circleSize,
              max(200, availableContentWidth - 4),
            ).toDouble();
            Widget buildCountdown(bool isSwiping) {
              final int currentDays = int.tryParse(circleValue) ?? 0;
              final bool isMilestone =
                  currentDays > 0 &&
                  (currentDays % 100 == 0 ||
                      currentDays % 30 == 0 ||
                      currentDays % 365 == 0);
              final bool enableMotionBase =
                  effectProfile.animationEnabled &&
                  !state._deferHeavyHomeMotion &&
                  !isSwiping;

              final countdown = RepaintBoundary(
                child: _MainHomeHeroCountdownSection(
                  state: state,
                  isSingle: isSingle,
                  houseName: houseName,
                  smartGreeting: smartGreeting,
                  circleValue: circleValue,
                  circleTopLabel: circleTopLabel,
                  circleBottomLabel: circleBottomLabel,
                  startDate: startDate,
                  circleSize: responsiveCircleSize,
                  homeShowHouseName: homeShowHouseName,
                  showDayCounter: showDayCounter,
                  showLoveTimeDetail: showLoveTimeDetail,
                  countdownShapeKey: countdownShapeKey,
                  countdownStyleKey: countdownStyleKey,
                  isMilestone: isMilestone,
                  enableMotionBase: enableMotionBase,
                  isScrollingNotifier: state._isScrollingNotifier,
                  onEditStartDate: onEditStartDate,
                  onEditTopLabel: onEditTopLabel,
                  onEditBottomLabel: onEditBottomLabel,
                  firstGuideHeroKey: state.widget.firstGuideHeroKey,
                ),
              );
              if (!showDayCounter) return countdown;
              return _HomeHeroStage(isSingle: isSingle, child: countdown);
            }

            Widget buildInsight(bool isSwiping) {
              final bool enableMotionBase =
                  effectProfile.animationEnabled &&
                  !state._deferHeavyHomeMotion &&
                  !isSwiping;

              return RepaintBoundary(
                child: state._buildModernInsightCard(
                  isSingle: isSingle,
                  nameU1: nameU1,
                  nameU2: nameU2,
                  enableMotion: enableMotionBase,
                ),
              );
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  state._isScrollingNotifier.value = true;
                  globalScrollingNotifier.value = true;
                } else if (notification is ScrollEndNotification) {
                  state._isScrollingNotifier.value = false;
                  globalScrollingNotifier.value = false;
                }
                return false;
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: MediaQuery.paddingOf(context).top + 62,
                        ),
                        _HomeStoryLetterhead(
                          smartGreeting: smartGreeting,
                          houseName: houseName,
                          showHouseName: homeShowHouseName,
                          isSingle: isSingle,
                        ),
                        SLSpacing.h24,
                        state.widget.isSwipingListenable == null
                            ? buildCountdown(false)
                            : ValueListenableBuilder<bool>(
                                valueListenable:
                                    state.widget.isSwipingListenable!,
                                builder: (context, isSwiping, _) =>
                                    buildCountdown(isSwiping),
                              ),
                        SLSpacing.h12,
                        RepaintBoundary(
                          child: state._buildModernAvatarSection(
                            isSingle: isSingle,
                            nameU1: nameU1,
                            nameU2: nameU2,
                            avtUser1: avtUser1,
                            avtUser2: avtUser2,
                          ),
                        ),
                        SLSpacing.h12,
                        // Removed manual sleep mode button
                        // state._buildSleepModeButton(),
                        // SLSpacing.h12,
                        RepaintBoundary(
                          child: _ChatReminderBanner(
                            state: state,
                            isSingle: isSingle,
                          ),
                        ),
                        if (state._pinnedApps.isNotEmpty) ...[
                          const _HomeScrapbookDivider(
                            color: SLColors.secondary,
                          ),
                          RepaintBoundary(
                            child: state._buildShortcutDock(state._pinnedApps),
                          ),
                        ],
                        if (!isSingle) ...[
                          const _HomeScrapbookDivider(),
                          RepaintBoundary(
                            child: state._buildModernHighlightCard(
                              startDate: startDate,
                              isSingle: isSingle,
                            ),
                          ),
                        ],
                        if (!isSingle) ...[
                          const _HomeScrapbookDivider(
                            color: SLColors.secondary,
                          ),
                          RepaintBoundary(
                            child: state._buildModernMapCard(
                              nameU1: nameU1,
                              nameU2: nameU2,
                            ),
                          ),
                        ],
                        const _HomeScrapbookDivider(
                          color: SLColors.accentPurple,
                        ),
                        state.widget.isSwipingListenable == null
                            ? buildInsight(false)
                            : ValueListenableBuilder<bool>(
                                valueListenable:
                                    state.widget.isSwipingListenable!,
                                builder: (context, isSwiping, _) =>
                                    buildInsight(isSwiping),
                              ),
                        RepaintBoundary(
                          child: state._buildHomeToolSlotSection(),
                        ),
                        SLSpacing.gapH(86),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        _MainHomeHeroHeader(
          state: state,
          isSingle: isSingle,
          onOpenSettings: onOpenSettings,
          firstGuideSettingsKey: state.widget.firstGuideSettingsKey,
        ),
      ],
    );
  }
}

extension _MainHomeTabHeroSection on _MainHomeTabState {}

class _ChatReminderBanner extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;

  const _ChatReminderBanner({required this.state, required this.isSingle});

  @override
  Widget build(BuildContext context) {
    if (isSingle) return const SizedBox.shrink();
    final ts = state._lastChatMessageTs;
    if (ts <= 0) return const SizedBox.shrink();
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - ts;
    const oneDayMs = 86400000;
    const threeDaysMs = 259200000;
    if (diffMs < oneDayMs || diffMs > threeDaysMs) {
      return const SizedBox.shrink();
    }

    final days = (diffMs / oneDayMs).floor();
    final label = days == 1
        ? context.tr('Hôm nay chưa nhắn tin cho nhau 💌')
        : context.tr('$days ngày chưa nhắn tin cho nhau 💌');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _HomeScrapbookCard(
        accentColor: SLColors.thread,
        color: SLColors.paperPeach,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SLColors.paper,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: SLColors.borderLight),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.mail_rounded, size: 20, color: SLColors.thread),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 8,
                      color: SLColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: context.tr('Nhắn ngay'),
              child: Material(
                color: SLColors.primary,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: state._openDirectChat,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
