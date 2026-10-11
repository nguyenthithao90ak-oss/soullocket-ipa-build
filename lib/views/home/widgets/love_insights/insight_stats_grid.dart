part of '../../love_insights_view.dart';

extension _InsightStatsGridExt on LoveInsightsView {
  Widget _buildStatsGrid(BuildContext context, LoveInsightData insight) {
    final cards = [
      _MetricCardData(
        title: L10nService().translate('home_nhtk_d59e8b'),
        value: '${insight.diaryTotal}',
        subtitle: L10nService().translateThisMonth(insight.diaryMonth),
        accent: const Color(0xFF99516B),
        icon: Icons.menu_book_rounded,
      ),
      _MetricCardData(
        title: L10nService().translate('home_albumnh_9e1acf'),
        value: '${insight.albumTotal}',
        subtitle: L10nService().translateThisMonth(insight.albumMonth),
        accent: const Color(0xFF80709E),
        icon: Icons.photo_library_rounded,
      ),
      _MetricCardData(
        title: _isSingle
            ? L10nService().translate('home_ngyhotng_367ea9')
            : L10nService().translate('home_tngtc_f5f47c'),
        value: '${insight.activeDays}',
        subtitle: _isSingle
            ? L10nService().translate('home_cdliu_81b703')
            : L10nService().translate('home_ngycdun_98fd1e'),
        accent: const Color(0xFFA47735),
        icon: Icons.auto_graph_rounded,
      ),
      _MetricCardData(
        title: L10nService().translate('home_tchcc_f12429'),
        value: '${insight.positivity}%',
        subtitle: _positivityStatus(insight.positivity),
        accent: const Color(0xFF397C78),
        icon: Icons.favorite_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final columns = largeText
            ? 1
            : constraints.maxWidth >= 620
            ? 4
            : 2;
        final itemWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: itemWidth,
                child: _buildMetricCard(context, card),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, _MetricCardData card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.lerp(_InsightStyle.surface(context), card.accent, 0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _InsightStyle.surface(context), width: 2),
        boxShadow: [
          BoxShadow(
            color: _InsightStyle.accent(
              context,
              card.accent,
            ).withValues(alpha: 0.10),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      card.value,
                      style: SLTheme.quicksand(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: _InsightStyle.accent(
                          context,
                          const Color(0xFF492E3A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Transform.rotate(
                angle: -0.10,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _InsightStyle.surface(
                      context,
                    ).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    card.icon,
                    size: 23,
                    color: _InsightStyle.accent(context, card.accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            card.title,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _InsightStyle.accent(context, const Color(0xFF493B43)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.subtitle,
            style: SLTheme.quicksand(
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: _InsightStyle.accent(context, const Color(0xFF756972)),
            ),
          ),
        ],
      ),
    );
  }
}
