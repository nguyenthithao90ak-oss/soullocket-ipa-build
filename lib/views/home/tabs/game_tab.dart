import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async' show StreamSubscription, unawaited;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:soullocket_app/core/sl_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utilities/block_blast_game.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/games/game_download_service.dart';
import '../../../utils/services/games/memory_puzzle_sound.dart';
import '../../../utils/services/house_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../utilities/memory_puzzle/memory_puzzle_screen.dart';
import '../../utilities/memory_puzzle/memory_puzzle_session.dart';
import 'game_library_view.dart';
import 'pet_care_game_screen.dart';
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
  bool _openingPuzzle = false;
  bool _openingGame = false;
  bool _openingSoulBlock = false;

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
    if (_openingGame) return;
    _openingGame = true;
    try {
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
    } finally {
      _openingGame = false;
    }
  }

  Future<void> _openSoulBlockGame(BuildContext context) async {
    if (_openingSoulBlock) return;
    _openingSoulBlock = true;
    final openGameErrorMsg = context.tr('home_khngmcsoul_009d9e');
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await slPushRoute<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const BlockBlastGame(),
          settings: const RouteSettings(name: 'soul_block_game'),
        ),
        identity: const ValueKey('soul_block_game'),
        rootNavigator: true,
      );
      if (mounted) setState(() => _coverRevision++);
    } catch (_) {
      if (messenger == null) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SLSnackBar(content: Text(openGameErrorMsg)));
    } finally {
      _openingSoulBlock = false;
    }
  }

  Future<void> _openMemoryPuzzle(BuildContext context) async {
    if (_openingPuzzle) return;
    _openingPuzzle = true;
    try {
      final noHouseMessage = context.tr('memory_puzzle_no_house');
      final messenger = ScaffoldMessenger.maybeOf(context);
      final navigator = Navigator.of(context, rootNavigator: true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final houseId = await HouseService().getCurrentHouseId();
      if (!mounted) return;
      if (uid == null ||
          houseId == null ||
          houseId.isEmpty ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        messenger?.showSnackBar(SLSnackBar(content: Text(noHouseMessage)));
        return;
      }
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      late final MaterialPageRoute<void> puzzleRoute;
      final session = MemoryPuzzleSession.forHouse(
        uid: uid,
        houseId: houseId,
        isCurrent: () =>
            mounted &&
            FirebaseAuth.instance.currentUser?.uid == uid &&
            (prefs.getString('il_house_id') ?? houseId) == houseId,
        onAccessDenied: () {
          if (mounted && puzzleRoute.isCurrent) navigator.pop();
          messenger?.showSnackBar(SLSnackBar(content: Text(noHouseMessage)));
        },
      );
      final audio = MemoryPuzzleSound();
      StreamSubscription<User?>? auth;
      try {
        puzzleRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'memory_puzzle'),
          builder: (_) => MemoryPuzzleScreen(
            progressScope: '$uid|$houseId',
            audio: audio,
            loadPhoto: ({excludePhotoId, preferredPhotoId}) =>
                session.loadPhoto(
                  excludePhotoId: excludePhotoId,
                  preferredPhotoId: preferredPhotoId,
                ),
            loadProgress: session.loadProgress,
            saveProgress: session.saveProgress,
          ),
        );
        auth = FirebaseAuth.instance.authStateChanges().listen((user) {
          // Không giữ ảnh của tài khoản trước trên một route độc lập với Home.
          if (user?.uid != uid && puzzleRoute.isCurrent) {
            navigator.removeRoute(puzzleRoute);
          }
        });
        if (!context.mounted) return;
        await slPushRoute<void>(
          context,
          puzzleRoute,
          identity: const ValueKey('memory_puzzle'),
          rootNavigator: true,
        );
      } finally {
        await auth?.cancel();
        session.dispose();
        await audio.dispose();
      }
    } finally {
      _openingPuzzle = false;
    }
  }

  Future<void> _openPetCareGame(BuildContext context) async {
    await slPushRoute<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PetCareGameScreen(),
        settings: const RouteSettings(name: 'pet_care_game'),
      ),
      identity: const ValueKey('pet_care_game'),
      rootNavigator: true,
    );
    if (mounted) setState(() => _coverRevision++);
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
      secondaryLabel: context.tr('memory_puzzle_open'),
      secondaryAction: () => unawaited(_openMemoryPuzzle(context)),
      // Trạm Mây và luồng chăm bé liên quan chỉ mở trong debug để thử
      // nghiệm; bản chính thức/release tạm thời không quảng bá luồng này.
      onOpenPetCare: kDebugMode
          ? () => unawaited(_openPetCareGame(context))
          : null,
      onDelete: downloaded
          ? () => _confirmDeleteGame(context, 'soul_block', 'Soul Block')
          : null,
    );
  }
}
