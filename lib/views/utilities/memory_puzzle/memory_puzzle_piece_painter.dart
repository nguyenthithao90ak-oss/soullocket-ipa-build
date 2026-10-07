import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'memory_puzzle_engine.dart';

/// Khoảng đệm giữ nguyên ngàm, kể cả khi xoay mảnh ở khay.
const puzzlePiecePaddingRatio = .22;
const puzzleBoardInset = 6.0;
const puzzleDragSize = 86.0;

Path memoryPuzzlePiecePath(Rect rect, MemoryPuzzlePiece piece) {
  final path = Path()..moveTo(rect.left, rect.top);
  void edge(Offset start, Offset end, int tab) {
    final delta = end - start;
    final length = delta.distance;
    final normal = Offset(delta.dy, -delta.dx) * (tab / length);
    Offset point(double t, double depth) =>
        start + delta * t + normal * (length * depth);
    final neck = point(.38, 0);
    path.lineTo(neck.dx, neck.dy);
    if (tab == 0) {
      path.lineTo(end.dx, end.dy);
      return;
    }
    void curve(
      double t1,
      double d1,
      double t2,
      double d2,
      double t3,
      double d3,
    ) {
      final a = point(t1, d1), b = point(t2, d2), c = point(t3, d3);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    // Cổ hẹp và đầu tròn, hai cạnh kề dùng cùng đường cắt trái dấu.
    curve(.42, .025, .32, .13, .39, .17);
    curve(.44, .22, .56, .22, .61, .17);
    curve(.68, .13, .58, .025, .62, 0);
    path.lineTo(end.dx, end.dy);
  }

  edge(rect.topLeft, rect.topRight, piece.top);
  edge(rect.topRight, rect.bottomRight, piece.right);
  edge(rect.bottomRight, rect.bottomLeft, piece.bottom);
  edge(rect.bottomLeft, rect.topLeft, piece.left);
  return path..close();
}

Rect _photoSquare(ui.Image image) {
  final side = math.min(image.width, image.height).toDouble();
  return Rect.fromLTWH(
    (image.width - side) / 2,
    (image.height - side) / 2,
    side,
    side,
  );
}

/// Vẽ từ toàn bitmap chung để đầu ngàm chứa đúng pixel của ảnh liền kề.
void _paintPiece(
  Canvas canvas,
  ui.Image image,
  MemoryPuzzlePiece piece,
  Rect rect,
  int rows,
  int cols, {
  bool shadow = false,
}) {
  final path = memoryPuzzlePiecePath(rect, piece);
  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  canvas.rotate(piece.quarterTurns * math.pi / 2);
  canvas.translate(-rect.center.dx, -rect.center.dy);
  if (shadow) canvas.drawShadow(path, Colors.black54, 3, false);
  canvas.save();
  canvas.clipPath(path);
  canvas.drawImageRect(
    image,
    _photoSquare(image),
    Rect.fromLTWH(
      rect.left - piece.col * rect.width,
      rect.top - piece.row * rect.height,
      rect.width * cols,
      rect.height * rows,
    ),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = shadow ? 1.4 : .7
      ..color = Colors.white.withValues(alpha: shadow ? .9 : .45),
  );
  canvas.restore();
}

class MemoryPuzzlePiecePainter extends CustomPainter {
  const MemoryPuzzlePiecePainter({
    required this.image,
    required this.piece,
    required this.rows,
    required this.cols,
  });
  final ui.Image image;
  final MemoryPuzzlePiece piece;
  final int rows, cols;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide / (1 + 2 * puzzlePiecePaddingRatio);
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    _paintPiece(canvas, image, piece, rect, rows, cols, shadow: true);
  }

  // Piece là model mutable; so sánh lại chính object cũ sẽ bỏ sót thao tác xoay.
  @override
  bool shouldRepaint(covariant MemoryPuzzlePiecePainter oldDelegate) => true;
}

class MemoryPuzzleBoardPainter extends CustomPainter {
  const MemoryPuzzleBoardPainter({required this.image, required this.engine});
  final ui.Image image;
  final MemoryPuzzleEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final board = (Offset.zero & size).deflate(puzzleBoardInset);
    final cellWidth = board.width / engine.difficulty.cols;
    final cellHeight = board.height / engine.difficulty.rows;
    for (final piece in engine.pieces) {
      final rect = Rect.fromLTWH(
        board.left + piece.col * cellWidth,
        board.top + piece.row * cellHeight,
        cellWidth,
        cellHeight,
      );
      if (piece.placed) {
        _paintPiece(
          canvas,
          image,
          piece,
          rect,
          engine.difficulty.rows,
          engine.difficulty.cols,
        );
      } else {
        canvas.drawPath(
          memoryPuzzlePiecePath(rect, piece),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..color = Colors.white.withValues(alpha: .16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MemoryPuzzleBoardPainter oldDelegate) => true;
}
