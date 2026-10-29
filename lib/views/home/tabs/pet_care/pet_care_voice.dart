import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Bản nhại vừa ghi: file WAV đã nâng giọng và nhịp to/nhỏ từng khung để bé
/// mấp máy miệng theo.
class PetCareEcho {
  const PetCareEcho({
    required this.path,
    required this.envelope,
    required this.frame,
  });

  final String path;

  /// Độ to từng khung (0..1) theo thời gian phát.
  final List<double> envelope;
  final Duration frame;

  Duration get length => frame * envelope.length;

  /// Độ há miệng tại thời điểm [at] kể từ lúc bắt đầu phát.
  double mouthAt(Duration at) {
    if (envelope.isEmpty || frame <= Duration.zero) return 0;
    final index = at.inMicroseconds ~/ frame.inMicroseconds;
    return index < 0 || index >= envelope.length ? 0 : envelope[index];
  }
}

/// Bé nhại lại giọng người chơi (kiểu Talking Tom). Giọng chỉ nằm trong file
/// tạm trên máy, phát xong là xóa; không lưu, không gửi đi.
abstract interface class PetCareVoice {
  /// Xin quyền micro rồi bắt đầu nghe; false khi không có quyền/không ghi được.
  Future<bool> listen();

  /// Độ to giọng lúc đang nghe (0..1), khoảng 10 lần mỗi giây.
  Stream<double> get loudness;

  /// Dừng nghe; trả bản nhại hoặc null nếu không ghi được gì.
  Future<PetCareEcho?> finish();

  /// Phát bản nhại; [mouth] nhận độ há miệng 0..1 theo giọng. Xong thì trả về.
  Future<void> speak(PetCareEcho echo, ValueChanged<double> mouth);

  /// Dừng nghe/phát (ra nền, rời màn) và xóa file tạm.
  Future<void> stop();

  Future<void> dispose();
}

/// Tốc độ nhại: phát nhanh 1,5 lần nên giọng cao hơn khoảng 7 nửa cung.
const petCareEchoPitch = 1.5;

/// Giọng thu ở 16 kHz, mono, PCM 16-bit để tự đổi tốc độ không cần thư viện.
const _sampleRate = 16000;

/// Đổi tần số mẫu trong header WAV PCM: phát nhanh và cao giọng hơn ([factor]
/// lần) mà không xử lý lại âm thanh. Trả null nếu không phải WAV đọc được.
Uint8List? petCarePitchWav(Uint8List wav, {double factor = petCareEchoPitch}) {
  final format = _WavFormat.read(wav);
  if (format == null || factor <= 0) return null;
  final out = Uint8List.fromList(wav);
  final data = ByteData.sublistView(out);
  final rate = (format.sampleRate * factor).round();
  data.setUint32(format.fmtOffset + 12, rate, Endian.little);
  data.setUint32(
    format.fmtOffset + 16,
    rate * format.blockAlign,
    Endian.little,
  );
  return out;
}

/// Độ to từng khung [frame] của WAV PCM 16-bit, chuẩn hóa 0..1 theo khung to
/// nhất (khung lặng gần 0). Trả rỗng nếu không đọc được.
List<double> petCareWavEnvelope(
  Uint8List wav, {
  Duration frame = const Duration(milliseconds: 50),
}) {
  final format = _WavFormat.read(wav);
  if (format == null || format.bitsPerSample != 16) return const [];
  final data = ByteData.sublistView(wav);
  final end = math.min(wav.length, format.dataOffset + format.dataLength);
  final perFrame = math.max(
    1,
    (format.sampleRate * frame.inMicroseconds / 1e6).round() *
        format.blockAlign,
  );
  final levels = <double>[];
  for (var start = format.dataOffset; start + 2 <= end; start += perFrame) {
    final stop = math.min(end, start + perFrame);
    var sum = 0.0;
    var count = 0;
    for (var i = start; i + 2 <= stop; i += format.blockAlign) {
      final sample = data.getInt16(i, Endian.little) / 32768;
      sum += sample * sample;
      count++;
    }
    levels.add(count == 0 ? 0 : math.sqrt(sum / count));
  }
  final peak = levels.fold<double>(0, math.max);
  if (peak <= 0) return List.filled(levels.length, 0);
  // Khung nhỏ hơn 12% đỉnh coi như lặng để miệng khép giữa các tiếng.
  return [
    for (final level in levels)
      level / peak < .12 ? 0 : math.pow(level / peak, .6).toDouble(),
  ];
}

