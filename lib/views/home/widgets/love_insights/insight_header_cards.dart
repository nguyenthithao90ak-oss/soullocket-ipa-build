part of '../../love_insights_screen.dart';

extension _InsightHeaderCardsExt on _LoveInsightsScreenState {
  Widget _buildHeaderCard(LoveInsightData insight) {
    final scoreColor = _scoreColor(insight.loveScore);
    final progress = _progressToNextLevel(insight.loveScore);
    final scoreTitle = _isSingle
        ? L10nService().translate('home_chshotng_328c7a')
        : L10nService().translate('home_chshnhphc_7c8e85');
    final dayLabel = _isSingle
        ? L10nService().translate('home_ngynghnh_05daff')
        : L10nService().translate('home_ngybnnhau_dd626e');
    final loveDays = insight.loveDays > 0 ? insight.loveDays : widget.loveDays;
    final levelLabel = _levelLabel(insight.loveScore);

    return Container(
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFFFA6C9).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 4,
            offset: Offset(0, -2),
            spreadRadius: 1,
            blurStyle: BlurStyle.inner,
          ),
        ],
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
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: insight.loveScore.toDouble()),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  scoreColor.withValues(alpha: 0.8),
                                  scoreColor
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                '${value.toInt()}',
                                style: SLTheme.quicksand(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 0.9,
                                ),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            '/100',
                            style: SLTheme.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF908C99),
                            ),
                          ),
                        ),
                      ],
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scaleXY(end: 1.02, duration: 1000.ms, curve: Curves.easeInOutSine),
                    SLSpacing.h12,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.10),
                        borderRadius: SLRadius.pillAll,
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSingle
                                ? Icons.local_fire_department_rounded
                                : Icons.favorite_rounded,
                            size: 16,
                            color: scoreColor,
                          ),
                          SLSpacing.w8,
                          Text(
                            levelLabel,
                            style: SLTheme.quicksand(
                              fontSize: 14,
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
                width: 110,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFFFF0F7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _isSingle
                          ? L10nService().translate('home_ngydng_ea4a15')
                          : L10nService().translate('home_ngyyu_caafdc'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF9B82A1),
                      ),
                    ),
                    SLSpacing.h8,
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: loveDays.toDouble()),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFD81B60), Color(0xFF8E24AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            '${value.toInt()}',
                            style: SLTheme.quicksand(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 0.95,
                            ),
                          ),
                        );
                      },
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
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress / 100),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scoreColor.withValues(alpha: 0.5),
                                scoreColor,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      );
                    },
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
                text: L10nService().translateActiveDays(insight.activeDays),
                color: const Color(0xFFF5A623),
                background: const Color(0xFFFFF2D8),
              ),
              _buildInfoChip(
                icon: Icons.event_note_rounded,
                text: L10nService()
                    .translateMemoriesPerMonth(insight.memoryThisMonth),
                color: const Color(0xFF0F4C81),
                background: const Color(0xFFEAF4FF),
              ),
              _buildInfoChip(
                icon: Icons.sentiment_satisfied_alt_rounded,
                text: L10nService().translatePositivity(insight.positivity),
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
    String tipEmoji = '💌';
    if (insight.loveScore >= 85) {
      tipEmoji = '🔥';
    } else if (insight.loveScore >= 70) {
      tipEmoji = '✨';
    } else if (insight.loveScore >= 40) {
      tipEmoji = '💖';
    } else {
      tipEmoji = '💡';
    }

    Widget emojiWidget = Text(tipEmoji, style: const TextStyle(fontSize: 24));
    
    // Áp dụng animation tuỳ theo emoji
    if (insight.loveScore >= 85) {
      emojiWidget = emojiWidget.animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(end: 1.15, duration: 600.ms, curve: Curves.easeInOut)
          .tint(color: Colors.orange.withValues(alpha: 0.2));
    } else if (insight.loveScore >= 70) {
      emojiWidget = emojiWidget.animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shake(hz: 3, curve: Curves.easeInOut, duration: 1.seconds);
    } else {
      emojiWidget = emojiWidget.animate(onPlay: (controller) => controller.repeat(reverse: true))
          .slideY(end: -0.15, duration: 800.ms, curve: Curves.easeInOut);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F5), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF73A6).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 8,
            offset: Offset(0, -4),
            spreadRadius: 2,
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF73A6).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: emojiWidget,
            ),
          ),
          SLSpacing.w16,
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
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .shimmer(duration: 4.seconds, color: Colors.white.withValues(alpha: 0.6));
  }
}
