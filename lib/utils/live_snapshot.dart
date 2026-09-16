import 'dart:async';
import 'package:flutter/widgets.dart';

/// Một subscription thuộc màn hình; tab mở muộn vẫn đọc được snapshot mới nhất.
class LiveSnapshot<T> extends ValueNotifier<AsyncSnapshot<T>> {
  LiveSnapshot() : super(AsyncSnapshot<T>.nothing());

  StreamSubscription<T>? _subscription;
  int _generation = 0;

  void bind(Stream<T> stream, {void Function(T data)? onFirstData}) {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    value = AsyncSnapshot<T>.waiting();
    var first = true;
    _subscription = stream.listen(
      (data) {
        if (generation != _generation) return;
        value = AsyncSnapshot<T>.withData(ConnectionState.active, data);
        if (first) {
          first = false;
          onFirstData?.call(data);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (generation != _generation) return;
        value = AsyncSnapshot<T>.withError(
          ConnectionState.active,
          error,
          stack,
        );
      },
      onDone: () {
        if (generation == _generation) {
          value = value.inState(ConnectionState.done);
        }
      },
    );
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
