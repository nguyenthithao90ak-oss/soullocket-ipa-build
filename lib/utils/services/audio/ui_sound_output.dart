import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'ui_sound_waves.dart';

abstract interface class UiSoundOutput {
  Future<void> unlock();
  Future<void> prepare(Uint8List wave);
  Future<void> play(double volume);
  Future<void> stop();
  Future<void> dispose();
}

/// Player được tạo lười; không lấy audio focus hoặc hạ âm lượng media khác.
class UiSoundPlayerOutput implements UiSoundOutput {
  AudioPlayer? _player;
  bool _configured = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  Future<void> unlock() async {
    if (!kIsWeb || _disposed) return;
    final generation = _generation;
    await prepare(UiSoundWaves.silence());
    if (!_disposed && generation == _generation) await play(0);
  }

  @override
  Future<void> prepare(Uint8List wave) async {
    if (_disposed) return;
    final generation = _generation;
    final player = _player ??= AudioPlayer();
    if (!_configured) {
      if (!kIsWeb) {
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
      }
      if (_disposed || generation != _generation) return;
      await player.setReleaseMode(ReleaseMode.stop);
      if (_disposed || generation != _generation) return;
      _configured = true;
    }
    await player.setSource(BytesSource(wave, mimeType: 'audio/wav'));
  }

  @override
  Future<void> play(double volume) async {
    final player = _player;
    if (_disposed || player == null) return;
    final generation = _generation;
    await player.setVolume(volume);
    if (_disposed || generation != _generation) return;
    await player.resume();
    if (!_disposed && generation != _generation) await player.stop();
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}
