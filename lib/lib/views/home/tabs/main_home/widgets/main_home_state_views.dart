// ignore_for_file: unused_element

part of '../../main_home_tab.dart';

const Color _mainHomeAccentColor = Color(0xFFD81B60);
const Color _mainHomeErrorTextColor = Color(0xFF6B7280);
const List<Color> _mainHomeLoadingGradient = [
  Color(0xFF231B4A),
  Color(0xFF1A1740),
  Color(0xFF171538),
];
const Color _mainHomeLoadingSpinnerTrack = Color(0x33FFFFFF);
const Color _mainHomeLoadingSpinnerColor = Color(0xFFFFA7C8);
const Color _mainHomeLoadingDotColor = Color(0x40FFFFFF);
const Color _mainHomeLoadingDotAccent = Color(0x80FF7FB0);
const Color _mainHomeLoadingGlow = Color(0x33FF7FB0);
const Color _mainHomeLoadingOverlayColor = Color(0x14000000);
const Color _mainHomeLoadingOverlaySpinner = Color(0xFFFF9FC3);
const Color _mainHomeLoadingOverlayTrack = Color(0x2AFFFFFF);
const Color _mainHomeLoadingOverlayBadge = Color(0x18000000);
const Color _mainHomeLoadingOverlayBadgeBorder = Color(0x26FFFFFF);
const Color _mainHomeLoadingOverlayBadgeText = Color(0xDFFFFFFF);

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
        children: [
          child!,
          const _MainHomeLoadingOverlay(),
        ],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: _mainHomeLoadingGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _mainHomeLoadingGlow,
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const CircularProgressIndicator.adaptive(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _mainHomeLoadingSpinnerColor,
                ),
                backgroundColor: _mainHomeLoadingSpinnerTrack,
              ),
            ),
            const SizedBox(height: 20),
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
                  'Đang tải...',
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

  const _MainHomeErrorView({
    required this.message,
  });

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
