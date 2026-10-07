import 'package:audioplayers/audioplayers.dart';

import '../../../views/utilities/memory_puzzle/memory_puzzle_audio.dart';

/// Bộ phát gọn dùng asset đã đóng trong APK/IPA. Không có request mạng.
class MemoryPuzzleSound implements MemoryPuzzleAudio {
  MemoryPuzzleSound()
    : _music = AudioPlayer(),
      _pickup = AudioPlayer(),
      _snap = AudioPlayer(),
      _complete = AudioPlayer();

  final AudioPlayer _music;
  final AudioPlayer _pickup;
  final AudioPlayer _snap;
  final AudioPlayer _complete;
  bool _musicEnabled = true;
  bool _effectsEnabled = true;
  bool _disposed = false;
  bool _musicReady = false;

  static const _musicAsset = 'audio/soul_block/original_v1/neon_memory.mp3';
  static const _pickupAsset = 'audio/soul_block/original_v1/lift.wav';
  static const _snapAsset = 'audio/soul_block/original_v1/place.wav';
  static const _completeAsset = 'audio/soul_block/original_v1/best_score.wav';

  bool get _active => !_disposed;

  @override
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    if (!_active) return;
    if (enabled) {
      await resume();
    } else {
      await _music.pause();
    }
  }

  @override
  Future<void> setEffectsEnabled(bool enabled) async =>
      _effectsEnabled = enabled;

  @override
  Future<void> resume() async {
    if (!_active || !_musicEnabled) return;
    try {
      if (!_musicReady) {
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setVolume(.24);
        await _music.setSource(AssetSource(_musicAsset));
        _musicReady = true;
      }
      if (_active && _musicEnabled && _music.state != PlayerState.playing) {
        await _music.resume();
      }
    } catch (_) {
      // Autoplay policy hoặc audio focus có thể tạm chặn; thao tác tiếp theo sẽ thử lại.
    }
  }

  @override
  Future<void> pause() async {
    if (_active) await _music.pause();
  }

  Future<void> _play(AudioPlayer player, String asset) async {
    if (!_active || !_effectsEnabled) return;
    try {
      await player.stop();
      if (!_active || !_effectsEnabled) return;
      await player.play(AssetSource(asset), volume: .72);
    } catch (_) {}
  }

  @override
  Future<void> playPickup() => _play(_pickup, _pickupAsset);

  @override
  Future<void> playSnap() => _play(_snap, _snapAsset);

  @override
  Future<void> playComplete() => _play(_complete, _completeAsset);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      _music.dispose(),
      _pickup.dispose(),
      _snap.dispose(),
      _complete.dispose(),
    ]);
  }
}
