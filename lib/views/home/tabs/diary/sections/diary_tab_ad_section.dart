part of '../../diary_tab.dart';

extension DiaryTabAdSection on _DiaryTabState {
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
    // Chỉ nạp sẵn, không chen ngang lúc người dùng đọc/viết nhật ký.
    _activeSecondsInDiary = 0;
    await AdMobService().loadInterstitialAd();
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
