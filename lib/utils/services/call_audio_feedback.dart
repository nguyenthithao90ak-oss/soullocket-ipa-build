import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../views/ui_prefs.dart';

enum CallTone { ringing, connected, ended, enabled, disabled }

abstract interface class CallToneOutput {
  Future<void> play(Uint8List wave, double volume);
  Future<void> stop();
  Future<void> dispose();
}

/// Output riêng: không dùng AudioPlayer làm thay đổi audio session của WebRTC.
class NativeCallToneOutput implements CallToneOutput {
  NativeCallToneOutput() {
    _latestSession = _session;
  }

  static const _channel = MethodChannel('soullocket/call_tones');
  static int _nextSession = 0;
  static String? _latestSession;
  final _session = '${DateTime.now().microsecondsSinceEpoch}-${_nextSession++}';

  @override
  Future<void> play(Uint8List wave, double volume) {
    // Lệnh play kết thúc tới muộn cũng không được giành âm của cuộc gọi mới.
    if (_latestSession != _session) return Future<void>.value();
    return _channel.invokeMethod<void>('play', {
      'session': _session,
      'wave': wave,
      'volume': volume,
    });
  }

  @override
  Future<void> stop() =>
      _channel.invokeMethod<void>('stop', {'session': _session});

  @override
  Future<void> dispose() =>
      _channel.invokeMethod<void>('dispose', {'session': _session});
}

enum _CallAudioPhase { idle, ringing, connected, ended }

/// Một instance theo màn gọi. Âm lỗi không được chặn nút bấm hay dọn media.
class CallAudioFeedback with WidgetsBindingObserver {
  CallAudioFeedback({
    CallToneOutput? output,
    ValueListenable<UiPrefsState>? preferences,
  }) : _output = output ?? NativeCallToneOutput(),
       _preferences = preferences ?? UiPrefs.notifier {
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _preferences.addListener(_syncPreferences);
  }

  static const ringInterval = Duration(seconds: 3);
  final CallToneOutput _output;
  final ValueListenable<UiPrefsState> _preferences;
  _CallAudioPhase _phase = _CallAudioPhase.idle;
  Future<void> _commands = Future<void>.value();
  Future<void>? _finishFuture;
  Timer? _ringTimer;
  Timer? _busyTimer;
  CallTone? _activeTone;
  bool _foreground = true;
  bool _busy = false;
  bool _disposed = false;
  bool _outputFailed = false;
  int _generation = 0;

  bool get _audible => !_disposed && !_outputFailed && _foreground;

  static bool _isControlTone(CallTone? tone) =>
      tone == CallTone.enabled || tone == CallTone.disabled;

  // Âm chờ/kết nối/kết thúc thuộc cuộc gọi; touchSound chỉ điều khiển âm nút.
  bool _canPlay(CallTone tone) =>
      _audible && (!_isControlTone(tone) || _preferences.value.touchSound);

  void startRinging() {
    if (_disposed || _finishFuture != null || _phase != _CallAudioPhase.idle) {
      return;
    }
    _phase = _CallAudioPhase.ringing;
    _ring();
  }

  void connected() {
    if (_disposed ||
        _finishFuture != null ||
        _phase == _CallAudioPhase.connected) {
      return;
    }
    _phase = _CallAudioPhase.connected;
    _interrupt();
    _play(CallTone.connected);
  }

  void control({required bool enabled}) {
    if (_finishFuture != null || _phase == _CallAudioPhase.ended) return;
    _play(enabled ? CallTone.enabled : CallTone.disabled);
  }

  void _ring() {
    if (!_audible || _phase != _CallAudioPhase.ringing) return;
    _play(CallTone.ringing);
    _ringTimer?.cancel();
    _ringTimer = Timer(ringInterval, _ring);
  }

  void _play(CallTone tone) {
    if (!_canPlay(tone) || _busy) return;
    _busy = true;
    _activeTone = tone;
    final generation = _generation;
    _enqueue(() async {
      if (!_current(generation) || !_canPlay(tone)) return;
      await _output.play(CallToneWaves.waveFor(tone), _volume(tone));
      // _interrupt đã xếp stop; callback play cũ không được dừng âm mới
      // sau khi watchdog cho phép hàng đợi tiếp tục.
      if (!_current(generation)) return;
      _busyTimer = Timer(CallToneWaves.durationFor(tone), () {
        if (_current(generation)) {
          _busy = false;
          _activeTone = null;
        }
      });
    }, toneGeneration: generation);
  }

