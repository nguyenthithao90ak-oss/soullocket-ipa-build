part of '../../main_home_tab.dart';
// ignore_for_file: unused_element

extension _MainHomeToolSlotSection on _MainHomeTabState {
  String _homeToolRelationshipMode() {
    final liveMode =
        _houseSettings?['relationshipMode']?.toString().trim().toLowerCase();
    if (liveMode != null && (liveMode == 'couple' || liveMode == 'single')) {
      return liveMode;
    }

    final cachedMode =
        (OfflineCacheService.getPrefsSync()?.getString('il_rel_mode') ?? '')
            .trim()
            .toLowerCase();
    return cachedMode == 'couple' ? 'couple' : 'single';
  }

  List<UtilityApp> _homeToolApps() {
    final apps = UtilityService.appsForMode(_homeToolRelationshipMode());
    if (apps.length < 2) {
      return apps.toList(growable: false);
    }

    final customOrder =
        OfflineCacheService.getPrefsSync()?.getStringList('il_utility_order') ??
            const <String>[];
    final orderIds =
        customOrder.isNotEmpty ? customOrder : utilitiesHubDefaultOrder;
    final orderMap = <String, int>{
      for (var index = 0; index < orderIds.length; index++)
        orderIds[index]: index,
    };

    final sorted = [...apps];
    sorted.sort((a, b) {
      final indexA = orderMap[a.id] ?? 999;
      final indexB = orderMap[b.id] ?? 999;
      return indexA.compareTo(indexB);
    });
    return sorted.toList(growable: false);
  }

  String _homeToolSelectionPrefKey(String houseId) {
    final normalizedHouseId = houseId.trim();
    final normalizedUid = (_auth.currentUser?.uid ?? 'guest').trim();
    return 'il_home_tool_slot_${normalizedUid.isEmpty ? 'guest' : normalizedUid}_${normalizedHouseId.isEmpty ? 'local' : normalizedHouseId}';
  }

