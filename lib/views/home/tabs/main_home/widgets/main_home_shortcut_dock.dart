part of '../../main_home_tab.dart';

extension _MainHomeShortcutDockExt on _MainHomeTabState {
  // ignore: unused_element
  Widget _buildShortcutDock(List<UtilityApp> visiblePinnedApps) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: SLSpacing.all8,
      decoration: _homeCardDecoration(radius: 18),
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
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  visiblePinnedApps.length > 8 ? 8 : visiblePinnedApps.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) =>
                  _buildShortcutItem(visiblePinnedApps[index]),
            ),
    );
  }

  Widget _buildShortcutItem(UtilityApp app) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF7FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: SLRadius.mdAll,
      ),
      child: Column(
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
            ),
            child: buildUtilityStickerIcon(
              utilityId: app.id,
              fallbackIcon: app.icon,
              fallbackColor: Colors.white,
              fallbackSize: 20,
              padding: const EdgeInsets.all(3),
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
    );
  }
}
