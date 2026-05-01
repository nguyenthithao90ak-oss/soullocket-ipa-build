import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../utils/services/utility_service.dart';
import 'utilities_hub_grid.dart';
import 'utilities_hub_header.dart';

class UtilitiesTabBody extends StatelessWidget {
  const UtilitiesTabBody({
    super.key,
    required this.currentSegment,
    required this.onSegmentChanged,
    required this.onResetTap,
    required this.apps,
    required this.pinnedApps,
    required this.recentApps,
    required this.onShortcutTap,
    required this.showBottomBanner,
    required this.bottomBannerAd,
    required this.isEditMode,
    required this.onAppTap,
    required this.onReorder,
    required this.onEditModeChanged,
    this.onDelete,
  });

  final int currentSegment;
  final ValueChanged<int> onSegmentChanged;
  final VoidCallback onResetTap;
  final List<UtilityApp> apps;
  final List<UtilityApp> pinnedApps;
  final List<UtilityApp> recentApps;
  final ValueChanged<String> onShortcutTap;
  final bool showBottomBanner;
  final BannerAd? bottomBannerAd;
  final bool isEditMode;
  final ValueChanged<String> onAppTap;
  final void Function(String fromId, String toId) onReorder;
  final ValueChanged<bool> onEditModeChanged;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UtilitiesHubHeader(
          currentSegment: currentSegment,
          onSegmentChanged: onSegmentChanged,
          onResetTap: onResetTap,
        ),
        Expanded(
          child: UtilitiesHubGrid(
            apps: apps,
            pinnedApps: pinnedApps,
            recentApps: recentApps,
            onShortcutTap: onShortcutTap,
            showBottomBanner: showBottomBanner,
            bottomBannerAd: bottomBannerAd,
            isEditMode: isEditMode,
            onAppTap: onAppTap,
            onReorder: onReorder,
            onEditModeChanged: onEditModeChanged,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

