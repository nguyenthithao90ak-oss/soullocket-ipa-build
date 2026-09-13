part of '../../main_home_tab.dart';

extension _MainHomeMediaWarmupController on _MainHomeTabState {
  void _restoreWarmHomeCache() {
    final prefs = OfflineCacheService.getPrefsSync();
    if (prefs == null) {
      return;
    }

    final cachedHouseId = (prefs.getString('il_house_id') ?? '').trim();
    final cachedAuthUid = (prefs.getString('il_auth_uid') ?? '').trim();
    final currentUid = _auth.currentUser?.uid.trim() ?? '';
    if (currentUid.isEmpty || cachedAuthUid != currentUid) {
      return;
    }
    if (cachedHouseId.isEmpty) {
      return;
    }

    final cachedSettings = OfflineCacheService.loadCacheSync(
      _homeSettingsCacheKey(cachedHouseId),
    );
    if (cachedSettings is! Map) {
      return;
    }

    _houseId = cachedHouseId;
    _currentRole = prefs.getString('il_role') ?? _currentRole;
    _showStatus = prefs.getBool('il_show_status') ?? _showStatus;
    _showWeather = prefs.getBool('il_show_weather') ?? _showWeather;
    _houseSettings = Map<String, dynamic>.from(cachedSettings);
    _houseSettings!['relationshipMode'] =
        prefs.getString('il_rel_mode') ?? 'couple';
    _selectedHomeToolId = _normalizeHomeToolId(
      prefs.getString(_homeToolSelectionPrefKey(cachedHouseId)),
    );
    _isLoading = false;
  }

  ({int width, int height}) _resolveHomeBackgroundCacheSize() {
    return HomeImagePolicy.backgroundSize(context: context);
  }

  Future<void> _precacheHomeMedia({
    required String avatarUrl1,
    required String avatarUrl2,
    required String backgroundUrl,
  }) async {
    if (!mounted) return;

    final providers = <ImageProvider<Object>>[
      for (final asset in HomeImagePolicy.bundledAssets) AssetImage(asset),
    ];

    final safeAvatarUrl1 = avatarUrl1.trim();
    final safeAvatarUrl2 = avatarUrl2.trim();
    if (safeAvatarUrl1.isNotEmpty) {
      if (HomeStartupMediaCache.getFile(safeAvatarUrl1) == null) {
        providers.add(
          CachedNetworkImageProvider(
            safeAvatarUrl1,
            maxWidth: HomeImagePolicy.avatarPixels,
            maxHeight: HomeImagePolicy.avatarPixels,
          ),
        );
      }
    }
    if (safeAvatarUrl2.isNotEmpty) {
      if (HomeStartupMediaCache.getFile(safeAvatarUrl2) == null) {
        providers.add(
          CachedNetworkImageProvider(
            safeAvatarUrl2,
            maxWidth: HomeImagePolicy.avatarPixels,
            maxHeight: HomeImagePolicy.avatarPixels,
          ),
        );
      }
    }
    final safeBackgroundUrl = backgroundUrl.trim();
    if (safeBackgroundUrl.isNotEmpty) {
      final backgroundSize = _resolveHomeBackgroundCacheSize();
      providers.add(
        CachedNetworkImageProvider(
          safeBackgroundUrl,
          maxWidth: backgroundSize.width,
          maxHeight: backgroundSize.height,
        ),
      );
    }
    if (providers.isEmpty) return;

    final configuration = createLocalImageConfiguration(context);
    await Future.wait<void>(
      providers.map((provider) async {
        try {
          await HomeImagePolicy.warmImage(
            provider,
            configuration: configuration,
          );
        } catch (error) {
          debugPrint('[MainHome] Image warm-up failed: $error');
        }
      }),
      eagerError: false,
    );
  }

  Future<void> _releaseDeferredHomeMotion(int token) async {
    await Future<void>.delayed(_MainHomeTabState._kHomeMotionWarmupDelay);
    if (!mounted || token != _homeMediaWarmupToken || !_deferHeavyHomeMotion) {
      return;
    }
    setState(() => _deferHeavyHomeMotion = false);
  }

  void _warmHomeMedia({bool delayMotion = false, bool force = false}) {
    final avatarUrl1 = _houseSettings?['avtUser1']?.toString().trim() ?? '';
    final avatarUrl2 = _houseSettings?['avtUser2']?.toString().trim() ?? '';
    final backgroundUrl = UiPrefs.notifier.value.customBackgroundUrl.trim();
    final signature = '$avatarUrl1|$avatarUrl2|$backgroundUrl';

    // ⚡ Defer setState for _deferHeavyHomeMotion to post-frame so it doesn't
    //    block the ongoing swipe animation frame.
    if (delayMotion && !_deferHeavyHomeMotion) {
      _deferHeavyHomeMotion = true;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {});
        });
      }
    }
    final shouldReleaseDeferredMotion = delayMotion || _deferHeavyHomeMotion;

    final token = ++_homeMediaWarmupToken;
    // Hiệu ứng chỉ chờ nhịp ổn định đầu màn, không chờ mạng tải xong ảnh.
    if (shouldReleaseDeferredMotion) {
      unawaited(_releaseDeferredHomeMotion(token));
    }
    if (!force && signature == _lastHomeMediaWarmupSignature) {
      return;
    }

    _lastHomeMediaWarmupSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || token != _homeMediaWarmupToken) return;
      await _precacheHomeMedia(
        avatarUrl1: avatarUrl1,
        avatarUrl2: avatarUrl2,
        backgroundUrl: backgroundUrl,
      );
    });
  }
}