class _WavFormat {
  const _WavFormat({
    required this.fmtOffset,
    required this.sampleRate,
    required this.blockAlign,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });

  final int fmtOffset;
  final int sampleRate;
  final int blockAlign;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;

  static _WavFormat? read(Uint8List wav) {
    if (wav.length < 44) return null;
    String tag(int at) => String.fromCharCodes(wav, at, at + 4);
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
    final data = ByteData.sublistView(wav);
    int? fmt;
    int? dataOffset;
    var dataLength = 0;
    var offset = 12;
    while (offset + 8 <= wav.length) {
      final size = data.getUint32(offset + 4, Endian.little);
      switch (tag(offset)) {
        case 'fmt ':
          fmt = offset;
        case 'data':
          dataOffset = offset + 8;
          // Bản ghi chưa chốt header có thể để kích thước 0/tối đa.
          dataLength = size == 0 || size > wav.length - dataOffset
              ? wav.length - dataOffset
              : size;
      }
      if (dataOffset != null) break;
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    if (fmt == null || dataOffset == null || fmt + 24 > wav.length) {
      return null;
    }
    final audioFormat = data.getUint16(fmt + 8, Endian.little);
    final rate = data.getUint32(fmt + 12, Endian.little);
    final blockAlign = data.getUint16(fmt + 20, Endian.little);
    final bits = data.getUint16(fmt + 22, Endian.little);
    // 1 = PCM, 0xFFFE = WAVE_FORMAT_EXTENSIBLE (vẫn là PCM thường gặp trên iOS).
    if ((audioFormat != 1 && audioFormat != 0xFFFE) ||
        rate == 0 ||
        blockAlign == 0) {
      return null;
    }
    return _WavFormat(
      fmtOffset: fmt,
      sampleRate: rate,
      blockAlign: blockAlign,
      bitsPerSample: bits,
      dataOffset: dataOffset,
      dataLength: dataLength,
    );
  }
}

/// Bản chạy thật: ghi bằng `record`, phát bằng `audioplayers`.
class RecordPetCareVoice implements PetCareVoice {
  RecordPetCareVoice({
    AudioRecorder Function()? createRecorder,
    Future<Directory> Function()? temporaryDirectory,
  }) : _createRecorder = createRecorder ?? AudioRecorder.new,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AudioRecorder Function() _createRecorder;
  final Future<Directory> Function() _temporaryDirectory;

  // Chỉ tạo bộ ghi khi người chơi bấm micro lần đầu (tạo là nối plugin).
  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= _createRecorder();
  final _levels = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSub;
  AudioPlayer? _player;
  final _files = <String>{};
  Timer? _mouthTimer;
  Completer<void>? _speaking;
  bool _recording = false;
  bool _finishing = false;
  bool _disposed = false;
  int _operationGeneration = 0;
  Future<void>? _stopOperation;

  @override
  Stream<double> get loudness => _levels.stream;

