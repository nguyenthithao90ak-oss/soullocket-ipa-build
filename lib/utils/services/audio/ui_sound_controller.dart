import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ui_sound_output.dart';
import 'ui_sound_waves.dart';

export 'ui_sound_output.dart' show UiSoundOutput;
export 'ui_sound_waves.dart' show UiSoundCue, UiSoundWaves;

/// Điều phối hiệu ứng ngắn; bỏ qua yêu cầu khi bận, không xếp hàng phát muộn.
class UiSoundController {
  UiSoundController({
    UiSoundOutput? output,
    Duration Function()? clock,
    Future<void> Function(Duration)? wait,
  }) : _output = output ?? UiSoundPlayerOutput(),
       _clock = clock ?? (Stopwatch()..start()).elapsedDuration,
       _wait = wait ?? Future<void>.delayed;

  static const volume = 0.18;
  static const cooldown = Duration(milliseconds: 350);
  final UiSoundOutput _output;
  final Duration Function() _clock;
  final Future<void> Function(Duration) _wait;
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  ValueListenable<bool> get busy => _busy;
  bool _enabled = false;
  bool _unlocked = false;
  bool _unlocking = false;
  bool _disposed = false;
  int _generation = 0;
  int _pendingStops = 0;
  int _audibleStops = 0;
  bool _playing = false;
  Duration? _lastSound;

  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) stop();
  }

  /// Chỉ gọi đồng bộ từ pointer/key gesture, không mở khóa từ timer hoặc mạng.
  void unlockFromGesture() {
    if (_disposed ||
        !_enabled ||
        _unlocked ||
        _unlocking ||
        _busy.value ||
        _pendingStops > 0) {
      return;
    }
    _unlocking = true;
    unawaited(_unlock(_generation));
  }

  Future<void> _unlock(int generation) async {
    try {
      await _output.unlock();
      if (_isCurrent(generation)) {
        _unlocked = true;
      } else if (!_disposed) {
        await _stopPlayback();
      }
    } catch (_) {
      // Autoplay/thiết bị từ chối thì bỏ qua, chỉ thử lại ở thao tác sau.
    } finally {
      _unlocking = false;
    }
  }

  Future<void> play(UiSoundCue cue) async {
    if (_disposed ||
        !_enabled ||
        !_unlocked ||
        _unlocking ||
        _busy.value ||
        _pendingStops > 0) {
      return;
    }
    final now = _clock();
    if (_lastSound != null && now - _lastSound! < cooldown) return;
    _lastSound = now;
    final generation = _generation;
    _playing = true;
    _syncBusy();
    try {
      await _output.prepare(UiSoundWaves.waveFor(cue));
      if (!_isCurrent(generation)) return;
      await _output.play(volume);
      if (!_isCurrent(generation)) {
        if (!_disposed) await _stopPlayback();
        return;
      }
      // resume hoàn tất trước khi WAV kết thúc; giữ quyền phát hết đuôi âm.
      await _wait(UiSoundWaves.durationFor(cue));
    } catch (_) {
      _unlocked = false;
      if (!_disposed) await _stopPlayback();
    } finally {
      _playing = false;
      _syncBusy();
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && _enabled && generation == _generation;

  void stop() {
    if (_disposed) return;
    _generation++;
    unawaited(_stopPlayback());
  }

  Future<void> _stopPlayback() async {
    // Rào chắn này ngăn stop chậm của lần cũ tắt nhầm âm của lần mới.
    _pendingStops++;
    final audible = _busy.value;
    if (audible) _audibleStops++;
    try {
      await _quiet(_output.stop);
    } finally {
      _pendingStops--;
      if (audible) _audibleStops--;
      _syncBusy();
    }
  }

  void _syncBusy() {
    if (!_disposed) _busy.value = _playing || _audibleStops > 0;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _enabled = false;
    _busy.dispose();
    unawaited(_quiet(_output.dispose));
  }

  static Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Hiệu ứng trang trí không được làm thất bại thao tác của người dùng.
    }
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
