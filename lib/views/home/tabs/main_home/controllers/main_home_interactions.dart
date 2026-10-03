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
    final prefs =
        OfflineCacheService.getPrefsSync() ??
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
      final nextPreset =
          _maybePresetForInteractionType(nextType) ??
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
      final nextPreset =
          _maybePresetForInteractionType(nextType) ??
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

    final currentList = List<_HomeReactionFlight>.from(
      _reactionFlightsNotifier.value,
    );
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
    final currentList = List<_HomeReactionFlight>.from(
      _reactionFlightsNotifier.value,
    );
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
    _showLatestSnackBar(message, duration: const Duration(seconds: 2));
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
      _dbRef
          .child('houses/$houseId/reaction_flights')
          .push()
          .set({
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
          })
          .then((_) {
            HapticFeedback.lightImpact();
          })
          .catchError((_) {
            _showLatestSnackBar(
              L10nService().translate('home_khnggicico_202368'),
            );
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
              ? L10nService().format('ui_home_value1_is_in_a_pretty_hot_place_a451a6', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_29e70d', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_tribnbnnng_6be553');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_opens_the_app_and_b4d9ce', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_fd0b09', {'value1': partnerName});
          break;
        case 'warmth':
          title = customTitle ?? '$myName nhắc bạn mặc ấm';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_in_a_rainy_or_cold_ee33bd', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_2e5983', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_bnbncvlnhn_a92b57');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_opens_the_app_and_b4d9ce', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_6d21ef', {'value1': partnerName});
          break;
        case 'kiss':
          title = customTitle ?? '$myName gửi bạn một nụ hôn';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_kiss_came_right_b937db', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_2093ea', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_chtmtcitht_f7bbad');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_8fee30', {'value1': partnerName});
          break;
        case 'hug':
          title = customTitle ?? '$myName ôm bạn một cái';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_soft_hug_is_954a62', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_d30419', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_mbnmtcitht_a0ec5e');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_845a47', {'value1': partnerName});
          break;
        case 'angry':
          title = customTitle ?? '$myName đang dỗi bạn đó';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_love_message_appeared_57ae14', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_d345ce', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_hmangdixut_2726ac');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_9c9038', {'value1': partnerName});
          break;
        case 'furious':
          title = customTitle ?? '$myName đang tức bạn đỏ mặt luôn';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_red_anger_appeared_e50739', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_0900e8', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_mnhangtcth_dfdd25');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_f4f01d', {'value1': partnerName});
          break;
        case 'tease':
          title = customTitle ?? '$myName vừa trêu bạn một chút';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_love_jab_popped_0180a9', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_57bf3a', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_mnhvachcbn_f70061');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_a1e737', {'value1': partnerName});
          break;
        case 'cry':
          title = customTitle ?? '$myName đang cần bạn dỗ dành';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_cry_signal_appeared_f43a9b', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_2c1e84', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_hmnaymnhhi_105e19');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_72e6d6', {'value1': partnerName});
          break;
        case 'poop':
          title = customTitle ?? '$myName vừa ném 💩 vào bạn';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_tease_popped_up_7ddb4e', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_0c43c8', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_nmnhmtcctr_3e8a1f');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_16e298', {'value1': partnerName});
          break;
        case 'miss':
        default:
          title = customTitle ?? '$myName gửi ngàn nỗi nhớ';
          body = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_this_nostalgia_hits_me_95a7c8', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_house_yet_e2a8f8', {'value1': partnerName});
          message =
              customMessage ??
              L10nService().translate('home_mnhnhbnnhi_88a6c7');
          notificationBody = partnerOnline
              ? L10nService().format('ui_home_value1_is_online_open_the_app_and_d40614', {'value1': partnerName})
              : L10nService().format('ui_home_value1_hasn_t_opened_the_app_yet_60eed7', {'value1': partnerName});
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

      final inboxRef = _dbRef
          .child('houses/$_houseId/partner_inbox/$_partnerRole')
          .push();
      await _dbRef.child('houses/$_houseId/alerts').push().set(payload);
      await inboxRef.set({...payload, 'timestamp': ServerValue.timestamp});
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
      } catch (error) {
        debugPrint('[MainHome] Partner notification failed: $error');
      }

      // Record daily quest progress
      await DailyQuestService().recordProgress('partner_interaction');

      if (!mounted || !showSentNotice) return;
      _showOutgoingInteractionNotice(
        interactionType: type,
        title: L10nScope.of(context).format('ui_home_sent_love_to_value1_91e959', {'value1': partnerName}),
        body: partnerOnline
            ? L10nScope.of(context).format('ui_home_value1_will_see_this_signal_right_on_39ac68', {'value1': partnerName})
            : L10nScope.of(context).format('ui_home_value1_has_not_opened_the_house_yet_f12fe8', {'value1': partnerName}),
        partnerName: partnerName,
        partnerOnline: partnerOnline,
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showLatestSnackBar(L10nService().translate('home_khngthgitn_55060e'));
    }
  }
}
