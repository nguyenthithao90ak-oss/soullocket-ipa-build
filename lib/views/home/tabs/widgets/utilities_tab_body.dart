import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../utils/services/utility_service.dart';
import 'utilities_hub_grid.dart';
import 'utilities_hub_header.dart';

class UtilitiesTabBody extends StatefulWidget {
  const UtilitiesTabBody({
    super.key,
    required this.currentSegment,
    required this.onSegmentChanged,
    required this.onResetTap,
    required this.commonApps,
    required this.essentialApps,
    required this.pinnedApps,
    required this.recentApps,
    required this.onShortcutTap,
    required this.showBottomBanner,
    required this.bottomBannerAd,
    required this.isEditMode,
    required this.onAppTap,
    required this.onReorder,
    required this.onEditModeChanged,
  });

  final int currentSegment;
  final ValueChanged<int> onSegmentChanged;
  final VoidCallback onResetTap;
  final List<UtilityApp> commonApps;
  final List<UtilityApp> essentialApps;
  final List<UtilityApp> pinnedApps;
  final List<UtilityApp> recentApps;
  final ValueChanged<String> onShortcutTap;
  final bool showBottomBanner;
  final BannerAd? bottomBannerAd;
  final bool isEditMode;
  final ValueChanged<String> onAppTap;
  final void Function(String fromId, String toId) onReorder;
  final ValueChanged<bool> onEditModeChanged;

  @override
  State<UtilitiesTabBody> createState() => _UtilitiesTabBodyState();
}

class _UtilitiesTabBodyState extends State<UtilitiesTabBody> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentSegment);
  }

  @override
  void didUpdateWidget(UtilitiesTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSegment != widget.currentSegment) {
      final currentPage = _pageController.page?.round() ?? _pageController.initialPage;
      if (currentPage != widget.currentSegment) {
        _pageController.animateToPage(
          widget.currentSegment,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UtilitiesHubHeader(
          currentSegment: widget.currentSegment,
          onSegmentChanged: widget.onSegmentChanged,
          onResetTap: widget.onResetTap,
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: widget.onSegmentChanged,
            physics: const ClampingScrollPhysics(),
            children: [
              _KeepAlivePage(
                child: UtilitiesHubGrid(
                  apps: widget.commonApps,
                  pinnedApps: widget.pinnedApps,
                  recentApps: widget.recentApps,
                  onShortcutTap: widget.onShortcutTap,
                  showBottomBanner: widget.showBottomBanner,
                  bottomBannerAd: widget.bottomBannerAd,
                  isEditMode: widget.isEditMode,
                  onAppTap: widget.onAppTap,
                  onReorder: widget.onReorder,
                  onEditModeChanged: widget.onEditModeChanged,
                ),
              ),
              _KeepAlivePage(
                child: UtilitiesHubGrid(
                  apps: widget.essentialApps,
                  pinnedApps: widget.pinnedApps,
                  recentApps: widget.recentApps,
                  onShortcutTap: widget.onShortcutTap,
                  showBottomBanner: widget.showBottomBanner,
                  bottomBannerAd: widget.bottomBannerAd,
                  isEditMode: widget.isEditMode,
                  onAppTap: widget.onAppTap,
                  onReorder: widget.onReorder,
                  onEditModeChanged: widget.onEditModeChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
