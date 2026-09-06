part of '../../home_screen.dart';

final Map<String, ImageProvider<Object>> _homeShellBackgroundProviderCache =
    <String, ImageProvider<Object>>{};

extension _HomeScreenShellBackground on _HomeScreenState {
  Widget _buildShellBackground({
    required String themeKey,
    required int tabIndex,
    required bool isDark,
    required String backgroundUrl,
    required String graphicsQualityKey,
    bool animateAmbientEffects = false,
  }) {
    final normalizedBackgroundUrl = backgroundUrl.trim();
    if (normalizedBackgroundUrl.isNotEmpty) {
      return _buildPinnedCustomShellBackground(
        themeKey: themeKey,
        isDark: isDark,
        backgroundUrl: normalizedBackgroundUrl,
      );
    }

    // Áp dụng ảnh nền mặc định cho tất cả các tab
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/default_home_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            isAntiAlias: false,
            cacheWidth: 720,
          ),
        ),
        // Lớp phủ tối nhẹ giúp làm dịu nền, làm nổi bật nội dung phía trên
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedCustomShellBackground({
    required String themeKey,
    required bool isDark,
    required String backgroundUrl,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _StableShellBackgroundImage(backgroundUrl: backgroundUrl),
        ),
        // Lớp phủ tối nhẹ giúp làm dịu nền tùy chỉnh
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }

  bool _usesDarkShell(
    int tabIndex,
    bool isDark, {
    required bool usesCustomBackground,
  }) {
    if (tabIndex == 1) return false; // Nháº­t kÃ½ luÃ´n sÃ¡ng
    return isDark;
  }

  List<Color> _resolveTabShellGradient({
    required int tabIndex,
    required String themeKey,
    required bool isDark,
    required bool usesCustomBackground,
  }) {
    if (tabIndex == 1) {
      // Nháº­t kÃ½: MÃ u pastel há»“ng sÃ¡ng áº¥m Ã¡p (Ná»•i báº­t nháº¥t)
      return const [
        Color(0xFFFFE4E1),
        Color(0xFFFFC0CB),
        Color(0xFFFBC2EB),
        Color(0xFFFF9A9E),
      ];
    } else if (tabIndex == 2) {
      // Tiá»‡n Ã­ch: Xanh ngá»c thanh lá»‹ch
      return isDark
          ? const [Color(0xFF001F3F), Color(0xFF003366), Color(0xFF00509E)]
          : const [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)];
    } else if (tabIndex == 3) {
      // Giáº£i trÃ­: TÃ­m huyá»n bÃ­
      return isDark
          ? const [Color(0xFF1A1025), Color(0xFF311B4B), Color(0xFF4A2377)]
          : const [Color(0xFFF3E5F5), Color(0xFFE1BEE7), Color(0xFFCE93D8)];
    } else if (tabIndex == 4) {
      // Cáº­p nháº­t: Xanh lÃ¡ má» thÆ° giÃ£n
      return isDark
          ? const [Color(0xFF00251A), Color(0xFF004D40), Color(0xFF00695C)]
          : const [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7)];
    }

    return _resolveShellGradient(themeKey, isDark);
  }

  List<Color> _resolveShellGradient(String themeKey, bool isDark) {
    if (themeKey == 'off') {
      return isDark
          ? const [Color(0xFF121212), Color(0xFF1E1E1E), Color(0xFF2D2D2D)]
          : const [Color(0xFFFDFDFD), Color(0xFFF4F7F6), Color(0xFFE8ECEF)];
    }

    switch (themeKey) {
      case 'theme-night':
        return const [
          Color(0xFF141E30),
          Color(0xFF243B55),
          Color(0xFF3A6073),
          Color(0xFF162447),
        ];
      case 'theme-dark':
        return const [
          Color(0xFF0A0A0A),
          Color(0xFF1A1A1A),
          Color(0xFF2D2D2D),
          Color(0xFF1A1A1A),
        ];
      case 'theme-mystic-dark':
        return const [
          Color(0xFF0F0C29),
          Color(0xFF302B63),
          Color(0xFF24243E),
          Color(0xFF0F0C29),
        ];
      case 'theme-ocean':
        return isDark
            ? const [
                Color(0xFF0D1B2A),
                Color(0xFF1B263B),
                Color(0xFF415A77),
                Color(0xFF1D3557),
              ]
            : const [
                Color(0xFFE0F7FA),
                Color(0xFFB2EBF2),
                Color(0xFF80DEEA),
                Color(0xFF4DD0E1),
              ];
      case 'theme-sunset':
        return isDark
            ? const [
                Color(0xFF2C0B1E),
                Color(0xFF4A1525),
                Color(0xFF6B1F38),
                Color(0xFF330A21),
              ]
            : const [
                Color(0xFFFFF3E0),
                Color(0xFFFFCC80),
                Color(0xFFFFAB91),
                Color(0xFFF48FB1),
              ];
      case 'theme-crazy-party':
        return isDark
            ? const [
                Color(0xFF1D0936),
                Color(0xFF3D136B),
                Color(0xFF5B178A),
                Color(0xFF260548),
              ]
            : const [
                Color(0xFFF3E5F5),
                Color(0xFFCE93D8),
                Color(0xFFFF80AB),
                Color(0xFF8C9EFF),
              ];
      case 'theme-pink-glow':
        return const [
          Color(0xFFFFE4E1),
          Color(0xFFFFC0CB),
          Color(0xFFFBC2EB),
          Color(0xFFFF9A9E),
        ];
      default:
        return isDark
            ? const [Color(0xFF1A1430), Color(0xFF241C3E), Color(0xFF302552)]
            : SLTheme.defaultGradient;
    }
  }
}

