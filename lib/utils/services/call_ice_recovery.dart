import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Chỉ caller tạo restart offer để hai đầu đổi mạng cùng lúc không bị glare.
/// Signaling nằm trong phòng cũ; không gửi lại lời mời/push hoặc đổi quota.
class CallIceRecovery {
  CallIceRecovery({
    required this.peer,
    required this.isCaller,
    required this.isCurrent,
    required this.write,
    required this.onLocalGeneration,
    required this.onRemoteGeneration,
    required this.onRecovering,
    required this.onFailure,
    this.prepareRestart,
  });
  final RTCPeerConnection peer;
  final bool isCaller;
  final bool Function() isCurrent;
  final Future<void> Function(Map<String, Object?>) write;
  final void Function(int) onLocalGeneration;
  final Future<void> Function(int) onRemoteGeneration;
  final void Function(bool) onRecovering;
  final void Function() onFailure;
  final Future<void> Function()? prepareRestart;
  static const maxRestarts = 12;
  static const recoveryWindow = Duration(seconds: 15);
  bool _closed = false;
  bool _enabled = false;
  bool _remoteSupported = false;
  bool _everConnected = false;
  bool _recovering = false;
  bool _waitingAnswer = false;
  int _generation = 0;
  int _answered = 0;
  int _request = 0;
  int _seenRequest = 0;
  int _attempts = 0;
  Future<void> _tail = Future.value();
  Timer? _deadline;
  Timer? _debounce;
  Timer? _retry;
  RTCPeerConnectionState? _state;
  bool get _alive {
    if (_closed) return false;
    if (isCurrent()) return true;
    close();
    return false;
  }

  bool get canRecover =>
      _alive &&
      _enabled &&
      _remoteSupported &&
      _everConnected &&
      _generation < maxRestarts;
  bool get isRecovering => _recovering;

  Future<void> start() async {
    try {
      if (!_alive) return;
      await write({
        isCaller ? 'callerVersion' : 'calleeVersion': 1,
      }).timeout(const Duration(seconds: 4));
      if (_alive) _enabled = true;
    } catch (_) {
      // Rules cũ chưa có nhánh recovery: giữ cuộc gọi gốc hoạt động bình thường.
      _enabled = false;
    }
  }

  void receive(Object? raw) {
    if (!_alive || raw is! Map) return;
    _remoteSupported = raw[isCaller ? 'calleeVersion' : 'callerVersion'] == 1;
    unawaited(
      _enqueue(() async {
        if (!_enabled || !_remoteSupported) return;
        if (isCaller) {
          final answer = _description(raw['answer'], 'answer');
          if (answer != null &&
              answer.$1 == _generation &&
              _waitingAnswer &&
              answer.$1 > _answered) {
            await peer.setRemoteDescription(answer.$2);
            if (!_alive) return;
            await onRemoteGeneration(answer.$1);
            if (!_alive) return;
            _answered = answer.$1;
            _waitingAnswer = false;
            _afterHandshake();
          }
          final request = raw['request'];
          if (request is int &&
              request > _seenRequest &&
              request <= maxRestarts) {
            _seenRequest = request;
            requestRecovery();
          }
        } else {
          final offer = _description(raw['offer'], 'offer');
          if (offer == null || offer.$1 != _generation + 1) return;
          _beginEpisode();
          _generation = offer.$1;
          await prepareRestart?.call();
          if (!_alive) return;
          await peer.setRemoteDescription(offer.$2);
          if (!_alive) return;
          await onRemoteGeneration(_generation);
          if (!_alive) return;
          final answer = await peer.createAnswer();
          if (!_alive) return;
          onLocalGeneration(_generation);
          await peer.setLocalDescription(answer);
          if (!_alive) return;
          await write({
            'answer': {'id': _generation, 'type': 'answer', 'sdp': answer.sdp},
          }).timeout(const Duration(seconds: 4));
          if (!_alive) return;
          _answered = _generation;
          _afterHandshake();
        }
      }),
    );
  }

  void stateChanged(RTCPeerConnectionState state) {
    if (!_alive) return;
    _state = state;
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _everConnected = true;
      if (!_waitingAnswer) _finishEpisode();
    } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      requestRecovery();
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
      close();
    }
  }

  void networkChanged() => requestRecovery();

  void requestRecovery() {
    if (!canRecover || _waitingAnswer || _debounce != null) return;
    _beginEpisode();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _debounce = null;
      if (!canRecover || _waitingAnswer) return;
      unawaited(
        _enqueue(() async {
          if (!canRecover || _waitingAnswer) return;
          if (!isCaller) {
            if (_request >= maxRestarts) return;
            await write({
              'request': ++_request,
            }).timeout(const Duration(seconds: 4));
            return;
          }
          if (_attempts >= 2) return;
          _attempts++;
          _generation++;
          _waitingAnswer = true;
          await prepareRestart?.call();
          if (!_alive) return;
          // Bridge native không đọc iceRestart ở top-level createOffer options.
          // Gọi API riêng để thực sự đổi ICE credential trên Android/iOS/Web.
          await peer.restartIce();
          if (!_alive) return;
          final offer = await peer.createOffer();
          if (!_alive) return;
          onLocalGeneration(_generation);
          await peer.setLocalDescription(offer);
          if (!_alive) return;
          await write({
            'offer': {'id': _generation, 'type': 'offer', 'sdp': offer.sdp},
          }).timeout(const Duration(seconds: 4));
        }),
      );
    });
  }

  void _beginEpisode() {
    if (!_alive || _recovering) return;
    _recovering = true;
    _attempts = 0;
    onRecovering(true);
    _deadline = Timer(recoveryWindow, () {
      if (!_alive) return;
      if (_state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        // Đổi mạng chủ động nhưng signaling lỗi không được cúp tiếng đang tốt.
        _enabled = false;
        _finishEpisode();
      } else {
        _fail();
      }
    });
  }

  void _afterHandshake() {
    if (_state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _finishEpisode();
    } else if (isCaller && _attempts < 2) {
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 4), requestRecovery);
    }
  }

  void _finishEpisode() {
    _deadline?.cancel();
    _deadline = null;
    _retry?.cancel();
    _retry = null;
    _debounce?.cancel();
    _debounce = null;
    if (!_recovering) return;
    _recovering = false;
    onRecovering(false);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _tail.then((_) async {
      if (_alive) await action();
    });
    _tail = operation.catchError((Object _) {
      if (!_alive) return;
      if (_state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _enabled = false;
        _finishEpisode();
      } else {
        // Chuyển Wi-Fi/4G có thể làm RTDB mất mạng cùng lúc. Vẫn chừa đủ
        // cửa sổ 15 giây cho ICE tự hồi phục thay vì cúp sớm do một write lỗi.
        _beginEpisode();
      }
    });
    return _tail;
  }

  void _fail() {
    if (!_alive) return;
    close();
    onFailure();
  }

  static (int, RTCSessionDescription)? _description(Object? raw, String type) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final sdp = raw['sdp'];
    if (id is! int ||
        id < 1 ||
        id > maxRestarts ||
        raw['type'] != type ||
        sdp is! String ||
        sdp.isEmpty ||
        sdp.length > 65536) {
      return null;
    }
    return (id, RTCSessionDescription(sdp, type));
  }

  void close() {
    _closed = true;
    _deadline?.cancel();
    _retry?.cancel();
    _debounce?.cancel();
    _recovering = false;
  }

  Future<void> waitUntilIdle() => _tail;
}
