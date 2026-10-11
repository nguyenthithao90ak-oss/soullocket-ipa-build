import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

enum FullscreenAdOutcome { rewarded, dismissed, unavailable }

/// Các caller cùng chờ một lượt tải, kể cả phần kiểm tra quyền trước native load.
class SharedAdLoad {
  Completer<void>? _pending;

  bool get isRunning => _pending != null;

  Future<void> run(Future<void> Function() load) {
    final running = _pending;
    if (running != null) return running.future;
    final pending = Completer<void>();
    _pending = pending;
    Future<void> start() async {
      try {
        await load();
        if (!pending.isCompleted) pending.complete();
      } catch (error, stack) {
        if (!pending.isCompleted) pending.completeError(error, stack);
      } finally {
        // Callback cũ không được tháo khóa của lượt mới sau cancel.
        if (identical(_pending, pending)) _pending = null;
      }
    }

    unawaited(start());
    return pending.future;
  }

  void cancel() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}

/// Chỉ ghi mã/domain SDK; message native và ResponseInfo có thể chứa dữ liệu riêng.
String adFailureDetails(Object error) {
  final message = AppErrorMapper.resolve(error).message;
  if (error is! AdError) return message;
  final domain =
      RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,79}$').hasMatch(error.domain)
      ? error.domain
      : 'unknown';
  return '$message (code=${error.code}, domain=$domain)';
}

/// Chỉ giới hạn việc chuẩn bị; quảng cáo đã xuất hiện chờ callback đóng.
/// Sau mỗi await, caller kiểm tra [canContinue] để bỏ kết quả đến muộn.
Future<T?> prepareAdWithTimeout<T>({
  required Future<T?> Function(bool Function() canContinue) prepare,
  required bool Function() isCurrent,
  Duration timeout = const Duration(seconds: 10),
}) async {
  var active = true;
  bool canContinue() => active && isCurrent();
  final settled = Completer<T?>();
  Timer? timeoutTimer;

  Future<void> settlePreparation() async {
    try {
      // Future.sync còn bắt cả lỗi xảy ra khi callback tạo Future, còn await
      // bên dưới giữ handler cho tới khi Future gốc kết thúc, kể cả sau timeout.
      final result = await Future<T?>.sync(() => prepare(canContinue));
      if (settled.isCompleted) return;
      settled.complete(canContinue() ? result : null);
    } catch (error) {
      // Khi timeout đã trả fallback, vẫn phải tiêu thụ lỗi của Future gốc để
      // callback native chậm không biến thành uncaught async error.
      if (!settled.isCompleted) {
        debugPrint(
          'AdMobService: ad preparation failed: ${adFailureDetails(error)}',
        );
        settled.complete(null);
      } else {
        debugPrint(
          'AdMobService: late ad preparation failure ignored: ${adFailureDetails(error)}',
        );
      }
    }
  }

  try {
    if (!canContinue()) return null;
    timeoutTimer = Timer(timeout, () {
      active = false;
      if (!settled.isCompleted) settled.complete(null);
    });
    unawaited(settlePreparation());
    return await settled.future;
  } finally {
    active = false;
    timeoutTimer?.cancel();
  }
}

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
    'AdMobService: fullscreen presentation failed: ${adFailureDetails(error)}',
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
      unawaited(disposeSafely());
    }

    // Giữ instance trong khoảng chờ earned sau dismiss: dispose sớm
    // xóa dispatcher SDK và làm mất callback. Không chờ Future dispose
    // để hoàn tất hoặc mở khóa cho caller.
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
  String debugLabel = 'ad',
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
        'AdMobService: stale ad dispose failed: ${adFailureDetails(error)}',
      );
    }
  }

  timer = Timer(timeout, () {
    debugPrint(
      'AdMobService: $debugLabel load timed out after ${timeout.inMilliseconds}ms.',
    );
    finish(null);
  });
  Future<void> start() async {
    try {
      await load(
        (ad) {
          if (result.isCompleted || !canAccept()) {
            if (!identical(accepted, ad)) unawaited(disposeSafely(ad));
            finish(null);
            return;
          }
          finish(ad);
        },
        (error) {
          // Ghi mã/domain SDK để phân biệt no-fill với lỗi adapter hoặc request.
          debugPrint(
            'AdMobService: $debugLabel load callback failed: '
            '${adFailureDetails(error)}',
          );
          finish(null);
        },
      );
    } catch (error) {
      finish(null);
      debugPrint(
        'AdMobService: $debugLabel load failed: ${adFailureDetails(error)}',
      );
    }
  }

  unawaited(start());
  return result.future;
}
