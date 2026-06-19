part of '../../main_home_tab.dart';

extension _MainHomeWidgetSyncController on _MainHomeTabState {
  static const int _widgetDiaryFetchLimit = 24;

  String _zodiacAndAgeForRoleImpl(String role) {
    if (_houseSettings == null) return '✨ 0';
    final dob =
        _houseSettings!['dob${role == 'user1' ? 'U1' : 'U2'}']?.toString() ??
            '';
    if (dob.isEmpty) return '✨ 0';

    try {
      final zInfo = ZodiacUtils.getZodiac(dob);
      final emoji = (zInfo?['emoji'] ?? '✨').toString().trim();

      final ageText = ZodiacUtils.getAgeInDays(dob);
      final match = RegExp(r'\d+').firstMatch(ageText ?? '');
      final ageDays = int.tryParse(match?.group(0) ?? '') ?? 0;

      if (ageDays <= 0) {
        return '$emoji 0';
      }

      final compactAge = ageDays >= 365 ? (ageDays / 365).floor() : ageDays;
      return '$emoji $compactAge';
    } catch (_) {}
    return '✨ 0';
  }

  int _widgetMemoryOrderValueImpl(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  List<({int order, String url})> _widgetDiaryImageEntriesFromRawImpl(
    dynamic raw,
  ) {
    if (raw is! Map) return const <({int order, String url})>[];

    final items = <({int order, String url})>[];
    raw.forEach((_, value) {
      if (value is! Map) return;
      final map = value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
      final imageUrl = (map['url'] ?? map['imageUrl'] ?? map['thumbUrl'] ?? '')
          .toString()
          .trim();
      if (imageUrl.isEmpty) return;
      final order = _widgetMemoryOrderValueImpl(
        map['ts'] ?? map['date'] ?? map['updatedAt'],
      );
      items.add((order: order, url: imageUrl));
    });

    return items;
  }

  Future<List<String>> _loadWidgetDiaryImageUrlsImpl(String houseId) async {
    try {
      final memoriesFuture = _dbRef
          .child('houses/$houseId/memories')
          .limitToLast(_widgetDiaryFetchLimit)
          .get()
          .timeout(const Duration(seconds: 4));
      final diaryFuture = _dbRef
          .child('houses/$houseId/diary')
          .limitToLast(_widgetDiaryFetchLimit)
          .get()
          .timeout(const Duration(seconds: 4));

      final snapshots = await Future.wait([memoriesFuture, diaryFuture]);
      final merged = <({int order, String url})>[
        ..._widgetDiaryImageEntriesFromRawImpl(snapshots[0].value),
        ..._widgetDiaryImageEntriesFromRawImpl(snapshots[1].value),
      ]..sort((a, b) => b.order.compareTo(a.order));

      final seen = <String>{};
      return merged
          .map((item) => item.url)
          .where((url) => seen.add(url))
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<
      ({
        String bgTheme,
        String widgetStyleKey,
        bool showDiaryOnWidget,
        bool heartAnimated,
        String heartStyleKey,
        String heartColorKey,
        String diaryLayoutKey,
        String seasonModeKey,
      })> _loadWidgetAppearancePrefsImpl(String houseId) async {
    final prefs = await SharedPreferences.getInstance();
    final accountKey = _widgetAccountKeyImpl(houseId);
    final showDiaryOnWidget =
        prefs.getBool('il_widget_show_diary_$accountKey') ??
            prefs.getBool('il_widget_show_diary') ??
            true;
    // Always pin heart style (no random animation) on app entry.
    const heartAnimated = false;
    final displayMode = WidgetService.normalizeWidgetDisplayMode(
      showDiaryOnWidget: showDiaryOnWidget,
      heartAnimated: heartAnimated,
    );
    return (
      bgTheme: prefs.getString('il_widget_theme_$accountKey') ??
          prefs.getString('il_widget_theme') ??
          'pink',
      widgetStyleKey: WidgetService.normalizeWidgetStyleKey(
        prefs.getString('il_widget_style_$accountKey') ??
            prefs.getString('il_widget_style') ??
            WidgetService.defaultWidgetStyleKey,
      ),
      showDiaryOnWidget: displayMode.showDiaryOnWidget,
      heartAnimated: displayMode.heartAnimated,
      // Force fixed default heart style (5th item) on app entry.
      heartStyleKey: '❤️',
      heartColorKey: prefs.getString('il_widget_heart_color_$accountKey') ??
          prefs.getString('il_widget_heart_color') ??
          'rose',
      diaryLayoutKey: prefs.getString('il_widget_diary_layout_$accountKey') ??
          prefs.getString('il_widget_diary_layout') ??
          'single',
      seasonModeKey: prefs.getString('il_widget_season_mode_$accountKey') ??
          prefs.getString('il_widget_season_mode') ??
          'auto',
    );
  }

  String _widgetAccountKeyImpl(String houseId) {
    final currentUid = _auth.currentUser?.uid ?? 'guest';
    return '${currentUid}_$houseId';
  }

  void _scheduleLoveWidgetSyncImpl(
    Map<String, dynamic> settings, {
    required bool includeDiaryMedia,
  }) {
    if (kIsWeb || !_isTabActive) return;
    final nextSettings = Map<String, dynamic>.from(settings);
    final nextSettingsKey = _buildWidgetSettingsSyncKeyImpl(nextSettings);
    final pendingSettings = _pendingWidgetSettings;
    if (pendingSettings != null) {
      final pendingSettingsKey =
          _buildWidgetSettingsSyncKeyImpl(pendingSettings);
      final alreadyCoversRequest = pendingSettingsKey == nextSettingsKey &&
          (_pendingWidgetSyncIncludeDiaryMedia || !includeDiaryMedia);
      if (alreadyCoversRequest) {
        return;
      }
    }

    _pendingWidgetSettings = nextSettings;
    _pendingWidgetSyncIncludeDiaryMedia =
        _pendingWidgetSyncIncludeDiaryMedia || includeDiaryMedia;
    if (_widgetSyncInFlight) {
      return;
    }
    _loveWidgetSyncDebounce?.cancel();
    _loveWidgetSyncDebounce =
        Timer(const Duration(milliseconds: 700), () async {
      if (_widgetSyncInFlight) {
        return;
      }
      final pendingSettings = _pendingWidgetSettings;
      final shouldIncludeDiaryMedia = _pendingWidgetSyncIncludeDiaryMedia;
      _pendingWidgetSettings = null;
      _pendingWidgetSyncIncludeDiaryMedia = false;
      if (pendingSettings == null || !mounted || !_isTabActive) return;
      _widgetSyncInFlight = true;
      try {
        await _syncLoveWidgetImpl(
          pendingSettings,
          includeDiaryMedia: shouldIncludeDiaryMedia,
        );
      } finally {
        _widgetSyncInFlight = false;
        final nextQueuedSettings = _pendingWidgetSettings;
        final nextQueuedIncludeDiaryMedia = _pendingWidgetSyncIncludeDiaryMedia;
        if (nextQueuedSettings != null && mounted && _isTabActive) {
          _pendingWidgetSettings = null;
          _pendingWidgetSyncIncludeDiaryMedia = false;
          _scheduleLoveWidgetSyncImpl(
            nextQueuedSettings,
            includeDiaryMedia: nextQueuedIncludeDiaryMedia,
          );
        }
      }
    });
  }

  Future<void> _syncLoveWidgetImpl(
    Map<String, dynamic> settings, {
    bool includeDiaryMedia = false,
  }) async {
    if (kIsWeb || !_isTabActive) return;
    try {
      final houseId = _houseId?.trim();
      if (houseId == null || houseId.isEmpty) return;
      final accountKey = _widgetAccountKeyImpl(houseId);
      if (_lastLoveWidgetAccountKey != accountKey) {
        _lastLoveWidgetAccountKey = accountKey;
        _lastLoveWidgetSignature = '';
        _cachedWidgetDiaryImageUrls = const <String>[];
      }
      final startDate = settings['startDate']?.toString();
      final days = _calculateLoveDays(startDate);
      final unit = _resolveCountdownLabel(
        settings['dayUnit']?.toString(),
        L10nService().translate('home_ngy_b9474a'),
      );
      final nameU1 = (settings['nameU1']?.toString().trim().isNotEmpty ?? false)
          ? settings['nameU1'].toString().trim()
          : L10nService().translate('home_bn_1fd75b');
      final nameU2 = (settings['nameU2']?.toString().trim().isNotEmpty ?? false)
          ? settings['nameU2'].toString().trim()
          : L10nService().translate('home_ngiy_5bab37');

      final configuredBucket = AppConfig.firebaseStorageBucket.trim();
      final defaultMaleAvatarUrl = configuredBucket.isEmpty
          ? ''
          : 'https://firebasestorage.googleapis.com/v0/b/$configuredBucket/o/default_avatars%2Fmale.jpg?alt=media';
      final defaultFemaleAvatarUrl = configuredBucket.isEmpty
          ? ''
          : 'https://firebasestorage.googleapis.com/v0/b/$configuredBucket/o/default_avatars%2Ffemale.jpg?alt=media';
      final avt1 = settings['avtUser1']?.toString().isNotEmpty == true
          ? settings['avtUser1'].toString()
          : defaultMaleAvatarUrl;
      final avt2 = settings['avtUser2']?.toString().isNotEmpty == true
          ? settings['avtUser2'].toString()
          : defaultFemaleAvatarUrl;

      final status1Text = _presenceStatusText('user1');
      final status2Text = _presenceStatusText('user2');
      final isOnline1 =
          _isPresenceDataOnlineForRole('user1', _presenceForRole('user1'));
      final isOnline2 =
          _isPresenceDataOnlineForRole('user2', _presenceForRole('user2'));

      final w1 = _widgetLocationTextForRole('user1');
      final w2 = _widgetLocationTextForRole('user2');

      final stars1Text = _zodiacAndAgeForRoleImpl('user1');
      final stars2Text = _zodiacAndAgeForRoleImpl('user2');
      final appearance = await _loadWidgetAppearancePrefsImpl(houseId);
      if (!_isTabActive) return;
      final dobU1 = settings['dobU1']?.toString() ?? '';
      final dobU2 = settings['dobU2']?.toString() ?? '';
      final diaryImageUrls = appearance.showDiaryOnWidget
          ? (includeDiaryMedia || _cachedWidgetDiaryImageUrls.isEmpty
              ? await _loadWidgetDiaryImageUrlsImpl(houseId)
              : _cachedWidgetDiaryImageUrls)
          : const <String>[];
      if (!_isTabActive) return;
      if (appearance.showDiaryOnWidget) {
        _cachedWidgetDiaryImageUrls = diaryImageUrls;
      } else {
        _cachedWidgetDiaryImageUrls = const <String>[];
      }

      final widgetSignature = jsonEncode({
        'houseId': houseId,
        'accountKey': accountKey,
        'name1': nameU1,
        'name2': nameU2,
        'daysText': '$days $unit',
        'avatar1': avt1,
        'avatar2': avt2,
        'status1': status1Text,
        'status2': status2Text,
        'isOnline1': isOnline1,
        'isOnline2': isOnline2,
        'weather1': w1,
        'weather2': w2,
        'stars1': stars1Text,
        'stars2': stars2Text,
        'bgTheme': appearance.bgTheme,
        'widgetStyleKey': appearance.widgetStyleKey,
        'showDiaryOnWidget': appearance.showDiaryOnWidget,
        'heartAnimated': appearance.heartAnimated,
        'heartStyleKey': appearance.heartStyleKey,
        'heartColorKey': appearance.heartColorKey,
        'diaryLayoutKey': appearance.diaryLayoutKey,
        'seasonModeKey': appearance.seasonModeKey,
        'diaryImageUrls': diaryImageUrls,
      });
      if (_lastLoveWidgetSignature == widgetSignature) {
        return;
      }

      await WidgetService.updateWidget(
        name1: nameU1,
        name2: nameU2,
        daysText: '$days $unit',
        avatarUrl1: avt1,
        avatarUrl2: avt2,
        status1: status1Text,
        status2: status2Text,
        isOnline1: isOnline1,
        isOnline2: isOnline2,
        weather1: w1,
        weather2: w2,
        stars1: stars1Text,
        stars2: stars2Text,
        bgTheme: appearance.bgTheme,
        widgetStyleKey: appearance.widgetStyleKey,
        showDiaryOnWidget: appearance.showDiaryOnWidget,
        heartAnimated: appearance.heartAnimated,
        heartStyleKey: appearance.heartStyleKey,
        heartColorKey: appearance.heartColorKey,
        diaryLayoutKey: appearance.diaryLayoutKey,
        seasonModeKey: appearance.seasonModeKey,
        loveDate: startDate ?? '',
        birthday1: dobU1,
        birthday2: dobU2,
        diaryImageUrls: diaryImageUrls,
      );
      await WidgetService.syncCycleWidgetData(houseId: houseId);
      await WidgetService.syncCalendarWidgetData(houseId: houseId);
      _lastLoveWidgetSignature = widgetSignature;
    } catch (_) {}
  }
}
