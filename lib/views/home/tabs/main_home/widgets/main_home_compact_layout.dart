part of '../../main_home_tab.dart';

/// Các khối gọn của trang Nhà: nút nhanh, "Sắp tới" và cặp thẻ bản đồ/hành trình.
extension _MainHomeCompactLayout on _MainHomeTabState {
  List<HomeQuickAction> _buildHomeQuickActions({required bool isSingle}) {
    final houseId = (_houseId ?? '').trim();
    final uid = _auth.currentUser?.uid;
    if (houseId.isEmpty || uid == null) return const <HomeQuickAction>[];

    final actions = <HomeQuickAction>[
      if (widget.onOpenDiary != null)
        HomeQuickAction(
          id: 'diary',
          label: context.tr('nav_diary'),
          stickerId: 'photo',
          fallbackIcon: Icons.photo_camera_back_outlined,
          onTap: widget.onOpenDiary!,
        ),
      if (!isSingle)
        HomeQuickAction(
          id: 'chat',
          label: context.tr('main_home_chat_now'),
          stickerId: 'friendly_chat',
          fallbackIcon: Icons.chat_bubble_outline_rounded,
          onTap: () => unawaited(_openSoulMergeChat()),
        ),
      if (!isSingle)
        HomeQuickAction(
          id: 'calendar',
          label: context.tr('utility_title_calendar'),
          stickerId: 'calendar',
          fallbackIcon: Icons.calendar_month_outlined,
          onTap: () => unawaited(
            _openHomeCalendar(expectedUid: uid, expectedHouseId: houseId),
          ),
        ),
      if (isSingle)
        HomeQuickAction(
          id: 'pairing',
          label: context.tr('pairing_connect_now'),
          stickerId: 'wish',
          fallbackIcon: Icons.favorite_border_rounded,
          onTap: () =>
              unawaited(slPush(context, const PairingDashboardScreen())),
        ),
      HomeQuickAction(
        id: 'together',
        label: context.tr(
          isSingle ? 'together_hub_solo_title' : 'together_hub_title',
        ),
        stickerId: 'surprise',
        fallbackIcon: Icons.interests_outlined,
        onTap: () => unawaited(_openTogetherHub(isSingle: isSingle)),
      ),
    ];

    final mode = _homeToolRelationshipMode();
    final fixedIds = actions.map((action) => action.id).toSet();
    for (final app in _pinnedApps) {
      if (fixedIds.contains(app.id)) continue;
      if (!UtilityService.isUtilityAllowed(app.id, mode)) continue;
      actions.add(
        HomeQuickAction(
          id: 'pin-${app.id}',
          label: app.localizedTitle,
          stickerId: app.id,
          fallbackIcon: app.icon,
          isPinned: true,
          onTap: () => _onPinnedAppTap(app),
        ),
      );
    }
    return actions;
  }

  Widget _buildCompactQuickActions({required bool isSingle}) {
    final actions = _buildHomeQuickActions(isSingle: isSingle);
    if (actions.isEmpty) return const SizedBox.shrink();
    return HomeQuickActionsRow(
      actions: actions,
      onAddPin: () => unawaited(_showHomePinPicker()),
    );
  }

