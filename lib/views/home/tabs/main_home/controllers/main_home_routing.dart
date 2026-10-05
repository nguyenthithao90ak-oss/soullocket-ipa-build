part of '../../main_home_tab.dart';

extension _MainHomeRouting on _MainHomeTabState {
  void _openLoveInsights() {
    if (_houseId == null) return;

    final nameU1 =
        _houseSettings?['nameU1']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU1'].toString().trim()
            : context.tr('home_bn_1fd75b');
    final nameU2 =
        _houseSettings?['nameU2']?.toString().trim().isNotEmpty == true
            ? _houseSettings!['nameU2'].toString().trim()
            : context.tr('home_ngiy_5bab37');
    final avtUser1 = _houseSettings?['avtUser1']?.toString() ?? '';
    final avtUser2 = _houseSettings?['avtUser2']?.toString() ?? '';
    Navigator.push(
      context,
      SLRoute(
        builder: (_) => LoveInsightsScreen(
          houseId: _houseId!,
          nameU1: nameU1,
          nameU2: nameU2,
          avatarU1: avtUser1,
          avatarU2: avtUser2,
          loveDays: _calculateDays(),
          relationshipMode:
              _houseSettings?['relationshipMode']?.toString() ?? 'single',
        ),
      ),
    );
  }

  void _openCoupleConnect() {
    if (_houseId == null) return;
    Navigator.push<bool>(
      context,
      SLRoute<bool>(
        builder: (_) => CoupleConnectScreen(houseId: _houseId!),
      ),
    ).then((connected) {
      if (connected == true && mounted) {
        _fetchHouseData(preserveVisibleState: true);
      }
    });
  }

  void _openSingleMatchHub() {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) return;
    Navigator.push(
      context,
      SLRoute(
        builder: (_) => SingleMatchHubScreen(houseId: houseId),
      ),
    );
  }

  void _openMilestonesDetail() {
    if (_houseId == null) return;
    Navigator.push(
      context,
      SLRoute(
        builder: (_) => MilestonesScreen(
          houseId: _houseId!,
          startDate: _houseSettings?['startDate']?.toString(),
          houseSettings: _houseSettings ?? {},
          homeCalendarEvents: _homeCalendarSnapshotMatchesScope
              ? _homeCalendarEvents : const [],
        ),
      ),
    ).then((_) {
      _fetchHouseData(preserveVisibleState: true);
    });
  }

  Future<void> _openHomeCalendar({
    required String expectedUid,
    required String expectedHouseId,
    HomeCalendarPlan? plan,
  }) async {
    bool isCurrent() =>
        mounted &&
        _auth.currentUser?.uid == expectedUid &&
        _houseId == expectedHouseId;
    if (!isCurrent() || _homeCalendarRouteIsOpen) return;
    if (plan != null &&
        (!_homeCalendarSnapshotMatchesScope ||
            !_homeCalendarEvents.any(
              (row) =>
                  row['id']?.toString() == plan.id &&
                  row['dateKey'] == plan.dateKey,
            ))) {
      return;
    }
    _homeCalendarRouteIsOpen = true;
    _pauseHomeCalendarEvents();
    try {
      await Navigator.of(context).push(
        SLRoute(
          builder: (_) => CalendarScreen(
            houseId: expectedHouseId,
            myName: _resolveMyName(),
            initialDateKey: plan?.dateKey,
          ),
        ),
      );
    } finally {
      _homeCalendarRouteIsOpen = false;
      if (isCurrent() && _isTabActive) {
        _listenHomeCalendarEvents(expectedHouseId);
      }
    }
  }

  Future<void> _openSoulMergeChat() async {
    final houseId = _houseId?.trim() ?? '';
    if (!mounted ||
        houseId.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }

    await Navigator.push(
      context,
      SLRoute(builder: (_) => const SoulMergeScreen()),
    );
  }

  Future<void> _openTogetherHub({required bool isSingle}) async {
    final houseId = _houseId?.trim() ?? '';
    final uid = _auth.currentUser?.uid;
    if (!mounted || houseId.isEmpty || uid == null || _togetherHubIsOpen) return;

    bool isCurrentScope() =>
        mounted && _auth.currentUser?.uid == uid && _houseId == houseId;

    _togetherHubIsOpen = true;
    try {
      await Navigator.of(context).push(
        SLRoute(
          builder: (_) => TogetherHubScreen(
            isSingle: isSingle,
            onOpenActivity: (activity) async {
              if (!isCurrentScope()) return;
              if (activity == TogetherActivity.soulMerge) {
                if (isSingle || _homeToolRelationshipMode() != 'couple') return;
                await _openSoulMergeChat();
                return;
              }

              final Widget? destination = switch (activity) {
                TogetherActivity.soulBlock => const BlockBlastGame(),
                TogetherActivity.drawing => _buildEmbeddedHomeTool('drawing'),
                TogetherActivity.collage => _buildEmbeddedHomeTool('collage'),
                TogetherActivity.soulMerge => null,
              };
              if (destination == null || !isCurrentScope()) return;
              await Navigator.of(context).push(
                SLRoute(builder: (_) => destination),
              );
            },
          ),
        ),
      );
    } finally {
      _togetherHubIsOpen = false;
    }
  }
}
