import 'dart:math' as math;
import 'dart:typed_data';

enum UiSoundCue {
  click,
  success,
  saved,
  paired,
  sent,
  received,
  reward,
  result,
  flip,
  uploadComplete,
  petPickup,
  petBite,
  petBubble,
  petRinse,
  petDry,
  petCuddle,
}

/// Âm tổng hợp cục bộ: không tải asset, không dùng mạng hoặc ghi âm người dùng.
abstract final class UiSoundWaves {
  static const sampleRate = 22050;
  static final _cache = <String, Uint8List>{};

  static Duration durationFor(UiSoundCue cue) => switch (cue) {
    UiSoundCue.click => const Duration(milliseconds: 75),
    UiSoundCue.success => const Duration(milliseconds: 240),
    UiSoundCue.saved => const Duration(milliseconds: 300),
    UiSoundCue.paired => const Duration(milliseconds: 440),
    UiSoundCue.sent => const Duration(milliseconds: 130),
    UiSoundCue.received => const Duration(milliseconds: 180),
    UiSoundCue.reward => const Duration(milliseconds: 420),
    UiSoundCue.result => const Duration(milliseconds: 360),
    UiSoundCue.flip => const Duration(milliseconds: 105),
    UiSoundCue.uploadComplete => const Duration(milliseconds: 330),
    UiSoundCue.petPickup => const Duration(milliseconds: 120),
    UiSoundCue.petBite => const Duration(milliseconds: 210),
    UiSoundCue.petBubble => const Duration(milliseconds: 350),
    UiSoundCue.petRinse => const Duration(milliseconds: 420),
    UiSoundCue.petDry => const Duration(milliseconds: 300),
    UiSoundCue.petCuddle => const Duration(milliseconds: 390),
  };

  /// Số biến thể của cue. Biến thể được đổi luân phiên khi cùng một sự kiện
  /// xảy ra nhiều lần, tránh cảm giác lặp lại máy móc.
  static int variantCount(UiSoundCue cue) => switch (cue) {
    UiSoundCue.click || UiSoundCue.success => 1,
    _ => 2,
  };

  static Uint8List waveFor(UiSoundCue cue, {int variant = 0}) {
    final normalized = variant % variantCount(cue);
    final key = '${cue.name}:$normalized';
    return _cache.putIfAbsent(
      key,
      () => _synthesize(cue, normalized).asUnmodifiableView(),
    );
  }

  static Uint8List silence() => _header(441);

  static Uint8List _synthesize(UiSoundCue cue, int variant) {
    final seconds = durationFor(cue).inMicroseconds / 1000000;
    final count = (seconds * sampleRate).round();
    final wave = _header(count);
    final data = ByteData.sublistView(wave);
    var phase = 0.0;
    var noiseSeed = 73 + variant * 97;
    var softNoise = 0.0;
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final p = i / (count - 1);
      noiseSeed = (noiseSeed * 1664525 + 1013904223) & 0xffffffff;
      softNoise = softNoise * .78 + ((noiseSeed / 0xffffffff) * 2 - 1) * .22;
      final frequency = switch (cue) {
        UiSoundCue.petPickup => 440 + 460 * p + variant * 45,
        UiSoundCue.petBite =>
          190 + 100 * math.sin(p * math.pi * 4) + variant * 30,
        UiSoundCue.petBubble =>
          350 + 390 * math.pow(1 - (p * 3 % 1), 2) + variant * 60,
        UiSoundCue.petRinse => 950 - p * 360 + variant * 40,
        UiSoundCue.petDry =>
          380 + math.sin(p * math.pi * 2) * 180 + variant * 30,
        UiSoundCue.petCuddle => p < .4 ? 523.25 + variant * 30 : 783.99,
        UiSoundCue.click => 420 - 150 * p,
        UiSoundCue.success => p < 0.46 ? 523.25 : 659.25,
        UiSoundCue.saved =>
          variant == 0
              ? (p < 0.33 ? 392.0 : 783.99)
              : (p < 0.45 ? 440.0 : 659.25),
        UiSoundCue.paired =>
          variant == 0
              ? (p < 0.42 ? 523.25 : 659.25)
              : (p < 0.35 ? 440.0 : 659.25),
        UiSoundCue.sent => variant == 0 ? 310 + 390 * p : 520 - 260 * p,
        UiSoundCue.received => variant == 0 ? 740 - 300 * p : 620 - 230 * p,
        UiSoundCue.reward =>
          variant == 0
              ? (p < 0.33
                    ? 587.33
                    : p < 0.66
                    ? 739.99
                    : 880.0)
              : (p < 0.33
                    ? 659.25
                    : p < 0.66
                    ? 783.99
                    : 987.77),
        UiSoundCue.result =>
          variant == 0
              ? (p < 0.5 ? 783.99 : 523.25)
              : (p < 0.5 ? 659.25 : 493.88),
        UiSoundCue.flip => variant == 0 ? 900 - 340 * p : 660 + 260 * p,
        UiSoundCue.uploadComplete =>
          variant == 0
              ? (p < 0.46 ? 493.88 : 659.25)
              : (p < 0.46 ? 554.37 : 739.99),
      };
      phase += 2 * math.pi * frequency / sampleRate;
      final envelope = math.pow(math.sin(math.pi * p), 2).toDouble();
      // Nốt chuông có đuôi êm; mỗi semantic cue có màu âm riêng.
      final harmonic = switch (cue) {
        UiSoundCue.paired =>
          math.sin(2 * math.pi * (variant == 0 ? 783.99 : 659.25) * t) * 0.22,
        UiSoundCue.reward => math.sin(phase * 2) * 0.16,
        UiSoundCue.result => math.sin(phase * 0.5) * 0.16,
        UiSoundCue.flip => math.sin(phase * 3) * 0.05,
        _ => math.sin(phase * 2) * 0.09,
      };
      // Tiếng cắn, bọt và nước tự tổng hợp; noise được lọc êm, không dùng sample bên ngoài.
      final signal = switch (cue) {
        UiSoundCue.petBite =>
          (softNoise * 1.4 + math.sin(phase) * .18) *
              math.pow(math.sin(p * math.pi * 3), 2),
        UiSoundCue.petRinse => softNoise * 1.35 + math.sin(phase) * .09,
        UiSoundCue.petDry => softNoise * 1.3 + math.sin(phase) * .16,
        UiSoundCue.petBubble =>
          math.sin(phase) * .55 * math.pow(math.sin(p * math.pi * 3), 2),
        _ => math.sin(phase) * 0.68 + harmonic,
      };
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
