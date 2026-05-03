import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/sl_theme.dart';
import '../../utilities/block_blast_game.dart';
import '../../utilities/soul_rhythm_game.dart';
import '../../utilities/caro_neon_screen.dart';
import '../../utilities/heart_catcher_game.dart';
import '../../../utils/services/game_download_service.dart';
import '../../../services/admob_service.dart';

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

  final Map<String, bool> _downloadedGames = {
    'soul_block': false,
    'soul_rhythm': false,
    'caro_neon': false,
    'heart_catcher': false,
  };

  final Map<String, double> _downloadProgress = {};
  
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadDownloadStatus();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
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
  }

  Future<void> _loadDownloadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final key in _downloadedGames.keys) {
        _downloadedGames[key] = prefs.getBool('game_downloaded_$key') ?? false;
      }
    });
  }

  Future<void> _saveDownloadStatus(String gameId, bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('game_downloaded_$gameId', status);
    setState(() {
      _downloadedGames[gameId] = status;
    });
  }

  Future<void> _handleRealDownload(String gameId) async {
    final service = GameDownloadService();
    if (service.isDownloading(gameId)) return;

    try {
      await service.downloadGame(gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tải xong game! Chúc bạn chơi vui vẻ. 🎮'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải game: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onGameTap(String gameId, VoidCallback onPlay) async {
    final service = GameDownloadService();
    final isDownloaded = await service.isGameDownloaded(gameId);
    if (isDownloaded) {
      onPlay();
    } else {
      await _handleRealDownload(gameId);
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

                    final downloadService = GameDownloadService();
                    return ListenableBuilder(
                      listenable: downloadService,
                      builder: (context, _) {
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing + 2,
                          childAspectRatio: crossAxisCount == 3 ? 0.68 : 0.75,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          children: [
                            FutureBuilder<bool>(
                              future: downloadService.isGameDownloaded('soul_block'),
                              builder: (context, snapshot) {
                                final isDownloaded = snapshot.data ?? false;
                                return _SoulBlockCard(
                                  isDownloaded: isDownloaded,
                                  downloadProgress: downloadService.getProgress('soul_block'),
                                  onTap: () => _onGameTap('soul_block', () => _openSoulBlockGame(context)),
                                  onLongPress: isDownloaded ? () => _confirmDeleteGame(context, 'soul_block', 'Soul Block') : null,
                                );
                              }
                            ),
                            FutureBuilder<bool>(
                              future: downloadService.isGameDownloaded('soul_rhythm'),
                              builder: (context, snapshot) {
                                final isDownloaded = snapshot.data ?? false;
                                return _SoulRhythmCard(
                                  imagePath: GameTab.soulRhythmIconPath,
                                  isDownloaded: isDownloaded,
                                  downloadProgress: downloadService.getProgress('soul_rhythm'),
                                  onTap: () => _onGameTap('soul_rhythm', () => _openSoulGame(context)),
                                  onLongPress: isDownloaded ? () => _confirmDeleteGame(context, 'soul_rhythm', 'Soul Rhythm') : null,
                                );
                              }
                            ),
                            _GenericGameCard(
                              label: 'Caro Neon',
                              icon: Icons.grid_4x4_rounded,
                              color: const Color(0xFF00E5FF),
                              isDownloaded: true, // Game nhẹ, mặc định có sẵn
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CaroNeonScreen()),
                              ),
                            ),
                            _GenericGameCard(
                              label: 'Heart Catcher',
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFFF4081),
                              isDownloaded: true, // Game nhẹ, mặc định có sẵn
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HeartCatcherGame()),
                              ),
                            ),
                          ],
                        );
                      }
                    );
                  },
                ),
              ),
              if (_isBannerReady && _bannerAd != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: Text('Dữ liệu Game', style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
                      content: Text(
                        'Nếu gặp lỗi "unauthorized", bạn cần cập nhật Firebase Storage Rules cho thư mục game_assets thành public read.',
                        style: SLTheme.quicksand(fontWeight: FontWeight.w700),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đã hiểu'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFFE91E63), size: 20),
                tooltip: 'Thông tin dữ liệu',
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
    this.isDownloaded = false,
    this.downloadProgress,
    this.onLongPress,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget preview;
  final Color borderColor;
  final Color shadowColor;
  final bool isDownloaded;
  final double? downloadProgress;

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
                          color: shadowColor.withOpacity(0.2),
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
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDownloaded
                            ? [const Color(0xFFE91E63), const Color(0xFFF48FB1)]
                            : [borderColor, borderColor.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isDownloaded ? const Color(0xFFE91E63) : borderColor).withOpacity(0.3),
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
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDownloaded ? Icons.play_arrow_rounded : Icons.file_download_outlined,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDownloaded ? 'CHƠI NGAY' : 'TẢI XUỐNG',
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
  });

  final String imagePath;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
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
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDownloaded;
  final double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    return _GameLauncherTile(
      label: 'Soul Block',
      semanticsLabel: 'Soul Block',
      onTap: onTap,
      onLongPress: onLongPress,
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

class _GenericGameCard extends StatelessWidget {
  const _GenericGameCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDownloaded = false,
    this.downloadProgress,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDownloaded;
  final double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    return _GameLauncherTile(
      label: label,
      semanticsLabel: label,
      onTap: onTap,
      isDownloaded: isDownloaded,
      downloadProgress: downloadProgress,
      borderColor: color,
      shadowColor: color,
      preview: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
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
