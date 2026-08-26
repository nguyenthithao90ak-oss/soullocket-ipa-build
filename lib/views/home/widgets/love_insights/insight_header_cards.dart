part of '../../love_insights_screen.dart';

extension _InsightHeaderCardsExt on _LoveInsightsScreenState {
  // ── Couple Avatars ──
  Widget _buildCoupleAvatars(LoveInsightData insight) {
    final name1 = insight.nameU1.isNotEmpty ? insight.nameU1 : widget.nameU1;
    final name2 = insight.nameU2.isNotEmpty ? insight.nameU2 : widget.nameU2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatarCircle(name1, widget.avatarU1, isUser1: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF4F87),
                  size: 24,
                ),
                const SizedBox(height: 2),
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4F87), Color(0xFF9B7AE8)],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          _buildAvatarCircle(name2, widget.avatarU2, isUser1: false),
        ],
      ),
    ).animate().fade(duration: 500.ms).slideY(begin: -0.1, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildAvatarCircle(String name, String avatarUrl, {required bool isUser1}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fallbackAsset = isUser1 
        ? 'assets/images/male_avatar_sticker.json' 
        : 'assets/images/female_avatar_sticker.json';
        
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFDCE8), Color(0xFFE9DDFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFF4F87).withValues(alpha: 0.3),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4F87).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            image: avatarUrl.trim().isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl.trim()),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl.trim().isEmpty
              ? ClipOval(
                  child: Lottie.asset(
                    fallbackAsset,
                    fit: BoxFit.cover,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF332C35),
          ),
        ),
      ],
    );
  }

  // ── Hero Card ──
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFDCE8).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4F87).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Score + Days side by side ──
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8D8490),
                        letterSpacing: 0.2,
                      ),
                    ),
                    SLSpacing.h8,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: 0, end: insight.loveScore.toDouble()),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFF4F87), Color(0xFF9B7AE8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                '${value.toInt()}',
                                style: SLTheme.quicksand(
                                  fontSize: 58,
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
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFBDB5C2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h10,
                    // ── Level badge ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEF4),
                        borderRadius: SLRadius.pillAll,
                        border: Border.all(
                          color: const Color(0xFFFFDCE8),
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
                            size: 15,
                            color: const Color(0xFFFF4F87),
                          ),
                          SLSpacing.w8,
                          Flexible(
                            child: Text(
                              levelLabel,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFF4F87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SLSpacing.w12,
              // ── Days badge ──
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7FA), Color(0xFFFFEEF4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFFDCE8),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: const Color(0xFFFF4F87).withValues(alpha: 0.6),
                    ),
                    SLSpacing.h8,
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: loveDays.toDouble()),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF4F87), Color(0xFF9B7AE8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            '${value.toInt()}',
                            style: SLTheme.quicksand(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 0.95,
                            ),
                          ),
                        );
                      },
                    ),
                    SLSpacing.h4,
                    Text(
                      dayLabel,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8D8490),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          // ── Progress bar ──
          _buildSectionLabel(
            title: _isSingle
                ? L10nService().translate('home_tintrnhnhp_7d5499')
                : L10nService().translate('home_tintrnhcpt_a15e61'),
            trailing: '${progress.round()}%',
          ),
          SLSpacing.h10,
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDCE8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress / 100),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF85A2), Color(0xFFFF4F87), Color(0xFF9B7AE8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SLSpacing.h16,
          // ── Info chips ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                icon: Icons.local_fire_department_rounded,
                text: L10nService().translateActiveDays(insight.activeDays),
                color: const Color(0xFFFF6B9D),
                background: const Color(0xFFFFEEF4),
              ),
              _buildInfoChip(
                icon: Icons.event_note_rounded,
                text: L10nService()
                    .translateMemoriesPerMonth(insight.memoryThisMonth),
                color: const Color(0xFF9B7AE8),
                background: const Color(0xFFF3E5FF),
              ),
              _buildInfoChip(
                icon: Icons.sentiment_satisfied_alt_rounded,
                text: L10nService().translatePositivity(insight.positivity),
                color: const Color(0xFFFF4F87),
                background: const Color(0xFFFFE4EF),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 600.ms).slideY(begin: 0.08, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }

  // ── Daily Tip Card ──
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEFF5), Color(0xFFFFF8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFDCE8),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4F87).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(tipEmoji, style: const TextStyle(fontSize: 20)),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8D8490),
                    letterSpacing: 0.2,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  _dailyTip(insight),
                  style: SLTheme.quicksand(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                    color: const Color(0xFF332C35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms, delay: 100.ms).slideY(begin: 0.06, end: 0, duration: 500.ms, delay: 100.ms, curve: Curves.easeOut);
  }
}
