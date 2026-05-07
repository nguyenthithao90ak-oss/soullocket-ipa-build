part of '../soul_block_game.dart';

const LinearGradient _kSoulSplashProgressGradient = LinearGradient(
  colors: <Color>[
    Color(0x00FFD978),
    Color(0xFFFF8E53),
    Color(0xFFFF5FA2),
    Color(0xFF7C7BFF),
    Color(0xFF53E0FF),
    Color(0x00FFD978),
  ],
  stops: <double>[0, 0.14, 0.34, 0.58, 0.84, 1],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const List<double> _kMemoryBurstSparkleAngles = <double>[
  0,
  pi / 3,
  (2 * pi) / 3,
  pi,
  (4 * pi) / 3,
  (5 * pi) / 3,
];

const Offset _kExplosionOrigin = Offset.zero;

extension _SoulBlockPanels on _SoulBlockGameState {
  Widget _buildSplashScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xFF182448).withValues(alpha: 0.96),
                    const Color(0xFF101A39).withValues(alpha: 0.98),
                    const Color(0xFF070D1E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _kSoulChrome.withValues(alpha: 0.18),
                  width: 1.15,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF070C19).withValues(alpha: 0.56),
                    blurRadius: 30,
                    spreadRadius: -10,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: const Color(0xFF4B65FF).withValues(alpha: 0.14),
                    blurRadius: 34,
                    spreadRadius: -18,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.10),
                          const Color(0xFF8B5CFF).withValues(alpha: 0.10),
                          const Color(0xFF3CD8FF).withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: _buildGameLogo(size: 94),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.gameTitle,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _kSoulIvory,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preparing a deeper neon board',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.74),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        width: double.infinity,
                        height: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.white.withValues(alpha: 0.05),
                                const Color(0xFF111B39),
                                Colors.black.withValues(alpha: 0.18),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: AnimatedBuilder(
                            animation: _playPulseController,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 0.42,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: _kSoulSplashProgressGradient,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(0xFF53E0FF)
                                            .withValues(alpha: 0.34),
                                        blurRadius: 14,
                                        spreadRadius: -6,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  _playPulseController.value * 150,
                                  0,
                                ),
                                child: child,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Blocks, tray, score and effects are syncing now',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 11.6,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadErrorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF00C3FF),
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                'Khởi động thất bại',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _loadError ?? '',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _retryBootstrap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C3FF),
                    foregroundColor: const Color(0xFF03131F),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Thử lại',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMainMenu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 18),
          _buildGameLogo(size: 104),
          const SizedBox(height: 26),
          Text(
            widget.gameTitle,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fast • Addictive • Endless',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withOpacity(0.12),
                  const Color(0xFFFFD166).withOpacity(0.09),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 14,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFCC00),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Best ${_formatNumber(_bestScore)}',
                  style: SLTheme.quicksand(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _playPulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _isOpeningGameplay ? 1.0 : _playPulseScale,
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF050B18).withValues(alpha: 0.34),
                    blurRadius: 24,
                    spreadRadius: -12,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: const Color(0xFF6F69FF).withValues(alpha: 0.10),
                    blurRadius: 18,
                    spreadRadius: -14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isOpeningGameplay ? null : _startSessionFromMenu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6AD7FF),
                    foregroundColor: const Color(0xFF07111F),
                    disabledBackgroundColor: const Color(0xFF314A72),
                    disabledForegroundColor: const Color(0xFFDDE9FF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: _isOpeningGameplay
                        ? Row(
                            key: const ValueKey<String>('play-loading'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF07111F),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'ĐANG VÀO',
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'PLAY',
                            key: const ValueKey<String>('play-idle'),
                            style: SLTheme.quicksand(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _MenuMiniButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: _openSettingsSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuMiniButton(
                  icon: Icons.leaderboard_rounded,
                  label: 'Scores',
                  onTap: _openLeaderboardSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuMiniButton(
                  icon: Icons.block_rounded,
                  label: 'No Ads',
                  onTap: _openPremiumStore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildGameplayScreen() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compactHeight = constraints.maxHeight < 760;
        final bool narrowWidth = constraints.maxWidth < 420;
        final bool ultraCompact =
            constraints.maxHeight < 700 || constraints.maxWidth < 390;
        final bool wideStage = constraints.maxWidth >= 760;
        final bool compactLayout = compactHeight || narrowWidth;
        final double horizontalPadding = wideStage
            ? 12
            : ultraCompact
                ? 4
                : narrowWidth
                    ? 6
                    : 8;
        final double stageGap = ultraCompact
            ? 6
            : compactLayout
                ? 8
                : 10;
        final double topBarHeight = ultraCompact
            ? 82
            : compactLayout
                ? 90
                : 104;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            ultraCompact
                ? 4
                : compactLayout
                    ? 6
                    : 10,
            horizontalPadding,
            ultraCompact
                ? 2
                : compactLayout
                    ? 4
                    : 6,
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: topBarHeight,
                child: _buildGameplayTopBar(
                  compact: compactLayout,
                  ultraCompact: ultraCompact,
                ),
              ),
              SizedBox(height: stageGap),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wideStage ? 980 : 860,
                    ),
                    child: LayoutBuilder(
                      builder: (BuildContext context,
                          BoxConstraints stageConstraints) {
                        final double minTrayHeight = ultraCompact
                            ? 76
                            : compactLayout
                                ? 84
                                : 96;
                        final double maxTrayHeight = ultraCompact
                            ? 96
                            : compactLayout
                                ? 108
                                : 124;
                        double trayHeight = (stageConstraints.maxHeight *
                                (ultraCompact
                                    ? 0.175
                                    : compactLayout
                                        ? 0.19
                                        : 0.205))
                            .clamp(minTrayHeight, maxTrayHeight)
                            .toDouble();
                        double boardExtent = min(
                          stageConstraints.maxWidth,
                          stageConstraints.maxHeight - trayHeight - stageGap,
                        );
                        if (boardExtent < 244) {
                          final double deficit = 244 - boardExtent;
                          trayHeight = max(minTrayHeight, trayHeight - deficit);
                          boardExtent = min(
                            stageConstraints.maxWidth,
                            stageConstraints.maxHeight - trayHeight - stageGap,
                          );
                        }
                        final double safeBoardExtent = max(0.0, boardExtent);
                        final bool trayCompact =
                            compactLayout || safeBoardExtent < 380;

                        return Column(
                          children: <Widget>[
                            if (safeBoardExtent > 0)
                              SizedBox.square(
                                dimension: safeBoardExtent,
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _dragVisualTick,
                                  builder: (context, _, __) {
                                    return _buildBoardPanel();
                                  },
                                ),
                              ),
                            SizedBox(height: stageGap),
                            SizedBox(
                              height: trayHeight,
                              child: ValueListenableBuilder<int>(
                                valueListenable: _trayVisualTick,
                                builder: (context, _, __) {
                                  return _buildTrayPanel(compact: trayCompact);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameplayTopBar({
    required bool compact,
    required bool ultraCompact,
  }) {
    final double sideGap = ultraCompact
        ? 6
        : compact
            ? 8
            : 10;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: _buildHeroScoreCard(
                  compact: compact,
                  ultraCompact: ultraCompact,
                ),
              ),
              Positioned(
                top: ultraCompact
                    ? 8
                    : compact
                        ? 10
                        : 12,
                right: ultraCompact
                    ? 8
                    : compact
                        ? 10
                        : 12,
                child: SizedBox(
                  width: ultraCompact
                      ? 40
                      : compact
                          ? 44
                          : 48,
                  height: ultraCompact
                      ? 40
                      : compact
                          ? 44
                          : 48,
                  child: _buildSettingsButton(
                    compact: compact,
                    ultraCompact: ultraCompact,
                    mini: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: sideGap),
        SizedBox(
          width: ultraCompact
              ? 108
              : compact
                  ? 116
                  : 128,
          child: Column(
            children: <Widget>[
              Expanded(
                child: _TopScoreCard(
                  label: 'BEST',
                  icon: Icons.emoji_events_rounded,
                  accent: const Color(0xFFFFD166),
                  value: _formatNumber(_bestScore),
                  dense: compact,
                  ultraCompact: ultraCompact,
                ),
              ),
              SizedBox(height: sideGap),
              Expanded(
                child: _TopScoreCard(
                  label: 'LINES',
                  icon: Icons.grid_4x4_rounded,
                  accent: const Color(0xFF7AE7FF),
                  value: _formatNumber(_clearedLines),
                  dense: compact,
                  ultraCompact: ultraCompact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroScoreCard({
    required bool compact,
    required bool ultraCompact,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        ultraCompact
            ? 12
            : compact
                ? 14
                : 16,
        ultraCompact
            ? 10
            : compact
                ? 12
                : 14,
        ultraCompact
            ? 12
            : compact
                ? 14
                : 16,
        ultraCompact
            ? 10
            : compact
                ? 12
                : 14,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF6AA6FF),
            Color(0xFF3E7ED9),
            Color(0xFF234B98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF162F6E).withOpacity(0.34),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('score-display-$_scorePulseTick-$_score'),
        tween: Tween<double>(begin: 0.95, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_combo > 1)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ultraCompact
                      ? 6
                      : compact
                          ? 7
                          : 9,
                  vertical: ultraCompact
                      ? 4
                      : compact
                          ? 5
                          : 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFD166).withOpacity(0.24),
                  ),
                ),
                child: Text(
                  'COMBO x$_combo',
                  style: SLTheme.quicksand(
                    fontSize: ultraCompact
                        ? 8.6
                        : compact
                            ? 9.4
                            : 10.2,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFFF1C2),
                    letterSpacing: 0.25,
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ultraCompact
                      ? 6
                      : compact
                          ? 7
                          : 9,
                  vertical: ultraCompact
                      ? 4
                      : compact
                          ? 5
                          : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Text(
                  'RUN SCORE',
                  style: SLTheme.quicksand(
                    fontSize: ultraCompact
                        ? 8.4
                        : compact
                            ? 9.2
                            : 10.0,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.78),
                    letterSpacing: ultraCompact
                        ? 0.58
                        : compact
                            ? 0.8
                            : 0.95,
                  ),
                ),
              ),
            const Spacer(),
            Text(
              _formatNumber(_score),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: ultraCompact
                    ? 30
                    : compact
                        ? 34
                        : 42,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.12,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            if (!ultraCompact) ...<Widget>[
              SizedBox(height: compact ? 2 : 4),
              Text(
                'Keep the board breathing and clear chains fast',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: compact ? 9.4 : 10.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.70),
                  letterSpacing: compact ? 0.04 : 0.12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton({
    required bool compact,
    required bool ultraCompact,
    bool mini = false,
  }) {
    final double radius = mini
        ? (ultraCompact
            ? 13
            : compact
                ? 15
                : 16)
        : 18;
    final double iconSize =
        mini ? (ultraCompact ? 18 : 20) : (ultraCompact ? 18 : 20);
    return InkWell(
      onTap: _openSettingsSheet,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        height: mini ? double.infinity : (compact ? 50 : 56),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              _kSoulPanelTop,
              _kSoulPanelMid,
              _kSoulPanelBottom,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: _kSoulChrome.withOpacity(0.24),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: mini ? 10 : 12,
              spreadRadius: -8,
              offset: Offset(0, mini ? 6 : 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Future<void> _openLeaderboardSheet() async {
    _emitClickFeedback();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Local Leaderboard',
                          style: SLTheme.quicksand(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    if (_leaderboard.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Chưa có lượt chơi nào được lưu.',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _leaderboard.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _leaderboard[index];
                            return _LeaderboardTile(
                              rank: index + 1,
                              score: _formatNumber(item.score),
                              lines: item.lines,
                              stamp: item.stampLabel,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSettingsSheet() async {
    _emitClickFeedback();
    await _refreshPremiumStatus();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        var sound = _soundEnabled;
        var vibration = _vibrationEnabled;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                'Settings',
                                style: SLTheme.quicksand(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _view == _SoulGameView.gameplay
                                ? 'Điều chỉnh nhanh, về menu, restart hoặc trở lại home.'
                                : 'Điều chỉnh âm thanh và mở nhanh các tính năng của game.',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SettingsSwitchTile(
                            icon: Icons.music_note_rounded,
                            title: 'Sound',
                            value: sound,
                            onChanged: (value) async {
                              setModalState(() => sound = value);
                              await _setSoundEnabled(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          _SettingsSwitchTile(
                            icon: Icons.vibration_rounded,
                            title: 'Vibration',
                            value: vibration,
                            onChanged: (value) async {
                              setModalState(() => vibration = value);
                              await _setVibrationEnabled(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              _SettingsActionButton(
                                icon: Icons.home_rounded,
                                label: 'Home',
                                accent: const Color(0xFF67E8FF),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await _exitToHomeFromSettings();
                                },
                              ),
                              _SettingsActionButton(
                                icon: Icons.leaderboard_rounded,
                                label: 'Scores',
                                accent: const Color(0xFFFFD166),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await _openLeaderboardSheet();
                                },
                              ),
                              _SettingsActionButton(
                                icon: Icons.workspace_premium_rounded,
                                label: 'No Ads',
                                accent: const Color(0xFFB794F4),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await _openPremiumStore();
                                },
                              ),
                              _SettingsActionButton(
                                icon: _view == _SoulGameView.gameplay
                                    ? Icons.refresh_rounded
                                    : Icons.play_arrow_rounded,
                                label: _view == _SoulGameView.gameplay
                                    ? 'Restart'
                                    : 'Play',
                                accent: const Color(0xFF7CF29C),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _restartCurrentRunFromSettings();
                                },
                              ),
                              _SettingsActionButton(
                                icon: Icons.grid_view_rounded,
                                label: 'Menu',
                                accent: const Color(0xFF9FB3FF),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _returnToMenuFromSettings();
                                },
                                enabled: _view == _SoulGameView.gameplay,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBannerDock() {
    final BannerAd? bannerAd = _bannerAd;
    if (bannerAd == null) {
      return const SizedBox.shrink();
    }

    final double dockHeight = max(
      _SoulBlockGameState._bannerDockBaseHeight,
      bannerAd.size.height.toDouble() + 4,
    );
    return SafeArea(
      top: false,
      child: Container(
        height: dockHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFF0B1220),
              Color(0xFF0F172A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: bannerAd.size.width.toDouble(),
          height: bannerAd.size.height.toDouble(),
          child: AdWidget(ad: bannerAd),
        ),
      ),
    );
  }

  Widget _buildFloatingToast() {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.24),
      end: const Offset(0, -0.62),
    ).animate(
      CurvedAnimation(
        parent: _floatingController,
        curve: Curves.easeOutCubic,
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _floatingController,
              curve: Curves.easeOut,
            ),
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _floatingController,
                  curve: Curves.easeOutBack,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        _floatingTextColor.withValues(alpha: 0.34),
                        _floatingTextColor.withValues(alpha: 0.16),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _floatingTextColor.withValues(alpha: 0.58),
                      width: 1.8,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _floatingTextColor.withValues(alpha: 0.18),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    _floatingText ?? '',
                    style: SLTheme.quicksand(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryBurstOverlay() {
    final _MemoryBurstSnapshot? snapshot = _memoryBurstSnapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    final _SoulBlockPerformanceProfile profile = _performanceProfile;
    final double cardWidth =
        min(MediaQuery.of(context).size.width * 0.72, 276.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _memoryBurstController,
          child: RepaintBoundary(
            child: _buildMemoryBurstCard(
              snapshot: snapshot,
              profile: profile,
            ),
          ),
          builder: (BuildContext context, Widget? child) {
            final double progress = _memoryBurstController.value;
            final double appear =
                Curves.easeOutBack.transform((progress / 0.28).clamp(0.0, 1.0));
            final double fadeOut = 1 -
                Curves.easeIn.transform(
                  ((progress - 0.84) / 0.16).clamp(0.0, 1.0),
                );
            final double scale =
                0.80 + (appear * profile.memoryBurstScaleBoost);
            final double offsetY =
                34 - (Curves.easeOutCubic.transform(progress) * 64);
            final double rotation = (1 - progress) *
                0.05 *
                profile.memoryBurstRotationScale *
                sin((progress * pi * 3.5) + 0.4);
            final double sparkleOpacity = fadeOut * 0.58;

            return Align(
              alignment: const Alignment(0, -0.06),
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Opacity(
                  opacity: fadeOut.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: SizedBox(
                        width: cardWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            if (profile.memoryBurstSparkleCount > 0)
                              ..._buildMemoryBurstSparkles(
                                snapshot: snapshot,
                                cardWidth: cardWidth,
                                sparkleOpacity: sparkleOpacity,
                                sparkleCount: profile.memoryBurstSparkleCount,
                              ),
                            if (child != null) child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExplosionEffect() {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: true,
            painter: _SoulExplosionPainter(
              repaint: _explosionController,
              progress: _explosionController,
              center: _explosionCenter,
              accent: _explosionAccent,
              particles: _explosionParticles,
              drawRing:
                  _performanceProfile.tier != _SoulBlockPerformanceTier.low,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMemoryBurstSparkles({
    required _MemoryBurstSnapshot snapshot,
    required double cardWidth,
    required double sparkleOpacity,
    required int sparkleCount,
  }) {
    final Color accentTransparent = snapshot.accent.withValues(alpha: 0);
    final Color accentGlow = snapshot.accent.withValues(alpha: 0.86);
    final Color whiteGlow = Colors.white.withValues(alpha: 0.96);
    return <Widget>[
      for (int index = 0;
          index < min(sparkleCount, _kMemoryBurstSparkleAngles.length);
          index++)
        Positioned(
          left: (cardWidth / 2) +
              (cos(_kMemoryBurstSparkleAngles[index]) * 110) -
              16,
          top: 124 + (sin(_kMemoryBurstSparkleAngles[index]) * 76) - 16,
          child: Opacity(
            opacity: sparkleOpacity,
            child: Transform.rotate(
              angle: _kMemoryBurstSparkleAngles[index],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: <Color>[
                      accentTransparent,
                      accentGlow,
                      whiteGlow,
                    ],
                  ),
                ),
                child: const SizedBox(width: 32, height: 10),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildMemoryBurstCard({
    required _MemoryBurstSnapshot snapshot,
    required _SoulBlockPerformanceProfile profile,
  }) {
    final ({int width, int height}) cacheSize = _memoryBurstCacheSize();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: <Color>[
            snapshot.accent.withValues(alpha: 0.34),
            const Color(0xFF09111D).withValues(alpha: 0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: snapshot.accent.withValues(alpha: 0.62),
          width: 2,
        ),
        boxShadow: profile.memoryBurstShadowScale <= 0
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: snapshot.accent
                      .withValues(alpha: 0.28 * profile.memoryBurstShadowScale),
                  blurRadius: 28 * profile.memoryBurstShadowScale,
                  spreadRadius: -6,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.34 * profile.memoryBurstShadowScale),
                  blurRadius: 30 * profile.memoryBurstShadowScale,
                  spreadRadius: -10,
                  offset: const Offset(0, 20),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: _SoulBlockGameState._memoryBurstCardAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            snapshot.accent.withValues(alpha: 0.20),
                            const Color(0xFF101722),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    CachedNetworkImage(
                      imageUrl: snapshot.imageUrl,
                      memCacheWidth: cacheSize.width,
                      memCacheHeight: cacheSize.height,
                      fadeInDuration: Duration.zero,
                      filterQuality: FilterQuality.low,
                      imageBuilder: (context, imageProvider) {
                        return FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 100,
                            height: 100 /
                                _SoulBlockGameState._memoryBurstCardAspectRatio,
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              alignment: Alignment.center,
                            ),
                          ),
                        );
                      },
                      placeholder: (_, __) => Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: snapshot.accent,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              snapshot.accent.withValues(alpha: 0.26),
                              const Color(0xFF162538),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.photo_library_rounded,
                            color: Colors.white70,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          snapshot.label,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              snapshot.subtitle,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
