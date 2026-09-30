import 'dart:async';
import 'dart:collection';

class PrivateMediaLoadQueue {
  PrivateMediaLoadQueue({this.maxConcurrent = 6}) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  final Queue<Future<void> Function()> _pending = Queue();
  int _active = 0;

  Future<T?> run<T>({
    required bool Function() isCurrent,
    required Future<T> Function() action,
  }) {
    final result = Completer<T?>();
    _pending.add(() async {
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
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      final next = _pending.removeFirst();
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
