import 'package:firebase_database/firebase_database.dart';

class CaroGameService {
  CaroGameService._();

  static final CaroGameService instance = CaroGameService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference _roomRef(String houseId) =>
      _db.ref('houses/${houseId.trim()}/game_caro');

  Stream<CaroRoom?> streamRoom(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<CaroRoom?>.value(null);
    return _roomRef(normalizedHouseId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      final data = _asMap(event.snapshot.value);
      if (data == null) return null;
      return CaroRoom.fromMap(data);
    });
  }

  Future<void> inviteMatch({
    required String houseId,
    required String myRole,
    required String myName,
    required String partnerName,
    required int boardSize,
    required int winLength,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = _normalizeRole(myRole);
    if (normalizedHouseId.isEmpty || normalizedRole == null) return;
    final otherRole = normalizedRole == 'user2' ? 'user1' : 'user2';
    final effectiveBoardSize = boardSize.clamp(3, 19);
    final effectiveWinLength = winLength.clamp(3, effectiveBoardSize);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _roomRef(normalizedHouseId).set({
      'status': 'waiting',
      'boardSize': effectiveBoardSize,
      'winLength': effectiveWinLength,
      'board': <String, String>{},
      'turnRole': normalizedRole,
      'playerXRole': normalizedRole,
      'playerORole': otherRole,
      'createdByRole': normalizedRole,
      'creatorName': myName.trim(),
      'guestName': partnerName.trim(),
      'winnerRole': '',
      'winnerSymbol': '',
      'winningCells': <String>[],
      'isDraw': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<bool> joinMatch({
    required String houseId,
    required String myRole,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = _normalizeRole(myRole);
    if (normalizedHouseId.isEmpty || normalizedRole == null) return false;
    final tx =
        await _roomRef(normalizedHouseId).runTransaction((Object? current) {
      final data = _asMap(current);
      if (data == null) return Transaction.abort();
      if ((data['status']?.toString() ?? '') != 'waiting') {
        return Transaction.abort();
      }

      final playerXRole = data['playerXRole']?.toString() ?? 'user1';
      final playerORole = data['playerORole']?.toString() ?? 'user2';
      if (normalizedRole != playerXRole && normalizedRole != playerORole) {
        return Transaction.abort();
      }

      data['status'] = 'active';
      data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      return Transaction.success(data);
    });

    return tx.committed;
  }

  Future<CaroMoveResult> playMove({
    required String houseId,
    required String myRole,
    required int row,
    required int col,
  }) async {
    String message = '';

    final normalizedHouseId = houseId.trim();
    final normalizedRole = _normalizeRole(myRole);
    if (normalizedHouseId.isEmpty || normalizedRole == null) {
      return const CaroMoveResult(
        committed: false,
        message: 'Nước đi không hợp lệ.',
      );
    }

    final tx =
        await _roomRef(normalizedHouseId).runTransaction((Object? current) {
      final data = _asMap(current);
      if (data == null) {
        message = 'Ván chơi không tồn tại.';
        return Transaction.abort();
      }
      if ((data['status']?.toString() ?? '') != 'active') {
        message = 'Ván chơi chưa sẵn sàng.';
        return Transaction.abort();
      }

      final currentTurn = data['turnRole']?.toString() ?? 'user1';
      if (currentTurn != normalizedRole) {
        message = 'Chưa tới lượt của bạn.';
        return Transaction.abort();
      }

      final boardSize = _toInt(data['boardSize'], fallback: 3);
      final winLength = _toInt(data['winLength'], fallback: 3);
      if (row < 0 || col < 0 || row >= boardSize || col >= boardSize) {
        message = 'Nước đi không hợp lệ.';
        return Transaction.abort();
      }

      final board = _asStringMap(data['board']) ?? <String, String>{};
      final cellKey = '$row:$col';
      if ((board[cellKey] ?? '').isNotEmpty) {
        message = 'Ô này đã được đánh.';
        return Transaction.abort();
      }

      final playerXRole = data['playerXRole']?.toString() ?? 'user1';
      final playerORole = data['playerORole']?.toString() ?? 'user2';
      final symbol = normalizedRole == playerXRole ? 'X' : 'O';
      board[cellKey] = symbol;

      final winningCells = _findWinningCells(
        board: board,
        row: row,
        col: col,
        symbol: symbol,
        boardSize: boardSize,
        winLength: winLength,
      );

      data['board'] = board;
      data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      if (winningCells.isNotEmpty) {
        data['status'] = 'done';
        data['winnerRole'] = normalizedRole;
        data['winnerSymbol'] = symbol;
        data['winningCells'] = winningCells;
        data['isDraw'] = false;
        return Transaction.success(data);
      }

      if (board.length >= boardSize * boardSize) {
        data['status'] = 'done';
        data['winnerRole'] = '';
        data['winnerSymbol'] = '';
        data['winningCells'] = <String>[];
        data['isDraw'] = true;
        return Transaction.success(data);
      }

      data['turnRole'] =
          normalizedRole == playerXRole ? playerORole : playerXRole;
      data['winnerRole'] = '';
      data['winnerSymbol'] = '';
      data['winningCells'] = <String>[];
      data['isDraw'] = false;
      return Transaction.success(data);
    });

    return CaroMoveResult(
      committed: tx.committed,
      message: tx.committed ? '' : message,
    );
  }

  Future<void> clearRoom(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    await _roomRef(normalizedHouseId).remove();
  }

  List<String> _findWinningCells({
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
        cells.sort((a, b) {
          final primary = a[0].compareTo(b[0]);
          if (primary != 0) return primary;
          return a[1].compareTo(b[1]);
        });

        final ordered = _orderLine(
          cells: cells,
          dx: direction[0],
          dy: direction[1],
        );
        final centerKey = '$row:$col';
        for (var start = 0; start <= ordered.length - winLength; start++) {
          final segment = ordered.sublist(start, start + winLength);
          final segmentKeys = segment.map((cell) => '${cell[0]}:${cell[1]}');
          if (segmentKeys.contains(centerKey)) {
            return segmentKeys.toList();
          }
        }
      }
    }

    return const <String>[];
  }

  List<List<int>> _orderLine({
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

  int _toInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is! Map) return null;
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  Map<String, String>? _asStringMap(Object? value) {
    if (value is! Map) return null;
    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }

  String? _normalizeRole(String value) {
    final role = value.trim();
    if (role == 'user1' || role == 'user2') return role;
    return null;
  }
}

class CaroMoveResult {
  final bool committed;
  final String message;

  const CaroMoveResult({
    required this.committed,
    required this.message,
  });
}

class CaroRoom {
  final String status;
  final int boardSize;
  final int winLength;
  final String turnRole;
  final String playerXRole;
  final String playerORole;
  final String createdByRole;
  final String creatorName;
  final String guestName;
  final String winnerRole;
  final String winnerSymbol;
  final bool isDraw;
  final int updatedAt;
  final Map<String, String> board;
  final List<String> winningCells;

  const CaroRoom({
    required this.status,
    required this.boardSize,
    required this.winLength,
    required this.turnRole,
    required this.playerXRole,
    required this.playerORole,
    required this.createdByRole,
    required this.creatorName,
    required this.guestName,
    required this.winnerRole,
    required this.winnerSymbol,
    required this.isDraw,
    required this.updatedAt,
    required this.board,
    required this.winningCells,
  });

  bool get isWaiting => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isDone => status == 'done';

  String symbolForRole(String role) {
    if (role == playerXRole) return 'X';
    if (role == playerORole) return 'O';
    return '';
  }

  String? cellAt(int row, int col) {
    final value = board['$row:$col']?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  factory CaroRoom.fromMap(Map<String, dynamic> map) {
    final board = <String, String>{};
    final rawBoard = map['board'];
    if (rawBoard is Map) {
      rawBoard.forEach((key, value) {
        final text = value?.toString() ?? '';
        if (text.isNotEmpty) {
          board[key.toString()] = text;
        }
      });
    }

    final winningCells = <String>[];
    final rawWinning = map['winningCells'];
    if (rawWinning is List) {
      for (final value in rawWinning) {
        final text = value?.toString() ?? '';
        if (text.isNotEmpty) winningCells.add(text);
      }
    }

    int toInt(Object? value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool toBool(Object? value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      return value?.toString() == 'true';
    }

    return CaroRoom(
      status: map['status']?.toString() ?? 'waiting',
      boardSize: toInt(map['boardSize'], 3),
      winLength: toInt(map['winLength'], 3),
      turnRole: map['turnRole']?.toString() ?? 'user1',
      playerXRole: map['playerXRole']?.toString() ?? 'user1',
      playerORole: map['playerORole']?.toString() ?? 'user2',
      createdByRole: map['createdByRole']?.toString() ?? 'user1',
      creatorName: map['creatorName']?.toString() ?? 'Người chơi 1',
      guestName: map['guestName']?.toString() ?? 'Người chơi 2',
      winnerRole: map['winnerRole']?.toString() ?? '',
      winnerSymbol: map['winnerSymbol']?.toString() ?? '',
      isDraw: toBool(map['isDraw']),
      updatedAt: toInt(map['updatedAt'], 0),
      board: board,
      winningCells: winningCells,
    );
  }
}
