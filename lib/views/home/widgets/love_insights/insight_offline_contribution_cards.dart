part of '../../love_insights_screen.dart';

extension _InsightOfflineContributionCardsExt on _LoveInsightsScreenState {
  Widget _buildOfflineCard(LoveInsightData insight) {
    // Offline card gộp vào contribution flow, giữ widget để không vỡ code
    return const SizedBox.shrink();
  }

  Widget _buildContributionCard(LoveInsightData insight) {
    final leftPercent = (insight.shareU1 * 100).round().clamp(5, 95);
    final rightPercent = (insight.shareU2 * 100).round().clamp(5, 95);
    final leftFlex = leftPercent.clamp(10, 90);
    final rightFlex = rightPercent.clamp(10, 90);

    final name1 = insight.nameU1;
    final name2 = insight.nameU2;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.pie_chart_outline_rounded,
            title: L10nService().translate('home_nggpchotnh_b78922'),
            subtitle: L10nService().translate('home_tnhtheonht_08e94d'),
            accent: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 14),
          // ── Names + Percentages ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$leftPercent%',
                      style: SLTheme.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$rightPercent%',
                      style: SLTheme.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Progress bar Blue → Rose ──
          Container(
            clipBehavior: Clip.antiAlias,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF3F4F6),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: leftFlex,
                  child: Container(
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                Expanded(
                  flex: rightFlex,
                  child: Container(
                    color: const Color(0xFFF43F5E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Balance comment ──
          Text(
            L10nService().translate('home_numtbnangt_32b73c'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: const Color(0xFF8D8490),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms, delay: 200.ms).slideY(begin: 0.06, end: 0, duration: 500.ms, delay: 200.ms, curve: Curves.easeOut);
  }

  Widget _buildSingleFocusCard(LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.self_improvement_rounded,
            title: L10nService().translate('home_thiquencab_8114d9'),
            subtitle: L10nService().translate('home_phntchtnhp_774d24'),
          ),
          SLSpacing.h16,
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  label: L10nService().translate('home_hotngngy_0b53ec'),
                  value: insight.interactionRate.toStringAsFixed(1),
                  color: const Color(0xFFFF6B9D),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildMiniMetric(
                  label: L10nService().translate('home_yuthch_2958ea'),
                  value: _favoriteActivityLabel(insight),
                  color: const Color(0xFF9B7AE8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8D8490),
            ),
          ),
          SLSpacing.h8,
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
