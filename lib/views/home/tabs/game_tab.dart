import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async' show unawaited;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utilities/block_blast_game.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/games/game_download_service.dart';
import 'game_library_view.dart';
import 'soul_block_diary_cover.dart';

class GameTab extends StatefulWidget {
  const GameTab({super.key});
  @override
  State<GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<GameTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Map<String, bool> _downloadedGames = {'soul_block': false};
  int _coverRevision = 0;

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
          SLSnackBar(
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
          SLSnackBar(
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
      builder: (dialogContext) => SLMessageDialog(
        title: context.tr('home_tithmdliu_d9fc46'),
        message: L10nScope.of(context).format('p9_game_download_description', {
          'game': name,
          'count': disclosure.fileCount,
          'size': disclosure.sizeLabel,
        }),
        cancelLabel: context.tr('home_sau_8a3721'),
        confirmLabel: context.tr('p9_game_download_now'),
        icon: Icons.download_rounded,
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
      builder: (dialogContext) => SLMessageDialog(
        title: context.tr('home_xadliu_bc37b4'),
        message: L10nScope.of(
          context,
        ).format('p9_game_delete_description', {'game': name}),
        cancelLabel: context.tr('home_hy_1e4050'),
        confirmLabel: context.tr('p9_game_delete_now'),
        tone: SLDialogTone.danger,
        icon: Icons.delete_outline_rounded,
      ),
    );

    if (confirmed == true) {
      await GameDownloadService().deleteGameData(gameId);
      if (mounted) {
        await _loadDownloadStatus();
        messenger?.showSnackBar(
          SLSnackBar(content: Text(deleteSuccessMessage)),
        );
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
      if (mounted) setState(() => _coverRevision++);
    } catch (_) {
      if (messenger == null) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SLSnackBar(content: Text(openGameErrorMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final service = GameDownloadService();
    final downloaded = _downloadedGames['soul_block'] ?? false;
    return GameLibraryView(
      cover: SoulBlockDiaryCover(revision: _coverRevision),
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
