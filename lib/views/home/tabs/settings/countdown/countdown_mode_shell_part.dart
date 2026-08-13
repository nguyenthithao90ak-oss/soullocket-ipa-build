// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../settings_tab.dart';

class _SettingsCountdownModeScreen extends StatelessWidget {
  _SettingsCountdownModeScreen({
    required this.currentHouseId,
    required this.loveDate,
    required this.birthDate,
    required this.relationshipMode,
    required this.fallbackTopLabel,
    required this.fallbackBottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avatarUrl1,
    required this.avatarUrl2,
    required this.onOpenAppearanceSettings,
  });

  final GlobalKey<TapHeartsOverlayState> _heartsOverlayKey =
      GlobalKey<TapHeartsOverlayState>();
  final String? currentHouseId;
  final String loveDate;
  final String birthDate;
  final String relationshipMode;
  final String fallbackTopLabel;
  final String fallbackBottomLabel;
  final String nameU1;
  final String nameU2;
  final String avatarUrl1;
  final String avatarUrl2;
  final Future<void> Function(BuildContext context) onOpenAppearanceSettings;

  bool get _isSingleMode => relationshipMode.trim() == 'single';

  DateTime? _resolveAnchorDate() {
    final raw = _isSingleMode ? birthDate : loveDate;
    final primary = DateInputUtils.parse(raw);
    if (primary != null) return primary;
    return DateInputUtils.parse(_isSingleMode ? loveDate : birthDate);
  }

  int _daysSince(DateTime startDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = DateTime(startDate.year, startDate.month, startDate.day);
    final days = today.difference(normalized).inDays;
    return days < 0 ? 0 : days;
  }

  String _limitLabel(String value, String fallback) {
    final resolved = value.trim().isEmpty ? fallback : value.trim();
    return resolved.length > 22 ? resolved.substring(0, 22) : resolved;
  }

  String _topLabel(UiPrefsState uiState) {
    if (_isSingleMode) {
      return _limitLabel(uiState.countdownTopLabel,
          L10nService().translate('home_tuicati_5c654c'));
    }
    return _limitLabel(
      uiState.countdownTopLabel,
      _limitLabel(
          fallbackTopLabel, L10nService().translate('home_bnnhau_d90054')),
    );
  }

  String _bottomLabel(UiPrefsState uiState) {
    if (_isSingleMode) {
      return _limitLabel(uiState.countdownBottomLabel,
          L10nService().translate('home_ngytui_22bed4'));
    }
    return _limitLabel(
      uiState.countdownBottomLabel,
      _limitLabel(
          fallbackBottomLabel, L10nService().translate('home_ngy_48e4b0')),
    );
  }

