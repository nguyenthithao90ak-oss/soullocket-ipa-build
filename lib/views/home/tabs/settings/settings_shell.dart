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
      _showToast(context.tr('settings_loading_data'), success: false);
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
      await slPush(
        context,
        _buildStandalonePanelPage(sectionId),
      );
    } finally {
      if (shouldAnimateWidgetPreview) {
        _stopWidgetPreviewTicker();
      }
      _hasActiveStandalonePanel = false;
    }
  }

  String _resolveSettingsMyName() {
    return _activeRoleKey == 'user2' ? _nameU2 : _nameU1;
  }

  Set<String> _settingsSearchableUtilityIds() {
    final houseId = (_houseId ?? '').trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final ids = <String>{
      'store',
      'calculator',
    };

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
      'gift',
      'giftcode',
      'diary_export',
      'tarot',
      'collage',
      'age_zodiac',
      'creative_diary',
    });

    if (currentUid != null && currentUid.isNotEmpty) {
      ids.add('love_card');
    }

    return ids;
  }

  Future<void> _openSearchResultFromSettings(dynamic result) async {
    final action = result.actionId as String;
    if (action == 'history') {
      await slPush(
        context,
        HistoryScreen(houseId: _houseId ?? ''),
      );
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
      case 'calculator':
        screen = const CalculatorScreen();
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
      case 'gift':
        screen = houseId.isEmpty
            ? null
            : GiftMakerScreen(houseId: houseId, myName: myName);
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
                myName: myName);
        break;
      case 'collage':
        screen = houseId.isEmpty ? null : CollageMakerScreen(houseId: houseId);
        break;
      case 'age_zodiac':
        screen = houseId.isEmpty ? null : AgeZodiacScreen(houseId: houseId);
        break;
      case 'love_card':
        screen = houseId.isEmpty || currentUid == null || currentUid.isEmpty
            ? null
            : LoveCardScreen(houseId: houseId, myUid: currentUid);
        break;
      case 'creative_diary':
        screen = houseId.isEmpty ? null : CreativeDiaryScreen(houseId: houseId);
        break;
    }

    if (screen == null) {
      return;
    }

    await slPush(
      context,
      screen,
    );
  }

  Widget _buildSettingsScaffold() {
    return _buildResponsiveSettingsScaffold();
  }

  Widget _buildResponsiveSettingsScaffold() {
    final uiState = UiPrefs.notifier.value;
    final isDark = uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';

    final double headerHeight = MediaQuery.paddingOf(context).top + 52;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
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
                            _buildNewSettingsList(isDark),
                            const SizedBox(height: 18),
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
    final isDark = uiState.themeKey == 'theme-night' ||
        uiState.themeKey == 'theme-dark' ||
        uiState.themeKey == 'theme-true-black';
    final headerBgColor =
        (isDark ? Colors.black : _kSettingsHeaderBg).withValues(alpha: 0.65);

    return RepaintBoundary(
      child: ClipRect(
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          fallbackColor: isDark ? Colors.black87 : _kSettingsHeaderBg,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              14,
              MediaQuery.paddingOf(context).top + 4,
              14,
              8,
            ),
            decoration: BoxDecoration(
              color: headerBgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border(
                bottom: BorderSide(
                  color: _kSettingsHeaderBorder.withValues(alpha: 0.45),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kSettingsHeaderSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _kSettingsHeaderBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: SLColors.primaryActive,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SLTheme.titleGradient(context.tr('settings'),
                      fontSize: 18),
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
        ),
      ),
    );
  }

  Widget _buildSettingsSyncBanner() {
    return const SizedBox(height: 8);
  }

  Widget _buildiOSSectionCard(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildiOSRow({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    bool isDark = false,
    bool isDestructive = false,
  }) {
    final textColor = isDestructive 
        ? const Color(0xFFD32F2F) 
        : (isDark ? Colors.white : const Color(0xFF243041));
        
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDestructive ? const Color(0xFFFFEBEE) : iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDestructive ? const Color(0xFFD32F2F) : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[500] : const Color(0xFF7B8794),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isDestructive)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[700] : const Color(0xFFCFD8DC),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 0.5, 
        thickness: 0.5, 
        color: isDark ? Colors.grey[800] : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildNewSettingsList(bool isDark) {
    return Column(
      children: [
        _buildiOSSectionCard([
          _buildiOSRow(
            icon: Icons.manage_accounts_rounded,
            iconBgColor: const Color(0xFFF6CB63),
            title: context.tr('settings_account_label'),
            subtitle: context.tr('settings_account_desc'),
            isDark: isDark,
            onTap: () => _togglePanel('account'),
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.link_rounded,
            iconBgColor: const Color(0xFFD81B60),
            title: 'Ghép nối tổ ấm',
            subtitle: 'Tham gia không gian chung với người ấy',
            isDark: isDark,
            onTap: () => JoinHouseDialog.show(context),
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.palette_rounded,
            iconBgColor: const Color(0xFF8ABAF5),
            title: context.tr('theme'),
            subtitle: context.tr('settings_theme_desc'),
            isDark: isDark,
            onTap: () => _togglePanel('theme'),
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.widgets_rounded,
            iconBgColor: const Color(0xFF73D5CC),
            title: context.tr('settings_widget_label'),
            subtitle: kIsWeb ? context.tr('settings_widget_desc_web') : context.tr('settings_widget_desc_mobile'),
            isDark: isDark,
            onTap: () => _togglePanel('widget'),
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.timelapse_rounded,
            iconBgColor: const Color(0xFFF1B58E),
            title: context.tr('settings_countdown_space_label'),
            subtitle: context.tr('settings_countdown_space_desc'),
            isDark: isDark,
            onTap: () => _togglePanel('countdownMode'),
          ),
        ], isDark),

        _buildSectionTitle(context.tr('settings_security_label'), topPadding: 16),
        _buildiOSSectionCard([
          _buildiOSRow(
            icon: Icons.shield_rounded,
            iconBgColor: const Color(0xFFFFA8BF),
            title: context.tr('settings_security_label'),
            subtitle: context.tr('settings_security_desc'),
            isDark: isDark,
            onTap: () => _togglePanel('security'),
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.notifications_active_rounded,
            iconBgColor: const Color(0xFFA4D7A9),
            title: '${context.tr('settings_notifications_label')} & Tương tác',
            subtitle: 'Quản lý thông báo, lời nhắc kỷ niệm',
            isDark: isDark,
            onTap: () => _togglePanel('notifications'),
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.hub_rounded,
            iconBgColor: const Color(0xFF90CAF9),
            title: context.tr('settings_data_system_label'),
            subtitle: context.tr('settings_data_system_desc'),
            isDark: isDark,
            onTap: () => _togglePanel('dataHealth'),
          ),
        ], isDark),

        _buildSectionTitle(context.tr('settings_other_features_title'), topPadding: 16),
        _buildiOSSectionCard([
          if (_relationshipMode != 'single') ...[
            _buildiOSRow(
              icon: Icons.swap_horiz_rounded,
              iconBgColor: const Color(0xFF42A5F5),
              title: _activeRoleKey == 'user1' ? context.tr('settings_swap_role_to_female') : context.tr('settings_swap_role_to_male'),
              isDark: isDark,
              onTap: _swapUserRole,
            ),
            _buildDivider(isDark),
          ],
          _buildiOSRow(
            icon: Icons.support_agent_rounded,
            iconBgColor: const Color(0xFF4FC3F7),
            title: context.tr('support_center'),
            isDark: isDark,
            onTap: _openSupportContact,
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.star_rate_rounded,
            iconBgColor: const Color(0xFFFFD54F),
            title: context.tr('rate_app'),
            isDark: isDark,
            onTap: _rateApp,
          ),
        ], isDark),

        _buildiOSSectionCard([
          _buildiOSRow(
            icon: Icons.logout_rounded,
            iconBgColor: const Color(0xFFFF8A65),
            title: context.tr('logout'),
            isDark: isDark,
            isDestructive: true,
            onTap: _logout,
          ),
          _buildDivider(isDark),
          _buildiOSRow(
            icon: Icons.delete_forever_rounded,
            iconBgColor: const Color(0xFFB71C1C),
            title: context.tr('settings_delete_account_data'),
            isDark: isDark,
            isDestructive: true,
            onTap: _deleteAccount,
          ),
        ], isDark),
      ],
    );
  }

  Widget _buildSettingsFooter() {
    return Center(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'SoulLocket',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF526071),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('settings_footer_tagline'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7B8794),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© Bản quyền SoulLocket Hoàng & Tú',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AA5B1),
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
    );
  }

  Widget _buildStandalonePanelPage(String id) {
    final sectionId = _sectionIdForPanel(id);
    return Stack(
      fit: StackFit.expand,
      children: [
        const _SettingsBackgroundLayer(),
        ValueListenableBuilder<int>(
          valueListenable: _panelRebuildNotifier,
          builder: (context, _, __) {
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
                            tabletMax: 980,
                            desktopMax: 1080,
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 0, bottom: 24),
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
                message:
                    'Tiện ích màn hình chỉ hỗ trợ trên thiết bị thật. Phần cấu hình này nên thao tác trên app cài đặt.',
              )
            : _buildSectionStack([
                _buildWidgetPanel(hideBackButton: false),
              ]);
      case 'notifications':
        return _buildSectionStack([
          _buildAdvancedPanel(hideBackButton: false),
        ]);
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
          title: 'Mục đang hoàn thiện',
          message: 'Tính năng này đang được cập nhật trong phiên bản mới.',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
