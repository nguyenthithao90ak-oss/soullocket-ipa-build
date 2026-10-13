part of '../../main_home_tab.dart';

extension _MainHomeListeners on _MainHomeTabState {
  void _listenHighlights(String houseId) {
    _noteSubscription?.cancel();

    _noteSubscription = _noteService
        .streamRecentNotes(houseId, limit: 10)
        .listen((items) {
          final nextNoteHighlights = items.take(4).toList(growable: false);
          if (_sameNoteHighlights(_noteHighlights, nextNoteHighlights)) {
            return;
          }
          _noteHighlights = nextNoteHighlights;
          _refreshSmartInteraction();
        });
  }

  bool get _homeCalendarSnapshotMatchesScope =>
      _auth.currentUser?.uid != null &&
      _homeCalendarUid == _auth.currentUser?.uid &&
      _homeCalendarHouseId == _houseId;

  void _pauseHomeCalendarEvents() {
    _homeCalendarBindingSerial++;
    _homeCalendarReadTimeout?.cancel();
    _homeCalendarReadTimeout = null;
    _homeCalendarFreshnessTimer?.cancel();
    _homeCalendarFreshnessTimer = null;
    unawaited(_homeCalendarSubscription?.cancel());
    _homeCalendarSubscription = null;
  }

  void _scheduleHomeCalendarFreshness(
    String houseId,
    String uid,
    int serial,
    String queryDay,
  ) {
    _homeCalendarFreshnessTimer?.cancel();
    final now = CalendarTimeZone.fromMilliseconds(
      DateTime.now().millisecondsSinceEpoch,
      MarketService.instance.preferences.timeZoneId,
    );
    if (CalendarCivilDate.key(now) != queryDay) {
      _listenHomeCalendarEvents(houseId);
      return;
    }
    final zone = CalendarTimeZone.locationFor(
      MarketService.instance.preferences.timeZoneId,
    );
    final nextDay = zone == null
        ? DateTime(now.year, now.month, now.day + 1)
        : tz.TZDateTime(zone, now.year, now.month, now.day + 1);
    var deadline = nextDay.millisecondsSinceEpoch;
    for (final plan in HomeCalendarPlan.upcoming(
      _homeCalendarEvents,
      now: now,
    )) {
      final end = plan.timing?.endUtcMs;
      if (end != null && end < deadline) deadline = end;
    }
    final delay = deadline - now.millisecondsSinceEpoch;
    _homeCalendarFreshnessTimer = Timer(
      Duration(milliseconds: max(1, delay)),
      () {
        if (!mounted ||
            !_isTabActive ||
            _homeCalendarBindingSerial != serial ||
            _auth.currentUser?.uid != uid ||
            _houseId != houseId) {
          return;
        }
        final current = CalendarTimeZone.fromMilliseconds(
          DateTime.now().millisecondsSinceEpoch,
          MarketService.instance.preferences.timeZoneId,
        );
        if (CalendarCivilDate.key(current) != queryDay) {
          _listenHomeCalendarEvents(houseId);
        } else {
          // Chỉ rebuild khi một kế hoạch hết giờ; không polling hoặc đọc lại Firebase.
          _safeSetState(() {});
          _scheduleHomeCalendarFreshness(houseId, uid, serial, queryDay);
        }
      },
    );
  }