class _StableShellBackgroundImage extends StatefulWidget {
  const _StableShellBackgroundImage({required this.backgroundUrl});

  final String backgroundUrl;

  @override
  State<_StableShellBackgroundImage> createState() =>
      _StableShellBackgroundImageState();
}

class _StableShellBackgroundImageState
    extends State<_StableShellBackgroundImage> {
  ImageProvider<Object>? _diskCachedProvider;
  ImageProvider<Object>? _networkProvider;
  ImageProvider<Object>? _retainedProvider;
  String _currentUrl = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncProviders();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _StableShellBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundUrl.trim() != widget.backgroundUrl.trim()) {
      _syncProviders();
    }
  }

  Future<void> _syncProviders() async {
    final url = widget.backgroundUrl.trim();
    final retainedProvider = _ready
        ? (_networkProvider ?? _diskCachedProvider ?? _retainedProvider)
        : (_diskCachedProvider ?? _retainedProvider ?? _networkProvider);
    _currentUrl = url;
    _ready = false;
    _retainedProvider = retainedProvider;
    if (url.isEmpty) {
      _networkProvider = null;
      _diskCachedProvider = null;
      _retainedProvider = null;
      if (mounted) setState(() {});
      return;
    }

    final provider = _buildNetworkProvider(url);
    final startupFile = HomeStartupMediaCache.getFile(url);
    _networkProvider = provider;
    _diskCachedProvider = startupFile != null ? FileImage(startupFile) : null;

    if (startupFile != null) {
      return;
    }

    precacheImage(provider, context)
        .then((_) {
          if (!mounted || _currentUrl != url) return;
          setState(() {
            _ready = true;
            _retainedProvider = provider;
          });
        })
        .catchError((error) {
          debugPrint(
            '[SuppressedError] lib/views/home/widgets/home_shell/home_screen_background.dart: $error',
          );
        });

    try {
      final cachedFile = await AppCacheManager.instance.getFileFromCache(url);
      if (!mounted || _currentUrl != url) return;
      final file = cachedFile?.file;
      if (file != null && await file.exists()) {
        setState(() {
          _diskCachedProvider = FileImage(file);
        });
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/widgets/home_shell/home_screen_background.dart: $error',
      );
    }
  }

  ImageProvider<Object> _buildNetworkProvider(String url) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final devicePixelRatio =
        mediaQuery?.devicePixelRatio ?? view?.devicePixelRatio ?? 1.0;
    final logicalWidth =
        mediaQuery?.size.width ??
        ((view?.physicalSize.width ?? 0) / devicePixelRatio);
    final logicalHeight =
        mediaQuery?.size.height ??
        ((view?.physicalSize.height ?? 0) / devicePixelRatio);
    final qualityScale = devicePixelRatio >= 2.5 ? 0.75 : 0.85;
    final cacheWidth = (logicalWidth * devicePixelRatio * qualityScale)
        .round()
        .clamp(600, 1280);
    final cacheHeight = (logicalHeight * devicePixelRatio * qualityScale)
        .round()
        .clamp(960, 1920);

    final provider = CachedNetworkImageProvider(
      url,
      maxWidth: cacheWidth,
      maxHeight: cacheHeight,
    );
    _homeShellBackgroundProviderCache[url] = provider;
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _diskCachedProvider ?? _retainedProvider;
    final current = _networkProvider;
    if (current == null) {
      return const SizedBox.shrink();
    }

    // Chỉ hiển thị 1 image tại 1 thời điểm để tránh GPU composite 2 full-screen
    final showCurrent = _ready || !_hasFallback;
    return Image(
      image: showCurrent ? current : (fallback ?? current),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      isAntiAlias: false,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (!_ready && (wasSynchronouslyLoaded || frame != null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _ready || _networkProvider != current) return;
            setState(() {
              _ready = true;
              _retainedProvider = current;
            });
          });
        }
        return child;
      },
      errorBuilder: (_, __, ___) => fallback != null
          ? Image(
              image: fallback,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          : const SizedBox.shrink(),
    );
  }

  bool get _hasFallback =>
      _diskCachedProvider != null || _retainedProvider != null;
}

class _BackgroundPatternPainter extends CustomPainter {
  final bool isDark;
  const _BackgroundPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(
        alpha: isDark ? 0.03 : 0.025,
      )
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 48.0;

    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }
    for (double x = size.width + size.height; x > -size.height; x -= step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        linePaint,
      );
    }

    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFFD81B60)).withValues(
        alpha: isDark ? 0.04 : 0.035,
      )
      ..style = PaintingStyle.fill;

    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
