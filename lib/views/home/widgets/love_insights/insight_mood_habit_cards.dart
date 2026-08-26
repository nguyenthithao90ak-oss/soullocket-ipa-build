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
          ),
          SLSpacing.h16,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF6B9D),
                  size: 20,
                ),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    '${insight.interactionRate.toStringAsFixed(1)} hoạt động/ngày',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF332C35),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h10,
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Ưu tiên: ${_favoriteActivityLabel(insight)}',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: const Color(0xFF8D8490),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms, delay: 250.ms).slideY(begin: 0.06, end: 0, duration: 500.ms, delay: 250.ms, curve: Curves.easeOut);
  }

  Widget _buildAdvisorCard(LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE1EC),
            Color(0xFFEDE2FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFDCE8).withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // ── Decorative heart ──
          Positioned(
            right: -8,
            bottom: -8,
            child: Opacity(
              opacity: 0.06,
              child: Icon(
                Icons.favorite_rounded,
                size: 80,
                color: const Color(0xFFFF4F87),
              ),
            ),
          ),
          Column(
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
                accent: const Color(0xFFFF4F87),
              ),
              SLSpacing.h12,
              Text(
                insight.suggestion,
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.6,
                  color: const Color(0xFF332C35),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms, delay: 300.ms).slideY(begin: 0.06, end: 0, duration: 500.ms, delay: 300.ms, curve: Curves.easeOut);
  }
}
