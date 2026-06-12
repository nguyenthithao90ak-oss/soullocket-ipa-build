import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/sl_theme.dart';
import '../../utilities/block_blast_game.dart';
import '../../utilities/soul_rhythm_game.dart';
import '../../utilities/caro_neon_screen.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/game_download_service.dart';
import '../../../utils/services/admob_service.dart';

class GameTab extends StatefulWidget {
  const GameTab({super.key});

  static const String soulRhythmIconPath = 'assets/games/rhythm-tiles/icon.png';

  @override
  State<GameTab> createState() => _GameTabState();
}

class _GameTabState extends State<GameTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const AssetImage _soulRhythmIcon =
      AssetImage(GameTab.soulRhythmIconPath);
  bool _didPrecacheSoulRhythmIcon = false;

  final Map<String, bool> _downloadedGames = {
    'soul_block': false,
    'soul_rhythm': false,
    'caro_neon': false,
  };

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadDownloadStatus();
    _loadBannerAd();
    // Lắng nghe thay đổi download để cập nhật state mà không tạo Future mới
    GameDownloadService().addListener(_onDownloadServiceChanged);
  }

  @override
  void dispose() {
    GameDownloadService().removeListener(_onDownloadServiceChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onDownloadServiceChanged() {
    // Khi download service thay đổi, cập nhật trạng thái từ cache thành synchronous
    unawaited(_loadDownloadStatus());
  }

  Future<void> _loadBannerAd() async {
    final adErrorFallback = context.tr('home_khngthtiqu_b7dcec');
    try {
      final adMob = AdMobService();
      await adMob.initialize();

      if (await adMob.isProUser()) {
        return;
      }

      _bannerAd = await adMob.createBannerAd(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerReady = true;
            });
          }
        },
      );
    } catch (e) {
      debugPrint(
        'GameTab banner load failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: adErrorFallback,
        ).message}',
      );
    }
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
        'GameTab download status load failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('home_khngthtitr_ff9207'),
        ).message}',
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
                fallbackMessage:
                    context.tr('home_chathtigam_4cf45e'),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('home_tithmdliu_d9fc46'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '$name cần tải thêm ${disclosure.fileCount} tệp tài nguyên '
          '(${disclosure.sizeLabel}) để tiếp tục. Bạn có muốn tải ngay không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('home_sau_8a3721')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('home_tingay_1e6761')),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _confirmDeleteGame(
      BuildContext context, String gameId, String name) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.tr('home_xadliu_bc37b4'),
            style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
        content: Text(
            'Bạn muốn xóa dữ liệu đã tải của game $name để giải phóng bộ nhớ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('home_hy_1e4050'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('home_xangay_dc07fa'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GameDownloadService().deleteGameData(gameId);
      if (mounted) {
        await _loadDownloadStatus();
        messenger?.showSnackBar(
          SnackBar(content: Text('Đã xóa dữ liệu game $name.')),
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
        ..showSnackBar(
          SnackBar(
            content: Text(openGameErrorMsg),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                    final downloadService = GameDownloadService();

                    // Dùng _downloadedGames trực tiếp thay vì FutureBuilder
                    // Để tránh tạo Future mới mỗi lần rebuild (gây flash loading)
                    final soulBlockDownloaded =
                        _downloadedGames['soul_block'] ?? false;
                    final soulRhythmDownloaded =
                        _downloadedGames['soul_rhythm'] ?? false;
                    final caroNeonDownloaded =
                        _downloadedGames['caro_neon'] ?? false;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing + 2,
                      childAspectRatio: crossAxisCount == 3 ? 0.68 : 0.75,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        _SoulBlockCard(
                          isDownloaded: soulBlockDownloaded,
                          downloadProgress:
                              downloadService.getProgress('soul_block'),
                          onTap: () => _onGameTap(
                              'soul_block',
                              'Soul Block',
                              () => _openSoulBlockGame(context)),
                          onLongPress: soulBlockDownloaded
                              ? () => _confirmDeleteGame(
                                  context, 'soul_block', 'Soul Block')
                              : null,
                          onDelete: soulBlockDownloaded
                              ? () => _confirmDeleteGame(
                                  context, 'soul_block', 'Soul Block')
                              : null,
                        ),
                        if (kDebugMode)
                          _SoulRhythmCard(
                            imagePath: GameTab.soulRhythmIconPath,
                            isDownloaded: soulRhythmDownloaded,
                            downloadProgress:
                                downloadService.getProgress('soul_rhythm'),
                            onTap: () => _onGameTap(
                                'soul_rhythm',
                                'Soul Rhythm',
                                () => _openSoulGame(context)),
                            onLongPress: soulRhythmDownloaded
                                ? () => _confirmDeleteGame(
                                    context, 'soul_rhythm', 'Soul Rhythm')
                                : null,
                            onDelete: soulRhythmDownloaded
                                ? () => _confirmDeleteGame(
                                    context, 'soul_rhythm', 'Soul Rhythm')
                                : null,
                          ),
                        if (kDebugMode)
                          _GenericGameCard(
                            label: 'Caro Neon',
                            icon: Icons.grid_4x4_rounded,
                            color: const Color(0xFF00E5FF),
                            isDownloaded: caroNeonDownloaded,
                            downloadProgress:
                                downloadService.getProgress('caro_neon'),
                            onLongPress: caroNeonDownloaded
                                ? () => _confirmDeleteGame(
                                    context, 'caro_neon', 'Caro Neon')
                                : null,
                            onDelete: caroNeonDownloaded
                                ? () => _confirmDeleteGame(
                                    context, 'caro_neon', 'Caro Neon')
                                : null,
                            onTap: () => _onGameTap(
                                'caro_neon',
                                'Caro Neon',
                                () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const CaroNeonScreen()),
                                    )),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_isBannerReady && _bannerAd != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
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
    this.isDownloaded = false,
    this.downloadProgress,
    this.onLongPress,
    this.onDelete,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final Widget preview;
  final Color borderColor;
  final Color shadowColor;
  final bool isDownloaded;
  final double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    const previewSize = 66.0;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
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
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        preview,
                        const _TileGlossOverlay(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A3440),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDownloaded
                            ? [const Color(0xFFE91E63), const Color(0xFFF48FB1)]
                            : [borderColor, borderColor.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isDownloaded
                                  ? const Color(0xFFE91E63)
                                  : borderColor)
                              .withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: downloadProgress != null
                        ? SizedBox(
                            width: 60,
                            height: 10,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: downloadProgress,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDownloaded
                                    ? Icons.play_arrow_rounded
                                    : Icons.file_download_outlined,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDownloaded ? context.tr('home_chingay_861291') : context.tr('home_tixung_82b80b'),
                                style: SLTheme.quicksand(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
    this.isDownloaded = false,
    this.downloadProgress,
    this.onLongPress,
    this.onDelete,
  });

  final String imagePath;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool isDownloaded;
  final double? downloadProgress;

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
      onLongPress: onLongPress,
      onDelete: onDelete,
      isDownloaded: isDownloaded,
      downloadProgress: downloadProgress,
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
    this.isDownloaded = false,
    this.downloadProgress,
    this.onLongPress,
    this.onDelete,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool isDownloaded;
  final double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    return _GameLauncherTile(
      label: 'Soul Block',
      semanticsLabel: 'Soul Block',
      onTap: onTap,
      onLongPress: onLongPress,
      onDelete: onDelete,
      isDownloaded: isDownloaded,
      downloadProgress: downloadProgress,
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
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD166).withValues(alpha: 0.34),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.72, size.height * 0.18),
        radius: size.width * 0.7,
      ));
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
    canvas.drawRRect(
      boardRect,
      Paint()..color = const Color(0x66061122),
    );
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

    drawBlock(const [Offset(0, 0), Offset(1, 0), Offset(0, 1)], const Color(0xFFFF4D6D));
    drawBlock(const [Offset(3, 0), Offset(4, 0), Offset(4, 1)], const Color(0xFFFFD166));
    drawBlock(const [Offset(1, 2), Offset(2, 2), Offset(3, 2)], const Color(0xFF4D96FF));
    drawBlock(const [Offset(0, 3), Offset(0, 4), Offset(1, 4)], const Color(0xFF37E67F));
    drawBlock(const [Offset(3, 3), Offset(4, 3), Offset(3, 4), Offset(4, 4)], const Color(0xFFC77DFF));

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.74, size.width * 0.64, 16),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xCCFFFFFF),
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'COMBO x4',
        style: TextStyle(
          color: Color(0xFF3B1453),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width * 0.5 - textPainter.width / 2,
        size.height * 0.74 + 3,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GenericGameCard extends StatelessWidget {
  const _GenericGameCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDownloaded = false,
    this.downloadProgress,
    this.onLongPress,
    this.onDelete,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDownloaded;
  final double? downloadProgress;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _GameLauncherTile(
      label: label,
      semanticsLabel: label,
      onTap: onTap,
      isDownloaded: isDownloaded,
      downloadProgress: downloadProgress,
      onLongPress: onLongPress,
      onDelete: onDelete,
      borderColor: color,
      shadowColor: color,
      preview: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 32,
          ),
        ),
      ),
    );
  }
}
