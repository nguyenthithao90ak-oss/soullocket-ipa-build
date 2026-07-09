part of '../../love_insights_screen.dart';

extension _InsightMoodHabitCardsExt on _LoveInsightsScreenState {
  Widget _buildMoodHabitRow(LoveInsightData insight) {
    return _buildHabitCard(insight);
  }

  Widget _buildHabitCard(LoveInsightData insight) {
    return Container(
      padding: SLSpacing.all16,
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSmallHeader(L10nService().translate('home_nhphotng_4917b2')),
          SLSpacing.h12,
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              SLSpacing.w8,
              Expanded(
                child: Text(
                  '${insight.interactionRate.toStringAsFixed(1)} hoạt động/ngày',
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF172033),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            'Ưu tiên: ${_favoriteActivityLabel(insight)}',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.45,
              color: const Color(0xFF6C6572),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorCard(LoveInsightData insight) {
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF0F6),
            Color(0xFFFFF8FB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: const Color(0xFFF6CAD8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.auto_awesome_rounded,
            title: _isSingle ? L10nService().translate('home_gcnhhng_699bdb') : L10nService().translate('home_gctvnyuthn_897317'),
            subtitle: _isSingle
                ? L10nService().translate('home_ctnhpsinhh_fdf44b')
                : L10nService().translate('home_datrnnhpyu_d7b4a7'),
            accent: const Color(0xFFD81B60),
          ),
          SLSpacing.h12,
          Text(
            insight.suggestion,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.65,
              color: const Color(0xFF4E4754),
            ),
          ),
        ],
      ),
    );
  }
}
