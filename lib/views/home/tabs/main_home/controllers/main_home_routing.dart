part of '../../main_home_tab.dart';

extension _MainHomeRouting on _MainHomeTabState {
  String _coupleDecorScope() =>
      '${_auth.currentUser?.uid ?? ''}|${_houseId ?? ''}';

  Future<HomeCoupleCardDecor> _coupleDecorWithVipAccess(
    HomeCoupleCardDecor decor,
  ) async {
    if (!HomeCoupleDecorCatalog.isVipFrame(decor.frameKey)) return decor;
    final isVip = await PurchaseService()
        .isVip()
        .timeout(const Duration(seconds: 5), onTimeout: () => false)
        .catchError((_) => false);
    return decor.withFrameAccess(isVip: isVip);
  }

  void _bindCoupleDecorSync({
    required String uid,
    required String houseId,
    required String scope,
    required int serial,
  }) {
    _homeCoupleDecorSubscription?.cancel();
    _homeCoupleDecorSubscription = _homeCoupleDecorSync
        .watch(
          uid: uid,
          houseId: houseId,
          isCurrent: () =>
              mounted &&
              _isTabActive &&
              serial == _homeCoupleDecorLoadSerial &&
              _coupleDecorScope() == scope,
        )
        .listen((snapshot) {
          if (snapshot.revision <= 0 ||
              !mounted ||
              serial != _homeCoupleDecorLoadSerial ||
              _coupleDecorScope() != scope) {
            return;
          }
          unawaited(
            _coupleDecorWithVipAccess(snapshot.decor).then((decor) {
              if (!mounted ||
                  serial != _homeCoupleDecorLoadSerial ||
                  _coupleDecorScope() != scope) {
                return;
              }
              _homeCoupleDecorRevision = snapshot.revision;
              _homeCoupleDecorLoadFuture = Future.value(decor);
              _safeSetState(() => _homeCoupleDecor = decor);
            }),
          );
        });
  }

  void _ensureCoupleDecorLoaded() {
    final uid = _auth.currentUser?.uid?.trim() ?? '';
    final houseId = _houseId?.trim() ?? '';
    final scope = '$uid|$houseId';
    if (uid.isEmpty || houseId.isEmpty || !_isTabActive) return;
    if (scope == _homeCoupleDecorScope && _homeCoupleDecorLoadStarted) return;
    _homeCoupleDecorScope = scope;
    _homeCoupleDecorLoadStarted = true;
    _homeCoupleDecor = HomeCoupleCardDecor.defaultValue();
    _homeCoupleDecorRevision = 0;
    final serial = ++_homeCoupleDecorLoadSerial;
    _bindCoupleDecorSync(
      uid: uid,
      houseId: houseId,
      scope: scope,
      serial: serial,
    );
    _homeCoupleDecorLoadFuture = _homeCoupleDecorSync
        .loadForScope(uid: uid, houseId: houseId)
        .then((snapshot) async {
          if (snapshot.revision > 0) _homeCoupleDecorRevision = snapshot.revision;
          return _coupleDecorWithVipAccess(snapshot.decor);
        });
    unawaited(
      _homeCoupleDecorLoadFuture!.then((decor) {
        if (!mounted ||
            _coupleDecorScope() != scope ||
            serial != _homeCoupleDecorLoadSerial) {
          return;
        }
        _safeSetState(() => _homeCoupleDecor = decor);
      }),
    );
  }

  void _openCoupleDecorEditor() {
    unawaited(
      _homeRouteGate.run(() async {
        if (!mounted ||
            (_houseId?.trim().isEmpty ?? true) ||
            _auth.currentUser == null) {
          return;
        }
        final scope = _coupleDecorScope();
        _ensureCoupleDecorLoaded();
        final initial = await _homeCoupleDecorLoadFuture;
        if (!mounted || _coupleDecorScope() != scope) return;
        final isSingle = _homeToolRelationshipMode() != 'couple';
        final compactMeta = !_showStatus && !_showWeather;
        final isVip = await PurchaseService()
            .isVip()
            .timeout(const Duration(seconds: 5), onTimeout: () => false)
            .catchError((_) => false);
        if (!mounted || _coupleDecorScope() != scope) return;
        final decor = await slPush<HomeCoupleCardDecor>(
          context,
          HomeCoupleDecorEditorScreen(
            scope: scope,
            initialDecor: initial ?? _homeCoupleDecor,
            initialRevision: _homeCoupleDecorRevision,
            saveShared: ({
              required decor,
              required expectedRevision,
              required requestId,
            }) => _homeCoupleDecorSync.save(
              uid: _auth.currentUser?.uid ?? '',
              houseId: _houseId ?? '',
              decor: decor,
              expectedRevision: expectedRevision,
              requestId: requestId,
              isCurrent: () =>
                  mounted &&
                  _isTabActive &&
                  _coupleDecorScope() == scope,
            ),
            isVip: isVip,
            isScopeCurrent: () => mounted && _coupleDecorScope() == scope,
            previewLeft: _coupleDecorPreviewPerson(
              isUser1: true,
              isSingle: isSingle,
            ),
            previewRight: _coupleDecorPreviewPerson(
              isUser1: false,
              isSingle: isSingle,
            ),
            previewCenter: Padding(
              padding: EdgeInsets.only(top: compactMeta ? 12 : 20),
              child: _buildModernRelationshipAction(isSingle: isSingle),
            ),
          ),
        );
        if (!mounted || _coupleDecorScope() != scope || decor == null) return;
        _homeCoupleDecorLoadFuture = Future.value(decor);
        _safeSetState(() => _homeCoupleDecor = decor);
      }),
    );
  }

