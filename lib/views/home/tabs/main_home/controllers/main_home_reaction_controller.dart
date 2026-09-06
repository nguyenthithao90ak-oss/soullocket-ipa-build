part of '../../main_home_tab.dart';

extension MainHomeReactionController on _MainHomeTabState {
  Future<void> _cleanupOldReactionFlights(String houseId) async {
    try {
      final cutoff =
          DateTime.now().millisecondsSinceEpoch -
          const Duration(minutes: 2).inMilliseconds;
      final snapshot = await _dbRef
          .child('houses/$houseId/reaction_flights')
          .orderByChild('sentAt')
          .endAt(cutoff)
          .limitToFirst(30)
          .get();
      final raw = snapshot.value;
      if (raw is! Map) return;

      final updates = <String, Object?>{};
      for (final key in raw.keys) {
        updates['houses/$houseId/reaction_flights/${key.toString()}'] = null;
      }
      if (updates.isNotEmpty) {
        await _dbRef.update(updates);
      }
    } catch (error) {
      debugPrint('[MainHome] Cannot prune stale reaction data: $error');
    }
  }

  void triggerShootingHeartState({String? emoji, String? fromRole}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _showReactionFlight(
      _HomeReactionFlight(
        id: 'local-$now-${_random.nextInt(999999)}',
        fromRole: fromRole ?? _currentRole,
        toRole: (fromRole ?? _currentRole) == 'user1' ? 'user2' : 'user1',
        emoji: emoji ?? _emojiForInteractionType('miss'),
        sentAtMs: now,
      ),
    );
  }

  int _consumeLocalReactionThrowWaitSeconds(int nowMs) {
    _localReactionThrowMs.removeWhere(
      (sentAt) =>
          nowMs - sentAt >=
          _MainHomeTabState._kReactionThrowWindow.inMilliseconds,
    );
    if (_localReactionThrowMs.length >=
        _MainHomeTabState._kReactionThrowBurstLimit) {
      final oldest = _localReactionThrowMs.first;
      final remainingMs =
          _MainHomeTabState._kReactionThrowWindow.inMilliseconds -
          (nowMs - oldest);
      final seconds = (remainingMs / 1000).ceil();
      return seconds < 1 ? 1 : seconds;
    }
    _localReactionThrowMs.add(nowMs);
    return 0;
  }

  Future<int> _consumeReactionThrowWaitSeconds() async {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) return 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int asInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is double) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    }

    var waitMs = 0;
    try {
      final ref = _dbRef.child(
        'houses/$houseId/reaction_throw_limits/$_currentRole',
      );
      final tx = await ref.runTransaction((Object? current) {
        final data = current is Map
            ? _toStringDynamicMap(current)
            : <String, dynamic>{};
        final windowStartMs = asInt(data['windowStartMs']);
        final count = asInt(data['count']);
        final elapsedMs = nowMs - windowStartMs;
        final shouldStartNewWindow =
            windowStartMs <= 0 ||
            elapsedMs < 0 ||
            elapsedMs >= _MainHomeTabState._kReactionThrowWindow.inMilliseconds;

        if (shouldStartNewWindow) {
          return Transaction.success({
            'windowStartMs': nowMs,
            'count': 1,
            'updatedAtMs': nowMs,
          });
        }

        if (count >= _MainHomeTabState._kReactionThrowBurstLimit) {
          waitMs =
              _MainHomeTabState._kReactionThrowWindow.inMilliseconds -
              elapsedMs;
          return Transaction.abort();
        }

        return Transaction.success({
          'windowStartMs': windowStartMs,
          'count': count + 1,
          'updatedAtMs': nowMs,
        });
      });

      if (tx.committed) return 0;
      final seconds = (waitMs / 1000).ceil();
      return seconds < 1 ? 1 : seconds;
    } catch (error) {
      debugPrint('[MainHome] Remote reaction throttle failed: $error');
      return _consumeLocalReactionThrowWaitSeconds(nowMs);
    }
  }

  Future<void> _handleSendInteraction(String type, String emoji) async {
    final cleanEmoji = emoji.trim().isEmpty
        ? _emojiForInteractionType(type)
        : emoji;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final localWait = _consumeLocalReactionThrowWaitSeconds(nowMs);
    if (localWait > 0) {
      _showReactionThrowLimitSnack();
      return;
    }
    if (!mounted) return;

    _sendReactionFlight(type, cleanEmoji);
    _triggerMissYouEffect(type);
    _vibrateHeartbeat();

    if (_isSendingInteraction) return;
    _isSendingInteraction = true;

    final preset = _maybePresetForInteractionType(type);
    final randomTitle = preset == null
        ? null
        : preset.titles[_random.nextInt(preset.titles.length)];
    final randomMessage = preset == null
        ? null
        : preset.messages[_random.nextInt(preset.messages.length)];

    unawaited(
      Future(() async {
        final waitSeconds = await _consumeReactionThrowWaitSeconds();
        if (waitSeconds > 0) {
          _showReactionThrowLimitSnack();
          return;
        }
        _sendPartnerInteraction(
          type,
          showSentNotice: false,
          emoji: cleanEmoji,
          customTitle: randomTitle,
          customMessage: randomMessage,
        );
      }),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _isSendingInteraction = false;
      }
    });
  }
}
