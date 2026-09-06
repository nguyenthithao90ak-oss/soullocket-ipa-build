part of '../../main_home_tab.dart';

extension _MainHomeShortcutDockExt on _MainHomeTabState {
  // ignore: unused_element
  Widget _buildShortcutDock(List<UtilityApp> visiblePinnedApps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: _HomeScrapbookCard(
        accentColor: SLColors.secondary,
        adornment: _HomeCardAdornment.paperClip,
        padding: EdgeInsets.zero,
        radius: 20,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: visiblePinnedApps.isEmpty
              ? CustomPaint(
                  painter: _DashedBorderPainter(),
                  child: Padding(
                    padding: SLSpacing.all8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.push_pin_outlined,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                        SLSpacing.w8,
                        Flexible(
                          child: Text(
                            context.tr('utilities_pin_hint'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final crossAxisCount = availableWidth < 280
                        ? 2
                        : availableWidth < 420
                        ? 3
                        : 4;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visiblePinnedApps.length > 8
                          ? 8
                          : visiblePinnedApps.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: crossAxisCount == 2 ? 0.98 : 0.94,
                      ),
                      itemBuilder: (context, index) =>
                          _buildAnimatedShortcutItem(
                            visiblePinnedApps[index],
                            index,
                          ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildAnimatedShortcutItem(UtilityApp app, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + 60 * index),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.7 + 0.3 * value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: SLBouncingButton(
        scaleFactor: 0.92,
        onTap: () => _onPinnedAppTap(app),
        child: _buildShortcutItem(app),
      ),
    );
  }

  Widget _buildShortcutItem(UtilityApp app) {
    final accent = app.colors.isEmpty ? SLColors.primary : app.colors.last;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: SLColors.paperBlush.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 12,
            spreadRadius: -5,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.58),
                      accent.withValues(alpha: 0.04),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: app.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: SLRadius.smAll,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: app.colors.last.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: HomeStickerMotion(
                  motion: SoulLocketStickerMotion.sway,
                  motionSeed: app.id,
                  child: buildUtilityStickerIcon(
                    utilityId: app.id,
                    fallbackIcon: app.icon,
                    fallbackColor: Colors.white,
                    fallbackSize: 20,
                    padding: const EdgeInsets.all(3),
                  ),
                ),
              ),
              SLSpacing.h4,
              Expanded(
                child: Center(
                  child: Text(
                    app.localizedTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
