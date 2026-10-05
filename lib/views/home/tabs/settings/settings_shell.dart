part of '../settings_tab.dart';

extension _SettingsTabShell on _SettingsTabState {
  void _openHelpCenter() {
    final uid = _auth.currentUser?.uid;
    final houseId = _houseId;
    bool valid() =>
        mounted && _auth.currentUser?.uid == uid && _houseId == houseId;
    slPush(
      context,
      AppHelpCenterScreen(
        isStillValid: valid,
        featureActions: {
          'account': () => _togglePanel('account'),
          'security': () => _togglePanel('security'),
          'personalize': () => _togglePanel('theme'),
          if (!kIsWeb) 'widget': () => _togglePanel('widget'),
          if ((houseId ?? '').isNotEmpty)
            'pairing': () => slPush(context, const PairingDashboardScreen()),
        },
        onSupport: _openSupportContact,
        onReplaySettings: () => _maybeShowSettingsGuideOnOpen(replay: true),
        onReplayHome: widget.onReplayFirstSetupGuide == null
            ? null
            : () {
                final replay = widget.onReplayFirstSetupGuide!;
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) => replay());
              },
      ),
    );
  }

  String _sectionIdForPanel(String id) {
    switch (id) {
      case 'vip':
      case 'identity':
      case 'language':
      case 'account':
        return 'account';
      case 'security':
      case 'lock':
        return 'security';
      case 'theme':
      case 'ai':
      case 'music':
        return 'theme';
      case 'advanced':
      case 'notifications':
        return 'notifications';
      case 'relationship':
        return 'relationship';
      case 'widget':
        return 'widget';
      case 'support':
      case 'supportLegal':
        return 'supportLegal';
      case 'dataHealth':
        return 'dataHealth';
      default:
        return id;
    }
  }

  bool _shouldShowPendingDeviceGate(String id) {
    return _sectionIdForPanel(id) == 'security';
  }

  Future<void> _togglePanel(String id) async {
    final sectionId = _sectionIdForPanel(id);
    if (_isBootstrappingSettings) {
      _showToast(
        L10nService().translate('settings_loading_data'),
        success: false,
      );
      return;
    }
    if (_shouldShowPendingDeviceGate(sectionId)) {
      if (!await _ensureCanModifySecurityInfo(showToast: false)) {
        return;
      }
      if (!mounted) return;
    }
    if (sectionId == 'countdownMode') {
      await _openCountdownMode();
      return;
    }
    final shouldAnimateWidgetPreview = sectionId == 'widget';
    _hasActiveStandalonePanel = true;
    if (shouldAnimateWidgetPreview) {
      _startWidgetPreviewTicker();
    }
    if (sectionId == 'dataHealth') {
      unawaited(_refreshSettingsBackupStatus());
    }
    try {
      await slPush(context, _buildStandalonePanelPage(sectionId));
    } finally {
      if (shouldAnimateWidgetPreview) {
        _stopWidgetPreviewTicker();
      }
      _hasActiveStandalonePanel = false;
    }
  }

  bool get _myGenderIsFemale =>
      RoleUtils.isFemaleRole(_activeRoleKey, genderSwapped: _genderSwapped);

  /// Chỉ đổi nhãn Nam/Nữ của cả nhà; chỗ user1/user2, tên và dữ liệu giữ nguyên.
  Future<void> _pickMyGender() async {
    final houseId = _houseId?.trim() ?? '';
    final uid = _auth.currentUser?.uid;
    if (houseId.isEmpty || uid == null || _relationshipMode == 'single') {
      return;
    }
    final fallbackErrMsg = context.tr('home_clixyra_775791');
    if (!await _ensureCanModifySharedInfo()) return;
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => GenderSelectionDialog(
        initialRole: _myGenderIsFemale ? 'user2' : 'user1',
        onSelected: (value) {
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(value);
          }
        },
      ),
    );
    // Hộp chọn trả 'user1' cho Nam, 'user2' cho Nữ.
    if (selected == null ||
        !mounted ||
        _auth.currentUser?.uid != uid ||
        _houseId?.trim() != houseId) {
      return;
    }
    final wantsFemale = selected == 'user2';
    if (wantsFemale == _myGenderIsFemale) return;
    final nextSwapped = wantsFemale != (_activeRoleKey == 'user2');
    try {
      await _dbRef
          .child('houses/$houseId/settings/genderSwapped')
          .set(nextSwapped);
    } catch (error) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(error, fallbackMessage: fallbackErrMsg).message,
        success: false,
      );
      return;
    }
    if (!mounted ||
        _auth.currentUser?.uid != uid ||
        _houseId?.trim() != houseId) {
      return;
    }
    setState(() {
      _genderSwapped = nextSwapped;
      final maleName = context.tr('home_bnnam_123ef2');
      final femaleName = context.tr('home_bnn_babaec');
      // Chỉ đổi tên mặc định; tên người dùng tự đặt giữ nguyên.
      if (_nameU1 == maleName || _nameU1 == femaleName) {
        _nameU1 = nextSwapped ? femaleName : maleName;
      }
      if (_nameU2 == maleName || _nameU2 == femaleName) {
        _nameU2 = nextSwapped ? maleName : femaleName;
      }
    });
    _showToast(
      L10nService().format('settings_my_gender_updated', {
        'gender': context.tr(
          wantsFemale ? 'auth_gender_female' : 'auth_gender_male',
        ),
      }),
    );
  }

  String _resolveSettingsMyName() {
    return _activeRoleKey == 'user2' ? _nameU2 : _nameU1;
  }

  Set<String> _settingsSearchableUtilityIds() {
    final houseId = (_houseId ?? '').trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final ids = <String>{'store'};

    if (houseId.isEmpty) {
      return ids;
    }

    ids.addAll({
      'bucket',
      'note',
      'friendly_chat',
      'finance',
      'wish',
      'habit',
      'drawing',
      'voice',
      'calendar',
      'capsule',
      'cinema',
      'wheel',
      'vault',
      'surprise_maker',
      'giftcode',
      'diary_export',
      'tarot',
      'collage',
      'creative_diary',
    });

    if (currentUid != null && currentUid.isNotEmpty) {
      ids.add('surprise_maker'); // Keeps backwards compatibility if needed
    }

    return ids;
  }

  Future<void> _openSearchResultFromSettings(dynamic result) async {
    final action = result.actionId as String;
    if (action == 'history') {
      await slPush(context, HistoryScreen(houseId: _houseId ?? ''));
      return;
    }

    if (!action.startsWith('utility:')) {
      return;
    }

    final utilityId = action.substring('utility:'.length);
    final houseId = (_houseId ?? '').trim();
    final myName = _resolveSettingsMyName();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    Widget? screen;
    switch (utilityId) {
      case 'store':
        screen = const RewardStoreScreen();
        break;
      case 'bucket':
        screen = houseId.isEmpty
            ? null
            : BucketListScreen(houseId: houseId, myName: myName);
        break;
      case 'note':
        screen = houseId.isEmpty
            ? null
            : SharedNotesScreen(houseId: houseId, myName: myName);
        break;
      case 'friendly_chat':
        screen = houseId.isEmpty
            ? null
            : FriendlyChatScreen(houseId: houseId, myName: myName);
        break;
      case 'finance':
        screen = houseId.isEmpty
            ? null
            : FinanceScreen(houseId: houseId, myName: myName);
        break;
      case 'wish':
        screen = houseId.isEmpty
            ? null
            : WishlistScreen(houseId: houseId, myName: myName);
        break;
      case 'habit':
        screen = houseId.isEmpty
            ? null
            : HabitScreen(houseId: houseId, myName: myName);
        break;
      case 'drawing':
        screen = houseId.isEmpty
            ? null
            : DrawingStudioScreen(houseId: houseId, myName: myName);
        break;
      case 'voice':
        screen = houseId.isEmpty
            ? null
            : VoiceScreen(houseId: houseId, myName: myName);
        break;
      case 'calendar':
        screen = houseId.isEmpty
            ? null
            : CalendarScreen(houseId: houseId, myName: myName);
        break;
      case 'health':
        screen = null;
        break;
      case 'capsule':
        screen = houseId.isEmpty
            ? null
            : CapsuleScreen(houseId: houseId, myName: myName);
        break;
      case 'cinema':
        screen = houseId.isEmpty
            ? null
            : CinemaScreen(houseId: houseId, myName: myName);
        break;
      case 'wheel':
        screen = houseId.isEmpty ? null : WheelScreen(houseId: houseId);
        break;
      case 'vault':
        screen = houseId.isEmpty ? null : SecretVaultScreen(houseId: houseId);
        break;
      case 'surprise_maker':
        screen = houseId.isEmpty
            ? null
            : LoveCardScreen(houseId: houseId, myUid: currentUid ?? '');
        break;
      case 'giftcode':
        screen = houseId.isEmpty
            ? null
            : GiftcodeScreen(houseId: houseId, myName: myName);
        break;
      case 'history':
        screen = houseId.isEmpty ? null : HistoryScreen(houseId: houseId);
        break;
      case 'diary_export':
        screen = houseId.isEmpty ? null : DiaryExportScreen(houseId: houseId);
        break;
      case 'tarot':
        screen = houseId.isEmpty
            ? null
            : TarotScreen(
                houseId: houseId,
                relationshipMode: _relationshipMode,
                myName: myName,
              );
        break;
      case 'collage':
        screen = houseId.isEmpty ? null : CollageMakerScreen(houseId: houseId);
        break;

      case 'love_card':
        screen = houseId.isEmpty || currentUid == null || currentUid.isEmpty
            ? null
            : LoveCardScreen(houseId: houseId, myUid: _auth.currentUser!.uid);
        break;
      case 'creative_diary':
        screen = houseId.isEmpty ? null : CreativeDiaryScreen(houseId: houseId);
        break;
    }

    if (screen == null) {
      return;
    }

    await slPush(context, screen);
  }

  Widget _buildSettingsScaffold() {
    return _buildResponsiveSettingsScaffold();
  }

  bool get _settingsIsDark => SLSettingsPalette.isNightTheme;

  Widget _buildResponsiveSettingsScaffold() {
    final isDark = _settingsIsDark;
    final palette = SLSettingsPalette.resolve(isDark);
    final double headerHeight =
        MediaQuery.paddingOf(context).top +
        SettingsHomeHeader.contentHeight +
        1;
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: SLSettingsBackdrop(isDark: isDark)),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: SLResponsive.maxContentWidthForWidth(
                            constraints.maxWidth,
                            handsetMax: 560,
                            tabletMax: 720,
                            desktopMax: 760,
                          ),
                        ),
                        child: ListView(
                          physics: SLResponsive.scrollPhysicsForPlatform(),
                          padding: EdgeInsets.only(
                            top: headerHeight,
                            bottom: MediaQuery.paddingOf(context).bottom + 20,
                          ),
                          children: [
                            _buildSettingsSyncBanner(),
                            SettingsInitialContent(
                              ready: _settingsIdentityReady,
                              failed: _settingsIdentityLoadFailed,
                              loadingLabel: context.tr('settings_loading_data'),
                              errorLabel: context.tr(
                                'settings_initial_load_error',
                              ),
                              retryLabel: context.tr('core_retry'),
                              onRetry: () {
                                setState(() {
                                  _settingsIdentityLoadFailed = false;
                                  _isBootstrappingSettings = true;
                                });
                                unawaited(_fetchSettingsData());
                              },
                              builder: (_) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ..._buildNewSettingsList(isDark),
                                  const SizedBox(height: 24),
                                  _buildSettingsFooter(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildSettingsHeader(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsHeader() {
    final isDark = _settingsIsDark;
    return SettingsHomeHeader(
      title: context.tr('settings'),
      isDark: isDark,
      backLabel: context.tr('p6_back'),
      onBack: widget.embedded ? null : () => Navigator.pop(context),
      actions: [
        SettingsHeaderAction(
          icon: Icons.search_rounded,
          tooltip: context.tr('settings_search_tooltip'),
          isDark: isDark,
          onTap: () {
            final houseId = _houseId?.trim() ?? '';
            if (houseId.isEmpty) {
              return;
            }
            slPush(
              context,
              GlobalSearchScreen(
                houseId: houseId,
                relationshipMode: _relationshipMode,
                allowedUtilityIds: _settingsSearchableUtilityIds(),
                onResultSelected: (result) async {
                  Navigator.of(context).pop();
                  await _openSearchResultFromSettings(result);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingsSyncBanner() {
    return const SizedBox(height: 14);
  }

  Widget _buildiOSSectionCard(List<Widget> children, bool isDark) =>
      RepaintBoundary(
        child: SLSettingsGroup(isDark: isDark, children: children),
      );

  Widget _buildiOSRow({
    Key? guideKey,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    String? value,
    Widget? trailing,
    bool isDark = false,
    bool isDestructive = false,
  }) => SLSettingsRow(
    key: guideKey,
    icon: icon,
    iconColor: iconBgColor,
    title: title,
    subtitle: subtitle,
    value: value,
    trailing: trailing,
    isDark: isDark,
    destructive: isDestructive,
    onTap: onTap,
  );

  Widget _buildDivider(bool isDark) => SLSettingsDivider(isDark: isDark);

  Widget _buildSettingsAccountHero(bool isDark) {
    final avatarUrl = (_activeRoleKey == 'user2' ? _avatarUrl2 : _avatarUrl1)
        .trim();
    final avatarProvider = avatarUrl.startsWith('http')
        ? CachedNetworkImageProvider(avatarUrl)
        : null;
    final displayName = _resolveSettingsMyName().trim();
    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';

    return SettingsProfileCard(
      isDark: isDark,
      name: displayName.isEmpty
          ? context.tr('settings_account_label')
          : displayName,
      detail: email.isEmpty ? context.tr('settings_account_desc') : email,
      footerLabel: context.tr('settings_profile_manage'),
      isPro: _isVipActive || _vipBadgeHint == true,
      onTap: () => _togglePanel('account'),
      avatar: SettingsAccountAvatar(
        key: ValueKey('${_auth.currentUser?.uid}:$_houseId:$_activeRoleKey'),
        backgroundColor: SLSettingsColors.accentSoft,
        foregroundColor: SLSettingsColors.accent,
        image: avatarProvider,
      ),
    );
  }

  Widget _buildSettingsQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PairingSettingsShortcut(
                houseId: _houseId,
                isDark: isDark,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PairingDashboardScreen(),
                    ),
                  );
                  if (!mounted) return;
                  // Người nhập mã có thể vừa chuyển nhà; cập nhật nguồn của ô này.
                  final houseId = await _houseService.getCurrentHouseId(
                    preferFresh: true,
                  );
                  if (!mounted || _houseId == houseId) return;
                  setState(() {
                    _houseId = houseId;
                    _settingsIdentityReady = false;
                    _isBootstrappingSettings = true;
                  });
                  unawaited(_fetchSettingsData());
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSettingsQuickAction(
                icon: Icons.timelapse_rounded,
                guideKey: _countdownGuideKey,
                color: SLSettingsColors.coral,
                title: context.tr('settings_countdown_space_label'),
                isDark: isDark,
                onTap: () => _togglePanel('countdownMode'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSettingsQuickAction(
                icon: Icons.palette_outlined,
                guideKey: _themeGuideKey,
                color: SLSettingsColors.violet,
                title: context.tr('theme'),
                isDark: isDark,
                onTap: () => _togglePanel('theme'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsQuickAction({
    Key? guideKey,
    required IconData icon,
    required Color color,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return KeyedSubtree(
      key: guideKey,
      child: SettingsQuickTile(
        icon: icon,
        color: color,
        title: title,
        isDark: isDark,
        onTap: onTap,
      ),
    );
  }

  /// Trạng thái khóa ứng dụng hiển thị ngay trên dòng Bảo mật.
  Widget? _buildSecurityStatusPill(bool isDark) {
    if (!_appLockSettingsLoaded) return null;
    return SLSettingsPill(
      label: context.tr(
        _isAppLockEnabled ? 'settings_app_lock_on' : 'settings_app_lock_off',
      ),
      tone: _isAppLockEnabled ? SLSettingsTone.success : SLSettingsTone.warning,
      icon: _isAppLockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
      isDark: isDark,
      dense: true,
    );
  }

  List<Widget> _buildNewSettingsList(bool isDark) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: KeyedSubtree(
          key: _accountGuideKey,
          child: _buildSettingsAccountHero(isDark),
        ),
      ),
      _buildSectionTitle(context.tr('settings_categories_title')),
      _buildSettingsQuickActions(isDark),
      _buildSectionTitle(context.tr('settings_menu_preferences')),
      _buildiOSSectionCard([
        if (_relationshipMode != 'single') ...[
          _buildiOSRow(
            icon: Icons.wc_rounded,
            iconBgColor: SLSettingsColors.sky,
            title: context.tr('settings_my_gender_title'),
            value: context.tr(
              _myGenderIsFemale ? 'auth_gender_female' : 'auth_gender_male',
            ),
            isDark: isDark,
            onTap: _pickMyGender,
          ),
          _buildDivider(isDark),
        ],
        _buildiOSRow(
          icon: Icons.widgets_outlined,
          guideKey: _widgetGuideKey,
          iconBgColor: SLSettingsColors.teal,
          title: context.tr('settings_menu_widget_title'),
          subtitle: kIsWeb
              ? context.tr('settings_menu_widget_web')
              : context.tr('settings_menu_widget_mobile'),
          isDark: isDark,
          onTap: () => _togglePanel('widget'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.notifications_none_rounded,
          iconBgColor: SLSettingsColors.amber,
          title: context.tr('settings_notifications_interactions'),
          subtitle: context.tr('settings_menu_notifications_desc'),
          isDark: isDark,
          onTap: () => _togglePanel('notifications'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.chat_bubble_outline_rounded,
          iconBgColor: SLSettingsColors.rose,
          title: context.tr('util_chatthnthi_c39699'),
          subtitle: L10nService().translate('settings_menu_chat_desc'),
          isDark: isDark,
          onTap: () {
            final houseId = (_houseId ?? '').trim();
            final myName = _resolveSettingsMyName();
            slPush(
              context,
              FriendlyChatScreen(houseId: houseId, myName: myName),
            );
          },
        ),
      ], isDark),
      _buildSectionTitle(context.tr('settings_menu_security_group')),
      _buildiOSSectionCard([
        _buildiOSRow(
          icon: Icons.shield_outlined,
          guideKey: _securityGuideKey,
          iconBgColor: SLSettingsColors.sage,
          title: context.tr('settings_menu_security_title'),
          subtitle: context.tr('settings_menu_security_desc'),
          trailing: _buildSecurityStatusPill(isDark),
          isDark: isDark,
          onTap: () => _togglePanel('security'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.cloud_sync_outlined,
          guideKey: _dataGuideKey,
          iconBgColor: SLSettingsColors.sky,
          title: context.tr('settings_menu_data_title'),
          subtitle: context.tr('settings_menu_data_desc'),
          isDark: isDark,
          onTap: () => _togglePanel('dataHealth'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.location_on_outlined,
          iconBgColor: SLSettingsColors.indigo,
          title: context.tr('settings_gps_mode_title'),
          value: _gpsMode == LocationService.kGpsModeAlways
              ? context.tr('settings_gps_mode_always')
              : context.tr('settings_gps_mode_foreground'),
          isDark: isDark,
          onTap: _showGpsModeSelectorDialog,
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.verified_user_outlined,
          iconBgColor: SLSettingsColors.violet,
          title: context.tr('settings_menu_permissions_title'),
          subtitle: context.tr('settings_menu_permissions_desc'),
          trailing: _isGrantingPermissions
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          isDark: isDark,
          onTap: _isGrantingPermissions ? () {} : _requestAllPermissions,
        ),
      ], isDark),
      _buildSectionTitle(context.tr('settings_menu_support_group')),
      _buildiOSSectionCard([
        _buildiOSRow(
          icon: Icons.history_rounded,
          iconBgColor: SLSettingsColors.slate,
          title: context.tr('settings_activity_history'),
          subtitle: context.tr('settings_menu_history_desc'),
          isDark: isDark,
          onTap: () {
            final houseId = _houseId?.trim() ?? '';
            if (houseId.isNotEmpty) {
              slPush(context, HistoryScreen(houseId: houseId));
            }
          },
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.support_agent_rounded,
          guideKey: _supportGuideKey,
          iconBgColor: SLSettingsColors.teal,
          title: context.tr('settings_menu_support_title'),
          subtitle: context.tr('settings_menu_support_desc'),
          isDark: isDark,
          onTap: _openSupportContact,
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.menu_book_outlined,
          iconBgColor: SLSettingsColors.coral,
          title: context.tr('settings_menu_guide_title'),
          subtitle: context.tr('settings_menu_guide_desc'),
          isDark: isDark,
          onTap: _openHelpCenter,
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.tune_rounded,
          iconBgColor: SLSettingsColors.sky,
          title: context.tr('settings_menu_replay_settings'),
          isDark: isDark,
          onTap: () => _maybeShowSettingsGuideOnOpen(replay: true),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.explore_outlined,
          iconBgColor: SLSettingsColors.rose,
          title: context.tr('starter_title'),
          isDark: isDark,
          onTap: () {
            final uid = _auth.currentUser?.uid ?? '';
            final houseId = _houseId ?? '';
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: SLSettingsColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(SLSettingsRadius.sheet),
                ),
              ),
              showDragHandle: true,
              builder: (_) => FractionallySizedBox(
                heightFactor: .85,
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GettingStartedChecklist(
                      uid: uid,
                      houseId: houseId,
                      isSingle: _relationshipMode == 'single',
                      alwaysVisible: true,
                      isStillValid: () =>
                          mounted &&
                          _auth.currentUser?.uid == uid &&
                          _houseId == houseId,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.onReplayFirstSetupGuide != null) ...[
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.home_outlined,
            iconBgColor: SLSettingsColors.indigo,
            title: context.tr('settings_menu_replay_home'),
            isDark: isDark,
            onTap: () {
              final replay = widget.onReplayFirstSetupGuide!;
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) => replay());
            },
          ),
        ],
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.star_outline_rounded,
          iconBgColor: SLSettingsColors.amber,
          title: context.tr('rate_app'),
          isDark: isDark,
          onTap: _rateApp,
        ),
      ], isDark),
      _buildSectionTitle(context.tr('settings_account_label')),
      _buildiOSSectionCard([
        _buildiOSRow(
          icon: Icons.logout_rounded,
          iconBgColor: SLSettingsColors.red,
          title: context.tr('logout'),
          isDark: isDark,
          isDestructive: true,
          onTap: _logout,
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.delete_forever_outlined,
          iconBgColor: SLSettingsColors.red,
          title: context.tr('settings_delete_account_data'),
          isDark: isDark,
          isDestructive: true,
          onTap: _deleteAccount,
        ),
      ], isDark),
    ];
  }

  Widget _buildSettingsFooter() {
    return SettingsMenuFooter(
      tagline: context.tr('settings_footer_tagline'),
      versionLabel: context.tr('version'),
      isDark: _settingsIsDark,
    );
  }

  Widget _buildStandalonePanelPage(String id) {
    final sectionId = _sectionIdForPanel(id);
    final baseTheme = Theme.of(context);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(SLSettingsRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );
    final settingsTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: SLSettingsColors.divider,
      dividerTheme: const DividerThemeData(
        color: SLSettingsColors.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: baseTheme.dialogTheme.copyWith(
        backgroundColor: SLSettingsColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: SLSettingsColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SLSettingsColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: SLSettingsColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SLSettingsRadius.sheet),
          ),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: SLSettingsColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: SLTheme.quicksand(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: SLSettingsColors.inkTertiary,
        ),
        prefixIconColor: SLSettingsColors.inkTertiary,
        suffixIconColor: SLSettingsColors.inkTertiary,
        border: inputBorder(SLSettingsColors.border),
        enabledBorder: inputBorder(SLSettingsColors.border),
        focusedBorder: inputBorder(SLSettingsColors.accent, 1.5),
        errorBorder: inputBorder(SLSettingsColors.danger),
        focusedErrorBorder: inputBorder(SLSettingsColors.danger, 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SLSettingsColors.accent
              : const Color(0xFFE6DCD3),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: baseTheme.checkboxTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SLSettingsColors.accent
              : Colors.transparent,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SLSettingsColors.accent
              : SLSettingsColors.inkTertiary,
        ),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: SLSettingsColors.accent,
        inactiveTrackColor: SLSettingsColors.accentSoft,
        thumbColor: SLSettingsColors.accent,
        overlayColor: SLSettingsColors.accent.withValues(alpha: 0.12),
      ),
    );
    return Theme(
      data: settingsTheme,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _SettingsBackgroundLayer(),
          ValueListenableBuilder<int>(
            valueListenable: _panelRebuildNotifier,
            builder: (context, _, _) {
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: SLResponsive.maxContentWidthForWidth(
                              constraints.maxWidth,
                              handsetMax: 560,
                              tabletMax: 760,
                              desktopMax: 840,
                            ),
                          ),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.only(top: 4, bottom: 40),
                            child: _buildStandalonePanelContent(sectionId),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStandalonePanelContent(String id) {
    final sectionId = _sectionIdForPanel(id);
    if (_isDevicePending && _shouldShowPendingDeviceGate(sectionId)) {
      return _buildDevicePendingScreen(context);
    }
    switch (sectionId) {
      case 'account':
        return _buildSectionStack([
          _buildPanelPageIntro(
            title: context.tr('settings_account_label'),
            description: context.tr('settings_account_desc'),
            icon: Icons.manage_accounts_outlined,
            color: SLSettingsColors.rose,
          ),
          _buildVipPanel(hideBackButton: true),
          _buildIdentityPanel(hideBackButton: true),
          _buildLanguagePanel(hideBackButton: true),
        ]);
      case 'security':
        return _buildSectionStack([
          _buildPanelPageIntro(
            title: context.tr('settings_menu_security_title'),
            description: context.tr('settings_menu_security_desc'),
            icon: Icons.shield_outlined,
            color: SLSettingsColors.sage,
          ),
          _buildSecurityPanel(hideBackButton: true),
          _buildLockPanel(hideBackButton: true),
        ]);
      case 'theme':
        return _buildSectionStack([
          _buildThemePanel(hideBackButton: false),
          _buildMusicPanel(hideBackButton: true),
          _buildAIPanel(hideBackButton: true),
        ]);
      case 'widget':
        return kIsWeb
            ? _buildUnavailablePanel(
                title: context.tr('home_screen_widget'),
                message: context.tr('settings_widget_device_only'),
              )
            : _buildSectionStack([_buildWidgetPanel(hideBackButton: false)]);
      case 'notifications':
        return _buildSectionStack([_buildAdvancedPanel(hideBackButton: false)]);
      case 'relationship':
        return _buildSectionStack([
          _buildRelationshipPanelV2(hideBackButton: false),
        ]);
      case 'supportLegal':
        return _buildSupportLegalSectionPanel(hideBackButton: false);
      case 'dataHealth':
        return _buildDataHealthPanel(hideBackButton: false);
      default:
        return _buildUnavailablePanel(
          title: context.tr('settings_feature_in_progress_title'),
          message: context.tr('settings_feature_in_progress_desc'),
        );
    }
  }

  /// Đầu trang con dùng chung khi một trang gồm nhiều khối.
  Widget _buildPanelPageIntro({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SLSettingsPageHeader(
        title: title,
        description: description,
        icon: icon,
        iconColor: color,
        backLabel: context.tr('p6_back'),
        onBack: Navigator.of(context).canPop()
            ? () => Navigator.pop(context)
            : null,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      ),
    );
  }

  Widget _buildSectionStack(List<Widget> panels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: panels,
    );
  }

  Widget _buildUnavailablePanel({
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsPageHeader(
            title: title,
            icon: Icons.hourglass_empty_rounded,
            iconColor: SLSettingsColors.slate,
            backLabel: context.tr('settings_back_btn'),
            onBack: () => Navigator.pop(context),
          ),
          SLSettingsNotice(tone: SLSettingsTone.info, message: message),
        ],
      ),
    );
  }
}

class _DraggableFloatingChatIcon extends StatefulWidget {
  final String houseId;
  final String myName;

  const _DraggableFloatingChatIcon({
    required this.houseId,
    required this.myName,
  });

  @override
  State<_DraggableFloatingChatIcon> createState() =>
      _DraggableFloatingChatIconState();
}

class _DraggableFloatingChatIconState
    extends State<_DraggableFloatingChatIcon> {
  Offset _position = const Offset(20, 200); // Default position
  bool _isDragging = false;

  Timer? _speechTimer;
  String? _currentSpeech;

  final List<String> _randomSpeeches = [
    L10nService().translate('settings_chat_speech_hello'),
    L10nService().translate('settings_chat_speech_share'),
    L10nService().translate('settings_chat_speech_tap'),
    L10nService().translate('settings_chat_speech_today'),
    L10nService().translate('settings_chat_speech_listen'),
    L10nService().translate('settings_chat_speech_search'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPosition();
    _scheduleNextSpeech();
  }

  @override
  void dispose() {
    _speechTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextSpeech() {
    _speechTimer?.cancel();
    final randomSeconds =
        60 + math.Random().nextInt(240); // 60s to 300s (1 to 5 mins)
    _speechTimer = Timer(Duration(seconds: randomSeconds), _showSpeech);
  }

  void _showSpeech() {
    if (!mounted || _isDragging) {
      _scheduleNextSpeech();
      return;
    }

    setState(() {
      _currentSpeech =
          _randomSpeeches[math.Random().nextInt(_randomSpeeches.length)];
    });

    // Hide after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentSpeech = null;
        });
        _scheduleNextSpeech();
      }
    });
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('il_settings_chat_icon_dx');
    final dy = prefs.getDouble('il_settings_chat_icon_dy');
    if (dx != null && dy != null) {
      if (mounted) {
        setState(() {
          _position = Offset(dx, dy);
        });
      }
    }
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('il_settings_chat_icon_dx', _position.dx);
    await prefs.setDouble('il_settings_chat_icon_dy', _position.dy);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          _savePosition();
        },
        onTap: () {
          if (widget.houseId.isNotEmpty) {
            slPush(
              context,
              FriendlyChatScreen(
                houseId: widget.houseId,
                myName: widget.myName,
              ),
            );
          } else {
            // fallback silently if no house ID
          }
        },
        child: AnimatedScale(
          scale: _isDragging ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: R2StickerImage(
                    'assets/images/anhtomau_stickers/sticker_23.gif',
                    width: 36,
                    height: 36,
                  ),
                ),
              ),
              if (_currentSpeech != null && !_isDragging)
                Positioned(
                  bottom: 64, // Positioned above the icon
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentSpeech!,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
