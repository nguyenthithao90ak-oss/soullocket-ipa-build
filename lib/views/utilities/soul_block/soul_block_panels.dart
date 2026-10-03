part of '../soul_block_game.dart';

const LinearGradient _kSoulSplashProgressGradient = LinearGradient(
  colors: [Color(0x00C3B6F6), _kSoulChrome, _kSoulWarm, Color(0x00E9C9A2)],
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGameLogo(size: 160),
              const SizedBox(height: 28),
              Text(
                widget.gameTitle,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: _kSoulIvory,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('soul_block_tagline'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: _kSoulMuted,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(width: 220, child: _buildSoulLoadingBar()),
              const SizedBox(height: 16),
              Text(
                context.tr('soul_block_preparing'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSoulMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoulLoadingBar() {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: ColoredBox(
          color: Colors.white.withValues(alpha: .07),
          child: AnimatedBuilder(
            animation: _playPulseController,
            builder: (context, child) => Align(
              alignment: Alignment(
                reducedMotion ? 0 : -1 + _playPulseController.value * 2,
                0,
              ),
              child: child,
            ),
            child: const FractionallySizedBox(
              widthFactor: .45,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _kSoulSplashProgressGradient,
                ),
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
                context.tr('util_khingthtbi_94e580'),
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
                    context.tr('util_thli_4dffdf'),
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
            context.tr('soul_block_tagline'),
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
                  Colors.white.withValues(alpha: 0.12),
                  const Color(0xFFFFD166).withValues(alpha: 0.09),
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
                  L10nScope.of(context).format('ui_utilities_best_value1_c6ee12', {'value1': _formatNumber(_bestScore)}),
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
                                context.tr('util_angvo_72ceaa'),
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            context.tr('soul_block_play_action'),
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
                  label: context.tr('Cài đặt'),
                  onTap: _openSettingsSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuMiniButton(
                  icon: Icons.leaderboard_rounded,
                  label: context.tr('Bảng điểm'),
                  onTap: _openLeaderboardSheet,
                ),
              ),
              if (AppConfig.isPurchaseEnabled) ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: _MenuMiniButton(
                    icon: Icons.block_rounded,
                    label: context.tr('Gỡ quảng cáo'),
                    onTap: _openPremiumStore,
                  ),
                ),
              ],
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
                      builder:
                          (
                            BuildContext context,
                            BoxConstraints stageConstraints,
                          ) {
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
                            double trayHeight =
                                (stageConstraints.maxHeight *
                                        (ultraCompact
                                            ? 0.175
                                            : compactLayout
                                            ? 0.19
                                            : 0.205))
                                    .clamp(minTrayHeight, maxTrayHeight)
                                    .toDouble();
                            double boardExtent = min(
                              stageConstraints.maxWidth,
                              stageConstraints.maxHeight -
                                  trayHeight -
                                  stageGap,
                            );
                            if (boardExtent < 244) {
                              final double deficit = 244 - boardExtent;
                              trayHeight = max(
                                minTrayHeight,
                                trayHeight - deficit,
                              );
                              boardExtent = min(
                                stageConstraints.maxWidth,
                                stageConstraints.maxHeight -
                                    trayHeight -
                                    stageGap,
                              );
                            }
                            final double safeBoardExtent = max(
                              0.0,
                              boardExtent,
                            );
                            final bool trayCompact =
                                compactLayout || safeBoardExtent < 380;

                            return Column(
                              children: <Widget>[
                                if (safeBoardExtent > 0)
                                  SizedBox.square(
                                    dimension: safeBoardExtent,
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _dragVisualTick,
                                      builder: (context, _, _) {
                                        return _buildBoardPanel();
                                      },
                                    ),
                                  ),
                                SizedBox(height: stageGap),
                                SizedBox(
                                  height: trayHeight,
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _trayVisualTick,
                                    builder: (context, _, _) {
                                      return _buildTrayPanel(
                                        compact: trayCompact,
                                      );
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
                  label: context.tr('soul_block_best'),
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
                  label: context.tr('soul_block_lines_label'),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF162F6E).withValues(alpha: 0.34),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
                  color: const Color(0xFFFFD166).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFD166).withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  L10nService().format('soul_block_combo', {'level': _combo}),
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
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  context.tr('soul_block_run_score_label'),
                  style: SLTheme.quicksand(
                    fontSize: ultraCompact
                        ? 8.4
                        : compact
                        ? 9.2
                        : 10.0,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.78),
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
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            if (!ultraCompact) ...<Widget>[
              SizedBox(height: compact ? 2 : 4),
              Text(
                context.tr('soul_block_play_hint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: compact ? 9.4 : 10.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.70),
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
    final double iconSize = mini
        ? (ultraCompact ? 18 : 20)
        : (ultraCompact ? 18 : 20);
    return InkWell(
      onTap: _openSettingsSheet,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        height: mini ? double.infinity : (compact ? 50 : 56),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[_kSoulPanelTop, _kSoulPanelMid, _kSoulPanelBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: _kSoulChrome.withValues(alpha: 0.24)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: _kSoulStageBottom.withValues(alpha: .72),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .78,
              ),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _kSoulPanelBottom,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        color: _kSoulWarm,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('Bảng điểm'),
                          style: SLTheme.quicksand(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _kSoulIvory,
                          ),
                        ),
                      ),
                      _SoulIconButton(
                        icon: Icons.close_rounded,
                        tooltip: context.tr('close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_leaderboard.isEmpty)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          context.tr('util_chacltchin_2aa20c'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            height: 1.5,
                            color: _kSoulMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _leaderboard.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
        );
      },
    );
  }

  Future<void> _openSettingsSheet() async {
    _emitClickFeedback();
    await _refreshPremiumStatus();
    if (!mounted) return;
    var sound = _soundEnabled;
    var vibration = _vibrationEnabled;
    var smoothGraphics = _smoothGraphics;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: _kSoulStageBottom.withValues(alpha: .72),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget divider() => Divider(
              height: 1,
              indent: 60,
              endIndent: 14,
              color: Colors.white.withValues(alpha: .06),
            );
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .9,
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  decoration: BoxDecoration(
                    color: _kSoulPanelBottom,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .10),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _kSoulMuted.withValues(alpha: .3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('Settings'),
                              style: SLTheme.quicksand(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _kSoulIvory,
                              ),
                            ),
                          ),
                          _SoulIconButton(
                            icon: Icons.close_rounded,
                            tooltip: context.tr('close'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      Text(
                        context.tr('soul_block_settings_hint'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          height: 1.5,
                          color: _kSoulMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _kSoulPanelTop.withValues(alpha: .55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    _SettingsSwitchTile(
                                      icon: Icons.volume_up_outlined,
                                      title: context.tr('Âm thanh'),
                                      value: sound,
                                      onChanged: (value) async {
                                        setModalState(() => sound = value);
                                        await _setSoundEnabled(value);
                                      },
                                    ),
                                    divider(),
                                    _SettingsSwitchTile(
                                      icon: Icons.vibration_rounded,
                                      title: context.tr('Rung'),
                                      value: vibration,
                                      onChanged: (value) async {
                                        setModalState(() => vibration = value);
                                        await _setVibrationEnabled(value);
                                      },
                                    ),
                                    divider(),
                                    _SettingsSwitchTile(
                                      icon: Icons.speed_rounded,
                                      title: context.tr('soul_block_smooth'),
                                      subtitle: context.tr(
                                        'soul_block_smooth_hint',
                                      ),
                                      value: smoothGraphics,
                                      onChanged: (value) async {
                                        setModalState(
                                          () => smoothGraphics = value,
                                        );
                                        await _setSmoothGraphicsEnabled(value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  color: _kSoulPanelTop.withValues(alpha: .28),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    _SettingsActionButton(
                                      icon: _view == _SoulGameView.gameplay
                                          ? Icons.refresh_rounded
                                          : Icons.play_arrow_rounded,
                                      label: context.tr(
                                        _view == _SoulGameView.gameplay
                                            ? 'Chơi lại'
                                            : 'Tiếp tục',
                                      ),
                                      accent: _kSoulChrome,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _restartCurrentRunFromSettings();
                                      },
                                    ),
                                    divider(),
                                    _SettingsActionButton(
                                      icon: Icons.emoji_events_outlined,
                                      label: context.tr('Bảng điểm'),
                                      accent: _kSoulWarm,
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await _openLeaderboardSheet();
                                      },
                                    ),
                                    if (AppConfig.isPurchaseEnabled) ...[
                                      divider(),
                                      _SettingsActionButton(
                                        icon: Icons.workspace_premium_outlined,
                                        label: context.tr('Gỡ quảng cáo'),
                                        accent: _kSoulChrome,
                                        onTap: () async {
                                          Navigator.of(context).pop();
                                          await _openPremiumStore();
                                        },
                                      ),
                                    ],
                                    if (_view == _SoulGameView.gameplay) ...[
                                      divider(),
                                      _SettingsActionButton(
                                        icon: Icons.grid_view_rounded,
                                        label: context.tr('Menu'),
                                        accent: _kSoulMuted,
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _returnToMenuFromSettings();
                                        },
                                      ),
                                    ],
                                    divider(),
                                    _SettingsActionButton(
                                      icon: Icons.home_outlined,
                                      label: context.tr('Trang chủ'),
                                      accent: _kSoulMuted,
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await _exitToHomeFromSettings();
                                      },
                                    ),
                                  ],
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
            colors: <Color>[Color(0xFF0B1220), Color(0xFF0F172A)],
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
          child: ConsentAdView(ad: bannerAd),
        ),
      ),
    );
  }

  Widget _buildFloatingToast() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -.48),
          child: AnimatedBuilder(
            animation: _floatingController,
            child: RepaintBoundary(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: min(320, MediaQuery.sizeOf(context).width - 32),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kSoulStageBottom.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _floatingTextColor.withValues(alpha: .8),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_boardPhoto != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox.square(
                          dimension: 36,
                          child: RawImage(
                            image: _boardPhoto,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _floatingText ?? '',
                              style: SLTheme.quicksand(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _floatingTextColor,
                              ),
                            ),
                            if (_floatingScoreText != null)
                              Text(
                                _floatingScoreText!,
                                style: SLTheme.quicksand(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: _kSoulIvory,
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
            builder: (context, child) {
              final t = _floatingController.value;
              final appear = (t / .18).clamp(0.0, 1.0);
              final fade = (1 - (t - .64) / .36).clamp(0.0, 1.0);
              return Opacity(
                opacity: reduced ? 1 : appear * fade,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    reduced ? 0 : 10 - 20 * Curves.easeOutCubic.transform(t),
                  ),
                  child: Transform.scale(
                    scale: reduced
                        ? 1
                        : .9 + .1 * Curves.easeOutBack.transform(appear),
                    child: child,
                  ),
                ),
              );
            },
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
    final double cardWidth = min(
      MediaQuery.sizeOf(context).width * 0.46,
      176.0,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _memoryBurstController,
          child: RepaintBoundary(
            child: _buildMemoryBurstCard(snapshot: snapshot, profile: profile),
          ),
          builder: (BuildContext context, Widget? child) {
            final double progress = _memoryBurstController.value;
            final double appear = Curves.easeOutBack.transform(
              (progress / 0.28).clamp(0.0, 1.0),
            );
            final double fadeOut =
                1 -
                Curves.easeIn.transform(
                  ((progress - 0.84) / 0.16).clamp(0.0, 1.0),
                );
            final double scale =
                0.80 + (appear * profile.memoryBurstScaleBoost);
            final double offsetY =
                34 - (Curves.easeOutCubic.transform(progress) * 64);
            final double rotation =
                (1 - progress) *
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
                            ?child,
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
              photoImage: _boardPhoto,
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
      for (
        int index = 0;
        index < min(sparkleCount, _kMemoryBurstSparkleAngles.length);
        index++
      )
        Positioned(
          left:
              (cardWidth / 2) +
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
                    colors: <Color>[accentTransparent, accentGlow, whiteGlow],
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
                  color: snapshot.accent.withValues(
                    alpha: 0.28 * profile.memoryBurstShadowScale,
                  ),
                  blurRadius: 28 * profile.memoryBurstShadowScale,
                  spreadRadius: -6,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.34 * profile.memoryBurstShadowScale,
                  ),
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
                    RawImage(
                      image: snapshot.image,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
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
