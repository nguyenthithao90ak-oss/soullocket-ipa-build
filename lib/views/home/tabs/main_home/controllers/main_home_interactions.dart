part of '../../main_home_tab.dart';

extension _MainHomeInteractions on _MainHomeTabState {
  static const String _kInteractionRotationLastTypePrefsKey =
      'il_home_interaction_rotation_last_type_v1';

  void _setManualInteractionPreset(String type) {
    final preset = _maybePresetForInteractionType(type);
    if (preset == null) return;
    _interactionRotationTimer?.cancel();
    _interactionRotationTimer = null;
    if (!mounted) {
      _manualInteractionPresetType = preset.type;
      _showDefaultHeartSuggestion = false;
      _smartInteractionPreset = preset;
      return;
    }
    _safeSetState(() {
      _manualInteractionPresetType = preset.type;
      _showDefaultHeartSuggestion = false;
      _smartInteractionPreset = preset;
    });
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
      final nextPreset = _maybePresetForInteractionType(nextType) ?? _defaultSmartInteractionPreset();
      if (!mounted) {
        _smartInteractionPreset = nextPreset;
      } else {
        _safeSetState(() {
          _smartInteractionPreset = nextPreset;
        });
      }
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
      final nextPreset = _maybePresetForInteractionType(nextType) ?? _defaultSmartInteractionPreset();
      if (!mounted) {
        _smartInteractionPreset = nextPreset;
        unawaited(_rememberInteractionRotationType(nextPreset.type));
        return;
      }
      _safeSetState(() {
        _smartInteractionPreset = nextPreset;
      });
      unawaited(_rememberInteractionRotationType(nextPreset.type));
    }
  }

  void _showReactionFlight(_HomeReactionFlight flight) {
    if (!_seenReactionFlightIds.add(flight.id)) return;
    if (_seenReactionFlightIds.length > 120) {
      _seenReactionFlightIds.remove(_seenReactionFlightIds.first);
    }
    if (!mounted) return;

    _safeSetState(() {
      _reactionFlights.removeWhere((item) => item.id == flight.id);
      _reactionFlights.add(flight);
      if (_reactionFlights.length > _kMaxVisibleReactionFlights) {
        _reactionFlights.removeRange(
          0,
          _reactionFlights.length - _kMaxVisibleReactionFlights,
        );
      }
    });
  }

  void _removeReactionFlight(String id) {
    if (!mounted) return;
    _safeSetState(() {
      _reactionFlights.removeWhere((item) => item.id == id);
    });
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
    final flight = _HomeReactionFlight(
      id: eventId,
      fromRole: _currentRole,
      toRole: _partnerRole,
      emoji: emoji,
      assetPath: preset?.assetPath ?? '',
      sentAtMs: nowMs,
    );
    _showReactionFlight(flight);

    unawaited(
      _dbRef.child('houses/$houseId/reaction_flights').push().set({
        'clientEventId': eventId,
        'type': type,
        'emoji': emoji,
        'assetPath': preset?.assetPath ?? '',
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
          title = customTitle ?? '$myName gửi bạn một nụ hôn';
          body = partnerOnline
              ? '$partnerName đang online, nụ hôn này bay tới ngay luôn.'
              : '$partnerName chưa mở nhà, nụ hôn sẽ nằm chờ xinh xắn khi người ấy quay lại.';
          message = customMessage ?? L10nService().translate('home_chtmtcitht_f7bbad');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, nụ hôn sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'hug':
          title = customTitle ?? '$myName ôm bạn một cái';
          body = partnerOnline
              ? '$partnerName đang online, cái ôm mềm này tới ngay rồi.'
              : '$partnerName chưa mở nhà, cái ôm sẽ đợi sẵn để người ấy mở ra là thấy.';
          message =
              customMessage ?? L10nService().translate('home_mbnmtcitht_a0ec5e');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, cái ôm sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'angry':
          title = customTitle ?? '$myName đang dỗi bạn đó';
          body = partnerOnline
              ? '$partnerName đang online, lời dỗi yêu này hiện lên ngay rồi.'
              : '$partnerName chưa mở nhà, lời dỗi yêu sẽ nằm chờ để người ấy dỗ bạn sau.';
          message = customMessage ??
              L10nService().translate('home_hmangdixut_2726ac');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, lời dỗi hờn sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'furious':
          title = customTitle ?? '$myName đang tức bạn đỏ mặt luôn';
          body = partnerOnline
              ? '$partnerName đang online, cơn tức đỏ rực này hiện lên ngay rồi.'
              : '$partnerName chưa mở nhà, cơn tức đỏ rực này sẽ chờ sẵn để người ấy dỗ bạn sau.';
          message =
              customMessage ?? L10nService().translate('home_mnhangtcth_dfdd25');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, cơn tức này sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'tease':
          title = customTitle ?? '$myName vừa trêu bạn một chút';
          body = partnerOnline
              ? '$partnerName đang online, cú chọc yêu này bật ra ngay rồi.'
              : '$partnerName chưa mở nhà, cú trêu nghịch này sẽ nằm chờ khi người ấy quay lại.';
          message = customMessage ??
              L10nService().translate('home_mnhvachcbn_f70061');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, cú trêu này sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'cry':
          title = customTitle ?? '$myName đang cần bạn dỗ dành';
          body = partnerOnline
              ? '$partnerName đang online, tín hiệu mít ướt này hiện lên ngay rồi.'
              : '$partnerName chưa mở nhà, tín hiệu cần dỗ dành sẽ chờ khi người ấy quay lại.';
          message = customMessage ??
              L10nService().translate('home_hmnaymnhhi_105e19');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, tín hiệu mít ướt sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'poop':
          title = customTitle ?? '$myName vừa ném 💩 vào bạn';
          body = partnerOnline
              ? '$partnerName đang online, cú trêu này bật ra ngay rồi.'
              : '$partnerName chưa mở nhà, cú trêu nghịch này sẽ chờ sẵn khi người ấy quay lại.';
          message =
              customMessage ?? L10nService().translate('home_nmnhmtcctr_3e8a1f');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, 💩 sẽ chờ sẵn khi người ấy quay lại.';
          break;
        case 'miss':
        default:
          title = customTitle ?? '$myName gửi ngàn nỗi nhớ';
          body = partnerOnline
              ? '$partnerName đang online, nỗi nhớ này chạm tới ngay luôn.'
              : '$partnerName chưa mở nhà, nỗi nhớ sẽ đợi sẵn để người ấy mở ra là nhận được.';
          message = customMessage ??
              L10nService().translate('home_mnhnhbnnhi_88a6c7');
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy ngay.'
              : '$partnerName chưa mở app, nỗi nhớ sẽ chờ sẵn khi người ấy quay lại.';
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
