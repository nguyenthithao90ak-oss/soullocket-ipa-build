part of '../../love_insights_screen.dart';

extension _InsightInteractionCardExt on _LoveInsightsScreenState {
  Widget _buildInteractionCard(LoveInsightData insight) {
    return Container(
      padding: SLSpacing.all16,
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.visibility_rounded,
            title: _isSingle
                ? L10nService().translate('home_tnsutsdng_72ed67')
                : L10nService().translate('home_tngtcquant_578a21'),
            subtitle: _isSingle
                ? L10nService().translate('home_lytheoslnm_cc9da8')
                : L10nService().translate('home_sosnhmcxem_8fb417'),
          ),
          SLSpacing.h16,
          if (_isSingle)
            _buildSingleInteractionOverview(insight)
          else
            Column(
              children: [
                _buildComparisonBar(
                  label: L10nService().translate('home_xemnhtk_37a828'),
                  val1: insight.viewU1,
                  val2: insight.viewU2,
                  name1: insight.nameU1,
                  name2: insight.nameU2,
                  color1: const Color(0xFF3B82F6),
                  color2: const Color(0xFFF43F5E),
                ),
                SLSpacing.h16,
                _buildComparisonBar(
                  label: L10nService().translate('home_mapp_ab1833'),
                  val1: insight.openU1,
                  val2: insight.openU2,
                  name1: insight.nameU1,
                  name2: insight.nameU2,
                  color1: const Color(0xFF3B82F6),
                  color2: const Color(0xFFF43F5E),
                ),
              ],
            ),
          SLSpacing.h12,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FD),
              borderRadius: SLRadius.lgAll,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    _isSingle
                        ? 'Bạn đang giữ nhịp ${insight.interactionRate.toStringAsFixed(1)} hoạt động/ngày.'
                        : 'Hiện nhịp gắn kết khoảng ${insight.interactionRate.toStringAsFixed(1)} hoạt động/ngày.',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4A4A55),
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

  Widget _buildSingleInteractionOverview(LoveInsightData insight) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniMetric(
            label: L10nService().translate('home_xemnhtk_37a828'),
            value: '${insight.viewU1}',
            color: const Color(0xFF1976D2),
          ),
        ),
        SLSpacing.w12,
        Expanded(
          child: _buildMiniMetric(
            label: L10nService().translate('home_mapp_ab1833'),
            value: '${insight.openU1}',
            color: const Color(0xFFD81B60),
          ),
        ),
      ],
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
        color: color.withValues(alpha: 0.07),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF716A74),
            ),
          ),
          SLSpacing.h8,
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar({
    required String label,
    required int val1,
    required int val2,
    required String name1,
    required String name2,
    required Color color1,
    required Color color2,
  }) {
    final maxVal = max(1, max(val1, val2));
    final p1 = val1 / maxVal;
    final p2 = val2 / maxVal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF504A55),
          ),
        ),
        SLSpacing.h8,
        _buildSingleBar(name1, val1, p1, color1),
        SLSpacing.h6,
        _buildSingleBar(name2, val2, p2, color2),
      ],
    );
  }

  Widget _buildSingleBar(String name, int val, double ratio, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8B8590),
            ),
          ),
        ),
        SLSpacing.w8,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.6), color],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
        SLSpacing.w8,
        SizedBox(
          width: 32,
          child: Text(
            '$val',
            textAlign: TextAlign.right,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
