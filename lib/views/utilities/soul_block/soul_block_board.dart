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
          final double boardExtent =
              min(constraints.maxWidth, constraints.maxHeight);
          final double cellExtent = _resolveBoardCellExtent(
            boardExtent,
            devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          );
          final double innerExtent =
              boardExtent - (_SoulBlockGameState._boardPanelPadding * 2);
          final double contentExtent =
              (cellExtent * _SoulBlockGameState._boardSize) +
                  (_SoulBlockGameState._boardGap *
                      (_SoulBlockGameState._boardSize - 1));
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
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color.lerp(_kSoulPanelTop, Colors.white, 0.12)!,
                        Color.lerp(_kSoulPanelMid, _kSoulChrome, 0.04)!,
                        Color.lerp(_kSoulPanelBottom, Colors.black, 0.12)!,
                      ],
                      stops: const <double>[0, 0.48, 1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _kSoulChrome.withValues(alpha: 0.40),
                      width: 1.15,
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
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(contentSlack / 2),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _dragVisualTick,
                        builder: (BuildContext context, int _, Widget? __) {
                          return RepaintBoundary(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: List<Widget>.generate(
                                _SoulBlockGameState._boardSize,
                                (int row) {
                                  final bool isLastRow = row ==
                                      (_SoulBlockGameState._boardSize - 1);
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: isLastRow ? 0 : boardGap,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: List<Widget>.generate(
                                        _SoulBlockGameState._boardSize,
                                        (int col) {
                                          final bool isLastCol = col ==
                                              (_SoulBlockGameState._boardSize -
                                                  1);
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
                                },
                                growable: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (_isGameOver) _buildGameOverOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: <Color>[
              const Color(0x00B00020),
              const Color(0x8820122A),
              Colors.black.withValues(alpha: 0.72),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF5A0A18),
                  Color(0xFF17070D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFFFF6B88).withValues(alpha: 0.28),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFF2D55).withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'GAME OVER',
                  style: SLTheme.quicksand(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF7A9E),
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score ${_formatNumber(_score)}  |  $_clearedLines lines',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 18),
                if (!_continueUsedThisRun)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isReviving ? null : _reviveFromRewardedAd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD166),
                        foregroundColor: const Color(0xFF101722),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _isReviving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ondemand_video_rounded),
                      label: Text(
                        _isReviving ? 'Loading Ad...' : 'Watch Ad To Continue',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (!_continueUsedThisRun) const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isRestarting ? null : _returnToMenuFromGameOver,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Menu',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRestarting ? null : _restartAfterGameOver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5C7A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _isRestarting ? 'Loading...' : 'Retry',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _openLeaderboardSheet,
                  child: Text(
                    'View Leaderboard',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFA1B7),
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

  bool _hasLinkedTile(
    int row,
    int col,
    int rowDelta,
    int colDelta,
  ) {
    final _SoulTile? tile = _board[row][col];
    if (tile == null) {
      return false;
    }

    final int nextRow = row + rowDelta;
    final int nextCol = col + colDelta;
    if (nextRow < 0 ||
        nextCol < 0 ||
        nextRow >= _SoulBlockGameState._boardSize ||
        nextCol >= _SoulBlockGameState._boardSize) {
      return false;
    }

    final _SoulTile? neighbor = _board[nextRow][nextCol];
    return neighbor != null && neighbor.pieceId == tile.pieceId;
  }

  int _templateCellKey(int x, int y) => (x << 16) ^ (y & 0xFFFF);

  bool _templateKeyContains(Set<int> cells, int x, int y) {
    return cells.contains(_templateCellKey(x, y));
  }

  ({Color tone, Set<int> templateCells}) _pieceRenderCache(
    _SoulPieceOption piece,
  ) {
    return (
      tone: _kSoulTones[piece.toneIndex % _kSoulTones.length],
      templateCells: piece.template.cellKeySet,
    );
  }

  Widget _buildBoardCell({
    required int row,
    required int col,
    required double cellExtent,
  }) {
    final _SoulTile? tile = _board[row][col];
    final _SoulPieceOption? draggingPiece = _draggingPiece;
    final bool hasPreviewAnchor = _previewRow >= 0 && _previewCol >= 0;
    final bool isPreview = draggingPiece != null &&
        hasPreviewAnchor &&
        _isCellInPreviewFootprint(row, col);
    final bool isClearing =
        _clearingRows.contains(row) || _clearingCols.contains(col);

    if (tile != null) {
      final Color tone = _kSoulTones[tile.toneIndex % _kSoulTones.length];
      final Widget block = _buildGlossyBlock(
        width: cellExtent,
        height: cellExtent,
        tone: tone,
        isClearing: isClearing,
        connectTop: _hasLinkedTile(row, col, -1, 0),
        connectRight: _hasLinkedTile(row, col, 0, 1),
        connectBottom: _hasLinkedTile(row, col, 1, 0),
        connectLeft: _hasLinkedTile(row, col, 0, -1),
      );
      return block;
    }

    if (isPreview) {
      final ({Color tone, Set<int> templateCells}) renderCache =
          _dragPieceRenderCache ?? _pieceRenderCache(draggingPiece);
      final int localX = col - _previewCol;
      final int localY = row - _previewRow;
      return RepaintBoundary(
        child: _buildGlossyBlock(
          width: cellExtent,
          height: cellExtent,
          tone: renderCache.tone,
          isPreview: true,
          isFloating: true,
          connectTop: _templateKeyContains(
              renderCache.templateCells, localX, localY - 1),
          connectRight: _templateKeyContains(
              renderCache.templateCells, localX + 1, localY),
          connectBottom: _templateKeyContains(
              renderCache.templateCells, localX, localY + 1),
          connectLeft: _templateKeyContains(
              renderCache.templateCells, localX - 1, localY),
        ),
      );
    }

    return _buildSocketCell(cellExtent, cellExtent);
  }

  Widget _buildTrayPanel({bool compact = false}) {
    final double pieceGap = compact ? 7 : 8;
    final List<_SoulPieceOption?> slots = List<_SoulPieceOption?>.generate(
      3,
      (int index) => index < _tray.length ? _tray[index] : null,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 12,
        compact ? 7 : 10,
        compact ? 9 : 12,
        compact ? 9 : 13,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        gradient: LinearGradient(
          colors: <Color>[
            Color.lerp(_kSoulPanelTop, Colors.white, 0.10)!,
            Color.lerp(_kSoulPanelMid, _kSoulChrome, 0.03)!,
            Color.lerp(_kSoulPanelBottom, Colors.black, 0.10)!,
          ],
          stops: const <double>[0, 0.50, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _kSoulChrome.withValues(alpha: 0.32),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF071226).withValues(alpha: 0.16),
            blurRadius: 12,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 11,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  'NEXT SET',
                  style: SLTheme.quicksand(
                    fontSize: compact ? 9.8 : 10.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.78),
                    letterSpacing: 0.75,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 10,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFFFFD978),
                      Color(0xFFE9A93A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFFFC95D).withValues(alpha: 0.20),
                      blurRadius: 8,
                      spreadRadius: -6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '${_tray.length}/3',
                  style: SLTheme.quicksand(
                    fontSize: compact ? 10.2 : 11.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF28334B),
                    letterSpacing: compact ? 0.45 : 0.6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List<Widget>.generate(slots.length, (int index) {
                final _SoulPieceOption? piece = slots[index];
                final bool isLast = index == slots.length - 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : pieceGap),
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
      ),
    );
  }

  Widget _buildEmptyPieceCard({bool compact = false}) {
    final double radius = compact ? 18 : 20;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: <Color>[
            _kSoulBoardTop,
            _kSoulBoardMid,
            _kSoulBoardBottom,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            3,
            (int index) => Container(
              width: compact ? 7 : 8,
              height: compact ? 7 : 8,
              margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieceCard(
    _SoulPieceOption piece, {
    bool compact = false,
  }) {
    final bool isDragging = _draggingPiece?.id == piece.id;
    final bool isSnapBack = _snapBackPieceId == piece.id;
    final bool isRecommended = _recommendedMove?.pieceId == piece.id;
    final Widget pieceCardChild = Transform.scale(
      scale: isDragging ? 0.96 : 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double hitPaddingX = compact ? 8 : 10;
          final double hitPaddingY = compact ? 6 : 8;
          return SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: isRecommended ? 0.10 : 0.05),
                            Colors.transparent,
                          ],
                          radius: 0.88,
                          center: const Alignment(0, -0.08),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      hitPaddingX,
                      hitPaddingY,
                      hitPaddingX,
                      compact ? 4 : 5,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: max(0, constraints.maxWidth - (hitPaddingX * 2)),
                        minHeight: max(0, constraints.maxHeight - hitPaddingY - 5),
                      ),
                      child: RepaintBoundary(
                        child: _buildPieceGrid(piece, compact: compact),
                      ),
                    ),
                  ),
                ),
                if (isRecommended)
                  Positioned(
                    top: compact ? -2 : -1,
                    right: compact ? 2 : 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD166).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD166).withValues(alpha: 0.30),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 11,
                        color: Color(0xFFFFD166),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (DragStartDetails details) {
        _startDrag(piece, details.globalPosition);
      },
      onPanUpdate: (DragUpdateDetails details) =>
          _updateDrag(details.globalPosition),
      onPanEnd: (_) => unawaited(_endDrag()),
      onPanCancel: _cancelDrag,
      child: AnimatedScale(
        duration: Duration(milliseconds: isSnapBack ? 170 : 120),
        curve: isSnapBack ? Curves.easeOutBack : Curves.easeOut,
        scale: isDragging
            ? 0.94
            : isSnapBack
                ? 1.06
                : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          opacity: isDragging ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: isDragging,
            child: pieceCardChild,
          ),
        ),
      ),
    );
  }

  Widget _buildDraggedPieceGrid(_SoulPieceOption piece) {
    if (_boardCellExtent <= 0) {
      return const SizedBox.shrink();
    }

    final ({Color tone, Set<int> templateCells}) renderCache =
        _dragPieceRenderCache ?? _pieceRenderCache(piece);
    final double cellFullSize =
        _boardCellExtent + _SoulBlockGameState._boardGap;
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: piece.template.cells.map((Point<int> cell) {
          return Positioned(
            left: cell.x * cellFullSize,
            top: cell.y * cellFullSize,
            width: _boardCellExtent,
            height: _boardCellExtent,
            child: RepaintBoundary(
              child: _buildGlossyBlock(
                width: _boardCellExtent,
                height: _boardCellExtent,
                tone: renderCache.tone,
                isFloating: true,
                connectTop: _templateKeyContains(
                    renderCache.templateCells, cell.x, cell.y - 1),
                connectRight: _templateKeyContains(
                    renderCache.templateCells, cell.x + 1, cell.y),
                connectBottom: _templateKeyContains(
                    renderCache.templateCells, cell.x, cell.y + 1),
                connectLeft: _templateKeyContains(
                    renderCache.templateCells, cell.x - 1, cell.y),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildPieceGrid(
    _SoulPieceOption piece, {
    bool compact = false,
  }) {
    final ({Color tone, Set<int> templateCells}) renderCache =
        _pieceRenderCache(piece);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double previewGap = compact ? 1.6 : 2.0;
        final double previewStrideBase =
            previewGap * (_SoulBlockGameState._trayPreviewGridSize - 1);
        final double usableWidth = max(0, constraints.maxWidth + (compact ? 14 : 18));
        final double usableHeight = max(0, constraints.maxHeight + (compact ? 12 : 16));
        final double previewCell = min(
          (usableWidth - previewStrideBase) /
              _SoulBlockGameState._trayPreviewGridSize,
          (usableHeight - previewStrideBase) /
              _SoulBlockGameState._trayPreviewGridSize,
        ).clamp(10.0, compact ? 30.0 : 36.0).toDouble();
        final int templateWidth = piece.template.width;
        final int templateHeight = piece.template.height;
        final double previewStride = previewCell + previewGap;
        final double contentWidth =
            (templateWidth * previewCell) + ((templateWidth - 1) * previewGap);
        final double contentHeight = (templateHeight * previewCell) +
            ((templateHeight - 1) * previewGap);
        final double originX =
            max(0, (constraints.maxWidth - contentWidth) / 2);
        final double originY =
            max(0, (constraints.maxHeight - contentHeight) / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: piece.template.cells.map((Point<int> cell) {
            return Positioned(
              left: originX + (cell.x * previewStride),
              top: originY + (cell.y * previewStride),
              width: previewCell,
              height: previewCell,
              child: _buildGlossyBlock(
                width: previewCell,
                height: previewCell,
                tone: renderCache.tone,
                connectTop: _templateKeyContains(
                  renderCache.templateCells,
                  cell.x,
                  cell.y - 1,
                ),
                connectRight: _templateKeyContains(
                    renderCache.templateCells, cell.x + 1, cell.y),
                connectBottom: _templateKeyContains(
                    renderCache.templateCells, cell.x, cell.y + 1),
                connectLeft: _templateKeyContains(
                    renderCache.templateCells, cell.x - 1, cell.y),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _buildGlossyBlock({
    required double width,
    required double height,
    required Color tone,
    bool isPreview = false,
    bool isClearing = false,
    bool isFloating = false,
    bool connectTop = false,
    bool connectRight = false,
    bool connectBottom = false,
    bool connectLeft = false,
  }) {
    final double shortSide = min(width, height);
    final double outerRadius = shortSide * 0.14;
    final double joinedRadius = max(1.6, shortSide * 0.045);
    final double faceInset = max(0.9, shortSide * 0.075);
    final double connectedInset = max(0.45, faceInset * 0.24);
    final double leftInset = connectLeft ? connectedInset : faceInset;
    final double rightInset = connectRight ? connectedInset : faceInset;
    final double topInset = connectTop ? connectedInset : faceInset;
    final double bottomInset = connectBottom ? connectedInset : faceInset;
    final Color shellTop = Color.lerp(
      tone,
      Colors.white,
      isPreview ? 0.32 : 0.22,
    )!;
    final Color shellBottom = Color.lerp(
      tone,
      const Color(0xFF0B1934),
      isPreview ? 0.14 : 0.28,
    )!;
    final Color faceTop = Color.lerp(
      tone,
      Colors.white,
      isPreview ? 0.42 : 0.30,
    )!;
    final Color faceBottom = Color.lerp(
      tone,
      const Color(0xFF050B16),
      isPreview ? 0.18 : 0.40,
    )!;
    final BorderRadius shellRadius = BorderRadius.only(
      topLeft: Radius.circular(
        _blockCornerRadius(connectTop, connectLeft, outerRadius, joinedRadius),
      ),
      topRight: Radius.circular(
        _blockCornerRadius(
          connectTop,
          connectRight,
          outerRadius,
          joinedRadius,
        ),
      ),
      bottomLeft: Radius.circular(
        _blockCornerRadius(
          connectBottom,
          connectLeft,
          outerRadius,
          joinedRadius,
        ),
      ),
      bottomRight: Radius.circular(
        _blockCornerRadius(
          connectBottom,
          connectRight,
          outerRadius,
          joinedRadius,
        ),
      ),
    );
    final double faceRadiusBase = max(
      joinedRadius,
      outerRadius - (faceInset * 0.48),
    );
    final BorderRadius faceRadius = BorderRadius.only(
      topLeft: Radius.circular(
        _blockCornerRadius(
          connectTop,
          connectLeft,
          faceRadiusBase,
          joinedRadius,
        ),
      ),
      topRight: Radius.circular(
        _blockCornerRadius(
          connectTop,
          connectRight,
          faceRadiusBase,
          joinedRadius,
        ),
      ),
      bottomLeft: Radius.circular(
        _blockCornerRadius(
          connectBottom,
          connectLeft,
          faceRadiusBase,
          joinedRadius,
        ),
      ),
      bottomRight: Radius.circular(
        _blockCornerRadius(
          connectBottom,
          connectRight,
          faceRadiusBase,
          joinedRadius,
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shellRadius,
        gradient: LinearGradient(
          colors: <Color>[
            shellTop.withValues(alpha: isPreview ? 0.94 : 1.0),
            tone.withValues(alpha: isPreview ? 0.92 : 1.0),
            shellBottom.withValues(alpha: 0.98),
          ],
          stops: const <double>[0, 0.52, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: Colors.black.withValues(alpha: isPreview ? 0.08 : 0.14),
          width: 0.55,
        ),
        boxShadow: const <BoxShadow>[],
      ),
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(leftInset, topInset, rightInset, bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: faceRadius,
            gradient: LinearGradient(
              colors: <Color>[
                faceTop.withValues(alpha: isPreview ? 0.94 : 1.0),
                tone.withValues(alpha: isPreview ? 0.92 : 1.0),
                faceBottom.withValues(alpha: 0.98),
              ],
              stops: const <double>[0, 0.6, 1],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isPreview ? 0.52 : (isClearing ? 0.28 : 0.14)),
              width: isPreview ? 1.0 : 0.7,
            ),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: EdgeInsets.fromLTRB(
                shortSide * 0.22,
                max(0.8, shortSide * 0.08),
                shortSide * 0.22,
                0,
              ),
              height: max(0.9, shortSide * 0.055),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(shortSide),
                color: Colors.white.withValues(alpha: isPreview ? 0.18 : 0.10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocketCell(double width, double height) {
    final double shortSide = min(width, height);
    final BorderRadius radius = BorderRadius.circular(shortSide * 0.13);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: <Color>[
            Color.lerp(_kSoulBoardTop, Colors.white, 0.03)!,
            _kSoulBoardMid,
            Color.lerp(_kSoulBoardBottom, Colors.black, 0.04)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.7,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(shortSide * 0.085),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(shortSide * 0.13),
            gradient: LinearGradient(
              colors: <Color>[
                Color.lerp(_kSoulBoardBottom, Colors.white, 0.04)!,
                Color.lerp(_kSoulBoardBottom, Colors.black, 0.10)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
              width: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  double _blockCornerRadius(
    bool primaryConnected,
    bool secondaryConnected,
    double exposedRadius,
    double joinedRadius,
  ) {
    return (primaryConnected || secondaryConnected)
        ? joinedRadius
        : exposedRadius;
  }
}
