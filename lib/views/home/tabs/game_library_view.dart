import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

/// Màn thư viện độc lập với nền ảnh chung, không tạo hoặc tải quảng cáo.
class GameLibraryView extends StatelessWidget {
  const GameLibraryView({
    super.key,
    required this.isDownloaded,
    required this.onPlay,
    this.downloadProgress,
    this.onDelete,
  });

  final bool isDownloaded;
  final double? downloadProgress;
  final VoidCallback onPlay;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF3EFFA) : const Color(0xFF292535);
    final secondary = dark ? const Color(0xFFBCB6CA) : const Color(0xFF746D82);
    final accent = dark ? const Color(0xFFBFB0F0) : const Color(0xFF68529E);
    final progress = downloadProgress;
    final status = context.tr(
      progress != null
          ? 'p9_game_download_progress'
          : isDownloaded
          ? 'p9_game_ready_status'
          : 'game_library_download_hint',
    );
    final text = SLTheme.quicksand(color: ink);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF191720) : const Color(0xFFF8F7FC),
      body: DecoratedBox(
        key: const ValueKey('game-library-background'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    const Color(0xFF252131),
                    const Color(0xFF191720),
                    const Color(0xFF202C2B),
                  ]
                : [
                    const Color(0xFFF0EBFA),
                    const Color(0xFFFAF8F4),
                    const Color(0xFFEEF5F1),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 128),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sports_esports_outlined,
                          size: 20,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('p9_game_title'),
                            style: text.copyWith(
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('game_library_heading'),
                      style: text.copyWith(
                        fontSize: 30,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('p9_game_subtitle'),
                      style: text.copyWith(
                        fontSize: 14,
                        height: 1.6,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      key: const ValueKey('soul-block-feature-card'),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF2B2736) : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: dark
                              ? const Color(0xFF40384C)
                              : const Color(0xFFE6E0ED),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.035),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(27),
                            ),
                            child: Container(
                              height: 204,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: dark
                                      ? [
                                          const Color(0xFF353047),
                                          const Color(0xFF273D3B),
                                        ]
                                      : [
                                          const Color(0xFFECE5F8),
                                          const Color(0xFFE7F1EB),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _GamePatternPainter(),
                                      ),
                                    ),
                                  ),
                                  Transform.rotate(
                                    angle: -0.06,
                                    child: Container(
                                      width: 146,
                                      height: 146,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(38),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF655086,
                                            ).withValues(alpha: 0.2),
                                            blurRadius: 24,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(38),
                                        child: const CustomPaint(
                                          painter: _SoulBlockCardPainter(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('game_library_category'),
                                  style: text.copyWith(
                                    fontSize: 11,
                                    color: accent,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.tr('game_soul_block_name'),
                                        style: text.copyWith(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (isDownloaded && onDelete != null)
                                      IconButton(
                                        key: const ValueKey('game-delete'),
                                        tooltip: context.tr(
                                          'p9_game_delete_tooltip',
                                        ),
                                        onPressed: progress == null
                                            ? onDelete
                                            : null,
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: secondary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context.tr('game_library_description'),
                                  style: text.copyWith(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: secondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isDownloaded
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.download_for_offline_outlined,
                                      size: 17,
                                      color: isDownloaded
                                          ? const Color(0xFF56856C)
                                          : secondary,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        status,
                                        style: text.copyWith(
                                          fontSize: 12,
                                          height: 1.45,
                                          color: secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (progress != null) ...[
                                  Semantics(
                                    liveRegion: true,
                                    label: context.tr(
                                      'p9_game_download_progress',
                                    ),
                                    value:
                                        '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      color: accent,
                                      backgroundColor: accent.withValues(
                                        alpha: 0.12,
                                      ),
                                      minHeight: 5,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    key: const ValueKey('game-primary-action'),
                                    onPressed: progress == null ? onPlay : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF68529E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: Icon(
                                      progress != null
                                          ? Icons.downloading_rounded
                                          : isDownloaded
                                          ? Icons.play_arrow_rounded
                                          : Icons.download_rounded,
                                    ),
                                    label: Text(
                                      context.tr(
                                        progress != null
                                            ? 'p9_game_download_progress'
                                            : isDownloaded
                                            ? 'home_chingay_861291'
                                            : 'p9_game_download_now',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: text.copyWith(
                                        color: progress != null
                                            ? secondary
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 17,
                          color: secondary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            context.tr('game_library_footer'),
                            style: text.copyWith(
                              fontSize: 12,
                              height: 1.5,
                              color: secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GamePatternPainter extends CustomPainter {
  const _GamePatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF82719C).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final point in [
      Offset(size.width * 0.12, 45),
      Offset(size.width * 0.84, 138),
    ]) {
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-20, -20, 40, 40),
          const Radius.circular(10),
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset(size.width * 0.83, 42), 8, paint);
    canvas.drawCircle(Offset(size.width * 0.18, 160), 5, paint);
  }

  @override
  bool shouldRepaint(covariant _GamePatternPainter oldDelegate) => false;
}

class _SoulBlockCardPainter extends CustomPainter {
  const _SoulBlockCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.34)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF10172E), Color(0xFF25164A), Color(0xFF4A183F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFD166).withValues(alpha: 0.34),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.72, size.height * 0.18),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawRect(rect, glowPaint);

    final boardSize = math.min(size.width, size.height) * 0.78;
    final cellSize = boardSize / 6.0;
    final gap = cellSize * 0.14;
    final gridSize = (cellSize * 5) + (gap * 4);
    final startX = (size.width - gridSize) / 2;
    final startY = size.height * 0.18;

    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        startX - gap,
        startY - gap,
        gridSize + gap * 2,
        gridSize + gap * 2,
      ),
      Radius.circular(cellSize * 0.55),
    );
    canvas.drawRRect(boardRect, Paint()..color = const Color(0x66061122));
    canvas.drawRRect(
      boardRect,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final emptyCell = Paint()..color = const Color(0x18FFFFFF);
    final emptyStroke = Paint()
      ..color = const Color(0x16FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        final cellRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + (col * (cellSize + gap)),
            startY + (row * (cellSize + gap)),
            cellSize,
            cellSize,
          ),
          Radius.circular(cellSize * 0.24),
        );
        canvas.drawRRect(cellRect, emptyCell);
        canvas.drawRRect(cellRect, emptyStroke);
      }
    }

    void drawBlock(List<Offset> cells, Color color) {
      final glow = Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final shine = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.26), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      final fill = Paint()
        ..shader = LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

      for (final cell in cells) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + (cell.dx * (cellSize + gap)),
            startY + (cell.dy * (cellSize + gap)),
            cellSize,
            cellSize,
          ),
          Radius.circular(cellSize * 0.26),
        );
        canvas.drawRRect(rrect, glow);
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, shine);
      }
    }

    drawBlock(const [
      Offset(0, 0),
      Offset(1, 0),
      Offset(0, 1),
    ], const Color(0xFFFF4D6D));
    drawBlock(const [
      Offset(3, 0),
      Offset(4, 0),
      Offset(4, 1),
    ], const Color(0xFFFFD166));
    drawBlock(const [
      Offset(1, 2),
      Offset(2, 2),
      Offset(3, 2),
    ], const Color(0xFF4D96FF));
    drawBlock(const [
      Offset(0, 3),
      Offset(0, 4),
      Offset(1, 4),
    ], const Color(0xFF37E67F));
    drawBlock(const [
      Offset(3, 3),
      Offset(4, 3),
      Offset(3, 4),
      Offset(4, 4),
    ], const Color(0xFFC77DFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
