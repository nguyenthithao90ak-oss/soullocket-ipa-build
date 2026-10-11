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

  /// Phiên bản có giá trị trả về dùng cho `Navigator.push`.
  /// Lần gọi trùng chỉ đợi thao tác hiện tại kết thúc rồi nhận `null`, không
  /// tạo thêm route hoặc xếp một route mới vào hàng chờ.
  Future<T?> runValue<T>(Future<T?> Function() action) {
    final active = _active;
    if (active != null) return active.then<T?>((_) => null);

    final gateCompleter = Completer<void>();
    final resultCompleter = Completer<T?>();
    _active = gateCompleter.future;
    unawaited(_executeValue(action, gateCompleter, resultCompleter));
    return resultCompleter.future;
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

  Future<void> _executeValue<T>(
    Future<T?> Function() action,
    Completer<void> gateCompleter,
    Completer<T?> resultCompleter,
  ) async {
    try {
      final result = await action();
      if (!resultCompleter.isCompleted) resultCompleter.complete(result);
      if (!gateCompleter.isCompleted) gateCompleter.complete();
    } catch (error, stackTrace) {
      if (!resultCompleter.isCompleted) {
        resultCompleter.completeError(error, stackTrace);
      }
      // Gate chỉ báo hiệu đã nhả khóa; lỗi được trả qua resultCompleter.
      if (!gateCompleter.isCompleted) gateCompleter.complete();
    } finally {
      if (identical(_active, gateCompleter.future)) _active = null;
    }
  }
}
