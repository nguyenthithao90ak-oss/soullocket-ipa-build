import 'dart:async';

/// Service native có thể chạy trước khi isolate đăng ký nguồn màn hình.
/// Chỉ xác nhận khi nhận phản hồi đúng UID/House/role đang yêu cầu.
Future<void> startSleepService({
  required String scope,
  required Stream<Map<String, dynamic>?> readiness,
  required Future<bool> Function() isRunning,
  required Future<bool> Function() start,
  required void Function() requestStatus,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final ready = Completer<void>();
  void failed() {
    if (!ready.isCompleted)
      ready.completeError(StateError('sleep_start_failed'));
  }

  final subscription = readiness.listen(
    (message) {
      if (ready.isCompleted || message?['scope'] != scope) return;
      if (message?['ready'] == false) {
        failed();
      } else if (message?['ready'] == true) {
        ready.complete();
      }
    },
    onError: (Object _) => failed(),
    onDone: failed,
  );
  final confirmed = ready.future.timeout(
    timeout,
    onTimeout: () => throw StateError('sleep_start_failed'),
  );
  // Native khởi chạy và stream lỗi có thể kết thúc trước await bên dưới.
  unawaited(confirmed.catchError((Object _) {}));
  try {
    if (!await isRunning() && !await start())
      throw StateError('sleep_start_failed');
    requestStatus();
    await confirmed;
  } finally {
    await subscription.cancel();
  }
}
