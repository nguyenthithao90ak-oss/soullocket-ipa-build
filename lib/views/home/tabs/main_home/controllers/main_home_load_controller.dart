
part of '../../main_home_tab.dart';

extension _MainHomeLoadController on _MainHomeTabState {
  int _invalidateLiveWorkSessionImpl() => ++_liveWorkSessionId;

  bool _isLiveWorkSessionStaleImpl(
    int sessionId, {
    bool allowInactive = false,
  }) {
    return (!allowInactive && !_isTabActive) ||
        !mounted ||
        _liveWorkSessionId != sessionId;
  }

  void _cancelLiveWorkBindingsImpl() {
    _weatherRefreshTimer?.cancel();
    _weatherRefreshTimer = null;
    _loveWidgetSyncDebounce?.cancel();
    _loveWidgetSyncDebounce = null;
    _incomingInteractionDialogTimer?.cancel();
    _incomingInteractionDialogTimer = null;
    _fallbackTimeoutTimer?.cancel();
    _fallbackTimeoutTimer = null;
    _delayedListenersTimer?.cancel();
    _delayedListenersTimer = null;
    _delayedMapWeatherTimer?.cancel();
    _delayedMapWeatherTimer = null;
    _presenceSnapshotFallbackTimer?.cancel();
    _presenceSnapshotFallbackTimer = null;
    _calendarWidgetSyncDebounce?.cancel();
    _calendarWidgetSyncDebounce = null;
    _healthCycleWidgetSyncDebounce?.cancel();
    _healthCycleWidgetSyncDebounce = null;
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _membersSubscription?.cancel();
    _membersSubscription = null;
    for (final sub in _presenceSubList) {
      sub.cancel();
    }
    _presenceSubList.clear();
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _missInteractionSubscription?.cancel();
    _missInteractionSubscription = null;
    _alertSubscription?.cancel();
    _alertSubscription = null;
    _newDeviceNotificationSubscription?.cancel();
    _newDeviceNotificationSubscription = null;
    _partnerInboxSubscription?.cancel();
    _partnerInboxSubscription = null;
    _albumSubscription?.cancel();
    _albumSubscription = null;
    _noteSubscription?.cancel();
    _noteSubscription = null;
    _homeCalendarSubscription?.cancel();
    _homeCalendarSubscription = null;
    _healthCycleSyncSubscription?.cancel();
    _healthCycleSyncSubscription = null;
    _chatSignalSubscription?.cancel();
    _chatSignalSubscription = null;
    _reactionFlightSubscription?.cancel();
    _reactionFlightSubscription = null;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _interactionRotationTimer?.cancel();
    _interactionRotationTimer = null;
    _pendingWidgetSettings = null;
    _pendingWidgetSyncIncludeDiaryMedia = false;
    _widgetSyncInFlight = false;
    _interactionDragOverlayEntry?.remove();
    _interactionDragOverlayEntry = null;
    _interactionDragHoveredType = null;
    _interactionDragHoveredNotifier.value = null;
    _weatherSyncInFlight = false;
  }

