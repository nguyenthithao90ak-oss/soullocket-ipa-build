import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../utilities/block_blast_game.dart';
import '../../utilities/soul_rhythm_game.dart';

class GameTab extends StatefulWidget {
  const GameTab({super.key});

  static const String soulRhythmIconPath = 'assets/games/rhythm-tiles/icon.png';

  @override
  State<GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<GameTab> {
  static const AssetImage _soulRhythmIcon =
      AssetImage(GameTab.soulRhythmIconPath);
  bool _didPrecacheSoulRhythmIcon = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheSoulRhythmIcon) return;
    _didPrecacheSoulRhythmIcon = true;
    precacheImage(_soulRhythmIcon, context);
  }

  void _openSoulGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SoulRhythmGame(),
      ),
    );
  }

  Future<void> _openSoulBlockGame(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const BlockBlastGame(),
          settings: const RouteSettings(name: 'soul_block_game'),
        ),
      );
    } catch (_) {
      if (messenger == null) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không mở được Soul Block lúc này. Hãy thử lại.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GameHeader(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 280 ? 2 : 3;
                    final spacing = constraints.maxWidth < 360 ? 10.0 : 14.0;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing + 2,
                      childAspectRatio: crossAxisCount == 3 ? 0.8 : 0.92,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        _SoulBlockCard(
                          onTap: () => _openSoulBlockGame(context),
                        ),
                        _SoulRhythmCard(
                          imagePath: GameTab.soulRhythmIconPath,
                          onTap: () => _openSoulGame(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                      ).createShader(bounds),
                      child: Text(
                        'GAME CENTER',
                        style: SLTheme.quicksand(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 96),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileGlossOverlay extends StatelessWidget {
  const _TileGlossOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, 0.18),
              Colors.transparent,
              Color.fromRGBO(255, 255, 255, 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _GameLauncherTile extends StatelessWidget {
  const _GameLauncherTile({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    required this.preview,
    required this.borderColor,
    required this.shadowColor,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget preview;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    const previewSize = 74.0;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: previewSize,
                  height: previewSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: borderColor.withOpacity(0.9),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withOpacity(0.22),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 7),
                      ),
                      const BoxShadow(
                        color: Color.fromRGBO(255, 255, 255, 0.12),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius - 1),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        preview,
                        const _TileGlossOverlay(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6B4A5D),
                        height: 1.08,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoulRhythmCard extends StatelessWidget {
  const _SoulRhythmCard({
    required this.imagePath,
    required this.onTap,
  });

  final String imagePath;
  final VoidCallback onTap;

  Widget _buildInstantPlaceholder() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B1453), Color(0xFF160821)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Color(0xFFFF77B7),
          size: 36,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GameLauncherTile(
      label: 'Soul Rhythm',
      semanticsLabel: 'Soul Rhythm',
      onTap: onTap,
      borderColor: const Color(0xFFFF77B7),
      shadowColor: const Color(0xFFFF77B7),
      preview: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return _buildInstantPlaceholder();
            },
            errorBuilder: (context, error, stackTrace) =>
                _buildInstantPlaceholder(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(49, 16, 69, 0.1),
                  Color.fromRGBO(24, 8, 36, 0.42),
                  Color.fromRGBO(255, 119, 183, 0.24),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoulBlockCard extends StatelessWidget {
  const _SoulBlockCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GameLauncherTile(
      label: 'Soul Block',
      semanticsLabel: 'Soul Block',
      onTap: onTap,
      borderColor: const Color(0xFFFFC857),
      shadowColor: const Color(0xFF8CFF98),
      preview: const SizedBox.expand(
        child: CustomPaint(
          painter: _SoulBlockCardPainter(),
        ),
      ),
    );
  }
}

class _SoulBlockCardPainter extends CustomPainter {
  const _SoulBlockCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1A2749), Color(0xFF2A1D3D), Color(0xFF3D2233)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    final panel = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = const Color(0x24FFFFFF)
      ..strokeWidth = 1;
    final boardSize = math.min(size.width, size.height);
    final cellSize = boardSize / 6.6;
    final gap = cellSize * 0.16;
    final gridSize = (cellSize * 4) + (gap * 3);
    final startX = (size.width - gridSize) / 2;
    final startY = (size.height - gridSize) / 2;
    final tones = <Color>[
      const Color(0xFFFF0000),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF0000FF),
      const Color(0xFFFF00FF),
    ];

    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        final cellRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + (col * (cellSize + gap)),
            startY + (row * (cellSize + gap)),
            cellSize,
            cellSize,
          ),
          Radius.circular(cellSize * 0.22),
        );
        canvas.drawRRect(cellRect, panel);
        canvas.drawRRect(cellRect, line);
      }
    }

    void drawBlock(
      double x,
      double y,
      List<Offset> cells,
      Color color,
    ) {
      final glow = Paint()
        ..color = color.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      final fill = Paint()
        ..shader = LinearGradient(
          colors: [color.withOpacity(0.95), color.withOpacity(0.58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(
          Rect.fromLTWH(x, y, cellSize * 2.6, cellSize * 2.2),
        );

      for (final cell in cells) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + (cell.dx * (cellSize + gap)),
            y + (cell.dy * (cellSize + gap)),
            cellSize,
            cellSize,
          ),
          Radius.circular(cellSize * 0.24),
        );
        canvas.drawRRect(rrect, glow);
        canvas.drawRRect(rrect, fill);
      }
    }

    drawBlock(
      startX + cellSize * 0.2,
      startY + cellSize * 0.25,
      const [Offset(0, 0), Offset(1, 0)],
      tones[0],
    );
    drawBlock(
      startX + cellSize * 1.75,
      startY + cellSize * 1.65,
      const [Offset(0, 0), Offset(1, 0), Offset(2, 0)],
      tones[1],
    );
    drawBlock(
      startX + cellSize * 0.9,
      startY + cellSize * 2.85,
      const [Offset(0, 0), Offset(0, 1), Offset(1, 1)],
      tones[2],
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
