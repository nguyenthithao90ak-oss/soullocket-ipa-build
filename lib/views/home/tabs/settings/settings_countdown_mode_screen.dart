part of '../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

class _CountdownModeIndependentScreen extends StatefulWidget {
  const _CountdownModeIndependentScreen({
    required this.currentHouseId,
    required this.isVipActive,
    required this.loveDate,
    required this.birthDate,
    required this.relationshipMode,
    required this.fallbackTopLabel,
    required this.fallbackBottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avatarUrl1,
    required this.avatarUrl2,
  });

  final String? currentHouseId;
  final bool isVipActive;
  final String loveDate;
  final String birthDate;
  final String relationshipMode;
  final String fallbackTopLabel;
  final String fallbackBottomLabel;
  final String nameU1;
  final String nameU2;
  final String avatarUrl1;
  final String avatarUrl2;

  @override
  State<_CountdownModeIndependentScreen> createState() =>
      _CountdownModeIndependentScreenState();
}

class _CountdownModeIndependentScreenState
    extends State<_CountdownModeIndependentScreen> {
  static const String _pendingSpaceAvatarUploadKeyPrefix =
      'countdown_space_avatar_';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      fn();
      return;
    }
    setState(fn);
  }

  static const int _maxSpaces = CountdownSpaceService.maxSpacesPerHouse;

  static const List<MapEntry<String, String>> _themeOptions = [
    MapEntry('Tự động theo mùa', 'theme-auto'),
    MapEntry('Sóng hồng', 'theme-pink-glow'),
    MapEntry('Mặc định sáng', 'theme-default'),
    MapEntry('Hoàng hôn', 'theme-sunset'),
    MapEntry('Đại dương', 'theme-ocean'),
    MapEntry('Đêm sâu', 'theme-night'),
    MapEntry('Dark', 'theme-dark'),
    MapEntry('Mystic Dark', 'theme-mystic-dark'),
    MapEntry('Tắt chủ đề', 'off'),
  ];

  static const List<MapEntry<String, String>> _countdownStyleOptions = [
    MapEntry('Mặc định', 'default'),
    MapEntry('Rose Wave', 'rose_wave'),
    MapEntry('Glass', 'glass'),
    MapEntry('Glow', 'glow'),
    MapEntry('Plain', 'plain'),
    MapEntry('Candy', 'candy'),
    MapEntry('Galaxy', 'galaxy'),
    MapEntry('Aurora', 'aurora'),
    MapEntry('Crystal', 'crystal'),
    MapEntry('Fireworks', 'fireworks'),
    MapEntry('Lava', 'lava'),
  ];

  static const Set<String> _premiumCountdownStyleKeys = <String>{
    'galaxy',
    'aurora',
    'crystal',
    'fireworks',
    'lava',
  };

  static bool _isPremiumCountdownStyleKey(String styleKey) {
    return _premiumCountdownStyleKeys.contains(styleKey.trim().toLowerCase());
  }

  static String _safeCountdownStyleKey({
    required String styleKey,
    required bool isVipActive,
    required bool hasAdUnlock,
  }) {
    final normalized = styleKey.trim().toLowerCase();
    final exists =
        _countdownStyleOptions.any((item) => item.value == normalized);
    if (!exists) {
      return 'default';
    }
    if (_isPremiumCountdownStyleKey(normalized) &&
        !isVipActive &&
        !hasAdUnlock) {
      return 'default';
    }
    return normalized;
  }

  static Future<bool> _hasCountdownStyleAdUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry = prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (expiry > now) {
      return true;
    }
    final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
    if (legacyTs <= 0) {
      return false;
    }
    return now - legacyTs < _countdownAdUnlockWindow.inMilliseconds;
  }

  static Future<void> _saveCountdownStyleAdUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(
      'il_countdown_unlock_weekly_expiry_v2',
      now + _countdownAdUnlockWindow.inMilliseconds,
    );
    await prefs.setInt('il_countdown_unlock_ad_ts', now);
    await prefs.setStringList(
      'il_unlocked_countdown_styles',
      _premiumCountdownStyleKeys.toList(growable: false),
    );
  }

  static const List<MapEntry<String, String>> _avatarFrameOptions = [
    MapEntry('Không khung', 'off'),
    MapEntry('Circle', 'circle'),
    MapEntry('Rounded', 'rounded'),
    MapEntry('Squircle', 'squircle'),
    MapEntry('Pearl', 'pearl'),
    MapEntry('Glass', 'glass'),
    MapEntry('PRO', 'vip'),
  ];

  final CountdownSpaceService _countdownSpaceService = CountdownSpaceService();
  final FriendsService _spaceLookupService = FriendsService();
  final StorageService _storageService = StorageService();
  final DatabaseReference _countdownSpaceDbRef =
      FirebaseDatabase.instance.ref();
  StreamSubscription<List<CountdownSpaceRequestInfo>>? _countdownRequestsSub;
  StreamSubscription<List<CountdownSpaceInfo>>? _countdownSpacesSub;
  StreamSubscription<List<CountdownSpaceDeleteRequestInfo>>?
      _countdownDeleteRequestsSub;
  Timer? _countdownDeleteEvaluationTimer;

  bool _singleMode = false;
  DateTime? _anchorDate;
  late String _topLabelText;
  late String _bottomLabelText;
  late String _nameU1;
  late String _nameU2;
  late String _avatarUrl1;
  late String _avatarUrl2;
  late String _themeKey;
  late String _countdownStyleKey;
  late String _centerIconType;
  late String _fontKey;
  late String _avatarFrameKey;
  late bool _transparentMode;
  late double _countdownSizePx;
  late String _customBackgroundUrl;

  List<String> _spaceHouseIds = <String>[];
  Map<String, String> _spaceDisplayNames = <String, String>{};
  final Map<String, _CountdownSpaceSnapshot> _spaceSnapshots =
      <String, _CountdownSpaceSnapshot>{};
  final Map<String, CountdownSpaceRequestInfo> _pendingSpaceRequests =
      <String, CountdownSpaceRequestInfo>{};
  final Map<String, CountdownSpaceRequestInfo> _incomingSpaceRequests =
      <String, CountdownSpaceRequestInfo>{};
  final Map<String, CountdownSpaceInfo> _sharedSpaces =
      <String, CountdownSpaceInfo>{};
  final Map<String, CountdownSpaceDeleteRequestInfo> _deleteSpaceRequests =
      <String, CountdownSpaceDeleteRequestInfo>{};
  final Set<String> _optimisticPendingSpaceHouseIds = <String>{};
  final Set<String> _spaceRequestActionIds = <String>{};
  Set<String> _acceptedSpaceHouseIds = <String>{};
  String? _openedSpaceHouseId;
  bool _isAddingSpace = false;
  bool _spaceChromeVisible = true;
  Set<String> _unlockedCountdownStyleKeys = <String>{};
  String? _uploadingAvatarRole;
  bool _didPromptPendingSpaceAvatarRetry = false;

  @override
  void initState() {
    super.initState();
    _seedDefaults();
    unawaited(_refreshCountdownStyleUnlockState());
    unawaited(_setSystemUiVisible(true));
    unawaited(_loadSpaces());
    _listenCountdownSpaces();
    unawaited(_promptPendingSpaceAvatarRetryIfNeeded());
  }

  @override
  void dispose() {
    unawaited(_setSystemUiVisible(true));
    _countdownRequestsSub?.cancel();
    _countdownSpacesSub?.cancel();
    _countdownDeleteRequestsSub?.cancel();
    _countdownDeleteEvaluationTimer?.cancel();
    super.dispose();
  }

  String get _selfSpaceHouseId {
    final houseId = (widget.currentHouseId ?? '').trim();
    return houseId.isEmpty ? 'local_self' : houseId;
  }

  String get _scopeKey {
    final opened = (_openedSpaceHouseId ?? '').trim();
    if (opened.isNotEmpty) {
      return opened;
    }
    return _selfSpaceHouseId;
  }

  String _prefKey(String key, {String? scope}) =>
      'il_countdown_space_${(scope ?? _scopeKey).trim()}_$key';

  Future<void> _refreshCountdownStyleUnlockState() async {
    final hasUnlock = await _hasCountdownStyleAdUnlock();
    if (!mounted) {
      if (hasUnlock || widget.isVipActive) {
        _unlockedCountdownStyleKeys = _premiumCountdownStyleKeys;
      }
      return;
    }
    _safeSetState(() {
      _unlockedCountdownStyleKeys = hasUnlock || widget.isVipActive
          ? _premiumCountdownStyleKeys
          : <String>{};
    });
  }

  String get _spacesPrefKey =>
      'il_countdown_spaces_${_selfSpaceHouseId.trim()}';
  String get _spaceNamesPrefKey =>
      'il_countdown_space_names_${_selfSpaceHouseId.trim()}';

  Future<void> _setSystemUiVisible(bool visible) {
    return SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _setSpaceChromeVisible(bool visible) async {
    if (_spaceChromeVisible != visible && mounted) {
      setState(() {
        _spaceChromeVisible = visible;
      });
    } else {
      _spaceChromeVisible = visible;
    }
    await _setSystemUiVisible(visible);
  }

  Future<void> _toggleSpaceChromeVisibility() async {
    if (_openedSpaceHouseId == null) {
      return;
    }
    await _setSpaceChromeVisible(!_spaceChromeVisible);
  }

  Future<void> _resetSpaceChromeVisibility() async {
    await _setSpaceChromeVisible(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_openedSpaceHouseId == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildSpacesGrid(context),
      );
    }

    final themeData =
        _CountdownModeThemeData.resolve(_resolveThemeKey(_themeKey));
    final styleData =
        _CountdownModeStyleData.resolve(_countdownStyleKey, _transparentMode);

    return PopScope(
      canPop: _openedSpaceHouseId == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleOpenedSpaceBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () => unawaited(_toggleSpaceChromeVisibility()),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeData.background,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              if (_customBackgroundUrl.trim().isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: themeData.imageOpacity,
                    child: CachedNetworkImage(
                      imageUrl: _customBackgroundUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      fadeInDuration: const Duration(milliseconds: 180),
                      memCacheWidth: 1080,
                      placeholder: (_, __) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeData.orbA.withOpacity(0.12),
                              themeData.orbB.withOpacity(0.16),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: themeData.overlay,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: themeData.isDark ? 0.12 : 0.24,
                    child: SLTheme.meshPattern(),
                  ),
                ),
              ),
              Positioned(
                top: -60,
                right: -40,
                child: _CountdownModeGlowOrb(color: themeData.orbA, size: 220),
              ),
              Positioned(
                left: -40,
                bottom: 60,
                child: _CountdownModeGlowOrb(color: themeData.orbB, size: 180),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rightName =
                        _nameU2.trim().isEmpty ? 'Người ấy' : _nameU2.trim();
                    return Stack(
                      children: [
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: constraints.maxHeight < 720 ? 28 : 36,
                            bottom: constraints.maxHeight < 720 ? 32 : 40,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: (() {
                                    final availableWidth =
                                        (constraints.maxWidth - 44).toDouble();
                                    final safeWidth = availableWidth > 0
                                        ? availableWidth
                                        : 320.0;
                                    return safeWidth
                                        .clamp(320.0, 860.0)
                                        .toDouble();
                                  })(),
                                  minHeight: (() {
                                    final minHeight = constraints.maxHeight -
                                        (constraints.maxHeight < 720
                                            ? 28
                                            : 36) -
                                        (constraints.maxHeight < 720 ? 32 : 40);
                                    return (minHeight > 0 ? minHeight : 0)
                                        .toDouble();
                                  })(),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildHeroCard(
                                      context,
                                      themeData,
                                      styleData,
                                      constraints,
                                    ),
                                    const SizedBox(height: 18),
                                    _CountdownModeAvatarCardStatic(
                                      isSingleMode: _singleMode,
                                      leftName: _nameU1.trim().isEmpty
                                          ? 'Bạn'
                                          : _nameU1.trim(),
                                      rightName: rightName,
                                      leftAvatarUrl: _avatarUrl1,
                                      rightAvatarUrl:
                                          _singleMode ? '' : _avatarUrl2,
                                      avatarFrameKey: _avatarFrameKey,
                                      fontKey: _fontKey,
                                      foreground: themeData.foreground,
                                      isDark: themeData.isDark,
                                      centerIconType: _centerIconType,
                                      onCenterIconChanged: (type) => unawaited(
                                          _updateCenterIconType(type)),
                                      onLeftAvatarTap: () => unawaited(
                                        _changeSpaceAvatar(isLeft: true),
                                      ),
                                      onRightAvatarTap: () => unawaited(
                                        _changeSpaceAvatar(isLeft: false),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 18,
                          right: 18,
                          child: IgnorePointer(
                            ignoring: !_spaceChromeVisible,
                            child: AnimatedOpacity(
                              opacity: _spaceChromeVisible ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Row(
                                children: [
                                  const Spacer(),
                                  _buildActionButton(
                                    icon: Icons.settings_rounded,
                                    foreground: themeData.foreground,
                                    isDark: themeData.isDark,
                                    onTap: _openSettingsSheet,
                                    tooltip:
                                        'Cài đặt không gian riêng cho bạn bè',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
