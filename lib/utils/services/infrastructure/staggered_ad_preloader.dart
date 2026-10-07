import 'dart:async';

import 'package:flutter/widgets.dart';

class StaggeredAdPreloader with WidgetsBindingObserver {
  StaggeredAdPreloader({
    required this.canPreload,
    required this.onError,
    this.spacing = const Duration(seconds: 3),
  });

  final bool Function() canPreload;
  final void Function(Object, StackTrace) onError;
  final Duration spacing;
  final List<Future<void> Function()> _tasks = [];
  Timer? _timer;
  bool _observing = false;
  bool _running = false;
  int _generation = 0;

  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void start(Iterable<Future<void> Function()> tasks) {
    cancel();
    _tasks.addAll(tasks);
    if (_tasks.isEmpty) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    _schedule();
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _tasks.clear();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    _timer = null;
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    if (_running || _timer != null || !_foreground) return;
    if (_tasks.isEmpty) {
      cancel();
      return;
    }
    _timer = Timer(spacing, () {
      _timer = null;
      if (!_foreground) return;
      if (!canPreload()) {
        _schedule();
        return;
      }
      final task = _tasks.removeAt(0);
      _running = true;
      unawaited(_run(task, _generation));
    });
  }

  Future<void> _run(Future<void> Function() task, int generation) async {
    try {
      await task();
    } catch (error, stackTrace) {
      if (generation == _generation) onError(error, stackTrace);
    } finally {
      _running = false;
      _schedule();
    }
  }
}