  String? _normalizeHomeToolId(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final app in UtilityService.allApps) {
      if (app.id == normalized &&
          UtilityService.isUtilityAllowed(
            normalized,
            _homeToolRelationshipMode(),
          )) {
        return normalized;
      }
    }
    return null;
  }

  Future<void> _loadHomeToolSelection({required String houseId}) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      if (!mounted) {
        _selectedHomeToolId = null;
        return;
      }
      if (_selectedHomeToolId == null) return;
      _safeSetState(() => _selectedHomeToolId = null);
      return;
    }

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final stored = _normalizeHomeToolId(
      prefs.getString(_homeToolSelectionPrefKey(normalizedHouseId)),
    );
    if (!mounted) {
      _selectedHomeToolId = stored;
      return;
    }
    if (_selectedHomeToolId == stored) {
      return;
    }
    _safeSetState(() => _selectedHomeToolId = stored);
  }

  Future<void> _persistHomeToolSelection(String? toolId) async {
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _homeToolSelectionPrefKey(houseId);
    final normalized = _normalizeHomeToolId(toolId);
    if (normalized == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, normalized);
  }

  Future<void> _setHomeToolSelection(String? toolId) async {
    final normalized = _normalizeHomeToolId(toolId);
    if (_selectedHomeToolId != normalized) {
      if (mounted) {
        _safeSetState(() => _selectedHomeToolId = normalized);
      } else {
        _selectedHomeToolId = normalized;
      }
    }
    await _persistHomeToolSelection(normalized);
  }

  UtilityApp? _selectedHomeToolApp() {
    final selectedId = _normalizeHomeToolId(_selectedHomeToolId);
    if (selectedId == null) {
      return null;
    }
    for (final app in _homeToolApps()) {
      if (app.id == selectedId) {
        return app;
      }
    }
    return null;
  }

  Future<void> _showHomeToolPicker() async {
    final apps = _homeToolApps();
    if (apps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('home_hinchactin_ec5a16')),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: _HomeToolPickerSheet(
          apps: apps,
          selectedId: _selectedHomeToolId,
        ),
      ),
    );

    if (selected == null) {
      return;
    }
    await _setHomeToolSelection(selected);
  }

  double _homeToolPanelHeight(String toolId) {
    final media = MediaQuery.of(context);
    final viewportHeight = media.size.height - media.padding.top;
    return viewportHeight.clamp(620.0, 980.0);
  }

  Widget? _buildEmbeddedHomeTool(String toolId) {
    final houseId = (_houseId ?? '').trim();

    switch (toolId) {
      case 'store':
        return !kIsWeb && Platform.isIOS ? null : const RewardStoreScreen();
      case 'calculator':
        return const CalculatorScreen();
    }

    if (houseId.isEmpty) {
      return null;
    }

    final myName = _resolveMyName();
    switch (toolId) {
      case 'bucket':
        return BucketListScreen(houseId: houseId, myName: myName);
      case 'note':
        return SharedNotesScreen(houseId: houseId, myName: myName);
      case 'friendly_chat':
        return FriendlyChatScreen(
          houseId: houseId,
          myName: myName,
          embedded: true,
        );
      case 'finance':
        return FinanceScreen(houseId: houseId, myName: myName);
      case 'wish':
        return WishlistScreen(houseId: houseId, myName: myName);
      case 'habit':
        return HabitScreen(houseId: houseId, myName: myName);
      case 'drawing':
        return DrawingStudioScreen(houseId: houseId, myName: myName);
      case 'voice':
        return VoiceScreen(
          houseId: houseId,
          myName: myName,
          embedded: true,
        );
      case 'calendar':
        return CalendarScreen(houseId: houseId, myName: myName);
      case 'capsule':
        return CapsuleScreen(houseId: houseId, myName: myName);
      case 'cinema':
        return CinemaScreen(houseId: houseId, myName: myName);
      case 'wheel':
        return WheelScreen(houseId: houseId);
      case 'vault':
        if (!kIsWeb && Platform.isIOS) {
          return null;
        }
        return UiPrefs.notifier.value.vaultHomeEnabled
            ? _HomeEmbeddedVaultGate(houseId: houseId)
            : null;
      case 'gift':
        return GiftMakerScreen(houseId: houseId, myName: myName);
      case 'giftcode':
        if (!kDebugMode && !kIsWeb && Platform.isIOS) {
          return null;
        }
        return GiftcodeScreen(houseId: houseId, myName: myName);
      case 'history':
        return HistoryScreen(
          houseId: houseId,
          embedded: true,
        );
      case 'diary_export':
        return DiaryExportScreen(houseId: houseId);
      case 'tarot':
        return TarotScreen(
          houseId: houseId,
          relationshipMode: _homeToolRelationshipMode(),
          myName: myName,
        );
      case 'collage':
        return CollageMakerScreen(houseId: houseId);
      case 'age_zodiac':
        return AgeZodiacScreen(houseId: houseId);
      case 'love_card':
        final currentUid = _auth.currentUser?.uid;
        if (currentUid == null || currentUid.isEmpty) {
          return null;
        }
        return LoveCardScreen(
          houseId: houseId,
          myUid: currentUid,
        );
      case 'creative_diary':
        return CreativeDiaryScreen(houseId: houseId);
      default:
        return null;
    }
  }

  Widget _buildHomeToolSlotSection() {
    return const SizedBox.shrink();
  }

  Widget _buildEmbeddedHomeToolSurface(UtilityApp app) {
    final tool = _buildEmbeddedHomeTool(app.id);
    if (tool == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: _homeCardDecoration(radius: 28),
        child: Text(
          context.tr('home_tinchnycnd_0ff769'),
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6B7280),
            height: 1.45,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width;
        final surfaceWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : fallbackWidth;
        return RepaintBoundary(
          child: SizedBox(
            width: surfaceWidth,
            height: _homeToolPanelHeight(app.id),
            child: _EmbeddedHomeToolSurface(
              toolId: app.id,
              child: tool,
            ),
          ),
        );
      },
    );
  }
}

