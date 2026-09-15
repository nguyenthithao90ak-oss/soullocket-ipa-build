import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'home_companion_motion.dart';

enum HomeCompanionSound { greeting, hop, sweep, success }

/// Đầu ra tách riêng để kiểm thử việc hủy âm thanh mà không mở thiết bị audio.
abstract interface class HomeCompanionAudioOutput {
  Future<void> unlock();
  Future<void> prepare(Uint8List wave);
  Future<void> play(double volume);
  Future<void> stop();
  Future<void> dispose();
}

/// Hiệu ứng cục bộ của Home; không phát nhạc nền, không gọi mạng hay ghi dữ liệu.
class HomeCompanionAudio {
  HomeCompanionAudio({
    HomeCompanionAudioOutput? output,
    Duration Function()? clock,
  }) : _output = output ?? _PlayerOutput(),
       _clock = clock ?? (Stopwatch()..start()).elapsedDuration;

  static const volume = 0.16;
  static const cooldown = Duration(milliseconds: 1800);
  final HomeCompanionAudioOutput _output;
  final Duration Function() _clock;
  bool _enabled = false;
  bool _paused = false;
  bool _unlocked = false;
  bool _busy = false;
  int _pendingStops = 0;
  bool _disposed = false;
  int _generation = 0;
  Duration? _lastSound;
  HomeCompanionPhase? _phase;
  int _greeting = 0;
  Duration? _pendingGreeting;

  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) stop();
  }

  /// Tạm ngừng tiếng khi giữ/kéo tay, nhưng vẫn nhận lần unlock im lặng
  /// ngay trong PointerUp dù parent hạ cờ swipe chậm hơn một frame.
  void setPaused(bool paused) {
    if (_disposed || _paused == paused) return;
    _paused = paused;
    if (paused) {
      _pendingGreeting = null;
      if (_unlocked || _busy) stop();
    }
  }

  /// Chỉ gọi trực tiếp từ một lần chạm/click hợp lệ của người dùng.
  void unlock() {
    if (_disposed || !_enabled || _unlocked || _busy || _pendingStops > 0) {
      return;
    }
    _busy = true;
    final generation = _generation;
    unawaited(_unlock(generation));
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
      // Trình duyệt có thể từ chối autoplay: giữ im lặng, thử ở lần chạm sau.
    } finally {
      _busy = false;
    }
  }

  void update(
    HomeCompanionPhase phase, {
    int? greeting,
    bool greetingActive = true,
  }) {
    if (_disposed) return;
    final phaseChanged = _phase != phase;
    _phase = phase;
    if (greeting != null && greeting != _greeting) {
      _greeting = greeting;
      _pendingGreeting = _enabled && !_paused && greetingActive
          ? _clock()
          : null;
    }
    if (!greetingActive) _pendingGreeting = null;
    if (!_enabled || _paused) return;
    final pending = _pendingGreeting;
    if (pending != null) {
      // Chỉ đợi unlock rất ngắn; không phát bù lời chào sau khi người dùng
      // đã chuyển việc, bật lại âm thanh hoặc quay về Home.
      if (_clock() - pending > const Duration(milliseconds: 500) ||
          _coolingDown) {
        _pendingGreeting = null;
      } else if (_ready) {
        _pendingGreeting = null;
        _emit(HomeCompanionSound.greeting);
        return;
      } else {
        return;
      }
    }
    if (!phaseChanged || !_ready) return;
    final sound = switch (phase) {
      HomeCompanionPhase.hopping => HomeCompanionSound.hop,
      HomeCompanionPhase.sweeping => HomeCompanionSound.sweep,
      HomeCompanionPhase.celebrating => HomeCompanionSound.success,
      _ => null,
    };
    if (sound == null) return;
    _emit(sound);
  }

  bool get _ready =>
      _enabled && !_paused && _unlocked && !_busy && _pendingStops == 0;

  bool get _coolingDown =>
      _lastSound != null && _clock() - _lastSound! < cooldown;

  void _emit(HomeCompanionSound sound) {
    if (_coolingDown) return;
    _lastSound = _clock();
    _busy = true;
    unawaited(_play(sound, _generation));
  }

  bool _isCurrent(int generation) =>
      !_disposed && _enabled && generation == _generation;

  Future<void> _play(HomeCompanionSound sound, int generation) async {
    try {
      await _output.prepare(waveFor(sound));
      if (!_isCurrent(generation) || _paused) return;
      await _output.play(volume);
      if (!_isCurrent(generation) && !_disposed) await _stopPlayback();
    } catch (_) {
      // Âm trang trí không được gây lỗi màn Home hoặc lặp lại lỗi mỗi frame.
      _unlocked = false;
    } finally {
      _busy = false;
    }
  }

  void stop() {
    if (_disposed) return;
    _generation++;
    _phase = null;
    _pendingGreeting = null;
    unawaited(_stopPlayback());
  }

  Future<void> _stopPlayback() async {
    // Đợi lệnh dừng cũ kết thúc trước khi cho phép mở/phát âm mới.
    // Nếu không, stop chậm của nền tảng có thể tắt nhầm lần phát tiếp theo.
    _pendingStops++;
    try {
      await _quiet(_output.stop);
    } finally {
      _pendingStops--;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _enabled = false;
    unawaited(_quiet(_output.dispose));
  }

  static Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Thiết bị audio có thể đã được hệ điều hành thu hồi khi app ẩn.
    }
  }

  /// WAV PCM mono nhỏ, âm lượng thấp; không cần asset, mạng hay package mới.
  @visibleForTesting
  static Uint8List waveFor(HomeCompanionSound sound) {
    const sampleRate = 22050;
    final duration = switch (sound) {
      HomeCompanionSound.greeting => 0.28,
      HomeCompanionSound.hop => 0.12,
      HomeCompanionSound.sweep => 0.22,
      HomeCompanionSound.success => 0.30,
    };
    final count = (sampleRate * duration).round();
    final bytes = _waveHeader(count, sampleRate);
    final view = ByteData.sublistView(bytes);
    var phase = 0.0;
    final random = math.Random(27);
    var filteredNoise = 0.0;
    for (var i = 0; i < count; i++) {
      final progress = i / (count - 1);
      // Hai tiếng líu ríu có khoảng nghỉ và fade riêng, không cắt sóng
      // đột ngột gây click; cao độ mềm hơn tiếng thành công.
      final chirpProgress = ((progress % 0.5) / 0.42).clamp(0.0, 1.0);
      final envelope = math
          .pow(
            math.sin(
              math.pi *
                  (sound == HomeCompanionSound.greeting
                      ? chirpProgress
                      : progress),
            ),
            2,
          )
          .toDouble();
      final frequency = switch (sound) {
        HomeCompanionSound.greeting =>
          (progress < 0.5 ? 560.0 : 700.0) + 130 * chirpProgress,
        HomeCompanionSound.hop => 480 + 320 * progress,
        HomeCompanionSound.sweep => 150.0,
        HomeCompanionSound.success => progress < 0.5 ? 660.0 : 880.0,
      };
      phase += 2 * math.pi * frequency / sampleRate;
      filteredNoise =
          filteredNoise * 0.86 + (random.nextDouble() * 2 - 1) * 0.14;
      final signal = sound == HomeCompanionSound.sweep
          ? filteredNoise * 1.4
          : math.sin(phase) * 0.8 + math.sin(phase * 2) * 0.12;
      final sample = (signal * envelope * 0.24 * 32767).round();
      view.setInt16(44 + i * 2, sample.clamp(-32767, 32767), Endian.little);
    }
    return bytes;
  }

  static Uint8List _waveHeader(int count, int rate) {
    final bytes = Uint8List(44 + count * 2);
    final view = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    view.setUint32(4, bytes.length - 8, Endian.little);
    bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, 1, Endian.little);
    view.setUint32(24, rate, Endian.little);
    view.setUint32(28, rate * 2, Endian.little);
    view.setUint16(32, 2, Endian.little);
    view.setUint16(34, 16, Endian.little);
    bytes.setRange(36, 40, 'data'.codeUnits);
    view.setUint32(40, count * 2, Endian.little);
    return bytes;
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}

class _PlayerOutput implements HomeCompanionAudioOutput {
  AudioPlayer? _player;
  bool _configured = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  Future<void> unlock() async {
    if (!kIsWeb || _disposed) return;
    final generation = _generation;
    // Gọi từ gesture thay vì ticker. Nếu browser vẫn chặn thì controller
    // giữ im lặng; không tìm cách vượt chính sách autoplay của trình duyệt.
    await prepare(HomeCompanionAudio._waveHeader(441, 22050));
    if (!_disposed && generation == _generation) await play(0);
  }

  @override
  Future<void> prepare(Uint8List wave) async {
    if (_disposed) return;
    final generation = _generation;
    final player = _player ??= AudioPlayer();
    if (!_configured) {
      // Không lấy audio focus/duck nhạc. Scene phải dừng helper khi route ẩn,
      // đang gọi hoặc phát media; audio session native dùng chung toàn app.
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
    if (_disposed || generation != _generation) await player.stop();
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
