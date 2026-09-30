part of '../../love_insights_view.dart';

extension _InsightHeaderCardsExt on LoveInsightsView {
  Widget _buildCoupleAvatars(LoveInsightData insight) {
    final firstName = _displayName(insight, isFirst: true);
    final secondName = _displayName(insight, isFirst: false);
    return Row(
      key: const ValueKey('insight-couple'),
      children: [
        Expanded(child: _buildAvatarCircle(firstName, avatarU1)),
        SizedBox(
          width: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 1, color: const Color(0xFFCD8F9F)),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB5871),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCE90A2)),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFFD5CC),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildAvatarCircle(secondName, avatarU2)),
      ],
    );
  }

  Widget _buildAvatarCircle(String name, String avatarUrl) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProfileAvatar(name: name, avatarUrl: avatarUrl, size: 58),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context, LoveInsightData insight) {
    final scoreTitle = context.tr(
      _isSingle ? 'home_chshotng_328c7a' : 'home_chshnhphc_7c8e85',
    );
    final dayLabel = context.tr(
      _isSingle ? 'home_ngynghnh_05daff' : 'home_ngybnnhau_dd626e',
    );
    final days = insight.loveDays > 0 ? insight.loveDays : loveDays;
    final progress = _progressToNextLevel(insight.loveScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('insight-hero'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF693149), Color(0xFF9B4B66)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3A52).withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -26,
                end: -24,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 190,
                    color: Colors.white.withValues(alpha: 0.045),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isSingle) ...[
                      _buildCoupleAvatars(insight),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1, color: Color(0xFFAA6F83)),
                      ),
                    ],
                    Text(
                      scoreTitle,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFDFE5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 280 ||
                            MediaQuery.textScalerOf(context).scale(16) > 22;
                        final score = _buildScoreRing(
                          context,
                          insight,
                          scoreTitle,
                        );
                        final details = Column(
                          crossAxisAlignment: stacked
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              _levelLabel(insight.loveScore),
                              textAlign: stacked
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: SLTheme.quicksand(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              '$days',
                              style: SLTheme.quicksand(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFFD2BF),
                              ),
                            ),
                            Text(
                              dayLabel,
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFDFE5),
                              ),
                            ),
                          ],
                        );
                        if (stacked) {
                          return Column(
                            children: [
                              score,
                              const SizedBox(height: 18),
                              details,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            score,
                            const SizedBox(width: 20),
                            Expanded(child: details),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(
                              _isSingle
                                  ? 'home_tintrnhnhp_7d5499'
                                  : 'home_tintrnhcpt_a15e61',
                            ),
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFDFE5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${progress.round()}%',
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      key: const ValueKey('insight-level-progress'),
                      value: progress / 100,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFFFC9AF),
                      backgroundColor: const Color(0xFFB2798D),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          icon: Icons.local_fire_department_outlined,
                          text: L10nService().translateActiveDays(
                            insight.activeDays,
                          ),
                          color: const Color(0xFFFFE6D7),
                          background: Colors.white.withValues(alpha: 0.09),
                        ),
                        _buildInfoChip(
                          icon: Icons.collections_bookmark_outlined,
                          text: L10nService().translateMemoriesPerMonth(
                            insight.memoryThisMonth,
                          ),
                          color: const Color(0xFFFFE6D7),
                          background: Colors.white.withValues(alpha: 0.09),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.tr('insight_score_note'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: const Color(0xFF806C73),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreRing(
    BuildContext context,
    LoveInsightData insight,
    String label,
  ) {
    final diameter =
        134 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    return Semantics(
      label: label,
      value: '${insight.loveScore}/100',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  key: const ValueKey('insight-score-ring'),
                  value: insight.loveScore.clamp(0, 100) / 100,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: const Color(0xFFFFCEB7),
                  backgroundColor: const Color(0xFFAD7488),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${insight.loveScore}',
                        style: SLTheme.quicksand(
                          fontSize: 46,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '/100',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFDFE5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTipCard(LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDE2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              size: 22,
              color: Color(0xFFAF653D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nService().translate('home_linhnhmnay_4773b5'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF996047),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _dailyTip(insight),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF573E35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
