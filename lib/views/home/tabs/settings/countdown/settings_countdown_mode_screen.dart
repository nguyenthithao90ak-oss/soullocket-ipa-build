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
    const MapEntry('Dark', 'theme-dark'),
    const MapEntry('Mystic Dark', 'theme-mystic-dark'),
    MapEntry(L10nService().translate('home_ttch_1676a7'), 'off'),
  ];

  // Keep the most useful styles on top for a cleaner, faster settings flow.
  static final List<MapEntry<String, String>> _countdownStyleOptions = [
    MapEntry(L10nService().translate('countdown_floating_hearts'), 'floating_hearts'),
    MapEntry(L10nService().translate('countdown_glass'), 'glass'),
    MapEntry(L10nService().translate('countdown_default'), 'default'),
    MapEntry(L10nService().translate('countdown_glow'), 'glow'),
    MapEntry(L10nService().translate('countdown_candy'), 'candy'),
    MapEntry(L10nService().translate('countdown_galaxy'), 'galaxy'),
    MapEntry(L10nService().translate('countdown_aurora'), 'aurora'),
    MapEntry(L10nService().translate('countdown_crystal'), 'crystal'),
    MapEntry(L10nService().translate('countdown_fireworks'), 'fireworks'),
    MapEntry(L10nService().translate('countdown_lava'), 'lava'),
  ];

  static const Set<String> _premiumCountdownStyleKeys = <String>{
    'floating_hearts',
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
    final legacyExpiry = prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (legacyExpiry > now) {
      result.addAll(_premiumCountdownStyleKeys);
    } else {
      final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      if (legacyTs > 0) {
        final fallbackExpiry = legacyTs + _countdownAdUnlockWindow.inMilliseconds;
        if (fallbackExpiry > now) {
          result.addAll(_premiumCountdownStyleKeys);
        }
      }
    }
    return result;
  }

  static final List<MapEntry<String, String>> _avatarFrameOptions = [
    MapEntry(L10nService().translate('home_khngkhung_e37077'), 'off'),
    const MapEntry('Circle', 'circle'),
    const MapEntry('Rounded', 'rounded'),
    const MapEntry('Squircle', 'squircle'),
    const MapEntry('Pearl', 'pearl'),
    const MapEntry('Glass', 'glass'),
    const MapEntry('Aurora', 'vip'),
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
  String _fallingEffectType = 'off';

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
      _interactiveEventsSub = SoulMergeService().watchInteractiveEvents().listen((event) async {
        if (!mounted || event.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        final myRole = prefs.getString('il_role') ?? 'user1';
        final sender = event['sender']?.toString();
        if (sender == myRole) return;
        
        final type = event['type']?.toString();
        if (type == 'photo_shot') {
          final size = MediaQuery.of(context).size;
          _heartsKey.currentState?.spawnLocalExplosion(
            Offset(size.width / 2, size.height * 0.74),
            count: 8,
          );
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

  Future<void> _selectFallingEffect() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF252036) : Colors.white;
        final fg = isDark ? Colors.white : const Color(0xFF252036);
        final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];
        
        final options = [
          {'key': 'off', 'label': 'Tắt hiệu ứng', 'icon': Icons.block_rounded},
          {'key': 'hearts', 'label': 'Trái tim bay', 'icon': Icons.favorite_rounded},
          {'key': 'bubbles', 'label': 'Bong bóng khí', 'icon': Icons.bubble_chart_rounded},
          {'key': 'snow', 'label': 'Tuyết rơi lạnh', 'icon': Icons.ac_unit_rounded},
          {'key': 'stars', 'label': 'Sao lấp lánh', 'icon': Icons.star_rounded},
        ];

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn hiệu ứng nền',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hiệu ứng rơi lãng mạn cho không gian đếm',
                style: SLTheme.quicksand(
                  fontSize: 13,
                  color: subtitleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final opt = options[idx];
                    final isSel = _fallingEffectType == opt['key'];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(opt['key'] as String),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: isSel
                          ? const Color(0xFFD81B60).withValues(alpha: 0.08)
                          : Colors.transparent,
                      leading: Icon(
                        opt['icon'] as IconData,
                        color: isSel ? const Color(0xFFD81B60) : fg.withValues(alpha: 0.6),
                      ),
                      title: Text(
                        opt['label'] as String,
                        style: SLTheme.quicksand(
                          fontSize: 14.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w700,
                          color: isSel ? const Color(0xFFD81B60) : fg,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD81B60))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    
    if (selected != null && mounted) {
      _safeSetState(() {
        _fallingEffectType = selected;
      });
      await _saveLocalSettings();
    }
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
                      filterQuality: FilterQuality.medium,
                      fadeInDuration: const Duration(milliseconds: 180),
                      memCacheWidth: 1080,
                      placeholder: (_, __) => DecoratedBox(
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
              if (_fallingEffectType != 'off')
                Positioned.fill(
                  child: IgnorePointer(
                    child: LegacyFallingEffect(
                      type: _fallingEffectType,
                      isDark: themeData.isDark,
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
                        _nameU2.trim().isEmpty ? L10nService().translate('home_ngiy_5bab37') : _nameU2.trim();
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
                                          ? L10nService().translate('home_bn_1fd75b')
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
                                      onCenterIconTap: () {
                                        if (!_singleMode) {
                                          unawaited(SoulMergeService().sendInteractiveEvent(type: 'photo_shot'));
                                        }
                                        final size = MediaQuery.of(context).size;
                                        _heartsKey.currentState?.spawnLocalExplosion(
                                          Offset(size.width / 2, size.height * 0.74),
                                          count: 10,
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
                                              myHouseId: widget.currentHouseId ?? '',
                                              targetHouseId: widget.currentHouseId ?? '',
                                              targetName: rightName,
                                              targetAvatar: _avatarUrl2,
                                              isInternal: true,
                                              currentRole: RoleUtils.currentRoleSync(),
                                              targetRole: RoleUtils.currentRoleSync() == 'user1' ? 'user2' : 'user1',
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
                                    icon: Icons.auto_awesome_rounded,
                                    foreground: themeData.foreground,
                                    isDark: themeData.isDark,
                                    onTap: _selectFallingEffect,
                                    tooltip: 'Chọn hiệu ứng nền',
                                  ),
                                  const SizedBox(width: 10),
                                  _buildActionButton(
                                    icon: Icons.settings_rounded,
                                    foreground: themeData.foreground,
                                    isDark: themeData.isDark,
                                    onTap: _openSettingsSheet,
                                    tooltip:
                                        L10nService().translate('home_citkhnggia_09f866'),
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
                child: TapHeartsOverlay(
                  key: _heartsKey,
                  style: 'basic',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
