part of '../soul_block_game.dart';

extension _SoulBlockRefinedPanels on _SoulBlockGameState {
  Widget _buildRefinedMainMenu() {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: max(0, constraints.maxHeight - 36),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SoulIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: context.tr('Trang chủ'),
                            onPressed: _exitToHomeFromSettings,
                          ),
                          _SoulIconButton(
                            icon: Icons.tune_rounded,
                            tooltip: context.tr('Settings'),
                            onPressed: _openSettingsSheet,
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 16 : 28,
                        ),
                        child: Column(
                          children: [
                            _buildGameLogo(size: compact ? 148 : 192),
                            const SizedBox(height: 20),
                            Text(
                              widget.gameTitle,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: compact ? 34 : 40,
                                fontWeight: FontWeight.w900,
                                color: _kSoulIvory,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _kSoulWarm.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _kSoulWarm.withValues(alpha: .16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    color: _kSoulWarm,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      context.tr('soul_block_best'),
                                      style: SLTheme.quicksand(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _kSoulWarm,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatNumber(_bestScore),
                                        style: SLTheme.quicksand(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: _kSoulIvory,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('soul_block_grid_size'),
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kSoulMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _kSoulPanelBottom,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .07),
                              ),
                            ),
                            child: Row(
                              children: [8, 9]
                                  .map((size) {
                                    final selected = _boardSize == size;
                                    return Expanded(
                                      child: Semantics(
                                        selected: selected,
                                        child: Material(
                                          color: selected
                                              ? _kSoulPanelTop
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            onTap: _isOpeningGameplay
                                                ? null
                                                : () {
                                                    _emitClickFeedback();
                                                    _setBoardSize(size);
                                                  },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              child: Text(
                                                '$size × $size',
                                                textAlign: TextAlign.center,
                                                style: SLTheme.quicksand(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: selected
                                                      ? _kSoulIvory
                                                      : _kSoulMuted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _isOpeningGameplay
                                ? null
                                : _startSessionFromMenu,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kSoulChrome,
                              foregroundColor: _kSoulStageBottom,
                              disabledBackgroundColor: _kSoulChrome.withValues(
                                alpha: .4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 28,
                            ),
                            label: Text(
                              context.tr('soul_block_play'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _MenuMiniButton(
                                  icon: Icons.emoji_events_outlined,
                                  label: context.tr('Bảng điểm'),
                                  onTap: _openLeaderboardSheet,
                                ),
                              ),
                              if (AppConfig.isPurchaseEnabled) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MenuMiniButton(
                                    icon: Icons.workspace_premium_outlined,
                                    label: context.tr('Gỡ quảng cáo'),
                                    onTap: _openPremiumStore,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
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
    return AbsorbPointer(
      child: ColoredBox(
        color: _kSoulStageBottom.withValues(alpha: .88),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGameLogo(size: 96),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('soul_block_preparing'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kSoulIvory,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSoulLoadingBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefinedGameplayScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape =
            constraints.maxWidth >= 600 &&
            constraints.maxWidth > constraints.maxHeight * 1.15;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final extraTextHeight = max(0.0, textScale - 1) * 100;
        final minHeight = (landscape ? 400.0 : 590.0) + extraTextHeight;
        final contentHeight = max(constraints.maxHeight, minHeight);
        final compact =
            constraints.maxWidth < 400 || constraints.maxHeight < 720;

        Widget boardView() => RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _dragVisualTick,
            builder: (context, value, child) => _buildBoardPanel(),
          ),
        );
        Widget trayView() => RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _trayVisualTick,
            builder: (context, value, child) =>
                _buildTrayPanel(compact: compact),
          ),
        );
        Widget header() => _buildRefinedGameplayHeader(
          compact: compact,
          ultraCompact: constraints.maxWidth < 360,
        );
        Widget photoStatus() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _buildPhotoStatus(compact: compact),
        );

        return SingleChildScrollView(
          physics: constraints.maxHeight >= minHeight
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: SizedBox(
            height: contentHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 20,
                8,
                compact ? 12 : 20,
                12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: landscape ? 1040 : 560),
                  child: landscape
                      ? Row(
                          children: [
                            Expanded(child: boardView()),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: (constraints.maxWidth * .42).clamp(
                                276.0,
                                310.0,
                              ),
                              child: Column(
                                children: [
                                  header(),
                                  photoStatus(),
                                  const Spacer(),
                                  SizedBox(
                                    height: 210 + extraTextHeight * .4,
                                    child: trayView(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            header(),
                            photoStatus(),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, stage) {
                                  // Khay giữ chiều cao đủ chạm; bảng dùng phần còn lại.
                                  final trayHeight =
                                      (stage.maxHeight * .32).clamp(
                                        192.0,
                                        220.0,
                                      ) +
                                      extraTextHeight * .4;
                                  final extent = max(
                                    0.0,
                                    min(
                                      stage.maxWidth,
                                      stage.maxHeight - trayHeight - 12,
                                    ),
                                  );
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox.square(
                                        dimension: extent,
                                        child: boardView(),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: trayHeight,
                                        child: trayView(),
                                      ),
                                    ],
                                  );
                                },
                              ),
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
  }

  Widget _buildRefinedGameplayHeader({
    required bool compact,
    required bool ultraCompact,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: _kSoulPanelTop.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TopScoreCard(
              label: context.tr('soul_block_best'),
              icon: Icons.emoji_events_rounded,
              accent: _kSoulWarm,
              value: _formatNumber(_bestScore),
              dense: compact,
              ultraCompact: ultraCompact,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: .09),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildRefinedScoreHero(
              compact: compact,
              ultraCompact: ultraCompact,
            ),
          ),
          const SizedBox(width: 6),
          _SoulIconButton(
            icon: Icons.tune_rounded,
            tooltip: context.tr('Settings'),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildRefinedScoreHero({
    required bool compact,
    required bool ultraCompact,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('soul_block_score'),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kSoulMuted,
                ),
              ),
              const SizedBox(width: 8),
              // Giữ chỗ cho nhãn chuỗi để bàn không nhảy kích thước khi
              // vừa xóa hàng hoặc mất chuỗi giữa lúc kéo mảnh.
              Visibility(
                visible: _combo > 0,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _buildRefinedComboStatus(ultraCompact: ultraCompact),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatNumber(_score),
            style: SLTheme.quicksand(
              fontSize: compact ? 28 : 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: _kSoulIvory,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefinedComboStatus({required bool ultraCompact}) {
    final accent = _comboMisses >= 2 ? _kSoulWarm : _kSoulChrome;
    return Tooltip(
      message: L10nService().format('soul_block_combo_grace', {
        'misses': _comboMisses,
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              L10nService().format('soul_block_combo', {'level': _combo}),
              style: SLTheme.quicksand(
                fontSize: ultraCompact ? 8 : 9,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(width: 3),
            for (var index = 0; index < 3; index++)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 3),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < 3 - _comboMisses
                      ? accent
                      : Colors.white.withValues(alpha: .16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
