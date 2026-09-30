part of '../../love_insights_view.dart';

extension _InsightOfflineContributionCardsExt on LoveInsightsView {
  Widget _buildContributionCard(LoveInsightData insight) {
    final firstPercent = (insight.shareU1 * 100).round().clamp(0, 100);
    final secondPercent = (insight.shareU2 * 100).round().clamp(0, 100);
    const firstColor = Color(0xFF99516B);
    const secondColor = Color(0xFF397C78);

    return Container(
      key: const ValueKey('insight-contribution'),
      padding: const EdgeInsets.all(20),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardTitle(
            icon: Icons.favorite_border_rounded,
            title: L10nService().translate('home_nggpchotnh_b78922'),
            subtitle: L10nService().translate('home_tnhtheonht_08e94d'),
            accent: firstColor,
          ),
          const SizedBox(height: 20),
          _buildAdaptivePair(
            first: _buildContributionMember(
              role: 'user1',
              name: _displayName(insight, isFirst: true),
              avatar: avatarU1,
              percent: firstPercent,
              accent: firstColor,
              background: const Color(0xFFFFF0F2),
            ),
            second: _buildContributionMember(
              role: 'user2',
              name: _displayName(insight, isFirst: false),
              avatar: avatarU2,
              percent: secondPercent,
              accent: secondColor,
              background: const Color(0xFFECF6F3),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: const Color(0xFFF0E5DF),
                child: Row(
                  key: const ValueKey('insight-contribution-bar'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (firstPercent > 0)
                      Expanded(
                        flex: firstPercent,
                        child: const ColoredBox(color: firstColor),
                      ),
                    if (secondPercent > 0)
                      Expanded(
                        flex: secondPercent,
                        child: const ColoredBox(color: secondColor),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 19,
                  color: Color(0xFFA47750),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    L10nService().translate('home_numtbnangt_32b73c'),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                      color: const Color(0xFF79655C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionMember({
    required String role,
    required String name,
    required String avatar,
    required int percent,
    required Color accent,
    required Color background,
  }) {
    return Container(
      key: ValueKey('insight-contribution-$role'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _buildProfileAvatar(
            name: name,
            avatarUrl: avatar,
            size: 54,
            accent: accent,
            avatarKey: ValueKey('insight-contribution-avatar-$role'),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF492E3A),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$percent%',
              style: SLTheme.quicksand(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
