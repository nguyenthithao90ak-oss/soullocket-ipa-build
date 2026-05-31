import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/utility_service.dart';
import 'utilities_hub_item.dart';
import 'utilities_hub_shortcuts.dart';

class UtilitiesHubGrid extends StatelessWidget {
  const UtilitiesHubGrid({
    super.key,
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
  });

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const crossAxisCount = 4;
        const tileHeight = 112.0;
        final spacing = width >= 430 ? 14.0 : 12.0;
        final itemWidth =
            ((width - 44 - (spacing * (crossAxisCount - 1))) / crossAxisCount)
                .clamp(64.0, 96.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pinnedApps.isNotEmpty || recentApps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: UtilitiesHubShortcuts(
                    pinnedApps: pinnedApps,
                    recentApps: recentApps,
                    onShortcutTap: onShortcutTap,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: 14,
                  children: apps.map((app) {
                    return SizedBox(
                      key: ValueKey<String>(app.id),
                      width: itemWidth,
                      height: tileHeight,
                      child: UtilitiesHubItem(
                        app: app,
                        isEditMode: isEditMode,
                        onTap: () => onAppTap(app.id),
                        onReorder: onReorder,
                        onEditModeChanged: onEditModeChanged,
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
              if (showBottomBanner)
                _buildBottomBanner(bottomBannerAd),
              SLSpacing.gapH(32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBanner(BannerAd? bannerAd) {
    if (bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: SLColors.bgElevated.withValues(alpha: 0.72),
            borderRadius: SLRadius.lgAll,
            border: Border.all(
              color: SLColors.bgElevated.withValues(alpha: 0.45),
            ),
            boxShadow: SLShadow.subtle,
          ),
          child: ClipRRect(
            borderRadius: SLRadius.mdAll,
            child: SizedBox(
              width: bannerAd.size.width.toDouble(),
              height: bannerAd.size.height.toDouble(),
              child: AdWidget(ad: bannerAd),
            ),
          ),
        ),
      ),
    );
  }
}
