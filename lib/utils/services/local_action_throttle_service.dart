enum LocalActionThrottleDecision {
  allow,
  cooldown,
  burstBlocked,
}

class LocalActionThrottleResult {
  const LocalActionThrottleResult({
    required this.decision,
    required this.attemptCount,
    required this.remainingCooldown,
    required this.window,
  });

  final LocalActionThrottleDecision decision;
  final int attemptCount;
  final Duration remainingCooldown;
  final Duration window;

  bool get isAllowed => decision == LocalActionThrottleDecision.allow;
  bool get isRapidRepeat => decision == LocalActionThrottleDecision.cooldown;
  bool get isSuspiciousBurst =>
      decision == LocalActionThrottleDecision.burstBlocked;
}

class LocalActionThrottleService {
  LocalActionThrottleService._internal();

  static final LocalActionThrottleService instance =
      LocalActionThrottleService._internal();

  final Map<String, _ActionThrottleState> _states =
      <String, _ActionThrottleState>{};

  LocalActionThrottleResult registerAttempt(
    String actionId, {
    Duration minInterval = const Duration(milliseconds: 800),
    int maxAttempts = 4,
    Duration burstWindow = const Duration(seconds: 4),
  }) {
    final normalizedId = actionId.trim().toLowerCase();
    final now = DateTime.now();
    final state =
        _states.putIfAbsent(normalizedId, () => _ActionThrottleState());

    state.attempts.removeWhere(
      (timestamp) => now.difference(timestamp) > burstWindow,
    );

    final lastAcceptedAt = state.lastAcceptedAt;
    final remainingCooldown = lastAcceptedAt == null
        ? Duration.zero
        : minInterval - now.difference(lastAcceptedAt);

    if (remainingCooldown > Duration.zero) {
      state.attempts.add(now);
      final decision = state.attempts.length >= maxAttempts
          ? LocalActionThrottleDecision.burstBlocked
          : LocalActionThrottleDecision.cooldown;
      return LocalActionThrottleResult(
        decision: decision,
        attemptCount: state.attempts.length,
        remainingCooldown: remainingCooldown,
        window: burstWindow,
      );
    }

    state.lastAcceptedAt = now;
    state.attempts.add(now);
    return LocalActionThrottleResult(
      decision: LocalActionThrottleDecision.allow,
      attemptCount: state.attempts.length,
      remainingCooldown: Duration.zero,
      window: burstWindow,
    );
  }

  void clear(String actionId) {
    _states.remove(actionId.trim().toLowerCase());
  }
}

class _ActionThrottleState {
  DateTime? lastAcceptedAt;
  final List<DateTime> attempts = <DateTime>[];
}
