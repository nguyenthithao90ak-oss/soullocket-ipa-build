// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../main_home_tab.dart';

extension _MainHomeInsightCardExt on _MainHomeTabState {
  Widget _buildLegacyInsightCard({
    required bool isSingle,
    required String nameU1,
    required String nameU2,
  }) {
    final insight = _insightData;
    final metrics = insight == null
        ? const <_InsightBubbleSpec>[]
        : [
            if (!isSingle)
              _InsightBubbleSpec(
                label: nameU1.trim(),
                value: insight.loveU1,
                color: const Color(0xFF42A5F5),
                phase: 0.4,
              ),
            _InsightBubbleSpec(
              label: isSingle
                  ? L10nService().translate('home_hotng_faccd7')
                  : 'LOVE',
              value: insight.loveScore,
              color: const Color(0xFFD81B60),
              phase: 1.7,
              emphasize: true,
            ),
            if (!isSingle)
              _InsightBubbleSpec(
                label: nameU2.trim(),
                value: insight.loveU2,
                color: const Color(0xFF7C83FD),
                phase: 2.7,
              ),
          ];

    return _buildHomeCardFirstTapWrapper(
      showHint: _showInsightCardFirstTapHint,
      onTap: _handleInsightCardTap,
      child: _buildGlassHomeCard(
        child: Container(
          width: double.infinity,
          padding: SLSpacing.all16,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFD81B60),
                  size: 18,
                ),
                SLSpacing.w8,
                Flexible(
                  child: Text(
                    isSingle
                        ? L10nService().translate('home_thngkcnhn_e82ba1')
                        : L10nService().translate('home_chshnhphc_243d83'),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                ),
                SLSpacing.w8,
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFD81B60),
                ),
              ],
            ),
            SLSpacing.h16,
            if (insight == null)
              Container(
                width: double.infinity,
                padding: SLSpacing.all12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5FA),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(color: const Color(0xFFF8BBD0)),
                ),
                child: Text(
                  isSingle
                      ? L10nService().translate('home_thngkshink_2cfa0a')
                      : L10nService().translate('home_chsshinkhi_2113ba'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    color: const Color(0xFFD81B60),
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else ...[
              _buildInsightBubbleWrap(metrics, compact: true),
              SLSpacing.h16,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      const Color(0xFFFFF3F8).withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(color: const Color(0xFFF9D8E5)),
                ),
                child: Text(
                  insight.suggestion,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    color: const Color(0xFF555555),
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
