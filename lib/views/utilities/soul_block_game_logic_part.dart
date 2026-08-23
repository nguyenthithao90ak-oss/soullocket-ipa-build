// ignore_for_file: invalid_use_of_protected_member, unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of 'soul_block_game.dart';

extension _SoulBlockGameLogicPart on _SoulBlockGameState {
  Future<void> _maybeShowResumeInterstitial(int pausedAtMs) async {
    if (_view != _SoulGameView.gameplay ||
        _isGameOver ||
        _isShowingFullscreenAd ||
        _draggingPiece != null) {
      return;
    }

    final pausedFor = DateTime.now().millisecondsSinceEpoch - pausedAtMs;
    if (pausedFor < const Duration(minutes: 2).inMilliseconds) {
      return;
    }
    if (_random.nextDouble() > 0.33) {
      return;
    }

    _isShowingFullscreenAd = true;
    try {
      await _adMob.showInterstitialAd();
    } finally {
      _isShowingFullscreenAd = false;
    }
  }

  Future<void> _openPremiumStore() async {
    _emitClickFeedback();
    if (!AppConfig.isPurchaseEnabled) {
      _showSnackBar(context.tr('util_mcnyangtmn_fdd99c'));
      return;
    }
    final houseId = _houseId ?? await _houseService.getCurrentHouseId() ?? '';
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumStoreScreen(
          houseId: houseId,
          myName: context.tr('util_bn_1fd75b'),
        ),
      ),
    );

    await _syncBannerAfterPremium();
  }

  Future<void> _persistSetting(String key, bool value) async {
    final prefs = await _prefsFuture;
    await prefs.setBool(key, value);
  }

  Future<void> _setSoundEnabled(bool value) async {
    setState(() {
      _soundEnabled = value;
    });
    await _persistSetting(_soundEnabledKey, value);
    await _syncBgmWithSound();
    if (value) {
      _emitClickFeedback();
    }
  }

  Future<void> _setVibrationEnabled(bool value) async {
    setState(() {
      _vibrationEnabled = value;
    });
    await _persistSetting(_vibrationEnabledKey, value);
    if (value) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _setSmoothGraphicsEnabled(bool value) async {
    setState(() {
      _smoothGraphics = value;
      _performanceProfile = _resolvePerformanceProfile();
    });
    await _persistSetting(_smoothGraphicsKey, value);
  }

  bool get _canRunAutoTrayShuffle =>
      _autoTrayShuffleEnabled &&
      _isPremiumUser &&
      _view == _SoulGameView.gameplay &&
      !_isGameOver;

  void _syncAutoTrayShuffleTimer({bool resetWindow = false}) {
    _autoTrayShuffleTimer?.cancel();
    _autoTrayShuffleTimer = null;

    if (!_canRunAutoTrayShuffle) {
      _autoTrayShuffleNextAt = null;
      return;
    }

    final DateTime now = DateTime.now();
    if (resetWindow || _autoTrayShuffleNextAt == null) {
      _autoTrayShuffleNextAt =
          now.add(_SoulBlockGameState._autoTrayShuffleInterval);
    }

    final Duration delay = _autoTrayShuffleNextAt!.difference(now);
    _autoTrayShuffleTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_handleAutoTrayShuffleTick()),
    );
  }

  Future<void> _handleAutoTrayShuffleTick() async {
    _autoTrayShuffleTimer = null;

    if (!_canRunAutoTrayShuffle) {
      _autoTrayShuffleNextAt = null;
      return;
    }

    if (_isBusy ||
        _draggingPiece != null ||
        _isReviving ||
        _isRestarting ||
        _isShowingFullscreenAd) {
      _autoTrayShuffleNextAt =
          DateTime.now().add(_SoulBlockGameState._autoTrayShuffleRetryDelay);
      _syncAutoTrayShuffleTimer();
      return;
    }

    _rerollRandomTrayPieces(automatic: true);
    _autoTrayShuffleNextAt =
        DateTime.now().add(_SoulBlockGameState._autoTrayShuffleInterval);
    _syncAutoTrayShuffleTimer();
  }

  bool _rerollRandomTrayPieces({required bool automatic}) {
    if (_tray.isEmpty || _isGameOver || _isBusy || _draggingPiece != null) {
      return false;
    }

    final int trayLength = _tray.length;
    final int replacementCount =
        trayLength == 1 ? 1 : min(trayLength, 1 + _random.nextInt(2));
    final List<int> shuffledIndices =
        List<int>.generate(trayLength, (int index) => index)..shuffle(_random);
    final List<_SoulPieceOption> replacementPool = _buildSmartBatch(_board);
    if (replacementPool.isEmpty) {
      return false;
    }

    var nextTray = List<_SoulPieceOption>.from(_tray);
    for (var index = 0; index < replacementCount; index++) {
      nextTray[shuffledIndices[index]] =
          replacementPool[index % replacementPool.length];
    }

    var nextRecommended = _recommendMoveFor(_board, nextTray);
    if (nextRecommended == null) {
      nextTray =
          _buildSmartBatch(_board).take(trayLength).toList(growable: false);
      if (nextTray.length != trayLength) {
        return false;
      }
      nextRecommended = _recommendMoveFor(_board, nextTray);
      if (nextRecommended == null) {
        return false;
      }
    }

    setState(() {
      _tray = nextTray;
      _recommendedMove = nextRecommended;
    });

    _showFloatingMessage(
      automatic
          ? 'T\u1ef1 \u0111\u1ed9ng \u0111\u1ed5i $replacementCount kh\u1ed1i'
          : '\u0110\u00e3 \u0111\u1ed5i $replacementCount kh\u1ed1i',
      color: automatic ? const Color(0xFF7AE7FF) : const Color(0xFFFFD166),
    );
    return true;
  }

  void _returnToMenuFromSettings() {
    _emitClickFeedback();
    setState(() {
      _clearDragVisualState(notify: false);
      _isBusy = false;
      _isGameOver = false;
      _isReviving = false;
      _isRestarting = false;
      _memoryBurstSnapshot = null;
      _explosionParticles = <_ExplosionParticle>[];
      _floatingText = null;
      _snapBackPieceId = null;
      _view = _SoulGameView.menu;
    });
    _resumeMenuPulse();
    _syncAutoTrayShuffleTimer();
    _markDragVisualDirty();
    _scheduleMenuRunWarmup();
  }

  void _restartCurrentRunFromSettings() {
    if (_isRestarting || _isOpeningGameplay) {
      return;
    }
    _emitClickFeedback();
    if (_view == _SoulGameView.menu) {
      _resumeMenuPulse();
      unawaited(_startSessionFromMenu());
      return;
    }
    setState(() {
      _isRestarting = true;
      _clearDragVisualState(notify: false);
    });
    _markDragVisualDirty();
    _startNewGame(openGameplay: true);
  }

  Future<void> _exitToHomeFromSettings() async {
    _emitClickFeedback();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Future<void> _startSessionFromMenu() async {
    if (_isOpeningGameplay || _view != _SoulGameView.menu) {
      return;
    }
    _emitClickFeedback();
    setState(() {
      _isOpeningGameplay = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    final _PreparedSoulRun? preparedRun = _preparedMenuRun;
    _preparedMenuRun = null;
    _startNewGame(
      openGameplay: true,
      preparedRun: preparedRun,
    );
  }

  _PreparedSoulRun _prepareFreshRun() {
    final nextBoard = _createOpeningBoard();
    final nextTray = _buildSmartBatch(nextBoard);
    return _PreparedSoulRun(
      board: nextBoard,
      tray: nextTray,
      recommendedMove: _recommendMoveFor(nextBoard, nextTray),
      sessionId: DateTime.now().microsecondsSinceEpoch,
    );
  }

  void _scheduleMenuRunWarmup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _view != _SoulGameView.menu ||
          _preparedMenuRun != null ||
          _loadError != null) {
        return;
      }
      final _PreparedSoulRun preparedMenuRun = _prepareFreshRun();
      if (!mounted || _view != _SoulGameView.menu) {
        return;
      }
      setState(() {
        _preparedMenuRun = preparedMenuRun;
      });
    });
  }

  void _startNewGame({
    required bool openGameplay,
    _PreparedSoulRun? preparedRun,
  }) {
    final _PreparedSoulRun nextRun = preparedRun ?? _prepareFreshRun();
    final bool restoringExistingRun = preparedRun != null;
    _memoryBurstController.stop();
    _explosionController.stop();

    setState(() {
      _board = _cloneBoard(nextRun.board);
      _tray = List<_SoulPieceOption>.from(nextRun.tray);
      _recommendedMove = nextRun.recommendedMove;
      _score = restoringExistingRun ? _score : 0;
      _combo = restoringExistingRun ? _combo : 0;
      _streak = restoringExistingRun ? _streak : 0;
      _turn = restoringExistingRun ? _turn : 0;
      _clearedLines = restoringExistingRun ? _clearedLines : 0;
      _scorePulseTick = 0;
      _currentSessionId = nextRun.sessionId;
      _draggingPiece = null;
      _previewRow = -1;
      _previewCol = -1;
      _dragBoardMask = null;
      _clearingRows = <int>{};
      _clearingCols = <int>{};
      _clearingCells = <Point<int>>{};
      _floatingText = null;
      _memoryBurstSnapshot = null;
      _snapBackPieceId = null;
      _isBusy = false;
      _isGameOver = nextRun.tray.isEmpty || nextRun.recommendedMove == null;
      _continueUsedThisRun =
          restoringExistingRun ? _continueUsedThisRun : false;
      _isReviving = false;
      _isRestarting = false;
      _isOpeningGameplay = false;
      if (openGameplay) {
        _view = _SoulGameView.gameplay;
      }
    });
    if (openGameplay) {
      _pauseMenuPulse();
    } else {
      _resumeMenuPulse();
    }
    _syncAutoTrayShuffleTimer(resetWindow: openGameplay);
    if (openGameplay) {
      unawaited(_syncBgmWithSound(restartIfStopped: true));
    }

    if (_isGameOver) {
      unawaited(_handleGameOverTransition());
    }
  }

  String _memoryBurstGalleryKeyFor(String? houseId) {
    final normalizedHouseId = houseId?.trim() ?? '';
    return '${widget.storageKeyPrefix}_memory_burst_gallery_$normalizedHouseId';
  }

  List<String> _decodeMemoryBurstGallery(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>[];
      }
      final urls = <String>[];
      final seen = <String>{};
      for (final Object? item in decoded) {
        final String normalized = (item as String? ?? '').trim();
        if (normalized.isEmpty || !seen.add(normalized)) {
          continue;
        }
        urls.add(normalized);
      }
      return urls;
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _refreshMemoryBurstGallery(String houseId) async {
    final String normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty || _isRefreshingMemoryBurstGallery) {
      return;
    }

    _isRefreshingMemoryBurstGallery = true;
    try {
      final List<String> nextGallery = [];
      final Set<String> seenUrls = {};

      final memoriesSnap = await FirebaseFirestore.instance
          .collection('houses')
          .doc(normalizedHouseId)
          .collection('memories')
          .orderBy('ts', descending: true)
          .limit(48)
          .get();

      for (var doc in memoriesSnap.docs) {
        final data = doc.data();
        for (final key in <String>['url', 'imageUrl', 'photoUrl', 'mediaUrl']) {
          final url = (data[key] as String? ?? '').trim();
          if (url.isNotEmpty && url.startsWith('http') && seenUrls.add(url)) {
            nextGallery.add(url);
            break;
          }
        }
      }

      if (nextGallery.length < 8) {
        final albumSnap = await FirebaseFirestore.instance
            .collection('houses')
            .doc(normalizedHouseId)
            .collection('album')
            .orderBy('ts', descending: true)
            .limit(48)
            .get();

        for (var doc in albumSnap.docs) {
          final data = doc.data();
          for (final key in <String>[
            'url',
            'imageUrl',
            'photoUrl',
            'mediaUrl',
            'thumbUrl'
          ]) {
            final url = (data[key] as String? ?? '').trim();
            if (url.isNotEmpty && url.startsWith('http') && seenUrls.add(url)) {
              nextGallery.add(url);
              break;
            }
          }
          if (nextGallery.length >= 18) {
            break;
          }
        }
      }

      if (nextGallery.isEmpty) {
        return;
      }

      final SharedPreferences prefs = await _prefsFuture;
      await prefs.setString(
        _memoryBurstGalleryKeyFor(normalizedHouseId),
        jsonEncode(nextGallery),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _memoryBurstGallery = nextGallery;
        _memoryBurstAspectRatios
            .removeWhere((String url, _) => !seenUrls.contains(url));
      });
      unawaited(
        _warmMemoryBurstImages(
          nextGallery,
          limit: _performanceProfile.memoryBurstWarmLimit,
        ),
      );
    } catch (error) {
      debugPrint(
        'Soul Block memory burst gallery load failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('util_khngthtinh_a304c7'),
        ).message}',
      );
    } finally {
      _isRefreshingMemoryBurstGallery = false;
    }
  }

  List<List<_SoulTile?>> _createEmptyBoard() {
    return List<List<_SoulTile?>>.generate(
      _boardSize,
      (_) => List<_SoulTile?>.filled(_boardSize, null),
    );
  }

  List<List<_SoulTile?>> _createOpeningBoard() {
    final List<List<_SoulTile?>> board = _createEmptyBoard();

    void placeCells(
      List<Point<int>> cells,
      int toneIndex,
      int pieceId,
    ) {
      for (final Point<int> cell in cells) {
        if (cell.y >= 0 &&
            cell.y < _boardSize &&
            cell.x >= 0 &&
            cell.x < _boardSize) {
          board[cell.y][cell.x] = _SoulTile(
            toneIndex: toneIndex,
            pieceId: pieceId,
            placedTurn: 0,
          );
        }
      }
    }

    // Smart opening: Row/col gần đầy để người dùng nổ nhanh
    // Mỗi pattern có 4 nhóm khối, tổng ~20-24 ô được lấp
    final List<List<List<Point<int>>>> smartOpeningPatterns =
        <List<List<Point<int>>>>[
      // Pattern A: Row 7 (6/8) + Col 7 (6/8) + row 0 (6/8) → user đặt 3 ô là nổ
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 7),
          const Point<int>(1, 7),
          const Point<int>(2, 7),
          const Point<int>(3, 7),
          const Point<int>(4, 7),
          const Point<int>(5, 7),
        ],
        <Point<int>>[
          const Point<int>(7, 0),
          const Point<int>(7, 1),
          const Point<int>(7, 2),
          const Point<int>(7, 3),
          const Point<int>(7, 4),
          const Point<int>(7, 5),
        ],
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(1, 0),
          const Point<int>(2, 0),
          const Point<int>(3, 0),
          const Point<int>(4, 0),
          const Point<int>(5, 0),
        ],
        <Point<int>>[
          const Point<int>(2, 3),
          const Point<int>(3, 3),
          const Point<int>(2, 4),
          const Point<int>(3, 4),
        ],
      ],
      // Pattern B: 2 rows gần đầy + cluster trung tâm
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 6),
          const Point<int>(1, 6),
          const Point<int>(2, 6),
          const Point<int>(4, 6),
          const Point<int>(5, 6),
          const Point<int>(6, 6),
        ],
        <Point<int>>[
          const Point<int>(0, 7),
          const Point<int>(1, 7),
          const Point<int>(2, 7),
          const Point<int>(3, 7),
          const Point<int>(5, 7),
          const Point<int>(6, 7),
        ],
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(0, 1),
          const Point<int>(0, 2),
          const Point<int>(0, 3),
          const Point<int>(0, 5),
          const Point<int>(0, 6),
        ],
        <Point<int>>[
          const Point<int>(3, 3),
          const Point<int>(4, 3),
          const Point<int>(3, 4),
          const Point<int>(4, 4),
        ],
      ],
      // Pattern C: Col 0 (6/8) + Col 7 (5/8) + row 7 gần đầy
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(7, 0),
          const Point<int>(7, 1),
          const Point<int>(7, 2),
          const Point<int>(7, 5),
          const Point<int>(7, 6),
        ],
        <Point<int>>[
          const Point<int>(0, 7),
          const Point<int>(0, 6),
          const Point<int>(0, 5),
          const Point<int>(0, 2),
          const Point<int>(0, 1),
          const Point<int>(0, 0),
        ],
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(1, 0),
          const Point<int>(2, 0),
          const Point<int>(3, 0),
          const Point<int>(5, 0),
          const Point<int>(6, 0),
        ],
        <Point<int>>[
          const Point<int>(4, 3),
          const Point<int>(5, 3),
          const Point<int>(4, 4),
          const Point<int>(5, 4),
        ],
      ],
      // Pattern D: Diagonal clusters + 2 near-full rows
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(1, 0),
          const Point<int>(2, 0),
          const Point<int>(3, 0),
          const Point<int>(4, 0),
          const Point<int>(6, 0),
        ],
        <Point<int>>[
          const Point<int>(1, 7),
          const Point<int>(2, 7),
          const Point<int>(3, 7),
          const Point<int>(4, 7),
          const Point<int>(5, 7),
          const Point<int>(6, 7),
        ],
        <Point<int>>[
          const Point<int>(2, 2),
          const Point<int>(3, 2),
          const Point<int>(2, 3),
        ],
        <Point<int>>[
          const Point<int>(5, 5),
          const Point<int>(6, 5),
          const Point<int>(6, 4),
          const Point<int>(5, 4),
        ],
      ],
      // Pattern E: 3 near-full cols spread
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(0, 1),
          const Point<int>(0, 2),
          const Point<int>(0, 4),
          const Point<int>(0, 5),
          const Point<int>(0, 6),
        ],
        <Point<int>>[
          const Point<int>(4, 0),
          const Point<int>(4, 1),
          const Point<int>(4, 2),
          const Point<int>(4, 4),
          const Point<int>(4, 5),
          const Point<int>(4, 6),
        ],
        <Point<int>>[
          const Point<int>(7, 0),
          const Point<int>(7, 1),
          const Point<int>(7, 2),
          const Point<int>(7, 4),
          const Point<int>(7, 5),
          const Point<int>(7, 6),
        ],
        <Point<int>>[
          const Point<int>(2, 3),
          const Point<int>(3, 3),
          const Point<int>(5, 3),
          const Point<int>(6, 3),
        ],
      ],
    ];

    final List<List<Point<int>>> selectedPattern =
        smartOpeningPatterns[_random.nextInt(smartOpeningPatterns.length)];
    for (int index = 0; index < selectedPattern.length; index++) {
      placeCells(
        selectedPattern[index],
        index % _kSoulTones.length,
        -(index + 1),
      );
    }

    final targetOpeningCells = 40 + _random.nextInt(5);
    var filledCells = 0;
    for (var row = 0; row < _boardSize; row++) {
      for (var col = 0; col < _boardSize; col++) {
        if (board[row][col] != null) filledCells++;
      }
    }

    var guard = 0;
    while (filledCells < targetOpeningCells && guard < 240) {
      guard++;
      final row = _random.nextInt(_boardSize);
      final col = _random.nextInt(_boardSize);
      if (board[row][col] != null) continue;

      var rowCount = 0;
      var colCount = 0;
      for (var i = 0; i < _boardSize; i++) {
        if (board[row][i] != null) rowCount++;
        if (board[i][col] != null) colCount++;
      }
      if (rowCount >= _boardSize - 1 || colCount >= _boardSize - 1) continue;

      board[row][col] = _SoulTile(
        toneIndex: (row + col) % _kSoulTones.length,
        pieceId: -100 - filledCells,
        placedTurn: 0,
      );
      filledCells++;
    }

    return board;
  }

  List<List<_SoulTile?>> _cloneBoard(List<List<_SoulTile?>> board) {
    return List<List<_SoulTile?>>.generate(
      _boardSize,
      (int row) => List<_SoulTile?>.from(board[row]),
    );
  }

  int _nearestBoardIndex(double relativeOffset, double cellFullSize) {
    return ((relativeOffset + (cellFullSize / 2)) / cellFullSize).floor();
  }

  bool _isInsideBoardBounds(_SoulPieceOption piece, int row, int col) {
    return row >= 0 &&
        col >= 0 &&
        row + piece.template.height <= _boardSize &&
        col + piece.template.width <= _boardSize;
  }

  void _startDrag(_SoulPieceOption piece, Offset globalPosition,
      {bool fromHold = false}) {
    if (_isGameOver || _isBusy || _view != _SoulGameView.gameplay) {
      return;
    }

    _draggingFromHold = fromHold;
    _updateBoardMetrics();
    _dragBoardMask = _boardMask(_board);
    _dragPieceRenderCache = _pieceRenderCache(piece);
    _dragPreviewFootprintKeys = null;
    _dragOverlayWidth = _dragPieceWidthPixels(piece);
    _dragOverlayHeight = _dragPieceHeightPixels(piece);
    _draggedPieceOverlay = _buildDraggedPieceGrid(piece);
    final preview = _resolvePreviewCell(piece, globalPosition);
    _emitLiftFeedback();
    _draggingPiece = piece;
    _dragPosition = globalPosition;
    _previewRow = preview.row;
    _previewCol = preview.col;
    _dragPreviewFootprintKeys =
        _previewFootprintKeys(piece, preview.row, preview.col);
    _markDragVisualDirty();
    _markTrayVisualDirty();
    _markDragOverlayDirty();
  }

  void _updateDrag(Offset globalPosition) {
    final draggingPiece = _draggingPiece;
    if (draggingPiece == null || _isBusy) {
      return;
    }

    final preview = _resolvePreviewCell(draggingPiece, globalPosition);
    final Offset previousPosition = _dragPosition;
    final bool previewChanged =
        preview.row != _previewRow || preview.col != _previewCol;
    final bool movedEnoughForPreview =
        (globalPosition - previousPosition).distanceSquared >=
            (_SoulBlockGameState._dragUpdateEpsilon *
                _SoulBlockGameState._dragUpdateEpsilon);
    if (!movedEnoughForPreview && !previewChanged) {
      return;
    }

    _dragPosition = globalPosition;
    _previewRow = preview.row;
    _previewCol = preview.col;
    if (previewChanged) {
      _dragPreviewFootprintKeys =
          _previewFootprintKeys(draggingPiece, preview.row, preview.col);
      _markDragVisualDirty();
    }

    final bool movedEnoughForOverlay =
        (globalPosition - previousPosition).distanceSquared >=
            (_SoulBlockGameState._dragOverlayUpdateEpsilon *
                _SoulBlockGameState._dragOverlayUpdateEpsilon);
    if (previewChanged || movedEnoughForOverlay) {
      _markDragOverlayDirty();
    }
  }

  void _cancelDrag() {
    _clearDragVisualState();
  }

  bool _isInsideHoldArea(Offset globalPosition) {
    final RenderBox? box =
        _holdAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height)
        .contains(globalPosition);
  }

  Future<void> _endDrag() async {
    if (_draggingPiece != null) {
      final piece = _draggingPiece!;
      if (_previewRow >= 0 && _previewCol >= 0) {
        final row = _previewRow;
        final col = _previewCol;
        _clearDragVisualState();
        await _placePieceAt(piece, row, col);
        return;
      }

      if (!_draggingFromHold && _isInsideHoldArea(_dragPosition)) {
        _clearDragVisualState();
        _emitPlaceFeedback();
        setState(() {
          final temp = _holdPiece;
          _holdPiece = piece;
          _tray = List<_SoulPieceOption>.from(_tray)
            ..removeWhere((item) => item.id == piece.id);
          if (temp != null) {
            _tray.add(temp);
          }
        });
        _markTrayVisualDirty();
        return;
      }
    }
    final _SoulPieceOption? piece = _draggingPiece;
    _cancelDrag();
    if (piece != null && mounted) {
      setState(() => _snapBackPieceId = piece.id);
      _markTrayVisualDirty();
      await Future<void>.delayed(const Duration(milliseconds: 170));
      if (!mounted || _snapBackPieceId != piece.id) {
        return;
      }
      setState(() => _snapBackPieceId = null);
      _markTrayVisualDirty();
    }
  }

  ({int row, int col}) _resolvePreviewCell(
    _SoulPieceOption piece,
    Offset globalPosition,
  ) {
    if (_boardCellExtent <= 0) {
      return (row: -1, col: -1);
    }

    final cellFullSize = _boardCellExtent + _SoulBlockGameState._boardGap;
    final Offset pieceOffset = _dragReferencePosition(piece, globalPosition);

    final relativeX = pieceOffset.dx -
        _boardOrigin.dx -
        _SoulBlockGameState._boardPanelPadding -
        _boardContentInset;
    final relativeY = pieceOffset.dy -
        _boardOrigin.dy -
        _SoulBlockGameState._boardPanelPadding -
        _boardContentInset;

    final baseCol = _nearestBoardIndex(relativeX, cellFullSize);
    final baseRow = _nearestBoardIndex(relativeY, cellFullSize);
    final boardMask = _dragBoardMask ?? _boardMask(_board);

    bool canPlaceAt(int row, int col) {
      return _isInsideBoardBounds(piece, row, col) &&
          _canPlace(boardMask, piece.template, row, col);
    }

    if (canPlaceAt(baseRow, baseCol)) {
      return (row: baseRow, col: baseCol);
    }

    const neighborOffsets = <({int rowOffset, int colOffset})>[
      (rowOffset: 0, colOffset: -1),
      (rowOffset: 0, colOffset: 1),
      (rowOffset: -1, colOffset: 0),
      (rowOffset: 1, colOffset: 0),
      (rowOffset: -1, colOffset: -1),
      (rowOffset: -1, colOffset: 1),
      (rowOffset: 1, colOffset: -1),
      (rowOffset: 1, colOffset: 1),
    ];

    ({int row, int col})? bestMatch;
    double bestDistance = double.infinity;

    for (final offset in neighborOffsets) {
      final row = baseRow + offset.rowOffset;
      final col = baseCol + offset.colOffset;
      if (!canPlaceAt(row, col)) {
        continue;
      }
      final center = _boardCellCenter(row.toDouble(), col.toDouble());
      final distance = (center - globalPosition).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = (row: row, col: col);
      }
    }

    return bestMatch ?? (row: -1, col: -1);
  }

  Future<void> _placePieceAt(
    _SoulPieceOption piece,
    int row,
    int col,
  ) async {
    if (_isGameOver || _isBusy) {
      return;
    }

    final boardMask = _boardMask(_board);
    if (!_canPlace(boardMask, piece.template, row, col)) {
      return;
    }

    _isBusy = true;

    final placedBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (boardRow) => List<_SoulTile?>.from(_board[boardRow]),
    );
    for (final cell in piece.template.cells) {
      placedBoard[row + cell.y][col + cell.x] = _SoulTile(
        toneIndex: piece.toneIndex,
        pieceId: piece.id,
        placedTurn: _turn + 1,
      );
    }

    final bombClearedCells = <Point<int>>[];
    if (piece.isBomb) {
      final int centerRow = row + piece.template.height ~/ 2;
      final int centerCol = col + piece.template.width ~/ 2;
      for (int r = centerRow - 1; r <= centerRow + 1; r++) {
        for (int c = centerCol - 1; c <= centerCol + 1; c++) {
          if (r >= 0 && r < _boardSize && c >= 0 && c < _boardSize) {
            if (placedBoard[r][c] != null) {
              placedBoard[r][c] = null;
              bombClearedCells.add(Point<int>(c, r));
            }
          }
        }
      }
    }

    final clearedRows = <int>[];
    final clearedCols = <int>[];
    for (var boardRow = 0; boardRow < _boardSize; boardRow++) {
      if (placedBoard[boardRow].every((cell) => cell != null)) {
        clearedRows.add(boardRow);
      }
    }
    for (var boardCol = 0; boardCol < _boardSize; boardCol++) {
      var full = true;
      for (var boardRow = 0; boardRow < _boardSize; boardRow++) {
        if (placedBoard[boardRow][boardCol] == null) {
          full = false;
          break;
        }
      }
      if (full) {
        clearedCols.add(boardCol);
      }
    }

    final clearedNow = clearedRows.length + clearedCols.length;
    int gainedScore = _scoreGainFor(piece.template, clearedNow, _combo);
    if (piece.isBomb) {
      gainedScore += bombClearedCells.length * 10;
    }
    if (piece.isGold) {
      gainedScore *= 2;
    }
    final nextScore = _score + gainedScore;
    final nextCombo = clearedNow > 0 ? _combo + 1 : 0;
    final nextStreak = clearedNow > 0 ? _streak + 1 : 0;
    final bool beatBestThisMove =
        _score <= _bestScore && nextScore > _bestScore;
    final List<_SoulPieceOption> remainingTray;
    if (_draggingFromHold) {
      remainingTray = _tray;
    } else {
      remainingTray = List<_SoulPieceOption>.from(_tray)
        ..removeWhere((item) => item.id == piece.id);
    }

    if (piece.isBomb) {
      _emitBombFeedback();
    } else {
      _emitPlaceFeedback();
    }
    if (piece.isBomb && bombClearedCells.isNotEmpty) {
      _showFloatingMessage(
        'BOOM! +${bombClearedCells.length * 10}',
        color: const Color(0xFFFF4500),
      );
      _triggerScreenPulse();
    }
    if (piece.isGold) {
      _showFloatingMessage(
        'GOLD! X2 POINTS',
        color: const Color(0xFFFFD700),
      );
      _triggerScreenPulse();
    }

    if (clearedNow > 0) {
      _emitClearFeedback(
        clearedCount: clearedNow,
        streakCount: nextStreak,
      );
      _triggerScreenPulse();
      if (clearedNow >= 2) {
        _showComboBurst(clearedNow);
      } else if (nextStreak >= 2) {
        _showFloatingMessage(
          'Chain x$nextStreak!',
          color: const Color(0xFF00C3FF),
        );
      }
    }
    if (beatBestThisMove) {
      _emitBestScoreFeedback();
      // Removed 'New Best!' floating message to reduce spam during gameplay.
    }

    setState(() {
      _board = placedBoard;
      _tray = remainingTray;
      if (_draggingFromHold) {
        _holdPiece = null;
      }
      _turn += 1;
      _score = nextScore;
      _combo = nextCombo;
      _streak = nextStreak;
      _scorePulseTick += 1;
      _clearingRows = clearedRows.toSet();
      _clearingCols = clearedCols.toSet();
      _clearingCells = bombClearedCells.toSet();
    });

    if (clearedNow > 0 || bombClearedCells.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) {
        return;
      }
    }

    final resolvedBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (boardRow) => List<_SoulTile?>.from(placedBoard[boardRow]),
    );
    for (final boardRow in clearedRows) {
      for (var boardCol = 0; boardCol < _boardSize; boardCol++) {
        resolvedBoard[boardRow][boardCol] = null;
      }
    }
    for (final boardCol in clearedCols) {
      for (var boardRow = 0; boardRow < _boardSize; boardRow++) {
        resolvedBoard[boardRow][boardCol] = null;
      }
    }

    final replenishedTray =
        remainingTray.isEmpty ? _buildSmartBatch(resolvedBoard) : remainingTray;
    final nextRecommended = _recommendMoveFor(resolvedBoard, replenishedTray);
    final noMovesLeft = replenishedTray.isEmpty || nextRecommended == null;

    setState(() {
      _board = resolvedBoard;
      _tray = replenishedTray;
      _recommendedMove = nextRecommended;
      _clearingRows = <int>{};
      _clearingCols = <int>{};
      _clearingCells = <Point<int>>{};
      _clearedLines += clearedNow;
      _isGameOver = noMovesLeft;
      _isBusy = false;
    });

    if (clearedNow > 0) {
      _triggerExplosionEffect(
        clearedCount: clearedNow,
        clearedRows: clearedRows,
        clearedCols: clearedCols,
        subtle: clearedNow == 1,
      );
    } else if (beatBestThisMove) {
      _triggerExplosionEffect(
        clearedCount: 2,
        clearedRows: <int>[row],
        clearedCols: <int>[col],
        subtle: true,
      );
    } else if (bombClearedCells.isNotEmpty) {
      _triggerExplosionEffect(
        clearedCount: 2,
        clearedRows: <int>[row],
        clearedCols: <int>[col],
        subtle: false,
      );
    }
    final bool shouldTriggerBurst = (clearedNow >= 2) ||
        (clearedNow == 1 && nextStreak.isEven && nextStreak >= 2);
    if (clearedNow > 0 && shouldTriggerBurst) {
      _triggerMemoryBurstReward(
        clearedCount: clearedNow,
        streakCount: nextStreak,
      );
    }

    if (nextScore > _bestScore) {
      unawaited(_persistBestScore(nextScore));
    }
    unawaited(_persistSavedRun());
    if (noMovesLeft) {
      await _handleGameOverTransition();
    }
  }

  void _rotatePiece(_SoulPieceOption piece) {
    if (_isGameOver || _isBusy) return;

    _emitClickFeedback();

    final int index = _tray.indexWhere((p) => p.id == piece.id);
    if (index != -1) {
      setState(() {
        _tray[index] = _SoulPieceOption(
          id: piece.id,
          template: piece.template.rotate(),
          toneIndex: piece.toneIndex,
        );
        _recommendedMove = _recommendMoveFor(_board, _tray);
      });
      _markTrayVisualDirty();
    } else if (_holdPiece != null && _holdPiece!.id == piece.id) {
      setState(() {
        _holdPiece = _SoulPieceOption(
          id: piece.id,
          template: piece.template.rotate(),
          toneIndex: piece.toneIndex,
        );
        _recommendedMove = _recommendMoveFor(_board, _tray);
      });
      _markTrayVisualDirty();
    }
  }

  void _setBoardSize(int size) {
    if (_boardSize == size) return;
    setState(() {
      _boardSize = size;
      _preparedMenuRun = null;
    });
    _scheduleMenuRunWarmup();
  }

  Future<void> _handleGameOverTransition() async {
    _cancelDrag();
    _memoryBurstController.stop();
    _combo = 0;
    _streak = 0;
    await _clearSavedRun();
    await _persistCurrentRunScore();
    _adMob.preloadSoulGameRewardedAd();
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (mounted) {
      setState(() {});
    }
    _syncAutoTrayShuffleTimer();
  }

  void _returnToMenuFromGameOver() {
    _emitClickFeedback();
    unawaited(_clearSavedRun());
    setState(() {
      _draggingPiece = null;
      _previewRow = -1;
      _previewCol = -1;
      _dragBoardMask = null;
      _draggedPieceOverlay = null;
      _isBusy = false;
      _isGameOver = false;
      _isReviving = false;
      _isRestarting = false;
      _memoryBurstSnapshot = null;
      _view = _SoulGameView.menu;
    });
    _resumeMenuPulse();
    _syncAutoTrayShuffleTimer();
    _scheduleMenuRunWarmup();
  }

  Future<void> _restartAfterGameOver() async {
    if (_isRestarting) {
      return;
    }

    _emitClickFeedback();
    setState(() {
      _isRestarting = true;
    });

    _isShowingFullscreenAd = true;
    try {
      await _adMob.showInterstitialAd();
    } finally {
      _isShowingFullscreenAd = false;
    }

    if (!mounted) {
      return;
    }
    _startNewGame(openGameplay: true);
  }

  Future<void> _reviveFromRewardedAd() async {
    if (_isReviving || _continueUsedThisRun) {
      return;
    }

    _emitClickFeedback();
    setState(() {
      _isReviving = true;
    });

    final rewarded = await _adMob.showSoulGameRewardedAd();
    if (!mounted) {
      return;
    }

    if (!rewarded) {
      setState(() {
        _isReviving = false;
      });
      _showSnackBar(context.tr('util_qungcochas_90f64e'));
      return;
    }

    final occupiedRows = <int>[];
    for (var row = 0; row < _boardSize; row++) {
      if (_board[row].any((tile) => tile != null)) {
        occupiedRows.add(row);
      }
    }
    occupiedRows.shuffle(_random);
    final revivedRows = occupiedRows.take(min(3, occupiedRows.length)).toSet();

    final nextBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (row) => List<_SoulTile?>.from(_board[row]),
    );
    for (final row in revivedRows) {
      for (var col = 0; col < _boardSize; col++) {
        nextBoard[row][col] = null;
      }
    }

    var nextTray = List<_SoulPieceOption>.from(_tray);
    var nextRecommended = _recommendMoveFor(nextBoard, nextTray);
    if (nextRecommended == null) {
      nextTray = List<_SoulPieceOption>.from(nextTray)
        ..add(_spawnPieceFromTemplate(_kSoulBlockTemplates.first));
      nextRecommended = _recommendMoveFor(nextBoard, nextTray);
    }

    setState(() {
      _board = nextBoard;
      _tray = nextTray;
      _recommendedMove = nextRecommended;
      _clearingRows = revivedRows;
      _clearingCols = <int>{};
      _clearingCells = <Point<int>>{};
      _continueUsedThisRun = true;
      _isReviving = false;
      _isGameOver = false;
      _isBusy = false;
    });

    _triggerScreenPulse();
    _showFloatingMessage(
      'Continue!',
      color: const Color(0xFF00FF66),
    );
    _emitClearFeedback(
      clearedCount: max(1, revivedRows.length),
      streakCount: max(1, revivedRows.length),
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      return;
    }
    setState(() {
      _clearingRows = <int>{};
      _clearingCells = <Point<int>>{};
    });
    unawaited(_persistSavedRun());
  }

  Future<void> _persistBestScore(int score) async {
    _bestScore = score;
    final prefs = await _prefsFuture;
    await prefs.setInt(_bestScoreKey, score);
    if (mounted) {
      setState(() {});
    }
  }

  List<_LeaderboardEntry> _decodeLeaderboard(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <_LeaderboardEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_LeaderboardEntry>[];
      }
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) => _LeaderboardEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
      entries.sort(_sortLeaderboard);
      return entries.take(10).toList(growable: false);
    } catch (_) {
      return <_LeaderboardEntry>[];
    }
  }

  int _sortLeaderboard(_LeaderboardEntry a, _LeaderboardEntry b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return b.timestampMs.compareTo(a.timestampMs);
  }

  Future<void> _persistCurrentRunScore() async {
    if (_turn <= 0) {
      return;
    }

    final entry = _LeaderboardEntry(
      sessionId: _currentSessionId,
      score: _score,
      lines: _clearedLines,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    final nextEntries = List<_LeaderboardEntry>.from(_leaderboard)
      ..removeWhere((item) => item.sessionId == _currentSessionId)
      ..add(entry)
      ..sort(_sortLeaderboard);
    final trimmed = nextEntries.take(10).toList(growable: false);

    final prefs = await _prefsFuture;
    await prefs.setString(
      _leaderboardKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );

    if (mounted) {
      setState(() {
        _leaderboard = trimmed;
      });
    }
  }

  Map<String, dynamic> _tileToJson(_SoulTile tile) {
    return <String, dynamic>{
      'toneIndex': tile.toneIndex,
      'pieceId': tile.pieceId,
      'placedTurn': tile.placedTurn,
    };
  }

  _SoulTile? _tileFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return _SoulTile(
      toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
      pieceId: (json['pieceId'] as num?)?.toInt() ?? 0,
      placedTurn: (json['placedTurn'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _pieceToJson(_SoulPieceOption piece) {
    return <String, dynamic>{
      'id': piece.id,
      'templateId': piece.template.id,
      'toneIndex': piece.toneIndex,
      'isGold': piece.isGold,
      'isBomb': piece.isBomb,
    };
  }

  _SoulPieceOption? _pieceFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final String templateId = (json['templateId'] as String? ?? '').trim();
    final _SoulPieceTemplate? template =
        _kSoulBlockTemplates.cast<_SoulPieceTemplate?>().firstWhere(
              (_SoulPieceTemplate? item) => item?.id == templateId,
              orElse: () => null,
            );
    if (template == null) {
      return null;
    }
    return _SoulPieceOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      template: template,
      toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
      isGold: json['isGold'] == true,
      isBomb: json['isBomb'] == true,
    );
  }

  Future<void> _persistSavedRun() async {
    final SharedPreferences prefs = await _prefsFuture;
    if (_view != _SoulGameView.gameplay || _isGameOver) {
      await prefs.remove(_savedRunKey);
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'sessionId': _currentSessionId,
      'score': _score,
      'bestScore': _bestScore,
      'combo': _combo,
      'streak': _streak,
      'turn': _turn,
      'clearedLines': _clearedLines,
      'continueUsedThisRun': _continueUsedThisRun,
      'pieceSequence': _pieceSequence,
      'board': _board
          .map(
            (List<_SoulTile?> row) => row
                .map((tile) => tile == null ? null : _tileToJson(tile))
                .toList(growable: false),
          )
          .toList(growable: false),
      'tray': _tray.map(_pieceToJson).toList(growable: false),
      'holdPiece': _holdPiece == null ? null : _pieceToJson(_holdPiece!),
      'boardSize': _boardSize,
    };
    await prefs.setString(_savedRunKey, jsonEncode(payload));
  }

  Future<void> _clearSavedRun() async {
    final SharedPreferences prefs = await _prefsFuture;
    await prefs.remove(_savedRunKey);
  }

  _PreparedSoulRun? _decodeSavedRun(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      final int savedBoardSize = (json['boardSize'] as num?)?.toInt() ?? 8;
      final List<dynamic> boardRows = (json['board'] as List?) ?? <dynamic>[];
      if (boardRows.length != savedBoardSize) {
        return null;
      }
      final List<List<_SoulTile?>> board = boardRows.map((Object? row) {
        final List<dynamic> cells = row is List ? row : <dynamic>[];
        if (cells.length != savedBoardSize) {
          throw const FormatException('invalid board row');
        }
        return cells.map(_tileFromJson).toList(growable: false);
      }).toList(growable: false);
      final List<_SoulPieceOption> tray =
          ((json['tray'] as List?) ?? <dynamic>[])
              .map(_pieceFromJson)
              .whereType<_SoulPieceOption>()
              .toList(growable: false);
      final _RecommendedMove? recommendedMove = _recommendMoveFor(board, tray);
      if (tray.isEmpty || recommendedMove == null) {
        return null;
      }
      _pieceSequence = max(
        (json['pieceSequence'] as num?)?.toInt() ?? 0,
        tray.fold<int>(
            0, (int maxId, _SoulPieceOption piece) => max(maxId, piece.id)),
      );
      _score = (json['score'] as num?)?.toInt() ?? 0;
      _bestScore = max(_bestScore, (json['bestScore'] as num?)?.toInt() ?? 0);
      _combo = (json['combo'] as num?)?.toInt() ?? 0;
      _streak = (json['streak'] as num?)?.toInt() ?? 0;
      _turn = (json['turn'] as num?)?.toInt() ?? 0;
      _clearedLines = (json['clearedLines'] as num?)?.toInt() ?? 0;
      _continueUsedThisRun = json['continueUsedThisRun'] == true;
      final _SoulPieceOption? holdPiece =
          json['holdPiece'] == null ? null : _pieceFromJson(json['holdPiece']);
      return _PreparedSoulRun(
        board: board,
        tray: tray,
        recommendedMove: recommendedMove,
        sessionId: (json['sessionId'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch,
        holdPiece: holdPiece,
        boardSize: savedBoardSize,
      );
    } catch (_) {
      return null;
    }
  }
}
