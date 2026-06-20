part of '../../main_home_tab.dart';

extension _MainHomeListeners on _MainHomeTabState {
  void _listenHighlights(String houseId) {
    _albumSubscription?.cancel();
    _noteSubscription?.cancel();

    unawaited(_albumService.migrateAlbumFromRTDB(houseId));

    _albumSubscription = _albumService.streamAlbum(houseId).listen((items) {
      final nextAlbumHighlights = items
          .where((item) => item.type.trim().toLowerCase() == 'image')
          .toList(growable: false);
      if (_sameAlbumHighlights(_albumHighlights, nextAlbumHighlights)) {
        return;
      }
      _albumHighlights = nextAlbumHighlights;
      _rebuildHighlightItems();
    });

    _noteSubscription = _noteService.streamNotes(houseId).listen((items) {
      final nextNoteHighlights = items.take(4).toList(growable: false);
      if (_sameNoteHighlights(_noteHighlights, nextNoteHighlights)) {
        return;
      }
      _noteHighlights = nextNoteHighlights;
      _rebuildHighlightItems();
      _refreshSmartInteraction();
    });
  }

  void _listenHomeCalendarEvents(String houseId) {
    _homeCalendarSubscription?.cancel();
    _homeCalendarSubscription = _dbRef
        .child('houses/$houseId/calendar')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        _safeSetState(() {
          _homeCalendarEvents = [];
        });
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
            final map = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(val));
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
      } catch (_) {}
    });
  }

  void _listenInteractionSignals(String houseId) {
    _chatSignalSubscription?.cancel();
    _chatSignalSubscription = _dbRef
        .child('houses/$houseId/chat_room/messages')
        .orderByChild('ts')
        .limitToLast(30)
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (_recentChatSignals.isEmpty) {
          return;
        }
        _recentChatSignals = [];
        _refreshSmartInteraction();
        return;
      }
      final snapshotValue = event.snapshot.value;
      if (snapshotValue is! Map) {
        if (_recentChatSignals.isEmpty) {
          return;
        }
        _recentChatSignals = [];
        _refreshSmartInteraction();
        return;
      }
      final raw = Map<dynamic, dynamic>.from(snapshotValue);
      final items = raw.values
          .whereType<Map>()
          .map((value) => Map<dynamic, dynamic>.from(value))
          .toList()
        ..sort((a, b) {
          final left = (a['ts'] as num?)?.toInt() ?? 0;
          final right = (b['ts'] as num?)?.toInt() ?? 0;
          return right.compareTo(left);
        });
      final nextSignals = items
          .where((item) => (item['type'] ?? 'text').toString() == 'text')
          .map((item) => (item['text'] ?? item['content'] ?? '').toString())
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .take(12)
          .toList(growable: false);
      if (_sameStringList(_recentChatSignals, nextSignals)) {
        return;
      }
      _recentChatSignals = nextSignals;
      _refreshSmartInteraction();
    });
  }

  void _listenReactionFlights(String houseId) {
    _reactionFlightSubscription?.cancel();
    final listenStartedAt = DateTime.now().millisecondsSinceEpoch;

    _reactionFlightSubscription = _dbRef
        .child('houses/$houseId/reaction_flights')
        .orderByChild('sentAt')
        .limitToLast(40)
        .onChildAdded
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;

      final data = _toStringDynamicMap(event.snapshot.value);
      final sentAtMs = _readEpochMs(data['sentAt']) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isTooOld = sentAtMs <= 0 ||
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

      final isReplayFromBeforeListen = sentAtMs <
          listenStartedAt - _kReactionFlightListenGrace.inMilliseconds;
      if (isReplayFromBeforeListen) return;

      final fromRole = data['fromRole']?.toString() ?? '';
      if (fromRole != 'user1' && fromRole != 'user2') return;
      final toRole = data['toRole']?.toString() ??
          (fromRole == 'user1' ? 'user2' : 'user1');
      final type = data['type']?.toString() ?? 'miss';
      final rawEmoji = data['emoji']?.toString().trim();
      final emoji = rawEmoji == null || rawEmoji.isEmpty
          ? _emojiForInteractionType(type)
          : rawEmoji;
      final eventId = data['clientEventId']?.toString() ??
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
        ),
      );
    });
  }
}