  Future<void> _showHomePinPicker() async {
    final apps = UtilityService.appsForMode(_homeToolRelationshipMode());
    final pinnedIds = {for (final app in _pinnedApps) app.id};
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: SLColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.78,
        child: StatefulBuilder(
          builder: (builderContext, setSheetState) => HomePinPickerSheet(
            apps: apps,
            pinnedIds: pinnedIds,
            onToggle: (app) async {
              final pinned = await _utilityService.togglePinApp(app.id);
              if (!builderContext.mounted) return;
              setSheetState(() {
                if (pinned) {
                  pinnedIds.add(app.id);
                } else {
                  pinnedIds.remove(app.id);
                }
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactUpcoming({
    required String? startDate,
    required bool isSingle,
  }) {
    final houseId = (_houseId ?? '').trim();
    final uid = _auth.currentUser?.uid;
    final now = CalendarTimeZone.fromMilliseconds(
      DateTime.now().millisecondsSinceEpoch,
      MarketService.instance.preferences.timeZoneId,
    );
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final displayFormat = CalendarDisplayFormat.forLocale(
      Localizations.localeOf(context),
      MarketService.instance.marketCode,
    );

    String relativeDays(DateTime date) {
      final days = CalendarCivilDate.daysBetween(todayMidnight, date);
      if (days <= 0) return context.tr('home_hmnay_d87b33');
      if (days == 1) return context.tr('home_ngymai_a3d820');
      return L10nService().format('home_days_later', {'n': days});
    }

    final dated = <(DateTime, HomeUpcomingItem)>[];

    // Kế hoạch trong Lịch chung (chế độ đôi); chế độ một người đã gộp sẵn
    // trong danh sách kỷ niệm bên dưới.
    if (!isSingle &&
        uid != null &&
        houseId.isNotEmpty &&
        _homeCalendarSnapshotMatchesScope) {
      for (final plan in HomeCalendarPlan.upcoming(
        _homeCalendarEvents,
        now: now,
      )) {
        final date = CalendarCivilDate.parse(plan.dateKey);
        if (date == null) continue;
        final timing = plan.timing;
        final timeText = timing == null
            ? context.tr('calendar_all_day')
            : displayFormat.time(
                timing.start,
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
                use24HourFormat:
                    MarketService.instance.preferences.use24HourFormat,
              );
        dated.add((
          date,
          HomeUpcomingItem(
            id: 'plan-${plan.identity}',
            title: plan.title,
            when: '${relativeDays(date)} · $timeText',
            stickerId: 'calendar',
            fallbackIcon: Icons.event_outlined,
            onTap: () => unawaited(
              _openHomeCalendar(
                expectedUid: uid,
                expectedHouseId: houseId,
                plan: plan,
              ),
            ),
          ),
        ));
      }
    }

    final collected = _collectHomeUpcomingEvents(
      startDate: startDate,
      todayMidnight: todayMidnight,
    );
    for (final event in collected.events) {
      if (event.date.isBefore(todayMidnight)) continue;
      final stickerId = switch (event.type) {
        'birthday' => 'gift',
        'holiday' => 'surprise',
        'calendar' => 'calendar',
        _ => 'love_card',
      };
      dated.add((
        event.date,
        HomeUpcomingItem(
          id: '${event.type}-${event.title}-${event.date.millisecondsSinceEpoch}',
          title: event.title,
          when:
              '${displayFormat.shortDate(event.date)} · ${relativeDays(event.date)}',
          stickerId: stickerId,
          fallbackIcon: Icons.celebration_outlined,
          onTap: _openMilestonesDetail,
        ),
      ));
    }

    dated.sort((a, b) => a.$1.compareTo(b.$1));
    final seen = <String>{};
    final items = <HomeUpcomingItem>[
      for (final entry in dated)
        if (seen.add(entry.$2.id)) entry.$2,
    ];

    final calendarFailed =
        !isSingle && _homeCalendarLoadState == HomeCalendarLoadState.failed;
    return HomeUpcomingCard(
      items: items,
      onSeeAll: _openMilestonesDetail,
      statusText: calendarFailed
          ? context.tr(
              items.isEmpty
                  ? 'home_upcoming_error'
                  : 'home_upcoming_cached_error',
            )
          : null,
      onRetry: calendarFailed && houseId.isNotEmpty
          ? () {
              if (!mounted ||
                  _auth.currentUser?.uid != uid ||
                  _houseId != houseId) {
                return;
              }
              _listenHomeCalendarEvents(houseId);
            }
          : null,
    );
  }

  Widget _buildCompactBento({required bool isSingle}) {
    final insight = HomeInsightMiniCard(
      data: _insightData,
      isSingle: isSingle,
      onTap: () => unawaited(_handleInsightCardTap()),
    );
    if (isSingle) return insight;

    final map = AnimatedBuilder(
      animation: Listenable.merge([
        _homeDistanceTextNotifier,
        _homeMapAlertNotifier,
        _homeMapMyPointNotifier,
        _homeMapPartnerPointNotifier,
      ]),
      builder: (context, _) => HomeMapMiniCard(
        title: context.tr('home_bncahaia_12dcb1'),
        distanceText: _homeDistanceTextNotifier.value,
        detailText: _homeMapAlertNotifier.value,
        myPoint: _homeMapMyPointNotifier.value,
        partnerPoint: _homeMapPartnerPointNotifier.value,
        myAvatarUrl: _resolveAvatarForRole(_currentRole),
        partnerAvatarUrl: _resolveAvatarForRole(_partnerRole),
        myFemale: RoleUtils.isFemaleRole(
          _currentRole,
          genderSwapped: RoleUtils.readGenderSwapped(_houseSettings),
        ),
        partnerFemale: RoleUtils.isFemaleRole(
          _partnerRole,
          genderSwapped: RoleUtils.readGenderSwapped(_houseSettings),
        ),
        onTap: () => unawaited(_handleMapCardTap()),
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: map),
          const SizedBox(width: 12),
          Expanded(child: insight),
        ],
      ),
    );
  }
}