  void _listenNewDeviceNotifications(String houseId) {
    final msgNewDeviceTitle = context.tr('home_ngnhpthitb_129d06');
    final msgNewDeviceBody = context.tr('home_cthitbmiva_74f5d4');
    _newDeviceNotificationSubscription?.cancel();
    final listenStartedAt = DateTime.now().millisecondsSinceEpoch;

    _newDeviceNotificationSubscription = _dbRef
        .child('notifications/$houseId')
        .orderByChild('type')
        .equalTo('new_device')
        .onChildAdded
        .listen((event) {
      if (!mounted || !_isTabActive || event.snapshot.value == null) return;

      final notificationId = event.snapshot.key?.trim() ?? '';
      if (notificationId.isEmpty ||
          !_seenNewDeviceNotificationIds.add(notificationId)) {
        return;
      }
      if (_seenNewDeviceNotificationIds.length > 120) {
        _seenNewDeviceNotificationIds.remove(
          _seenNewDeviceNotificationIds.first,
        );
      }

      final data = _toStringDynamicMap(event.snapshot.value);
      final readAt = data['readAt'];
      if (readAt != null) return;

      final createdAt =
          _readEpochMs(data['ts']) ?? _readEpochMs(data['timestamp']) ?? 0;
      final isReplayFromBeforeListen = createdAt > 0 &&
          createdAt <
              listenStartedAt - const Duration(seconds: 3).inMilliseconds;
      if (isReplayFromBeforeListen) return;

      final title = (data['title']?.toString().trim().isNotEmpty ?? false)
          ? data['title'].toString().trim()
          : msgNewDeviceTitle;
      final body = (data['msg']?.toString().trim().isNotEmpty ?? false)
          ? data['msg'].toString().trim()
          : msgNewDeviceBody;

      _showLatestSnackBarImpl('⚠️ $title: $body');
    }, onError: (Object error) {
      if (error.toString().contains('permission-denied')) {
        debugPrint('[MainHome] new device notification listener: permission-denied (ignored)');
        _newDeviceNotificationSubscription?.cancel();
      } else {
        debugPrint('[MainHome] new device notification listener error: $error');
      }
    });
  }

