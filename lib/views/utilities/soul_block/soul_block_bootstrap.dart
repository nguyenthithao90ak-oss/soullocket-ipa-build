// ignore_for_file: invalid_use_of_protected_member
part of '../soul_block_game.dart';

extension _SoulBlockBootstrap on _SoulBlockGameState {
  Future<void> _bootstrap() async {
    final splashDelay = Future<void>.delayed(
      const Duration(milliseconds: 1100),
    );
    try {
      final prefs = await _prefsFuture;
      final bestScore = prefs.getInt(_bestScoreKey) ?? 0;
      final soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      final vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
      final smoothGraphics = prefs.getBool(_smoothGraphicsKey) ?? true;
      final storedAutoTrayShuffleEnabled =
          prefs.getBool(_autoTrayShuffleEnabledKey) ?? false;
      final leaderboard = _decodeLeaderboard(prefs.getString(_leaderboardKey));
      final houseId = await _houseService.getCurrentHouseId();
      final isPremiumUser = await _readPremiumStatus();
      final memoryBurstGallery = _decodeMemoryBurstGallery(
        prefs.getString(_memoryBurstGalleryKeyFor(houseId)),
      );
      final _PreparedSoulRun? savedRun = _decodeSavedRun(
        prefs.getString(_savedRunKey),
      );
      final _PreparedSoulRun preparedMenuRun = savedRun ?? _prepareFreshRun();
      final autoTrayShuffleEnabled =
          storedAutoTrayShuffleEnabled && isPremiumUser;

      unawaited(_adMob.initialize());
      _adMob.preloadSoulGameRewardedAd();
      unawaited(_prepareBannerAd());

      await splashDelay;
      if (!mounted) {
        return;
      }

      setState(() {
        _bestScore = max(_bestScore, bestScore);
        _soundEnabled = soundEnabled;
        _vibrationEnabled = vibrationEnabled;
        _smoothGraphics = smoothGraphics;
        _leaderboard = leaderboard;
        _houseId = houseId;
        _memoryBurstGallery = memoryBurstGallery;
        _preparedMenuRun = savedRun == null ? preparedMenuRun : null;
        _autoTrayShuffleEnabled = autoTrayShuffleEnabled;
        _isPremiumUser = isPremiumUser;
        _loadError = null;
        _isOpeningGameplay = false;
        if (savedRun != null) {
          _board = _cloneBoard(savedRun.board);
          _tray = List<_SoulPieceOption>.from(savedRun.tray);
          _holdPiece = savedRun.holdPiece;
          if (savedRun.boardSize != null) {
            _boardSize = savedRun.boardSize!;
          }
          _recommendedMove = savedRun.recommendedMove;
          _currentSessionId = savedRun.sessionId;
          _isGameOver = false;
          _isBusy = false;
          _isReviving = false;
          _isRestarting = false;
          _view = _SoulGameView.gameplay;
        } else {
          _view = _SoulGameView.menu;
        }
      });

      if (storedAutoTrayShuffleEnabled && !autoTrayShuffleEnabled) {
        unawaited(_persistSetting(_autoTrayShuffleEnabledKey, false));
      }
      if (memoryBurstGallery.isNotEmpty) {
        unawaited(_warmMemoryBurstImages(memoryBurstGallery));
      }
      unawaited(_syncBgmWithSound());
      if (houseId != null && houseId.trim().isNotEmpty) {
        unawaited(_refreshMemoryBurstGallery(houseId));
      }
    } catch (_) {
      await splashDelay;
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = widget.loadErrorMessage;
        _isOpeningGameplay = false;
        _view = _SoulGameView.menu;
      });
    }
  }

  Future<void> _retryBootstrap() async {
    setState(() {
      _loadError = null;
      _isOpeningGameplay = false;
      _view = _SoulGameView.splash;
    });
    await _bootstrap();
  }

  void _onBannerPrivacyChanged() {
    if (!mounted) return;
    if (_bannerAd != null && !_adMob.isBannerUsable(_bannerAd!)) {
      _adMob.disposeBanner(_bannerAd);
      setState(() {
        _bannerAd = null;
      });
    }
    if (_adMob.canRequestAds) unawaited(_prepareBannerAd());
  }

  Future<void> _prepareBannerAd() async {
    if (_bannerAd != null || _loadingBanner || !mounted) return;
    _loadingBanner = true;
    final revision = _adMob.adRevision.value;
    try {
      final banner = await _adMob.createBannerAd(onAdLoaded: (_) {});
      if (!mounted) {
        _adMob.disposeBanner(banner);
        return;
      }
      setState(() {
        _bannerAd = banner;
      });
    } catch (error) {
      debugPrint('Soul Block banner load failed: $error');
    } finally {
      _loadingBanner = false;
      if (mounted &&
          _adMob.canRequestAds &&
          revision != _adMob.adRevision.value) {
        unawaited(_prepareBannerAd());
      }
    }
  }

  Future<void> _syncBannerAfterPremium() async {
    final isPro = await _refreshPremiumStatus();
    if (!mounted) {
      return;
    }

    if (isPro) {
      AdMobService().disposeBanner(_bannerAd);
      setState(() {
        _bannerAd = null;
      });
      return;
    }

    if (_bannerAd == null) {
      unawaited(_prepareBannerAd());
    }
  }

  Future<bool> _readPremiumStatus() async {
    try {
      return await _adMob.isProUser();
    } catch (error) {
      debugPrint(
        'Soul Block premium status check failed: ${AppErrorMapper.resolve(error).message}',
      );
      return false;
    }
  }

  Future<bool> _refreshPremiumStatus() async {
    final bool isPremiumUser = await _readPremiumStatus();
    final bool shouldDisableAutoShuffle =
        _autoTrayShuffleEnabled && !isPremiumUser;

    if (mounted) {
      if (_isPremiumUser != isPremiumUser || shouldDisableAutoShuffle) {
        setState(() {
          _isPremiumUser = isPremiumUser;
          if (shouldDisableAutoShuffle) {
            _autoTrayShuffleEnabled = false;
          }
        });
      }
    } else {
      _isPremiumUser = isPremiumUser;
      if (shouldDisableAutoShuffle) {
        _autoTrayShuffleEnabled = false;
      }
    }

    if (shouldDisableAutoShuffle) {
      await _persistSetting(_autoTrayShuffleEnabledKey, false);
    }
    _syncAutoTrayShuffleTimer();
    return isPremiumUser;
  }
}
