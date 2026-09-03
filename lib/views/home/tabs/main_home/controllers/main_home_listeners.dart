part of '../../main_home_tab.dart';

extension _MainHomeListeners on _MainHomeTabState {
  void _listenHighlights(String houseId) {
    _noteSubscription?.cancel();

    _noteSubscription = _noteService.streamRecentNotes(houseId, limit: 10).listen((items) {
      final nextNoteHighlights = items.take(4).toList(growable: false);
      if (_sameNoteHighlights(_noteHighlights, nextNoteHighlights)) {
        return;
      }
      _noteHighlights = nextNoteHighlights;
      _refreshSmartInteraction();
    });
  }

  void _listenHomeCalendarEvents(String houseId) {
    _homeCalendarSubscription?.cancel();
    // Chỉ query 30 ngày tới thay vì toàn bộ lịch sử calendar
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final end = now.add(const Duration(days: 30));
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final calendarRef = _dbRef
        .child('houses/$houseId/calendar')
        .orderByKey()
        .startAt(todayStr)
        .endAt(endStr);
    _homeCalendarSubscription = calendarRef.onValue.listen(
      (event) {
        if (!mounted || !_isTabActive) return;
        if (event.snapshot.value == null) {
          _safeSetState(() {
            _homeCalendarEvents = [];
          });
          _calendarWidgetSyncDebounce?.cancel();
          _calendarWidgetSyncDebounce = Timer(
            const Duration(milliseconds: 500),
            () {
              if (!mounted) return;
              unawaited(WidgetService.syncCalendarWidgetData(houseId: houseId));
            },
          );
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
                'ts': map['ts'] as int? ?? 0,
              });
            });
          });

          _safeSetState(() {
            _homeCalendarEvents = parsedEvents;
          });
          // Debounce 500ms trước khi sync calendar widget
          _calendarWidgetSyncDebounce?.cancel();
          _calendarWidgetSyncDebounce = Timer(
            const Duration(milliseconds: 500),
            () {
              if (!mounted) return;
              unawaited(WidgetService.syncCalendarWidgetData(houseId: houseId));
            },
          );
        } catch (e) {
          debugPrint('[MainHomeListeners] Calendar events parse error: $e');
        }
      },
      onError: (Object error) {
        debugPrint('[MainHomeListeners] Calendar events stream failed: $error');
      },
    );
  }

  void _listenHealthCycleForWidgetSync(String houseId) {
    _healthCycleSyncSubscription?.cancel();
    final healthRef = _dbRef.child('houses/$houseId/health_cycle');
    _healthCycleSyncSubscription = healthRef.onValue.listen(
      (event) {
        if (!mounted || !_isTabActive || !event.snapshot.exists) return;
        // Debounce 500ms trước khi sync cycle widget
        _healthCycleWidgetSyncDebounce?.cancel();
        _healthCycleWidgetSyncDebounce = Timer(
          const Duration(milliseconds: 500),
          () {
            if (!mounted) return;
            unawaited(WidgetService.syncCycleWidgetData(houseId: houseId));
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
    final partnerSenderId = _currentRole == 'user1' ? 'U2' : 'U1';

    // Use onChildAdded with limitToLast(12) to save bandwidth and prevent sorting a large map
    _chatSignalSubscription = _dbRef
        .child('houses/$houseId/chat_room/messages')
        .orderByChild('ts')
        .limitToLast(12)
        .onChildAdded
        .listen(
          (event) {
            if (!event.snapshot.exists || event.snapshot.value == null) return;

            final item = _toStringDynamicMap(event.snapshot.value);

            if ((item['type'] ?? 'text').toString() == 'text' &&
                item['senderId'] == partnerSenderId &&
                item['isRead'] != true) {
              final text = (item['text'] ?? item['content'] ?? '')
                  .toString()
                  .trim();
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
                      .catchError((_) {}),
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
