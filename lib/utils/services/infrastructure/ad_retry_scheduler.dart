import 'dart:async';

/// Thử lại có giới hạn khi màn còn hoạt động, tránh gọi mạng liên tục lúc no fill.
class AdRetryScheduler {
  AdRetryScheduler({required this.canRetry, required this.retry});

  final bool Function() canRetry;
  final void Function() retry;
  static const _delays = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  Timer? _timer;
  int _attempts = 0;

  void schedule() {
    if (_timer != null || _attempts >= _delays.length || !canRetry()) return;
    _timer = Timer(_delays[_attempts], () {
      _timer = null;
      if (!canRetry()) return;
      _attempts++;
      retry();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    cancel();
    _attempts = 0;
  }
}
