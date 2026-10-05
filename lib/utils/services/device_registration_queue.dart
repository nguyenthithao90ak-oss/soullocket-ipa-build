class DeviceRegistrationQueue {
  DeviceRegistrationQueue({
    this.cooldown = const Duration(minutes: 5),
    this.failureCooldown = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration cooldown;
  final Duration failureCooldown;
  final DateTime Function() _clock;
  final Map<String, Future<void>> _pending = {};
  String? _lastScope;
  DateTime? _lastSuccess;
  String? _failedScope;
  DateTime? _lastFailure;
  Object? _lastError;

  Future<void> run(String scope, Future<void> Function() register) {
    final pending = _pending[scope];
    if (pending != null) return pending;
    final lastFailure = _lastFailure;
    final failureAge = lastFailure == null
        ? null
        : _clock().difference(lastFailure);
    if (_failedScope == scope &&
        failureAge != null &&
        !failureAge.isNegative &&
        failureAge < failureCooldown &&
        _lastError != null) {
      return Future<void>.error(_lastError!);
    }
    final lastSuccess = _lastSuccess;
    final age = lastSuccess == null ? null : _clock().difference(lastSuccess);
    if (_lastScope == scope &&
        age != null &&
        !age.isNegative &&
        age < cooldown) {
      return Future<void>.value();
    }

    late final Future<void> future;
    future = Future<void>.sync(register)
        .then<void>(
          (_) {
            _lastScope = scope;
            _lastSuccess = _clock();
            if (_failedScope == scope) {
              _failedScope = null;
              _lastFailure = null;
              _lastError = null;
            }
          },
          onError: (Object error, StackTrace stack) {
            _failedScope = scope;
            _lastFailure = _clock();
            _lastError = error;
            Error.throwWithStackTrace(error, stack);
          },
        )
        .whenComplete(() {
          if (identical(_pending[scope], future)) _pending.remove(scope);
        });
    _pending[scope] = future;
    return future;
  }
}
