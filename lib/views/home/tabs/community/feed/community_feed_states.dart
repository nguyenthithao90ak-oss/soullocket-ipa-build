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
                color: accentColor.withOpacity(0.1),
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

class _CommunityFeedLoadingState extends StatelessWidget {
  const _CommunityFeedLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 50),
        child: CircularProgressIndicator(color: Color(0xFFD81B60)),
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
