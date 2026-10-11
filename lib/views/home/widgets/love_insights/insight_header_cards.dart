part of '../../love_insights_view.dart';

extension _InsightHeaderCardsExt on LoveInsightsView {
  Widget _buildCoupleAvatars(BuildContext context, LoveInsightData insight) {
    final first = _buildAvatarCircle(
      context,
      _displayName(insight, isFirst: true),
      avatarU1,
    );
    final second = _buildAvatarCircle(
      context,
      _displayName(insight, isFirst: false),
      avatarU2,
    );
    return LayoutBuilder(
      key: const ValueKey('insight-couple'),
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(12) > 18) {
          return Column(children: [first, const SizedBox(height: 12), second]);
        }
        return Row(
          children: [
            Expanded(child: first),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.favorite_rounded,
                color: _InsightStyle.accent(context, const Color(0xFFE7849D)),
                size: 18,
              ),
            ),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildAvatarCircle(
    BuildContext context,
    String name,
    String avatarUrl,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProfileAvatar(name: name, avatarUrl: avatarUrl, size: 32),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _InsightStyle.accent(context, const Color(0xFF71465A)),
            ),
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _InsightStyle.wash(context, const Color(0xFFFFE3EC)),
                _InsightStyle.wash(context, const Color(0xFFFFF0E7)),
                _InsightStyle.wash(context, const Color(0xFFF6EFFF)),
              ],
            ),
            border: Border.all(color: _InsightStyle.surface(context), width: 2),
            boxShadow: [
              BoxShadow(
                color: _InsightStyle.accent(
                  context,
                  const Color(0xFFCC7C95),
                ).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isSingle) _buildCoupleAvatars(context, insight),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  final daysText = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: largeText
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$days',
                        style: SLTheme.quicksand(
                          fontSize: 44,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: _InsightStyle.accent(
                            context,
                            const Color(0xFFA34268),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabel,
                        textAlign: largeText
                            ? TextAlign.center
                            : TextAlign.start,
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: _InsightStyle.accent(
                            context,
                            const Color(0xFF805B6C),
                          ),
                        ),
                      ),
                    ],
                  );
                  final art = _InsightCompanionArt(single: _isSingle);
                  if (largeText) {
                    return Column(
                      children: [
                        SizedBox(width: 180, height: 140, child: art),
                        daysText,
                        const SizedBox(height: 20),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: SizedBox(height: 150, child: art),
                      ),
                      const SizedBox(width: 10),
                      Expanded(flex: 5, child: daysText),
                    ],
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _InsightStyle.surface(context).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 210 ||
                            MediaQuery.textScalerOf(context).scale(14) > 21;
                        final details = Column(
                          crossAxisAlignment: stacked
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              scoreTitle,
                              textAlign: stacked
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: _InsightStyle.accent(
                                  context,
                                  const Color(0xFF8B6B7A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _levelLabel(insight.loveScore),
                              textAlign: stacked
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: SLTheme.quicksand(
                                fontSize: 17,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: _InsightStyle.accent(
                                  context,
                                  const Color(0xFF713B59),
                                ),
                              ),
                            ),
                          ],
                        );
                        final score = _buildScoreRing(
                          context,
                          insight,
                          scoreTitle,
                        );
                        if (stacked) {
                          return Column(
                            children: [
                              score,
                              const SizedBox(height: 12),
                              details,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            score,
                            const SizedBox(width: 14),
                            Expanded(child: details),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
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
                              fontSize: 10,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: _InsightStyle.accent(
                                context,
                                const Color(0xFF8B6B7A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${progress.round()}%',
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _InsightStyle.accent(
                              context,
                              const Color(0xFFA34268),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      key: const ValueKey('insight-level-progress'),
                      value: progress / 100,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(8),
                      color: _InsightStyle.accent(
                        context,
                        const Color(0xFFE88FA9),
                      ),
                      backgroundColor: _InsightStyle.wash(
                        context,
                        const Color(0xFFF8E8EE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    context,
                    icon: Icons.local_fire_department_rounded,
                    text: L10nService().translateActiveDays(insight.activeDays),
                    color: _InsightStyle.accent(
                      context,
                      const Color(0xFF985B24),
                    ),
                    background: _InsightStyle.wash(
                      context,
                      const Color(0xFFFFF5DC),
                    ),
                  ),
                  _buildInfoChip(
                    context,
                    icon: Icons.collections_bookmark_rounded,
                    text: L10nService().translateMemoriesPerMonth(
                      insight.memoryThisMonth,
                    ),
                    color: _InsightStyle.accent(
                      context,
                      const Color(0xFF79529E),
                    ),
                    background: _InsightStyle.wash(
                      context,
                      const Color(0xFFF3E9FF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            context.tr('insight_score_note'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: _InsightStyle.accent(context, const Color(0xFF806C73)),
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
        76 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
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
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: _InsightStyle.accent(context, const Color(0xFFDC7B9E)),
                  backgroundColor: _InsightStyle.wash(
                    context,
                    const Color(0xFFF7E5EC),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${insight.loveScore}',
                        style: SLTheme.quicksand(
                          fontSize: 27,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: _InsightStyle.accent(
                            context,
                            const Color(0xFFA34268),
                          ),
                        ),
                      ),
                      Text(
                        '/100',
                        style: SLTheme.quicksand(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _InsightStyle.accent(
                            context,
                            const Color(0xFF957386),
                          ),
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

  Widget _buildDailyTipCard(BuildContext context, LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _InsightStyle.wash(context, const Color(0xFFFFF3D9)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _InsightStyle.wash(context, const Color(0xFFFFE7B4)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.rotate(
            angle: -0.10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _InsightStyle.surface(context),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: _InsightStyle.accent(
                      context,
                      const Color(0xFFD6AE68),
                    ).withValues(alpha: 0.14),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.mark_email_unread_rounded,
                size: 25,
                color: _InsightStyle.accent(context, const Color(0xFFD89B46)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nService().translate('home_linhnhmnay_4773b5'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _InsightStyle.accent(
                      context,
                      const Color(0xFF946022),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _dailyTip(insight),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: _InsightStyle.accent(
                      context,
                      const Color(0xFF654E38),
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
}
