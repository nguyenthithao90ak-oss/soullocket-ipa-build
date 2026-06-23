import 'package:flutter/material.dart';

import 'soul_block_game.dart';
part 'block_blast/block_blast_models.dart';

class BlockBlastGame extends StatelessWidget {
  const BlockBlastGame({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep the old storage key so best score and local leaderboard are preserved.
    return SoulBlockGame(
      storageKeyPrefix: 'block_blast',
    );
  }
}
