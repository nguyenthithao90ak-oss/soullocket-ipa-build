import 'dart:math' as math;
import 'dart:typed_data';

enum UiSoundCue { click, success, saved, paired, sent }

/// Âm tổng hợp cục bộ: không tải asset, không dùng mạng hoặc ghi âm người dùng.
abstract final class UiSoundWaves {
  static const sampleRate = 22050;
  static final _cache = <UiSoundCue, Uint8List>{};

  static Duration durationFor(UiSoundCue cue) => switch (cue) {
    UiSoundCue.click => const Duration(milliseconds: 75),
    UiSoundCue.success => const Duration(milliseconds: 240),
    UiSoundCue.saved => const Duration(milliseconds: 300),
    UiSoundCue.paired => const Duration(milliseconds: 440),
    UiSoundCue.sent => const Duration(milliseconds: 130),
  };

  static Uint8List waveFor(UiSoundCue cue) =>
      _cache.putIfAbsent(cue, () => _synthesize(cue).asUnmodifiableView());

  static Uint8List silence() => _header(441);

  static Uint8List _synthesize(UiSoundCue cue) {
    final seconds = durationFor(cue).inMicroseconds / 1000000;
    final count = (seconds * sampleRate).round();
    final wave = _header(count);
    final data = ByteData.sublistView(wave);
    var phase = 0.0;
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final p = i / (count - 1);
      final frequency = switch (cue) {
        UiSoundCue.click => 420 - 150 * p,
        UiSoundCue.success => p < 0.46 ? 523.25 : 659.25,
        UiSoundCue.saved => p < 0.33 ? 392.0 : 783.99,
        UiSoundCue.paired => p < 0.42 ? 523.25 : 659.25,
        UiSoundCue.sent => 310 + 390 * p,
      };
      phase += 2 * math.pi * frequency / sampleRate;
      final envelope = math.pow(math.sin(math.pi * p), 2).toDouble();
      // Nốt chuông có đuôi êm; cặp nốt hòa âm chỉ dành cho ghép nối hoàn tất.
      final harmonic = cue == UiSoundCue.paired
          ? math.sin(2 * math.pi * 783.99 * t) * 0.22
          : math.sin(phase * 2) * 0.09;
      final signal = math.sin(phase) * 0.68 + harmonic;
      final sample = (signal * envelope * 0.30 * 32767).round();
      data.setInt16(44 + i * 2, sample.clamp(-32767, 32767), Endian.little);
    }
    return wave;
  }

  static Uint8List _header(int samples) {
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
    return wave;
  }
}