  String _resolveThemeKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isNotEmpty && key != 'theme-auto') return key;
    final now = DateTime.now();
    if (now.hour >= 19 || now.hour < 5) return 'theme-night';
    switch (now.month) {
      case 6:
      case 7:
      case 8:
        return 'theme-ocean';
      case 9:
      case 10:
      case 11:
        return 'theme-sunset';
      default:
        return 'theme-pink-glow';
    }
  }

  double _circleSize(
    BoxConstraints constraints,
    UiPrefsState uiState, {
    required bool showAvatarCard,
  }) {
    final shortest = constraints.biggest.shortestSide;
    final widthBasedMax = shortest >= 820
        ? 470.0
        : shortest >= 660
            ? 420.0
            : shortest >= 520
                ? 380.0
                : 326.0;
    final reservedHeight = showAvatarCard ? 332.0 : 200.0;
    final heightBasedMax =
        (constraints.maxHeight - reservedHeight).clamp(220.0, widthBasedMax);
    final maxSize =
        widthBasedMax < heightBasedMax ? widthBasedMax : heightBasedMax;
    final baseSize = uiState.countdownSizePx + (showAvatarCard ? 8 : 32);
    return baseSize.clamp(220.0, maxSize).roundToDouble();
  }

  String _caption(BuildContext context, DateTime? anchorDate) {
    if (anchorDate == null) {
      return L10nService().translate('countdown_mode_no_date_desc');
    }
    return L10nService().translate('countdown_mode_since').replaceFirst(
          '{date}',
          DateInputUtils.formatDisplayDate(anchorDate),
        );
  }

  Future<void> _handleAction(
    BuildContext context,
    _CountdownModeMenuAction action,
  ) async {
    switch (action) {
      case _CountdownModeMenuAction.appearance:
        await onOpenAppearanceSettings(context);
        break;
      case _CountdownModeMenuAction.exit:
        Navigator.of(context).pop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      builder: (context, uiState, _) {
        final themeData = _CountdownModeThemeData.resolve(
          _resolveThemeKey(uiState.themeKey),
        );
        final styleData = _CountdownModeStyleData.resolve(
          uiState.countdownStyleKey,
          uiState.transparentMode,
        );
        final anchorDate = _resolveAnchorDate();
        final value =
            anchorDate == null ? '--' : _daysSince(anchorDate).toString();
        const showAvatarCard = true;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: TapHeartsOverlay(
                    key: _heartsOverlayKey,
                    style: uiState.countdownStyleKey,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeData.background,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              if (uiState.customBackgroundUrl.trim().isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: themeData.imageOpacity,
                    child: CachedNetworkImage(
                      imageUrl: uiState.customBackgroundUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
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
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final circleSize = _circleSize(
                      constraints,
                      uiState,
                      showAvatarCard: showAvatarCard,
                    );
                    final topPadding =
                        constraints.maxHeight < 720 ? 86.0 : 104.0;
                    final bottomPadding =
                        constraints.maxHeight < 720 ? 20.0 : 28.0;
                    return Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 18,
                          child: PopupMenuButton<_CountdownModeMenuAction>(
                            tooltip: L10nService().translate('settings'),
                            color: Colors.white,
                            surfaceTintColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            onSelected: (action) {
                              unawaited(_handleAction(context, action));
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _CountdownModeMenuAction.appearance,
                                child: _CountdownModeMenuRow(
                                  icon: Icons.palette_outlined,
                                  label: L10nService()
                                      .translate('countdown_mode_appearance'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _CountdownModeMenuAction.exit,
                                child: _CountdownModeMenuRow(
                                  icon: Icons.close_rounded,
                                  label: L10nService()
                                      .translate('countdown_mode_exit'),
                                ),
                              ),
                            ],
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                    alpha: themeData.isDark ? 0.14 : 0.80),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                      alpha: themeData.isDark ? 0.24 : 0.92),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.settings_rounded,
                                color: themeData.foreground,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              topPadding,
                              24,
                              bottomPadding,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight -
                                    topPadding -
                                    bottomPadding,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: circleSize,
                                        height: circleSize,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            _CountdownModeCircle(
                                              size: circleSize,
                                              value: value,
                                              topLabel: _topLabel(uiState),
                                              bottomLabel:
                                                  _bottomLabel(uiState),
                                              styleData: styleData,
                                              fontKey: uiState.fontKey,
                                              styleKey:
                                                  uiState.countdownStyleKey,
                                              countdownShapeKey:
                                                  uiState.countdownShapeKey,
                                              transparentMode:
                                                  uiState.transparentMode,
                                              enableMotion: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        _caption(context, anchorDate),
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          uiState.fontKey,
                                          color:
                                              themeData.foreground.withValues(
                                            alpha:
                                                themeData.isDark ? 0.82 : 0.72,
                                          ),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (showAvatarCard) ...[
                                        const SizedBox(height: 24),
                                        _CountdownModeAvatarCard(
                                          isSingleMode: _isSingleMode,
                                          leftName: nameU1.trim().isEmpty
                                              ? L10nService()
                                                  .translate('home_bn_1fd75b')
                                              : nameU1.trim(),
                                          rightName: _isSingleMode
                                              ? L10nService()
                                                  .translate('home_ngiy_5bab37')
                                              : (nameU2.trim().isEmpty
                                                  ? L10nService().translate(
                                                      'home_ngiy_5bab37')
                                                  : nameU2.trim()),
                                          leftAvatarUrl: avatarUrl1,
                                          rightAvatarUrl:
                                              _isSingleMode ? '' : avatarUrl2,
                                          avatarFrameKey:
                                              uiState.avatarFrameKey,
                                          fontKey: uiState.fontKey,
                                          foreground: themeData.foreground,
                                          isDark: themeData.isDark,
                                          currentHouseId: currentHouseId,
                                          onCenterIconTap: () {
                                            if (!_isSingleMode) {
                                              unawaited(SoulMergeService()
                                                  .sendInteractiveEvent(
                                                      type: 'photo_shot'));
                                            }
                                            final size =
                                                MediaQuery.sizeOf(context);
                                            final randomPaths = [
                                              'assets/images/interaction_stickers/custom/numbered/sticker_001.webp',
                                              'assets/images/interaction_stickers/custom/numbered/sticker_002.webp',
                                              'assets/images/interaction_stickers/custom/numbered/sticker_003.webp',
                                            ];
                                            final assetPath = randomPaths[
                                                DateTime.now().millisecondsSinceEpoch %
                                                    randomPaths.length];
                                            _heartsOverlayKey.currentState
                                                ?.spawnFlyingStickers(
                                              Offset(size.width / 2, size.height * 0.42),
                                              Offset(size.width / 2, size.height * 0.74),
                                              assetPath,
                                              count: 3,
                                            );
                                            HapticFeedback.mediumImpact();
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
        );
      },
    );
  }
}

class _CountdownModeAvatarCard extends StatefulWidget {
  const _CountdownModeAvatarCard({
    required this.isSingleMode,
    required this.leftName,
    required this.rightName,
    required this.leftAvatarUrl,
    required this.rightAvatarUrl,
    required this.avatarFrameKey,
    required this.fontKey,
    required this.foreground,
    required this.isDark,
    this.currentHouseId,
    this.onCenterIconTap,
  });

  final bool isSingleMode;
  final String leftName;
  final String rightName;
  final String leftAvatarUrl;
  final String rightAvatarUrl;
  final String avatarFrameKey;
  final String fontKey;
  final Color foreground;
  final bool isDark;
  final String? currentHouseId;
  final VoidCallback? onCenterIconTap;

  @override
  State<_CountdownModeAvatarCard> createState() =>
      _CountdownModeAvatarCardState();
}

class _CountdownModeAvatarCardState extends State<_CountdownModeAvatarCard> {
  final FriendsService _friendsService = FriendsService();
  final HouseSettingsService _houseSettingsService = HouseSettingsService();
  final HouseService _houseService = HouseService();

  _CountdownModeFriendTarget? _selectedFriend;
  bool _isSelectingFriend = false;
  String _centerIconType = 'heart';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCenterIconType());
  }

  Future<void> _loadCenterIconType() async {
    final houseId = widget.currentHouseId?.trim() ?? '';
    if (houseId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'il_countdown_mode_center_icon_type_$houseId';
    final saved = prefs.getString(key) ?? 'heart';
    if (mounted) {
      setState(() {
        _centerIconType = saved;
      });
    }
  }

  String get _displayRightName {
    final selected = _selectedFriend;
    if (selected != null) {
      return selected.displayName;
    }
    return widget.rightName.trim().isEmpty
        ? L10nService().translate('home_chnbn_ba8971')
        : widget.rightName;
  }

  String get _displayRightAvatarUrl {
    final selected = _selectedFriend;
    if (selected != null) {
      return selected.avatarUrl;
    }
    return widget.rightAvatarUrl;
  }

  bool get _showPlaceholder {
    if (_selectedFriend != null) {
      return false;
    }
    return widget.rightAvatarUrl.trim().isEmpty;
  }

  Future<void> _pickFriendSpace() async {
    if (_isSelectingFriend) {
      return;
    }

    setState(() {
      _isSelectingFriend = true;
    });

    try {
      final picked = await _showFriendPicker();
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _selectedFriend = picked;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingFriend = false;
        });
      }
    }
  }

  Future<void> _openSelectedSpace() async {
    final selected = _selectedFriend;
    if (selected == null) {
      await _pickFriendSpace();
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorProfileScreen(targetHouseId: selected.houseId),
      ),
    );
  }

  Future<_CountdownModeFriendTarget?> _showFriendPicker() async {
    final currentHouseId =
        (await _houseService.getCurrentHouseId())?.trim() ?? '';

    if (currentHouseId.isEmpty) {
      _showHint(L10nService().translate('home_chaxcnhcnh_04b381'));
      return null;
    }

    if (!mounted) {
      return null;
    }

    final friendTargetsFuture = _loadFriendTargets(currentHouseId);

    return showModalBottomSheet<_CountdownModeFriendTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FutureBuilder<List<_CountdownModeFriendTarget>>(
          future: friendTargetsFuture,
          builder: (context, snapshot) {
            final bool loading =
                snapshot.connectionState == ConnectionState.waiting;
            final List<_CountdownModeFriendTarget> friends =
                snapshot.data ?? const <_CountdownModeFriendTarget>[];

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF101A2B),
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                L10nService()
                                    .translate('home_chnkhnggia_68d5e3'),
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          L10nService().translate('home_chnmtngibn_13721c'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        else if (friends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              L10nService().translate('home_bnchacbnbg_34d6ac'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                height: 1.45,
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: friends.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final friend = friends[index];
                                return _CountdownModeFriendTile(
                                  friend: friend,
                                  avatarFrameKey: widget.avatarFrameKey,
                                  fontKey: widget.fontKey,
                                  onTap: () =>
                                      Navigator.of(sheetContext).pop(friend),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_CountdownModeFriendTarget>> _loadFriendTargets(
    String currentHouseId,
  ) async {
    final friendIds = await _friendsService.streamFriends(currentHouseId).first;
    if (friendIds.isEmpty) {
      return const <_CountdownModeFriendTarget>[];
    }

    final settingsList = await Future.wait<HouseSettings?>(
      friendIds.map(
        (houseId) async {
          try {
            return await _houseSettingsService.fetchSettings(houseId);
          } catch (_) {
            return null;
          }
        },
      ),
    );

    final targets = <_CountdownModeFriendTarget>[];
    for (var index = 0; index < friendIds.length; index++) {
      final HouseSettings? settings = settingsList[index];
      if (settings == null) {
        continue;
      }

      final displayName = settings.houseName.trim().isNotEmpty
          ? settings.houseName.trim()
          : (settings.nameU1.trim().isNotEmpty
              ? settings.nameU1.trim()
              : friendIds[index]);
      final avatarUrl = settings.houseAvatar.trim().isNotEmpty
          ? settings.houseAvatar.trim()
          : settings.avtUser1.trim();
      final subtitle = settings.isCouple
          ? L10nService().translate('home_khnggiani_534bb6')
          : L10nService().translate('home_khnggiancn_36c9f9');

      targets.add(
        _CountdownModeFriendTarget(
          houseId: friendIds[index],
          displayName: displayName,
          avatarUrl: avatarUrl,
          subtitle: subtitle,
        ),
      );
    }

    targets.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return targets;
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.hub_rounded,
              size: 18,
              color: widget.foreground
                  .withValues(alpha: widget.isDark ? 0.90 : 0.72),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                L10nService().translate('home_ghpkhnggia_ecd541'),
                style: SLTheme.textStyleForKey(
                  widget.fontKey,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: widget.foreground,
                ),
              ),
            ),
            if (_selectedFriend != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4BA7FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF4BA7FF).withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  L10nService().translate('home_chn_59a9e8'),
                  style: SLTheme.textStyleForKey(
                    widget.fontKey,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4BA7FF),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _CountdownModeAvatarCardStatic(
          isSingleMode: _showPlaceholder,
          leftName: widget.leftName,
          rightName: _displayRightName,
          leftAvatarUrl: widget.leftAvatarUrl,
          rightAvatarUrl: _displayRightAvatarUrl,
          avatarFrameKey: widget.avatarFrameKey,
          fontKey: widget.fontKey,
          foreground: widget.foreground,
          isDark: widget.isDark,
          centerIconType: _centerIconType,
          onCenterIconChanged: (type) async {
            setState(() {
              _centerIconType = type;
            });
            final prefs = await SharedPreferences.getInstance();
            final houseId = widget.currentHouseId?.trim() ?? '';
            if (houseId.isNotEmpty) {
              await prefs.setString(
                  'il_countdown_mode_center_icon_type_$houseId', type);
            }
          },
          onCenterIconTap: widget.onCenterIconTap,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSelectingFriend ? null : _pickFriendSpace,
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.foreground,
                  side: BorderSide(
                    color: Colors.white.withValues(
                      alpha: widget.isDark ? 0.16 : 0.86,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSelectingFriend
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_search_rounded, size: 18),
                label: Text(
                  _selectedFriend == null
                      ? L10nService().translate('home_chnngi_34ef59')
                      : L10nService().translate('home_ingi_3a22c1'),
                  style: SLTheme.textStyleForKey(
                    widget.fontKey,
                    fontWeight: FontWeight.w900,
                    color: widget.foreground,
                  ),
                ),
              ),
            ),
            if (_selectedFriend != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openSelectedSpace,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.north_east_rounded, size: 18),
                  label: Text(
                    L10nService().translate('home_vokhnggian_c03ae2'),
                    style: SLTheme.textStyleForKey(
                      widget.fontKey,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _selectedFriend == null
              ? L10nService().translate('home_khungbnphi_61a4e8')
              : 'Đã ghép với ${_selectedFriend!.displayName}. Bạn có thể đổi người hoặc vào ngay không gian của họ.',
          textAlign: TextAlign.center,
          style: SLTheme.textStyleForKey(
            widget.fontKey,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: widget.foreground.withValues(
              alpha: widget.isDark ? 0.72 : 0.62,
            ),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
