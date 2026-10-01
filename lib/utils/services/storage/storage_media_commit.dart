abstract final class StorageMediaCommit {
  static Future<void> commit({
    required bool Function() scopeIsCurrent,
    required Future<void> Function() persist,
    required Future<void> Function() clearPending,
  }) async {
    if (!scopeIsCurrent()) throw StateError('Media upload scope changed');
    await persist();
    if (!scopeIsCurrent()) throw StateError('Media upload scope changed');
    try {
      await clearPending();
    } catch (_) {}
  }
}
