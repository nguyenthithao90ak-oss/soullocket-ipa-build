import 'package:flutter/foundation.dart';

class StorageWebPickerGuard {
  const StorageWebPickerGuard._();

  static DateTime? _guardUntil;

  static bool get shouldIgnoreLifecyclePulse {
    if (!kIsWeb) return false;
    final until = _guardUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void arm([
    Duration duration = const Duration(seconds: 2),
  ]) {
    _guardUntil = DateTime.now().add(duration);
  }
}
