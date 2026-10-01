part of '../soul_block_game.dart';

extension _SoulBlockBoard on _SoulBlockGameState {
  Widget _buildBoardPanel() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(_boardShakeX, _boardShakeY),
          child: child,
        );
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double boardExtent = min(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final double cellExtent = _resolveBoardCellExtent(
            boardExtent,
            devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          );
          final double innerExtent =
              boardExtent - (_SoulBlockGameState._boardPanelPadding * 2) - 6.0;
          final double contentExtent =
              (cellExtent * _boardSize) +
              (_SoulBlockGameState._boardGap * (_boardSize - 1));
          final double contentSlack = max(0, innerExtent - contentExtent);

          const double boardGap = _SoulBlockGameState._boardGap;

          return Center(
            child: Stack(
              children: <Widget>[
                Container(
                  key: _boardKey,
                  width: boardExtent,
                  height: boardExtent,
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.all(
                    _SoulBlockGameState._boardPanelPadding,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: <Color>[
                        _kSoulPanelTop,
                        _kSoulBoardTop,
                        _kSoulBoardBottom,
                      ],
                      stops: <double>[0, 0.48, 1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _kSoulChrome.withValues(alpha: 0.20),
                      width: 1.0,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF071226).withValues(alpha: 0.18),
                        blurRadius: 14,
                        spreadRadius: -10,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: <Color>[
                          Color.lerp(_kSoulBoardTop, Colors.white, 0.04)!,
                          _kSoulBoardMid,
                          Color.lerp(_kSoulBoardBottom, _kSoulChrome, 0.03)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.025),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(contentSlack / 2),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _dragVisualTick,
                        builder: (BuildContext context, int _, Widget? _) {
                          return RepaintBoundary(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: List<Widget>.generate(_boardSize, (
                                int row,
                              ) {
                                final bool isLastRow = row == (_boardSize - 1);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: isLastRow ? 0 : boardGap,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: List<Widget>.generate(
                                      _boardSize,
                                      (int col) {
                                        final bool isLastCol =
                                            col == (_boardSize - 1);
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            right: isLastCol ? 0 : boardGap,
                                          ),
                                          child: SizedBox(
                                            width: cellExtent,
                                            height: cellExtent,
                                            child: _buildBoardCell(
                                              row: row,
                                              col: col,
                                              cellExtent: cellExtent,
                                            ),
                                          ),
                                        );
                                      },
                                      growable: false,
                                    ),
                                  ),
                                );
                              }, growable: false),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (_isGameOver && !_isResolvingGameOver)
                  _buildGameOverOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return _GameOverOverlayContent(this);
  }

  Widget _buildBoardCell({
    required int row,
    required int col,
    required double cellExtent,
  }) {
    final _SoulTile? tile = _board[row][col];
    final _SoulPieceOption? draggingPiece = _draggingPiece;
    final bool hasPreviewAnchor = _previewRow >= 0 && _previewCol >= 0;
    final bool isPreview =
        draggingPiece != null &&
        hasPreviewAnchor &&
        _isCellInPreviewFootprint(row, col);
    final bool isClearing =
        _clearingRows.contains(row) ||
        _clearingCols.contains(col) ||
        _clearingCells.contains(Point<int>(col, row));

    if (tile != null) {
      return _buildPhotoTile(
        width: cellExtent,
        height: cellExtent,
        crop: _tilePhotoRect(tile, row, col),
        clearing: isClearing,
        gold: tile.toneIndex == 999,
      );
    }
    if (isPreview) {
      return _buildPhotoTile(
        width: cellExtent,
        height: cellExtent,
        crop: _piecePhotoRect(
          draggingPiece,
          col - _previewCol,
          row - _previewRow,
          boardRow: row,
          boardCol: col,
        ),
        preview: true,
        gold: draggingPiece.isGold,
        bomb: draggingPiece.isBomb,
      );
    }
    // Gợi ý nước đi vẫn được tính nội bộ để chọn mảnh và kiểm tra Game Over,
    // nhưng không phủ ô hướng dẫn lên bàn khi người chơi chưa kéo mảnh.
    return _buildSocketCell(cellExtent, cellExtent);
  }

  Widget _buildHoldEmptyCard({bool compact = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kSoulChrome.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kSoulChrome.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.move_to_inbox_outlined,
            color: _kSoulChrome,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr('soul_block_hold'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kSoulChrome,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayPanel({bool compact = false}) {
    final slots = List<_SoulPieceOption?>.generate(
      3,
      (index) => index < _tray.length ? _tray[index] : null,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('soul_block_tray'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kSoulIvory,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [_tray.length, 3].join(' / '),
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kSoulMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Tooltip(
                message: context.tr('soul_block_hold_hint'),
                child: Semantics(
                  label: context.tr('soul_block_hold_hint'),
                  child: SizedBox(
                    key: _holdAreaKey,
                    width: 144,
                    height: 52 + max(0.0, textScale - 1) * 18,
                    child: _holdPiece == null
                        ? _buildHoldEmptyCard(compact: compact)
                        : _buildPieceCard(
                            _holdPiece!,
                            compact: compact,
                            isHold: true,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(slots.length, (index) {
              final piece = slots[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: index == slots.length - 1 ? 0 : 8,
                  ),
                  child: RepaintBoundary(
                    child: piece == null
                        ? _buildEmptyPieceCard(compact: compact)
                        : _buildPieceCard(piece, compact: compact),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPieceCard({bool compact = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .018),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .04)),
      ),
      child: const Center(
        child: Icon(Icons.check_rounded, size: 20, color: Color(0x446D7697)),
      ),
    );
  }

  Widget _buildPieceCard(
    _SoulPieceOption piece, {
    bool compact = false,
    bool isHold = false,
  }) {
    final isDragging = _draggingPiece?.id == piece.id;
    final isSnapBack = _snapBackPieceId == piece.id;
    final accent = piece.isGold
        ? _kSoulWarm
        : piece.isBomb
        ? const Color(0xFFE9A7AC)
        : _kSoulChrome;
    final pieceCardChild = Container(
      decoration: BoxDecoration(
        color: _kSoulPanelTop.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(isHold ? 16 : 18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),

      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideControls =
              isHold || piece.template.height > piece.template.width;
          final previewPadding = sideControls
              ? const EdgeInsetsDirectional.fromSTEB(8, 8, 44, 8)
              : const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 44);
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: previewPadding,
                  child: RepaintBoundary(
                    child: _buildPieceGrid(piece, compact: compact),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: isHold ? null : 0,
                top: isHold ? 0 : null,
                child: IconButton(
                  tooltip: context.tr('soul_block_rotate'),
                  onPressed: () => _rotatePiece(piece),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    maximumSize: const Size.square(48),
                    padding: EdgeInsets.zero,
                    foregroundColor: _kSoulMuted,
                  ),
                  icon: const Icon(Icons.rotate_right_rounded, size: 20),
                ),
              ),
              if (!isHold && (piece.isGold || piece.isBomb))
                PositionedDirectional(
                  start: sideControls ? null : 12,
                  end: sideControls ? 16 : null,
                  top: sideControls ? 12 : null,
                  bottom: sideControls ? null : 16,
                  child: Icon(
                    piece.isGold
                        ? Icons.star_rounded
                        : piece.isBomb
                        ? Icons.local_fire_department_rounded
                        : Icons.auto_awesome_rounded,
                    size: 16,
                    color: accent,
                  ),
                ),
            ],
          );
        },
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) =>
          _startDrag(piece, details.globalPosition, fromHold: isHold),
      onPanUpdate: (details) => _updateDrag(details.globalPosition),
      onPanEnd: (_) => unawaited(_endDrag()),
      onPanCancel: _cancelDrag,
      child: AnimatedScale(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context)
              ? 0
              : isSnapBack
              ? 170
              : 120,
        ),
        curve: isSnapBack ? Curves.easeOutBack : Curves.easeOut,
        scale: isDragging
            ? .96
            : isSnapBack
            ? 1.04
            : 1,
        child: AnimatedOpacity(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 120,
          ),
          opacity: isDragging ? .12 : 1,
          child: IgnorePointer(ignoring: isDragging, child: pieceCardChild),
        ),
      ),
    );
  }

  Widget _buildDraggedPieceGrid(_SoulPieceOption piece) {
    if (_boardCellExtent <= 0) {
      return const SizedBox.shrink();
    }

    final anchor = _previewRow >= 0 && _previewCol >= 0
        ? Point<int>(_previewCol, _previewRow)
        : _piecePhotoAnchor(piece);
    final double cellFullSize =
        _boardCellExtent + _SoulBlockGameState._boardGap;
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: piece.template.cells
            .map((Point<int> cell) {
              return Positioned(
                left: cell.x * cellFullSize,
                top: cell.y * cellFullSize,
                width: _boardCellExtent,
                height: _boardCellExtent,
                child: RepaintBoundary(
                  child: _buildPhotoTile(
                    width: _boardCellExtent,
                    height: _boardCellExtent,
                    crop: _boardPhotoRect(anchor.y + cell.y, anchor.x + cell.x),
                    floating: true,
                    gold: piece.isGold,
                    bomb: piece.isBomb,
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildPieceGrid(_SoulPieceOption piece, {bool compact = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchor = _piecePhotoAnchor(piece);
        final columns = piece.template.width;
        final rows = piece.template.height;
        final gap = compact ? 2.0 : 2.5;
        // Tính theo kích thước thật của mảnh, tránh ép mọi mảnh vào lưới 5 × 5.
        final cell = max(
          0.0,
          min(
            compact ? 38.0 : 44.0,
            min(
              (constraints.maxWidth - gap * (columns - 1)) / columns,
              (constraints.maxHeight - gap * (rows - 1)) / rows,
            ),
          ),
        );
        if (cell <= 0) {
          return const SizedBox.shrink();
        }
        final width = columns * cell + (columns - 1) * gap;
        final height = rows * cell + (rows - 1) * gap;
        final originX = (constraints.maxWidth - width) / 2;
        final originY = (constraints.maxHeight - height) / 2;
        return Stack(
          children: piece.template.cells
              .map(
                (point) => Positioned(
                  left: originX + point.x * (cell + gap),
                  top: originY + point.y * (cell + gap),
                  width: cell,
                  height: cell,
                  child: _buildPhotoTile(
                    width: cell,
                    height: cell,
                    crop: _boardPhotoRect(
                      anchor.y + point.y,
                      anchor.x + point.x,
                    ),
                    gold: piece.isGold,
                    bomb: piece.isBomb,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildSocketCell(double width, double height, {Rect? crop}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kSoulStageBottom.withValues(alpha: .64),
        borderRadius: BorderRadius.circular(min(width, height) * .18),
        border: Border.all(
          color: Colors.white.withValues(alpha: .045),
          width: .7,
        ),
      ),
      child: _boardPhoto != null && crop != null
          ? CustomPaint(painter: _SoulPhotoReferencePainter(_boardPhoto!, crop))
          : null,
    );
  }
}

class _GameOverOverlayContent extends StatelessWidget {
  const _GameOverOverlayContent(this.state);
  final _SoulBlockGameState state;

  @override
  Widget build(BuildContext context) {
    final bool canRevive =
        !state._isReviving &&
        !state._isRestarting &&
        !state._isResolvingGameOver &&
        !state._isShowingFullscreenAd &&
        state._reviveAdsUsed < state.maxReviveAdsPerRun;
    final String reviveCount = L10nService().format(
      'soul_block_revive_count',
      <String, Object?>{
        'used': state._reviveAdsUsed,
        'limit': state.maxReviveAdsPerRun,
      },
    );
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: _kSoulStageBottom.withValues(alpha: .92),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: _kSoulWarm,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('util_trchiktthc_010cc1'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _kSoulIvory,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('soul_block_score'),
                    style: SLTheme.quicksand(fontSize: 12, color: _kSoulMuted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state._formatNumber(state._score),
                      style: SLTheme.quicksand(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: _kSoulChrome,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _kSoulPanelTop.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _kSoulWarm.withValues(alpha: .28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.ondemand_video_rounded,
                                color: _kSoulWarm,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  context.tr('soul_block_revive'),
                                  textAlign: TextAlign.center,
                                  style: SLTheme.quicksand(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _kSoulIvory,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            reviveCount,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kSoulMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (state._reviveAdsUsed >= state.maxReviveAdsPerRun)
                            Text(
                              context.tr('soul_block_revive_limit'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kSoulMuted,
                              ),
                            )
                          else
                            FilledButton.icon(
                              onPressed: canRevive
                                  ? state._reviveFromRewardedAd
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _kSoulWarm,
                                foregroundColor: _kSoulStageBottom,
                                disabledBackgroundColor: _kSoulWarm.withValues(
                                  alpha: .35,
                                ),
                                disabledForegroundColor: _kSoulIvory.withValues(
                                  alpha: .62,
                                ),
                                minimumSize: const Size(0, 46),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: state._isReviving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 21,
                                    ),
                              label: Text(
                                state._isReviving
                                    ? context.tr('p7_ad_loading')
                                    : state._isPremiumUser
                                    ? context.tr('util_cquynprohi_0db3f1')
                                    : context.tr('watch_ad'),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        state._isRestarting ||
                            state._isReviving ||
                            state._isResolvingGameOver ||
                            state._isShowingFullscreenAd
                        ? null
                        : state._restartAfterGameOver,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kSoulChrome,
                      foregroundColor: _kSoulStageBottom,
                      disabledBackgroundColor: _kSoulChrome.withValues(
                        alpha: .35,
                      ),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    label: Text(
                      context.tr('util_chili_ddbf84'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
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
}
