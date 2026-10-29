import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../utils/services/couple_call_signaling.dart';
import '../../utils/services/webrtc_service.dart';

enum WatchVoicePhase {
  idle,
  preparing,
  ringing,
  connecting,
  connected,
  reconnecting,
  ending,
}

enum WatchVoiceEndReason { local, remote, busy, timeout, failed }

abstract interface class WatchVoiceTransport {
  bool get isBusy;
  ValueListenable<RTCPeerConnectionState?> get connectionState;
  void reserve();
  Future<void> initialize();
  Future<void> openMedia();
  Future<({String roomId, bool outgoing})> connect();
  Future<void> join(String roomId);
  Future<void> hangUp({bool keepReservation = false});
  void mute(bool muted);
  Stream<String?> roomStatus(String roomId);
  Stream<String> incomingAudioRooms();
}

/// Adapter giữ toàn bộ thao tác native/Firebase ngoài controller vòng đời.
class WatchVoiceRtcTransport implements WatchVoiceTransport {
  WatchVoiceRtcTransport({
    required this.service,
    required this.renderer,
    required this.rendererInitialization,
    required this.myHouseId,
    required this.targetHouseId,
    required this.database,
  });

  final WebRTCService service;
  final RTCVideoRenderer renderer;
  final Future<void> rendererInitialization;
  final String myHouseId;
  final String targetHouseId;
  final FirebaseDatabase database;

  @override
  bool get isBusy => service.isBusy;
  @override
  ValueListenable<RTCPeerConnectionState?> get connectionState =>
      service.connectionState;
  @override
  void reserve() => service.reserveCall();
  @override
  Future<void> initialize() =>
      rendererInitialization.timeout(const Duration(seconds: 8));
  @override
  Future<void> openMedia() async {
    await service.openUserMedia(includeVideo: false);
  }

  @override
  Future<({String roomId, bool outgoing})> connect() =>
      service.connectOrCreateAudioRoom(
        renderer,
        callerHouseId: myHouseId,
        targetHouseId: targetHouseId,
      );
  @override
  Future<void> join(String roomId) => service.joinRoom(roomId, renderer);
  @override
  Future<void> hangUp({bool keepReservation = false}) => service.hangUp(
    keepReservation: keepReservation,
    beforeMediaRelease: () async {
      if (kIsWeb || renderer.textureId != null) {
        await renderer.setSrcObject(stream: null);
      }
    },
  );
  @override
  void mute(bool muted) => service.toggleMic(muted);
  @override
  Stream<String?> roomStatus(String roomId) => database
      .ref('calls/$roomId/status')
      .onValue
      .map((event) => event.snapshot.value?.toString());
  @override
  Stream<String> incomingAudioRooms() => service.watchIncomingAudioRooms(
    callerHouseId: myHouseId,
    targetHouseId: targetHouseId,
  );
}

/// Một phiên thoại do Watch sở hữu. Kết quả setup cũ không được dọn phiên mới.
class WatchVoiceCallController extends ValueNotifier<WatchVoicePhase> {
  WatchVoiceCallController({
    required this.transport,
    required this.myHouseId,
    required this.targetHouseId,
    this.onEnded,
    this.setupTimeout = const Duration(
      seconds: CoupleCallInvite.ringingSeconds,
    ),
    this.reconnectTimeout = const Duration(seconds: 15),
  }) : super(WatchVoicePhase.idle);

  final WatchVoiceTransport transport;
  final String myHouseId;
  final String targetHouseId;
  final void Function(WatchVoiceEndReason)? onEnded;
  final Duration setupTimeout;
  final Duration reconnectTimeout;
  Timer? _timer;
  StreamSubscription<String?>? _roomSubscription;
  StreamSubscription<String>? _incomingSubscription;
  Future<void>? _cleanup;
  int _generation = 0;
  int _roomGeneration = 0;
  bool _owned = false;
  bool _disposed = false;
  bool _switching = false;
  bool _outgoing = false;
  bool _muted = false;
  String? _roomId;

  bool get active => value != WatchVoicePhase.idle;
  String? get roomId => _roomId;

  bool _current(int generation) =>
      !_disposed && _owned && generation == _generation;

  void _phase(WatchVoicePhase phase) {
    if (!_disposed) value = phase;
  }

