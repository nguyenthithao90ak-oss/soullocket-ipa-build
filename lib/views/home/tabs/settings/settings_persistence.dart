part of '../settings_tab.dart';

const Duration _countdownAdUnlockWindow = Duration(days: 7);
const List<String> _countdownPremiumStyleKeys = <String>[
  'galaxy',
  'aurora',
  'crystal',
  'fireworks',
  'lava',
];

extension _SettingsTabPersistence on _SettingsTabState {
  Future<void> _persistHomeDisplayPrefsQuickly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('il_show_weather', _showWeather);
    await prefs.setBool('il_show_status', _showStatus);
    await prefs.setBool('il_home_show_house_name', _homeShowHouseName);
    await prefs.setBool('il_home_show_timer', _homeShowTimer);

    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      return;
    }

    if (!mounted) return;
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.saveSecondaryEmail,
      houseId: _houseId,
    );
    if (!canContinue) {
      return;
    }

    try {
      await _dbRef.child('houses/$houseId/settings').update({
        'showWeather': _showWeather,
        'showStatus': _showStatus,
        'homeShowHouseName': _homeShowHouseName,
        'homeShowTimer': _homeShowTimer,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  void _updateThemeDraft(VoidCallback updateFn) {
    setState(updateFn);
    _applyThemeDraftToUiPrefsPreview();
    _autoSaveThemeTimer?.cancel();
    if (mounted) {
      _autoSaveThemeTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        unawaited(_saveThemeSettings(silent: true));
      });
    }
  }

  void _applyThemeDraftToUiPrefsPreview() {
    if (!UiPrefs.isLoaded) {
      return;
    }
    final ui = UiPrefs.notifier.value;
    final nextState = ui.copyWith(
      themeKey: (_draftThemeKey ?? ui.themeKey).trim(),
      fallingEffectKey: (_draftEffectKey ?? ui.fallingEffectKey).trim(),
      avatarSizePx: _draftAvatarSizePx ?? ui.avatarSizePx,
      countdownSizePx: _draftCountdownSizePx ?? ui.countdownSizePx,
      avatarFrameKey: _resolveAllowedAvatarFrameKey(
        (_draftAvatarFrameKey ?? ui.avatarFrameKey).trim(),
      ),
      countdownStyleKey:
          (_draftCountdownStyleKey ?? ui.countdownStyleKey).trim(),
      fontKey: (_draftFontKey ?? ui.fontKey).trim(),
      homeBlockToneKey: (_draftHomeBlockToneKey ?? ui.homeBlockToneKey).trim(),
      liteMode: _draftLiteMode,
      graphicsQualityKey:
          (_draftGraphicsQualityKey ?? ui.graphicsQualityKey).trim(),
      customBackgroundUrl:
          (_draftCustomBackgroundUrl ?? ui.customBackgroundUrl).trim(),
      transparentMode: _draftTransparentMode ?? ui.transparentMode,
    );
    if (UiPrefs.notifier.value != nextState) {
      UiPrefs.notifier.value = nextState;
    }
  }

  int _widgetMemorySortValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  List<String> _extractWidgetDiaryUrls(
    dynamic raw, {
    int limit = 5,
  }) {
    if (raw is! Map) return const <String>[];

    final items = <MapEntry<int, String>>[];
    raw.forEach((_, value) {
      if (value is! Map) return;
      final map = value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
      final imageUrl = (map['url'] ?? map['imageUrl'] ?? map['thumbUrl'] ?? '')
          .toString()
          .trim();
      if (imageUrl.isEmpty) return;
      final sortValue = _widgetMemorySortValue(
        map['ts'] ?? map['date'] ?? map['updatedAt'],
      );
      items.add(MapEntry(sortValue, imageUrl));
    });

    items.sort((a, b) => b.key.compareTo(a.key));
    final seen = <String>{};
    return items
        .map((item) => item.value)
        .where((url) => seen.add(url))
        .take(limit)
        .toList(growable: false);
  }

  Future<List<String>> _loadWidgetDiaryUrls({int limit = 5}) async {
    final houseId = _houseId?.trim();
    if (houseId == null || houseId.isEmpty) {
      return const <String>[];
    }
    try {
      final snapshot =
          await _dbRef.child('houses/$houseId/memories').limitToLast(12).get();
      return _extractWidgetDiaryUrls(snapshot.value, limit: limit);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _syncWidgetAppearanceDraft() async {
    if (kIsWeb) return;
    final widgetThemeKey = _draftWidgetThemeKey ?? 'pink';
    final diaryImageUrls =
        _showDiaryOnWidget ? await _loadWidgetDiaryUrls() : const <String>[];
    await WidgetService.updateWidgetAppearance(
      bgTheme: widgetThemeKey,
      widgetStyleKey: _widgetStyleKey,
      showDiaryOnWidget: _showDiaryOnWidget,
      heartAnimated: _widgetHeartAnimated,
      heartStyleKey: _widgetHeartStyleKey,
      heartColorKey: _widgetHeartColorKey,
      diaryLayoutKey: _widgetDiaryLayoutKey,
      seasonModeKey: _widgetSeasonModeKey,
      loveDate: _loveDate,
      birthday1: _dobU1,
      birthday2: _dobU2,
      diaryImageUrls: diaryImageUrls,
    );
  }

  // ignore: unused_element
  Future<void> _legacyLoadAppLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final localCustomLock = (prefs.getString('il_custom_lock') ?? '').trim();
    final localCustomLockSalt =
        (prefs.getString('il_custom_lock_salt') ?? '').trim();
    final localCustomLockLength = prefs.getInt('il_custom_lock_length');
    final localConfiguredAt = prefs.getInt('il_custom_lock_configured_at');
    final localEnabled = (prefs.getBool('il_app_lock_enabled') ?? false) &&
        localCustomLock.isNotEmpty;
    final localScopes = MilitaryLockService.normalizeScopeStorageConfig(
      {
        'app': prefs.getBool('il_lock_scope_app') ?? true,
        'security': prefs.getBool('il_lock_scope_security') ?? false,
        'diary': prefs.getBool('il_lock_scope_diary') ?? false,
        'chat': prefs.getBool('il_lock_scope_chat') ?? false,
        'private': prefs.getBool('il_lock_scope_private') ?? false,
      },
      enabled: localEnabled,
    );
    if (mounted) {
      setState(() {
        _appLockSettingsLoaded = true;
        _isAppLockEnabled = localEnabled;
        _useBiometrics =
            localEnabled && (prefs.getBool('il_use_biometrics') ?? false);
        _lockTimeout = prefs.getInt('il_lock_timeout') ?? 0;
        _isMilitaryMode =
            localEnabled && (prefs.getBool('il_military_mode') ?? false);
        _lockConfiguredAtMs = localConfiguredAt;
        _applyStoredLockDraft(
          secret: localCustomLock,
          salt: localCustomLockSalt,
          pinLength: localCustomLockLength,
        );
        _notificationsEnabled =
            prefs.getBool('il_notifications_enabled') ?? true;
        _applyLockScopeDrafts(localScopes);
      });
    }
  }

  // ignore: unused_element
  Future<void> _legacySaveAppLockSettings() async {
    try {
      final wantsAppLock = _isAppLockEnabled;
      final enteredLock = _customLockCtrl.text.trim();
      final existingLock = _storedLockSecret.trim();
      LockSecretRecord? storedSecretRecord;
      if (wantsAppLock) {
        if (enteredLock.isNotEmpty) {
          final validationError =
              _militaryLockService.validateCustomLock(enteredLock);
          if (validationError != null) {
            _showToast(validationError, success: false);
            return;
          }
          storedSecretRecord =
              _militaryLockService.createStoredLockSecret(enteredLock);
        } else if (existingLock.isNotEmpty) {
          if (_militaryLockService.canRevealPlaintextLock(
            secret: existingLock,
            salt: _storedLockSalt,
          )) {
            storedSecretRecord =
                _militaryLockService.createStoredLockSecret(existingLock);
          } else {
            storedSecretRecord = LockSecretRecord(
              secret: existingLock,
              salt: _storedLockSalt,
              pinLength: _storedLockLength,
            );
          }
        } else {
          _showToast(context.tr('home_hythitlpmp_44a093'), success: false);
          return;
        }
        if (!_lockScopes.values.any((value) => value)) {
          _showToast(context.tr('home_hychntnht1_54215e'), success: false);
          return;
        }
      }

      final persistedScopes = MilitaryLockService.normalizeScopeStorageConfig(
        _lockScopes,
        enabled: wantsAppLock,
      );
      final persistedUseBiometrics = wantsAppLock ? _useBiometrics : false;
      final persistedMilitaryMode = wantsAppLock ? _isMilitaryMode : false;
      final persistedCustomLock =
          wantsAppLock ? (storedSecretRecord?.secret ?? '') : '';
      final persistedCustomLockSalt =
          wantsAppLock ? storedSecretRecord?.salt : null;
      final persistedCustomLockLength =
          wantsAppLock ? storedSecretRecord?.pinLength : null;
      final persistedConfiguredAt = wantsAppLock
          ? ((enteredLock.isNotEmpty || _lockConfiguredAtMs == null)
              ? DateTime.now().millisecondsSinceEpoch
              : _lockConfiguredAtMs)
          : null;

      if (mounted) {
        setState(() {
          _useBiometrics = persistedUseBiometrics;
          _isMilitaryMode = persistedMilitaryMode;
          _lockConfiguredAtMs = persistedConfiguredAt;
          _applyLockScopeDrafts(persistedScopes);
          _applyStoredLockDraft(
            secret: persistedCustomLock,
            salt: persistedCustomLockSalt,
            pinLength: persistedCustomLockLength,
          );
        });
      }

      await _militaryLockService.saveLocalLockSettings(
        enabled: wantsAppLock,
        useBiometrics: persistedUseBiometrics,
        timeoutMinutes: _lockTimeout,
        militaryMode: persistedMilitaryMode,
        customLock: persistedCustomLock,
        customLockSalt: persistedCustomLockSalt,
        customLockLength: persistedCustomLockLength,
        configuredAtEpochMs: persistedConfiguredAt,
        scopeMap: persistedScopes,
      );
      if (!wantsAppLock) {
        _militaryLockService.lockAllScopes();
      }
      final houseId = _houseId?.trim();
      if (houseId != null && houseId.isNotEmpty) {
        unawaited(
          _clearRemoteAppLockSyncArtifacts(houseId: houseId).catchError((_) {}),
        );
      }

      if (!mounted) return;
      _showToast(
        context.tr('home_lucitbomtt_c60175'),
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(
        context.tr('home_khngthluci_eb591a'),
        success: false,
      );
    }
  }

  // ignore: unused_element
  Future<void> _legacyClearRemoteAppLockSyncArtifacts({String? houseId}) async {
    final resolvedHouseId = (houseId ?? _houseId ?? '').trim();
    if (resolvedHouseId.isEmpty) {
      return;
    }

    await _dbRef.update({
      'houses/$resolvedHouseId/security/lock': null,
      'houses/$resolvedHouseId/settings/appLocked': null,
      'houses/$resolvedHouseId/settings/customLock': null,
      'houses/$resolvedHouseId/settings/customLockSalt': null,
      'houses/$resolvedHouseId/settings/customLockLength': null,
      'houses/$resolvedHouseId/settings/appLockConfiguredAt': null,
      'houses/$resolvedHouseId/settings/appLockFaceId': null,
      'houses/$resolvedHouseId/settings/appLockScopes': null,
    });
  }

  // ignore: unused_element
  Future<void> _legacyMigrateHousePinToPrivate({
    required String houseId,
    required String rawPin,
  }) async {
    final trimmedPin = rawPin.trim();
    if (trimmedPin.isEmpty) {
      return;
    }

    await _dbRef.update({
      'house_private_security/$houseId/pinHash':
          _authService.hashHousePin(trimmedPin),
      'house_private_security/$houseId/updatedAt': ServerValue.timestamp,
      'houses/$houseId/security/pin': null,
      'houses/$houseId/security/pinConfigured': true,
      'houses/$houseId/security/pinUpdatedAt': ServerValue.timestamp,
      'houses/$houseId/security/updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await UiPrefs.ensureLoaded();
    final ui = UiPrefs.notifier.value;
    final currentUid = _auth.currentUser?.uid ?? 'guest';
    final houseIdKey = _houseId ?? 'local';
    final accountKey = '${currentUid}_$houseIdKey';
    final localGreetingQuote = (prefs.getString('il_greeting_quote_text') ??
            prefs.getString('il_auto_reply_text') ??
            '')
        .trim();
    final localLoveUnit = (prefs.getString('il_love_unit_text') ?? '').trim();
    if (!mounted) return;
    setState(() {
      _musicAutoplay = prefs.getBool('il_music_autoplay') ?? false;
      _bgMusicUrl = (prefs.getString('il_local_music_url') ?? '').trim();
      _bgMusicTitle = (prefs.getString('il_local_music_title') ?? '').trim();
      _bgMusicType = (prefs.getString('il_local_music_type') ?? 'audio').trim();
      _notifAnniversary = prefs.getBool('il_notif_anniversary') ?? true;
      _notifPost = prefs.getBool('il_notif_post') ?? true;
      _notifChat = prefs.getBool('il_notif_chat') ?? true;
      _notifFriend = prefs.getBool('il_notif_friend') ?? true;
      _notifHeart = prefs.getBool('il_notif_heart') ?? true;
      _smartDiaryReminder = prefs.getBool('il_smart_reminder_diary') ?? true;
      _smartCapsuleReminder =
          prefs.getBool('il_smart_reminder_capsule') ?? true;
      _smartLoveNoteReminder =
          prefs.getBool('il_smart_reminder_love_note') ?? true;
      _touchSound = prefs.getBool('il_touch_sound') ?? true;
      _confettiFx = prefs.getBool('il_confetti_fx') ?? true;
      _showWeather = prefs.getBool('il_show_weather') ?? true;
      _showStatus = prefs.getBool('il_show_status') ?? true;
      _homeShowHouseName =
          prefs.getBool('il_home_show_house_name') ?? _homeShowHouseName;
      _homeShowTimer = prefs.getBool('il_home_show_timer') ?? _homeShowTimer;
      if ((_houseId ?? '').trim().isEmpty) {
        _autoReplyCtrl.text = localGreetingQuote;
        if (localLoveUnit.isNotEmpty) {
          _loveUnit = localLoveUnit;
          _loveUnitCtrl.text = localLoveUnit;
        }
      }
      _draftThemeKey ??= ui.themeKey;
      _draftEffectKey ??= ui.fallingEffectKey;
      _draftAvatarSizePx ??= ui.avatarSizePx;
      _draftCountdownSizePx ??= ui.countdownSizePx;
      _draftAvatarFrameKey ??= ui.avatarFrameKey;
      _draftCountdownStyleKey ??= ui.countdownStyleKey;
      _draftFontKey ??= ui.fontKey;
      _draftHomeBlockToneKey ??= ui.homeBlockToneKey;
      _draftGraphicsQualityKey ??= ui.graphicsQualityKey;

      _draftWidgetThemeKey ??= prefs.getString('il_widget_theme_$accountKey') ??
          prefs.getString('il_widget_theme') ??
          'pink';
      _widgetStyleKey = WidgetService.normalizeWidgetStyleKey(
        prefs.getString('il_widget_style_$accountKey') ??
            prefs.getString('il_widget_style') ??
            WidgetService.defaultWidgetStyleKey,
      );
      _widgetPanelTabKey = _widgetStyleKey;
      _showDiaryOnWidget = prefs.getBool('il_widget_show_diary_$accountKey') ??
          prefs.getBool('il_widget_show_diary') ??
          true;
      _widgetHeartAnimated =
          prefs.getBool('il_widget_heart_animated_$accountKey') ??
              prefs.getBool('il_widget_heart_animated') ??
              true;
      final widgetDisplayMode = WidgetService.normalizeWidgetDisplayMode(
        showDiaryOnWidget: _showDiaryOnWidget,
        heartAnimated: _widgetHeartAnimated,
      );
      _showDiaryOnWidget = widgetDisplayMode.showDiaryOnWidget;
      _widgetHeartAnimated = widgetDisplayMode.heartAnimated;
      _widgetHeartStyleKey = _normalizeWidgetHeartStyleKey(
        prefs.getString('il_widget_heart_style_$accountKey') ??
            prefs.getString('il_widget_heart_style') ??
            _defaultWidgetHeartStyleKey,
      );
      _widgetHeartColorKey =
          prefs.getString('il_widget_heart_color_$accountKey') ??
              prefs.getString('il_widget_heart_color') ??
              'rose';
      _widgetPreviewSizeKey =
          prefs.getString('il_widget_preview_size_$accountKey') ??
              prefs.getString('il_widget_preview_size') ??
              'medium';
      _widgetDiaryLayoutKey =
          prefs.getString('il_widget_diary_layout_$accountKey') ??
              prefs.getString('il_widget_diary_layout') ??
              'single';
      _widgetSeasonModeKey =
          prefs.getString('il_widget_season_mode_$accountKey') ??
              prefs.getString('il_widget_season_mode') ??
              'auto';
      _draftCustomBackgroundUrl ??= ui.customBackgroundUrl;
      _draftTransparentMode ??= ui.transparentMode;
      _draftLiteMode = ui.liteMode;

      final now = DateTime.now().millisecondsSinceEpoch;
      final storedUnlockExpiry =
          prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
      final legacyUnlockTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      final legacyUnlockedRaw =
          prefs.getStringList('il_unlocked_countdown_styles') ?? [];
      var resolvedUnlockExpiry = storedUnlockExpiry;

      if (resolvedUnlockExpiry <= 0 &&
          (legacyUnlockTs > 0 || legacyUnlockedRaw.isNotEmpty)) {
        final baseTs = legacyUnlockTs > 0 ? legacyUnlockTs : now;
        resolvedUnlockExpiry = baseTs + _countdownAdUnlockWindow.inMilliseconds;
      }

      final hasCountdownAdPass = resolvedUnlockExpiry > now;
      _countdownAdUnlockExpiryMs =
          hasCountdownAdPass ? resolvedUnlockExpiry : 0;
      _unlockedCountdownStyles =
          hasCountdownAdPass ? _countdownPremiumStyleKeys.toSet() : <String>{};
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedUnlockExpiry =
        prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    final legacyUnlockTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
    final legacyUnlockedRaw =
        prefs.getStringList('il_unlocked_countdown_styles') ?? [];
    final shouldPersistResolvedUnlock =
        normalizedUnlockExpiry != _countdownAdUnlockExpiryMs ||
            (legacyUnlockedRaw.isNotEmpty && _countdownAdUnlockExpiryMs == 0) ||
            (legacyUnlockTs > 0 && _countdownAdUnlockExpiryMs == 0);
    if (shouldPersistResolvedUnlock) {
      if (_countdownAdUnlockExpiryMs > now) {
        await prefs.setInt(
          'il_countdown_unlock_weekly_expiry_v2',
          _countdownAdUnlockExpiryMs,
        );
        await prefs.setStringList(
          'il_unlocked_countdown_styles',
          _countdownPremiumStyleKeys,
        );
      } else {
        await prefs.remove('il_countdown_unlock_weekly_expiry_v2');
        await prefs.remove('il_countdown_unlock_ad_ts');
        await prefs.setStringList('il_unlocked_countdown_styles', const []);
      }
    }
  }

  bool _hasActiveCountdownAdUnlock() {
    return _countdownAdUnlockExpiryMs > DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _saveCountdownAdUnlockWindow() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _countdownAdUnlockExpiryMs = now + _countdownAdUnlockWindow.inMilliseconds;
    _unlockedCountdownStyles = _countdownPremiumStyleKeys.toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'il_countdown_unlock_weekly_expiry_v2',
      _countdownAdUnlockExpiryMs,
    );
    await prefs.setInt('il_countdown_unlock_ad_ts', now);
    await prefs.setStringList(
        'il_unlocked_countdown_styles', _countdownPremiumStyleKeys);
  }

  bool _isThemeDraftDirty(UiPrefsState ui) {
    final draftTheme = (_draftThemeKey ?? ui.themeKey).trim();
    final draftEffect = (_draftEffectKey ?? ui.fallingEffectKey).trim();
    final draftAvatarSize = _draftAvatarSizePx ?? ui.avatarSizePx;
    final draftCountdownSize = _draftCountdownSizePx ?? ui.countdownSizePx;
    final draftAvatarFrame = (_draftAvatarFrameKey ?? ui.avatarFrameKey).trim();
    final draftCountdownStyle =
        (_draftCountdownStyleKey ?? ui.countdownStyleKey).trim();
    final draftFont = (_draftFontKey ?? ui.fontKey).trim();
    final draftTone = (_draftHomeBlockToneKey ?? ui.homeBlockToneKey).trim();
    final draftQuality =
        (_draftGraphicsQualityKey ?? ui.graphicsQualityKey).trim();
    final draftBackground =
        (_draftCustomBackgroundUrl ?? ui.customBackgroundUrl).trim();

    return draftTheme != ui.themeKey ||
        draftEffect != ui.fallingEffectKey ||
        (draftAvatarSize - ui.avatarSizePx).abs() > 0.01 ||
        (draftCountdownSize - ui.countdownSizePx).abs() > 0.01 ||
        draftAvatarFrame != ui.avatarFrameKey ||
        draftCountdownStyle != ui.countdownStyleKey ||
        draftFont != ui.fontKey ||
        draftTone != ui.homeBlockToneKey ||
        _draftLiteMode != ui.liteMode ||
        _draftTransparentMode != ui.transparentMode ||
        draftQuality != ui.graphicsQualityKey ||
        draftBackground != ui.customBackgroundUrl ||
        _draftWidgetThemeKey != null;
  }

  Future<void> _saveThemeSettings({bool silent = false}) async {
    final missingDataMsg = context.tr('home_thiudliugi_e5d4ed');
    final notDirtyMsg = context.tr('home_giaodinhin_c0fb51');
    final successMsg = context.tr('home_lugiaodint_742be7');
    final errorMsg = context.tr('home_khngthlugi_4e7f1d');

    final houseId = _houseId?.trim();
    if (houseId != null &&
        houseId.isNotEmpty &&
        !await _ensureCanModifySharedInfo(showToast: !silent)) {
      return;
    }
    await UiPrefs.ensureLoaded();
    final ui = UiPrefs.notifier.value;
    final themeKey = (_draftThemeKey ?? ui.themeKey).trim();
    final effectKey = (_draftEffectKey ?? ui.fallingEffectKey).trim();
    final avatarSizePx = _draftAvatarSizePx ?? ui.avatarSizePx;
    final countdownSizePx = _draftCountdownSizePx ?? ui.countdownSizePx;
    final avatarFrameKey = _resolveAllowedAvatarFrameKey(
        (_draftAvatarFrameKey ?? ui.avatarFrameKey).trim());
    final countdownStyleKey =
        (_draftCountdownStyleKey ?? ui.countdownStyleKey).trim();
    final fontKey = (_draftFontKey ?? ui.fontKey).trim();
    final homeBlockToneKey =
        (_draftHomeBlockToneKey ?? ui.homeBlockToneKey).trim();
    final graphicsQualityKey =
        (_draftGraphicsQualityKey ?? ui.graphicsQualityKey).trim();
    final customBackgroundUrl =
        (_draftCustomBackgroundUrl ?? ui.customBackgroundUrl).trim();
    final widgetThemeKey = _draftWidgetThemeKey ?? 'pink';
    final transparentMode = _draftTransparentMode ?? ui.transparentMode;
    final oldSavedUrl = ui.customBackgroundUrl;

    if (themeKey.isEmpty ||
        effectKey.isEmpty ||
        avatarFrameKey.isEmpty ||
        countdownStyleKey.isEmpty ||
        fontKey.isEmpty ||
        homeBlockToneKey.isEmpty ||
        graphicsQualityKey.isEmpty) {
      if (!silent) {
        _showToast(missingDataMsg, success: false);
      }
      return;
    }

    if (!_isThemeDraftDirty(ui) && _houseId == null) {
      if (!silent) {
        _showToast(notDirtyMsg, success: false);
      }
      return;
    }

    if (!silent) setState(() => _isSavingTheme = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      final currentUid = _auth.currentUser?.uid ?? 'guest';
      final houseIdKey = _houseId ?? 'local';
      final accountKey = '${currentUid}_$houseIdKey';

      await prefs.setString('il_widget_theme_$accountKey', widgetThemeKey);
      await prefs.setString('il_widget_style_$accountKey', _widgetStyleKey);
      await prefs.setBool(
          'il_widget_show_diary_$accountKey', _showDiaryOnWidget);
      await prefs.setBool(
          'il_widget_heart_animated_$accountKey', _widgetHeartAnimated);
      await prefs.setString(
          'il_widget_heart_style_$accountKey', _widgetHeartStyleKey);
      await prefs.setString(
          'il_widget_heart_color_$accountKey', _widgetHeartColorKey);
      await prefs.setString(
          'il_widget_preview_size_$accountKey', _widgetPreviewSizeKey);
      await prefs.setString(
          'il_widget_diary_layout_$accountKey', _widgetDiaryLayoutKey);
      await prefs.setString(
          'il_widget_season_mode_$accountKey', _widgetSeasonModeKey);
      await _syncWidgetAppearanceDraft();

      await UiPrefs.saveState(
        ui.copyWith(
          themeKey: themeKey,
          fallingEffectKey: effectKey,
          avatarSizePx: avatarSizePx,
          countdownSizePx: countdownSizePx,
          avatarFrameKey: avatarFrameKey,
          countdownStyleKey: countdownStyleKey,
          fontKey: fontKey,
          homeBlockToneKey: homeBlockToneKey,
          liteMode: _draftLiteMode,
          graphicsQualityKey: graphicsQualityKey,
          customBackgroundUrl: customBackgroundUrl,
          transparentMode: transparentMode,
        ),
      );
      if (_houseId != null) {
        await _dbRef.child('houses/$_houseId/settings').update({
          'theme': themeKey,
          'fallingEffect': effectKey,
          'avatarSizePx': avatarSizePx,
          'countdownSizePx': countdownSizePx,
          'avatarFrame': avatarFrameKey,
          'countdownStyle': countdownStyleKey,
          'font': fontKey,
          'homeBlockTone': homeBlockToneKey,
          'customBackgroundUrl': customBackgroundUrl,
          'customHomeBackground': customBackgroundUrl,
          'transparentMode': transparentMode,
          'updatedAt': ServerValue.timestamp,
        });
      }

      if (oldSavedUrl.isNotEmpty && oldSavedUrl != customBackgroundUrl) {
        try {
          _storageService.deleteImageByUrl(oldSavedUrl);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _draftThemeKey = themeKey;
        _draftEffectKey = effectKey;
        _draftAvatarSizePx = avatarSizePx;
        _draftCountdownSizePx = countdownSizePx;
        _draftAvatarFrameKey = avatarFrameKey;
        _draftCountdownStyleKey = countdownStyleKey;
        _draftFontKey = fontKey;
        _draftHomeBlockToneKey = homeBlockToneKey;
        _draftGraphicsQualityKey = graphicsQualityKey;
        _draftCustomBackgroundUrl = customBackgroundUrl;
        _draftTransparentMode = transparentMode;
        // Force home/settings surfaces to re-evaluate style immediately.
        _showSettingsSyncBanner = false;
      });

      // Trigger notifier assignment to ensure listeners redraw even when
      // copyWith values are same as current saved state edge-cases.
      UiPrefs.notifier.value = UiPrefs.notifier.value.copyWith();
      _showToast(
        successMsg,
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        _showToast(
          errorMsg,
          success: false,
        );
      }
    } finally {
      if (mounted) {
        if (!silent) setState(() => _isSavingTheme = false);
      }
    }
  }

//   Future<void> _saveAdvancedSettings({bool silent = false}) async {
//     if (!silent) setState(() => _isSavingAdvanced = true);
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('il_notifications_enabled', _notificationsEnabled);
//       await prefs.setBool('il_notif_anniversary', _notifAnniversary);
//       await prefs.setBool('il_notif_post', _notifPost);
//       await prefs.setBool('il_notif_chat', _notifChat);
//       await prefs.setBool('il_notif_friend', _notifFriend);
//       await prefs.setBool('il_notif_heart', _notifHeart);
//       await prefs.setBool('il_touch_sound', _touchSound);
//       await prefs.setBool('il_confetti_fx', _confettiFx);
//       await prefs.setBool('il_show_weather', _showWeather);
//       await prefs.setBool('il_show_status', _showStatus);
//       await prefs.setString('il_auto_reply_text', _autoReplyCtrl.text.trim());
//       if (!silent) _showToast(context.tr('home_lucitnngca_14ab51'), success: true);
//     } catch (e) {
//       if (!silent) {
//         _showToast('KhÃ´ng thá»ƒ lÆ°u cÃ i Ä‘áº·t nÃ¢ng cao: $e', success: false);
//       }
//     } finally {
//       if (mounted) {
//         if (!silent) setState(() => _isSavingAdvanced = false);
//       }
//     }
//   }

  Future<void> _loadVipStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final vipPlanSettingLabel = context.tr('home_thngtinhs_283d9c');
    final activeLabel = context.tr('home_anghotng_cfaecd');
    final basicAccountLabel = context.tr('home_tikhonbasi_5bd48d');
    final nonVipExpiryLabel = context.tr('home_gicbnangho_ce2f95');
    final freePlanLabel = context.tr('home_giminph_5edaf7');
    final inactiveVipExpiryLabel = context.tr('home_chakchhot_27fec1');
    final activatedByPartnerLabel = context.tr('home_kchhotchon_c1a2d2');

    if (!AppConfig.isPurchaseEnabled) {
      if (mounted) {
        setState(() {
          _isVipActive = false;
          _vipPlanLabel = vipPlanSettingLabel;
          _vipExpiryLabel = activeLabel;
          _vipPlanCode = '';
          _isLifetimeVip = false;
        });
      }
      return;
    }

    try {
      final access = await PurchaseService()
          .getVipAccessInfo()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw Exception();
      });

      final vipActive = access.isVip;
      final planCode = access.planId;
      final isLifetimeVip = access.isLifetime;
      final planLabel = vipActive
          ? _labelForVipPlan(planCode)
          : basicAccountLabel;
      final expiryLabel = vipActive
          ? _formatVipExpiry(access.expiresAtMs)
          : nonVipExpiryLabel;

      if (mounted) {
        setState(() {
          _isVipActive = vipActive;
          _vipPlanLabel = planLabel;
          _vipExpiryLabel = expiryLabel;
          _vipPlanCode = planCode;
          _isLifetimeVip = isLifetimeVip;
        });
      }
      return;
    } catch (_) {}

    bool vipActive = false;
    String planLabel = freePlanLabel;
    String expiryLabel = inactiveVipExpiryLabel;

    try {
      final userVipSnap = await _dbRef
          .child('users/${user.uid}/vip')
          .get()
          .timeout(const Duration(seconds: 3),
              onTimeout: () => throw Exception());
      if (userVipSnap.exists && userVipSnap.value is Map) {
        final vip = Map<dynamic, dynamic>.from(userVipSnap.value as Map);

        vipActive = vip['isVip'] == true;
        planLabel = _labelForVipPlan(vip['vipPlan']?.toString());
        expiryLabel = _formatVipExpiry(vip['vipExpiresAt']);
      } else if (_houseId != null) {
        final houseVipSnap = await _dbRef
            .child('houses/$_houseId/vip')
            .get()
            .timeout(const Duration(seconds: 3),
                onTimeout: () => throw Exception());
        if (houseVipSnap.exists && houseVipSnap.value is Map) {
          final vip = Map<dynamic, dynamic>.from(houseVipSnap.value as Map);

          vipActive = vip['isVip'] == true;
          planLabel = _labelForVipPlan(vip['plan']?.toString());
          expiryLabel = vipActive
              ? activatedByPartnerLabel
              : inactiveVipExpiryLabel;
        }
        if (!vipActive) {
          final legacyProSnap = await _dbRef
              .child('houses/$_houseId/proUntil')
              .get()
              .timeout(const Duration(seconds: 3),
                  onTimeout: () => throw Exception());
          final proUntil = _toIntOrNull(legacyProSnap.value);
          if (proUntil != null &&
              proUntil > DateTime.now().millisecondsSinceEpoch) {
            vipActive = true;
            planLabel = 'PRO legacy / ImgBB';
            expiryLabel = _formatVipExpiry(proUntil);
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isVipActive = vipActive;
        _vipPlanLabel = planLabel;
        _vipExpiryLabel = expiryLabel;
      });
    }
  }

  String _labelForVipPlan(String? raw) {
    final normalized = VipProduct.canonicalPlanId(raw);
    switch (normalized) {
      case VipProduct.weekly:
        return context.tr('vip_1_week');
      case VipProduct.monthly:
        return context.tr('vip_1_month');
      case VipProduct.sixMonths:
        return context.tr('vip_6_month');
      case VipProduct.yearly:
        return context.tr('vip_1_year');
      case VipProduct.lifetime:
        return context.tr('vip_lifetime');
      case 'trial':
      case 'legacy_pro':
        return 'SoulLocket PRO';
      case '':
        return context.tr('home_tikhonbasi_5bd48d');
      default:
        return 'SoulLocket PRO';
    }

    // ignore: dead_code
    switch (raw) {
      case VipProduct.weekly:
        return context.tr('vip_1_week');
      case VipProduct.monthly:
        return context.tr('vip_1_month');
      case VipProduct.sixMonths:
      case VipProduct.sixMonthsAlt:
        return context.tr('vip_6_month');
      case VipProduct.yearly:
        return context.tr('vip_1_year');
      case VipProduct.lifetime:
      case VipProduct.lifetimeLegacy:
        return context.tr('vip_lifetime');
      default:
        return raw == null || raw.isEmpty
            ? context.tr('home_giminph_5edaf7')
            : raw;
    }
  }

  String _formatVipExpiry(dynamic raw) {
    final quickTs = _toIntOrNull(raw);
    if (quickTs == null) {
      return context.tr('vip_unlimited_or_nodata');
    }
    final quickDt = DateTime.fromMillisecondsSinceEpoch(quickTs);
    final quickNow = DateTime.now();
    final quickDiff = quickDt.difference(quickNow);

    if (quickDiff.isNegative) {
      final expiredDate =
          '${quickDt.day.toString().padLeft(2, '0')}/${quickDt.month.toString().padLeft(2, '0')}/${quickDt.year}';
      return 'ÄÃ£ háº¿t háº¡n vÃ o $expiredDate';
    }

    final daysLeft = quickDiff.inDays;
    final hoursLeft = quickDiff.inHours % 24;
    final minutesLeft = quickDiff.inMinutes % 60;

    if (daysLeft > 0) {
      return hoursLeft > 0
          ? 'CÃ²n láº¡i: $daysLeft ngÃ y $hoursLeft giá»'
          : 'CÃ²n láº¡i: $daysLeft ngÃ y';
    }
    if (hoursLeft > 0) {
      return minutesLeft > 0
          ? 'CÃ²n láº¡i: $hoursLeft giá» $minutesLeft phÃºt'
          : 'CÃ²n láº¡i: $hoursLeft giá»';
    }
    if (minutesLeft > 0) {
      return 'CÃ²n láº¡i: $minutesLeft phÃºt';
    }
    return context.tr('home_sphthnhmna_470d6c');

    // ignore: dead_code
    int? ts;
    if (raw is int) {
      ts = raw;
    } else if (raw is num) {
      ts = raw.toInt();
    } else if (raw != null) {
      ts = int.tryParse('$raw');
    }
    if (ts == null) return context.tr('vip_unlimited_or_nodata');
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final difference = dt.difference(now);

    final formattedDate =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    if (difference.isNegative) {
      return 'ÄÃ£ háº¿t háº¡n vÃ o: $formattedDate';
    } else {
      final daysLeft = difference.inDays;
      final hoursLeft = difference.inHours % 24;
      if (daysLeft > 0) {
        return 'CÃ²n láº¡i: $daysLeft ngÃ y (Háº¡n: $formattedDate)';
      } else if (hoursLeft > 0) {
        return 'CÃ²n láº¡i: $hoursLeft giá» (Háº¡n hÃ´m nay)';
      } else {
        return context.tr('home_sphthnhnhm_1ffe67');
      }
    }
  }

  Future<void> _restoreVipPurchases() async {
    final noVipFoundMsg = context.tr('home_thitbnycha_99bee3');
    final activeVipMsg = context.tr('vip_active_msg');
    final restoreSuccessMsg = context.tr('restore_vip_success');
    final noPackageMsg = context.tr('err_no_vip_package');
    final fallbackErrorMsg = context.tr('home_chathlmmit_9a10be');

    setState(() => _isRestoringVip = true);
    try {
      final wasVipActive = _isVipActive;
      final restored = await PurchaseService().restorePurchases();
      if (!restored) {
        _showToast(noVipFoundMsg, success: false);
      } else {
        bool vipDetected = false;
        for (var attempt = 0; attempt < 6; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 900));
          await _loadVipStatus();
          if (_isVipActive) {
            vipDetected = true;
            break;
          }
        }

        if (vipDetected) {
          if (!mounted) return;
          _showToast(
            wasVipActive
                ? activeVipMsg
                : restoreSuccessMsg,
            success: true,
          );
        } else {
          if (!mounted) return;
          _showToast(
            noPackageMsg,
            success: false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: fallbackErrorMsg,
        ).message,
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isRestoringVip = false);
    }
  }

  Future<void> _loadSecurityDetails() async {
    if (_houseId == null) return;
    try {
      try {
        await _auth.currentUser?.reload();
      } catch (_) {}
      final currentUser = _auth.currentUser;
      final security = await _authService.getHouseSecurityData(_houseId!);
      final houseSnap = await _dbRef
          .child('houses/$_houseId')
          .get()
          .timeout(const Duration(seconds: 3));
      final houseMap = houseSnap.exists && houseSnap.value is Map
          ? Map<dynamic, dynamic>.from(houseSnap.value as Map)
          : <dynamic, dynamic>{};
      final secMap = houseMap['security'] is Map
          ? Map<dynamic, dynamic>.from(houseMap['security'])
          : <dynamic, dynamic>{};

      final effectiveSecurity = {
        ...security ?? <String, dynamic>{},
        ...secMap,
      };
      final prefs = await SharedPreferences.getInstance();
      final currentRole =
          prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      final legacyHousePin = (effectiveSecurity['pin'] ?? '').toString().trim();
      final pinConfiguredRaw = effectiveSecurity['pinConfigured'];
      final hasHousePinConfigured = pinConfiguredRaw == true ||
          pinConfiguredRaw?.toString().toLowerCase() == 'true' ||
          legacyHousePin.isNotEmpty;
      final question = (effectiveSecurity['question'] ?? '').toString().trim();
      final legacySecondaryEmail = (effectiveSecurity['backupEmail'] ??
              effectiveSecurity['secondaryEmail'] ??
              '')
          .toString()
          .trim();
      var secondaryEmail = legacySecondaryEmail;
      if (currentUser != null) {
        try {
          final loginAliasSnap = await _dbRef
              .child('users/${currentUser.uid}/loginAliasEmail')
              .get()
              .timeout(const Duration(seconds: 3));
          final loginAliasEmail =
              loginAliasSnap.value?.toString().trim().toLowerCase() ?? '';
          if (loginAliasEmail.isNotEmpty) {
            secondaryEmail = loginAliasEmail;
          }
        } catch (_) {}
      }
      final recoveryAnswerHash =
          (effectiveSecurity['answerHash'] ?? effectiveSecurity['answer'] ?? '')
              .toString()
              .trim();
      final linkedGoogle = await _authService.isGoogleLinkedCurrentUser();
      final linkedPassword = await _authService.isPasswordLinkedCurrentUser();
      final settingsMap =
          Map<dynamic, dynamic>.from(houseMap['settings'] ?? {});
      final lockMap = Map<dynamic, dynamic>.from(secMap['lock'] ?? {});
      final hasLegacyRemoteLockArtifacts = lockMap.isNotEmpty ||
          settingsMap['appLocked'] != null ||
          settingsMap['customLock'] != null ||
          settingsMap['customLockSalt'] != null ||
          settingsMap['customLockLength'] != null ||
          settingsMap['appLockConfiguredAt'] != null ||
          settingsMap['appLockFaceId'] != null ||
          settingsMap['appLockScopes'] != null;

      if (currentUser != null) {
        try {
          await _authService.syncSecurityEmailForCurrentUser(
            user: currentUser,
            houseId: _houseId,
          );
        } catch (_) {}
      }
      if (legacyHousePin.isNotEmpty) {
        unawaited(
          _migrateLegacyHousePinToPrivate(
            houseId: _houseId!,
            rawPin: legacyHousePin,
          ).catchError((_) {}),
        );
      }
      if (hasLegacyRemoteLockArtifacts) {
        unawaited(
          _clearRemoteAppLockSyncArtifacts(houseId: _houseId)
              .catchError((_) {}),
        );
      }

      if (!mounted) return;
      setState(() {
        _securityEmail =
            (effectiveSecurity['email'] ?? currentUser?.email ?? '')
                .toString()
                .trim();
        _secondaryEmail = secondaryEmail;
        _securityQuestion = question;
        _housePin = hasHousePinConfigured ? 'â€¢â€¢â€¢â€¢' : '';
        _hasRecoveryAnswer = recoveryAnswerHash.isNotEmpty;
        _googleLinked = linkedGoogle;
        _passwordLinked = linkedPassword;
        _isMainEmailVerified = currentUser?.emailVerified ?? false;
        _activeRoleKey = currentRole;
        _selectedSecurityQuestion = _securityQuestions.contains(question)
            ? question
            : _selectedSecurityQuestion;
        _secondaryEmailCtrl.text = secondaryEmail;
        _recoveryQuestionCtrl.text =
            question.isNotEmpty ? question : _selectedSecurityQuestion;
        _housePinCtrl.clear();
      });
    } catch (_) {}
  }

  Future<void> _saveSecondaryEmail() async {
    if (_houseId == null) return;
    final logInReq = context.tr('home_bncnngnhpl_1c2e72');
    final enterEmailReq = context.tr('home_hynhpemail_7509cc');
    final invalidEmailErr = context.tr('home_emailphkhn_2e049e');
    final duplicateEmailErr = context.tr('home_emailphkhn_ca4585');

    if (!await _ensureCanModifySharedInfo()) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showToast(logInReq, success: false);
      return;
    }
    final value = _secondaryEmailCtrl.text.trim();
    if (value.isEmpty) {
      _showToast(enterEmailReq, success: false);
      return;
    }

    final normalized = value.toLowerCase();
    if (!_looksLikeSettingsEmail(normalized)) {
      _showToast(invalidEmailErr, success: false);
      return;
    }

    if (!_isSupportedSettingsEmail(normalized)) {
      _showToast(
          'Há»‡ thá»‘ng chá»‰ há»— trá»£ sá»­ dá»¥ng cÃ¡c loáº¡i email: ${_settingsSupportedEmailDomainsLabel()}',
          success: false);
      return;
    }

    final mainEmail =
        (_auth.currentUser?.email ?? _securityEmail).trim().toLowerCase();
    if (normalized == mainEmail) {
      _showToast(duplicateEmailErr, success: false);
      return;
    }

    try {
      await _authService.validateLoginEmailAliasForCurrentUser(normalized);
    } catch (e) {
      if (mounted) {
        _showToast(
          AppErrorMapper.resolve(
            e,
            fallbackMessage: context.tr('home_emailphnyc_cef5da'),
          ).message,
          success: false,
        );
      }
      return;
    }

    try {
      if (!mounted) return;
      final canContinue = await _securityFlowGuard.guard(
        context,
        action: SensitiveActionType.saveSecondaryEmail,
        houseId: _houseId,
      );
      if (!canContinue) {
        return;
      }
      if (!mounted) return;
      final success = await showSettingsEmailOtpDialog(
        context: context,
        title: context.tr('home_xcthcemail_292ed5'),
        email: normalized,
        sendCode: () => _authService.sendOtpEmail(normalized),
        verifyCode: (otpCode) =>
            _authService.validateEmailOTP(normalized, otpCode),
      );

      if (success) {
        try {
          await _dbRef.update({
            'users/${currentUser.uid}/loginAliasEmail': normalized,
            'users/${currentUser.uid}/loginAliasUpdatedAt':
                ServerValue.timestamp,
            'houses/$_houseId/security/secondaryEmail': normalized,
            'houses/$_houseId/security/backupEmail': normalized,
            'houses/$_houseId/security/updatedAt': ServerValue.timestamp,
          });
          if (mounted) {
            setState(() => _secondaryEmail = normalized);
            _showToast(context.tr('home_xcthcvluem_038a4a'), success: true);
          }
        } catch (e) {
          if (mounted) {
            _showToast(
              AppErrorMapper.resolve(
                e,
                fallbackMessage: context.tr('home_emailxcthc_875a96'),
              ).message,
              success: false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          AppErrorMapper.resolve(
            e,
            fallbackMessage: context.tr('home_chathgimxc_947d2b'),
          ).message,
          success: false,
        );
      }
    }
  }

//   Future<void> _saveSecondaryEmailLegacy() async {
//     if (_houseId == null) return;
//     final value = _secondaryEmailCtrl.text.trim();
//     await _dbRef.child('houses/$_houseId/security').update({
//       'secondaryEmail': value,
//       'updatedAt': ServerValue.timestamp,
//     });
//     if (mounted) {
//       setState(() => _secondaryEmail = value);
//       _showToast(context.tr('home_luemailph_7e403a'), success: true);
//     }
//   }

  Future<void> _saveHousePin() async {
    if (_houseId == null) return;
    if (!await _ensureCanModifySharedInfo()) return;
    if (!mounted) return;
    final pin = _housePinCtrl.text.trim();
    if (pin.length < 4 || !RegExp(r'\d').hasMatch(pin)) {
      _showToast(context.tr('err_house_pwd_format'), success: false);
      return;
    }
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.saveHousePin,
      houseId: _houseId,
    );
    if (!canContinue) {
      return;
    }

    await _dbRef.update({
      'house_private_security/$_houseId/pinHash':
          _authService.hashHousePin(pin),
      'house_private_security/$_houseId/updatedAt': ServerValue.timestamp,
      'houses/$_houseId/security/pin': null,
      'houses/$_houseId/security/pinConfigured': true,
      'houses/$_houseId/security/pinUpdatedAt': ServerValue.timestamp,
      'houses/$_houseId/security/updatedAt': ServerValue.timestamp,
    });
    if (mounted) {
      setState(() {
        _housePin = 'â€¢â€¢â€¢â€¢';
        _housePinCtrl.clear();
        _showHousePin = false;
      });
      _showToast(context.tr('saved_house_password'), success: true);
    }
  }

  Future<void> _saveRecoveryInfo() async {
    if (_houseId == null) return;
    if (!await _ensureCanModifySharedInfo()) return;
    if (!mounted) return;
    if (_securityQuestion.isNotEmpty && _hasRecoveryAnswer) {
      _showToast(
        context.tr('err_security_q_locked'),
        success: false,
      );
      return;
    }

    final question = _selectedSecurityQuestion.trim();
    final rawAnswer = _recoveryAnswerCtrl.text.trim();
    if (question.isEmpty || rawAnswer.isEmpty) {
      _showToast(context.tr('err_fill_security_q'), success: false);
      return;
    }
    if (_isBirthQuestion(question)) {
      final validationError = DateInputUtils.validationError(
        rawAnswer,
        firstYear: 1900,
        lastYear: DateTime.now().year,
        allowMissingYear: true,
      );
      if (validationError != null) {
        _showToast(validationError, success: false);
        return;
      }
    }
    final answer = _isBirthQuestion(question)
        ? DateInputUtils.normalizeForDisplay(
            rawAnswer,
            firstYear: 1900,
            lastYear: DateTime.now().year,
            allowMissingYear: true,
          )
        : rawAnswer;

    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.saveRecoveryInfo,
      houseId: _houseId,
    );
    if (!canContinue) {
      return;
    }

    final hashedAnswer = _authService.hashRecoveryAnswer(answer);
    await _dbRef.child('houses/$_houseId').update({
      'security/recovery/question': question,
      'security/recovery/answerHash': hashedAnswer,
      'security/recovery/configuredAt': ServerValue.timestamp,
      'recovery_q': null,
      'recovery_a': null,
    });
    if (mounted) {
      setState(() {
        _securityQuestion = question;
        _hasRecoveryAnswer = true;
        _recoveryQuestionCtrl.text = question;
        _recoveryAnswerCtrl.clear();
      });
      _showToast(context.tr('saved_security_q'), success: true);
    }
  }

//   Future<void> _saveRecoveryInfoLegacy() async {
//     if (_houseId == null) return;
//     final question = _recoveryQuestionCtrl.text.trim();
//     final answer = _recoveryAnswerCtrl.text.trim();
//     if (question.isEmpty || answer.isEmpty) {
//       _showToast(context.tr('err_fill_security_q'), success: false);
//       return;
//     }
//     final hashedAnswer = _authService.hashRecoveryAnswer(answer);
//     await _dbRef.child('houses/$_houseId/security').update({
//       'question': question,
//       'answer': hashedAnswer,
//       'updatedAt': ServerValue.timestamp,
//     });
//     await _dbRef.child('houses/$_houseId').update({
//       'recovery_q': question,
//       'recovery_a': hashedAnswer,
//     });
//     if (mounted) {
//       setState(() {
//         _securityQuestion = question;
//         _hasRecoveryAnswer = true;
//         _recoveryAnswerCtrl.clear();
//       });
//       _showToast(context.tr('home_cpnhtcuhib_120aaf'), success: true);
//     }
//   }

//   Future<void> _saveIdentity() async {
//     if (_houseId == null) return;
//     try {
//       await _dbRef.child('houses/$_houseId/settings').update({
//         'houseName': _houseNameCtrl.text.trim(),
//         'nameU1': _nameU1Ctrl.text.trim(),
//         'nameU2': _nameU2Ctrl.text.trim(),
//         'dobU1': _dobU1,
//         'dobU2': _dobU2,
//         'dayUnit': _loveUnitCtrl.text.trim(),
//       });
//       setState(() {
//         _houseName = _houseNameCtrl.text.trim();
//         _nameU1 = _nameU1Ctrl.text.trim();
//         _nameU2 = _nameU2Ctrl.text.trim();
//         _loveUnit = _loveUnitCtrl.text.trim();
//         _openPanel = null;
//       });
//       if (mounted) _showToast(context.tr('saved_info'), success: true);
//     } catch (e) {
//       if (mounted) _showToast('Lá»—i lÆ°u: $e', success: false);
//     }
//   }

  Future<void> _saveAdvancedSettingsV2({bool silent = false}) async {
    final houseId = _houseId?.trim();
    if (houseId != null &&
        houseId.isNotEmpty &&
        !await _ensureCanModifySharedInfo(showToast: !silent)) {
      return;
    }
    if (!silent) setState(() => _isSavingAdvanced = true);
    bool localSaved = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('il_notifications_enabled', _notificationsEnabled);
      await prefs.setBool('il_notif_anniversary', _notifAnniversary);
      await prefs.setBool('il_notif_post', _notifPost);
      await prefs.setBool('il_notif_chat', _notifChat);
      await prefs.setBool('il_notif_friend', _notifFriend);
      await prefs.setBool('il_notif_heart', _notifHeart);
      await prefs.setBool('il_smart_reminder_diary', _smartDiaryReminder);
      await prefs.setBool('il_smart_reminder_capsule', _smartCapsuleReminder);
      await prefs.setBool(
          'il_smart_reminder_love_note', _smartLoveNoteReminder);
      await prefs.setBool('il_touch_sound', _touchSound);
      await prefs.setBool('il_confetti_fx', _confettiFx);
      await prefs.setBool('il_show_weather', _showWeather);
      await prefs.setBool('il_show_status', _showStatus);
      await prefs.setString('il_auto_reply_text', _autoReplyCtrl.text.trim());
      localSaved = true;

      final ui = UiPrefs.notifier.value;
      await UiPrefs.saveState(ui.copyWith(
        touchSound: _touchSound,
        confettiFx: _confettiFx,
        musicAutoplay: _musicAutoplay,
      ));

      if (_houseId != null) {
        await _dbRef.child('houses/$_houseId/settings').update({
          'notificationsEnabled': _notificationsEnabled,
          'notifAnniversary': _notifAnniversary,
          'notifPost': _notifPost,
          'notifChat': _notifChat,
          'notifFriend': _notifFriend,
          'notifHeart': _notifHeart,
          'smartReminderDiary': _smartDiaryReminder,
          'smartReminderCapsule': _smartCapsuleReminder,
          'smartReminderLoveNote': _smartLoveNoteReminder,
          'touchSound': _touchSound,
          'confettiFx': _confettiFx,
          'showWeather': _showWeather,
          'showStatus': _showStatus,
          'homeShowTimer': _homeShowTimer,
          'autoReply': _autoReplyCtrl.text.trim(),
          'updatedAt': ServerValue.timestamp,
        });
      }

      if (!silent) {
        if (!mounted) return;
        _showToast(
          _houseId == null
              ? context.tr('saved_local_only')
              : context.tr('saved_all_success'),
          success: true,
        );
      }
    } catch (e) {
      if (!silent) {
        if (!mounted) return;
        _showToast(
          AppErrorMapper.resolve(
            e,
            fallbackMessage: localSaved
                ? context.tr('home_lutrnmynhn_5551e4')
                : context.tr('home_chathlucit_535775'),
          ).message,
          success: false,
        );
      }
    } finally {
      if (mounted) {
        if (!silent) setState(() => _isSavingAdvanced = false);
      }
    }
  }

  Future<void> _clearRemoteMusicSettings() async {
    // Background music is local-only now, so there is no remote music state to clear.
  }

  /*
  _SettingsIdentityDraft _buildIdentityDraft() {
    return _SettingsIdentityDraft(
      houseId: (_houseId ?? '').trim(),
      houseName: _houseNameCtrl.text.trim(),
      previousHouseName: _houseName,
      nameU1: _nameU1Ctrl.text.trim(),
      nameU2: _nameU2Ctrl.text.trim(),
      startDate: _loveDate,
      dobU1: _dobU1,
      dobU2: _dobU2,
      greetingQuote: _autoReplyCtrl.text.trim(),
      dayUnit: _loveUnitCtrl.text.trim().isEmpty
          ? context.tr('home_ngyyu_722b21')
          : _loveUnitCtrl.text.trim(),
      relationshipMode: _relationshipMode,
      homeShowHouseName: _homeShowHouseName,
      homeShowTimer: _homeShowTimer,
    );
  }

  String? _validateIdentityDraft(_SettingsIdentityDraft draft) {
    if (draft.nameU1.isEmpty) {
      return context.tr('err_enter_name1');
    }
    if (draft.isCouple && draft.nameU2.isEmpty) {
      return context.tr('err_enter_name2');
    }
    return null;
  }

  Future<bool> _canRenameHouseFromIdentityDraft(
    _SettingsIdentityDraft draft,
  ) async {
    if (!draft.isHouseNameChanged) {
      return true;
    }

    try {
      final snapshot = await _dbRef
          .child('houses/${draft.houseId}/settings/lastUsernameUpdate')
          .get();
      if (snapshot.exists && snapshot.value is int) {
        final lastUpdate = snapshot.value as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        const renameCooldownMs = 7 * 24 * 60 * 60 * 1000;
        if ((now - lastUpdate) < renameCooldownMs) {
          _showToast(
            context.tr('home_bnchcthitn_17fe89'),
            success: false,
          );
          return false;
        }
      }
    } catch (_) {}

    return true;
  }

  Future<void> _persistIdentityDraft(_SettingsIdentityDraft draft) async {
    await _houseSettingsService.updateIdentityBundle(
      houseId: draft.houseId,
      houseName: draft.houseName,
      nameU1: draft.nameU1,
      nameU2: draft.nameU2,
      startDate: draft.startDate,
      dobU1: draft.dobU1,
      dobU2: draft.dobU2,
      dayUnit: draft.dayUnit,
      greetingQuote: draft.greetingQuote,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('il_greeting_quote_text', draft.greetingQuote);
    await prefs.setString('il_love_unit_text', draft.dayUnit);

    await _dbRef.child('houses/${draft.houseId}/settings').update({
      'homeShowHouseName': draft.homeShowHouseName,
      'homeShowTimer': draft.homeShowTimer,
    });

    if (draft.isHouseNameChanged) {
      await _dbRef
          .child('houses/${draft.houseId}/settings/lastUsernameUpdate')
          .set(ServerValue.timestamp);
    }
  }

  Future<void> _applySavedIdentityDraft(_SettingsIdentityDraft draft) async {
    if (!mounted) return;
    setState(() {
      _houseName = draft.houseName;
      _nameU1 = draft.nameU1;
      _nameU2 = draft.nameU2;
      _loveUnit = draft.dayUnit;
      _openPanel = null;
    });
    await NotificationService().syncDailySleepReminder();
  }

  Future<void> _saveIdentityV2() async {
    if (_houseId == null) return;
    if (!await _ensureCanModifySharedInfo()) return;
    if (!mounted) return;

    final draft = _buildIdentityDraft();
    final validationError = _validateIdentityDraft(draft);
    if (validationError != null) {
      _showToast(validationError, success: false);
      return;
    }
    if (!await _canRenameHouseFromIdentityDraft(draft)) {
      return;
    }

    try {
      await _persistIdentityDraft(draft);
      await _applySavedIdentityDraft(draft);
      if (!mounted) return;
      _showToast(context.tr('saved_info'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast('${context.tr('err_save_info')}: $e', success: false);
    }
  }
  */
}
