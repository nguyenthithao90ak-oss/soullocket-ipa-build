import 'dart:async';

enum SettingsPanelOpenResult { opened, busy, cancelled, loadFailed, timedOut }

class SettingsPanelNavigation {
  SettingsPanelNavigation({this.waitTimeout = const Duration(seconds: 30)});

  final Duration waitTimeout;
  Completer<bool> _bootstrap = Completer<bool>();
  int _generation = 0;
  bool _busy = false;
  bool _disposed = false;

  int get generation => _generation;
  bool get isBusy => _busy;

  void restartBootstrap() {
    if (_disposed) return;
    if (!_bootstrap.isCompleted) _bootstrap.complete(false);
    _generation++;
    _bootstrap = Completer<bool>();
  }

  void completeBootstrap({required bool succeeded}) {
    if (!_disposed && !_bootstrap.isCompleted) {
      _bootstrap.complete(succeeded);
    }
  }

  Future<SettingsPanelOpenResult> open({
    required bool Function() isStillValid,
    required Future<void> Function() onOpen,
    void Function(bool waiting)? onWaitingChanged,
  }) async {
    if (_disposed || !isStillValid()) return SettingsPanelOpenResult.cancelled;
    if (_busy) return SettingsPanelOpenResult.busy;
    _busy = true;
    final requestGeneration = _generation;
    bool valid() =>
        !_disposed && requestGeneration == _generation && isStillValid();
    var waiting = !_bootstrap.isCompleted;
    if (waiting) onWaitingChanged?.call(true);
    try {
      bool ready;
      try {
        ready = await _bootstrap.future.timeout(waitTimeout);
      } on TimeoutException {
        return valid()
            ? SettingsPanelOpenResult.timedOut
            : SettingsPanelOpenResult.cancelled;
      }
      if (!valid()) return SettingsPanelOpenResult.cancelled;
      if (!ready) return SettingsPanelOpenResult.loadFailed;
      if (waiting) {
        waiting = false;
        onWaitingChanged?.call(false);
      }
      if (!valid()) return SettingsPanelOpenResult.cancelled;
      await onOpen();
      return SettingsPanelOpenResult.opened;
    } finally {
      _busy = false;
      if (waiting) onWaitingChanged?.call(false);
    }
  }

  void dispose() {
    _disposed = true;
    if (!_bootstrap.isCompleted) _bootstrap.complete(false);
  }
}
