part of '../../love_insights_screen.dart';

extension _InsightHeaderCardsExt on _LoveInsightsScreenState {
  // ── Couple Avatars with Clean Modern Connection ──
  Widget _buildCoupleAvatars(LoveInsightData insight) {
    final name1 = insight.nameU1.isNotEmpty ? insight.nameU1 : widget.nameU1;
    final name2 = insight.nameU2.isNotEmpty ? insight.nameU2 : widget.nameU2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sợi dây kết nối thanh mảnh, xinh xắn
          Positioned(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 50),
              color: const Color(0xFFF0E5DF),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAvatarCircle(name1, widget.avatarU1, isUser1: true),
              // Trái tim trung tâm ngọt ngào
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2F5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD6E0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5E7E).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF5E7E),
                    size: 16,
                  ),
                ),
              ),
              _buildAvatarCircle(name2, widget.avatarU2, isUser1: false),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildAvatarCircle(String name, String avatarUrl, {required bool isUser1}) {
    final fallbackAsset = isUser1 
        ? 'assets/images/male_avatar_sticker.json' 
        : 'assets/images/female_avatar_sticker.json';
        
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFFFD6E0),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5E7E).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF0E5DF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2E2427),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero Happiness Score Card (Clean Modern Style) ──
  Widget _buildHeaderCard(LoveInsightData insight) {
    final scoreTitle = _isSingle
        ? L10nService().translate('home_chshotng_328c7a')
        : L10nService().translate('home_chshnhphc_7c8e85');
    final dayLabel = _isSingle
        ? L10nService().translate('home_ngynghnh_05daff')
        : L10nService().translate('home_ngybnnhau_dd626e');
    final loveDays = insight.loveDays > 0 ? insight.loveDays : widget.loveDays;
    final levelLabel = _levelLabel(insight.loveScore);
    final progress = _progressToNextLevel(insight.loveScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF0E5DF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5E7E).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Score & Days Side by Side ──
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
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6B72),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: 0, end: insight.loveScore.toDouble()),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Text(
                              '${value.toInt()}',
                              style: SLTheme.quicksand(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2E2427),
                                height: 0.95,
                                letterSpacing: -1.0,
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '/100',
                            style: SLTheme.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFA699A0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Level Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD6E0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: Color(0xFFFF5E7E),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              levelLabel,
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2E2427),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Love Days Box ──
              Container(
                width: 98,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9F6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFE7DD),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 15,
                      color: Color(0xFFFF5E7E),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: loveDays.toDouble()),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '${value.toInt()}',
                          style: SLTheme.quicksand(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2E2427),
                            height: 0.95,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayLabel,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6B72),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ── Progress to Next Level ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSingle
                    ? L10nService().translate('home_tintrnhnhp_7d5499')
                    : L10nService().translate('home_tintrnhcpt_a15e61'),
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5E5056),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${progress.round()}%',
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFF5E7E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EFEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress / 100),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF5E7E),
                            Color(0xFFFF9E7A),
                          ],
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
          const SizedBox(height: 14),
          // ── Info Chips ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                icon: Icons.local_fire_department_rounded,
                text: L10nService().translateActiveDays(insight.activeDays),
                color: const Color(0xFFFF6B4A),
                background: const Color(0xFFFFF3ED),
              ),
              _buildInfoChip(
                icon: Icons.event_note_rounded,
                text: L10nService()
                    .translateMemoriesPerMonth(insight.memoryThisMonth),
                color: const Color(0xFF6366F1),
                background: const Color(0xFFF3EFFF),
              ),
              _buildInfoChip(
                icon: Icons.sentiment_satisfied_alt_rounded,
                text: L10nService().translatePositivity(insight.positivity),
                color: const Color(0xFF10B981),
                background: const Color(0xFFECFDF5),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  // ── Daily Tip Card (Cute & Sweet Style) ──
  Widget _buildDailyTipCard(LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0E5DF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '“${_dailyTip(insight)}”',
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }
}