  Widget _coupleDecorPreviewPerson({
    required bool isUser1,
    required bool isSingle,
  }) {
    final role = isUser1 ? 'user1' : 'user2';
    final dob = _houseSettings?[isUser1 ? 'dobU1' : 'dobU2']?.toString() ?? '';
    final zodiac = ZodiacUtils.getZodiac(dob);
    final placeholder = isSingle && !isUser1;
    return _buildModernUserColumn(
      name: placeholder ? '' : _resolveNameForRole(role),
      avatarUrl: placeholder ? '' : _resolveAvatarForRole(role),
      zodiacEmoji: zodiac?['emoji'] ?? '',
      zodiacName: zodiac?['name'] ?? '',
      ageDays: _extractAgeDays(dob),
      role: role,
      isUser1: isUser1,
      hideMeta: isSingle,
      isGreyedOut: placeholder,
    );
  }

  void _openLoveInsights() {
    unawaited(
      _homeRouteGate.run(() async {
        if (_houseId == null || !mounted) return;

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
        await slPush<void>(
          context,
          LoveInsightsScreen(
            houseId: _houseId!,
            nameU1: nameU1,
            nameU2: nameU2,
            avatarU1: avtUser1,
            avatarU2: avtUser2,
            loveDays: _calculateDays(),
            relationshipMode:
                _houseSettings?['relationshipMode']?.toString() ?? 'single',
          ),
        );
      }),
    );
  }

  void _openCoupleConnect() {
    unawaited(
      _homeRouteGate.run(() async {
        if (_houseId == null || !mounted) return;
        final connected = await slPush<bool>(
          context,
          CoupleConnectScreen(houseId: _houseId!),
        );
        if (connected == true && mounted) {
          _fetchHouseData(preserveVisibleState: true);
        }
      }),
    );
  }

  void _openSingleMatchHub() {
    unawaited(
      _homeRouteGate.run(() async {
        final houseId = _houseId?.trim() ?? '';
        if (houseId.isEmpty || !mounted) return;
        await slPush<void>(context, SingleMatchHubScreen(houseId: houseId));
      }),
    );
  }

  void _openMilestonesDetail() {
    unawaited(
      _homeRouteGate.run(() async {
        if (_houseId == null || !mounted) return;
        await slPush<void>(
          context,
          MilestonesScreen(
            houseId: _houseId!,
            startDate: _houseSettings?['startDate']?.toString(),
            houseSettings: _houseSettings ?? {},
            homeCalendarEvents: _homeCalendarSnapshotMatchesScope
                ? _homeCalendarEvents
                : const [],
          ),
        );
        if (mounted) _fetchHouseData(preserveVisibleState: true);
      }),
    );
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
      await slPush<void>(
        context,
        CalendarScreen(
          houseId: expectedHouseId,
          myName: _resolveMyName(),
          initialDateKey: plan?.dateKey,
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

    await slPush<void>(
      context,
      const SoulMergeScreen(),
      fullscreenDialog: true,
    );
  }

  Future<void> _openTogetherHub({required bool isSingle}) async {
    final houseId = _houseId?.trim() ?? '';
    final uid = _auth.currentUser?.uid;
    if (!mounted || houseId.isEmpty || uid == null || _togetherHubIsOpen) {
      return;
    }

    bool isCurrentScope() =>
        mounted && _auth.currentUser?.uid == uid && _houseId == houseId;

    _togetherHubIsOpen = true;
    try {
      await slPush<void>(
        context,
        TogetherHubScreen(
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
            await slPush<void>(context, destination);
          },
        ),
      );
    } finally {
      _togetherHubIsOpen = false;
    }
  }
}
