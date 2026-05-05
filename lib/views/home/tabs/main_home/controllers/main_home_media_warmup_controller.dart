// ignore_for_file: invalid_use_of_protected_member, unused_element

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

    final cachedSettings =
        OfflineCacheService.loadCacheSync(_homeSettingsCacheKey(cachedHouseId));
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
    final mediaQuery = MediaQuery.maybeOf(context);
    final view = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first
        : null;
    final devicePixelRatio =
        mediaQuery?.devicePixelRatio ?? view?.devicePixelRatio ?? 1.0;
    final logicalWidth = mediaQuery?.size.width ??
        ((view?.physicalSize.width ?? 0) / devicePixelRatio);
    final logicalHeight = mediaQuery?.size.height ??
        ((view?.physicalSize.height ?? 0) / devicePixelRatio);
    final qualityScale = devicePixelRatio >= 2.5 ? 0.75 : 0.85;
    final cacheWidth =
        (logicalWidth * devicePixelRatio * qualityScale).round().clamp(600, 1280);
    final cacheHeight = (logicalHeight * devicePixelRatio * qualityScale)
        .round()
        .clamp(960, 1920);
    return (width: cacheWidth, height: cacheHeight);
  }

  Future<void> _precacheHomeMedia({
    required String avatarUrl1,
    required String avatarUrl2,
    required String backgroundUrl,
  }) async {
    if (!mounted) return;

    final providers = <ImageProvider<Object>>[];
    final safeAvatarUrl1 = avatarUrl1.trim();
    final safeAvatarUrl2 = avatarUrl2.trim();
    if (safeAvatarUrl1.isNotEmpty) {
      if (HomeStartupMediaCache.getFile(safeAvatarUrl1) == null) {
        providers.add(
          CachedNetworkImageProvider(
            safeAvatarUrl1,
            maxWidth: 300,
            maxHeight: 300,
          ),
        );
      }
    }
    if (safeAvatarUrl2.isNotEmpty) {
      if (HomeStartupMediaCache.getFile(safeAvatarUrl2) == null) {
        providers.add(
          CachedNetworkImageProvider(
            safeAvatarUrl2,
            maxWidth: 300,
            maxHeight: 300,
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

    await Future.wait<void>(
      providers.map(
        (provider) async {
          try {
            await precacheImage(provider, context);
          } catch (_) {}
        },
      ),
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

  void _warmHomeMedia({
    bool delayMotion = false,
    bool force = false,
  }) {
    final avatarUrl1 = _houseSettings?['avtUser1']?.toString().trim() ?? '';
    final avatarUrl2 = _houseSettings?['avtUser2']?.toString().trim() ?? '';
    final backgroundUrl = UiPrefs.notifier.value.customBackgroundUrl.trim();
    final signature = '$avatarUrl1|$avatarUrl2|$backgroundUrl';

    if (delayMotion && !_deferHeavyHomeMotion) {
      if (mounted) {
        setState(() => _deferHeavyHomeMotion = true);
      } else {
        _deferHeavyHomeMotion = true;
      }
    }
    final shouldReleaseDeferredMotion = delayMotion || _deferHeavyHomeMotion;

    final token = ++_homeMediaWarmupToken;
    if (!force && signature == _lastHomeMediaWarmupSignature) {
      if (shouldReleaseDeferredMotion) {
        unawaited(_releaseDeferredHomeMotion(token));
      }
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
      if (shouldReleaseDeferredMotion) {
        unawaited(_releaseDeferredHomeMotion(token));
      }
    });
  }
}
