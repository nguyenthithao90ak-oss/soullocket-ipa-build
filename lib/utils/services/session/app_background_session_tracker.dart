import 'package:shared_preferences/shared_preferences.dart';

class AppBackgroundSessionTracker {
  const AppBackgroundSessionTracker({
    this.lastBackgroundAtPrefsKey = 'il_app_last_background_at_ms_v1',
    this.lastHomeTabPrefsKey = 'il_home_last_tab_v1',
    this.resumeResetThreshold = const Duration(minutes: 5),
  });

  final String lastBackgroundAtPrefsKey;
  final String lastHomeTabPrefsKey;
  final Duration resumeResetThreshold;

  Future<void> persistBackgroundTimestamp(
    SharedPreferences prefs,
    DateTime timestamp,
  ) async {
    await prefs.setInt(
      lastBackgroundAtPrefsKey,
      timestamp.millisecondsSinceEpoch,
    );
  }

  Future<DateTime?> resolveLastBackgroundAt(
    SharedPreferences prefs, {
    required DateTime? inMemoryPausedAt,
  }) async {
    final persistedAtMs = prefs.getInt(lastBackgroundAtPrefsKey);
    final persistedAt = persistedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(persistedAtMs);

    if (inMemoryPausedAt == null) {
      return persistedAt;
    }

    if (persistedAt != null && persistedAt.isAfter(inMemoryPausedAt)) {
      return persistedAt;
    }
    return inMemoryPausedAt;
  }

  Future<void> clearPersistedBackgroundTimestamp(
      SharedPreferences prefs) async {
    await prefs.remove(lastBackgroundAtPrefsKey);
  }

  Future<void> resetSavedHomeState(SharedPreferences prefs) async {
    await prefs.remove(lastHomeTabPrefsKey);
  }

  Future<AppBackgroundResumePolicyResult> applyResumePolicy(
    SharedPreferences prefs, {
    required DateTime? inMemoryPausedAt,
    required bool keepInMemoryTimestamp,
  }) async {
    final pausedAt = await resolveLastBackgroundAt(
      prefs,
      inMemoryPausedAt: inMemoryPausedAt,
    );
    if (pausedAt == null) {
      return const AppBackgroundResumePolicyResult();
    }

    final shouldResetToHome =
        DateTime.now().difference(pausedAt) >= resumeResetThreshold;
    await clearPersistedBackgroundTimestamp(prefs);

    if (shouldResetToHome) {
      await resetSavedHomeState(prefs);
      return const AppBackgroundResumePolicyResult(
        shouldResetToHome: true,
        resolvedPausedAt: null,
      );
    }

    return AppBackgroundResumePolicyResult(
      shouldResetToHome: false,
      resolvedPausedAt: keepInMemoryTimestamp ? pausedAt : null,
    );
  }
}

class AppBackgroundResumePolicyResult {
  const AppBackgroundResumePolicyResult({
    this.shouldResetToHome = false,
    this.resolvedPausedAt,
  });

  final bool shouldResetToHome;
  final DateTime? resolvedPausedAt;
}
