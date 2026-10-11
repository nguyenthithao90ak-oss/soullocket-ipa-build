import 'dart:async';

class SignedOutCleanupCoordinator {
  SignedOutCleanupCoordinator({
    required List<Future<void> Function()> actions,
    this.timeout = const Duration(seconds: 4),
  }) : _actions = List.unmodifiable(actions);

  final List<Future<void> Function()> _actions;
  final Duration timeout;
  Future<void>? _pending;

  Future<void>? get pending => _pending;

  Future<void> run() {
    var pending = _pending;
    if (pending == null) {
      final operation = Future.wait<void>(_actions.map(_runAction));
      _pending = pending = operation;
      final monitor = operation.then<void>(
        (_) => _clearCompleted(operation),
        onError: (Object error, StackTrace stackTrace) {
          _clearCompleted(operation);
        },
      );
      unawaited(monitor.catchError((Object _) {}));
    }
    return _observeErrors(pending.timeout(timeout));
  }

  Future<void> waitForPending() =>
      _observeErrors((_pending ?? Future<void>.value()).timeout(timeout));

  Future<void> _observeErrors(Future<void> future) {
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {},
      ),
    );
    return future;
  }

  Future<void> _runAction(Future<void> Function() action) {
    final result = Completer<void>();
    unawaited(
      result.future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {},
      ),
    );
    Future<void>.microtask(() async {
      try {
        await action();
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  void _clearCompleted(Future<void> operation) {
    if (identical(_pending, operation)) _pending = null;
  }
}
