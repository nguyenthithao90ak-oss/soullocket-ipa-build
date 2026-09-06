// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../settings_tab.dart';

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

  static final List<MapEntry<String, String>> _themeOptions = [
    MapEntry(L10nService().translate('home_tngtheoma_da55a7'), 'theme-auto'),
    MapEntry(L10nService().translate('home_snghng_641d9c'), 'theme-pink-glow'),
    MapEntry(L10nService().translate('home_mcnhsng_41d947'), 'theme-default'),
    MapEntry(L10nService().translate('home_honghn_ab7dad'), 'theme-sunset'),
    MapEntry(L10nService().translate('home_idng_b4a250'), 'theme-ocean'),
    MapEntry(L10nService().translate('home_msu_573436'), 'theme-night'),
    MapEntry(L10nService().translate('p7_theme_dark'), 'theme-dark'),
    MapEntry(
      L10nService().translate('p7_theme_mystic_dark'),
      'theme-mystic-dark',
    ),
    MapEntry(L10nService().translate('home_ttch_1676a7'), 'off'),
  ];

  // Keep the most useful styles on top for a cleaner, faster settings flow.
  static final List<MapEntry<String, String>> _countdownStyleOptions = [
    MapEntry(
      L10nService().translate('countdown_floating_hearts'),
      'floating_hearts',
    ),
    MapEntry(L10nService().translate('countdown_glass'), 'glass'),
    MapEntry(L10nService().translate('countdown_default'), 'default'),
    MapEntry(L10nService().translate('countdown_glow'), 'glow'),
    MapEntry(L10nService().translate('countdown_candy'), 'candy'),
    MapEntry(L10nService().translate('countdown_galaxy'), 'galaxy'),
    MapEntry(L10nService().translate('countdown_aurora'), 'aurora'),
    MapEntry(L10nService().translate('countdown_crystal'), 'crystal'),
    MapEntry(L10nService().translate('countdown_fireworks'), 'fireworks'),
    MapEntry(L10nService().translate('countdown_lava'), 'lava'),
    MapEntry(
      L10nService().translate('countdown_cherry_blossom'),
      'cherry_blossom',
    ),
    MapEntry(
      L10nService().translate('countdown_meteor_shower'),
      'meteor_shower',
    ),
    MapEntry(L10nService().translate('countdown_deep_ocean'), 'deep_ocean'),
    MapEntry(
      L10nService().translate('countdown_golden_sunset'),
      'golden_sunset',
    ),
    MapEntry(L10nService().translate('countdown_neon_pulse'), 'neon_pulse'),
  ];

  static const Set<String> _premiumCountdownStyleKeys = <String>{
    'floating_hearts',
    'glass',
    'glow',
    'candy',
    'galaxy',
    'aurora',
    'crystal',
    'fireworks',
    'lava',
    'cherry_blossom',
    'meteor_shower',
    'deep_ocean',
    'golden_sunset',
    'neon_pulse',
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
    final exists = _countdownStyleOptions.any(
      (item) => item.value == normalized,
    );
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

  static Future<Set<String>> _getUnlockedCountdownStyleKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String>{};
    for (final styleKey in _premiumCountdownStyleKeys) {
      final expiryKey = 'il_countdown_style_unlock_expiry_$styleKey';
      final expiry = prefs.getInt(expiryKey) ?? 0;
      if (expiry > now) {
        result.add(styleKey);
      }
    }
    // Migration: nếu đã có unlock hàng loạt cũ còn hiệu lực thì cộng vào
    final legacyExpiry =
        prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (legacyExpiry > now) {
      result.addAll(_premiumCountdownStyleKeys);
    } else {
      final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      if (legacyTs > 0) {
        final fallbackExpiry =
            legacyTs + _countdownAdUnlockWindow.inMilliseconds;
        if (fallbackExpiry > now) {
          result.addAll(_premiumCountdownStyleKeys);
        }
      }
    }
    return result;
  }

  static final List<MapEntry<String, String>> _avatarFrameOptions = [
    MapEntry(L10nService().translate('home_khngkhung_e37077'), 'off'),
    MapEntry(L10nService().translate('p7_frame_circle'), 'circle'),
    MapEntry(L10nService().translate('p7_frame_rounded'), 'rounded'),
    MapEntry(L10nService().translate('p7_frame_squircle'), 'squircle'),
    MapEntry(L10nService().translate('p7_frame_pearl'), 'pearl'),
    MapEntry(L10nService().translate('p7_frame_glass'), 'glass'),
    MapEntry(L10nService().translate('p7_frame_aurora'), 'vip'),
  ];

  final CountdownSpaceService _countdownSpaceService = CountdownSpaceService();
  final FriendsService _spaceLookupService = FriendsService();
  final StorageService _storageService = StorageService();
  final DatabaseReference _countdownSpaceDbRef = FirebaseDatabase.instance
      .ref();
  StreamSubscription<List<CountdownSpaceRequestInfo>>? _countdownRequestsSub;
  StreamSubscription<List<CountdownSpaceInfo>>? _countdownSpacesSub;
  StreamSubscription<List<CountdownSpaceDeleteRequestInfo>>?
  _countdownDeleteRequestsSub;
  StreamSubscription<Map<String, dynamic>>? _interactiveEventsSub;
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
  final GlobalKey<TapHeartsOverlayState> _heartsKey =
      GlobalKey<TapHeartsOverlayState>();
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
    if (widget.relationshipMode.trim() != 'single') {
      _interactiveEventsSub = SoulMergeService()
          .watchInteractiveEvents()
          .listen((event) async {
            if (!mounted || event.isEmpty) return;
            final prefs = await SharedPreferences.getInstance();
            final myRole = prefs.getString('il_role') ?? 'user1';
            final sender = event['sender']?.toString();
            if (sender == myRole) return;

            final type = event['type']?.toString() ?? '';
            final emoji =
                event['emoji']?.toString() ??
                event['customData']?['emoji']?.toString() ??
                '❤️';

            if (!mounted) return;
            if (type == 'photo_shot') {
              final size = MediaQuery.sizeOf(context);
              _heartsKey.currentState?.spawnLocalExplosion(
                Offset(size.width / 2, size.height * 0.74),
                count: 8,
              );
            } else {
              final exists = _kCountdownModeCenterIconPresets.any(
                (p) => p.type == type,
              );
              if (exists) {
                _sendReactionFlight(type, emoji, isIncoming: true);
              }
            }
          });
    }
    unawaited(_promptPendingSpaceAvatarRetryIfNeeded());
  }

  @override
  void dispose() {
    unawaited(_setSystemUiVisible(true));
    _countdownRequestsSub?.cancel();
    _countdownSpacesSub?.cancel();
    _countdownDeleteRequestsSub?.cancel();
    _interactiveEventsSub?.cancel();
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
    final unlocked = widget.isVipActive
        ? _premiumCountdownStyleKeys
        : await _getUnlockedCountdownStyleKeys();
    if (!mounted) {
      _unlockedCountdownStyleKeys = unlocked;
      return;
    }
    _safeSetState(() {
      _unlockedCountdownStyleKeys = unlocked;
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

    final themeData = _CountdownModeThemeData.resolve(
      _resolveThemeKey(_themeKey),
    );
    final styleData = _CountdownModeStyleData.resolve(
      _countdownStyleKey,
      _transparentMode,
    );

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
                      filterQuality: FilterQuality.medium,
                      fadeInDuration: const Duration(milliseconds: 180),
                      maxWidthDiskCache: 1080,
                      memCacheWidth: 400,
                      placeholder: (_, _) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeData.orbA.withValues(alpha: 0.12),
                              themeData.orbB.withValues(alpha: 0.16),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
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
                    final rightName = _nameU2.trim().isEmpty
                        ? L10nService().translate('home_ngiy_5bab37')
                        : _nameU2.trim();
                    return Stack(
                      children: [
                        SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
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
                                    final minHeight =
                                        constraints.maxHeight -
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
                                          ? L10nService().translate(
                                              'home_bn_1fd75b',
                                            )
                                          : _nameU1.trim(),
                                      rightName: rightName,
                                      leftAvatarUrl: _avatarUrl1,
                                      rightAvatarUrl: _singleMode
                                          ? ''
                                          : _avatarUrl2,
                                      avatarFrameKey: _avatarFrameKey,
                                      fontKey: _fontKey,
                                      foreground: themeData.foreground,
                                      isDark: themeData.isDark,
                                      centerIconType: _centerIconType,
                                      onCenterIconChanged: (type) => unawaited(
                                        _updateCenterIconType(type),
                                      ),
                                      onCenterIconTap: () {
                                        final preset =
                                            _countdownModeCenterIconPresetFor(
                                              _centerIconType,
                                            );
                                        if (!_singleMode) {
                                          unawaited(
                                            SoulMergeService()
                                                .sendInteractiveEvent(
                                                  type: preset.type,
                                                ),
                                          );
                                        }
                                        _sendReactionFlight(
                                          preset.type,
                                          preset.emoji,
                                          isIncoming: false,
                                        );
                                        HapticFeedback.mediumImpact();
                                      },
                                      onLeftAvatarTap: () => unawaited(
                                        _changeSpaceAvatar(isLeft: true),
                                      ),
                                      onRightAvatarTap: () => unawaited(
                                        _changeSpaceAvatar(isLeft: false),
                                      ),
                                      onRightAvatarChatTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatDetailScreen(
                                              myHouseId:
                                                  widget.currentHouseId ?? '',
                                              targetHouseId:
                                                  widget.currentHouseId ?? '',
                                              targetName: rightName,
                                              targetAvatar: _avatarUrl2,
                                              isInternal: true,
                                              currentRole:
                                                  RoleUtils.currentRoleSync(),
                                              targetRole:
                                                  RoleUtils.currentRoleSync() ==
                                                      'user1'
                                                  ? 'user2'
                                                  : 'user1',
                                            ),
                                          ),
                                        );
                                      },
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
                                    tooltip: L10nService().translate(
                                      'home_citkhnggia_09f866',
                                    ),
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
              Positioned.fill(
                child: ValueListenableBuilder<List<_CountdownReactionFlight>>(
                  valueListenable: _reactionFlightsNotifier,
                  builder: (context, flights, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final flight in flights)
                          Positioned.fill(
                            key: ValueKey('countdown-flight-${flight.id}'),
                            child: IgnorePointer(
                              child: ShootingHeartEffect(
                                shootToRight: flight.shootToRight,
                                emoji: flight.emoji,
                                assetPath: flight.assetPath,
                                onComplete: () =>
                                    _removeReactionFlight(flight.id),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: TapHeartsOverlay(key: _heartsKey, style: 'basic'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final ValueNotifier<List<_CountdownReactionFlight>> _reactionFlightsNotifier =
      ValueNotifier<List<_CountdownReactionFlight>>([]);

  void _sendReactionFlight(
    String type,
    String emoji, {
    required bool isIncoming,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final myRole = prefs.getString('il_role') ?? 'user1';
    final bool shootToRight = isIncoming
        ? (myRole == 'user2')
        : (myRole == 'user1');

    String? assetPath;
    for (final preset in _kCountdownModeCenterIconPresets) {
      if (preset.type == type) {
        assetPath = preset.assetPath;
        break;
      }
    }

    final flight = _CountdownReactionFlight(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      shootToRight: shootToRight,
      emoji: emoji,
      assetPath: assetPath,
    );

    _safeSetState(() {
      _reactionFlightsNotifier.value = [
        ..._reactionFlightsNotifier.value,
        flight,
      ];
    });
  }

  void _removeReactionFlight(String id) {
    if (!mounted) return;
    _safeSetState(() {
      _reactionFlightsNotifier.value = _reactionFlightsNotifier.value
          .where((f) => f.id != id)
          .toList();
    });
  }
}

class _CountdownReactionFlight {
  final String id;
  final bool shootToRight;
  final String emoji;
  final String? assetPath;

  _CountdownReactionFlight({
    required this.id,
    required this.shootToRight,
    required this.emoji,
    this.assetPath,
  });
}
