// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../settings_tab.dart';

class CountdownSpaceScreen extends StatefulWidget {
  const CountdownSpaceScreen({
    super.key,
    this.spaceService,
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
  final CountdownSpaceService? spaceService;
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
  State<CountdownSpaceScreen> createState() =>
      _CountdownModeIndependentScreenState();
}

class _CountdownModeIndependentScreenState extends State<CountdownSpaceScreen> {
  static const String _pendingSpaceAvatarUploadKeyPrefix =
      'countdown_space_avatar_';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
    _spaceRevision.value++;
  }

  static const int _maxSpaces = CountdownSpaceService.maxSpacesPerHouse;

  static List<MapEntry<String, String>> get _themeOptions => [
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
  static List<MapEntry<String, String>> get _countdownStyleOptions => [
    for (final key in KeepsakePalette.newStyleKeys)
      MapEntry(L10nService().translate('keepsake_$key'), key),
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

  static Future<Set<String>> _getUnlockedCountdownStyleKeys() =>
      AdMobService().verifiedCountdownStyles();

  static List<MapEntry<String, String>> get _avatarFrameOptions => [
    for (final key in KeepsakePalette.newStyleKeys)
      MapEntry(L10nService().translate('keepsake_$key'), key),
    MapEntry(L10nService().translate('home_khngkhung_e37077'), 'off'),
    MapEntry(L10nService().translate('p7_frame_circle'), 'circle'),
    MapEntry(L10nService().translate('p7_frame_rounded'), 'rounded'),
    MapEntry(L10nService().translate('p7_frame_squircle'), 'squircle'),
    MapEntry(L10nService().translate('p7_frame_pearl'), 'pearl'),
    MapEntry(L10nService().translate('p7_frame_glass'), 'glass'),
    MapEntry(L10nService().translate('p7_frame_aurora'), 'vip'),
  ];

  late final CountdownSpaceService _countdownSpaceService =
      widget.spaceService ?? CountdownSpaceService();
  late final FriendsService _spaceLookupService = FriendsService();
  late final StorageService _storageService = StorageService();
  late final DatabaseReference _countdownSpaceDbRef = FirebaseDatabase.instance
      .ref();
  StreamSubscription<List<CountdownSpaceRequestInfo>>? _countdownRequestsSub;
  StreamSubscription<List<CountdownSpaceInfo>>? _countdownSpacesSub;
  StreamSubscription<List<CountdownSpaceDeleteRequestInfo>>?
  _countdownDeleteRequestsSub;
  StreamSubscription<Map<String, dynamic>>? _interactiveEventsSub;
  Timer? _countdownDeleteEvaluationTimer;

  final ValueNotifier<int> _spaceRevision = ValueNotifier(0);
  final Set<String> _spaceStreamErrors = {};
  final Map<String, _CountdownSpaceSnapshot> _unsyncedSpaceSnapshots = {};
  Future<void> _spaceSaveQueue = Future<void>.value();
  bool _savingSpace = false;

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
    if (widget.relationshipMode.trim() != 'single' &&
        _selfSpaceHouseId != 'local_self') {
      _interactiveEventsSub = SoulMergeService()
          .watchInteractiveEvents()
          .listen((event) async {
            if (!mounted ||
                event.isEmpty ||
                _openedSpaceHouseId != _selfSpaceHouseId) {
              return;
            }
            final prefs = await SharedPreferences.getInstance();
            final myRole = prefs.getString('il_role') ?? 'user1';
            final sender = event['sender']?.toString();
            if (sender == myRole) return;

            final type = event['type']?.toString() ?? '';
            final emoji =
                event['emoji']?.toString() ??
                event['customData']?['emoji']?.toString() ??
                '❤️';

            if (!mounted || _openedSpaceHouseId != _selfSpaceHouseId) return;
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
    _reactionFlightsNotifier.dispose();
    _spaceRevision.dispose();
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
        backgroundColor: AppearancePanelStyle.canvas,
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

    final rightName = _nameU2.trim().isEmpty
        ? context.tr('home_ngiy_5bab37')
        : _nameU2.trim();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleOpenedSpaceBack();
      },
      child: Scaffold(
        backgroundColor: AppearancePanelStyle.canvas,
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
                    opacity: .22,
                    child: CachedNetworkImage(
                      imageUrl: _customBackgroundUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 900,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          children: [
                            if (_spaceChromeVisible) ...[
                              Row(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.arrow_back_rounded,
                                    foreground: themeData.foreground,
                                    isDark: themeData.isDark,
                                    onTap: () => unawaited(_closeOpenedSpace()),
                                    tooltip: context.tr('p7_back'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _spaceTitle(_scopeKey),
                                      style: SLTheme.quicksand(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: themeData.foreground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildActionButton(
                                    icon: Icons.tune_rounded,
                                    foreground: themeData.foreground,
                                    isDark: themeData.isDark,
                                    onTap: _savingSpace
                                        ? () {}
                                        : _openSettingsSheet,
                                    tooltip: context.tr(
                                      'home_citkhnggia_09f866',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _spaceConnectionStatusLabel(_scopeKey),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  color: themeData.foreground,
                                ),
                              ),
                            ],
                            if (_savingSpace) const LinearProgressIndicator(),
                            if (_unsyncedSpaceSnapshots.containsKey(_scopeKey))
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppearancePanelStyle.paper,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      context.tr('p7_countdown_sync_failed'),
                                      style: SLTheme.quicksand(
                                        color: AppearancePanelStyle.ink,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _savingSpace
                                          ? null
                                          : () => _saveLocalSettings(),
                                      child: Text(context.tr('p7_retry')),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 22),
                            _buildHeroCard(
                              context,
                              themeData,
                              styleData,
                              constraints,
                            ),
                            const SizedBox(height: 24),
                            _CountdownModeAvatarCardStatic(
                              isSingleMode: _singleMode,
                              leftName: _nameU1.trim().isEmpty
                                  ? L10nService().translate('home_bn_1fd75b')
                                  : _nameU1.trim(),
                              rightName: rightName,
                              leftAvatarUrl: _avatarUrl1,
                              rightAvatarUrl: _singleMode ? '' : _avatarUrl2,
                              avatarFrameKey: _avatarFrameKey,
                              fontKey: _fontKey,
                              foreground: themeData.foreground,
                              isDark: themeData.isDark,
                              centerIconType: _centerIconType,
                              onCenterIconChanged: (type) =>
                                  unawaited(_updateCenterIconType(type)),
                              onCenterIconTap: () {
                                final preset =
                                    _countdownModeCenterIconPresetFor(
                                      _centerIconType,
                                    );
                                if (!_singleMode &&
                                    _scopeKey == _selfSpaceHouseId) {
                                  unawaited(
                                    SoulMergeService().sendInteractiveEvent(
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
                              onLeftAvatarTap: () =>
                                  unawaited(_changeSpaceAvatar(isLeft: true)),
                              onRightAvatarTap: () =>
                                  unawaited(_changeSpaceAvatar(isLeft: false)),
                              onRightAvatarChatTap:
                                  (_selfSpaceHouseId == 'local_self' ||
                                      (_scopeKey != _selfSpaceHouseId &&
                                          !_isSharedSpace(_scopeKey)))
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ChatDetailScreen(
                                            myHouseId:
                                                widget.currentHouseId ?? '',
                                            targetHouseId: _scopeKey,
                                            targetName: rightName,
                                            targetAvatar: _avatarUrl2,
                                            isInternal:
                                                _scopeKey == _selfSpaceHouseId,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<List<_CountdownReactionFlight>>(
                    valueListenable: _reactionFlightsNotifier,
                    builder: (context, flights, _) => Stack(
                      children: [
                        for (final flight in flights)
                          Positioned.fill(
                            key: ValueKey('countdown-flight-${flight.id}'),
                            child: ShootingHeartEffect(
                              shootToRight: flight.shootToRight,
                              emoji: flight.emoji,
                              assetPath: flight.assetPath,
                              onComplete: () =>
                                  _removeReactionFlight(flight.id),
                            ),
                          ),
                      ],
                    ),
                  ),
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
    final scope = _scopeKey;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || scope != _scopeKey) return;
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
        ..._reactionFlightsNotifier.value.take(7),
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
