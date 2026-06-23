class AppLifecyclePresenceGuard {
  const AppLifecyclePresenceGuard._();

  static const Duration operationWindow = Duration(minutes: 3);
  static const Duration settleWindow = Duration(seconds: 10);

  static DateTime? _guardUntil;

  static bool get shouldKeepPresenceOnline {
    final until = _guardUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void arm([
    Duration duration = operationWindow,
  ]) {
    _guardUntil = DateTime.now().add(duration);
  }

  static void settle() {
    arm(settleWindow);
  }

  static Future<T> guard<T>(Future<T> Function() action) async {
    arm();
    try {
      return await action();
    } finally {
      settle();
    }
  }
}