  bool _readBoolSettingFlagImpl(dynamic raw, {required bool fallback}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  void _showLatestSnackBarImpl(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
        ),
      );
  }

  String _presenceRoleUiSignatureImpl(
    String role,
    Map<String, dynamic>? data,
  ) {
    if (data == null || data.isEmpty) {
      return 'none';
    }

    final online = _isPresenceDataOnlineForRole(role, data);
    final weatherRaw = data['weather'];
    var weatherSignature = '';
    if (weatherRaw is Map) {
      final weather = _toStringDynamicMap(weatherRaw);
      final temp = _readDouble(weather['temp'])?.round();
      final condition = weather['cond']?.toString().trim() ?? '';
      weatherSignature = '${temp ?? ''}|$condition';
    }

    if (online) {
      return 'on|$weatherSignature';
    }

    final lastSeen = _readEpochMs(data['lastSeen']) ?? -1;
    return 'off|$lastSeen|$weatherSignature';
  }

  String _presenceUiSignatureForPayloadImpl(Map<String, dynamic> payload) {
    String roleSignature(String role) {
      final raw = payload[role];
      if (raw is! Map) {
        return '$role:none';
      }
      final signature = _presenceRoleUiSignatureImpl(
        role,
        _toStringDynamicMap(raw),
      );
      return '$role:$signature';
    }

    return '${roleSignature('user1')}|${roleSignature('user2')}';
  }

  void _updatePresenceDataImpl(Map<String, dynamic> nextPresence) {
    _presenceData = nextPresence;
    _presenceDataNotifier.value = nextPresence;
    _presenceUiSignature = _presenceUiSignatureForPayloadImpl(nextPresence);
  }

  bool _updatePresenceDataIfNeededImpl(Map<String, dynamic> nextPresence) {
    final nextSignature = _presenceUiSignatureForPayloadImpl(nextPresence);
    if (_presenceUiSignature == nextSignature) {
      _presenceData = nextPresence;
      return false;
    }

    _updatePresenceDataImpl(nextPresence);
    return true;
  }

  void _updateHomeMapPreviewImpl({
    required String distanceText,
    required String? alertText,
  }) {
    final nextSignature = '$distanceText|${alertText ?? ''}';
    bool needsUpdate = false;
    if (_homeMapPreviewSignature != nextSignature) {
      _homeMapPreviewSignature = nextSignature;
      needsUpdate = true;
    }
    _homeDistanceTextNotifier.value = distanceText;
    _homeMapAlertNotifier.value = alertText;
    if (!needsUpdate) return;
  }

  dynamic _normalizeInsightSignatureValueImpl(dynamic value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, dynamic>{
        for (final entry in entries)
          entry.key.toString():
              _normalizeInsightSignatureValueImpl(entry.value),
      };
    }
    if (value is List) {
      return value
          .map<dynamic>(_normalizeInsightSignatureValueImpl)
          .toList(growable: false);
    }
    return value;
  }

  String _buildInsightSettingsKeyImpl(
    Map<String, dynamic> settings,
    String relationshipMode,
  ) {
    return jsonEncode({
      'relationshipMode': relationshipMode,
      'startDate': settings['startDate'],
      'nameU1': settings['nameU1'],
      'nameU2': settings['nameU2'],
      'customEvents':
          _normalizeInsightSignatureValueImpl(settings['customEvents']),
    });
  }

  String _buildCanonicalSettingsPayloadSignatureImpl(
    Map<String, dynamic> settings,
  ) {
    return jsonEncode(_normalizeInsightSignatureValueImpl(settings));
  }

  String _buildWidgetSettingsSyncKeyImpl(Map<String, dynamic> settings) {
    return jsonEncode({
      'startDate': settings['startDate'],
      'dayUnit': settings['dayUnit'],
      'nameU1': settings['nameU1'],
      'nameU2': settings['nameU2'],
      'avtUser1': settings['avtUser1'],
      'avtUser2': settings['avtUser2'],
      'dobU1': settings['dobU1'],
      'dobU2': settings['dobU2'],
    });
  }

  Future<void> _refreshHomeInsightsImpl({
    required String houseId,
    required String relationshipMode,
    required String settingsKey,
  }) async {
    if (_pendingInsightSettingsKey == settingsKey) {
      return;
    }

    _pendingInsightSettingsKey = settingsKey;
    final requestId = ++_insightRequestSerial;
    try {
      final insight =
          await _insightService.computeInsights(houseId, relationshipMode);
      if (!mounted || requestId != _insightRequestSerial) {
        return;
      }

      _lastInsightSettingsKey = settingsKey;
      if (_pendingInsightSettingsKey == settingsKey) {
        _pendingInsightSettingsKey = null;
      }
      setState(() {
        _insightData = insight;
      });
    } finally {
      if (_pendingInsightSettingsKey == settingsKey) {
        _pendingInsightSettingsKey = null;
      }
    }
  }

  void _setupTimeoutFallback(int sessionId, bool Function() isStale) {
    _fallbackTimeoutTimer?.cancel();
    _fallbackTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (isStale() || !mounted || !_isLoading || _houseSettings != null) {
        return;
      }
      setState(() {
        _houseSettings = _buildDefaultHomeSettings();
        _isLoading = false;
      });
    });
  }

  void _startDelayedListeners(String houseId, int sessionId, bool Function() isStale) {
    _delayedListenersTimer?.cancel();
    _delayedListenersTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || isStale()) return;
      _wrapSetup(() => _listenNewDeviceNotifications(houseId), 'NewDevice');
      _wrapSetup(() => _listenInteractionSignals(houseId), 'Interactions');
      _wrapSetup(() => _listenReactionFlights(houseId), 'Reactions');
      _startInteractionRotationLoop();
    });
  }

  void _startDelayedMapAndWeather(String houseId, int sessionId, bool Function() isStale) {
    _delayedMapWeatherTimer?.cancel();
    _delayedMapWeatherTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || isStale()) return;
      _wrapSetup(() => _bindHomeMapPreview(houseId), 'MapPreview');
      unawaited(_ensureAppWideLocationTracking(houseId));
      if (_showWeather) {
        _startWeatherRefreshLoop(houseId);
      }
    });
  }

  void _startPresenceSnapshotFallback(int sessionId, bool Function() isStale) {
    _presenceSnapshotFallbackTimer?.cancel();
    _presenceSnapshotFallbackTimer = Timer(const Duration(seconds: 6), () {
      if (isStale() || !mounted || _hasLoadedPresenceSnapshot) return;
      setState(() {
        _hasLoadedPresenceSnapshot = true;
      });
    });
  }

  void _applyResolvedHomeSettings(
    Map<String, dynamic> settings,
    String cachedRelMode, {
    bool warmMedia = true,
    bool delayMotion = false,
    bool forceWarmMedia = false,
  }) {
    _houseSettings = settings;
    _houseSettings!['relationshipMode'] = cachedRelMode;
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    } else {
      _isLoading = false;
    }
    if (warmMedia) {
      _warmHomeMedia(
        delayMotion: delayMotion,
        force: forceWarmMedia,
      );
    }
  }

  Future<void> _loadAndApplySettings({
    required String houseId,
    required String cacheKey,
    required String cachedRelMode,
    required bool isNewHouseContext,
    required bool preserveVisibleState,
    required bool Function() isStale,
  }) async {
    final cachedSettings = OfflineCacheService.loadCacheSync(cacheKey);
    if (cachedSettings != null &&
        mounted &&
        (_houseSettings == null || isNewHouseContext)) {
      final cachedSettingsMap = cachedSettings is Map
          ? Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(cachedSettings),
            )
          : null;
      if (cachedSettingsMap != null) {
        _applyResolvedHomeSettings(
          cachedSettingsMap,
          cachedRelMode,
          delayMotion: preserveVisibleState && isNewHouseContext,
          forceWarmMedia: isNewHouseContext,
        );
      }
    }

    if (_houseSettings == null) {
      final initialSettingsSnap = await _dbRef
          .child('houses/$houseId/settings')
          .get()
          .timeout(const Duration(seconds: 5));
      if (isStale()) return;
      if (initialSettingsSnap.exists && initialSettingsSnap.value is Map) {
        _houseSettings = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(initialSettingsSnap.value as Map),
        );
        final msgCacheSettingsFail = L10nService().translate('home_clixyra_775791');
        try {
          await OfflineCacheService.saveCache(cacheKey, _houseSettings);
        } catch (e) {
          debugPrint(
            'Error saving settings to cache: ${AppErrorMapper.resolve(
              e,
              fallbackMessage: msgCacheSettingsFail,
            ).message}',
          );
        }
      } else {
        _houseSettings = _buildDefaultHomeSettings();
      }

      _applyResolvedHomeSettings(_houseSettings!, cachedRelMode);
    }
  }

  void _setupMembersSubscription(
    String houseId,
    int sessionId,
    bool Function() isStale,
    String msgMembersFail,
  ) {
    _membersSubscription?.cancel();
    _membersSubscription =
        _dbRef.child('houses/$houseId/members').onValue.listen(
      (event) {
        if (isStale() || !_isTabActive) return;
        if (event.snapshot.value != null && mounted) {
          final raw = event.snapshot.value;
          if (raw is Map) {
            final nextConnected = raw.length >= 2;
            if (_isCoupleConnected != nextConnected) {
              if (isStale()) return;
              setState(() {
                _isCoupleConnected = nextConnected;
              });
            }
          }
        } else if (mounted) {
          if (_isCoupleConnected) {
            if (isStale()) return;
            setState(() {
              _isCoupleConnected = false;
            });
          }
        }
      },
      onError: (Object error) {
        debugPrint(
          'Home members listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: msgMembersFail,
          ).message}',
        );
      },
    );
  }

  void _updatePresenceField(
    String role,
    String field,
    dynamic value, {
    required bool Function() isStale,
  }) {
    if (isStale()) return;
    final roleData = Map<String, dynamic>.from(
        _presenceData[role] is Map ? _presenceData[role] as Map : {});
    roleData[field] = value;
    final nextPresence = Map<String, dynamic>.from(_presenceData);
    nextPresence[role] = roleData;
    _hasLoadedPresenceSnapshot = true;
    final didUpdatePresence = _updatePresenceDataIfNeededImpl(nextPresence);

    if (didUpdatePresence &&
        _isRoleOnline('user1') &&
        _isRoleOnline('user2')) {
      DailyQuestService().recordProgress('simultaneous_online');
    }

    if (didUpdatePresence) {
      final partnerPresence = _presenceForRole(_partnerRole);
      final partnerWeatherRaw = partnerPresence?['weather'];
      if (partnerWeatherRaw is Map) {
        unawaited(
          _maybeSendAutomaticWeatherCare(
            _toStringDynamicMap(partnerWeatherRaw),
          ),
        );
      }
    }

    if (didUpdatePresence && _houseSettings != null) {
      _scheduleLoveWidgetSync(
        _houseSettings!,
        includeDiaryMedia: false,
      );
    }
  }

  void _setupPresenceSubscription(
    String houseId,
    int sessionId,
    bool Function() isStale,
    String msgPresenceFail,
  ) {
    for (final sub in _presenceSubList) {
      sub.cancel();
    }
    _presenceSubList.clear();

    final roles = ['user1', 'user2'];
    final fields = [
      'status',
      'lastSeen',
      'device',
      'weather',
      'city',
      'activeSessionCount'
    ];

    for (final role in roles) {
      for (final field in fields) {
        final sub = _dbRef
            .child('houses/$houseId/presence/$role/$field')
            .onValue
            .listen(
          (event) {
            if (isStale() || !_isTabActive) return;
            _updatePresenceField(role, field, event.snapshot.value,
                isStale: isStale);
          },
          onError: (Object error) {
            debugPrint(
              'Home presence field $role/$field listener failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: msgPresenceFail,
              ).message}',
            );
            if (mounted) {
              setState(() {
                _hasLoadedPresenceSnapshot = true;
              });
            }
          },
        );
        _presenceSubList.add(sub);
      }
    }
  }

  void _setupAlertsAndPartnerInbox(
    String houseId,
    int sessionId,
    bool Function() isStale,
    String userUid,
  ) {
    _alertSubscription?.cancel();
    _alertSubscription = _dbRef
        .child('houses/$houseId/alerts')
        .onChildAdded
        .listen((event) async {
      if (isStale()) return;
      if (event.snapshot.value == null || !mounted) return;
      final data = _toStringDynamicMap(event.snapshot.value);
      final payload = _MissYouAlertPayload.fromMap(data);
      final sentAt = payload.sentAtMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = sentAt > 0 &&
          now - sentAt > const Duration(hours: 24).inMilliseconds;

      if (isExpired) {
        final key = event.snapshot.key;
        if (key != null) {
          _dbRef.child('houses/$houseId/alerts/$key').remove().catchError(
                (_) {},
              );
        }
        return;
      }

      if (!_shouldDisplayIncomingAlert(payload, currentUid: userUid)) {
        return;
      }

      final key = event.snapshot.key;
      await _deliverIncomingAlert(
        payload,
        removalPath: key == null ? null : 'houses/$houseId/alerts/$key',
      );
    }, onError: (Object error) {
      debugPrint('Home alerts listener failed: $error');
    });

    _partnerInboxSubscription?.cancel();
    _partnerInboxSubscription = _dbRef
        .child('houses/$houseId/partner_inbox/$_currentRole')
        .onChildAdded
        .listen((event) async {
      if (isStale()) return;
      if (event.snapshot.value == null || !mounted) return;
      final data = _toStringDynamicMap(event.snapshot.value);
      final payload = _MissYouAlertPayload.fromMap(data);
      final sentAt = payload.sentAtMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = sentAt > 0 &&
          now - sentAt > const Duration(hours: 24).inMilliseconds;

      final key = event.snapshot.key;
      if (isExpired) {
        if (key != null) {
          _dbRef
              .child('houses/$houseId/partner_inbox/$_currentRole/$key')
              .remove()
              .catchError((_) {});
        }
        return;
      }

      if (!_shouldDisplayIncomingAlert(payload, currentUid: userUid)) {
        return;
      }

      await _deliverIncomingAlert(
        payload,
        removalPath: key == null
            ? null
            : 'houses/$houseId/partner_inbox/$_currentRole/$key',
      );
    }, onError: (Object error) {
      debugPrint('Home partner inbox listener failed: $error');
    });
  }

  void _setupMissInteractionSubscription(
    String houseId,
    int sessionId,
    bool Function() isStale,
    String userUid,
  ) {
    _missInteractionSubscription?.cancel();
    _missInteractionSubscription = _dbRef
        .child('houses/$houseId/interactions/miss')
        .onValue
        .listen((event) {
      if (isStale()) return;
      if (event.snapshot.value != null && mounted) {
        final data = _toStringDynamicMap(event.snapshot.value);
        final payload = _MissYouAlertPayload.fromMap(data);
        final sentAt = payload.sentAtMs;

        if (sentAt > 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - sentAt < const Duration(seconds: 15).inMilliseconds &&
              _shouldDisplayIncomingAlert(payload, currentUid: userUid)) {
            _showMissYouScreen(payload);
          }
        }
      }
    }, onError: (Object error) {
      debugPrint('Home miss interaction listener failed: $error');
    });
  }

  void _setupSettingsSubscription(
    String houseId,
    int sessionId,
    bool Function() isStale,
    String cacheKey,
    String cachedRelMode,
    String msgCacheSettingsFail,
    String msgLoadDataFail,
  ) {
    _settingsSubscription?.cancel();
    _settingsSubscription = _dbRef
        .child('houses/$houseId/settings')
        .onValue
        .listen((event) async {
      if (isStale()) return;
      final snapshot = event.snapshot;
      if (snapshot.value is Map && mounted) {
        final settings = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(snapshot.value as Map),
        );
        final nextShowStatus = settings.containsKey('showStatus')
            ? _readBoolSettingFlagImpl(
                settings['showStatus'],
                fallback: _showStatus,
              )
            : _showStatus;
        final nextShowWeather = settings.containsKey('showWeather')
            ? _readBoolSettingFlagImpl(
                settings['showWeather'],
                fallback: _showWeather,
              )
            : _showWeather;
        final visibilityPrefsChanged = nextShowStatus != _showStatus ||
            nextShowWeather != _showWeather;
        final relMode =
            (settings['relationshipMode'] ?? 'single').toString();
        final settingsKey = _buildInsightSettingsKeyImpl(settings, relMode);
        final payloadSignature =
            _buildCanonicalSettingsPayloadSignatureImpl(settings);
        final widgetSettingsKey = _buildWidgetSettingsSyncKeyImpl(settings);
        final shouldApplySettings =
            _lastHomeSettingsPayloadSignature != payloadSignature;
        final shouldSyncWidget =
            _lastWidgetSettingsSyncKey != widgetSettingsKey;

        if (visibilityPrefsChanged) {
          final prefs = OfflineCacheService.getPrefsSync() ??
              await SharedPreferences.getInstance();
          if (isStale()) return;
          await prefs.setBool('il_show_status', nextShowStatus);
          await prefs.setBool('il_show_weather', nextShowWeather);
          if (isStale()) return;
        }

        if (shouldApplySettings) {
          _lastHomeSettingsPayloadSignature = payloadSignature;

          try {
            await OfflineCacheService.saveCache(cacheKey, settings);
          } catch (e) {
            debugPrint(
              'Error saving settings to cache: ${AppErrorMapper.resolve(
                e,
                fallbackMessage: msgCacheSettingsFail,
              ).message}',
            );
          }

          if (isStale()) return;
          if (!mounted) return;
          setState(() {
            _houseSettings = settings;
            _showStatus = nextShowStatus;
            _showWeather = nextShowWeather;
            _isLoading = false;
          });
          unawaited(_maybeShowFirstSetupGuide());
          _warmHomeMedia();
        } else if (visibilityPrefsChanged && mounted) {
          if (isStale()) return;
          setState(() {
            _showStatus = nextShowStatus;
            _showWeather = nextShowWeather;
          });
        } else if (_isLoading && mounted) {
          if (isStale()) return;
          setState(() => _isLoading = false);
          unawaited(_maybeShowFirstSetupGuide());
        }

        if (visibilityPrefsChanged) {
          if (nextShowWeather && _isTabActive) {
            _startWeatherRefreshLoop(houseId);
          } else {
            _weatherRefreshTimer?.cancel();
            _weatherRefreshTimer = null;
          }
        }
        if (_insightData == null ||
            (_lastInsightSettingsKey != settingsKey &&
                _pendingInsightSettingsKey != settingsKey)) {
          unawaited(
            _refreshHomeInsightsImpl(
              houseId: houseId,
              relationshipMode: relMode,
              settingsKey: settingsKey,
            ),
          );
        }
        if (shouldSyncWidget) {
          _lastWidgetSettingsSyncKey = widgetSettingsKey;
          _scheduleLoveWidgetSync(settings, includeDiaryMedia: true);
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    }, onError: (Object error) {
      debugPrint(
        'Home settings listener failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: msgLoadDataFail,
        ).message}',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _fetchHouseDataImpl({
    bool preserveVisibleState = false,
    bool preloadOnly = false,
  }) async {
    final msgMembersFail = L10nService().translate('home_khngthtitr_e4f662');
    final msgPresenceFail = L10nService().translate('home_khngthtitr_2ae6b3');
    final msgCacheSettingsFail = L10nService().translate('home_clixyra_775791');
    final msgLoadDataFail = L10nService().translate('home_khngthtidl_7be608');
    if (!_isTabActive && !preloadOnly) {
      return;
    }

    final previousHouseId = _houseId;
    final houseId = await _houseService.getCurrentHouseId();

    final normalizedPreviousHouseId = previousHouseId?.trim() ?? '';
    final normalizedNewHouseId = houseId?.trim() ?? '';
    final isNewHouseContext = normalizedNewHouseId.isEmpty ||
        normalizedPreviousHouseId != normalizedNewHouseId;

    if (!isNewHouseContext &&
        _presenceSubscription != null &&
        _settingsSubscription != null) {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final sessionId = _invalidateLiveWorkSessionImpl();
    if (isNewHouseContext) {
      // ⚡ Chỉ cancel bindings cũ khi đổi nhà context mới, tránh teardown listener rác
      _cancelLiveWorkBindingsImpl();
    }

    bool isStale() {
      return _isLiveWorkSessionStaleImpl(
        sessionId,
        allowInactive: preloadOnly,
      );
    }

    if (!preserveVisibleState) {
      _lastLoveWidgetSignature = '';
      _lastLoveWidgetAccountKey = '';
      _lastHomeSettingsPayloadSignature = '';
      _lastWidgetSettingsSyncKey = '';
      _lastInsightSettingsKey = null;
      _pendingInsightSettingsKey = null;
      _insightRequestSerial++;
      _presenceUiSignature = '';
      _hasLoadedPresenceSnapshot = false;
      _homeMapPreviewSignature = '';
      _cachedWidgetDiaryImageUrls = const <String>[];
      _reactionFlightsNotifier.value = const [];
      _seenReactionFlightIds.clear();
      _localReactionThrowMs.clear();
      _showDefaultHeartSuggestion = false;
      _smartInteractionPreset = _defaultSmartInteractionPreset();
      _manualInteractionPresetType = null;
      _rotationQueue.clear();
    }

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    // 1. Setup Timeout Fallback
    _setupTimeoutFallback(sessionId, isStale);

    try {
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (isStale()) return;
      _currentRole = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      final cachedRelMode = prefs.getString('il_rel_mode') ?? 'couple';
      _showStatus = prefs.getBool('il_show_status') ?? true;
      _showWeather = prefs.getBool('il_show_weather') ?? true;
      if (isStale()) return;

      if (houseId != null && houseId.isNotEmpty) {
        _houseId = houseId;
        final cacheKey = _homeSettingsCacheKey(houseId);
        final normalizedPreviousHouseId = previousHouseId?.trim() ?? '';
        final isNewHouseContext = normalizedPreviousHouseId.isEmpty ||
            normalizedPreviousHouseId != houseId.trim();
        final shouldKeepVisibleState =
            preserveVisibleState && _houseSettings != null;

        if (isNewHouseContext) {
          if (preserveVisibleState) {
            if (mounted) {
              setState(() => _isLoading = true);
            } else {
              _isLoading = true;
            }
          }
          if (!shouldKeepVisibleState) {
            _selectedHomeToolId = null;
            _houseSettings = null;
            // Giữ presenceData cũ đến khi listener đầu tiên kích hoạt
            // để tránh flash "trắng" UI khi chỉ thay đổi settings
            _hasLoadedPresenceSnapshot = false;
            _insightData = null;
          }
        }

        await _loadHomeToolSelection(houseId: houseId);
        if (isStale()) return;

        // 2. Load and Apply Settings
        await _loadAndApplySettings(
          houseId: houseId,
          cacheKey: cacheKey,
          cachedRelMode: cachedRelMode,
          isNewHouseContext: isNewHouseContext,
          preserveVisibleState: preserveVisibleState,
          isStale: isStale,
        );
        if (isStale()) return;

        if (preloadOnly) {
          _pinnedApps = await _utilityService.getPinnedApps();
          if (isStale()) return;

          final connected =
              await _houseSettingsService.isCoupleConnected(houseId);
          if (isStale()) return;

          if (mounted) {
            setState(() {
              _isCoupleConnected = connected;
              _isLoading = false;
            });
          } else {
            _isCoupleConnected = connected;
            _isLoading = false;
          }
          return;
        }

        // Setup immediate active bindings
        _wrapSetup(() => _listenHighlights(houseId), 'Highlights');
        _wrapSetup(() => _listenHomeCalendarEvents(houseId), 'Calendar');
        _wrapSetup(() => _listenHealthCycleForWidgetSync(houseId), 'HealthCycle');

        // 3. Delayed bindings setup
        _startDelayedListeners(houseId, sessionId, isStale);
        _startDelayedMapAndWeather(houseId, sessionId, isStale);

        _pinnedApps = await _utilityService.getPinnedApps();
        if (isStale()) return;

        final connected =
            await _houseSettingsService.isCoupleConnected(houseId);
        if (isStale()) return;
        if (mounted) setState(() => _isCoupleConnected = connected);

        // 4. Stream subscriptions setup
        _setupMembersSubscription(houseId, sessionId, isStale, msgMembersFail);
        _setupPresenceSubscription(houseId, sessionId, isStale, msgPresenceFail);
        unawaited(_albumService.cleanupExpiredTrash(houseId));

        // Setup presence fallback timer
        _startPresenceSnapshotFallback(sessionId, isStale);

        _setupAlertsAndPartnerInbox(houseId, sessionId, isStale, user.uid);
        _setupMissInteractionSubscription(houseId, sessionId, isStale, user.uid);
        _setupSettingsSubscription(
          houseId,
          sessionId,
          isStale,
          cacheKey,
          cachedRelMode,
          msgCacheSettingsFail,
          msgLoadDataFail,
        );
        return;
      }

      if (isStale()) return;
      if (mounted) {
        setState(() {
          _houseSettings = _buildDefaultHomeSettings();
          _presenceData = {};
          _presenceDataNotifier.value = _presenceData;
          _hasLoadedPresenceSnapshot = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Home data load failed: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: msgLoadDataFail,
        ).message}',
      );
      if (mounted) setState(() => _isLoading = false);
    }
    _lastFetchTime = DateTime.now();
  }
}
