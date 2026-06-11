part of '../settings_tab.dart';

// ignore_for_file: dead_code, unused_element

extension _SettingsTabIdentityHelpers on _SettingsTabState {
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
        final updateFuture = _dbRef.child('houses/$_houseId/settings').update({
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
        if (!silent) {
          await updateFuture;
        }
      }

      if (oldSavedUrl.isNotEmpty && oldSavedUrl != customBackgroundUrl) {
        try {
          _storageService.deleteImageByUrl(oldSavedUrl);
        } catch (_) {}
      }

      if (!mounted) return;
      if (!silent) {
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
          _showSettingsSyncBanner = false;
        });

        UiPrefs.notifier.value = UiPrefs.notifier.value.copyWith();
        _showToast(
          successMsg,
          success: true,
        );
      } else {
        // Silent save: update drafts without triggering rebuild
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
        _showSettingsSyncBanner = false;
      }
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
}