  void _listenHomeCalendarEvents(String houseId) {
    final uid = _auth.currentUser?.uid;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final timeZoneId = MarketService.instance.preferences.timeZoneId;
    final queryKey =
        '$houseId|$timeZoneId|${CalendarCivilDate.key(CalendarTimeZone.fromMilliseconds(DateTime.now().millisecondsSinceEpoch, timeZoneId))}';
    // Mở lại app và đổi tab có thể gọi hàm này hai lần liền: đang nghe đúng
    // truy vấn (cùng nhà, múi giờ, ngày) và chưa lỗi thì giữ nguyên, không gỡ
    // rồi gắn lại (mỗi lần gắn là thêm lượt thao tác RTDB).
    if (_homeCalendarSubscription != null &&
        _homeCalendarQueryKey == queryKey &&
        _homeCalendarUid == uid &&
        _homeCalendarLoadState != HomeCalendarLoadState.failed &&
        mounted &&
        _isTabActive &&
        _houseId == houseId &&
        !_homeCalendarRouteIsOpen &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
      return;
    }
    _pauseHomeCalendarEvents();
    if (!mounted ||
        !_isTabActive ||
        uid == null ||
        _houseId != houseId ||
        _homeCalendarRouteIsOpen ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    final serial = _homeCalendarBindingSerial;
    bool isCurrent() =>
        mounted &&
        _isTabActive &&
        _homeCalendarBindingSerial == serial &&
        _auth.currentUser?.uid == uid &&
        _houseId == houseId;
    final sameScope =
        _homeCalendarUid == uid && _homeCalendarHouseId == houseId;
    _safeSetState(() {
      if (!sameScope) _homeCalendarEvents = [];
      _homeCalendarUid = uid;
      _homeCalendarHouseId = houseId;
      if (!sameScope || _homeCalendarLoadState != HomeCalendarLoadState.ready) {
        _homeCalendarLoadState = HomeCalendarLoadState.loading;
      }
    });
    _homeCalendarReadTimeout = Timer(const Duration(seconds: 12), () {
      if (!isCurrent()) return;
      _safeSetState(
        () => _homeCalendarLoadState = HomeCalendarLoadState.failed,
      );
    });
    // Chỉ query 30 ngày tới thay vì toàn bộ lịch sử calendar
    final now = CalendarTimeZone.fromMilliseconds(
      DateTime.now().millisecondsSinceEpoch,
      MarketService.instance.preferences.timeZoneId,
    );
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final end = DateTime.utc(now.year, now.month, now.day + 30);
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final calendarRef = _dbRef
        .child('houses/$houseId/calendar')
        .orderByKey()
        .startAt(todayStr)
        .endAt(endStr)
        .limitToFirst(31);
    _homeCalendarQueryKey = queryKey;
    _homeCalendarSubscription = calendarRef.onValue.listen(
      (event) {
        if (!isCurrent()) return;
        _homeCalendarReadTimeout?.cancel();
        if (event.snapshot.value == null) {
          _safeSetState(() {
            _homeCalendarEvents = [];
            _homeCalendarLoadState = HomeCalendarLoadState.ready;
          });
          _scheduleHomeCalendarFreshness(houseId, uid, serial, todayStr);
          return;
        }

        try {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final List<Map<String, dynamic>> parsedEvents = [];

          data.forEach((dateKey, dateEvents) {
            if (dateEvents is! Map) return;
            final eventsMap = Map<dynamic, dynamic>.from(dateEvents);
            eventsMap.forEach((key, val) {
              if (val is! Map) return;
              final map = Map<String, dynamic>.from(
                Map<dynamic, dynamic>.from(val),
              );
              parsedEvents.add({
                'id': key,
                'dateKey': dateKey.toString(),
                'title': map['title']?.toString() ?? '',
                'ts': _readEpochMs(map['ts']) ?? 0,
                if (map['timing'] is Map)
                  'timing': {
                    for (final field in [
                      'schemaVersion',
                      'startUtcMs',
                      'endUtcMs',
                      'timeZoneId',
                    ])
                      field: (map['timing'] as Map)[field],
                  }
                else if (map['timing'] != null)
                  'timing': const <String, dynamic>{},
              });
            });
          });

          _safeSetState(() {
            _homeCalendarEvents = parsedEvents;
            _homeCalendarLoadState = HomeCalendarLoadState.ready;
          });
          _scheduleHomeCalendarFreshness(houseId, uid, serial, todayStr);
        } catch (_) {
          _safeSetState(
            () => _homeCalendarLoadState = HomeCalendarLoadState.failed,
          );
        }
      },
      onError: (Object error) {
        if (!isCurrent()) return;
        _homeCalendarReadTimeout?.cancel();
        final denied =
            error is FirebaseException &&
            (error.code == 'permission-denied' ||
                error.code == 'permission_denied');
        if (denied) _homeCalendarFreshnessTimer?.cancel();
        _safeSetState(() {
          if (denied) _homeCalendarEvents = [];
          _homeCalendarLoadState = HomeCalendarLoadState.failed;
        });
      },
    );
  }

  void _listenHealthCycleForWidgetSync(String houseId) {
    _healthCycleSyncSubscription?.cancel();
    _healthCycleSyncSubscription = null;
    if (!WidgetService.supportsMobileWidgets) return;
    final healthRef = _dbRef.child('houses/$houseId/health_cycle');
    _healthCycleSyncSubscription = healthRef.onValue.listen(
      (event) {
        if (!mounted || _houseId != houseId) return;
        // Debounce 500ms trước khi sync cycle widget
        _healthCycleWidgetSyncDebounce?.cancel();
        _healthCycleWidgetSyncDebounce = Timer(
          const Duration(milliseconds: 500),
          () {
            if (!mounted || _houseId != houseId) return;
            unawaited(
              WidgetService.updateCycleWidgetData(
                cycleData: event.snapshot.value,
              ),
            );
          },
        );
      },
      onError: (Object error) {
        debugPrint('[MainHomeListeners] Health cycle stream failed: $error');
      },
    );
  }

  void _listenInteractionSignals(String houseId) {
    _chatSignalSubscription?.cancel();
    _chatSignalSubscription = null;
    _recentChatSignals.clear();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final sessionId = _liveWorkSessionId;
    final currentRole = _currentRole;
    if (uid == null ||
        houseId != _houseId ||
        _isLiveWorkSessionStaleImpl(sessionId)) {
      return;
    }
    final partnerSenderRole = currentRole == 'user1' ? 'user2' : 'user1';

    // Keep Home signals on the same chat as Soul Merge, with a bounded page.
    _chatSignalSubscription = _dbRef
        .child('houses/$houseId/soul_merge/chat')
        .orderByChild('timestamp')
        .limitToLast(12)
        .onChildAdded
        .listen(
          (event) {
            if (_isLiveWorkSessionStaleImpl(sessionId) ||
                FirebaseAuth.instance.currentUser?.uid != uid ||
                _houseId != houseId ||
                _currentRole != currentRole) {
              return;
            }
            if (!event.snapshot.exists || event.snapshot.value == null) return;

            final item = _toStringDynamicMap(event.snapshot.value);

            if (item['sender'] == partnerSenderRole) {
              final text = (item['text'] ?? '').toString().trim();
              if (text.isNotEmpty) {
                if (!_recentChatSignals.contains(text)) {
                  _recentChatSignals.insert(0, text);
                  if (_recentChatSignals.length > 12) {
                    _recentChatSignals.removeLast();
                  }
                  _refreshSmartInteraction();
                }
              }
            }
          },
          onError: (Object error) {
            debugPrint('[MainHomeListeners] Chat signal stream failed: $error');
          },
        );
  }

  void _listenReactionFlights(String houseId) {
    _reactionFlightSubscription?.cancel();
    final listenStartedAt = DateTime.now().millisecondsSinceEpoch;

    _reactionFlightSubscription = _dbRef
        .child('houses/$houseId/reaction_flights')
        .orderByChild('sentAt')
        .limitToLast(40)
        .onChildAdded
        .listen(
          (event) {
            if (!mounted || !_isTabActive || event.snapshot.value == null)
              return;

            final data = _toStringDynamicMap(event.snapshot.value);
            final sentAtMs = _readEpochMs(data['sentAt']) ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            final isTooOld =
                sentAtMs <= 0 ||
                now - sentAtMs > _kReactionFlightMaxReplayAge.inMilliseconds;
            if (isTooOld) {
              final key = event.snapshot.key;
              if (key != null) {
                unawaited(
                  _dbRef
                      .child('houses/$houseId/reaction_flights/$key')
                      .remove()
                      .catchError((error) {
                        debugPrint(
                          '[SuppressedError] lib/views/home/tabs/main_home/controllers/main_home_listeners.dart: $error',
                        );
                      }),
                );
              }
              return;
            }

            final isReplayFromBeforeListen =
                sentAtMs <
                listenStartedAt - _kReactionFlightListenGrace.inMilliseconds;
            if (isReplayFromBeforeListen) return;

            final fromRole = data['fromRole']?.toString() ?? '';
            if (fromRole != 'user1' && fromRole != 'user2') return;
            final toRole =
                data['toRole']?.toString() ??
                (fromRole == 'user1' ? 'user2' : 'user1');
            final type = data['type']?.toString() ?? 'miss';
            final rawEmoji = data['emoji']?.toString().trim();
            final emoji = rawEmoji == null || rawEmoji.isEmpty
                ? _emojiForInteractionType(type)
                : rawEmoji;
            final eventId =
                data['clientEventId']?.toString() ??
                event.snapshot.key ??
                '$fromRole-$sentAtMs-${_random.nextInt(999999)}';

            _showReactionFlight(
              _HomeReactionFlight(
                id: eventId,
                fromRole: fromRole,
                toRole: toRole,
                emoji: emoji,
                assetPath: data['assetPath']?.toString() ?? '',
                sentAtMs: sentAtMs,
                imageUrl: data['imageUrl']?.toString().trim().isNotEmpty == true
                    ? data['imageUrl']!.toString().trim()
                    : null,
              ),
            );
          },
          onError: (Object error) {
            debugPrint(
              '[MainHomeListeners] Reaction flight stream failed: $error',
            );
          },
        );
  }
}
