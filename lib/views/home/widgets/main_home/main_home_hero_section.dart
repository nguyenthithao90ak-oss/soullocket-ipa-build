part of '../../tabs/main_home_tab.dart';

/// Lề hai bên chung cho mọi khối Home: gần sát mép màn hình trên điện thoại
/// (10–12dp, đủ chỗ cho bóng đổ), rộng hơn trên máy tính bảng.
double _homeSidePadding(double width) => width < 340
    ? 10
    : SLResponsive.horizontalPaddingForWidth(
        width,
        compactPadding: 12,
        handsetPadding: 16,
        tabletPadding: 28,
      );

/// Lối đi của bé đồng hành nằm ngay trong lề, cách mép khối 1dp như thiết kế
/// cũ (lối 32 + lề 33) để bé vẫn đi vòng qua cạnh khối được.
double _homeCompanionLane(double sidePadding) => max(0.0, sidePadding - 1);

class _ModernHomeBody extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final String? startDate;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final double circleSize;
  final bool homeShowHouseName;
  final String customBackgroundUrl;
  final bool showDayCounter;
  final bool showLoveTimeDetail;
  final String countdownShapeKey;
  final String countdownStyleKey;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final VoidCallback? onOpenSettings;
  final HomeDisplayStyle displayStyle;

  const _ModernHomeBody({
    required this.state,
    required this.isSingle,
    required this.houseName,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    this.startDate,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    required this.circleSize,
    required this.homeShowHouseName,
    required this.customBackgroundUrl,
    required this.showDayCounter,
    required this.showLoveTimeDetail,
    required this.countdownShapeKey,
    required this.countdownStyleKey,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.onOpenSettings,
    this.displayStyle = HomeDisplayStyle.current,
  });

  @override
  Widget build(BuildContext context) {
    final uiState = UiPrefs.notifier.value;
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: uiState,
      isWeb: kIsWeb,
    );

    // Fullscreen layout mode
    if (displayStyle == HomeDisplayStyle.current &&
        uiState.homeLayoutKey == 'fullscreen') {
      return _FullscreenHomeBody(
        state: state,
        isSingle: isSingle,
        houseName: houseName,
        showHouseName: homeShowHouseName,
        circleValue: circleValue,
        circleTopLabel: circleTopLabel,
        circleBottomLabel: circleBottomLabel,
        nameU1: nameU1,
        nameU2: nameU2,
        avtUser1: avtUser1,
        avtUser2: avtUser2,
        onOpenSettings: onOpenSettings,
      );
    }

    final partnerName = isSingle ? '' : state._resolvePartnerName();
    final petUid = state._auth.currentUser?.uid;
    final petHouseId = state._houseId;
    return PetCareHomeScope(
      uid: petUid,
      houseId: petHouseId,
      appearanceBuilder: (context, care, outfits) => HomePartnerLetterHost(
        houseId: isSingle ? null : state._houseId,
        uid: state._auth.currentUser?.uid,
        partnerName: partnerName,
        builder: (context, letter, openLetter) => _buildCompanionScene(
          context,
          uiState: uiState,
          effectProfile: effectProfile,
          partnerName: partnerName,
          hasLetter: letter != null,
          openLetter: openLetter,
          petCare: care,
          petOutfits: outfits,
        ),
      ),
    );
  }

  /// Bé đại diện người ấy ngủ gật khi offline quá 30 phút.
  HomeCompanionPartnerStatus _companionPartnerStatus() {
    if (isSingle) return HomeCompanionPartnerStatus.unknown;
    final role = state._partnerRole;
    final data = state._presenceForRole(role);
    if (data == null) return HomeCompanionPartnerStatus.unknown;
    if (PresenceService.isSleeping(data)) {
      return HomeCompanionPartnerStatus.away;
    }
    if (state._isRoleOnline(role)) return HomeCompanionPartnerStatus.online;
    final lastSeen = state._readEpochMs(data['lastSeen']);
    if (lastSeen == null) return HomeCompanionPartnerStatus.away;
    final idle = DateTime.now().millisecondsSinceEpoch - lastSeen;
    return idle > const Duration(minutes: 30).inMilliseconds
        ? HomeCompanionPartnerStatus.away
        : HomeCompanionPartnerStatus.unknown;
  }

  void _openPetCare(BuildContext context) {
    if (!state.mounted || !context.mounted) return;
    slPushRoute<void>(
      context,
      SLRoute<void>(
        builder: (_) => PetCareGameScreen(
          houseId: state._houseId,
          ownedPet: petCareOwnedPetForRole(
            state._currentRole,
            genderSwapped: RoleUtils.readGenderSwapped(state._houseSettings),
          ),
        ),
        settings: const RouteSettings(name: 'pet_care_game'),
      ),
      identity: const ValueKey('pet_care_game'),
      rootNavigator: true,
    );
  }

  Widget _buildCompanionScene(
    BuildContext context, {
    required UiPrefsState uiState,
    required UiEffectProfile effectProfile,
    required String partnerName,
    required bool hasLetter,
    required VoidCallback openLetter,
    required ValueListenable<Map<PetCarePet, PetCareVitals>> petCare,
    required ValueListenable<Map<PetCarePet, PetCareOutfit>> petOutfits,
  }) {
    final sidePadding = _homeSidePadding(MediaQuery.sizeOf(context).width);
    final companionLane = _homeCompanionLane(sidePadding);
    return HomeCompanionScene(
      followScroll: true,
      calm: true,
      guestVisits: true,
      petCare: petCare,
      petOutfits: petOutfits,
      onOpenPetCare: () => _openPetCare(context),
      partnerStatusListenable: _PartnerStatusListenable(
        state._presenceDataNotifier,
        _companionPartnerStatus,
      ),
      partnerName: partnerName,
      partnerIsBunny: RoleUtils.isFemaleRole(
        state._partnerRole,
        genderSwapped: RoleUtils.readGenderSwapped(state._houseSettings),
      ),
      partnerHasLetter: hasLetter,
      onOpenPartnerLetter: openLetter,
      enabled: uiState.homeCompanionEnabled,
      soundEnabled: uiState.homeCompanionSoundEnabled,
      maxVisibleCharacters: 2,
      audioSuppressed: SoundService().companionSuppressed,
      animate: effectProfile.animationEnabled && !state._deferHeavyHomeMotion,
      isActive: state.widget.isActiveListenable,
      isScrolling: state._isScrollingNotifier,
      isSwiping: state.widget.isSwipingListenable,
      captureMode: UiPrefs.captureModeNotifier,
      foreground: _MainHomeHeroHeader(
        state: state,
        isSingle: isSingle,
        onOpenSettings: onOpenSettings,
        firstGuideSettingsKey: state.widget.firstGuideSettingsKey,
      ),
      safeInsets: EdgeInsets.fromLTRB(
        companionLane,
        max(
          MediaQuery.paddingOf(context).top + 60,
          HomeCompanionPainter.topClearance,
        ),
        companionLane,
        MediaQuery.paddingOf(context).bottom + 92,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: displayStyle == HomeDisplayStyle.current
                ? _HomeScrapbookBackdrop(
                    hasCustomBackground: customBackgroundUrl.trim().isNotEmpty,
                  )
                : HomeDisplayBackdrop(
                    style: displayStyle,
                    hasCustomBackground: customBackgroundUrl.trim().isNotEmpty,
                  ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Mọi khối dùng chung lề này để rộng gần sát mép trên mọi máy.
              final horizontalPadding = sidePadding;
              final contentWidth = SLResponsive.maxContentWidthForWidth(
                constraints.maxWidth,
                handsetMax: 540,
                tabletMax: 700,
                desktopMax: 760,
              );
              final availableContentWidth = min(
                contentWidth,
                max(0, constraints.maxWidth - (horizontalPadding * 2)),
              );
              final responsiveCircleSize = min(
                circleSize,
                max(200, availableContentWidth - 4),
              ).toDouble();
              Widget buildCountdown(bool isSwiping) {
                final int currentDays = int.tryParse(circleValue) ?? 0;
                final bool isMilestone =
                    currentDays > 0 &&
                    (currentDays % 100 == 0 ||
                        currentDays % 30 == 0 ||
                        currentDays % 365 == 0);
                final bool enableMotionBase =
                    effectProfile.animationEnabled &&
                    !state._deferHeavyHomeMotion &&
                    !isSwiping;

                final countdown = RepaintBoundary(
                  child: _MainHomeHeroCountdownSection(
                    state: state,
                    isSingle: isSingle,
                    houseName: houseName,
                    smartGreeting: smartGreeting,
                    circleValue: circleValue,
                    circleTopLabel: circleTopLabel,
                    circleBottomLabel: circleBottomLabel,
                    startDate: startDate,
                    circleSize: responsiveCircleSize,
                    homeShowHouseName: homeShowHouseName,
                    showDayCounter: showDayCounter,
                    showLoveTimeDetail: showLoveTimeDetail,
                    countdownShapeKey: countdownShapeKey,
                    countdownStyleKey: countdownStyleKey,
                    isMilestone: isMilestone,
                    enableMotionBase: enableMotionBase,
                    isScrollingNotifier: state._isScrollingNotifier,
                    onEditStartDate: onEditStartDate,
                    onEditTopLabel: onEditTopLabel,
                    onEditBottomLabel: onEditBottomLabel,
                    firstGuideHeroKey: state.widget.firstGuideHeroKey,
                  ),
                );
                return countdown;
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    state._isScrollingNotifier.value = true;
                    globalScrollingNotifier.value = true;
                  } else if (notification is ScrollEndNotification) {
                    state._isScrollingNotifier.value = false;
                    globalScrollingNotifier.value = false;
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  // Offset cuộn phải tách theo tài khoản/kiểu, không dùng chung
                  // ô PageStorage với trạng thái mở chi tiết hồ sơ bên dưới.
                  key: PageStorageKey<String>(
                    'home-display-scroll-${state._auth.currentUser?.uid ?? 'guest'}-${displayStyle.storageKey}',
                  ),
                  physics: SLResponsive.scrollPhysicsForPlatform(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: uiState.homeCompanionEnabled
                                ? max(
                                    MediaQuery.paddingOf(context).top + 62,
                                    HomeCompanionPainter.topClearance + 2,
                                  )
                                : MediaQuery.paddingOf(context).top + 62,
                          ),
                          if (displayStyle != HomeDisplayStyle.current)
                            _buildDisplayContent(context)
                          else ...[
                            // Cặp đôi: lời nhắn chung đồng bộ thay cho lời chào tự động.
                            if (!isSingle &&
                                (state._houseId?.isNotEmpty ?? false)) ...[
                              if (homeShowHouseName &&
                                  houseName.trim().isNotEmpty)
                                HomeCompactHeader(title: houseName),
                              HomeCompanionContentArea(
                                child: HomeSharedNoteHeader(
                                  houseId: state._houseId!,
                                  partnerName: state._resolvePartnerName(),
                                ),
                              ),
                            ] else
                              HomeCompactHeader(
                                title:
                                    homeShowHouseName &&
                                        houseName.trim().isNotEmpty
                                    ? houseName
                                    : smartGreeting,
                                subtitle:
                                    homeShowHouseName &&
                                        houseName.trim().isNotEmpty
                                    ? smartGreeting
                                    : null,
                              ),
                            SLSpacing.h16,
                            state._buildGettingStartedChecklist(
                              isSingle: isSingle,
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: state.widget.isSwipingListenable == null
                                  ? buildCountdown(false)
                                  : ValueListenableBuilder<bool>(
                                      valueListenable:
                                          state.widget.isSwipingListenable!,
                                      builder: (context, isSwiping, _) =>
                                          buildCountdown(isSwiping),
                                    ),
                            ),
                            SLSpacing.h12,
                            RepaintBoundary(
                              // Chế độ độc thân không dựng vòng đếm; hướng dẫn
                              // cần khoanh thẻ đại diện đang hiển thị thay thế.
                              key: showDayCounter
                                  ? null
                                  : state.widget.firstGuideHeroKey,
                              child: state._buildModernAvatarSection(
                                isSingle: isSingle,
                                nameU1: nameU1,
                                nameU2: nameU2,
                                avtUser1: avtUser1,
                                avtUser2: avtUser2,
                              ),
                            ),
                            SLSpacing.h16,
                            RepaintBoundary(
                              child: _ChatReminderBanner(
                                state: state,
                                isSingle: isSingle,
                              ),
                            ),
                            // Trạm Mây mở cho bản chính thức theo yêu cầu chủ dự
                            // án 23/10/2026 (trước đó chỉ hiện ở debug).
                            PetCareEntryCard(
                              pet:
                                  petCareOwnedPetForRole(
                                    state._currentRole,
                                    genderSwapped: RoleUtils.readGenderSwapped(
                                      state._houseSettings,
                                    ),
                                  ) ??
                                  PetCarePet.bear,
                              onTap: () => _openPetCare(context),
                            ),
                            SLSpacing.h12,
                            // Hàng nút nhanh (Nhật ký, Nhắn ngay, Lịch chung,
                            // Chơi cùng, Ghim thêm) đã gỡ khỏi Home theo yêu cầu
                            // chủ dự án 12/10/2026 cho đỡ chật.
                            RepaintBoundary(
                              child: state._buildCompactUpcoming(
                                startDate: startDate,
                                isSingle: isSingle,
                              ),
                            ),
                            SLSpacing.h16,
                            RepaintBoundary(
                              child: state._buildCompactBento(
                                isSingle: isSingle,
                              ),
                            ),
                          ],
                          SLSpacing.gapH(
                            uiState.homeCompanionEnabled ? 100 : 86,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayContent(BuildContext context) {
    final hasHouse = state._houseId?.isNotEmpty ?? false;
    final palette = HomeDisplayPalette.of(context, displayStyle);
    final heading = HomeDisplayHeading(
      style: displayStyle,
      houseName: homeShowHouseName ? houseName : null,
      title: isSingle ? smartGreeting : null,
    );
    final note = !isSingle && hasHouse
        ? HomeDisplayNoteSurface(
            style: displayStyle,
            child: HomeCompanionContentArea(
              child: HomeSharedNoteHeader(
                houseId: state._houseId!,
                partnerName: state._resolvePartnerName(),
                textStyle: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
    final details = RepaintBoundary(
      child: state._buildModernAvatarSection(
        isSingle: isSingle,
        nameU1: nameU1,
        nameU2: nameU2,
        avtUser1: avtUser1,
        avtUser2: avtUser2,
      ),
    );
    final dayBadge = showDayCounter
        ? HomeDisplayDaySummary(
            style: displayStyle,
            value: circleValue,
            topLabel: circleTopLabel,
            bottomLabel: circleBottomLabel,
            onEditValue: onEditStartDate,
            onEditTopLabel: onEditTopLabel,
            onEditBottomLabel: onEditBottomLabel,
            onCustomize: state._showCountdownQuickCustomizeSheet,
          )
        : null;
    Widget? photo(String name, String url, bool left) {
      if (url.trim().isEmpty) return null;
      return Semantics(
        button: true,
        label: name,
        child: GestureDetector(
          onTap: () => state._changeAvatar(isUser1: left),
          onLongPress: () => state._changeAvatar(isUser1: left),
          child: SizedBox.square(
            dimension: 112,
            child: _StableAvatarNetworkImage(
              imageUrl: url,
              female: !left,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    final hero = HomeCompanionAnchor(
      id: 'home-countdown',
      shape: HomeCompanionSurfaceShape.ledge,
      child: RepaintBoundary(
        key: state.widget.firstGuideHeroKey,
        child: HomeDisplayHero(
          style: displayStyle,
          nameU1: nameU1,
          nameU2: nameU2,
          avtUser1: avtUser1,
          avtUser2: avtUser2,
          isSingle: isSingle,
          dayBadge: dayBadge,
          leftAvatar: photo(nameU1, avtUser1, true),
          rightAvatar: isSingle ? null : photo(nameU2, avtUser2, false),
          onTapLeftAvatar: () => state._changeAvatar(isUser1: true),
          onTapRightAvatar: isSingle
              ? state._openSingleMatchHub
              : () => state._changeAvatar(isUser1: false),
          onEditLeftName: () =>
              state._showEditNameDialog(isUser1: true, currentName: nameU1),
          onEditRightName: isSingle
              ? null
              : () => state._showEditNameDialog(
                  isUser1: false,
                  currentName: nameU2,
                ),
          footer: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: isSingle
                  ? state._openSingleMatchHub
                  : state._openSoulMergeChat,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: palette.accent,
              ),
              icon: Icon(
                isSingle
                    ? Icons.favorite_border_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 18,
              ),
              label: Text(
                context.tr(
                  isSingle ? 'sm_find_people' : 'main_home_chat_now',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final compactCountdown = showLoveTimeDetail
        ? _MainHomeHeroCounters(state: state, startDate: startDate)
        : const SizedBox.shrink();
    return HomeDisplayLayout(
      style: displayStyle,
      heading: heading,
      note: note,
      checklist: state._buildGettingStartedChecklist(isSingle: isSingle),
      profile: hero,
      details: details,
      countdown: compactCountdown,
      compactCountdown: compactCountdown,
      reminder: _ChatReminderBanner(state: state, isSingle: isSingle),
      pet: HomeDisplayPetEntry(
        style: displayStyle,
        onTap: () => _openPetCare(context),
      ),
      upcoming: RepaintBoundary(
        child: state._buildCompactUpcoming(
          startDate: startDate,
          isSingle: isSingle,
          displayStyle: displayStyle,
        ),
      ),
      bento: RepaintBoundary(
        child: state._buildCompactBento(isSingle: isSingle),
      ),
    );
  }
}

extension _MainHomeTabHeroSection on _MainHomeTabState {}

class _ChatReminderBanner extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;

  const _ChatReminderBanner({required this.state, required this.isSingle});

  @override
  Widget build(BuildContext context) {
    if (isSingle) return const SizedBox.shrink();
    final ts = state._lastChatMessageTs;
    if (ts <= 0) return const SizedBox.shrink();
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - ts;
    const oneDayMs = 86400000;
    const threeDaysMs = 259200000;
    if (diffMs < oneDayMs || diffMs > threeDaysMs) {
      return const SizedBox.shrink();
    }

    final days = (diffMs / oneDayMs).floor();
    final label = days == 1
        ? context.tr('main_home_chat_reminder_today')
        : L10nService().format('main_home_chat_reminder_days', {'days': days});

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _HomeScrapbookCard(
        companionId: 'home-chat-reminder',
        accentColor: SLColors.thread,
        color: SLColors.paperPeach,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SLColors.paper,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: SLColors.borderLight),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.mail_rounded, size: 20, color: SLColors.thread),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 8,
                      color: SLColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: SLColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: context.tr('main_home_chat_now'),
              child: Material(
                color: SLColors.primary,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: state._openSoulMergeChat,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái người ấy cho bé thỏ, tính lại mỗi khi presence đổi mà không
/// dựng lại nội dung Home (chỉ chuyển tiếp listener của notifier gốc).
class _PartnerStatusListenable
    extends ValueListenable<HomeCompanionPartnerStatus> {
  _PartnerStatusListenable(this._source, this._resolve);

  final Listenable _source;
  final HomeCompanionPartnerStatus Function() _resolve;

  @override
  HomeCompanionPartnerStatus get value => _resolve();

  @override
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);
}
