import 'dart:async';

import 'package:flutter/foundation.dart';

/// Không bật lạc quan: đọc lại consent sau cả thành công lẫn rollback.
class SleepTrackingToggle extends ChangeNotifier {
  SleepTrackingToggle({
    required this.readEnabled,
    required this.start,
    required this.stop,
  });
  final Future<bool> Function() readEnabled;
  final Future<void> Function() start, stop;
  bool enabled = false, busy = false;
  Object? error;
  int _revision = 0;
  bool _disposed = false;

  void reset() {
    _revision++;
    enabled = false;
    error = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final revision = _revision;
    final value = await readEnabled().timeout(const Duration(seconds: 10));
    if (!_disposed && revision == _revision) {
      enabled = value;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (busy || _disposed) return;
    final revision = _revision;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await (value ? start() : stop());
    } catch (failure) {
      if (revision == _revision) error = failure;
    } finally {
      try {
        final actual = await readEnabled().timeout(const Duration(seconds: 10));
        if (revision == _revision) enabled = actual;
      } catch (failure) {
        if (revision == _revision) error ??= failure;
      }
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
