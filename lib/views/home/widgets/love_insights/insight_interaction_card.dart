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
            title: _isSingle ? 'Tần suất sử dụng' : 'Tương tác & quan tâm',
            subtitle: _isSingle
                ? 'Lấy theo số lần mở app và chạm xem nhật ký'
                : 'So sánh mức độ xem nhật ký và mở app của hai người',
          ),
          SLSpacing.h16,
          if (_isSingle)
            _buildSingleInteractionOverview(insight)
          else
            Row(
              children: [
                Expanded(
                  child: _buildPersonStatBlock(
                    name: insight.nameU1,
                    primaryLabel: 'Xem nhật ký',
                    primaryValue: insight.viewU1,
                    secondaryLabel: 'Mở app',
                    secondaryValue: insight.openU1,
                    accent: const Color(0xFF1976D2),
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: _buildPersonStatBlock(
                    name: insight.nameU2,
                    primaryLabel: 'Xem nhật ký',
                    primaryValue: insight.viewU2,
                    secondaryLabel: 'Mở app',
                    secondaryValue: insight.openU2,
                    accent: const Color(0xFFD81B60),
                  ),
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
            label: 'Xem nhật ký',
            value: '${insight.viewU1}',
            color: const Color(0xFF1976D2),
          ),
        ),
        SLSpacing.w12,
        Expanded(
          child: _buildMiniMetric(
            label: 'Mở app',
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

  Widget _buildPersonStatBlock({
    required String name,
    required String primaryLabel,
    required int primaryValue,
    required String secondaryLabel,
    required int secondaryValue,
    required Color accent,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          SLSpacing.h8,
          _buildDualLineMetric(primaryLabel, primaryValue, accent),
          SLSpacing.h8,
          _buildDualLineMetric(
            secondaryLabel,
            secondaryValue,
            const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildDualLineMetric(String label, int value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6C6770),
            ),
          ),
        ),
        Text(
          '$value',
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
