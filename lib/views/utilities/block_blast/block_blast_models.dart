part of '../block_blast_game.dart';

class BlockBlastTile {
  final Color color;

  BlockBlastTile({required this.color});
}

class BlockBlastPiece {
  final Color color;
  final List<List<bool>> shape;

  BlockBlastPiece({
    required this.color,
    required this.shape,
  });
}
