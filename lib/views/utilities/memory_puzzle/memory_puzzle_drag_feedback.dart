import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'memory_puzzle_engine.dart';
import 'memory_puzzle_piece_painter.dart';

/// Feedback của mảnh đang kéo: phóng to nhẹ, nâng khỏi nền và phát glow.
/// Kích thước layout vẫn giữ nguyên [puzzleDragSize] để anchor/tâm thả không
/// thay đổi; chỉ phần vẽ được scale nên thao tác trên màn nhỏ vẫn chính xác.
class MemoryPuzzleDragFeedback extends StatelessWidget {
  const MemoryPuzzleDragFeedback({
    super.key,
    required this.image,
    required this.piece,
    required this.rows,
    required this.cols,
    required this.reduceMotion,
  });

  final ui.Image image;
  final MemoryPuzzlePiece piece;
  final int rows;
  final int cols;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    const targetScale = 1.14;
    final startScale = reduceMotion ? targetScale : .82;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('memory-puzzle-drag-feedback-animation'),
      tween: Tween(begin: startScale, end: targetScale),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        final progress =
            ((scale - startScale) /
                    (targetScale - startScale == 0
                        ? 1
                        : targetScale - startScale))
                .clamp(0.0, 1.0);
        return Transform.scale(
          key: const ValueKey('memory-puzzle-drag-feedback'),
          scale: scale,
          child: Container(
            width: puzzleDragSize,
            height: puzzleDragSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFEACB7E,
                  ).withValues(alpha: .18 + progress * .2),
                  blurRadius: 12 + progress * 12,
                  spreadRadius: 1 + progress * 2,
                  offset: Offset(0, 4 + progress * 4),
                ),
                BoxShadow(
                  color: const Color(
                    0xFF8B7CFF,
                  ).withValues(alpha: .1 + progress * .08),
                  blurRadius: 22 + progress * 10,
                  spreadRadius: progress,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: SizedBox.square(
            dimension: puzzleDragSize,
            child: CustomPaint(
              painter: MemoryPuzzlePiecePainter(
                image: image,
                piece: piece,
                rows: rows,
                cols: cols,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
