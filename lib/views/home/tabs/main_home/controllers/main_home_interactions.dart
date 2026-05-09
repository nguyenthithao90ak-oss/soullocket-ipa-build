part of '../../main_home_tab.dart';

extension _MainHomeInteractions on _MainHomeTabState {
  static const String _kInteractionRotationLastTypePrefsKey =
      'il_home_interaction_rotation_last_type_v1';

  void _setManualInteractionPreset(String type) {
    final preset = _maybePresetForInteractionType(type);
    if (preset == null) return;
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

  List<_PartnerInteractionPreset> _interactionRotationPresets() {
    return _kPartnerInteractionPresets;
  }

  _PartnerInteractionPreset _pickRandomInteractionPreset({String? avoidType}) {
    final presets = _interactionRotationPresets();
    if (presets.isEmpty) {
      return _defaultSmartInteractionPreset();
    }

    final filtered = avoidType == null || presets.length == 1
        ? presets
        : presets.where((preset) => preset.type != avoidType).toList();
    final pool = filtered.isNotEmpty ? filtered : presets;
    return pool[_random.nextInt(pool.length)];
  }

  Future<String?> _readLastInteractionRotationType() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final value = prefs.getString(_kInteractionRotationLastTypePrefsKey);
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _rememberInteractionRotationType(String type) async {
    final normalized = type.trim();
    if (normalized.isEmpty) return;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(_kInteractionRotationLastTypePrefsKey, normalized);
  }

  void _startInteractionRotationLoop() {
    if (!_isTabActive) return;
    _interactionRotationTimer?.cancel();
    _interactionRotationTimer = null;
    _showDefaultHeartSuggestion = true;
    unawaited(() async {
      final lastType = await _readLastInteractionRotationType();
      final nextPreset = _pickRandomInteractionPreset(avoidType: lastType);
      if (!mounted) {
        _showDefaultHeartSuggestion = false;
        _smartInteractionPreset = nextPreset;
        return;
      }
      _safeSetState(() {
        _showDefaultHeartSuggestion = false;
        _smartInteractionPreset = nextPreset;
      });
      await _rememberInteractionRotationType(nextPreset.type);
    }());
    _interactionRotationTimer =
        Timer(_kInteractionSuggestionRefreshInterval, () {
      final nextPreset = _pickRandomInteractionPreset(
        avoidType: _smartInteractionPreset.type,
      );
      if (mounted) {
        _safeSetState(() {
          _showDefaultHeartSuggestion = false;
          _smartInteractionPreset = nextPreset;
        });
      } else {
        _showDefaultHeartSuggestion = false;
        _smartInteractionPreset = nextPreset;
      }
      unawaited(_rememberInteractionRotationType(nextPreset.type));
      _interactionRotationTimer = Timer.periodic(
        _kInteractionSuggestionRefreshInterval,
        (_) => _refreshSmartInteraction(forceRotate: true),
      );
    });
  }

  void _refreshSmartInteraction({bool forceRotate = false}) {
    if (_showDefaultHeartSuggestion) {
      return;
    }
    final nextPreset = _pickRandomInteractionPreset(
      avoidType: forceRotate ? _smartInteractionPreset.type : null,
    );
    if (!mounted) {
      _smartInteractionPreset = nextPreset;
      unawaited(_rememberInteractionRotationType(nextPreset.type));
      return;
    }
    if (!forceRotate && nextPreset.type == _smartInteractionPreset.type) {
      return;
    }
    _safeSetState(() {
      _smartInteractionPreset = nextPreset;
    });
    unawaited(_rememberInteractionRotationType(nextPreset.type));
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
    const message = 'Bạn thao tác hơi nhanh. Vui lòng chờ một lát rồi thử lại.';
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
        _showLatestSnackBar('Không gửi được icon, kiểm tra mạng rồi thử lại.');
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
              'Trời bên bạn nóng đó nha, uống thêm nước rồi nghỉ một chút cho mình yên tâm nhé.';
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
              'Bên bạn có vẻ lạnh đó nha, nhớ mặc ấm và giữ mình thật ấm áp nhé.';
          notificationBody = partnerOnline
              ? '$partnerName đang online, mở app là thấy lời dặn này ngay luôn.'
              : '$partnerName chưa mở app, lời nhắc giữ ấm sẽ chờ khi người ấy quay lại.';
          break;
        case 'kiss':
          title = customTitle ?? '$myName gửi bạn một nụ hôn';
          body = partnerOnline
              ? '$partnerName đang online, nụ hôn này bay tới ngay luôn.'
              : '$partnerName chưa mở nhà, nụ hôn sẽ nằm chờ xinh xắn khi người ấy quay lại.';
          message = customMessage ?? 'Chụt một cái thật ngoan nè 💋';
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
              customMessage ?? 'Ôm bạn một cái thật chặt và thật êm nè 🫂';
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
              'Hừm, đang dỗi xíu thôi nên nhớ qua ôm mình nhé 😡';
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
              customMessage ?? 'Mình đang tức thật đó nha, qua dỗ liền đi 😡';
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
              'Mình vừa chọc bạn một cái nhẹ xíu thôi đó, cười lên nha 🤡';
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
              'Hôm nay mình hơi tủi một chút, nếu rảnh thì dỗ mình nha 😭';
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
              customMessage ?? 'Ném nhẹ một cục troll cho bạn bật cười nè 💩';
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
              'Mình nhớ bạn nhiều lắm đó, mở ra rồi ôm lấy nỗi nhớ này giúp mình nhé.';
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
      _showLatestSnackBar('Không thể gửi tín hiệu lúc này. Vui lòng thử lại.');
    }
  }
}