class _HomeToolActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;

  const _HomeToolActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _HomeToolPickerSheet extends StatelessWidget {
  final List<UtilityApp> apps;
  final String? selectedId;

  const _HomeToolPickerSheet({
    required this.apps,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final funApps = apps.where((app) => !app.isTool).toList(growable: false);
    final toolApps = apps.where((app) => app.isTool).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('home_chntinch_c56314'),
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF243042),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('home_homechhint_91bdc8'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A8598),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                if (funApps.isNotEmpty) ...[
                  _HomeToolSectionHeader(
                    title: context.tr('home_tinchchung_3e7d5e'),
                    icon: Icons.celebration_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...funApps.map(
                    (app) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HomeToolPickerTile(
                        app: app,
                        isSelected: app.id == selectedId,
                        onTap: () => Navigator.of(context).pop(app.id),
                      ),
                    ),
                  ),
                ],
                if (toolApps.isNotEmpty) ...[
                  if (funApps.isNotEmpty) const SizedBox(height: 8),
                  _HomeToolSectionHeader(
                    title: context.tr('home_cngcthityu_872418'),
                    icon: Icons.build_circle_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...toolApps.map(
                    (app) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HomeToolPickerTile(
                        app: app,
                        isSelected: app.id == selectedId,
                        onTap: () => Navigator.of(context).pop(app.id),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeToolSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _HomeToolSectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SLColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF243042),
          ),
        ),
      ],
    );
  }
}

class _HomeToolPickerTile extends StatelessWidget {
  final UtilityApp app;
  final bool isSelected;
  final VoidCallback onTap;

