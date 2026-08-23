part of '../../love_insights_screen.dart';

extension _InsightStatsGridExt on _LoveInsightsScreenState {
  Widget _buildStatsGrid(LoveInsightData insight) {
    final cards = [
      _MetricCardData(
        title: context.tr('home_nhtk_d59e8b'),
        value: '${insight.diaryTotal}',
        subtitle: L10nService().translateThisMonth(insight.diaryMonth),
        accent: const Color(0xFFE91E63),
        icon: Icons.menu_book_rounded,
      ),
      _MetricCardData(
        title: context.tr('home_albumnh_9e1acf'),
        value: '${insight.albumTotal}',
        subtitle: L10nService().translateThisMonth(insight.albumMonth),
        accent: const Color(0xFF7C4DFF),
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
        accent: const Color(0xFF00897B),
        icon: Icons.auto_graph_rounded,
      ),
      _MetricCardData(
        title: context.tr('home_tchcc_f12429'),
        value: '${insight.positivity}%',
        subtitle: _positivityStatus(insight.positivity),
        accent: const Color(0xFFFF6D00),
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
                  .fade(duration: 500.ms, delay: (120 * index).ms)
                  .slideY(
                      begin: 0.12,
                      end: 0,
                      duration: 500.ms,
                      delay: (120 * index).ms,
                      curve: Curves.easeOut),
            );
          }),
        );
      },
    );
  }

  Widget _buildMetricCard(_MetricCardData card) {
    final bgColor = card.accent.withValues(alpha: 0.06);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: card.accent.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: card.accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(card.icon, size: 18, color: card.accent),
              ),
              SLSpacing.w8,
              Expanded(
                child: Text(
                  card.title,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8D8490),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [card.accent, card.accent.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              card.value,
              style: SLTheme.quicksand(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 0.95,
              ),
            ),
          ),
          SLSpacing.h6,
          Text(
            card.subtitle,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: card.accent.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
