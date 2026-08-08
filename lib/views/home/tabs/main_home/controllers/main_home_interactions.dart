part of '../../main_home_tab.dart';

extension _MainHomeInteractions on _MainHomeTabState {
  static const String _kInteractionRotationLastTypePrefsKey =
      'il_home_interaction_rotation_last_type_v1';

  void _setManualInteractionPreset(String type) {
    final preset = _maybePresetForInteractionType(type);
    if (preset == null) return;
    _interactionRotationTimer?.cancel();
    _interactionRotationTimer = null;
    _manualInteractionPresetType = preset.type;
    _showDefaultHeartSuggestion = false;
    _smartInteractionPreset = preset;
  }

  Future<void> _rememberInteractionRotationType(String type) async {
    final normalized = type.trim();
    if (normalized.isEmpty) return;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(_kInteractionRotationLastTypePrefsKey, normalized);
  }

  void _refillRotationQueue() {
    final allTypes = _kPartnerInteractionPresets.map((e) => e.type).toList();
    allTypes.shuffle(_random);
    final currentType = _smartInteractionPreset.type;
    if (allTypes.isNotEmpty && allTypes.first == currentType) {
      final swapIdx = 1 + _random.nextInt(allTypes.length - 1);
      final temp = allTypes[0];
      allTypes[0] = allTypes[swapIdx];
      allTypes[swapIdx] = temp;
    }
    _rotationQueue.clear();
    _rotationQueue.addAll(allTypes);
  }

  void _startInteractionRotationLoop() {
    if (!_isTabActive) return;
    _interactionRotationTimer?.cancel();
    _interactionRotationTimer = null;
    _showDefaultHeartSuggestion = false;

    if (_manualInteractionPresetType != null) {
      return;
    }

    if (_rotationQueue.isEmpty) {
      _refillRotationQueue();
    }

    if (_rotationQueue.isNotEmpty) {
      final nextType = _rotationQueue.removeAt(0);
      final nextPreset = _maybePresetForInteractionType(nextType) ??
          _defaultSmartInteractionPreset();
      _smartInteractionPreset = nextPreset;
      unawaited(_rememberInteractionRotationType(nextPreset.type));
    }

    _interactionRotationTimer = Timer.periodic(
      _kInteractionSuggestionRefreshInterval,
      (_) => _refreshSmartInteraction(forceRotate: true),
    );
  }

  void _refreshSmartInteraction({bool forceRotate = false}) {
    if (_manualInteractionPresetType != null) {
      return;
    }
    if (_rotationQueue.isEmpty) {
      _refillRotationQueue();
    }
    if (_rotationQueue.isNotEmpty) {
      final nextType = _rotationQueue.removeAt(0);
      final nextPreset = _maybePresetForInteractionType(nextType) ??
          _defaultSmartInteractionPreset();
      _smartInteractionPreset = nextPreset;
      unawaited(_rememberInteractionRotationType(nextPreset.type));
    }
  }

  void _showReactionFlight(_HomeReactionFlight flight) {
    if (!_seenReactionFlightIds.add(flight.id)) return;
    if (_seenReactionFlightIds.length > 120) {
      _seenReactionFlightIds.remove(_seenReactionFlightIds.first);
    }
    if (!mounted) return;

    final currentList =
        List<_HomeReactionFlight>.from(_reactionFlightsNotifier.value);
    currentList.removeWhere((item) => item.id == flight.id);
    currentList.add(flight);
    if (currentList.length > _kMaxVisibleReactionFlights) {
      currentList.removeRange(
        0,
        currentList.length - _kMaxVisibleReactionFlights,
      );
    }
    _reactionFlightsNotifier.value = currentList;
  }

  void _removeReactionFlight(String id) {
    if (!mounted) return;
    final currentList =
        List<_HomeReactionFlight>.from(_reactionFlightsNotifier.value);
    final initialLength = currentList.length;
    currentList.removeWhere((item) => item.id == id);
    if (currentList.length != initialLength) {
      _reactionFlightsNotifier.value = currentList;
    }
  }

  void _triggerMissYouEffect(String interactionType) {
    final effectType = switch (interactionType) {
      'hot' => 'sparkles',
      'warmth' => 'snow',
      'kiss' => 'hearts',
      'hug' => 'bubbles',
      'cry' => 'snow',
      'angry' => 'meteors',
      'furious' => 'meteors',
      'tease' => 'sparkles',
      'poop' => 'leaves',
      _ => 'hearts',
    };
    _fallingEffectTypeNotifier.value = effectType;
    Future.delayed(const Duration(seconds: 4), () {
      _fallingEffectTypeNotifier.value = 'off';
    });
  }

