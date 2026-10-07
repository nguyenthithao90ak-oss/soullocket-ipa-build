/// Âm thanh là dependency riêng để màn chơi có thể kiểm thử không cần plugin.
abstract interface class MemoryPuzzleAudio {
  Future<void> setMusicEnabled(bool enabled);
  Future<void> setEffectsEnabled(bool enabled);
  Future<void> resume();
  Future<void> pause();
  Future<void> playPickup();
  Future<void> playSnap();
  Future<void> playComplete();
  Future<void> dispose();
}
