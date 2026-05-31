part of '../../love_insights_screen.dart';

extension _InsightStatsGridExt on _LoveInsightsScreenState {
  Widget _buildStatsGrid(LoveInsightData insight) {
    final cards = [
      _MetricCardData(
        title: context.tr('home_nhtk_d59e8b'),
        value: '${insight.diaryTotal}',
        subtitle: '+${insight.diaryMonth} tháng này',
        accent: const Color(0xFF10B981),
        icon: Icons.menu_book_rounded,
      ),
      _MetricCardData(
        title: context.tr('home_albumnh_9e1acf'),
        value: '${insight.albumTotal}',
        subtitle: '+${insight.albumMonth} tháng này',
        accent: const Color(0xFF8B5CF6),
        icon: Icons.photo_library_rounded,
      ),
      _MetricCardData(
        title: _isSingle ? context.tr('home_ngyhotng_367ea9') : context.tr('home_tngtc_f5f47c'),
        value: '${insight.activeDays}',
        subtitle: _isSingle ? context.tr('home_cdliu_81b703') : context.tr('home_ngycdun_98fd1e'),
        accent: const Color(0xFF0F4C81),
        icon: Icons.auto_graph_rounded,
      ),
      _MetricCardData(
        title: context.tr('home_tchcc_f12429'),
        value: '${insight.positivity}%',
        subtitle: _positivityStatus(insight.positivity),
        accent: const Color(0xFFD81B60),
        icon: Icons.favorite_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = ((constraints.maxWidth - 12) / 2)
            .clamp(0.0, constraints.maxWidth)
            .toDouble();

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: itemWidth,
                child: _buildMetricCard(card),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(_MetricCardData card) {
    return Container(
      padding: SLSpacing.all16,
      decoration:
          _softCardDecoration(borderColor: card.accent.withValues(alpha: 0.14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: card.accent.withValues(alpha: 0.10),
                  borderRadius: SLRadius.mdAll,
                ),
                child: Icon(card.icon, size: 18, color: card.accent),
              ),
              SLSpacing.w8,
              Expanded(
                child: Text(
                  card.title,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF6D6670),
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            card.value,
            style: SLTheme.quicksand(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF172033),
              height: 0.95,
            ),
          ),
          SLSpacing.h8,
          Text(
            card.subtitle,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: card.accent,
            ),
          ),
        ],
      ),
    );
  }
}
