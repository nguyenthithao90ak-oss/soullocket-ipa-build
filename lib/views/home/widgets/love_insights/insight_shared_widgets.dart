part of '../../love_insights_view.dart';

extension _InsightSharedWidgetsExt on LoveInsightsView {
  // ── Palette chung ──

  static const _textDark = Color(0xFF492E3A);
  static const _textGrey = Color(0xFF806C73);

  String _displayName(LoveInsightData insight, {required bool isFirst}) {
    final current = (isFirst ? nameU1 : nameU2).trim();
    final cached = (isFirst ? insight.nameU1 : insight.nameU2).trim();
    if (current.isNotEmpty) return current;
    if (cached.isNotEmpty) return cached;
    return L10nService().translate(
      isFirst ? 'home_bn_1fd75b' : 'home_ngiy_5bab37',
    );
  }

  Widget _buildProfileAvatar({
    required String name,
    required String avatarUrl,
    required double size,
    Color accent = const Color(0xFF99516B),
    Key? avatarKey,
  }) {
    return InsightProfileAvatar(
      key: avatarKey,
      name: name,
      avatarUrl: avatarUrl,
      size: size,
      accent: accent,
    );
  }

  Widget _buildAdaptivePair({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 230 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    Color accent = const Color(0xFF99516B),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21, color: accent),
        ),
        SLSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                SLSpacing.h4,
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: _textGrey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