  const _HomeToolPickerTile({
    required this.app,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF0F6)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFC5D8)
                  : Colors.white.withValues(alpha: 0.92),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: app.colors),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: buildUtilityStickerIcon(
                  utilityId: app.id,
                  fallbackIcon: app.icon,
                  fallbackColor: Colors.white,
                  fallbackSize: 22,
                  padding: const EdgeInsets.all(3),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Text(
                  app.localizedTitle,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF243042),
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: isSelected ? SLColors.primary : const Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmbeddedHomeToolSurface extends StatelessWidget {
  final String toolId;
  final Widget child;

  const _EmbeddedHomeToolSurface({
    required this.toolId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: ValueKey<String>('home_tool_nav_$toolId'),
      onGenerateRoute: (_) {
        return MaterialPageRoute<void>(
          builder: (_) => MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: PopScope(
              canPop: false,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _HomeVaultChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HomeVaultChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEmbeddedVaultGate extends StatefulWidget {
  final String houseId;

  const _HomeEmbeddedVaultGate({
    required this.houseId,
  });

  @override
  State<_HomeEmbeddedVaultGate> createState() => _HomeEmbeddedVaultGateState();
}

class _HomeEmbeddedVaultGateState extends State<_HomeEmbeddedVaultGate> {
  final MilitaryLockService _militaryLockService = MilitaryLockService();

  bool _isRequestingUnlock = true;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_requestUnlock());
    });
  }

  Future<void> _requestUnlock() async {
    if (mounted) {
      setState(() => _isRequestingUnlock = true);
    }

    if (kIsWeb) {
      _militaryLockService.lockScope(LockScope.privateArea);
    }

    final unlocked = await _militaryLockService.requestUnlock(
      context: context,
      scope: LockScope.privateArea,
      houseId: widget.houseId,
      title: MilitaryLockService.getScopeTitle(LockScope.privateArea),
      reason: MilitaryLockService.scopeReason(LockScope.privateArea),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isRequestingUnlock = false;
      _isUnlocked = unlocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return SecretVaultScreen(houseId: widget.houseId);
    }

    return StreamBuilder<bool>(
      stream: PurchaseService().vipStatusStream(),
      initialData: false,
      builder: (context, snapshot) {
        final isVip = (snapshot.data ?? false) || kDebugMode;
        final uiPrefs = UiPrefs.notifier.value;
        final secureStyle = uiPrefs.vaultHomeStyle == 'secure';
        final compactStyle = uiPrefs.vaultHomeStyle == 'compact';
        final cosmicStyle = uiPrefs.vaultHomeStyle == 'cosmic' && isVip;

        List<Color> colors;
        Color accent;

        if (secureStyle) {
          colors = [const Color(0xFF1F1C2C), const Color(0xFF928DAB)];
          accent = const Color(0xFF4F46E5);
        } else if (cosmicStyle) {
          colors = [const Color(0xFF0F0C20), const Color(0xFF15102A)];
          accent = const Color(0xFFFFD700);
        } else {
          colors = [const Color(0xFFFFF0F6), const Color(0xFFE3F2FD)];
          accent = SLColors.primary;
        }

        final showPreview = uiPrefs.vaultHomePreviewEnabled &&
            !(uiPrefs.vaultHomeHidePreviewWhenLocked && !_isUnlocked);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
                padding: EdgeInsets.fromLTRB(
                  18,
                  compactStyle ? 18 : 22,
                  18,
                  compactStyle ? 18 : 22,
                ),
                decoration: BoxDecoration(
                  color: cosmicStyle
                      ? Colors.black.withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: cosmicStyle
                        ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.92),
                    width: cosmicStyle ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: cosmicStyle ? 0.35 : 0.18),
                      blurRadius: cosmicStyle ? 36 : 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: compactStyle ? 62 : 76,
                              height: compactStyle ? 62 : 76,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: secureStyle
                                      ? [const Color(0xFF4F46E5), const Color(0xFF111827)]
                                      : cosmicStyle
                                          ? [const Color(0xFFD97706), const Color(0xFF7C2D12)]
                                          : [const Color(0xFFFF7A86), const Color(0xFFF6A0C6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                secureStyle
                                    ? Icons.enhanced_encryption_rounded
                                    : cosmicStyle
                                        ? Icons.vpn_key_rounded
                                        : Icons.lock_person_rounded,
                                color: Colors.white,
                                size: compactStyle ? 28 : 34,
                              ),
                            ),
                            if (uiPrefs.vaultHomeBadgeEnabled)
                              Positioned(
                                right: -5,
                                bottom: -5,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _isRequestingUnlock
                                        ? const Color(0xFFFFB74D)
                                        : const Color(0xFF43A047),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: Icon(
                                    _isRequestingUnlock
                                        ? Icons.hourglass_top_rounded
                                        : Icons.verified_user_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('home_khnggianri_5aa2fb'),
                                style: SLTheme.quicksand(
                                  fontSize: compactStyle ? 18 : 21,
                                  fontWeight: FontWeight.w900,
                                  color: cosmicStyle
                                      ? const Color(0xFFFFD700)
                                      : const Color(0xFF243042),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _isRequestingUnlock
                                    ? context.tr('home_angxcthcmk_e31a5e')
                                    : context.tr('home_nhtknhring_4acbf3'),
                                style: SLTheme.quicksand(
                                  fontSize: compactStyle ? 11.8 : 12.8,
                                  fontWeight: FontWeight.w700,
                                  color: cosmicStyle
                                      ? const Color(0xFFE2B653)
                                      : const Color(0xFF667085),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!compactStyle) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _HomeVaultChip(
                            icon: Icons.visibility_off_rounded,
                            label: showPreview
                                ? context.tr('home_previewant_dbaf55')
                                : context.tr('home_npreview_1da491'),
                            color: accent,
                          ),
                          _HomeVaultChip(
                            icon: Icons.fingerprint_rounded,
                            label: context.tr('home_mbngkha_d3e60a'),
                            color: cosmicStyle ? const Color(0xFFFFD700) : const Color(0xFF7E57C2),
                          ),
                          _HomeVaultChip(
                            icon: Icons.favorite_rounded,
                            label: context.tr('home_chhaibn_a913db'),
                            color: cosmicStyle ? const Color(0xFFFFD700) : const Color(0xFFD81B60),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (_isRequestingUnlock)
                      SizedBox(
                        width: compactStyle ? 24 : 28,
                        height: compactStyle ? 24 : 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _requestUnlock,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(context.tr('home_mkhnggianr_b53f72')),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: cosmicStyle ? Colors.black87 : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
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
  }
}
