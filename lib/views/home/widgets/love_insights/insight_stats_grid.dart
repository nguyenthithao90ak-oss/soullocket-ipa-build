part of '../../love_insights_screen.dart';

extension _InsightStatsGridExt on _LoveInsightsScreenState {
  Widget _buildStatsGrid(LoveInsightData insight) {
    final cards = [
      _MetricCardData(
        title: context.tr('home_nhtk_d59e8b'),
        value: '${insight.diaryTotal}',
        subtitle: L10nService().translateThisMonth(insight.diaryMonth),
        accent: const Color(0xFF3B82F6),
        icon: Icons.menu_book_rounded,
      ),
      _MetricCardData(
        title: context.tr('home_albumnh_9e1acf'),
        value: '${insight.albumTotal}',
        subtitle: L10nService().translateThisMonth(insight.albumMonth),
        accent: const Color(0xFF6366F1),
        icon: Icons.photo_library_rounded,
      ),
      _MetricCardData(
        title: _isSingle
            ? context.tr('home_ngyhotng_367ea9')
            : context.tr('home_tngtc_f5f47c'),
        value: '${insight.activeDays}',
        subtitle: _isSingle
            ? context.tr('home_cdliu_81b703')
            : context.tr('home_ngycdun_98fd1e'),
        accent: const Color(0xFFF59E0B),
        icon: Icons.auto_graph_rounded,
      ),
      _MetricCardData(
        title: context.tr('home_tchcc_f12429'),
        value: '${insight.positivity}%',
        subtitle: _positivityStatus(insight.positivity),
        accent: const Color(0xFF10B981),
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
          children: List.generate(cards.length, (index) {
            final card = cards[index];
            return SizedBox(
              width: itemWidth,
              child: _buildMetricCard(card)
                  .animate()
                  .fade(duration: 400.ms),
            );
          }),
        );
      },
    );
  }

  Widget _buildMetricCard(_MetricCardData card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E5DF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5E7E).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: card.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, size: 18, color: card.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A6B72),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            card.value,
            style: SLTheme.quicksand(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2E2427),
              height: 0.95,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFA699A0),
            ),
          ),
        ],
      ),
    );
  }
}
