// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../main_home_tab.dart';

const Color _mainHomeAccentColor = Color(0xFFD81B60);
const Color _mainHomeErrorTextColor = Color(0xFF6B7280);
const List<Color> _mainHomeLoadingGradient = [
  Color(0xFFFFF9F3),
  Color(0xFFFFEDF3),
  Color(0xFFF2ECFF),
];
const Color _mainHomeLoadingSpinnerTrack = Color(0x28D96B7C);
const Color _mainHomeLoadingSpinnerColor = Color(0xFFD94D78);
const Color _mainHomeLoadingDotColor = Color(0x42D96B7C);
const Color _mainHomeLoadingDotAccent = Color(0xFFD94D78);
const Color _mainHomeLoadingGlow = Color(0x2ED94D78);
const Color _mainHomeLoadingOverlayColor = Color(0x0A3F2430);
const Color _mainHomeLoadingOverlaySpinner = Color(0xFFD94D78);
const Color _mainHomeLoadingOverlayTrack = Color(0x24D96B7C);
const Color _mainHomeLoadingOverlayBadge = Color(0xF7FFF9F5);
const Color _mainHomeLoadingOverlayBadgeBorder = Color(0x66E8D8D1);
const Color _mainHomeLoadingOverlayBadgeText = Color(0xFF6E4D5A);

class _MainHomeStateView extends StatelessWidget {
  final bool isLoading;
  final bool hasVisibleContent;
  final Widget? child;

  const _MainHomeStateView({
    required this.isLoading,
    required this.hasVisibleContent,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Luôn show loading khi chưa có dữ liệu
    if (!hasVisibleContent) {
      return const _MainHomeLoadingView();
    }
    // Đã có dữ liệu, đang load thêm → show content + overlay
    if (isLoading && child != null) {
      return Stack(
        fit: StackFit.expand,
        children: [child!, const _MainHomeLoadingOverlay()],
      );
    }
    // Đã có dữ liệu, không load → show content
    if (child != null) {
      return child!;
    }
    // Fallback an toàn
    return const _MainHomeLoadingView();
  }
}

class _MainHomeLoadingView extends StatelessWidget {
  const _MainHomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _mainHomeLoadingGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: _HomeScrapbookBackdrop(hasCustomBackground: false),
        ),
        Semantics(
          liveRegion: true,
          label: context.tr('Đang tải...'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 98,
                  height: 98,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.09,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: SLColors.paper,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: SLColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: _mainHomeLoadingGlow,
                                blurRadius: 26,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: SLColors.paperBlush,
                          shape: BoxShape.circle,
                          border: Border.all(color: SLColors.borderLight),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 28,
                          color: _mainHomeLoadingSpinnerColor,
                        ),
                      ),
                      const SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _mainHomeLoadingSpinnerColor,
                          ),
                          backgroundColor: _mainHomeLoadingSpinnerTrack,
                        ),
                      ),
                      const Positioned(
                        right: 1,
                        top: 9,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: SLColors.warningGold,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'SoulLocket',
                  style: GoogleFonts.dancingScript(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loadingDot(),
                    const SizedBox(width: 6),
                    _loadingDot(isAccent: true),
                    const SizedBox(width: 6),
                    _loadingDot(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _loadingDot({bool isAccent = false}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAccent ? _mainHomeLoadingDotAccent : _mainHomeLoadingDotColor,
      ),
    );
  }
}

class _MainHomeLoadingOverlay extends StatelessWidget {
  const _MainHomeLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: _mainHomeLoadingOverlayColor,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _mainHomeLoadingOverlayBadge,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _mainHomeLoadingOverlayBadgeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _mainHomeLoadingOverlaySpinner,
                    ),
                    backgroundColor: _mainHomeLoadingOverlayTrack,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.tr('Đang tải...'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _mainHomeLoadingOverlayBadgeText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainHomeEmptyView extends StatelessWidget {
  const _MainHomeEmptyView();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _MainHomeErrorView extends StatelessWidget {
  final String message;

  const _MainHomeErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _mainHomeErrorTextColor,
        ),
      ),
    );
  }
}
