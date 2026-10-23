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

    // Nền canvas mặc định; ảnh nền riêng vẫn được ưu tiên ở nhánh phía trên.
    return Stack(
      fit: StackFit.expand,
      children: [
        const DefaultHomeBackgroundImage(),
        // Giữ màu tranh sáng dịu, giảm độ sáng khi dùng giao diện tối.
        ColoredBox(
          color: isDark
              ? Colors.black.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
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
          child: _buildHomeBackgroundImage(backgroundUrl),
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
  Widget _buildHomeBackgroundImage(String url) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final prefs = OfflineCacheService.getPrefsSync();
    final houseId = prefs?.getString('il_auth_uid') == uid
        ? (prefs?.getString('il_house_id') ?? '').trim()
        : '';
    final size = HomeImagePolicy.backgroundSize(context: context);
    return HomeBackgroundImage(
      scopeKey: '$uid:$houseId',
      imageKey: '$url:${size.width}:${size.height}',
      loadImage: () async {
        final isR2 = CloudflareR2Service.instance.isR2Url(url);
        if (!isR2) {
          final file = HomeStartupMediaCache.getFile(url);
          final provider = HomeImagePolicy.resized(
            file == null ? CachedNetworkImageProvider(url) : FileImage(file),
            width: size.width,
            height: size.height,
          );
          WallpaperLuminanceService.instance.analyzeProvider(url, provider);
          return provider;
        }
        final resolvedHouse = await AuthHouseContextService.quickHouseId();
        bool isCurrentScope() =>
            mounted &&
            FirebaseAuth.instance.currentUser?.uid == uid &&
            (houseId.isEmpty || resolvedHouse == houseId) &&
            UiPrefs.notifier.value.customBackgroundUrl.trim() == url;
        if (uid.isEmpty || resolvedHouse == null ||
            resolvedHouse.isEmpty || !isCurrentScope()) {
          throw StateError('Home background session changed');
        }
        final cacheKey = 'home_background:$uid:$resolvedHouse:$url';
        final cached = await AppCacheManager.instance.getFileFromCache(cacheKey);
        if (!isCurrentScope()) throw StateError('Home background session changed');
        if (cached != null && await cached.file.exists()) {
          final provider = HomeImagePolicy.resized(FileImage(cached.file),
            width: size.width, height: size.height);
          WallpaperLuminanceService.instance.analyzeProvider(url, provider);
          return provider;
        }
        final signedUrl = await StorageService().resolveHomeBackgroundReadUrl(resolvedHouse, url);
        if (!isCurrentScope() ||
            await AuthHouseContextService.quickHouseId() != resolvedHouse) {
          throw StateError('Home background session changed');
        }
        final provider = HomeImagePolicy.resized(
          CachedNetworkImageProvider(signedUrl,
            cacheKey: cacheKey, cacheManager: AppCacheManager.instance),
          width: size.width, height: size.height,
        );
        WallpaperLuminanceService.instance.analyzeProvider(url, provider);
        return provider;
      },
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
    _diskCachedProvider = startupFile != null
        ? _buildFileProvider(startupFile)
        : null;
    // Render ngay provider mới (hoặc fallback cũ) trong lúc precache/network
    // còn chờ; nếu đợi precache mới rebuild thì nền có thể đứng ở placeholder.
    if (mounted) setState(() {});

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
          _diskCachedProvider = _buildFileProvider(file);
        });
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/widgets/home_shell/home_screen_background.dart: $error',
      );
    }
  }

  ImageProvider<Object> _buildFileProvider(File file) {
    final size = HomeImagePolicy.backgroundSize(context: context);
    return HomeImagePolicy.resized(
      FileImage(file),
      width: size.width,
      height: size.height,
    );
  }

  ImageProvider<Object> _buildNetworkProvider(String url) {
    final size = HomeImagePolicy.backgroundSize(context: context);
    final provider = CachedNetworkImageProvider(
      url,
      maxWidth: size.width,
      maxHeight: size.height,
    );
    _homeShellBackgroundProviderCache[url] = provider;
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _diskCachedProvider ?? _retainedProvider;
    final current = _networkProvider;
    if (current == null) {
      return const ColoredBox(color: Color(0xFFF8EEE3));
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
      errorBuilder: (context, child, error) => fallback != null
          ? Image(
              image: fallback,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, child, error) =>
                  const ColoredBox(color: Color(0xFFF8EEE3)),
            )
          : const ColoredBox(color: Color(0xFFF8EEE3)),
    );
  }

  bool get _hasFallback =>
      _diskCachedProvider != null || _retainedProvider != null;
}
