part of '../../love_insights_view.dart';

extension _InsightMoodHabitCardsExt on LoveInsightsView {
  Widget _buildHabitCard(LoveInsightData insight) {
    final favoriteIcon = insight.diaryTotal > insight.albumTotal
        ? Icons.menu_book_rounded
        : insight.diaryTotal < insight.albumTotal
        ? Icons.photo_library_outlined
        : Icons.balance_rounded;
    return Container(
      key: const ValueKey('insight-habits'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF2E5), Color(0xFFFCF7EF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1E3D1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardTitle(
            icon: Icons.spa_outlined,
            title: L10nService().translate(
              _isSingle ? 'home_thiquencab_8114d9' : 'home_nhphotng_4917b2',
            ),
            subtitle: _isSingle
                ? L10nService().translate('home_phntchtnhp_774d24')
                : '',
            accent: const Color(0xFFA46A35),
          ),
          const SizedBox(height: 20),
          _buildAdaptivePair(
            first: _buildHabitMetric(
              icon: Icons.local_fire_department_outlined,
              label: L10nService().translate('home_hotngngy_0b53ec'),
              value: insight.interactionRate.toStringAsFixed(1),
              accent: const Color(0xFFA46A35),
              isNumber: true,
            ),
            second: _buildHabitMetric(
              icon: favoriteIcon,
              label: L10nService().translate('home_yuthch_2958ea'),
              value: _favoriteActivityLabel(insight),
              accent: const Color(0xFF99516B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    bool isNumber = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: accent),
          const SizedBox(height: 12),
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: isNumber ? 32 : 18,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF573E35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: const Color(0xFF846D5E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorCard(LoveInsightData insight) {
    return Container(
      key: const ValueKey('insight-advisor'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7EAF0), Color(0xFFF7F1F8)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDDEE7)),
      ),
      child: Stack(
        children: [
          const PositionedDirectional(
            end: -6,
            top: -8,
            child: ExcludeSemantics(
              child: Icon(
                Icons.format_quote_rounded,
                size: 120,
                color: Color(0xFFEBDCE7),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardTitle(
                  icon: Icons.auto_awesome_outlined,
                  title: L10nService().translate(
                    _isSingle
                        ? 'home_gcnhhng_699bdb'
                        : 'home_gctvnyuthn_897317',
                  ),
                  subtitle: L10nService().translate(
                    _isSingle
                        ? 'home_ctnhpsinhh_fdf44b'
                        : 'home_datrnnhpyu_d7b4a7',
                  ),
                  accent: const Color(0xFF915D80),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    insight.suggestion.trim().isEmpty
                        ? _dailyTip(insight)
                        : insight.suggestion,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.65,
                      color: const Color(0xFF5A3F51),
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
}
