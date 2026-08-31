part of '../settings_tab.dart';

extension _SettingsTabShell on _SettingsTabState {
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

  Future<void> _swapRole() async {
    final fallbackErrMsg = context.tr('home_clixyra_775791');
    final houseId = _houseId?.trim();
    if (houseId != null &&
        houseId.isNotEmpty &&
        !await _ensureCanModifySharedInfo()) {
      return;
    }
    if (!mounted) return;
    final roleChangeTitle = context.tr('change_role');
    final previousRole = _activeRoleKey == 'user2' ? 'user2' : 'user1';
    final nextRole = _activeRoleKey == 'user1' ? 'user2' : 'user1';
    final roleTerm = _displayNameForRole(nextRole);

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _activeRoleKey = nextRole;
    });

    await prefs.setString('il_role', nextRole);
    await prefs.setString('il_user_name', roleTerm);
    RoleUtils.roleNotifier.value = nextRole;

    if (_relationshipMode == 'single') {
      _showToast(
        L10nService().translate('Chế độ độc thân không hỗ trợ đổi vai Nam/Nữ.'),
        success: false,
      );
    } else {
      _showToast(
        '${L10nService().translate('settings_role_swap_prefix')} $roleTerm 🎉',
        success: true,
      );
    }

    final resolvedHouseId =
        (_houseId ?? await _houseService.getCurrentHouseId())?.trim();
    if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
      try {
        await PresenceService().goOffline(
          houseId: resolvedHouseId,
          role: previousRole,
        );
      } catch (e) {
        debugPrint(
          'swap role presence cleanup failed: ${AppErrorMapper.resolve(e, fallbackMessage: fallbackErrMsg).message}',
        );
      }
      unawaited(
        PushNotificationHelper.systemEvent(
          toHouseId: resolvedHouseId,
          type: 'role_change',
          title: roleChangeTitle,
          content:
              'Thiết bị này vừa chuyển từ ${_displayNameForRole(previousRole)} sang ${_displayNameForRole(nextRole)} trong phần Cài đặt.',
          extra: {'previousRole': previousRole, 'role': nextRole},
        ),
      );
    }
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

  Widget _buildResponsiveSettingsScaffold() {
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    final double headerHeight = MediaQuery.paddingOf(context).top + 66;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF120F11) : SLColors.paperCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            const Positioned.fill(child: _SettingsBackgroundLayer()),
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
                            tabletMax: 980,
                            desktopMax: 1080,
                          ),
                        ),
                        child: ListView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: headerHeight,
                            bottom: 120,
                          ),
                          children: [
                            _buildSettingsSyncBanner(),
                            ..._buildNewSettingsList(isDark),
                            const SizedBox(height: 26),
                            _buildSettingsFooter(),
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
    final uiState = UiPrefs.notifier.value;
    final isDark =
        uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    // Bề mặt giấy đặc giúp cuộn mượt mà nhưng vẫn giữ cá tính Love Journal.
    final headerBgColor = isDark
        ? const Color(0xFF211A1E).withValues(alpha: 0.98)
        : SLColors.paper.withValues(alpha: 0.98);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 8,
          16,
          12,
        ),
        decoration: BoxDecoration(
          color: headerBgColor,
          boxShadow: [
            BoxShadow(
              color: SLColors.ink.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : SLColors.border,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            if (!widget.embedded)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : _kSettingsHeaderSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : _kSettingsHeaderBorder,
                    ),
                    boxShadow: SLShadow.subtle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: SLColors.primaryActive,
                    size: 15,
                  ),
                ),
              )
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SLColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: SLColors.primary,
                  size: 20,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('settings'),
                    style: SLTheme.textStyleForKey(
                      'dancingScript',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : SLColors.ink,
                    ),
                  ),
                  Text(
                    context.tr('settings_footer_tagline'),
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : SLColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _buildHeaderAction(
              icon: Icons.search_rounded,
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
        ),
      ),
    );
  }

  Widget _buildSettingsSyncBanner() {
    return const SizedBox(height: 8);
  }

  Widget _buildiOSSectionCard(List<Widget> children, bool isDark) {
    return RepaintBoundary(
      child: SLTheme.paperCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.zero,
        radius: 22,
        showTape: false,
        color: isDark ? const Color(0xFF261F23) : SLColors.paper,
        accentColor: SLColors.thread,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildiOSRow({
    required IconData icon,
    required Color iconBgColor,
    Gradient? iconGradient,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    bool isDark = false,
    bool isDestructive = false,
  }) {
    final textColor = isDestructive
        ? SLColors.danger
        : (isDark ? Colors.white : SLColors.ink);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? SLColors.danger.withValues(alpha: 0.1)
                      : (iconGradient == null
                            ? iconBgColor.withValues(
                                alpha: isDark ? 0.22 : 0.13,
                              )
                            : null),
                  gradient: isDestructive ? null : iconGradient,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isDestructive
                        ? SLColors.danger.withValues(alpha: 0.2)
                        : iconBgColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDestructive
                      ? SLColors.danger
                      : (iconGradient == null ? iconBgColor : Colors.white),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey[500]
                              : SLColors.textTertiary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isDestructive)
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark
                      ? Colors.white38
                      : SLColors.thread.withValues(alpha: 0.72),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 67, right: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : SLColors.borderLight,
      ),
    );
  }

  Widget _buildSettingsAccountHero(bool isDark) {
    final avatarUrl = (_activeRoleKey == 'user2' ? _avatarUrl2 : _avatarUrl1)
        .trim();
    final avatarProvider = avatarUrl.startsWith('http')
        ? CachedNetworkImageProvider(avatarUrl)
        : null;
    final displayName = _resolveSettingsMyName().trim();
    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';

    return SLTheme.paperCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.fromLTRB(18, 22, 16, 18),
      radius: 28,
      showTape: true,
      color: isDark ? const Color(0xFF261F23) : SLColors.paper,
      accentColor: SLColors.primary,
      child: InkWell(
        onTap: () => _togglePanel('account'),
        borderRadius: BorderRadius.circular(22),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SLColors.paperBlush,
                border: Border.all(color: SLColors.thread, width: 1.6),
              ),
              child: CircleAvatar(
                backgroundColor: SLColors.primarySoft,
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? const Icon(
                        Icons.favorite_rounded,
                        color: SLColors.primary,
                        size: 27,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isEmpty
                              ? context.tr('settings_account_label')
                              : displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : SLColors.ink,
                          ),
                        ),
                      ),
                      if (_isVipActive) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: SLColors.washi,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: SLColors.secondary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'PRO',
                            style: SLTheme.quicksand(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: SLColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.isEmpty ? context.tr('settings_account_desc') : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : SLColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: SLColors.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: SLColors.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSettingsQuickAction(
              icon: Icons.favorite_border_rounded,
              color: SLColors.primary,
              title: context.tr('settings_partner_connect'),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PairingDashboardScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSettingsQuickAction(
              icon: Icons.timelapse_rounded,
              color: SLColors.secondary,
              title: context.tr('settings_countdown_space_label'),
              isDark: isDark,
              onTap: () => _togglePanel('countdownMode'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSettingsQuickAction(
              icon: Icons.palette_outlined,
              color: SLColors.accentPurple,
              title: context.tr('theme'),
              isDark: isDark,
              onTap: () => _togglePanel('theme'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsQuickAction({
    required IconData icon,
    required Color color,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF261F23) : SLColors.paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : SLColors.border,
            ),
            boxShadow: SLShadow.subtle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : SLColors.ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNewSettingsList(bool isDark) {
    return [
      _buildSettingsAccountHero(isDark),
      _buildSectionTitle(
        context.tr('settings_categories_title'),
        topPadding: 18,
      ),
      _buildSettingsQuickActions(isDark),
      _buildSectionTitle(
        context.tr('settings_group_config_title'),
        topPadding: 22,
      ),
      _buildiOSSectionCard([
        if (_relationshipMode != 'single') ...[
          _buildiOSRow(
            icon: Icons.swap_horiz_rounded,
            iconBgColor: SLColors.info,
            title: _activeRoleKey == 'user1'
                ? context.tr('settings_swap_role_to_female')
                : context.tr('settings_swap_role_to_male'),
            isDark: isDark,
            onTap: _swapRole,
          ),
          _buildDivider(isDark),
        ],
        _buildiOSRow(
          icon: Icons.widgets_outlined,
          iconBgColor: SLColors.success,
          title: context.tr('settings_widget_label'),
          subtitle: kIsWeb
              ? context.tr('settings_widget_desc_web')
              : context.tr('settings_widget_desc_mobile'),
          isDark: isDark,
          onTap: () => _togglePanel('widget'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.notifications_none_rounded,
          iconBgColor: SLColors.success,
          title: context.tr('settings_notifications_interactions'),
          subtitle: context.tr('settings_notifications_interactions_desc'),
          isDark: isDark,
          onTap: () => _togglePanel('notifications'),
        ),
      ], isDark),
      _buildSectionTitle(context.tr('settings_security_label'), topPadding: 22),
      _buildiOSSectionCard([
        _buildiOSRow(
          icon: Icons.shield_outlined,
          iconBgColor: SLColors.primary,
          title: context.tr('settings_security_label'),
          subtitle: context.tr('settings_security_desc'),
          isDark: isDark,
          onTap: () => _togglePanel('security'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.cloud_sync_outlined,
          iconBgColor: SLColors.info,
          title: context.tr('settings_data_system_label'),
          subtitle: context.tr('settings_data_system_desc'),
          isDark: isDark,
          onTap: () => _togglePanel('dataHealth'),
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.admin_panel_settings_outlined,
          iconBgColor: SLColors.accentPurple,
          title: context.tr('theme_permission_center'),
          subtitle: L10nService().translate('Quản lý cấp quyền hệ thống'),
          isDark: isDark,
          onTap: _isGrantingPermissions ? () {} : _requestAllPermissions,
        ),
      ], isDark),
      _buildSectionTitle(
        context.tr('settings_support_legal_label'),
        topPadding: 22,
      ),
      _buildiOSSectionCard([
        _buildiOSRow(
          icon: Icons.history_rounded,
          iconBgColor: SLColors.info,
          title: L10nService().translate('Lịch sử hoạt động'),
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
          iconBgColor: SLColors.success,
          title: context.tr('support_center'),
          isDark: isDark,
          onTap: _openSupportContact,
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.star_outline_rounded,
          iconBgColor: SLColors.warning,
          title: context.tr('rate_app'),
          isDark: isDark,
          onTap: _rateApp,
        ),
      ], isDark),
      const SizedBox(height: 8),
      _buildiOSSectionCard([
        _buildiOSRow(
          icon: Icons.logout_rounded,
          iconBgColor: SLColors.danger,
          title: context.tr('logout'),
          isDark: isDark,
          isDestructive: true,
          onTap: _logout,
        ),
        _buildDivider(isDark),
        _buildiOSRow(
          icon: Icons.delete_forever_outlined,
          iconBgColor: SLColors.danger,
          title: context.tr('settings_delete_account_data'),
          isDark: isDark,
          isDestructive: true,
          onTap: _deleteAccount,
        ),
      ], isDark),
    ];
  }

  Widget _buildSettingsFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Center(
        child: Column(
          children: [
            Transform.rotate(
              angle: -0.035,
              child: Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SLColors.paper,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: SLColors.border),
                  boxShadow: SLShadow.subtle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SoulLocket',
              style: SLTheme.textStyleForKey(
                'dancingScript',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: SLColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('settings_footer_tagline'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: SLColors.textSecond,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              L10nService().translate('© Bản quyền SoulLocket Hoàng & Tú'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: SLColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            /*
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD81B60).withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              '© ${DateTime.now().year} Tame Trương Việt Hoàng. SoulLocket có bản quyền. Mọi hành vi crack, mod, can thiệp trái phép đều bị nghiêm cấm.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFAD1457).withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
          */
          ],
        ),
      ),
    );
  }

  Widget _buildStandalonePanelPage(String id) {
    final sectionId = _sectionIdForPanel(id);
    final baseTheme = Theme.of(context);
    final settingsTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      dialogTheme: DialogThemeData(
        backgroundColor: SLColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: SLColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SLColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: SLColors.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : SLColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SLColors.primary
              : SLColors.bgMuted,
        ),
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
                            padding: const EdgeInsets.only(top: 4, bottom: 32),
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
          _buildVipPanel(hideBackButton: false),
          _buildIdentityPanel(hideBackButton: true),
          _buildLanguagePanel(hideBackButton: true),
        ]);
      case 'security':
        return _buildSectionStack([
          _buildSecurityPanel(hideBackButton: false),
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
                message: L10nService().translate(
                  'Tiện ích màn hình chỉ hỗ trợ trên thiết bị thật. Phần cấu hình này nên thao tác trên app cài đặt.',
                ),
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
          title: L10nService().translate('Mục đang hoàn thiện'),
          message: L10nService().translate(
            'Tính năng này đang được cập nhật trong phiên bản mới.',
          ),
        );
    }
  }

  Widget _buildSectionStack(List<Widget> panels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: panels,
    );
  }

  Widget _buildUnavailablePanel({
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SLColors.primary.withValues(alpha: 0.18),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: SLColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: SLColors.primaryActive,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SLColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 12,
                        color: SLColors.primaryActive,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('settings_back_btn'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: SLColors.primaryActive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B5563),
              height: 1.45,
            ),
          ),
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
    L10nService().translate('Hello bạn, mình là Chat Thân Thiện đây!'),
    L10nService().translate('Bạn có tâm sự gì không? Kể mình nghe nhé!'),
    L10nService().translate('Bấm vào mình để trò chuyện nha!'),
    L10nService().translate('Hôm nay của bạn thế nào?'),
    L10nService().translate('Mình luôn ở đây để lắng nghe bạn!'),
    L10nService().translate('Bạn đang tìm gì trong cài đặt thế?'),
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
