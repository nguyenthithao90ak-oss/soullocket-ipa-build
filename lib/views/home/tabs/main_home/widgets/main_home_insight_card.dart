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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _buildHomeCardFirstTapWrapper(
        showHint: _showInsightCardFirstTapHintNotifier.value,
        onTap: _handleInsightCardTap,
        child: SLTheme.glassCard(
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
                  _buildInsightLoadingShimmer()
                else ...[
                  _buildInsightBubbleWrap(metrics, compact: true),
                  SLSpacing.h16,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFF0F6),
                          Color(0xFFF8F0FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: const Color(0xFFF9D8E5)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF6FA5).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      insight.suggestion,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        color: const Color(0xFF4A3060),
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
      ),
    );
  }

  Widget _buildInsightLoadingShimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () => setState(() {}),
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD6E7).withValues(alpha: value),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD6E7).withValues(alpha: value * 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        );
      },
    );
  }
}
