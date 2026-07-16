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
    final showDecorGlow = !effectProfile.performanceMode;

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2A1523).withValues(alpha: 0.18),
                          const Color(0xFF5B2544).withValues(alpha: 0.12),
                          const Color(0xFF120A11).withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: SLTheme.meshPattern()),
                if (showDecorGlow) ...[
                  Positioned(
                    top: -88,
                    right: -72,
                    child: _HomeDecorGlow(
                      size: 210,
                      color: SLColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  Positioned(
                    top: 250,
                    left: -96,
                    child: _HomeDecorGlow(
                      size: 230,
                      color: SLColors.secondary.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
              constraints.maxWidth,
              compactPadding: 12,
              handsetPadding: 16,
              tabletPadding: 24,
            );
            final contentWidth = SLResponsive.maxContentWidthForWidth(
              constraints.maxWidth,
              handsetMax: 520,
              tabletMax: 620,
              desktopMax: 680,
            );
            Widget buildCountdown(bool isSwiping) {
              final int currentDays = int.tryParse(circleValue) ?? 0;
              final bool isMilestone = currentDays > 0 && (currentDays % 100 == 0 || currentDays % 30 == 0 || currentDays % 365 == 0);
              
              return ValueListenableBuilder<bool>(
                valueListenable: state._isScrollingNotifier,
                builder: (context, isScrolling, _) {
                  return _MainHomeHeroCountdownSection(
                    state: state,
                    isSingle: isSingle,
                    houseName: houseName,
                    smartGreeting: smartGreeting,
                    circleValue: circleValue,
                    circleTopLabel: circleTopLabel,
                    circleBottomLabel: circleBottomLabel,
                    startDate: startDate,
                    circleSize: circleSize,
                    homeShowHouseName: homeShowHouseName,
                    showDayCounter: showDayCounter,
                    showLoveTimeDetail: showLoveTimeDetail,
                    countdownStyleKey: countdownStyleKey,
                    isMilestone: isMilestone,
                    enableMotion: effectProfile.animationEnabled &&
                        !state._deferHeavyHomeMotion &&
                        !isSwiping &&
                        !isScrolling,
                    onEditStartDate: onEditStartDate,
                    onEditTopLabel: onEditTopLabel,
                    onEditBottomLabel: onEditBottomLabel,
                    firstGuideHeroKey: state.widget.firstGuideHeroKey,
                  );
                },
              );
            }

            Widget buildInsight(bool isSwiping) {
              return ValueListenableBuilder<bool>(
                valueListenable: state._isScrollingNotifier,
                builder: (context, isScrolling, _) {
                  return RepaintBoundary(
                    child: state._buildModernInsightCard(
                      isSingle: isSingle,
                      nameU1: nameU1,
                      nameU2: nameU2,
                      enableMotion: effectProfile.animationEnabled &&
                          !state._deferHeavyHomeMotion &&
                          !isSwiping &&
                          !isScrolling,
                    ),
                  );
                },
              );
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  state._isScrollingNotifier.value = true;
                } else if (notification is ScrollEndNotification) {
                  state._isScrollingNotifier.value = false;
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
                            height: MediaQuery.paddingOf(context).top + 36),
                        state.widget.isSwipingListenable == null
                            ? buildCountdown(false)
                            : ValueListenableBuilder<bool>(
                                valueListenable:
                                    state.widget.isSwipingListenable!,
                                builder: (context, isSwiping, _) =>
                                    buildCountdown(isSwiping),
                              ),
                        SLSpacing.h8,
                        state._buildModernAvatarSection(
                          isSingle: isSingle,
                          nameU1: nameU1,
                          nameU2: nameU2,
                          avtUser1: avtUser1,
                          avtUser2: avtUser2,
                        ),
                        SLSpacing.h20,
                        RepaintBoundary(
                          child: _ChatReminderBanner(
                              state: state, isSingle: isSingle),
                        ),
                        if (!isSingle) ...[
                          SLSpacing.h20,
                          RepaintBoundary(
                            child: state._buildModernHighlightCard(
                              startDate: startDate,
                              isSingle: isSingle,
                            ),
                          ),
                        ],
                        if (!isSingle) ...[
                          SLSpacing.h20,
                          RepaintBoundary(
                            child: state._buildModernMapCard(
                              nameU1: nameU1,
                              nameU2: nameU2,
                            ),
                          ),
                        ],
                        SLSpacing.h20,
                        state.widget.isSwipingListenable == null
                            ? buildInsight(false)
                            : ValueListenableBuilder<bool>(
                                valueListenable:
                                    state.widget.isSwipingListenable!,
                                builder: (context, isSwiping, _) =>
                                    buildInsight(isSwiping),
                              ),
                        SLSpacing.h20,
                        RepaintBoundary(
                          child: state._buildHomeToolSlotSection(),
                        ),
                        SLSpacing.gapH(72),
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
        ? 'Hôm nay chưa nhắn tin cho nhau 💌'
        : '$days ngày chưa nhắn tin cho nhau 💌';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SLColors.primary.withValues(alpha: 0.18),
              SLColors.secondary.withValues(alpha: 0.14),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: SLRadius.lgAll,
          border: Border.all(
            color: SLColors.primary.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Text('💬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => state._openDirectChat(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SLColors.primary.withValues(alpha: 0.22),
                  borderRadius: SLRadius.pillAll,
                ),
                child: Text(
                  'Nhắn ngay',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLColors.primary,
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

class _HomeDecorGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _HomeDecorGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
