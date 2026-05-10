// ignore_for_file: invalid_use_of_protected_member, unused_element

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
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _membersSubscription?.cancel();
    _membersSubscription = null;
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
    _loveCardsSubscription?.cancel();
    _loveCardsSubscription = null;
    _albumSubscription?.cancel();
    _albumSubscription = null;
    _noteSubscription?.cancel();
    _noteSubscription = null;
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
          : 'Đăng nhập thiết bị mới';
      final body = (data['msg']?.toString().trim().isNotEmpty ?? false)
          ? data['msg'].toString().trim()
          : 'Có thiết bị mới vừa đăng nhập vào tài khoản của nhà bạn.';

      _showLatestSnackBarImpl('⚠️ $title: $body');
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
    final nextSignature = _presenceUiSignatureForPayloadImpl(nextPresence);
    if (_presenceUiSignature == nextSignature || !mounted) {
      _presenceUiSignature = nextSignature;
      return;
    }

    _presenceUiSignature = nextSignature;
    setState(() {});
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
    _homeDistanceText = distanceText;
    _homeMapAlert = alertText;
    if (_homeMapPreviewSignature == nextSignature || !mounted) {
      _homeMapPreviewSignature = nextSignature;
      return;
    }

    _homeMapPreviewSignature = nextSignature;
    setState(() {});
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

  Future<void> _fetchHouseDataImpl({
    bool preserveVisibleState = false,
    bool preloadOnly = false,
  }) async {
    if (!_isTabActive && !preloadOnly) {
      return;
    }
    final sessionId = _invalidateLiveWorkSessionImpl();
    if (!preloadOnly) {
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
      _reactionFlights.clear();
      _seenReactionFlightIds.clear();
      _localReactionThrowMs.clear();
      _showDefaultHeartSuggestion = true;
      _smartInteractionPreset = _defaultSmartInteractionPreset();
      _manualInteractionPresetType = null;
    }

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    try {
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (isStale()) return;
      _currentRole = prefs.getString('il_role') ?? 'user1';
      final cachedRelMode = prefs.getString('il_rel_mode') ?? 'couple';
      _showStatus = prefs.getBool('il_show_status') ?? true;
      _showWeather = prefs.getBool('il_show_weather') ?? true;
      final previousHouseId = _houseId;
      final houseId = await _houseService.getCurrentHouseId();
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
            _presenceData = <String, dynamic>{};
            _hasLoadedPresenceSnapshot = false;
            _insightData = null;
          }
        }

        await _loadHomeToolSelection(houseId: houseId);
        if (isStale()) return;

        void applyResolvedHomeSettings(
          Map<String, dynamic> settings, {
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
            applyResolvedHomeSettings(
              cachedSettingsMap,
              delayMotion: preserveVisibleState && isNewHouseContext,
              forceWarmMedia: isNewHouseContext,
            );
          }
        }

        if (_houseSettings == null) {
          final initialSettingsSnap =
              await _dbRef.child('houses/$houseId/settings').get();
          if (isStale()) return;
          if (initialSettingsSnap.exists && initialSettingsSnap.value is Map) {
            _houseSettings = Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(initialSettingsSnap.value as Map),
            );
            await OfflineCacheService.saveCache(cacheKey, _houseSettings);
          } else {
            _houseSettings = _buildDefaultHomeSettings();
          }

          applyResolvedHomeSettings(_houseSettings!);
        }

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

        _listenHighlights(houseId);
        _listenNewDeviceNotifications(houseId);
        _listenInteractionSignals(houseId);
        _listenReactionFlights(houseId);
        _bindHomeMapPreview(houseId);
        unawaited(_ensureAppWideLocationTracking(houseId));
        if (_showWeather) {
          _startWeatherRefreshLoop(houseId);
        }
        _startInteractionRotationLoop();

        _pinnedApps = await _utilityService.getPinnedApps();
        if (isStale()) return;

        final connected =
            await _houseSettingsService.isCoupleConnected(houseId);
        if (isStale()) return;
        if (mounted) setState(() => _isCoupleConnected = connected);

        _membersSubscription =
            _dbRef.child('houses/$houseId/members').onValue.listen(
          (event) {
            if (isStale()) return;
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
                fallbackMessage: 'Không thể tải trạng thái thành viên.',
              ).message}',
            );
          },
        );

        _presenceSubscription =
            _dbRef.child('houses/$houseId/presence').onValue.listen(
          (event) {
            if (isStale()) return;
            if (event.snapshot.value != null && mounted) {
              final raw = event.snapshot.value;
              if (raw is Map) {
                final map = _toStringDynamicMap(raw);
                final hadLoadedPresenceSnapshot = _hasLoadedPresenceSnapshot;
                _hasLoadedPresenceSnapshot = true;
                final didUpdatePresence = _updatePresenceDataIfNeededImpl(map);
                if (!didUpdatePresence &&
                    !hadLoadedPresenceSnapshot &&
                    mounted) {
                  setState(() {});
                }

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
            } else if (mounted) {
              final hadLoadedPresenceSnapshot = _hasLoadedPresenceSnapshot;
              _hasLoadedPresenceSnapshot = true;
              final didUpdatePresence =
                  _updatePresenceDataIfNeededImpl(const <String, dynamic>{});
              if (!didUpdatePresence && !hadLoadedPresenceSnapshot) {
                setState(() {});
              }
              if (didUpdatePresence && _houseSettings != null) {
                _scheduleLoveWidgetSync(
                  _houseSettings!,
                  includeDiaryMedia: false,
                );
              }
            }
          },
          onError: (Object error) {
            debugPrint(
              'Home presence listener failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể tải trạng thái hiện diện.',
              ).message}',
            );
          },
        );

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

          if (!_shouldDisplayIncomingAlert(payload, currentUid: user.uid)) {
            return;
          }

          final key = event.snapshot.key;
          await _deliverIncomingAlert(
            payload,
            removalPath: key == null ? null : 'houses/$houseId/alerts/$key',
          );
        });

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

          if (!_shouldDisplayIncomingAlert(payload, currentUid: user.uid)) {
            return;
          }

          await _deliverIncomingAlert(
            payload,
            removalPath: key == null
                ? null
                : 'houses/$houseId/partner_inbox/$_currentRole/$key',
          );
        });

        _loveCardsSubscription = _dbRef
            .child('houses/$houseId/love_cards')
            .orderByChild('ts')
            .onChildAdded
            .listen((event) {
          if (isStale()) return;
          if (event.snapshot.value == null || !mounted) return;
          final data = _toStringDynamicMap(event.snapshot.value);
          final isOpened = data['isOpened'] == true;
          final fromUid = data['fromUid']?.toString() ?? '';
          final myUid = user.uid;

          if (!isOpened && fromUid != myUid) {}
        });

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
                  _shouldDisplayIncomingAlert(payload, currentUid: user.uid)) {
                _showMissYouScreen(payload);
              }
            }
          }
        });

        _settingsSubscription = _dbRef
            .child('houses/$houseId/settings')
            .onValue
            .listen((event) async {
          if (isStale()) return;
          if (event.snapshot.value is Map && mounted) {
            final settings = Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(event.snapshot.value as Map),
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
              final prefs = await SharedPreferences.getInstance();
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
                    fallbackMessage: 'Đã có lỗi xảy ra',
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
        });
        return;
      }
      if (isStale()) return;
      if (mounted) {
        setState(() {
          _houseSettings = _buildDefaultHomeSettings();
          _presenceData = {};
          _hasLoadedPresenceSnapshot = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