  @override
  Future<bool> listen() async {
    if (_disposed) return false;
    final generation = ++_operationGeneration;
    await _stopInternal();
    if (!_isCurrent(generation)) return false;
    final recorder = _recorder;
    try {
      if (!await recorder.hasPermission()) return false;
      if (!_isCurrent(generation)) return false;
      final dir = await _temporaryDirectory();
      if (!_isCurrent(generation)) return false;
      final path =
          '${dir.path}/pet_care_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
      _files.add(path);
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
        path: path,
      );
      if (!_isCurrent(generation)) {
        try {
          await recorder.cancel();
        } catch (_) {}
        await _delete(path);
        return false;
      }
      _recording = true;
      await _amplitudeSub?.cancel();
      if (!_isCurrent(generation)) {
        try {
          await recorder.cancel();
        } catch (_) {}
        _recording = false;
        await _delete(path);
        return false;
      }
      _amplitudeSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
            (amp) {
              if (_isCurrent(generation)) {
                _levels.add(((amp.current + 55) / 45).clamp(0.0, 1.0));
              }
            },
            onError: (_) {},
          );
      return true;
    } catch (error) {
      debugPrint('PetCareVoice: không ghi được giọng: $error');
      _recording = false;
      return false;
    }
  }

  @override
  Future<PetCareEcho?> finish() async {
    if (!_recording || _finishing || _disposed) return null;
    _finishing = true;
    final generation = _operationGeneration;
    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      final path = await _recorder.stop();
      _recording = false;
      if (path == null) return null;
      _files.add(path);
      if (!_isCurrent(generation)) {
        await _delete(path);
        return null;
      }
      final raw = await File(path).readAsBytes();
      if (!_isCurrent(generation)) {
        await _delete(path);
        return null;
      }
      final pitched = petCarePitchWav(raw);
      if (pitched == null) return null;
      final envelope = petCareWavEnvelope(raw);
      if (envelope.isEmpty) return null;
      final echoPath = '$path.echo.wav';
      _files.add(echoPath);
      await File(echoPath).writeAsBytes(pitched, flush: true);
      if (!_isCurrent(generation)) {
        await _delete(echoPath);
        await _delete(path);
        return null;
      }
      unawaited(_delete(path));
      return PetCareEcho(
        path: echoPath,
        envelope: envelope,
        frame: Duration(microseconds: (50000 / petCareEchoPitch).round()),
      );
    } catch (error) {
      debugPrint('PetCareVoice: không đọc được bản ghi: $error');
      return null;
    } finally {
      _recording = false;
      _finishing = false;
    }
  }

  @override
  Future<void> speak(PetCareEcho echo, ValueChanged<double> mouth) async {
    if (_disposed) {
      await _delete(echo.path);
      return;
    }
    final generation = _operationGeneration;
    final player = _player ??= AudioPlayer();
    final done = _speaking = Completer<void>();
    final sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.play(DeviceFileSource(echo.path));
      if (!_isCurrent(generation)) return;
      final clock = Stopwatch()..start();
      _mouthTimer?.cancel();
      _mouthTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        mouth(echo.mouthAt(clock.elapsed));
        // Phòng khi máy không báo phát xong: dừng sau độ dài bản nhại.
        if (clock.elapsed > echo.length + const Duration(seconds: 1) &&
            !done.isCompleted) {
          done.complete();
        }
      });
      await done.future;
    } catch (error) {
      debugPrint('PetCareVoice: không phát được bản nhại: $error');
    } finally {
      await sub.cancel();
      _mouthTimer?.cancel();
      _mouthTimer = null;
      mouth(0);
      if (identical(_speaking, done)) _speaking = null;
      unawaited(_delete(echo.path));
    }
  }

  @override
  Future<void> stop() async {
    _operationGeneration++;
    await _stopInternal();
  }

  Future<void> _stopInternal() {
    final existing = _stopOperation;
    if (existing != null) return existing;
    final operation = _stopResources();
    _stopOperation = operation;
    return operation.whenComplete(() {
      if (identical(_stopOperation, operation)) {
        _stopOperation = null;
      }
    });
  }

  Future<void> _stopResources() async {
    _mouthTimer?.cancel();
    _mouthTimer = null;
    final speaking = _speaking;
    if (speaking != null && !speaking.isCompleted) speaking.complete();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    try {
      await _player?.stop();
      if (_recording) await _recorder.cancel();
    } catch (_) {
      // Đã dừng/không có gì để dừng.
    }
    _recording = false;
    for (final path in _files.toList()) {
      await _delete(path);
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _operationGeneration;

  Future<void> _delete(String path) async {
    _files.remove(path);
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // File tạm: hệ điều hành sẽ tự dọn nếu xóa không được.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _operationGeneration++;
    await _stopInternal();
    await _recorderInstance?.dispose();
    _recorderInstance = null;
    await _player?.dispose();
    _player = null;
    await _levels.close();
  }
}
