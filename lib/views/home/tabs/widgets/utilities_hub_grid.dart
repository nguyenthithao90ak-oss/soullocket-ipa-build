import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/admob_service.dart';
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
        final crossAxisCount = width >= 1000
            ? 6
            : width >= 760
            ? 5
            : width >= 520
            ? 4
            : 3;
        const tileHeight = 126.0;
        final spacing = width >= 520 ? 16.0 : 12.0;
        final horizontalInset = width > 1040 ? (width - 1000) / 2 : 20.0;
        final itemWidth =
            ((width -
                        (horizontalInset * 2) -
                        (spacing * (crossAxisCount - 1))) /
                    crossAxisCount)
                .clamp(78.0, 150.0);

        return CustomScrollView(
          physics: SLResponsive.scrollPhysicsForPlatform(),
          slivers: [
            if (pinnedApps.isNotEmpty || recentApps.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  8,
                  horizontalInset,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: UtilitiesHubShortcuts(
                    pinnedApps: pinnedApps,
                    recentApps: recentApps,
                    onShortcutTap: onShortcutTap,
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                8,
                horizontalInset,
                12,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: spacing,
                  childAspectRatio: itemWidth / tileHeight,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final app = apps[index];
                  return RepaintBoundary(
                    child: UtilitiesHubItem(
                      key: ValueKey<String>(app.id),
                      app: app,
                      isEditMode: isEditMode,
                      onTap: () => onAppTap(app.id),
                      onReorder: onReorder,
                      onEditModeChanged: onEditModeChanged,
                    ),
                  );
                }, childCount: apps.length),
              ),
            ),
            if (showBottomBanner)
              SliverToBoxAdapter(child: _buildBottomBanner(bottomBannerAd)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }

  Widget _buildBottomBanner(BannerAd? bannerAd) {
    if (bannerAd == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Tap vùng ngoài ad → trigger interstitial (doanh thu cao hơn banner)
        AdMobService().showInterstitialAd();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      ),
    );
  }
}
