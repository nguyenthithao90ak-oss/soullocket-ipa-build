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
    final double clearProgress =
        (_clearedLines / 28).clamp(0.0, 1.0).toDouble();
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

  double _templateBatchWeight(
    _SoulPieceTemplate template,
    double progress,
  ) {
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
    final edgePressure =
        (_countNearCompleteLines(boardMask) / 8).clamp(0.0, 1.0);
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
    return combo
        .any((template) => template.tier == 0 && template.cellCount <= 4);
  }

  bool _hasRecoveryPiece(List<_SoulPieceTemplate> combo) {
    return combo.any((template) =>
        template.cellCount <= 3 || template.width == 1 || template.height == 1);
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
        .where((item) =>
            item.template.cellCount <= 3 ||
            item.template.width == 1 ||
            item.template.height == 1)
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
        combo.fold<double>(0, (sum, item) => sum + item.tier) / combo.length;
    final avgCells =
        combo.fold<double>(0, (sum, item) => sum + item.cellCount) /
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

  List<_SoulPieceTemplate> _pickBatchWinnerPool(
    List<_BatchChoice> rankedBatches,
    double progress,
  ) {
    final int winnerCount = progress < 0.28
        ? min(6, rankedBatches.length)
        : progress < 0.62
            ? min(5, rankedBatches.length)
            : min(4, rankedBatches.length);
    final candidates = rankedBatches
        .take(max(1, winnerCount))
        .map((choice) => choice.templates)
        .toList(growable: false);
    final sampled = _weightedTemplateSample(
      candidates.map((templates) => templates.first).toList(growable: false),
      1,
      progress,
    );
    final sampledFirst = sampled.first;
    return candidates.firstWhere(
      (templates) => identical(templates.first, sampledFirst),
      orElse: () => candidates[_random.nextInt(candidates.length)],
    );
  }

  List<_SoulPieceOption> _buildSmartBatch(List<List<_SoulTile?>> boardTiles) {
    final boardMask = _boardMask(boardTiles);
    final fittingCandidates = <_TemplateScore>[];
    for (final template in _kSoulBlockTemplates) {
      final placements = _findPlacements(boardMask, template);
      if (placements.isEmpty) {
        continue;
      }
      final _PlacementEval bestPlacement = _bestPlacement(placements);
      fittingCandidates.add(
        _TemplateScore(
          template: template,
          bestHeuristic: bestPlacement.heuristic,
          playableCount: placements.length,
        ),
      );
    }

    if (fittingCandidates.isEmpty) {
      return const <_SoulPieceOption>[];
    }

    fittingCandidates.sort((a, b) {
      final heuristicCompare = b.bestHeuristic.compareTo(a.bestHeuristic);
      if (heuristicCompare != 0) {
        return heuristicCompare;
      }
      return b.playableCount.compareTo(a.playableCount);
    });

    final double progress = _batchDifficultyProgress;
    final double boardStress = _boardStressLevel(boardMask);
    final pool = <_SoulPieceTemplate>[];
    final pooledTemplateIds = <String>{};
    final int rankedTake = progress < 0.30
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
    final List<_SoulPieceTemplate> easierTemplates = fittingCandidates
        .where((element) => element.template.tier == 0)
        .map((element) => element.template)
        .toList(growable: false);
    final List<_SoulPieceTemplate> diverseTemplates = fittingCandidates
        .where((element) => element.template.tier <= 1)
        .map((element) => element.template)
        .toList(growable: false);
    final supplementalTemplates = progress < 0.32 || boardStress >= 0.58
        ? _weightedTemplateSample(easierTemplates, 3, progress)
        : _weightedTemplateSample(diverseTemplates, 3, progress);
    for (final template in supplementalTemplates) {
      if (pool.length >= 9) {
        break;
      }
      if (pooledTemplateIds.add(template.id)) {
        pool.add(template);
      }
    }
    if (pool.length < 6) {
      for (final candidate in fittingCandidates) {
        if (pool.length >= 6) {
          break;
        }
        if (pooledTemplateIds.add(candidate.template.id)) {
          pool.add(candidate.template);
        }
      }
    }

    final bool forceEasyAnchor = (progress < 0.24 || boardStress >= 0.65) &&
        fittingCandidates.any((candidate) => candidate.template.tier == 0);

    final allCombos = _pickTemplateCombos(pool, 3);
    if (allCombos.isEmpty) {
      return fittingCandidates
          .take(3)
          .map((candidate) => _spawnPieceFromTemplate(candidate.template))
          .toList(growable: false);
    }

    final memo = <String, double>{};
    final rankedBatches = <_BatchChoice>[];
    for (final combo in allCombos) {
      if (forceEasyAnchor && !_hasEasyAnchor(combo)) {
        continue;
      }
      final uniqueTiers = combo.map((e) => e.tier).toSet().length;
      final uniqueIds = combo.map((e) => e.id).toSet().length;
      final double varietyBonus = (uniqueTiers * 5.0) + (uniqueIds * 3.0);
      final difficultyBias =
          _difficultyBiasForCombo(boardMask, combo, progress);

      final score = _evaluateBatchPlan(boardMask, combo, memo);
      if (score.isFinite) {
        rankedBatches.add(_BatchChoice(
          templates: combo,
          score: score + varietyBonus + difficultyBias,
        ));
      }
    }

    if (rankedBatches.isEmpty) {
      return fittingCandidates
          .take(3)
          .map((candidate) => _spawnPieceFromTemplate(candidate.template))
          .toList(growable: false);
    }

    rankedBatches.sort((a, b) => b.score.compareTo(a.score));
    late final List<_SoulPieceTemplate> chosenTemplates;
    if (rankedBatches.isEmpty) {
      chosenTemplates = fittingCandidates
          .take(3)
          .map((candidate) => candidate.template)
          .toList(growable: false);
    } else {
      chosenTemplates = _pickBatchWinnerPool(rankedBatches, progress);
    }

    return chosenTemplates.map(_spawnPieceFromTemplate).toList(growable: false);
  }

  List<_SoulPieceOption> _buildFastTray(List<List<_SoulTile?>> boardTiles) {
    final boardMask = _boardMask(boardTiles);
    final fittingTemplates = <_SoulPieceTemplate>[];
    for (final template in _kSoulBlockTemplates) {
      var canFit = false;
      for (var row = 0; row <= _strategyBoardSize - template.height; row++) {
        for (var col = 0; col <= _strategyBoardSize - template.width; col++) {
          if (_canPlace(boardMask, template, row, col)) {
            canFit = true;
            break;
          }
        }
        if (canFit) {
          break;
        }
      }
      if (canFit) {
        fittingTemplates.add(template);
      }
    }
    if (fittingTemplates.isEmpty) {
      return const <_SoulPieceOption>[];
    }

    fittingTemplates.shuffle(_random);
    final selected = <_SoulPieceTemplate>[];
    for (final tier in <int>[0, 1, 2]) {
      for (final template in fittingTemplates) {
        if (selected.length >= 3) {
          break;
        }
        if (template.tier == tier && !selected.contains(template)) {
          selected.add(template);
        }
      }
    }
    for (final template in fittingTemplates) {
      if (selected.length >= 3) {
        break;
      }
      if (!selected.contains(template)) {
        selected.add(template);
      }
    }
    return selected.map(_spawnPieceFromTemplate).toList(growable: false);
  }

  _SoulPieceOption _spawnPieceFromTemplate(_SoulPieceTemplate template) {
    _pieceSequence += 1;
    return _SoulPieceOption(
      id: _pieceSequence,
      template: template,
      toneIndex: _random.nextInt(_kSoulTones.length),
    );
  }

  _RecommendedMove? _recommendMoveFor(
    List<List<_SoulTile?>> boardTiles,
    List<_SoulPieceOption> tray,
  ) {
    final boardMask = _boardMask(boardTiles);
    _RecommendedMove? bestMove;
    for (final piece in tray) {
      final placements = _findPlacements(boardMask, piece.template);
      if (placements.isEmpty) {
        continue;
      }
      final bestPlacement = _bestPlacement(placements);
      final expectedGain =
          _scoreGainFor(piece.template, bestPlacement.clearedLines, _combo);
      if (bestMove == null || bestPlacement.heuristic > bestMove.heuristic) {
        bestMove = _RecommendedMove(
          pieceId: piece.id,
          row: bestPlacement.row,
          col: bestPlacement.col,
          heuristic: bestPlacement.heuristic,
          expectedGain: expectedGain,
          clearCount: bestPlacement.clearedLines,
        );
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
    _SoulPieceTemplate template,
  ) {
    final placements = <_PlacementEval>[];
    for (var row = 0; row <= _strategyBoardSize - template.height; row++) {
      for (var col = 0; col <= _strategyBoardSize - template.width; col++) {
        if (!_canPlace(boardMask, template, row, col)) {
          continue;
        }
        placements.add(_simulatePlacement(boardMask, template, row, col));
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
    int startCol,
  ) {
    final nextBoard = List<List<bool>>.generate(
      _strategyBoardSize,
      (row) => List<bool>.from(boardMask[row]),
    );

    for (final cell in template.cells) {
      nextBoard[startRow + cell.y][startCol + cell.x] = true;
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

    final heuristic = _basePiecePoints(template).toDouble() +
        (clearedLines * 145) +
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

  bool _hasAnyPlayableMove(
    List<List<_SoulTile?>> boardTiles,
    List<_SoulPieceOption> tray,
  ) {
    final boardMask = _boardMask(boardTiles);
    for (final piece in tray) {
      for (var row = 0;
          row <= _strategyBoardSize - piece.template.height;
          row++) {
        for (var col = 0;
            col <= _strategyBoardSize - piece.template.width;
            col++) {
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

  double _centerBias(
    _SoulPieceTemplate template,
    int startRow,
    int startCol,
  ) {
    final pieceCenterRow = startRow + ((template.height - 1) / 2);
    final pieceCenterCol = startCol + ((template.width - 1) / 2);
    final boardCenter = (_strategyBoardSize - 1) / 2;
    final distance = (pieceCenterRow - boardCenter).abs() +
        (pieceCenterCol - boardCenter).abs();
    return distance * 2.4;
  }

  List<List<_SoulPieceTemplate>> _pickTemplateCombos(
    List<_SoulPieceTemplate> pool,
    int size,
  ) {
    final combos = <List<_SoulPieceTemplate>>[];

    void visit(int index, List<_SoulPieceTemplate> current) {
      if (current.length == size) {
        combos.add(List<_SoulPieceTemplate>.from(current));
        return;
      }
      for (var i = index; i < pool.length; i++) {
        current.add(pool[i]);
        visit(i + 1, current);
        current.removeLast();
      }
    }

    visit(0, <_SoulPieceTemplate>[]);
    return combos;
  }

  double _evaluateBatchPlan(
    List<List<bool>> boardMask,
    List<_SoulPieceTemplate> templates,
    Map<String, double> memo,
  ) {
    if (templates.isEmpty) {
      return 0;
    }

    final pieceIds = templates.map((template) => template.id).toList()..sort();
    final key = '${_serializeBoard(boardMask)}|${pieceIds.join(",")}';
    final cached = memo[key];
    if (cached != null) {
      return cached;
    }

    var best = double.negativeInfinity;
    for (var i = 0; i < templates.length; i++) {
      final template = templates[i];
      final placements = _findPlacements(boardMask, template);
      if (placements.isEmpty) {
        continue;
      }
      for (final placement in _topPlacements(placements, 4)) {
        final remaining = List<_SoulPieceTemplate>.from(templates)..removeAt(i);
        final next = _evaluateBatchPlan(
          placement.boardAfter,
          remaining,
          memo,
        );
        if (!next.isFinite) {
          continue;
        }
        final batchBias = templates.length == 3
            ? (template.tier * 9) + (template.cellCount * 1.4)
            : 0;
        best = max(best, placement.heuristic + next + batchBias);
      }
    }

    memo[key] = best;
    return best;
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
