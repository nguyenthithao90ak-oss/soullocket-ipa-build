part of '../soul_block_game.dart';

mixin _SoulBlockStrategyLogic {
  Random get _random;
  int get _combo;
  int get _pieceSequence;
  set _pieceSequence(int value);
  int get _turn;
  int get _clearedLines;
  int get _strategyBoardSize;

  double get _batchDifficultyProgress {
    final double turnProgress = (_turn / 18).clamp(0.0, 1.0).toDouble();
    final double clearProgress = (_clearedLines / 28)
        .clamp(0.0, 1.0)
        .toDouble();
    return ((turnProgress * 0.55) + (clearProgress * 0.45))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _tierWeightForProgress(int tier, double progress) {
    switch (tier) {
      case 0:
        return 1.30 - (progress * 0.72);
      case 1:
        return 0.82 + (progress * 0.26);
      case 2:
        return 0.24 + (progress * 1.16);
      default:
        return 1.0;
    }
  }

  double _templateBatchWeight(_SoulPieceTemplate template, double progress) {
    final double tierWeight = _tierWeightForProgress(template.tier, progress);
    final double sizePenalty = template.cellCount >= 9
        ? (0.72 + (progress * 0.42))
        : template.cellCount >= 5
        ? (0.88 + (progress * 0.30))
        : 1.0;
    return max(0.12, tierWeight * sizePenalty);
  }

  double _boardStressLevel(List<List<bool>> boardMask) {
    final filledRatio =
        _filledCount(boardMask) / (_strategyBoardSize * _strategyBoardSize);
    final holesPressure = (_countHoles(boardMask) / 12).clamp(0.0, 1.0);
    final edgePressure = (_countNearCompleteLines(boardMask) / 8).clamp(
      0.0,
      1.0,
    );
    return ((filledRatio * 0.45) +
            (holesPressure * 0.30) +
            (edgePressure * 0.25))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int _countNearCompleteLines(List<List<bool>> boardMask) {
    var count = 0;
    for (var row = 0; row < _strategyBoardSize; row++) {
      var filled = 0;
      for (var col = 0; col < _strategyBoardSize; col++) {
        if (boardMask[row][col]) filled += 1;
      }
      if (filled >= _strategyBoardSize - 2) {
        count += 1;
      }
    }
    for (var col = 0; col < _strategyBoardSize; col++) {
      var filled = 0;
      for (var row = 0; row < _strategyBoardSize; row++) {
        if (boardMask[row][col]) filled += 1;
      }
      if (filled >= _strategyBoardSize - 2) {
        count += 1;
      }
    }
    return count;
  }

  bool _hasEasyAnchor(List<_SoulPieceTemplate> combo) {
    return combo.any(
      (template) => template.tier == 0 && template.cellCount <= 4,
    );
  }

  bool _hasRecoveryPiece(List<_SoulPieceTemplate> combo) {
    return combo.any(
      (template) =>
          template.cellCount <= 3 ||
          template.width == 1 ||
          template.height == 1,
    );
  }

  List<_SoulPieceTemplate> _stageBagTemplates(
    List<_TemplateScore> fittingCandidates,
    double progress,
    double boardStress,
  ) {
    final easy = fittingCandidates
        .where((item) => item.template.tier == 0)
        .map((item) => item.template)
        .toList(growable: false);
    final mid = fittingCandidates
        .where((item) => item.template.tier == 1)
        .map((item) => item.template)
        .toList(growable: false);
    final hard = fittingCandidates
        .where((item) => item.template.tier >= 2)
        .map((item) => item.template)
        .toList(growable: false);
    final rescue = fittingCandidates
        .where(
          (item) =>
              item.template.cellCount <= 3 ||
              item.template.width == 1 ||
              item.template.height == 1,
        )
        .map((item) => item.template)
        .toList(growable: false);

    final bag = <_SoulPieceTemplate>[];
    void addSample(List<_SoulPieceTemplate> source, int count) {
      for (final template in _weightedTemplateSample(source, count, progress)) {
        if (!bag.contains(template)) {
          bag.add(template);
        }
      }
    }

    if (progress < 0.28) {
      addSample(easy, 7);
      addSample(rescue, 3);
      addSample(mid, 2);
    } else if (progress < 0.62) {
      addSample(easy, boardStress >= 0.58 ? 5 : 3);
      addSample(mid, 5);
      addSample(rescue, 2);
      if (boardStress < 0.50) {
        addSample(hard, 2);
      }
    } else {
      addSample(rescue, boardStress >= 0.58 ? 4 : 2);
      addSample(easy, boardStress >= 0.58 ? 3 : 1);
      addSample(mid, 4);
      addSample(hard, boardStress >= 0.58 ? 1 : 4);
    }

    for (final candidate in fittingCandidates) {
      if (bag.length >= 10) {
        break;
      }
      if (!bag.contains(candidate.template)) {
        bag.add(candidate.template);
      }
    }
    return bag;
  }

  double _difficultyBiasForCombo(
    List<List<bool>> boardMask,
    List<_SoulPieceTemplate> combo,
    double progress,
  ) {
    final stress = _boardStressLevel(boardMask);
    final avgTier =
        combo.fold<double>(0, (total, item) => total + item.tier) /
        combo.length;
    final avgCells =
        combo.fold<double>(0, (total, item) => total + item.cellCount) /
        combo.length;
    final hasEasyAnchor = _hasEasyAnchor(combo);
    final hasRecoveryPiece = _hasRecoveryPiece(combo);

    double bias = 0;
    if (progress < 0.28) {
      bias += hasEasyAnchor ? 34 : -26;
      bias += avgTier <= 0.7 ? 16 : -18;
      bias += avgCells <= 4.5 ? 10 : -12;
    } else if (progress < 0.62) {
      bias += hasRecoveryPiece ? 12 : -8;
      bias += avgTier <= 1.2 ? 8 : -6;
    } else {
      bias += avgTier >= 1.0 ? 10 : 0;
      bias += avgCells >= 4.5 ? 8 : 0;
    }

    if (stress >= 0.62) {
      bias += hasRecoveryPiece ? 28 : -24;
      bias += hasEasyAnchor ? 12 : -10;
      bias += avgCells <= 4.8 ? 10 : -12;
    } else if (stress <= 0.28 && progress >= 0.55) {
      bias += avgTier >= 1.0 ? 10 : 0;
      bias += avgCells >= 4.8 ? 6 : 0;
    }

    return bias;
  }

  List<_SoulPieceTemplate> _weightedTemplateSample(
    List<_SoulPieceTemplate> templates,
    int count,
    double progress,
  ) {
    if (templates.length <= count) {
      return List<_SoulPieceTemplate>.from(templates);
    }

    final pool = List<_SoulPieceTemplate>.from(templates);
    final chosen = <_SoulPieceTemplate>[];
    while (pool.isNotEmpty && chosen.length < count) {
      double totalWeight = 0;
      for (final template in pool) {
        totalWeight += _templateBatchWeight(template, progress);
      }
      double pick = _random.nextDouble() * totalWeight;
      var chosenIndex = 0;
      for (var i = 0; i < pool.length; i++) {
        pick -= _templateBatchWeight(pool[i], progress);
        if (pick <= 0) {
          chosenIndex = i;
          break;
        }
      }
      chosen.add(pool.removeAt(chosenIndex));
    }
    return chosen;
  }

  List<_SoulPieceOption> _buildSmartBatch(List<List<_SoulTile?>> boardTiles) {
    final boardMask = _boardMask(boardTiles);
    // Mỗi trạng thái bàn + mẫu chỉ tính placements một lần trong lượt refill.
    // Beam search dùng lại cache này để tránh quét lặp khi ba mảnh có đường đi chung.
    final placementMemo = <String, List<_PlacementEval>>{};
    List<_PlacementEval> placementsFor(
      List<List<bool>> mask,
      _SoulPieceTemplate template, {
      bool bomb = false,
    }) {
      final key = '${_serializeBoard(mask)}|${template.id}|${bomb ? '1' : '0'}';
      final cached = placementMemo[key];
      if (cached != null) {
        return cached;
      }
      final placements = _findPlacements(mask, template, bomb: bomb);
      // Cache cục bộ, có trần để một bàn bất thường không giữ quá nhiều board copy.
      if (placementMemo.length < 128) {
        placementMemo[key] = placements;
      }
      return placements;
    }

    final fittingCandidates = <_TemplateScore>[];
    for (final template in _kSoulBlockTemplates) {
      if (template.id == 'single') {
        final stress = _boardStressLevel(boardMask);
        final allowSingle = stress >= 0.82 || _random.nextDouble() < 0.02;
        if (!allowSingle) {
          continue;
        }
      }
      final placements = placementsFor(boardMask, template);
      if (placements.isEmpty) {
        continue;
      }
      final bestPlacement = _bestPlacement(placements);
      fittingCandidates.add(
        _TemplateScore(
          template: template,
          bestHeuristic: bestPlacement.heuristic,
          playableCount: placements.length,
        ),
      );
    }

    if (fittingCandidates.isEmpty) {
      // Nếu bàn còn ô trống nhưng tất cả mẫu lớn đều bị kẹt, cho một mảnh
      // đơn kèm bomb để người chơi có cơ hội dọn vùng cuối thay vì deadlock giả.
      final single = _kSoulBlockTemplates.firstWhere(
        (template) => template.id == 'single',
      );
      if (placementsFor(boardMask, single).isEmpty) {
        return const <_SoulPieceOption>[];
      }
      return <_SoulPieceOption>[
        _spawnPieceFromTemplate(single, forceBomb: true),
      ];
    }

    fittingCandidates.sort((a, b) {
      final heuristicCompare = b.bestHeuristic.compareTo(a.bestHeuristic);
      if (heuristicCompare != 0) {
        return heuristicCompare;
      }
      return b.playableCount.compareTo(a.playableCount);
    });

    final progress = _batchDifficultyProgress;
    final boardStress = _boardStressLevel(boardMask);
    final pool = <_SoulPieceTemplate>[];
    final pooledTemplateIds = <String>{};
    final rankedTake = progress < 0.30
        ? 8
        : progress < 0.70
        ? 7
        : 6;
    for (final candidate in fittingCandidates.take(rankedTake)) {
      if (pooledTemplateIds.add(candidate.template.id)) {
        pool.add(candidate.template);
      }
    }
    for (final template in _stageBagTemplates(
      fittingCandidates,
      progress,
      boardStress,
    )) {
      if (pool.length >= 10) {
        break;
      }
      if (pooledTemplateIds.add(template.id)) {
        pool.add(template);
      }
    }
    final easierTemplates = fittingCandidates
        .where((item) => item.template.tier == 0)
        .map((item) => item.template)
        .toList(growable: false);
    final diverseTemplates = fittingCandidates
        .where((item) => item.template.tier <= 1)
        .map((item) => item.template)
        .toList(growable: false);
    final supplementalTemplates = progress < 0.32 || boardStress >= 0.58
        ? _weightedTemplateSample(easierTemplates, 3, progress)
        : _weightedTemplateSample(diverseTemplates, 3, progress);
    for (final template in supplementalTemplates) {
      if (pool.length >= 10) {
        break;
      }
      if (pooledTemplateIds.add(template.id)) {
        pool.add(template);
      }
    }
    for (final candidate in fittingCandidates) {
      if (pool.length >= 10) {
        break;
      }
      if (pooledTemplateIds.add(candidate.template.id)) {
        pool.add(candidate.template);
      }
    }

    // Giữ tối đa 10 mẫu để có đủ khối hồi phục nhưng vẫn giới hạn số nhánh.
    final shortlist = pool.take(10).toList(growable: false);
    final beamWidth = boardStress >= 0.62 ? 4 : 3;
    var beam =
        <
          ({
            List<List<bool>> board,
            List<_SoulPieceTemplate> templates,
            double score,
            int clearedLines,
          })
        >[
          (
            board: boardMask,
            templates: <_SoulPieceTemplate>[],
            score: 0,
            clearedLines: 0,
          ),
        ];

    for (var depth = 0; depth < 3; depth++) {
      final next =
          <
            ({
              List<List<bool>> board,
              List<_SoulPieceTemplate> templates,
              double score,
              int clearedLines,
            })
          >[];
      for (final plan in beam) {
        for (final template in shortlist) {
          final placements = placementsFor(plan.board, template);
          if (placements.isEmpty) {
            continue;
          }
          for (final placement in _topPlacements(placements, 2)) {
            final templates = <_SoulPieceTemplate>[...plan.templates, template];
            final repeated = plan.templates.any(
              (item) => item.id == template.id,
            );
            final mobility = _countPlayableTemplates(
              placement.boardAfter,
              shortlist,
            );
            final clearBonus =
                placement.clearedLines * (progress < 0.60 ? 76.0 : 54.0);
            final mobilityBonus = mobility * (depth == 2 ? 12.0 : 4.0);
            final deadlockPenalty = mobility == 0 ? 180.0 : 0.0;
            final bias = depth == 2
                ? _difficultyBiasForCombo(boardMask, templates, progress)
                : 0.0;
            next.add((
              board: placement.boardAfter,
              templates: templates,
              score:
                  plan.score +
                  placement.heuristic +
                  clearBonus +
                  mobilityBonus +
                  bias +
                  (repeated ? -18.0 : 9.0) -
                  deadlockPenalty,
              clearedLines: plan.clearedLines + placement.clearedLines,
            ));
          }
        }
      }
      if (next.isEmpty) {
        break;
      }
      next.sort((a, b) {
        final clearCompare = b.clearedLines.compareTo(a.clearedLines);
        if (depth == 2 &&
            clearCompare != 0 &&
            (progress < 0.60 || boardStress >= 0.48)) {
          return clearCompare;
        }
        return b.score.compareTo(a.score);
      });
      final signatures = <String>{};
      beam = next
          .where(
            (plan) => signatures.add(
              plan.templates.map((template) => template.id).join('|') +
                  _serializeBoard(plan.board),
            ),
          )
          .take(beamWidth)
          .toList(growable: false);
    }

    var completePlans = beam
        .where((plan) => plan.templates.length == 3)
        .toList(growable: false);

    if (completePlans.isEmpty) {
      // Beam có thể bỏ mất nhánh hợp lệ khi bàn chật. Greedy fallback quét
      // toàn bộ mẫu đang hợp lệ theo từng trạng thái, luôn giữ chuỗi khả thi.
      final sequencePool = <_SoulPieceTemplate>[...pool];
      for (final candidate in fittingCandidates) {
        if (!sequencePool.any((item) => item.id == candidate.template.id)) {
          sequencePool.add(candidate.template);
        }
      }
      final single = _kSoulBlockTemplates.firstWhere(
        (template) => template.id == 'single',
      );
      if (!sequencePool.any((item) => item.id == single.id)) {
        sequencePool.add(single);
      }
      var fallbackBoard = boardMask;
      var fallbackScore = 0.0;
      var fallbackClearedLines = 0;
      final fallbackTemplates = <_SoulPieceTemplate>[];
      for (var depth = 0; depth < 3; depth++) {
        final choices =
            <
              ({
                _SoulPieceTemplate template,
                _PlacementEval placement,
                double score,
              })
            >[];
        for (final template in sequencePool) {
          final placements = placementsFor(fallbackBoard, template);
          for (final placement in _topPlacements(placements, 3)) {
            final mobility = _countPlayableTemplates(
              placement.boardAfter,
              sequencePool,
            );
            choices.add((
              template: template,
              placement: placement,
              score:
                  placement.heuristic +
                  (placement.clearedLines * 92.0) +
                  (mobility * 10.0) -
                  (mobility == 0 ? 160.0 : 0.0),
            ));
          }
        }
        if (choices.isEmpty) {
          break;
        }
        choices.sort((a, b) => b.score.compareTo(a.score));
        final choice = choices.first;
        fallbackTemplates.add(choice.template);
        fallbackBoard = choice.placement.boardAfter;
        fallbackScore += choice.score;
        fallbackClearedLines += choice.placement.clearedLines;
      }
      completePlans =
          <
            ({
              List<List<bool>> board,
              List<_SoulPieceTemplate> templates,
              double score,
              int clearedLines,
            })
          >[];
      if (fallbackTemplates.isNotEmpty) {
        completePlans =
            <
              ({
                List<List<bool>> board,
                List<_SoulPieceTemplate> templates,
                double score,
                int clearedLines,
              })
            >[
              (
                board: fallbackBoard,
                templates: fallbackTemplates,
                score: fallbackScore,
                clearedLines: fallbackClearedLines,
              ),
            ];
      }
    }

    if (completePlans.isEmpty) {
      return fittingCandidates
          .take(3)
          .map((candidate) => _spawnPieceFromTemplate(candidate.template))
          .toList(growable: false);
    }
    final hasClearPlan = completePlans.any((plan) => plan.clearedLines > 0);
    completePlans.sort((a, b) {
      if (hasClearPlan) {
        final aHasClear = a.clearedLines > 0 ? 1 : 0;
        final bHasClear = b.clearedLines > 0 ? 1 : 0;
        if (aHasClear != bHasClear) {
          return bHasClear.compareTo(aHasClear);
        }
      }
      final clearCompare = b.clearedLines.compareTo(a.clearedLines);
      if (clearCompare != 0) {
        return clearCompare;
      }
      return b.score.compareTo(a.score);
    });
    final winnerCount = min(2, completePlans.length);
    final chosenPlan = completePlans[_random.nextInt(winnerCount)];
    final chosenTemplates = chosenPlan.templates;

    final shouldRescue = boardStress >= 0.65;
    var gaveBomb = false;
    return chosenTemplates
        .map((template) {
          var makeBomb = false;
          if (!gaveBomb && shouldRescue && _random.nextInt(100) < 85) {
            makeBomb = true;
            gaveBomb = true;
          }
          return _spawnPieceFromTemplate(template, forceBomb: makeBomb);
        })
        .toList(growable: false);
  }

  _SoulPieceOption _spawnPieceFromTemplate(
    _SoulPieceTemplate template, {
    bool forceBomb = false,
  }) {
    _pieceSequence += 1;
    final int roll = _random.nextInt(100);
    final bool isGold = !forceBomb && roll < 15; // 15% (buffed from 12)
    final bool isBomb =
        forceBomb || (!isGold && (roll >= 15 && roll < 25)); // 10% or forced
    return _SoulPieceOption(
      id: _pieceSequence,
      template: template,
      toneIndex: _random.nextInt(_kSoulTones.length),
      isGold: isGold,
      isBomb: isBomb,
    );
  }

  String? _moveCacheBoard;
  int? _moveCacheCombo;
  final Map<(int, String, int, bool, bool), _RecommendedMove?> _moveCache = {};

  _RecommendedMove? _recommendMoveFor(
    List<List<_SoulTile?>> boardTiles,
    List<_SoulPieceOption> tray,
  ) {
    final boardMask = _boardMask(boardTiles);
    final boardKey = _serializeBoard(boardMask);
    if (_moveCacheBoard != boardKey || _moveCacheCombo != _combo) {
      _moveCache.clear();
      _moveCacheBoard = boardKey;
      _moveCacheCombo = _combo;
    }
    if (_moveCache.length > 32) _moveCache.clear();
    _RecommendedMove? bestMove;
    for (final piece in tray) {
      final key = (
        piece.id,
        piece.template.id,
        piece.template.quarterTurns,
        piece.isGold,
        piece.isBomb,
      );
      if (!_moveCache.containsKey(key)) {
        final placements = _findPlacements(
          boardMask,
          piece.template,
          bomb: piece.isBomb,
        );
        if (placements.isEmpty) {
          _moveCache[key] = null;
        } else {
          final best = _bestPlacement(placements);
          _moveCache[key] = _RecommendedMove(
            pieceId: piece.id,
            row: best.row,
            col: best.col,
            heuristic: best.heuristic,
            expectedGain:
                _scoreGainFor(piece.template, best.clearedLines, _combo) *
                (piece.isGold ? 2 : 1),
            clearCount: best.clearedLines,
          );
        }
      }
      final move = _moveCache[key];
      if (move != null &&
          (bestMove == null || move.heuristic > bestMove.heuristic)) {
        bestMove = move;
      }
    }
    return bestMove;
  }

  List<List<bool>> _boardMask(List<List<_SoulTile?>> boardTiles) {
    return List<List<bool>>.generate(
      _strategyBoardSize,
      (row) => List<bool>.generate(
        _strategyBoardSize,
        (col) => boardTiles[row][col] != null,
      ),
    );
  }

  List<_PlacementEval> _findPlacements(
    List<List<bool>> boardMask,
    _SoulPieceTemplate template, {
    bool bomb = false,
  }) {
    final placements = <_PlacementEval>[];
    for (var row = 0; row <= _strategyBoardSize - template.height; row++) {
      for (var col = 0; col <= _strategyBoardSize - template.width; col++) {
        if (!_canPlace(boardMask, template, row, col)) {
          continue;
        }
        placements.add(
          _simulatePlacement(boardMask, template, row, col, bomb: bomb),
        );
      }
    }
    return placements;
  }

  _PlacementEval _bestPlacement(List<_PlacementEval> placements) {
    _PlacementEval best = placements.first;
    for (var i = 1; i < placements.length; i++) {
      final candidate = placements[i];
      if (candidate.heuristic > best.heuristic) {
        best = candidate;
      }
    }
    return best;
  }

  List<_PlacementEval> _topPlacements(
    List<_PlacementEval> placements,
    int limit,
  ) {
    if (placements.length <= limit) {
      final sorted = List<_PlacementEval>.from(placements);
      sorted.sort((a, b) => b.heuristic.compareTo(a.heuristic));
      return sorted;
    }

    final best = <_PlacementEval>[];
    for (final placement in placements) {
      var insertAt = best.length;
      for (var i = 0; i < best.length; i++) {
        if (placement.heuristic > best[i].heuristic) {
          insertAt = i;
          break;
        }
      }
      if (insertAt >= limit) {
        continue;
      }
      best.insert(insertAt, placement);
      if (best.length > limit) {
        best.removeLast();
      }
    }
    return best;
  }

  bool _canPlace(
    List<List<bool>> boardMask,
    _SoulPieceTemplate template,
    int startRow,
    int startCol,
  ) {
    for (final cell in template.cells) {
      final row = startRow + cell.y;
      final col = startCol + cell.x;
      if (row < 0 ||
          col < 0 ||
          row >= _strategyBoardSize ||
          col >= _strategyBoardSize) {
        return false;
      }
      if (boardMask[row][col]) {
        return false;
      }
    }
    return true;
  }

  Set<int> _occupiedRowsFor(_SoulPieceTemplate template, int startRow) {
    return template.cells.map((cell) => startRow + cell.y).toSet();
  }

  Set<int> _occupiedColsFor(_SoulPieceTemplate template, int startCol) {
    return template.cells.map((cell) => startCol + cell.x).toSet();
  }

  // ignore: unused_element
  _PlacementResolution _placeTemplate(
    List<List<_SoulTile?>> boardTiles,
    _SoulPieceOption piece,
    int startRow,
    int startCol,
  ) {
    final nextBoard = List<List<_SoulTile?>>.generate(
      _strategyBoardSize,
      (row) => List<_SoulTile?>.from(boardTiles[row]),
    );
    final occupiedCells = <Point<int>>[];
    for (final cell in piece.template.cells) {
      final row = startRow + cell.y;
      final col = startCol + cell.x;
      nextBoard[row][col] = _SoulTile(
        toneIndex: piece.toneIndex,
        pieceId: piece.id,
        placedTurn: 0,
      );
      occupiedCells.add(Point<int>(row, col));
    }
    return _PlacementResolution(
      board: nextBoard,
      occupiedCells: occupiedCells,
      rowsToClear: _occupiedRowsFor(piece.template, startRow),
      colsToClear: _occupiedColsFor(piece.template, startCol),
    );
  }

  // ignore: unused_element
  _LineClearResolution _clearAffectedLines(
    List<List<_SoulTile?>> boardTiles,
    Set<int> rowsToClear,
    Set<int> colsToClear,
  ) {
    final nextBoard = List<List<_SoulTile?>>.generate(
      _strategyBoardSize,
      (row) => List<_SoulTile?>.from(boardTiles[row]),
    );
    final clearedRows = <int>{};
    final clearedCols = <int>{};

    for (final row in rowsToClear) {
      final isFull = nextBoard[row].every((cell) => cell != null);
      if (!isFull) {
        continue;
      }
      clearedRows.add(row);
      for (var col = 0; col < _strategyBoardSize; col++) {
        nextBoard[row][col] = null;
      }
    }

    for (final col in colsToClear) {
      var isFull = true;
      for (var row = 0; row < _strategyBoardSize; row++) {
        if (nextBoard[row][col] == null) {
          isFull = false;
          break;
        }
      }
      if (!isFull) {
        continue;
      }
      clearedCols.add(col);
      for (var row = 0; row < _strategyBoardSize; row++) {
        nextBoard[row][col] = null;
      }
    }

    return _LineClearResolution(
      board: nextBoard,
      clearedRows: clearedRows,
      clearedCols: clearedCols,
    );
  }

  _PlacementEval _simulatePlacement(
    List<List<bool>> boardMask,
    _SoulPieceTemplate template,
    int startRow,
    int startCol, {
    bool bomb = false,
  }) {
    final nextBoard = List<List<bool>>.generate(
      _strategyBoardSize,
      (row) => List<bool>.from(boardMask[row]),
    );

    for (final cell in template.cells) {
      nextBoard[startRow + cell.y][startCol + cell.x] = true;
    }

    var bombCells = 0;
    if (bomb) {
      final centerRow = startRow + template.height ~/ 2;
      final centerCol = startCol + template.width ~/ 2;
      for (
        var row = max(0, centerRow - 1);
        row <= min(_strategyBoardSize - 1, centerRow + 1);
        row++
      ) {
        for (
          var col = max(0, centerCol - 1);
          col <= min(_strategyBoardSize - 1, centerCol + 1);
          col++
        ) {
          if (nextBoard[row][col]) bombCells++;
          nextBoard[row][col] = false;
        }
      }
    }
    final clearedRows = <int>[];
    final clearedCols = <int>[];

    for (final row in _occupiedRowsFor(template, startRow)) {
      if (nextBoard[row].every((value) => value)) {
        clearedRows.add(row);
      }
    }

    for (final col in _occupiedColsFor(template, startCol)) {
      var full = true;
      for (var row = 0; row < _strategyBoardSize; row++) {
        if (!nextBoard[row][col]) {
          full = false;
          break;
        }
      }
      if (full) {
        clearedCols.add(col);
      }
    }

    for (final row in clearedRows) {
      for (var col = 0; col < _strategyBoardSize; col++) {
        nextBoard[row][col] = false;
      }
    }
    for (final col in clearedCols) {
      for (var row = 0; row < _strategyBoardSize; row++) {
        nextBoard[row][col] = false;
      }
    }

    final clearedLines = clearedRows.length + clearedCols.length;
    final nearLinePressure = _countNearLines(nextBoard);
    final tightHoles = _countTightHoles(nextBoard);
    final adjacency = _countAdjacency(nextBoard);
    final occupancy =
        _filledCount(nextBoard) / (_strategyBoardSize * _strategyBoardSize);
    final centerBias = _centerBias(template, startRow, startCol);

    final heuristic =
        _basePiecePoints(template).toDouble() +
        (clearedLines * 145) +
        (bombCells * 18) +
        (nearLinePressure * 16) +
        (adjacency * 1.6) -
        (tightHoles * 18) -
        (occupancy > 0.74 ? occupancy * 72 : occupancy * 28) -
        centerBias;

    return _PlacementEval(
      row: startRow,
      col: startCol,
      clearedLines: clearedLines,
      heuristic: heuristic,
      boardAfter: nextBoard,
    );
  }

  int _countPlayableTemplates(
    List<List<bool>> boardMask,
    Iterable<_SoulPieceTemplate> templates,
  ) {
    var playable = 0;
    for (final template in templates) {
      var hasPlacement = false;
      for (
        var row = 0;
        row <= _strategyBoardSize - template.height && !hasPlacement;
        row++
      ) {
        for (var col = 0; col <= _strategyBoardSize - template.width; col++) {
          if (_canPlace(boardMask, template, row, col)) {
            hasPlacement = true;
            break;
          }
        }
      }
      if (hasPlacement) {
        playable += 1;
      }
    }
    return playable;
  }

  // ignore: unused_element
  bool _hasAnyPlayableMove(
    List<List<_SoulTile?>> boardTiles,
    List<_SoulPieceOption> tray,
  ) {
    final boardMask = _boardMask(boardTiles);
    for (final piece in tray) {
      for (
        var row = 0;
        row <= _strategyBoardSize - piece.template.height;
        row++
      ) {
        for (
          var col = 0;
          col <= _strategyBoardSize - piece.template.width;
          col++
        ) {
          if (_canPlace(boardMask, piece.template, row, col)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  int _countNearLines(List<List<bool>> boardMask) {
    var score = 0;
    for (var row = 0; row < _strategyBoardSize; row++) {
      final gaps = boardMask[row].where((filled) => !filled).length;
      if (gaps == 1) {
        score += 3;
      } else if (gaps == 2) {
        score += 1;
      }
    }
    for (var col = 0; col < _strategyBoardSize; col++) {
      var gaps = 0;
      for (var row = 0; row < _strategyBoardSize; row++) {
        if (!boardMask[row][col]) {
          gaps += 1;
        }
      }
      if (gaps == 1) {
        score += 3;
      } else if (gaps == 2) {
        score += 1;
      }
    }
    return score;
  }

  int _countHoles(List<List<bool>> boardMask) {
    return _countTightHoles(boardMask);
  }

  int _countTightHoles(List<List<bool>> boardMask) {
    var holes = 0;
    for (var row = 0; row < _strategyBoardSize; row++) {
      for (var col = 0; col < _strategyBoardSize; col++) {
        if (boardMask[row][col]) {
          continue;
        }
        var neighbors = 0;
        if (row > 0 && boardMask[row - 1][col]) {
          neighbors += 1;
        }
        if (row < _strategyBoardSize - 1 && boardMask[row + 1][col]) {
          neighbors += 1;
        }
        if (col > 0 && boardMask[row][col - 1]) {
          neighbors += 1;
        }
        if (col < _strategyBoardSize - 1 && boardMask[row][col + 1]) {
          neighbors += 1;
        }
        if (neighbors >= 3) {
          holes += 1;
        }
      }
    }
    return holes;
  }

  int _countAdjacency(List<List<bool>> boardMask) {
    var adjacency = 0;
    for (var row = 0; row < _strategyBoardSize; row++) {
      for (var col = 0; col < _strategyBoardSize; col++) {
        if (!boardMask[row][col]) {
          continue;
        }
        if (row + 1 < _strategyBoardSize && boardMask[row + 1][col]) {
          adjacency += 1;
        }
        if (col + 1 < _strategyBoardSize && boardMask[row][col + 1]) {
          adjacency += 1;
        }
      }
    }
    return adjacency;
  }

  int _filledCount(List<List<bool>> boardMask) {
    var count = 0;
    for (final row in boardMask) {
      for (final filled in row) {
        if (filled) {
          count += 1;
        }
      }
    }
    return count;
  }

  double _centerBias(_SoulPieceTemplate template, int startRow, int startCol) {
    final pieceCenterRow = startRow + ((template.height - 1) / 2);
    final pieceCenterCol = startCol + ((template.width - 1) / 2);
    final boardCenter = (_strategyBoardSize - 1) / 2;
    final distance =
        (pieceCenterRow - boardCenter).abs() +
        (pieceCenterCol - boardCenter).abs();
    return distance * 2.4;
  }

  String _serializeBoard(List<List<bool>> boardMask) {
    final buffer = StringBuffer();
    for (final row in boardMask) {
      for (final filled in row) {
        buffer.write(filled ? '1' : '0');
      }
    }
    return buffer.toString();
  }

  int _scoreGainFor(
    _SoulPieceTemplate template,
    int clearedLines,
    int currentCombo,
  ) {
    final base = _basePiecePoints(template);
    if (clearedLines == 0) {
      return base;
    }
    final comboMult = 1.0 + (currentCombo * 0.25).clamp(0.0, 2.0);
    final lineBonus = clearedLines * _strategyBoardSize * 10;
    return base + (lineBonus * comboMult).round();
  }

  int _basePiecePoints(_SoulPieceTemplate template) {
    return template.cellCount * 5 + template.tier * 8;
  }
}
