// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math';

/// Độ khó có trần số mảnh để vẫn thao tác được trên điện thoại.
class MemoryPuzzleLevel {
  const MemoryPuzzleLevel._(this.level, this.rows, this.cols);

  factory MemoryPuzzleLevel.forLevel(int level) {
    final value = level.clamp(1, 9999);
    final side = value == 1
        ? 2
        : value <= 3
        ? 3
        : value <= 6
        ? 4
        : value <= 9
        ? 5
        : 6;
    return MemoryPuzzleLevel._(value, side, side);
  }

  final int level;
  final int rows;
  final int cols;
  int get pieceCount => rows * cols;
  bool get rotationEnabled => level >= 5;
  int get hintBudget => level <= 3 ? 3 : 2;
  double get snapTolerance => max(.26, .56 - (level - 1) * .035);
  int get targetSeconds => pieceCount * (rotationEnabled ? 24 : 18);
}

class MemoryPuzzlePiece {
  MemoryPuzzlePiece({
    required this.id,
    required this.row,
    required this.col,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    this.quarterTurns = 0,
    this.placed = false,
  });

  final int id, row, col;
  // Hai cạnh kề nhau luôn trái dấu, mép ngoài phẳng.
  final int top, right, bottom, left;
  int quarterTurns;
  bool placed;
}

/// Logic ván không phụ thuộc Flutter/plugin, đường cắt xác định bằng seed.
class MemoryPuzzleEngine {
  MemoryPuzzleEngine({required int level, required this.seed})
    : difficulty = MemoryPuzzleLevel.forLevel(level) {
    final random = Random(seed);
    for (var row = 0; row < difficulty.rows; row++) {
      for (var col = 0; col < difficulty.cols; col++) {
        final id = row * difficulty.cols + col;
        pieces.add(
          MemoryPuzzlePiece(
            id: id,
            row: row,
            col: col,
            top: row == 0 ? 0 : -pieces[id - difficulty.cols].bottom,
            left: col == 0 ? 0 : -pieces[id - 1].right,
            right: col == difficulty.cols - 1
                ? 0
                : (random.nextBool() ? 1 : -1),
            bottom: row == difficulty.rows - 1
                ? 0
                : (random.nextBool() ? 1 : -1),
            quarterTurns: difficulty.rotationEnabled ? random.nextInt(4) : 0,
          ),
        );
      }
    }
    trayOrder.addAll(
      List<int>.generate(pieces.length, (id) => id)..shuffle(random),
    );
  }

  final MemoryPuzzleLevel difficulty;
  final int seed;
  final List<MemoryPuzzlePiece> pieces = [];
  final List<int> trayOrder = [];
  int hintsUsed = 0;
  int mistakes = 0;
  int moves = 0;
  Set<int> get placedIds => {
    for (final piece in pieces)
      if (piece.placed) piece.id,
  };
  bool get isComplete => pieces.every((piece) => piece.placed);
  double get progress => placedIds.length / pieces.length;

  MemoryPuzzlePiece? _piece(int id) =>
      id < 0 || id >= pieces.length ? null : pieces[id];

  bool rotatePiece(int id) {
    final piece = _piece(id);
    if (piece == null || piece.placed || !difficulty.rotationEnabled)
      return false;
    piece.quarterTurns = (piece.quarterTurns + 1) % 4;
    return true;
  }

  /// Chỉ hút mảnh vào đúng tọa độ và đúng chiều; thả sai không mất mảnh.
  bool tryPlace(int id, {required double centerX, required double centerY}) {
    final piece = _piece(id);
    if (piece == null || piece.placed || !centerX.isFinite || !centerY.isFinite)
      return false;
    moves++;
    final dx = (centerX - (piece.col + .5) / difficulty.cols) * difficulty.cols;
    final dy = (centerY - (piece.row + .5) / difficulty.rows) * difficulty.rows;
    if (piece.quarterTurns != 0 ||
        sqrt(dx * dx + dy * dy) > difficulty.snapTolerance) {
      mistakes++;
      return false;
    }
    piece.placed = true;
    return true;
  }

  int? useHint() {
    if (isComplete || hintsUsed >= difficulty.hintBudget) return null;
    final piece = pieces.firstWhere((piece) => !piece.placed);
    piece.quarterTurns = 0;
    piece.placed = true;
    hintsUsed++;
    return piece.id;
  }

  int stars(int elapsedSeconds) {
    if (!isComplete) return 0;
    if (hintsUsed == 0 &&
        elapsedSeconds <= difficulty.targetSeconds &&
        mistakes <= pieces.length ~/ 2)
      return 3;
    if (hintsUsed < difficulty.hintBudget &&
        elapsedSeconds <= difficulty.targetSeconds * 2)
      return 2;
    return 1;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'level': difficulty.level,
    'seed': seed,
    'placed': placedIds.toList(),
    'turns': pieces.map((piece) => piece.quarterTurns).toList(),
    'hintsUsed': hintsUsed,
    'mistakes': mistakes,
    'moves': moves,
  };

  static MemoryPuzzleEngine fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['level'] is! int ||
        json['seed'] is! int ||
        (json['level'] as int) < 1 ||
        (json['level'] as int) > 9999) {
      throw const FormatException('Invalid puzzle snapshot');
    }
    final engine = MemoryPuzzleEngine(
      level: json['level'] as int,
      seed: json['seed'] as int,
    );
    final placed = json['placed'];
    final turns = json['turns'];
    if (placed is! List ||
        turns is! List ||
        turns.length != engine.pieces.length ||
        placed.any(
          (id) => id is! int || id < 0 || id >= engine.pieces.length,
        ) ||
        placed.toSet().length != placed.length ||
        turns.any((turn) => turn is! int || turn < 0 || turn > 3)) {
      throw const FormatException('Invalid puzzle pieces');
    }
    for (final piece in engine.pieces) {
      piece.placed = placed.contains(piece.id);
      piece.quarterTurns = turns[piece.id] as int;
      if ((piece.placed || !engine.difficulty.rotationEnabled) &&
          piece.quarterTurns != 0) {
        throw const FormatException('Invalid puzzle rotation');
      }
    }
    int count(String key) {
      final value = json[key];
      if (value is! int || value < 0 || value > 1000000000)
        throw const FormatException('Invalid puzzle counters');
      return value;
    }

    engine.hintsUsed = count('hintsUsed');
    engine.mistakes = count('mistakes');
    engine.moves = count('moves');
    if (engine.hintsUsed > engine.difficulty.hintBudget ||
        engine.hintsUsed > placed.length) {
      throw const FormatException('Invalid puzzle hints');
    }
    return engine;
  }
}
