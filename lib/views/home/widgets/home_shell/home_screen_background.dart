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

    const usesCustomBackground = false;
    final effectiveIsDark = _usesDarkShell(
      tabIndex,
      isDark,
      usesCustomBackground: usesCustomBackground,
    );
    final gradient = _resolveTabShellGradient(
      tabIndex: tabIndex,
      themeKey: themeKey,
      isDark: effectiveIsDark,
      usesCustomBackground: usesCustomBackground,
    );

    final accent = _HomeScreenState._navItems[tabIndex].activeColor;
    final safeQuality = switch (graphicsQualityKey) {
      'low' => 'low',
      'high' => 'high',
      _ => 'balanced',
    };
    final orbScale = switch (safeQuality) {
      'low' => 0.72,
      'high' => 1.18,
      _ => 1.0,
    };
    final baseOpacity = _resolveOrbOpacity(
      tabIndex: tabIndex,
      quality: safeQuality,
      isDark: effectiveIsDark,
    );
    final primaryOrbColor = _resolvePrimaryOrbColor(tabIndex, accent);
    final secondaryOrbColor = _resolveSecondaryOrbColor(tabIndex);
    final tertiaryOrbColor = _resolveTertiaryOrbColor(tabIndex);

    final showPrimaryOrb = safeQuality != 'low';
    final showSecondaryOrb = safeQuality != 'low';
    final showTertiaryOrb = safeQuality == 'high';
    final primaryAnimate = animateAmbientEffects && safeQuality != 'low';
    final secondaryAnimate = animateAmbientEffects && safeQuality == 'high';

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (showPrimaryOrb)
          Positioned(
            top: safeQuality == 'low' ? -48 : (safeQuality == 'high' ? -96 : -80),
            right: safeQuality == 'low' ? -28 : (safeQuality == 'high' ? -56 : -40),
            child: RepaintBoundary(
              child: _buildGlowOrb(
                primaryOrbColor.withOpacity(
                  safeQuality == 'low'
                      ? (baseOpacity - 0.05).clamp(0.03, 0.10).toDouble()
                      : (safeQuality == 'high'
                          ? (baseOpacity + 0.035).clamp(0.12, 0.30).toDouble()
                          : baseOpacity),
                ),
                (safeQuality == 'low'
                        ? 156
                        : (safeQuality == 'high' ? 254 : 220)) *
                    orbScale,
                animate: primaryAnimate,
              ),
            ),
          ),
        if (showSecondaryOrb)
          Positioned(
            top: safeQuality == 'high' ? 132 : 150,
            left: safeQuality == 'high' ? -82 : -60,
            child: RepaintBoundary(
              child: _buildGlowOrb(
                secondaryOrbColor.withOpacity(
                  (baseOpacity - (safeQuality == 'high' ? -0.005 : 0.04))
                      .clamp(0.05, 0.22)
                      .toDouble(),
                ),
                (safeQuality == 'high' ? 224 : 180) * orbScale,
                animate: secondaryAnimate,
              ),
            ),
          ),
        if (showTertiaryOrb)
          Positioned(
            bottom: -104,
            right: -16,
            child: RepaintBoundary(
              child: _buildGlowOrb(
                tertiaryOrbColor.withOpacity(
                  (baseOpacity + 0.01).clamp(0.08, 0.20).toDouble(),
                ),
                266 * orbScale,
                animate: false,
              ),
            ),
          ),
        if (safeQuality == 'high')
          Positioned(
            top: MediaQuery.of(context).size.height * 0.34,
            right: -42,
            child: RepaintBoundary(
              child: _buildGlowOrb(
                Color.alphaBlend(
                  Colors.white.withOpacity(0.14),
                  primaryOrbColor,
                ).withOpacity(0.10),
                144,
                animate: false,
              ),
            ),
          ),
        if (safeQuality == 'high')
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.045),
                      Colors.transparent,
                      Colors.white.withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
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
    final overlayColors = isDark
        ? [
            Colors.black.withOpacity(0.30),
            Colors.black.withOpacity(0.18),
            Colors.black.withOpacity(0.40),
          ]
        : [
            Colors.white.withOpacity(0.14),
            Colors.white.withOpacity(0.08),
            Colors.black.withOpacity(0.30),
          ];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _resolveShellGradient(themeKey, isDark),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: _StableShellBackgroundImage(backgroundUrl: backgroundUrl),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: overlayColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
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
    switch (tabIndex) {
      case 1:
        return true;
      case 2:
        return false;
      case 3:
        return true;
      case 4:
        return true;
      case 5:
        return false;
      default:
        return isDark;
    }
  }

  List<Color> _resolveTabShellGradient({
    required int tabIndex,
    required String themeKey,
    required bool isDark,
    required bool usesCustomBackground,
  }) {
    return _resolveShellGradient(themeKey, isDark);
  }

  double _resolveOrbOpacity({
    required int tabIndex,
    required String quality,
    required bool isDark,
  }) {
    return switch (quality) {
      'low' => isDark ? 0.10 : 0.14,
      'high' => isDark ? 0.18 : 0.26,
      _ => isDark ? 0.13 : 0.20,
    };
  }

  Color _resolvePrimaryOrbColor(int tabIndex, Color accent) {
    return accent;
  }

  Color _resolveSecondaryOrbColor(int tabIndex) {
    return SLTheme.accentPurple;
  }

  Color _resolveTertiaryOrbColor(int tabIndex) {
    return SLTheme.primaryLight;
  }

  Widget _buildGlowOrb(Color color, double size, {bool animate = false}) {
    if (!animate) {
      return IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color,
                blurRadius: 80,
                spreadRadius: 18,
              ),
            ],
          ),
        ),
      );
    }
    return _BreathingGlowOrb(color: color, size: size);
  }

  List<Color> _resolveShellGradient(String themeKey, bool isDark) {
    if (themeKey == 'off') {
      return isDark
          ? const [
              Color(0xFF121212),
              Color(0xFF1E1E1E),
              Color(0xFF2D2D2D),
            ]
          : const [
              Color(0xFFFDFDFD),
              Color(0xFFF4F7F6),
              Color(0xFFE8ECEF),
            ];
    }

    switch (themeKey) {
      case 'theme-night':
        return const [
          Color(0xFF141E30),
          Color(0xFF243B55),
          Color(0xFF4A00E0),
          Color(0xFF8E2DE2),
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
        return const [
          Color(0xFF4FACFE),
          Color(0xFF00F2FE),
          Color(0xFF43E97B),
          Color(0xFF38F9D7),
        ];
      case 'theme-sunset':
        return const [
          Color(0xFFFF0844),
          Color(0xFFFFB199),
          Color(0xFFFA709A),
          Color(0xFFFEE140),
        ];
      case 'theme-crazy-party':
        return const [
          Color(0xFFFF2400),
          Color(0xFFE8B71D),
          Color(0xFF1DE840),
          Color(0xFF2B1DE8),
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
            ? const [
                Color(0xFF1A1430),
                Color(0xFF241C3E),
                Color(0xFF302552),
              ]
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
    _syncProviders();
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

    try {
      final cachedFile = await DefaultCacheManager().getFileFromCache(url);
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
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final devicePixelRatio = view?.devicePixelRatio ?? 1.0;
    final logicalSize = view?.physicalSize != null
        ? Size(
            view!.physicalSize.width / devicePixelRatio,
            view.physicalSize.height / devicePixelRatio,
          )
        : const Size(430, 932);
    final cacheWidth =
        (logicalSize.width * devicePixelRatio).round().clamp(1080, 2160);
    final cacheHeight =
        (logicalSize.height * devicePixelRatio).round().clamp(1920, 3840);
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

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_ready && fallback != null)
          Image(
            image: fallback,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        Image(
          image: current,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
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
            return AnimatedOpacity(
              opacity:
                  (wasSynchronouslyLoaded || frame != null || _ready) ? 1 : 0,
              duration: Duration.zero,
              child: child,
            );
          },
          errorBuilder: (_, __, ___) => fallback != null
              ? Image(
                  image: fallback,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _BreathingGlowOrb extends StatefulWidget {
  final Color color;
  final double size;

  const _BreathingGlowOrb({required this.color, required this.size});

  @override
  State<_BreathingGlowOrb> createState() => _BreathingGlowOrbState();
}

class _BreathingGlowOrbState extends State<_BreathingGlowOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color,
                      blurRadius: 80,
                      spreadRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
