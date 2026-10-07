import 'dart:async';

/// Đảm bảo chỉ có một thao tác mở màn hình chạy tại một thời điểm.
///
/// Các lần gọi đến trong lúc thao tác hiện tại còn chạy sẽ dùng chung
/// [Future] đang có, vì vậy một cú chạm bị lặp do máy lag không tạo thêm route.
class SingleOpenGate {
  Future<void>? _active;

  bool get isBusy => _active != null;

  Future<void> run(Future<void> Function() action) {
    final active = _active;
    if (active != null) return active;

    final completer = Completer<void>();
    _active = completer.future;
    unawaited(_execute(action, completer));
    return completer.future;
  }

  Future<void> _execute(
    Future<void> Function() action,
    Completer<void> completer,
  ) async {
    try {
      await action();
      if (!completer.isCompleted) completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    } finally {
      if (identical(_active, completer.future)) _active = null;
    }
  }
}
