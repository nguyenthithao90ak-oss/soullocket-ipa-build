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
    return Stack(
      children: [
        Positioned.fill(child: SLTheme.meshPattern()),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 36),
                _MainHomeHeroCountdownSection(
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
                  enableMotion: !state._deferHeavyHomeMotion,
                  onEditStartDate: onEditStartDate,
                  onEditTopLabel: onEditTopLabel,
                  onEditBottomLabel: onEditBottomLabel,
                ),
                state._buildModernAvatarSection(
                  isSingle: isSingle,
                  nameU1: nameU1,
                  nameU2: nameU2,
                  avtUser1: avtUser1,
                  avtUser2: avtUser2,
                ),
                SLSpacing.h16,
                if (!isSingle)
                  state._buildModernHighlightCard(
                    startDate: startDate,
                    isSingle: isSingle,
                  ),
                if (!isSingle) SLSpacing.h16,
                state._buildModernMapCard(nameU1: nameU1, nameU2: nameU2),
                SLSpacing.h16,
                state._buildModernInsightCard(
                  isSingle: isSingle,
                  nameU1: nameU1,
                  nameU2: nameU2,
                ),
                SLSpacing.h16,
                state._buildHomeToolSlotSection(),
                SLSpacing.gapH(140),
              ],
            ),
          ),
        ),
        _MainHomeHeroHeader(
          state: state,
          isSingle: isSingle,
          onOpenSettings: onOpenSettings,
        ),
      ],
    );
  }
}

extension _MainHomeTabHeroSection on _MainHomeTabState {}
