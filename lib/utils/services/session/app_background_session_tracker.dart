import 'package:shared_preferences/shared_preferences.dart';

class AppBackgroundSessionTracker {
  const AppBackgroundSessionTracker({
    this.lastBackgroundAtPrefsKey = 'il_app_last_background_at_ms_v1',
  });

  final String lastBackgroundAtPrefsKey;

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

    await clearPersistedBackgroundTimestamp(prefs);
    // Thời gian ở nền chỉ phục vụ kiểm tra khóa app, không được xóa màn/tab
    // đang làm hoặc bỏ qua bước xác thực khi người dùng quay lại.
    return AppBackgroundResumePolicyResult(
      resolvedPausedAt: keepInMemoryTimestamp ? pausedAt : null,
    );
  }
}

class AppBackgroundResumePolicyResult {
  const AppBackgroundResumePolicyResult({
    this.resolvedPausedAt,
  });

  final DateTime? resolvedPausedAt;
}
