part of '../../main_home_tab.dart';

extension _MainHomeBodySectionBuilder on _MainHomeTabState {
  Widget _buildMainContentSection(
    BuildContext context, {
    required String customBackgroundUrl,
  }) {
    final viewData = _buildMainHomeBodyViewData(context);
    return _MainHomeBodySection(
      state: this,
      viewData: viewData,
      customBackgroundUrl: customBackgroundUrl,
      onOpenSettings: widget.onOpenSettings,
    );
  }
}

class _MainHomeBodySection extends StatelessWidget {
  final _MainHomeTabState state;
  final _MainHomeBodyViewData viewData;
  final String customBackgroundUrl;
  final VoidCallback? onOpenSettings;

  const _MainHomeBodySection({
    required this.state,
    required this.viewData,
    required this.customBackgroundUrl,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1A45),
      body: _ModernHomeBody(
        state: state,
        isSingle: viewData.isSingle,
        houseName: viewData.houseName,
        smartGreeting: viewData.smartGreeting,
        circleValue: viewData.circleValue,
        circleTopLabel: viewData.circleTopLabel,
        circleBottomLabel: viewData.circleBottomLabel,
        startDate: viewData.startDate,
        nameU1: viewData.nameU1,
        nameU2: viewData.nameU2,
        avtUser1: viewData.avtUser1,
        avtUser2: viewData.avtUser2,
        circleSize: viewData.circleSize,
        homeShowHouseName: viewData.homeShowHouseName,
        customBackgroundUrl: customBackgroundUrl,
        showDayCounter: viewData.showDayCounter,
        showLoveTimeDetail: viewData.showLoveTimeDetail,
        countdownStyleKey: viewData.countdownStyleKey,
        onEditStartDate: state._showEditStartDateDialog,
        onEditTopLabel: viewData.isSingle
            ? null
            : () => state._showEditCountdownLabelDialog(
                  editTopLabel: true,
                  currentLabel: viewData.circleTopLabel,
                ),
        onEditBottomLabel: viewData.isSingle
            ? null
            : () => state._showEditCountdownLabelDialog(
                  editTopLabel: false,
                  currentLabel: viewData.circleBottomLabel,
                ),
        onOpenSettings: onOpenSettings,
      ),
    );
  }
}
