part of '../../soul_rhythm_game.dart';

extension _SoulRhythmGameOverScreen on _SoulRhythmGameState {
  Widget _buildGameOverScreen() {
    int total = max(1, _hits + _misses);
    int acc = ((_hits / total) * 100).round();
    String grade = (acc >= 95 && _misses == 0)
        ? 'S'
        : acc >= 90
            ? 'A'
            : acc >= 80
                ? 'B'
                : acc >= 70
                    ? 'C'
                    : 'D';

    Color gradeColor = grade == 'S'
        ? const Color(0xFF00E5FF)
        : grade == 'A'
            ? const Color(0xFF76FF03)
            : grade == 'B'
                ? const Color(0xFFFFEB3B)
                : grade == 'C'
                    ? const Color(0xFFFF9900)
                    : const Color(0xFFFF0055);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xF2050516),
              Color(0xF2140A24),
              Color(0xF2081B31),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 360), // Ngắn và hẹp hơn
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28), // Bo góc mềm mại
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E1E2E).withValues(alpha: 0.9),
                        const Color(0xFF141420).withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: gradeColor.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_newBestAchieved)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEB3B).withValues(alpha: 0.15),
                            borderRadius: SLRadius.pillAll,
                            border: Border.all(
                              color: const Color(0xFFFFEB3B).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'NEW BEST $_highScore',
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFFEB3B),
                            ),
                          ),
                        ),
                      Text(
                        'RESULTS · $_displayTrackLabel',
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white60,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FINAL SCORE',
                                        style: SLTheme.quicksand(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white54,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$_score',
                                        style: SLTheme.quicksand(
                                          fontSize: 52,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1,
                                          shadows: [
                                            Shadow(
                                              color: Colors.white.withValues(alpha: 0.42),
                                              blurRadius: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        gradeColor.withValues(alpha: 0.30),
                                        gradeColor.withValues(alpha: 0.08),
                                        Colors.transparent,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: gradeColor.withValues(alpha: 0.52),
                                      width: 1.4,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    grade,
                                    style: SLTheme.quicksand(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: gradeColor,
                                      shadows: [
                                        Shadow(color: gradeColor, blurRadius: 15),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildResultStatTile(
                                    'Accuracy',
                                    '$acc%',
                                    const Color(0xFF76FF03),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildResultStatTile(
                                    'Max combo',
                                    '$_maxCombo',
                                    const Color(0xFFFFEB3B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildResultStatTile(
                                    'Perfect',
                                    '$_perfects',
                                    const Color(0xFF00E5FF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildResultStatTile(
                                    'Miss',
                                    '$_misses',
                                    const Color(0xFFFF5E8A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_showReviveOffer)
                        _buildReviveOfferCard()
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.flag_rounded,
                                color: Color(0xFFFFC94D),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Run kết thúc. Bạn có thể chơi lại ngay hoặc về menu chọn stage khác.',
                                  style: SLTheme.quicksand(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    height: 1.28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      _buildResultActionButton(
                        label: 'CHƠI TIẾP VÁN MỚI',
                        icon: Icons.replay_rounded,
                        onTap: _startGame,
                        primary: true,
                      ),
                      const SizedBox(height: 12),
                      _buildResultActionButton(
                        label: 'VỀ TRANG CHỦ',
                        icon: Icons.home_rounded,
                        onTap: _backToMenu,
                        primary: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white54,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviveOfferCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0C2336).withValues(alpha: 0.96),
            const Color(0xFF152544).withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF6FE8FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REVIVE READY',
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6FE8FF),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hồi sinh đầy HP để tiếp tục stage hiện tại.',
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildResultActionButton(
            label: _isWatchingReviveAd
                ? 'ĐANG XỬ LÝ HỒI SINH...'
                : 'XEM QUẢNG CÁO HỒI SINH',
            icon: _isWatchingReviveAd
                ? Icons.hourglass_top_rounded
                : Icons.play_circle_fill_rounded,
            onTap: _isWatchingReviveAd ? null : _watchReviveAd,
            primary: false,
            accent: const Color(0xFF00E5FF),
            showLoader: _isWatchingReviveAd,
          ),
        ],
      ),
    );
  }

  Widget _buildResultActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool primary,
    Color? accent,
    bool showLoader = false,
  }) {
    final actionColor = accent ?? const Color(0xFFFF4D88);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFFFF0055), Color(0xFFFF6B9F)],
                  )
                : LinearGradient(
                    colors: [
                      actionColor.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary
                  ? Colors.white.withValues(alpha: 0.08)
                  : actionColor.withValues(alpha: 0.34),
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF0055).withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showLoader)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
