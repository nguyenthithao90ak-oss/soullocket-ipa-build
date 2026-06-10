part of '../../love_insights_screen.dart';

extension _InsightHeaderCardsExt on _LoveInsightsScreenState {
  Widget _buildHeaderCard(LoveInsightData insight) {
    final scoreColor = _scoreColor(insight.loveScore);
    final progress = _progressToNextLevel(insight.loveScore);
    final scoreTitle = _isSingle ? L10nService().translate('home_chshotng_328c7a') : L10nService().translate('home_chshnhphc_7c8e85');
    final dayLabel = _isSingle ? L10nService().translate('home_ngynghnh_05daff') : L10nService().translate('home_ngybnnhau_dd626e');
    final loveDays = insight.loveDays > 0 ? insight.loveDays : widget.loveDays;
    final levelLabel = _levelLabel(insight.loveScore);

    return Container(
      padding: SLSpacing.all20,
      decoration: _glassCardDecoration(
        borderColor: const Color(0xFFF6CDD8),
        shadowColor: const Color(0xFFD81B60).withValues(alpha: 0.14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scoreTitle,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF76717A),
                        letterSpacing: 0.2,
                      ),
                    ),
                    SLSpacing.h8,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [scoreColor.withValues(alpha: 0.8), scoreColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            '${insight.loveScore}',
                            style: SLTheme.quicksand(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 0.9,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '/100',
                            style: SLTheme.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF908C99),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h12,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.10),
                        borderRadius: SLRadius.pillAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSingle
                                ? Icons.local_fire_department_rounded
                                : Icons.favorite_rounded,
                            size: 15,
                            color: scoreColor,
                          ),
                          SLSpacing.w8,
                          Text(
                            levelLabel,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SLSpacing.w16,
              Container(
                width: 104,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _isSingle ? L10nService().translate('home_ngydng_ea4a15') : L10nService().translate('home_ngyyu_caafdc'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF9B82A1),
                      ),
                    ),
                    SLSpacing.h8,
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFD81B60), Color(0xFF8E24AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        '$loveDays',
                        style: SLTheme.quicksand(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 0.95,
                        ),
                      ),
                    ),
                    SLSpacing.h8,
                    Text(
                      dayLabel,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFC7B1CD),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          _buildSectionLabel(
            title: _isSingle
                ? L10nService().translate('home_tintrnhnhp_7d5499')
                : L10nService().translate('home_tintrnhcpt_a15e61'),
            trailing: '${progress.round()}%',
          ),
          SLSpacing.h8,
          SLSpacing.h8,
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scoreColor.withValues(alpha: 0.6),
                            scoreColor,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SLSpacing.h16,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(
                icon: Icons.local_fire_department_rounded,
                text: '${insight.activeDays} ngày tích cực',
                color: const Color(0xFFF5A623),
                background: const Color(0xFFFFF2D8),
              ),
              _buildInfoChip(
                icon: Icons.event_note_rounded,
                text: '${insight.memoryThisMonth} kỷ niệm/tháng',
                color: const Color(0xFF0F4C81),
                background: const Color(0xFFEAF4FF),
              ),
              _buildInfoChip(
                icon: Icons.sentiment_satisfied_alt_rounded,
                text: '${insight.positivity}% tích cực',
                color: const Color(0xFFD81B60),
                background: const Color(0xFFFFEAF2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTipCard(LoveInsightData insight) {
    return Container(
      padding: SLSpacing.all16,
      decoration: _softCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD1E3), Color(0xFFFFEAF2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.tips_and_updates_rounded,
              color: Color(0xFFD81B60),
              size: 24,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nService().translate('home_linhnhmnay_4773b5'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFA3A1A9),
                    letterSpacing: 0.25,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  _dailyTip(insight),
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: const Color(0xFF4B4650),
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
