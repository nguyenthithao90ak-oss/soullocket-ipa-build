import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import 'soul_block_diary_cover.dart';

/// Màn thư viện độc lập với nền ảnh chung, không tạo hoặc tải quảng cáo.
class GameLibraryView extends StatelessWidget {
  const GameLibraryView({
    super.key,
    required this.isDownloaded,
    required this.onPlay,
    this.downloadProgress,
    this.onDelete,
    this.cover,
  });

  final bool isDownloaded;
  final double? downloadProgress;
  final VoidCallback onPlay;
  final VoidCallback? onDelete;
  final Widget? cover;

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
                              height: 232,
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
                              child: cover ?? const SoulBlockPhotoArtwork(),
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
