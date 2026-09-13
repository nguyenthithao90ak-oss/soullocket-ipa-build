import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

/// Một lượt trình bày App Open; không chờ ghi thống kê để trả kết quả SDK.
/// Khóa native do bên gọi giữ từ onShown đến onClosed, kể cả ad dài.
Future<bool> presentAppOpenAd({
  required AppOpenAd ad,
  required VoidCallback onShown,
  required VoidCallback onClosed,
  required Future<void> Function() recordShown,
  Duration showTimeout = const Duration(seconds: 12),
}) {
  final result = Completer<bool>();
  var shown = false;
  var closed = false;
  Timer? startTimer;

  void logFailure(String action, Object error) {
    debugPrint(
      'AdMobService: App Open $action failed: '
      '${AppErrorMapper.resolve(error).message}',
    );
  }

  Future<void> disposeAd() async {
    try {
      await ad.dispose();
    } catch (error) {
      logFailure('dispose', error);
    }
  }

  void finish(bool didShow) {
    if (closed) return;
    closed = true;
    startTimer?.cancel();
    // Hoàn tất trước cleanup để lỗi phụ không giữ Future/khóa đang chờ.
    if (!result.isCompleted) result.complete(didShow);
    onClosed();
    unawaited(disposeAd());
  }

  Future<void> recordSafely() async {
    try {
      await recordShown().timeout(const Duration(seconds: 5));
    } catch (error) {
      logFailure('record shown', error);
    }
  }

  ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
    onAdShowedFullScreenContent: (_) {
      if (closed || shown) return;
      shown = true;
      startTimer?.cancel();
      onShown();
      if (!result.isCompleted) result.complete(true);
      unawaited(recordSafely());
    },
    onAdDismissedFullScreenContent: (_) => finish(shown),
    onAdFailedToShowFullScreenContent: (_, error) {
      logFailure('show callback', error);
      finish(false);
    },
  );

  // Chỉ timeout khi SDK chưa báo đã mở. Không tháo khóa giữa một ad dài.
  startTimer = Timer(showTimeout, () => finish(false));
  Future<void> showSafely() async {
    try {
      await ad.show();
    } catch (error) {
      logFailure('show', error);
      // SDK đã báo đang hiện thì chờ callback đóng, không mở ad chồng lên.
      if (!shown) finish(false);
    }
  }

  // SDK có thể không hoàn tất Future show(); vẫn nhận callback/timeout.
  unawaited(showSafely());
  return result.future;
}
