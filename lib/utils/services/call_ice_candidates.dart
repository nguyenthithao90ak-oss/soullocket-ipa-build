import 'package:flutter_webrtc/flutter_webrtc.dart';

/// ICE của lượt nối lại phải đợi đúng SDP, không trộn vào description cũ.
class CallIceCandidates {
  CallIceCandidates(this.apply);
  final Future<void> Function(RTCIceCandidate) apply;
  final Map<int, List<RTCIceCandidate>> _pending = {};
  int _generation = 0;
  bool _ready = false;
  bool _closed = false;
  Future<void>? _draining;

  Future<void> add(RTCIceCandidate candidate, {int generation = 0}) {
    if (_closed ||
        generation < _generation ||
        generation > _generation + 2 ||
        candidate.candidate?.isNotEmpty != true) {
      return Future.value();
    }
    final queue = _pending.putIfAbsent(generation, () => []);
    if (queue.length < 128) queue.add(candidate);
    return _drain();
  }

  Future<void> descriptionReady([int generation = 0]) {
    if (_closed || generation < _generation) return Future.value();
    _generation = generation;
    _pending.removeWhere((key, _) => key < generation);
    _ready = true;
    return _drain();
  }

  Future<void> _drain() {
    if (_closed || !_ready || (_pending[_generation]?.isEmpty ?? true)) {
      return Future.value();
    }
    return _draining ??= _consume();
  }

  Future<void> _consume() async {
    try {
      while (!_closed && _ready) {
        final queue = _pending[_generation];
        if (queue == null || queue.isEmpty) break;
        final candidate = queue.removeAt(0);
        try {
          await apply(candidate);
        } catch (_) {
          // Candidate cũ/lệch ufrag không được chặn toàn bộ hàng đợi mới.
        }
      }
    } finally {
      _draining = null;
    }
  }

  void close() {
    _closed = true;
    _pending.clear();
  }
}
