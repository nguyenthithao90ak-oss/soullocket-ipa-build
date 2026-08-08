part of '../../diary_tab.dart';

extension DiaryTabAdSection on _DiaryTabState {
  void _loadBottomBanner() async {
    if (kIsWeb) return;
    final adMob = AdMobService();
    await adMob.initialize();
    if (!mounted) return;

    if (await adMob.isProUser()) {
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
      if (!mounted) return;
      setState(() => _isBottomBannerReady = false);
      return;
    }

    _bottomBannerAd?.dispose();
    _bottomBannerAd = null;
    if (!mounted) return;
    final banner = await adMob.createBannerAd(
      onAdLoaded: (_) {
        if (!mounted) return;
        setState(() => _isBottomBannerReady = true);
      },
    );
    if (!mounted) {
      banner?.dispose();
      return;
    }
    _bottomBannerAd = banner;
  }

  Widget _buildBottomAdBanner(BannerAd bannerAd) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        AdMobService().showInterstitialAd();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: SLColors.bgElevated.withValues(alpha: 0.72),
              borderRadius: SLRadius.lgAll,
              border: Border.all(
                color: SLColors.bgElevated.withValues(alpha: 0.45),
              ),
              boxShadow: SLShadow.subtle,
            ),
            child: ClipRRect(
              borderRadius: SLRadius.mdAll,
              child: SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startDiaryActiveTimer() {
    _diaryActiveTimer?.cancel();
    _diaryActiveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted || !_isTabActive) {
        timer.cancel();
        return;
      }
      _activeSecondsInDiary += 10;
      if (_activeSecondsInDiary >= 15 * 60) {
        _showForcedDiaryAd();
      }
    });
  }

  void _stopDiaryActiveTimer() {
    _diaryActiveTimer?.cancel();
    _diaryActiveTimer = null;
  }

  Future<void> _showForcedDiaryAd() async {
    final adMob = AdMobService();
    if (await adMob.isProUser()) return;

    final hasRecent =
        adMob.hasRecentFullscreenAd(cooldown: const Duration(minutes: 15));
    if (hasRecent) {
      return;
    }

    debugPrint(
        'DiaryTab: Showing forced interstitial ad after 15 minutes of activity.');
    final shown = await adMob.showInterstitialAd();
    if (shown) {
      _activeSecondsInDiary = 0;
    }
  }

  void _preloadMemoryShareRewardedAd() {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 20), () async {
        final adMob = AdMobService();
        await adMob.initialize();
        adMob.preloadRewardedAd();
      }),
    );
  }
}
