import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

enum FullscreenAdOutcome { rewarded, dismissed, unavailable }

/// Callback native quyết định đóng; Future show treo không giữ luồng chờ.
Future<FullscreenAdOutcome> presentRewardedAd({
  required RewardedAd ad,
  required bool Function() canShow,
  required VoidCallback onShown,
  required VoidCallback onClosed,
  Duration startTimeout = const Duration(seconds: 12),
}) => _presentFullscreenAd(
  onShown: onShown,
  onClosed: onClosed,
  startTimeout: startTimeout,
  rewardGrace: const Duration(milliseconds: 150),
  dispose: ad.dispose,
  installCallbacks: (shown, dismissed, failed) {
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) => shown(),
      onAdDismissedFullScreenContent: (_) => dismissed(),
      onAdFailedToShowFullScreenContent: (_, error) => failed(error),
    );
  },
  show: (earned, active) async {
    await ad.setImmersiveMode(true);
    if (!active() || !canShow()) throw StateError('ad_scope_changed');
    await ad.show(onUserEarnedReward: (_, _) => earned());
  },
);

Future<FullscreenAdOutcome> presentInterstitialAd({
  required InterstitialAd ad,
  required bool Function() canShow,
  required VoidCallback onShown,
  required VoidCallback onClosed,
  Duration startTimeout = const Duration(seconds: 12),
}) => _presentFullscreenAd(
  onShown: onShown,
  onClosed: onClosed,
  startTimeout: startTimeout,
  rewardGrace: Duration.zero,
  dispose: ad.dispose,
  installCallbacks: (shown, dismissed, failed) {
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) => shown(),
      onAdDismissedFullScreenContent: (_) => dismissed(),
      onAdFailedToShowFullScreenContent: (_, error) => failed(error),
    );
  },
  show: (_, active) async {
    if (!active() || !canShow()) throw StateError('ad_scope_changed');
    await ad.show();
  },
);

Future<FullscreenAdOutcome> _presentFullscreenAd({
  required VoidCallback onShown,
  required VoidCallback onClosed,
  required Duration startTimeout,
  required Duration rewardGrace,
  required Future<void> Function() dispose,
  required void Function(VoidCallback, VoidCallback, void Function(Object))
  installCallbacks,
  required Future<void> Function(VoidCallback, bool Function()) show,
}) {
  final result = Completer<FullscreenAdOutcome>();
  var shown = false;
  var closed = false;
  var earned = false;
  Timer? startTimer;

  void logFailure(Object error) => debugPrint(
    'AdMobService: fullscreen presentation failed: ${AppErrorMapper.resolve(error).message}',
  );

  Future<void> disposeSafely() async {
    try {
      await dispose();
    } catch (error) {
      logFailure(error);
    }
  }

  void finish(FullscreenAdOutcome outcome) {
    if (closed) return;
    closed = true;
    startTimer?.cancel();
    void complete() {
      if (!result.isCompleted) {
        result.complete(earned ? FullscreenAdOutcome.rewarded : outcome);
      }
    }

    // Adapter có thể báo earned ngay sau dismiss. Cleanup không chờ
    // ghi prefs hoặc Future dispose để mở khóa/hoàn tất cho caller.
    if (outcome == FullscreenAdOutcome.dismissed &&
        rewardGrace > Duration.zero) {
      Timer(rewardGrace, complete);
    } else {
      complete();
    }
    try {
      onClosed();
    } catch (error) {
      logFailure(error);
    }
    unawaited(disposeSafely());
  }

  installCallbacks(
    () {
      if (closed || shown) return;
      shown = true;
      startTimer?.cancel();
      onShown();
    },
    () => finish(FullscreenAdOutcome.dismissed),
    (error) {
      logFailure(error);
      finish(
        shown ? FullscreenAdOutcome.dismissed : FullscreenAdOutcome.unavailable,
      );
    },
  );
  // Không timeout một quảng cáo đã mở, kể cả video dài.
  startTimer = Timer(
    startTimeout,
    () => finish(FullscreenAdOutcome.unavailable),
  );
  Future<void> start() async {
    try {
      await show(() {
        if (!result.isCompleted) earned = true;
      }, () => !closed);
    } catch (error) {
      logFailure(error);
      if (!shown) finish(FullscreenAdOutcome.unavailable);
    }
  }

  unawaited(start());
  return result.future;
}

/// Timeout bắt đầu cùng request, kể cả Future native load không hoàn tất.
Future<T?> loadAdWithTimeout<T extends Ad>({
  required Future<void> Function(void Function(T), void Function(Object)) load,
  required bool Function() canAccept,
  Duration timeout = const Duration(seconds: 12),
}) {
  final result = Completer<T?>();
  T? accepted;
  late final Timer timer;
  void finish(T? ad) {
    if (result.isCompleted) return;
    timer.cancel();
    accepted = ad;
    result.complete(ad);
  }

  Future<void> disposeSafely(T ad) async {
    try {
      await ad.dispose();
    } catch (error) {
      debugPrint(
        'AdMobService: stale ad dispose failed: ${AppErrorMapper.resolve(error).message}',
      );
    }
  }

  timer = Timer(timeout, () => finish(null));
  Future<void> start() async {
    try {
      await load((ad) {
        if (result.isCompleted || !canAccept()) {
          if (!identical(accepted, ad)) unawaited(disposeSafely(ad));
          finish(null);
          return;
        }
        finish(ad);
      }, (_) => finish(null));
    } catch (error) {
      finish(null);
      debugPrint(
        'AdMobService: ad load failed: ${AppErrorMapper.resolve(error).message}',
      );
    }
  }

  unawaited(start());
  return result.future;
}
