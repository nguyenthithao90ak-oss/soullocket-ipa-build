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
            'assets/images/default_home_bg.webp',
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

    precacheImage(provider, context).then((_) {
      if (!mounted || _currentUrl != url) return;
      setState(() {
        _ready = true;
        _retainedProvider = provider;
      });
    }).catchError((_) {});

    try {
      final cachedFile = await AppCacheManager.instance.getFileFromCache(url);
      if (!mounted || _currentUrl != url) return;
      final file = cachedFile?.file;
      if (file != null && await file.exists()) {
        setState(() {
          _diskCachedProvider = FileImage(file);
        });
      }
    } catch (_) {}
  }

  ImageProvider<Object> _buildNetworkProvider(String url) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final devicePixelRatio =
        mediaQuery?.devicePixelRatio ?? view?.devicePixelRatio ?? 1.0;
    final logicalWidth = mediaQuery?.size.width ??
        ((view?.physicalSize.width ?? 0) / devicePixelRatio);
    final logicalHeight = mediaQuery?.size.height ??
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
      errorBuilder: (_, _, _) => fallback != null
          ? Image(
              image: fallback,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : const SizedBox.shrink(),
    );
  }

  bool get _hasFallback =>
      _diskCachedProvider != null || _retainedProvider != null;
}

