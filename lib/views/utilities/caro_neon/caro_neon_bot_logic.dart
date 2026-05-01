part of '../caro_neon_screen.dart';

mixin _CaroNeonBotLogic {
  math.Random get _random;
  _BotStyle get _selectedBotStyle;

  double _botMistakeChance({
    required _BotStyle style,
    required int boardSize,
  });

  double _botAttackWeight(_BotStyle style);

  double _botDefenseWeight(_BotStyle style);

  double _botCenterWeight(_BotStyle style);

  math.Point<int> _chooseBotMove({
    required Map<String, String> board,
    required int boardSize,
    required int winLength,
  }) {
    if (board.isEmpty) {
      return _chooseBotOpeningMove(boardSize: boardSize);
    }

    if (boardSize == 3 && winLength == 3) {
      return _chooseFlexible3x3Move(board: board, boardSize: boardSize);
    }

    final immediateWin = _findCriticalMove(
      board: board,
      boardSize: boardSize,
      winLength: winLength,
      symbol: 'O',
    );
    if (immediateWin != null) return immediateWin;

    final immediateBlock = _findCriticalMove(
      board: board,
      boardSize: boardSize,
      winLength: winLength,
      symbol: 'X',
    );
    if (immediateBlock != null) return immediateBlock;

    final candidates = _candidateMoves(board: board, boardSize: boardSize);
    final rankedMoves = <MapEntry<math.Point<int>, int>>[];
    for (final move in candidates) {
      final score = _scoreBotMove(
        board: board,
        row: move.x,
        col: move.y,
        boardSize: boardSize,
        winLength: winLength,
      );
      rankedMoves.add(MapEntry<math.Point<int>, int>(move, score));
    }
    rankedMoves.sort((a, b) => b.value.compareTo(a.value));

    return _pickRankedBotMove(
      rankedMoves: rankedMoves,
      boardSize: boardSize,
    );
  }

  math.Point<int> _chooseBotOpeningMove({
    required int boardSize,
  }) {
    final center = boardSize ~/ 2;
    if (boardSize == 3) {
      final commonOpenings = <math.Point<int>>[
        math.Point<int>(center, center),
        const math.Point<int>(0, 0),
        const math.Point<int>(0, 2),
        const math.Point<int>(2, 0),
        const math.Point<int>(2, 2),
        const math.Point<int>(0, 1),
        const math.Point<int>(1, 0),
        const math.Point<int>(1, 2),
        const math.Point<int>(2, 1),
      ];
      if (_selectedBotStyle == _BotStyle.tricky ||
          _random.nextDouble() > 0.12) {
        return commonOpenings.first;
      }
      if (_selectedBotStyle == _BotStyle.gentle && _random.nextDouble() < 0.4) {
        return commonOpenings[5 + _random.nextInt(4)];
      }
      return commonOpenings[1 + _random.nextInt(commonOpenings.length - 1)];
    }

    final openings = <math.Point<int>>[
      math.Point<int>(center, center),
      math.Point<int>(center - 1, center),
      math.Point<int>(center, center - 1),
      math.Point<int>(center - 1, center - 1),
      math.Point<int>(center + 1, center),
      math.Point<int>(center, center + 1),
    ].where((point) {
      return point.x >= 0 &&
          point.y >= 0 &&
          point.x < boardSize &&
          point.y < boardSize;
    }).toList();

    if (_selectedBotStyle == _BotStyle.tricky || _random.nextDouble() > 0.1) {
      return openings.first;
    }
    return openings[_random.nextInt(openings.length)];
  }

  math.Point<int> _chooseFlexible3x3Move({
    required Map<String, String> board,
    required int boardSize,
  }) {
    final rankedMoves = <MapEntry<math.Point<int>, int>>[];
    for (final move in _allEmptyMoves(board: board, boardSize: boardSize)) {
      final next = Map<String, String>.from(board)
        ..['${move.x}:${move.y}'] = 'O';
      final score = _minimax(
        board: next,
        boardSize: boardSize,
        currentSymbol: 'X',
        depth: 0,
      );
      rankedMoves.add(MapEntry<math.Point<int>, int>(move, score));
    }
    rankedMoves.sort((a, b) => b.value.compareTo(a.value));
    return _pickRankedBotMove(
      rankedMoves: rankedMoves,
      boardSize: boardSize,
    );
  }

  math.Point<int> _pickRankedBotMove({
    required List<MapEntry<math.Point<int>, int>> rankedMoves,
    required int boardSize,
  }) {
    if (rankedMoves.isEmpty) {
      return const math.Point<int>(0, 0);
    }

    final bestScore = rankedMoves.first.value;
    final bestMoves =
        rankedMoves.where((entry) => entry.value == bestScore).toList();
    final mistakeChance = _botMistakeChance(
      style: _selectedBotStyle,
      boardSize: boardSize,
    );

    if (rankedMoves.length == 1 || _random.nextDouble() >= mistakeChance) {
      return bestMoves[_random.nextInt(bestMoves.length)].key;
    }

    final offset = bestMoves.length;
    if (offset >= rankedMoves.length) {
      return bestMoves[_random.nextInt(bestMoves.length)].key;
    }

    final fallbackPoolSize = boardSize == 3
        ? (_selectedBotStyle == _BotStyle.gentle ? 3 : 2)
        : (_selectedBotStyle == _BotStyle.gentle ? 4 : 3);
    final fallbackPool = rankedMoves
        .skip(offset)
        .take(fallbackPoolSize)
        .map((entry) => entry.key)
        .toList();
    if (fallbackPool.isEmpty) {
      return bestMoves[_random.nextInt(bestMoves.length)].key;
    }
    return fallbackPool[_random.nextInt(fallbackPool.length)];
  }

  int _minimax({
    required Map<String, String> board,
    required int boardSize,
    required String currentSymbol,
    required int depth,
  }) {
    final winner = _winnerSymbolForBoard(
      board: board,
      boardSize: boardSize,
      winLength: 3,
    );
    if (winner == 'O') return 10 - depth;
    if (winner == 'X') return depth - 10;
    if (board.length >= boardSize * boardSize) return 0;

    if (currentSymbol == 'O') {
      var bestScore = -1 << 30;
      for (final move in _allEmptyMoves(board: board, boardSize: boardSize)) {
        final next = Map<String, String>.from(board)
          ..['${move.x}:${move.y}'] = 'O';
        bestScore = math.max(
          bestScore,
          _minimax(
            board: next,
            boardSize: boardSize,
            currentSymbol: 'X',
            depth: depth + 1,
          ),
        );
      }
      return bestScore;
    }

    var bestScore = 1 << 30;
    for (final move in _allEmptyMoves(board: board, boardSize: boardSize)) {
      final next = Map<String, String>.from(board)
        ..['${move.x}:${move.y}'] = 'X';
      bestScore = math.min(
        bestScore,
        _minimax(
          board: next,
          boardSize: boardSize,
          currentSymbol: 'O',
          depth: depth + 1,
        ),
      );
    }
    return bestScore;
  }

  math.Point<int>? _findCriticalMove({
    required Map<String, String> board,
    required int boardSize,
    required int winLength,
    required String symbol,
  }) {
    for (final move in _candidateMoves(board: board, boardSize: boardSize)) {
      final next = Map<String, String>.from(board)
        ..['${move.x}:${move.y}'] = symbol;
      final winningCells = _findWinningCellsLocal(
        board: next,
        row: move.x,
        col: move.y,
        symbol: symbol,
        boardSize: boardSize,
        winLength: winLength,
      );
      if (winningCells.isNotEmpty) return move;
    }
    return null;
  }

  List<math.Point<int>> _candidateMoves({
    required Map<String, String> board,
    required int boardSize,
  }) {
    final candidates = <String>{};
    if (board.isEmpty) {
      final center = boardSize ~/ 2;
      return <math.Point<int>>[math.Point<int>(center, center)];
    }

    for (final key in board.keys) {
      final cell = _parseCellKey(key);
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          final row = cell.x + dr;
          final col = cell.y + dc;
          if (row < 0 || col < 0 || row >= boardSize || col >= boardSize) {
            continue;
          }
          final nextKey = '$row:$col';
          if (!board.containsKey(nextKey)) {
            candidates.add(nextKey);
          }
        }
      }
    }

    if (candidates.isEmpty) {
      return _allEmptyMoves(board: board, boardSize: boardSize);
    }

    final moves = candidates.map(_parseCellKey).toList()
      ..sort((a, b) {
        final center = boardSize / 2;
        final distA = (a.x - center).abs() + (a.y - center).abs();
        final distB = (b.x - center).abs() + (b.y - center).abs();
        return distA.compareTo(distB);
      });
    return moves;
  }

  List<math.Point<int>> _allEmptyMoves({
    required Map<String, String> board,
    required int boardSize,
  }) {
    final moves = <math.Point<int>>[];
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        if (!board.containsKey('$row:$col')) {
          moves.add(math.Point<int>(row, col));
        }
      }
    }
    return moves;
  }

  // ignore: unused_element
  math.Point<int> _firstEmptyCell({
    required int boardSize,
    required Map<String, String> board,
  }) {
    final all = _allEmptyMoves(board: board, boardSize: boardSize);
    return all.isEmpty ? const math.Point<int>(0, 0) : all.first;
  }

  int _scoreBotMove({
    required Map<String, String> board,
    required int row,
    required int col,
    required int boardSize,
    required int winLength,
  }) {
    var attackScore = 0;
    var defenseScore = 0;
    const directions = <List<int>>[
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];
    for (final direction in directions) {
      attackScore += _scoreDirection(
        board: board,
        row: row,
        col: col,
        symbol: 'O',
        enemySymbol: 'X',
        boardSize: boardSize,
        winLength: winLength,
        dr: direction[0],
        dc: direction[1],
      );
      defenseScore += _scoreDirection(
        board: board,
        row: row,
        col: col,
        symbol: 'X',
        enemySymbol: 'O',
        boardSize: boardSize,
        winLength: winLength,
        dr: direction[0],
        dc: direction[1],
      );
    }

    final weightedAttack =
        (attackScore * _botAttackWeight(_selectedBotStyle)).round();
    final weightedDefense =
        (defenseScore * _botDefenseWeight(_selectedBotStyle)).round();
    final center = boardSize / 2;
    final centerBias = ((boardSize * 10) -
            (((row - center).abs() + (col - center).abs()) * 8)) *
        _botCenterWeight(_selectedBotStyle);
    return weightedAttack + weightedDefense + centerBias.round();
  }

  int _scoreDirection({
    required Map<String, String> board,
    required int row,
    required int col,
    required String symbol,
    required String enemySymbol,
    required int boardSize,
    required int winLength,
    required int dr,
    required int dc,
  }) {
    final forward = _countLine(
      board: board,
      row: row,
      col: col,
      dr: dr,
      dc: dc,
      symbol: symbol,
      boardSize: boardSize,
    );
    final backward = _countLine(
      board: board,
      row: row,
      col: col,
      dr: -dr,
      dc: -dc,
      symbol: symbol,
      boardSize: boardSize,
    );
    final enemyForward = _countBlockedByEnemy(
      board: board,
      row: row,
      col: col,
      dr: dr,
      dc: dc,
      enemySymbol: enemySymbol,
      boardSize: boardSize,
    );
    final enemyBackward = _countBlockedByEnemy(
      board: board,
      row: row,
      col: col,
      dr: -dr,
      dc: -dc,
      enemySymbol: enemySymbol,
      boardSize: boardSize,
    );

    final streak = 1 + forward.x + backward.x;
    final openEnds = forward.y + backward.y;
    final enemyPressure = enemyForward + enemyBackward;

    if (streak >= winLength) return 900000;
    if (streak == winLength - 1 && openEnds > 0) return 160000;
    if (streak == winLength - 2 && openEnds == 2) return 36000;
    if (streak == winLength - 2 && openEnds == 1) return 12000;
    if (streak == 2 && openEnds == 2) return 3200 + (enemyPressure * 80);
    return (streak * streak * 180) + (openEnds * 120) + (enemyPressure * 40);
  }

  math.Point<int> _countLine({
    required Map<String, String> board,
    required int row,
    required int col,
    required int dr,
    required int dc,
    required String symbol,
    required int boardSize,
  }) {
    var count = 0;
    var nextRow = row + dr;
    var nextCol = col + dc;
    while (nextRow >= 0 &&
        nextCol >= 0 &&
        nextRow < boardSize &&
        nextCol < boardSize &&
        board['$nextRow:$nextCol'] == symbol) {
      count++;
      nextRow += dr;
      nextCol += dc;
    }
    final isOpen = nextRow >= 0 &&
        nextCol >= 0 &&
        nextRow < boardSize &&
        nextCol < boardSize &&
        !board.containsKey('$nextRow:$nextCol');
    return math.Point<int>(count, isOpen ? 1 : 0);
  }

  int _countBlockedByEnemy({
    required Map<String, String> board,
    required int row,
    required int col,
    required int dr,
    required int dc,
    required String enemySymbol,
    required int boardSize,
  }) {
    var nextRow = row + dr;
    var nextCol = col + dc;
    var count = 0;
    while (nextRow >= 0 &&
        nextCol >= 0 &&
        nextRow < boardSize &&
        nextCol < boardSize &&
        board['$nextRow:$nextCol'] == enemySymbol) {
      count++;
      nextRow += dr;
      nextCol += dc;
    }
    return count;
  }

  String _winnerSymbolForBoard({
    required Map<String, String> board,
    required int boardSize,
    required int winLength,
  }) {
    for (final entry in board.entries) {
      final cell = _parseCellKey(entry.key);
      final winningCells = _findWinningCellsLocal(
        board: board,
        row: cell.x,
        col: cell.y,
        symbol: entry.value,
        boardSize: boardSize,
        winLength: winLength,
      );
      if (winningCells.isNotEmpty) return entry.value;
    }
    return '';
  }

  math.Point<int> _parseCellKey(String key) {
    final parts = key.split(':');
    final row = int.tryParse(parts.first) ?? 0;
    final col = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return math.Point<int>(row, col);
  }

  List<String> _findWinningCellsLocal({
    required Map<String, String> board,
    required int row,
    required int col,
    required String symbol,
    required int boardSize,
    required int winLength,
  }) {
    const directions = <List<int>>[
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];

    for (final direction in directions) {
      final cells = <List<int>>[
        [row, col],
      ];

      void collect(int dr, int dc) {
        var nextRow = row + dr;
        var nextCol = col + dc;
        while (nextRow >= 0 &&
            nextCol >= 0 &&
            nextRow < boardSize &&
            nextCol < boardSize &&
            board['$nextRow:$nextCol'] == symbol) {
          cells.add([nextRow, nextCol]);
          nextRow += dr;
          nextCol += dc;
        }
      }

      collect(direction[0], direction[1]);
      collect(-direction[0], -direction[1]);

      if (cells.length >= winLength) {
        final ordered = _orderLineLocal(
          cells: cells,
          dx: direction[0],
          dy: direction[1],
        );
        final centerKey = '$row:$col';
        for (var start = 0; start <= ordered.length - winLength; start++) {
          final segment = ordered.sublist(start, start + winLength);
          final keys = segment.map((cell) => '${cell[0]}:${cell[1]}').toList();
          if (keys.contains(centerKey)) return keys;
        }
      }
    }

    return const <String>[];
  }

  List<List<int>> _orderLineLocal({
    required List<List<int>> cells,
    required int dx,
    required int dy,
  }) {
    final ordered = List<List<int>>.from(cells);
    ordered.sort((a, b) {
      final aProjection = a[0] * dx + a[1] * dy;
      final bProjection = b[0] * dx + b[1] * dy;
      return aProjection.compareTo(bProjection);
    });
    return ordered;
  }
}
