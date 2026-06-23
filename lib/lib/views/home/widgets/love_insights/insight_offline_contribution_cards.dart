part of '../../love_insights_screen.dart';

extension _InsightOfflineContributionCardsExt on _LoveInsightsScreenState {
  Widget _buildOfflineCard(LoveInsightData insight) {
    return Container(
      padding: SLSpacing.all16,
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.wifi_off_rounded,
            title:
                _isSingle ? L10nService().translate('home_nhponlineg_42a0ba') : L10nService().translate('home_trngthionl_e20b34'),
            subtitle: _isSingle
                ? L10nService().translate('home_osngybnria_cb6f93')
                : L10nService().translate('home_numtngivng_9f01d2'),
          ),
          SLSpacing.h16,
          if (_isSingle)
            _buildOfflineMetric(
              title: insight.nameU1,
              value: insight.offU1,
              accent: const Color(0xFF0F4C81),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildOfflineMetric(
                    title: insight.nameU1,
                    value: insight.offU1,
                    accent: const Color(0xFF0F4C81),
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: _buildOfflineMetric(
                    title: insight.nameU2,
                    value: insight.offU2,
                    accent: const Color(0xFFD81B60),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOfflineMetric({
    required String title,
    required double value,
    required Color accent,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF283040),
            ),
          ),
          SLSpacing.h8,
          Text(
            _offlineText(value),
            style: SLTheme.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          SLSpacing.h4,
          Text(
            value <= 0.6
                ? L10nService().translate('home_angginhpn_697a9b')
                : value <= 2
                    ? L10nService().translate('home_cduhiuvngn_c47464')
                    : L10nService().translate('home_nnghappthn_c0748e'),
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF76707A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(LoveInsightData insight) {
    final leftFlex = (insight.shareU1 * 100).round().clamp(10, 90);
    final rightFlex = (insight.shareU2 * 100).round().clamp(10, 90);

    return Container(
      padding: SLSpacing.all16,
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.balance_rounded,
            title: L10nService().translate('home_nggpchotnh_b78922'),
            subtitle:
                L10nService().translate('home_tnhtheonht_08e94d'),
          ),
          SLSpacing.h16,
          Row(
            children: [
              Expanded(
                child: _buildShareTag(
                  name: insight.nameU1,
                  percent: (insight.shareU1 * 100).round(),
                  accent: const Color(0xFF0F4C81),
                  alignment: CrossAxisAlignment.start,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildShareTag(
                  name: insight.nameU2,
                  percent: (insight.shareU2 * 100).round(),
                  accent: const Color(0xFFD81B60),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: SLRadius.pillAll,
              color: const Color(0xFFF1F4F8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: leftFlex,
                  child: Container(
                    height: 16,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF1565C0)],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: rightFlex,
                  child: Container(
                    height: 16,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF80AB), Color(0xFFAD1457)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h12,
          Text(
            L10nService().translate('home_numtbnangt_32b73c'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.45,
              color: const Color(0xFF6A6470),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareTag({
    required String name,
    required int percent,
    required Color accent,
    required CrossAxisAlignment alignment,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF253042),
          ),
        ),
        SLSpacing.h4,
        Text(
          '$percent%',
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleFocusCard(LoveInsightData insight) {
    return Container(
      padding: SLSpacing.all16,
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
                  color: const Color(0xFFF59E0B),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: _buildMiniMetric(
                  label: L10nService().translate('home_yuthch_2958ea'),
                  value: _favoriteActivityLabel(insight),
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