  bool _current(int generation) => _audible && generation == _generation;

  static double _volume(CallTone tone) => switch (tone) {
    CallTone.enabled || CallTone.disabled => .12,
    _ => .32,
  };

  void _enqueue(Future<void> Function() action, {int? toneGeneration}) {
    _commands = _commands.then((_) async {
      try {
        await action().timeout(const Duration(seconds: 2));
      } catch (error) {
        // Không dùng âm thanh để quyết định kết nối hay thành công thao tác.
        if (toneGeneration == _generation) {
          // Native có thể bận lúc đổi đường thoại. Chỉ thiếu bridge mới tắt
          // hẳn output; lỗi tạm thời thử lại ở nhịp chờ/trạng thái kế tiếp.
          _outputFailed = error is MissingPluginException;
          _interrupt();
          if (_audible && _phase == _CallAudioPhase.ringing) {
            _ringTimer = Timer(ringInterval, _ring);
          }
        }
      }
    });
  }

  void _interrupt() {
    _generation++;
    _ringTimer?.cancel();
    _busyTimer?.cancel();
    _busy = false;
    _activeTone = null;
    _enqueue(_output.stop);
  }

  void _syncPreferences() {
    if (_disposed ||
        _preferences.value.touchSound ||
        !_isControlTone(_activeTone)) {
      return;
    }
    // Đổi theme hay các cài đặt khác không được cắt âm báo cuộc gọi đang phát.
    _interrupt();
    if (_audible && _phase == _CallAudioPhase.ringing) _ring();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground || _disposed) return;
    _foreground = foreground;
    _interrupt();
    if (_audible && _phase == _CallAudioPhase.ringing) _ring();
  }

  /// Âm kết thúc ngắn được tự nhả kể cả khi route vừa đóng.
  Future<void> finish() => _finishFuture ??= _finish(playEnd: true);

  Future<void> dispose() => _finishFuture ??= _finish(playEnd: false);

  Future<void> _finish({required bool playEnd}) async {
    _phase = _CallAudioPhase.ended;
    _interrupt();
    if (playEnd && _audible) {
      _play(CallTone.ended);
      await _commands;
      await Future<void>.delayed(CallToneWaves.durationFor(CallTone.ended));
    }
    _disposed = true;
    _generation++;
    _ringTimer?.cancel();
    _busyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _preferences.removeListener(_syncPreferences);
    _enqueue(_output.dispose);
    await _commands;
  }
}

/// WAV tự tổng hợp, không tải mạng, không mượn âm thanh của ứng dụng khác.
abstract final class CallToneWaves {
  static const sampleRate = 22050;
  static final _cache = <CallTone, Uint8List>{};

  static Duration durationFor(CallTone tone) => switch (tone) {
    CallTone.ringing => const Duration(milliseconds: 640),
    CallTone.connected => const Duration(milliseconds: 200),
    CallTone.ended => const Duration(milliseconds: 280),
    CallTone.enabled || CallTone.disabled => const Duration(milliseconds: 65),
  };

  static Uint8List waveFor(CallTone tone) =>
      _cache.putIfAbsent(tone, () => _synthesize(tone).asUnmodifiableView());

  static Uint8List _synthesize(CallTone tone) {
    final samples = (durationFor(tone).inMicroseconds * sampleRate / 1000000)
        .round();
    final wave = Uint8List(44 + samples * 2);
    final data = ByteData.sublistView(wave);
    wave.setRange(0, 4, 'RIFF'.codeUnits);
    data.setUint32(4, wave.length - 8, Endian.little);
    wave.setRange(8, 16, 'WAVEfmt '.codeUnits);
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    wave.setRange(36, 40, 'data'.codeUnits);
    data.setUint32(40, samples * 2, Endian.little);
    var phase = 0.0;
    for (var i = 0; i < samples; i++) {
      final p = i / (samples - 1);
      final frequency = switch (tone) {
        CallTone.ringing => p < .5 ? 440.0 : 554.37,
        CallTone.connected => p < .45 ? 659.25 : 880.0,
        CallTone.ended => p < .45 ? 493.88 : 329.63,
        CallTone.enabled => 600.0,
        CallTone.disabled => 420.0,
      };
      phase += 2 * math.pi * frequency / sampleRate;
      final envelope = math.pow(math.sin(math.pi * p), 2).toDouble();
      final sample = (math.sin(phase) * envelope * .4 * 32767).round();
      data.setInt16(44 + i * 2, sample, Endian.little);
    }
    return wave;
  }
}
