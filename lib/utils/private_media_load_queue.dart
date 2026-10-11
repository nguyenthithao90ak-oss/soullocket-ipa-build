import 'dart:async';
import 'dart:collection';

class PrivateMediaLoadQueue {
  PrivateMediaLoadQueue({this.maxConcurrent = 6}) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  // Lượt ưu tiên (ảnh đang mở toàn màn hình) luôn được lấy trước lượt thường.
  final Queue<Future<void> Function()> _priorityPending = Queue();
  final Queue<Future<void> Function()> _pending = Queue();
  int _active = 0;

  /// [priority] cho lượt này chạy trước mọi lượt thường đang chờ (ví dụ ảnh đang mở không
  /// phải xếp sau hàng trăm ô ở lưới album); các lượt ưu tiên vẫn theo thứ tự đến trước.
  Future<T?> run<T>({
    required bool Function() isCurrent,
    required Future<T> Function() action,
    bool priority = false,
  }) {
    final result = Completer<T?>();
    (priority ? _priorityPending : _pending).add(() async {
      try {
        if (!isCurrent()) {
          result.complete(null);
          return;
        }
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    _drain();
    return result.future;
  }

  void _drain() {
    while (_active < maxConcurrent &&
        (_priorityPending.isNotEmpty || _pending.isNotEmpty)) {
      final next = _priorityPending.isNotEmpty
          ? _priorityPending.removeFirst()
          : _pending.removeFirst();
      _active++;
      unawaited(
        next().whenComplete(() {
          _active--;
          _drain();
        }),
      );
    }
  }
}
