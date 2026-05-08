part of '../../love_insights_screen.dart';

extension _InsightHeaderCardsExt on _LoveInsightsScreenState {
  Widget _buildHeaderCard(LoveInsightData insight) {
    final scoreColor = _scoreColor(insight.loveScore);
    final progress = _progressToNextLevel(insight.loveScore);
    final scoreTitle = _isSingle ? 'Chỉ số hoạt động' : 'Chỉ số hạnh phúc';
    final dayLabel = _isSingle ? 'ngày đồng hành' : 'ngày bên nhau';
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
                        Text(
                          '${insight.loveScore}',
                          style: SLTheme.quicksand(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF172033),
                            height: 0.9,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 5),
                          child: Text(
                            '/100',
                            style: SLTheme.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFABB1BA),
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
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: SLRadius.xlAll,
                  border: Border.all(color: const Color(0xFFF4D3DE)),
                ),
                child: Column(
                  children: [
                    Text(
                      _isSingle ? 'Ngày dùng' : 'Ngày yêu',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6D6872),
                      ),
                    ),
                    SLSpacing.h8,
                    Text(
                      '$loveDays',
                      style: SLTheme.quicksand(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F4C81),
                        height: 0.95,
                      ),
                    ),
                    SLSpacing.h8,
                    Text(
                      dayLabel,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B8390),
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
                ? 'Tiến trình nhịp sống tích cực'
                : 'Tiến trình cấp độ tiếp theo',
            trailing: '${progress.round()}%',
          ),
          SLSpacing.h8,
          ClipRRect(
            borderRadius: SLRadius.pillAll,
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress / 100,
              backgroundColor: const Color(0xFFF0F1F5),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF5),
              borderRadius: SLRadius.mdAll,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFFD81B60),
              size: 22,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lời nhắn hôm nay',
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
                    height: 1.5,
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
