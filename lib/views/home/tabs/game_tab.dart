import 'dart:async' show unawaited;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../core/sl_theme.dart';
import '../../utilities/block_blast_game.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/games/game_download_service.dart';
import 'game_library_view.dart';

class GameTab extends StatefulWidget {
  const GameTab({super.key});
  @override
  State<GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<GameTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Map<String, bool> _downloadedGames = {'soul_block': false};

  @override
  void initState() {
    super.initState();
    _loadDownloadStatus();
    // Lắng nghe thay đổi download để cập nhật state mà không tạo Future mới
    GameDownloadService().addListener(_onDownloadServiceChanged);
  }

  @override
  void dispose() {
    GameDownloadService().removeListener(_onDownloadServiceChanged);
    super.dispose();
  }

  void _onDownloadServiceChanged() {
    // Khi download service thay đổi, cập nhật trạng thái từ cache thành synchronous
    unawaited(_loadDownloadStatus());
  }

  Future<void> _loadDownloadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        for (final key in _downloadedGames.keys) {
          _downloadedGames[key] =
              prefs.getBool('game_downloaded_$key') ?? false;
        }
      });
    } catch (e) {
      debugPrint(
        'GameTab download status load failed: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('home_khngthtitr_ff9207')).message}',
      );
    }
  }

  Future<bool> _handleRealDownload(String gameId) async {
    final service = GameDownloadService();
    if (service.isDownloading(gameId)) return false;

    try {
      await service.downloadGame(gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home_tixonggame_d8e5c1')),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMapper.resolve(
                e,
                fallbackMessage: context.tr('home_chathtigam_4cf45e'),
              ).message,
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _confirmGameDownload(String gameId, String name) async {
    final disclosure = GameDownloadService().disclosureFor(gameId);
    if (disclosure.fileCount == 0) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF0F5), Color(0xFFFFF8FA), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD81B60).withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6584), Color(0xFFD81B60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎮', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('home_tithmdliu_d9fc46'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: const Color(0xFFD81B60),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L10nScope.of(context).format('p9_game_download_description', {
                  'game': name,
                  'count': disclosure.fileCount,
                  'size': disclosure.sizeLabel,
                }),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5D4E56),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        context.tr('home_sau_8a3721'),
                        style: SLTheme.quicksand(
                          color: const Color(0xFF8A7682),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF527B), Color(0xFFD81B60)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFD81B60,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          context.tr('p9_game_download_now'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return confirmed == true;
  }

  Future<void> _confirmDeleteGame(
    BuildContext context,
    String gameId,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final deleteSuccessMessage = L10nScope.of(
      context,
    ).format('p9_game_delete_success', {'game': name});
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF5F5), Color(0xFFFFF8FA), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🗑️', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('home_xadliu_bc37b4'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: const Color(0xFFE53935),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L10nScope.of(
                  context,
                ).format('p9_game_delete_description', {'game': name}),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5D4E56),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        context.tr('home_hy_1e4050'),
                        style: SLTheme.quicksand(
                          color: const Color(0xFF8A7682),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFD32F2F,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          context.tr('p9_game_delete_now'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await GameDownloadService().deleteGameData(gameId);
      if (mounted) {
        await _loadDownloadStatus();
        messenger?.showSnackBar(SnackBar(content: Text(deleteSuccessMessage)));
      }
    }
  }

  void _onGameTap(String gameId, String name, VoidCallback onPlay) async {
    final service = GameDownloadService();
    final isDownloaded = await service.isGameDownloaded(gameId);
    if (!mounted) return;
    if (isDownloaded) {
      onPlay();
      return;
    }

    final shouldDownload = await _confirmGameDownload(gameId, name);
    if (!mounted || !shouldDownload) return;

    final downloaded = await _handleRealDownload(gameId);
    if (!mounted) return;
    await _loadDownloadStatus();
    if (downloaded && mounted) {
      onPlay();
    }
  }

  Future<void> _openSoulBlockGame(BuildContext context) async {
    final openGameErrorMsg = context.tr('home_khngmcsoul_009d9e');
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
        ..showSnackBar(SnackBar(content: Text(openGameErrorMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final service = GameDownloadService();
    final downloaded = _downloadedGames['soul_block'] ?? false;
    return GameLibraryView(
      isDownloaded: downloaded,
      downloadProgress: service.getProgress('soul_block'),
      onPlay: () => _onGameTap(
        'soul_block',
        'Soul Block',
        () => _openSoulBlockGame(context),
      ),
      onDelete: downloaded
          ? () => _confirmDeleteGame(context, 'soul_block', 'Soul Block')
          : null,
    );
  }
}
