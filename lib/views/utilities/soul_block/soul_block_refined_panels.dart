part of '../soul_block_game.dart';

extension _SoulBlockRefinedPanels on _SoulBlockGameState {
  Widget _buildRefinedMainMenu() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeight = constraints.maxHeight < 760;
            final double bottomInset = compactHeight ? 12 : 24;
            final double introGap = compactHeight ? 18 : 32;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 18 - bottomInset,
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          colors: <Color>[
                            const Color(0xFF1F2F6F).withValues(alpha: 0.50),
                            const Color(0xFF0F173B).withValues(alpha: 0.92),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color:
                              const Color(0xFF5B8CFF).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color:
                                const Color(0xFF5B8CFF).withValues(alpha: 0.15),
                            blurRadius: 36,
                            spreadRadius: -6,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.40),
                            blurRadius: 22,
                            spreadRadius: -8,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0C1435),
                              border: Border.all(
                                color: const Color(0xFF36D1FF)
                                    .withValues(alpha: 0.45),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF36D1FF)
                                      .withValues(alpha: 0.22),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: _buildGameLogo(size: 80),
                          ),
                          const SizedBox(height: 18),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0xFFDCE7FF),
                                Color(0xFF8C6CFF)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              widget.gameTitle,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bright blocks, cleaner layout, endless flow',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.72),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: <Color>[
                                  const Color(0xFFFFD85E)
                                      .withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFD85E)
                                    .withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD85E)
                                      .withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  color: Color(0xFFFFD85E),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'BEST RUN',
                                      style: SLTheme.quicksand(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFFFD85E)
                                            .withValues(alpha: 0.85),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      _formatNumber(_bestScore),
                                      style: SLTheme.quicksand(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: introGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'GRID SIZE:  ',
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                            letterSpacing: 0.8,
                          ),
                        ),
                        ...<int>[8, 9].map((int size) {
                          final bool isSelected = _boardSize == size;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () {
                                if (!_isOpeningGameplay) {
                                  _emitClickFeedback();
                                  _setBoardSize(size);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF36D1FF),
                                            Color(0xFF5B8CFF)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF36D1FF)
                                            .withValues(alpha: 0.8)
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF5B8CFF)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  '${size}x$size',
                                  style: SLTheme.quicksand(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white60,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isOpeningGameplay
                          ? 'Preparing your next board'
                          : 'Tap play for a smoother, cleaner run',
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _playPulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isOpeningGameplay ? 1.0 : _playPulseScale,
                          child: child,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF36D1FF), Color(0xFF8C6CFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF8C6CFF)
                                  .withValues(alpha: 0.45),
                              blurRadius: 28,
                              spreadRadius: -4,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              _isOpeningGameplay ? null : _startSessionFromMenu,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.transparent,
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: _isOpeningGameplay
                                ? Row(
                                    key: const ValueKey<String>('play-loading'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'SETTING BOARD',
                                        style: SLTheme.quicksand(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'PLAY',
                                    key: const ValueKey<String>('play-idle'),
                                    style: SLTheme.quicksand(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: <Color>[
                            const Color(0xFF0F173B).withValues(alpha: 0.85),
                            const Color(0xFF0A1436).withValues(alpha: 0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color:
                              const Color(0xFF5B8CFF).withValues(alpha: 0.20),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: -4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
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
                          if (AppConfig.isPurchaseEnabled) ...<Widget>[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MenuMiniButton(
                                icon: Icons.block_rounded,
                                label: 'No Ads',
                                onTap: _openPremiumStore,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_isOpeningGameplay) _buildRefinedMenuLoadingOverlay(),
      ],
    );
  }

  Widget _buildRefinedMenuLoadingOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC12214A).withValues(alpha: 0.74),
        ),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.16),
                  _kSoulPanelTop.withValues(alpha: 0.20),
                  _kSoulPanelBottom.withValues(alpha: 0.96),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _kSoulChrome.withValues(alpha: 0.30),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildGameLogo(size: 54),
                const SizedBox(height: 12),
                Text(
                  'PREPARING BOARD',
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kSoulIvory,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One short beat so the transition feels smoother',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: double.infinity,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      child: AnimatedBuilder(
                        animation: _playPulseController,
                        builder: (context, _) {
                          return Align(
                            alignment: Alignment(
                              -1 + (_playPulseController.value * 2),
                              0,
                            ),
                            child: Container(
                              width: 112,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Color(0x00F2D27A),
                                    _kSoulChrome,
                                    Color(0xFF78D6FF),
                                    Color(0x00F2D27A),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefinedGameplayScreen() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final double bannerReserve =
            _view == _SoulGameView.gameplay && _bannerAd != null
                ? max(
                    _SoulBlockGameState._bannerDockBaseHeight,
                    _bannerAd!.size.height.toDouble() + 4,
                  )
                : 0;
        final double effectiveHeight = max(
          0.0,
          constraints.maxHeight - bannerReserve,
        );
        final bool compactHeight = effectiveHeight < 760;
        final bool narrowWidth = constraints.maxWidth < 420;
        final bool ultraCompact =
            effectiveHeight < 700 || constraints.maxWidth < 390;
        final bool extremeCompact =
            effectiveHeight < 640 || constraints.maxWidth < 372;
        final bool wideStage = constraints.maxWidth >= 760;
        final bool compactLayout = compactHeight || narrowWidth;
        final double bottomInset = mediaQuery.viewPadding.bottom;
        final double horizontalPadding = wideStage
            ? 20
            : extremeCompact
                ? 7
                : ultraCompact
                    ? 8
                    : narrowWidth
                        ? 10
                        : 14;
        final double stageGap = extremeCompact
            ? 3
            : ultraCompact
                ? 5
                : compactLayout
                    ? 7
                    : 12;
        final double headerHeight = extremeCompact
            ? 62
            : ultraCompact
                ? 72
                : compactLayout
                    ? 82
                    : 96;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            extremeCompact
                ? 1
                : ultraCompact
                    ? 2
                    : compactLayout
                        ? 3
                        : 5,
            horizontalPadding,
            max(
              extremeCompact ? 0.0 : (compactLayout ? 2.0 : 4.0),
              bottomInset > 0 ? 2.0 : 0.0,
            ),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: headerHeight,
                child: _buildRefinedGameplayHeader(
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
                      maxWidth: wideStage ? 820 : 720,
                    ),
                    child: LayoutBuilder(
                      builder: (BuildContext context,
                          BoxConstraints stageConstraints) {
                        final double availableStageHeight = max(
                          0,
                          stageConstraints.maxHeight -
                              (_SoulBlockGameState._boardLayoutSafetyInset * 2),
                        ).toDouble();
                        final double minTrayHeight = extremeCompact
                            ? 68
                            : ultraCompact
                                ? 78
                                : compactLayout
                                    ? 98
                                    : 128;
                        final double maxTrayHeight = extremeCompact
                            ? 102
                            : ultraCompact
                                ? 118
                                : compactLayout
                                    ? 144
                                    : 170;
                        final double trayRatio = extremeCompact
                            ? 0.188
                            : ultraCompact
                                ? 0.208
                                : compactLayout
                                    ? 0.230
                                    : 0.240;
                        double trayHeight =
                            (stageConstraints.maxHeight * trayRatio)
                                .clamp(minTrayHeight, maxTrayHeight)
                                .toDouble();
                        final double minBoardExtent = extremeCompact
                            ? 176
                            : ultraCompact
                                ? 196
                                : 224;
                        double boardExtent = min(
                          stageConstraints.maxWidth,
                          availableStageHeight - trayHeight - stageGap,
                        );
                        if (boardExtent < minBoardExtent) {
                          final double deficit = minBoardExtent - boardExtent;
                          trayHeight = max(minTrayHeight, trayHeight - deficit);
                          boardExtent = min(
                            stageConstraints.maxWidth,
                            availableStageHeight - trayHeight - stageGap,
                          );
                        }
                        final double safeBoardExtent = max(0.0, boardExtent);
                        final bool trayCompact =
                            compactLayout || safeBoardExtent < 344;
                        final double totalContentHeight =
                            safeBoardExtent + stageGap + trayHeight;

                        return SizedBox(
                          height: min(
                            availableStageHeight,
                            totalContentHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (safeBoardExtent > 0)
                                SizedBox.square(
                                  dimension: safeBoardExtent,
                                  child: RepaintBoundary(
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _dragVisualTick,
                                      builder: (BuildContext context, int _,
                                          Widget? _) {
                                        return _buildBoardPanel();
                                      },
                                    ),
                                  ),
                                ),
                              SizedBox(height: stageGap),
                              SizedBox(
                                height: trayHeight,
                                child: RepaintBoundary(
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _trayVisualTick,
                                    builder: (BuildContext context, int _,
                                        Widget? _) {
                                      return _buildTrayPanel(
                                          compact: trayCompact);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildRefinedGameplayHeader({
    required bool compact,
    required bool ultraCompact,
  }) {
    final double bestCardWidth = ultraCompact
        ? 110
        : compact
            ? 120
            : 134;
    final double settingsSize = ultraCompact
        ? 46
        : compact
            ? 50
            : 56;
    final double sideGap = ultraCompact ? 6 : 10;
    return Padding(
      padding: EdgeInsets.only(top: ultraCompact ? 0 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: bestCardWidth,
            child: _TopScoreCard(
              label: 'BEST',
              icon: Icons.emoji_events_rounded,
              accent: _kSoulChrome,
              value: _formatNumber(_bestScore),
              dense: compact,
              ultraCompact: ultraCompact,
            ),
          ),
          SizedBox(width: sideGap),
          Expanded(
            child: _buildRefinedScoreHero(
              compact: compact,
              ultraCompact: ultraCompact,
            ),
          ),
          SizedBox(width: sideGap),
          SizedBox(
            width: settingsSize,
            height: settingsSize,
            child: _buildSettingsButton(
              compact: compact,
              ultraCompact: ultraCompact,
              mini: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefinedScoreHero({
    required bool compact,
    required bool ultraCompact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ultraCompact ? 7 : (compact ? 9 : 10),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF00E5FF),
            Color(0xFF7C3AED),
            Color(0xFF0F172A),
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'SCORE',
            style: SLTheme.quicksand(
              fontSize: ultraCompact
                  ? 8.5
                  : compact
                      ? 9.5
                      : 10.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE0F7FF),
              letterSpacing: 1.4,
            ),
          ),
          SizedBox(height: ultraCompact ? 1 : 2),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ultraCompact ? 160 : 230,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatNumber(_score),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: ultraCompact
                      ? 22
                      : compact
                          ? 26
                          : 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.4,
                  shadows: const [
                    Shadow(color: Color(0xFF00E5FF), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