  void _vibrateHeartbeat() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });
  }

  void _showReactionThrowLimitSnack() {
    final message = L10nService().translate('home_bnthaotchi_00f319');
    _showLatestSnackBar(
      message,
      duration: const Duration(seconds: 2),
    );
  }

  void _sendReactionFlight(String type, String emoji) {
    final houseId = _houseId;
    final user = _auth.currentUser;
    if (houseId == null || houseId.isEmpty || user == null) return;

    unawaited(PresenceService().markActiveNow());

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final eventId =
        '${_currentRole}_${user.uid}_${nowMs}_${_random.nextInt(999999)}';
    final preset = _maybePresetForInteractionType(type);

    final randomImageUrl = _currentRole == 'user1'
        ? (_houseSettings?['avtUser1'])
        : (_houseSettings?['avtUser2']);

    final flight = _HomeReactionFlight(
      id: eventId,
      fromRole: _currentRole,
      toRole: _partnerRole,
      emoji: emoji,
      assetPath: preset?.assetPath ?? '',
      sentAtMs: nowMs,
      imageUrl: randomImageUrl?.toString(),
    );
    _showReactionFlight(flight);

    unawaited(
      _dbRef.child('houses/$houseId/reaction_flights').push().set({
        'clientEventId': eventId,
        'type': type,
        'emoji': emoji,
        'assetPath': preset?.assetPath ?? '',
        if (randomImageUrl != null) 'imageUrl': randomImageUrl,
        'fromUid': user.uid,
        'fromRole': _currentRole,
        'toRole': _partnerRole,
        'sentAt': nowMs,
        'ts': ServerValue.timestamp,
      }).then((_) {
        HapticFeedback.lightImpact();
      }).catchError((_) {
        _showLatestSnackBar(L10nService().translate('home_khnggicico_202368'));
      }),
    );

    if (_random.nextInt(10) == 0) {
      unawaited(_cleanupOldReactionFlights(houseId));
    }
  }

  void _sendPartnerInteraction(
    String type, {
    bool showSentNotice = true,
    String? emoji,
    String? customTitle,
    String? customMessage,
  }) async {
    if (_houseId == null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final myName = _resolveMyName();
      final partnerName = _resolvePartnerName();
      final senderRole = _currentRole;
      final senderAvatar = _resolveAvatarForRole(senderRole);
      final sentAt = DateTime.now().millisecondsSinceEpoch;
      final partnerOnline = _isRoleOnline(_partnerRole);

      final String title;
      final String body;
      final String message;
      final String notificationBody;

      switch (type) {
        case 'hot':
          title = customTitle ?? '$myName nhắc bạn uống nước';
          body = partnerOnline
              ? '$partnerName đang ở nơi khá nóng, lời nhắc đáng yêu này hiện ngay rồi.'
              : '$partnerName chưa mở nhà, lời nhắc uống nước sẽ đợi sẵn để người ấy mở ra là thấy.';
          message = customMessage ??
              L10nService().translate('home_tribnbnnng_6be553');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy lời dặn này ngay luôn.'
              : '$partnerName chưa mở app, lời nhắc uống nước sẽ chờ khi người ấy quay lại.';
          break;
        case 'warmth':
          title = customTitle ?? '$myName nhắc bạn mặc ấm';
          body = partnerOnline
              ? '$partnerName đang ở nơi mưa hoặc lạnh, lời nhắc giữ ấm đã tới ngay rồi.'
              : '$partnerName chưa mở nhà, lời nhắc giữ ấm sẽ đợi sẵn để người ấy mở ra là thấy.';
          message = customMessage ??
              L10nService().translate('home_bnbncvlnhn_a92b57');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy lời dặn này ngay luôn.'
              : '$partnerName chưa mở app, lời nhắc giữ ấm sẽ chờ khi người ấy quay lại.';
          break;
        case 'kiss':
        case 'hug':
        case 'angry':
        case 'furious':
        case 'tease':
        case 'cry':
        case 'poop':
        case 'miss':
        default:
          title = customTitle ?? '$myName vừa gửi cho bạn một Sticker';
          body = partnerOnline
              ? '$partnerName đang online, mở ngay xem sticker gì nào!'
              : '$partnerName chưa mở nhà, sticker siêu cute đang chờ người ấy xem.';
          message = customMessage ?? 'Vừa gửi một sticker đáng yêu 💌';
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, sticker sẽ nằm chờ khi người ấy quay lại.';
          break;
      }

      final payload = {
        'type': type,
        'emoji': emoji ?? '\u{1F496}',
        'from': myName,
        'fromUid': user.uid,
        'fromRole': senderRole,
        'fromRoleLabel': _resolveRoleBadge(senderRole),
        'fromAvatar': senderAvatar,
        'toRole': _partnerRole,
        'toName': partnerName,
        'title': title,
        'body': body,
        'message': message,
        'sentAt': sentAt,
        'ts': ServerValue.timestamp,
      };

      final inboxRef =
          _dbRef.child('houses/$_houseId/partner_inbox/$_partnerRole').push();
      await _dbRef.child('houses/$_houseId/alerts').push().set(payload);
      await inboxRef.set({
        ...payload,
        'timestamp': ServerValue.timestamp,
      });
      await _dbRef.child('houses/$_houseId/interactions/$type').set({
        ...payload,
        'timestamp': ServerValue.timestamp,
      });
      try {
        final prefs = await OfflineCacheService.getPrefs();
        final lastFCM = prefs.getInt('il_last_sent_fcm_push_v2') ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        if (nowMs - lastFCM >= 3600000) {
          await prefs.setInt('il_last_sent_fcm_push_v2', nowMs);
          await _notificationService.sendPartnerNotification(
            houseId: _houseId!,
            title: title,
            body: notificationBody,
            data: {
              'screen': 'home',
              'type': 'partner_care',
              'careType': type,
              'houseId': _houseId!,
            },
          );
        }
      } catch (_) {}

      // Record daily quest progress
      await DailyQuestService().recordProgress('partner_interaction');

      if (!mounted || !showSentNotice) return;
      _showOutgoingInteractionNotice(
        interactionType: type,
        title: 'Đã gửi yêu thương cho $partnerName',
        body: partnerOnline
            ? '$partnerName sẽ thấy tín hiệu này ngay trên màn hình chính luôn đó.'
            : '$partnerName chưa mở nhà, nhưng tín hiệu này đã được gửi sang và sẽ chờ người ấy mở ra.',
        partnerName: partnerName,
        partnerOnline: partnerOnline,
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showLatestSnackBar(L10nService().translate('home_khngthgitn_55060e'));
    }
  }
}