  void _armTimer(Duration duration, int generation) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (_current(generation)) {
        unawaited(end(WatchVoiceEndReason.timeout));
      }
    });
  }

  Future<void> start() async {
    if (_disposed || active || _cleanup != null) return;
    if (transport.isBusy) {
      onEnded?.call(WatchVoiceEndReason.busy);
      return;
    }
    final generation = ++_generation;
    try {
      // Giữ chỗ đồng bộ trước renderer, quyền micro hay đọc Firebase.
      transport.reserve();
      _owned = true;
      transport.connectionState.addListener(_onConnectionChanged);
      _armTimer(setupTimeout, generation);
      _phase(WatchVoicePhase.preparing);
      if (!_current(generation)) return;
      await transport.initialize();
      if (!_current(generation)) return;
      await transport.openMedia();
      if (!_current(generation)) return;
      transport.mute(_muted);
      final room = await transport.connect();
      if (!_current(generation)) return;
      _followRoom(room.roomId, outgoing: room.outgoing);
      _onConnectionChanged();
    } catch (_) {
      if (_current(generation)) await end(WatchVoiceEndReason.failed);
    }
  }

  void _followRoom(String roomId, {required bool outgoing}) {
    _roomId = roomId;
    _outgoing = outgoing;
    final generation = _generation;
    final roomGeneration = ++_roomGeneration;
    _phase(outgoing ? WatchVoicePhase.ringing : WatchVoicePhase.connecting);
    if (!_current(generation)) return;
    _roomSubscription = transport
        .roomStatus(roomId)
        .listen(
          (status) {
            if (!_current(generation) || roomGeneration != _roomGeneration) {
              return;
            }
            if (status == 'ongoing') {
              if (value == WatchVoicePhase.ringing) {
                _phase(WatchVoicePhase.connecting);
                _armTimer(setupTimeout, generation);
              }
            } else if (status != 'ringing') {
              unawaited(end(WatchVoiceEndReason.remote));
            }
          },
          onError: (Object error) {
            if (_current(generation) && roomGeneration == _roomGeneration) {
              unawaited(end(WatchVoiceEndReason.failed));
            }
          },
        );
    // Chỉ một phía nhường outbound khi hai người bấm gọi cùng lúc.
    // Đây là phân xử ở client; không phải khóa atomic trên máy chủ.
    if (outgoing && myHouseId.compareTo(targetHouseId) > 0) {
      _incomingSubscription = transport.incomingAudioRooms().listen(
        (incomingId) {
          if (_current(generation) &&
              roomGeneration == _roomGeneration &&
              !_switching &&
              _outgoing &&
              value == WatchVoicePhase.ringing &&
              incomingId != _roomId) {
            unawaited(_switchToIncoming(incomingId, generation));
          }
        },
        onError: (Object error) {
          if (_current(generation) && roomGeneration == _roomGeneration) {
            unawaited(end(WatchVoiceEndReason.failed));
          }
        },
      );
    }
  }

  Future<void> _switchToIncoming(String roomId, int generation) async {
    _switching = true;
    _detachRoom();
    _phase(WatchVoicePhase.connecting);
    _armTimer(setupTimeout, generation);
    try {
      // hangUp đóng cả micro; mở lại trước join, không dùng stream đã dispose.
      await transport.hangUp(keepReservation: true);
      if (!_current(generation)) return;
      await transport.openMedia();
      if (!_current(generation)) return;
      transport.mute(_muted);
      await transport.join(roomId);
      if (!_current(generation)) return;
      _switching = false;
      _followRoom(roomId, outgoing: false);
      _onConnectionChanged();
    } catch (_) {
      if (_current(generation)) await end(WatchVoiceEndReason.failed);
    }
  }

  void _onConnectionChanged() {
    if (_disposed || !_owned || _switching) return;
    switch (transport.connectionState.value) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _timer?.cancel();
        _phase(WatchVoicePhase.connected);
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        if (value != WatchVoicePhase.reconnecting) {
          _phase(WatchVoicePhase.reconnecting);
          _armTimer(reconnectTimeout, _generation);
        }
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        unawaited(end(WatchVoiceEndReason.failed));
      default:
        break;
    }
  }

  void mute(bool muted) {
    if (!_owned || _disposed) return;
    _muted = muted;
    transport.mute(muted);
  }

  void _detachRoom() {
    _roomGeneration++;
    final room = _roomSubscription;
    final incoming = _incomingSubscription;
    _roomSubscription = null;
    _incomingSubscription = null;
    if (room != null) unawaited(room.cancel());
    if (incoming != null) unawaited(incoming.cancel());
  }

  Future<void> end([
    WatchVoiceEndReason reason = WatchVoiceEndReason.local,
  ]) async {
    final pending = _cleanup;
    if (pending != null) return pending;
    if (!_owned) return;
    _generation++;
    _owned = false;
    _timer?.cancel();
    _detachRoom();
    transport.connectionState.removeListener(_onConnectionChanged);
    _phase(WatchVoicePhase.ending);
    final cleanup = _finish(reason);
    _cleanup = cleanup;
    try {
      await cleanup;
    } finally {
      if (identical(_cleanup, cleanup)) _cleanup = null;
    }
  }

  Future<void> _finish(WatchVoiceEndReason reason) async {
    try {
      await transport.hangUp();
    } catch (_) {
      // UI vẫn trở về trạng thái có thể gọi lại khi ghi ended bị lỗi mạng.
      reason = WatchVoiceEndReason.failed;
    } finally {
      _roomId = null;
      _outgoing = false;
      _switching = false;
      _muted = false;
      _phase(WatchVoicePhase.idle);
      if (!_disposed) onEnded?.call(reason);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(end());
    super.dispose();
  }
}
