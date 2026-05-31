part of '../../community_tab.dart';

class _CommunityFeedErrorState extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String message;
  final Color titleColor;
  final Color messageColor;

  const _CommunityFeedErrorState({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.message,
    required this.titleColor,
    required this.messageColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: SLSpacing.all24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 72, color: accentColor),
            ),
            SLSpacing.gapH(32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: titleColor,
                letterSpacing: 0.5,
              ),
            ),
            SLSpacing.h16,
            Text(
              message,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: messageColor,
                height: 1.5,
              ),
            ),
            SLSpacing.gapH(40),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedLoadingState extends StatefulWidget {
  const _CommunityFeedLoadingState();

  @override
  State<_CommunityFeedLoadingState> createState() =>
      _CommunityFeedLoadingStateState();
}

class _CommunityFeedLoadingStateState extends State<_CommunityFeedLoadingState>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) => Column(
        children: [
          _SkeletonPostCard(shimmer: _shimmerCtrl.value),
          _SkeletonPostCard(shimmer: _shimmerCtrl.value),
          _SkeletonPostCard(shimmer: _shimmerCtrl.value),
        ],
      ),
    );
  }
}

class _SkeletonPostCard extends StatelessWidget {
  final double shimmer;
  const _SkeletonPostCard({required this.shimmer});

  static const Color _base = Color(0xFFECECEC);
  static const Color _highlight = Color(0xFFF8F8F8);

  Widget _block({
    double width = double.infinity,
    double height = 13,
    double radius = 8,
  }) {
    final double shift = shimmer * 3 - 1.5;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(shift - 1, 0),
          end: Alignment(shift + 1, 0),
          colors: const [_base, _highlight, _base],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + tên
          Row(
            children: [
              _block(width: 42, height: 42, radius: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(width: 130, height: 13),
                    const SizedBox(height: 7),
                    _block(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Nội dung text
          _block(),
          const SizedBox(height: 7),
          _block(),
          const SizedBox(height: 7),
          _block(width: 200),
          const SizedBox(height: 16),
          // Ảnh placeholder
          _block(height: 170, radius: 16),
          const SizedBox(height: 16),
          // Action bar
          Row(
            children: [
              _block(width: 64, height: 30, radius: 15),
              const SizedBox(width: 8),
              _block(width: 64, height: 30, radius: 15),
              const SizedBox(width: 8),
              _block(width: 64, height: 30, radius: 15),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityFeedEmptyState extends StatelessWidget {
  final String message;
  final Color textColor;

  const _CommunityFeedEmptyState({
    required this.message,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Text(
          message,
          style: SLTheme.quicksand(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CommunityFeedBottomLoader extends StatelessWidget {
  const _CommunityFeedBottomLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Color(0xFFD81B60),
          ),
        ),
      ),
    );
  }
}
