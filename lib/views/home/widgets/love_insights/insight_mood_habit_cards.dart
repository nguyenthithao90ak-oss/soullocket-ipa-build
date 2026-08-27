part of '../../love_insights_screen.dart';

extension _InsightMoodHabitCardsExt on _LoveInsightsScreenState {
  Widget _buildMoodHabitRow(LoveInsightData insight) {
    return _buildHabitCard(insight);
  }

  Widget _buildHabitCard(LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.auto_graph_rounded,
            title: L10nService().translate('home_nhphotng_4917b2'),
            subtitle: '',
            accent: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${insight.interactionRate.toStringAsFixed(1)} hoạt động/ngày',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Ưu tiên: ${_favoriteActivityLabel(insight)}',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildAdvisorCard(LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.auto_awesome_rounded,
            title: _isSingle
                ? L10nService().translate('home_gcnhhng_699bdb')
                : L10nService().translate('home_gctvnyuthn_897317'),
            subtitle: _isSingle
                ? L10nService().translate('home_ctnhpsinhh_fdf44b')
                : L10nService().translate('home_datrnnhpyu_d7b4a7'),
            accent: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          Text(
            insight.suggestion,
            style: SLTheme.quicksand(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.55,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }
}
