import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_camera_effects.dart';
import 'call_connection_quality.dart';

/// Dành sẵn đường video trong SDP nhưng chỉ xin camera khi chính người dùng bật.
/// Hai đầu dùng data channel để báo trạng thái; không đổi loại lời mời/phòng.
class CallMediaSession {
  CallMediaSession({
    CallCameraEffects? effects,
    Future<MediaStream> Function(Map<String, dynamic>)? capture,
  }) : _effects = effects ?? CallCameraEffects(),
       _capture = capture ?? navigator.mediaDevices.getUserMedia;

  final CallCameraEffects _effects;
  final Future<MediaStream> Function(Map<String, dynamic>) _capture;
  final cameraEnabled = ValueNotifier(false);
  final remoteCameraEnabled = ValueNotifier(false);
  RTCPeerConnection? _peer;
  RTCRtpSender? _videoSender;
  MediaStream? _local;
  MediaStream? _cameraStream;
  RTCDataChannel? _channel;
  bool Function()? _isCurrent;
  bool _closed = false;
  Future<bool>? _cameraChange;
  Future<MediaStream>? _capturePending;
  Future<void>? _qualityChange;
  CallVideoQuality _desiredQuality = CallVideoQuality.medium;
  CallVideoQuality? _appliedQuality;
  double skinBrightening = 0;

  bool get supportsBeauty => _effects.isSupported;
  bool get _alive => !_closed && (_isCurrent?.call() ?? false);

  void bind(
    RTCPeerConnection peer,
    MediaStream local, {
    required bool Function() isCurrent,
    required bool initialRemoteVideo,
  }) {
    _peer = peer;
    _local = local;
    _isCurrent = isCurrent;
    cameraEnabled.value = local.getVideoTracks().any((t) => t.enabled);
    remoteCameraEnabled.value = initialRemoteVideo;
    peer.onDataChannel = (channel) {
      if (_alive && channel.label == 'soullocket-media') _bindChannel(channel);
    };
  }

  Future<void> prepareOffer() async {
    final peer = _peer!;
    final senders = await peer.getSenders();
    _checkCurrent();
    for (final sender in senders) {
      if (sender.track?.kind == 'video') _videoSender = sender;
    }
    if (_videoSender == null) {
      final transceiver = await peer.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendRecv,
          streams: [_local!],
        ),
      );
      _checkCurrent();
      _videoSender = transceiver.sender;
    }
    final channel = await peer.createDataChannel(
      'soullocket-media',
      RTCDataChannelInit(),
    );
    if (!_alive) {
      await channel.close();
      _checkCurrent();
    }
    _bindChannel(channel);
    unawaited(setVideoQuality(_desiredQuality));
  }

  Future<void> prepareAnswer() async {
    final transceivers = await _peer!.getTransceivers();
    _checkCurrent();
    for (final transceiver in transceivers) {
      if (transceiver.receiver.track?.kind == 'video' ||
          transceiver.sender.track?.kind == 'video') {
        await transceiver.setDirection(TransceiverDirection.SendRecv);
        _checkCurrent();
        await transceiver.sender.setStreams([_local!]);
        _checkCurrent();
        _videoSender = transceiver.sender;
        unawaited(setVideoQuality(_desiredQuality));
        break;
      }
    }
  }

  void _bindChannel(RTCDataChannel channel) {
    _channel = channel;
    channel.onDataChannelState = (state) {
      if (_alive && state == RTCDataChannelState.RTCDataChannelOpen) {
        unawaited(_sendState());
      }
    };
    channel.onMessage = (message) {
      if (!_alive || message.isBinary || message.text.length > 256) return;
      try {
        final data = jsonDecode(message.text);
        if (data is Map &&
            data['type'] == 'camera' &&
            data['enabled'] is bool) {
          remoteCameraEnabled.value = data['enabled'] as bool;
        }
      } on FormatException {
        // Không dùng nội dung tùy ý của peer làm lệnh hoặc dữ liệu UI.
      }
    };
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      unawaited(_sendState());
    }
  }

  Future<void> _sendState() async {
    final channel = _channel;
    if (!_alive || channel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    try {
      await channel!.send(
        RTCDataChannelMessage(
          jsonEncode({'type': 'camera', 'enabled': cameraEnabled.value}),
        ),
      );
    } catch (_) {
      // Đóng data channel không được làm gián đoạn phần thoại.
    }
  }

  Future<bool> setCameraEnabled(bool enabled) {
    final pending = _cameraChange;
    if (pending != null) return pending;
    final operation = _changeCamera(enabled);
    _cameraChange = operation;
    return operation.whenComplete(() {
      if (identical(_cameraChange, operation)) _cameraChange = null;
    });
  }

  Future<bool> _changeCamera(bool enabled) async {
    _checkCurrent();
    if (enabled == cameraEnabled.value) return enabled;
    final sender = _videoSender;
    final local = _local!;
    if (sender == null) {
      throw UnsupportedError('call_video_upgrade_unavailable');
    }
    if (!enabled) {
      final tracks = local.getVideoTracks();
      // Chặn phát hình ngay, kể cả khi peer vừa mất kết nối.
      for (final track in tracks) {
        track.enabled = false;
      }
      try {
        await sender.replaceTrack(null);
      } catch (_) {
        // Sender lỗi vẫn phải dừng thu hình thay vì giữ camera đang bật.
      }
      // Không kiểm tra phiên ở đây: cúp máy có thể đã đánh dấu phiên cũ,
      // nhưng các track vừa xin vẫn phải được tháo khỏi stream local.
      await _clearEffects();
      for (final track in tracks) {
        try {
          await local.removeTrack(track);
        } catch (_) {
          // Stream có thể đã được giải phóng đồng thời trong lúc cúp máy.
        }
        try {
          await track.stop();
        } catch (_) {
          // Một track đã dừng không được ngăn các track còn lại được dọn.
        }
      }
      final camera = _cameraStream;
      _cameraStream = null;
      try {
        await camera?.dispose();
      } catch (_) {
        // MediaStream có thể đã được hangUp giải phóng trước đó.
      }
      cameraEnabled.value = false;
      if (_alive) await _sendState();
      return false;
    }

    if (_capturePending != null) throw StateError('call_camera_pending');
    var abandoned = false;
    final capture =
        _capture({
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': 640,
            'height': 480,
            'frameRate': 24,
          },
        }).then((stream) async {
          if (abandoned || !_alive) {
            await _releaseCapture(stream);
            throw StateError('call_media_cancelled');
          }
          return stream;
        });
    _capturePending = capture;
    unawaited(
      capture.then(
        (_) {
          if (identical(_capturePending, capture)) _capturePending = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_capturePending, capture)) _capturePending = null;
        },
      ),
    );
    late final MediaStream captured;
    try {
      captured = await capture.timeout(const Duration(seconds: 15));
    } catch (_) {
      // Future native không hủy được; nếu trả về muộn vẫn phải nhả camera.
      abandoned = true;
      rethrow;
    }
    final tracks = captured.getVideoTracks();
    try {
      _checkCurrent();
      if (tracks.isEmpty) throw StateError('camera_track_missing');
      final track = tracks.first;
      await local.addTrack(track);
      _checkCurrent();
      if (skinBrightening > 0) {
        await _effects.setSkinBrightening(track.id!, skinBrightening);
        _checkCurrent();
      }
      await sender.replaceTrack(track);
      _checkCurrent();
      _appliedQuality = null;
      unawaited(setVideoQuality(_desiredQuality));
      _cameraStream = captured;
      cameraEnabled.value = true;
      await _sendState();
      return true;
    } catch (_) {
      if (_alive) {
        try {
          await sender.replaceTrack(null);
        } catch (_) {
          // Vẫn dừng phần thu hình dù sender đã đóng/lỗi.
        }
      }
      for (final track in tracks) {
        try {
          await local.removeTrack(track);
        } catch (_) {
          // Luồng local có thể đã được giải phóng bởi hangUp.
        }
      }
      await _clearEffects();
      await _releaseCapture(captured);
      rethrow;
    }
  }

  Future<void> setSkinBrightening(double amount) async {
    _checkCurrent();
    final tracks = _local!.getVideoTracks();
    if (!cameraEnabled.value || tracks.isEmpty) return;
    final value = amount.clamp(0.0, 1.0);
    await _effects.setSkinBrightening(tracks.first.id!, value);
    _checkCurrent();
    skinBrightening = value;
  }

  /// Chỉ giới hạn video, giữ micro và trạng thái bật/tắt camera của người dùng.
  Future<void> setVideoQuality(CallVideoQuality quality) {
    _desiredQuality = quality;
    final pending = _qualityChange;
    if (pending != null) return pending;
    final operation = _applyVideoQuality();
    _qualityChange = operation;
    return operation.whenComplete(() {
      if (identical(_qualityChange, operation)) _qualityChange = null;
    });
  }

  Future<void> _applyVideoQuality() async {
    while (_alive && _desiredQuality != _appliedQuality) {
      final boundSender = _videoSender;
      if (boundSender == null || boundSender.track?.kind != 'video') return;
      final quality = _desiredQuality;
      try {
        // Native sender giữ snapshot parameters từ trước khi có SDP. Đọc lại
        // đúng sender để lấy encoding/transaction hiện tại sau thương lượng.
        final senders = await _peer!.getSenders();
        if (!_alive) return;
        RTCRtpSender? sender;
        for (final item in senders) {
          if (item.senderId == boundSender.senderId) sender = item;
        }
        if (sender == null || sender.track?.kind != 'video') return;
        final base = sender.parameters;
        final encodings = base.encodings;
        // Không tự tạo encoding/SSRC nếu nền tảng chưa thương lượng xong.
        if (encodings == null || encodings.isEmpty) return;
        final (bitrate, fps, scale) = switch (quality) {
          CallVideoQuality.low => (180000, 12, 2.0),
          CallVideoQuality.medium => (500000, 20, 1.0),
          CallVideoQuality.high => (1000000, 24, 1.0),
        };
        final updated = RTCRtpParameters(
          transactionId: base.transactionId,
          rtcp: base.rtcp,
          headerExtensions: base.headerExtensions,
          codecs: base.codecs,
          degradationPreference: base.degradationPreference,
          encodings: encodings.map((encoding) {
            final copy = RTCRtpEncoding.fromMap(encoding.toMap());
            copy.maxBitrate = bitrate;
            copy.maxFramerate = fps;
            copy.scaleResolutionDownBy = scale;
            if (copy.minBitrate != null && copy.minBitrate! > bitrate) {
              copy.minBitrate = bitrate;
            }
            return copy;
          }).toList(),
        );
        if (!_alive) return;
        final applied = await sender.setParameters(updated);
        if (!_alive || !applied) return;
        _appliedQuality = quality;
      } catch (_) {
        // Thiết bị không hỗ trợ giới hạn sender vẫn dùng congestion control gốc.
        return;
      }
    }
  }

  void _checkCurrent() {
    if (!_alive) throw StateError('call_media_cancelled');
  }

  Future<void> _clearEffects() async {
    try {
      await _effects.clear();
    } catch (_) {
      // Hiệu ứng không được ngăn thao tác tắt camera/cúp máy.
    }
  }

  Future<void> _releaseCapture(MediaStream stream) async {
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {
        // Tiếp tục nhả các track còn lại nếu một track đã dừng.
      }
    }
    try {
      await stream.dispose();
    } catch (_) {
      // Phòng có thể đã nhả stream trong khi camera còn đang khởi động.
    }
  }

  Future<void> close() async {
    _closed = true;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      channel.onMessage = null;
      channel.onDataChannelState = null;
      try {
        await channel.close();
      } catch (_) {
        // Peer đã đóng vẫn phải dọn camera và bộ lọc.
      }
    }
    await _clearEffects();
    final camera = _cameraStream;
    _cameraStream = null;
    if (camera != null) await _releaseCapture(camera);
    cameraEnabled.value = false;
    remoteCameraEnabled.value = false;
  }

  /// Service giữ reservation tới khi native cũ kết thúc; tách khỏi close để
  /// close vẫn an toàn khi được gọi ngay trong callback của replaceTrack.
  Future<void> waitUntilIdle() async {
    try {
      await _capturePending;
    } catch (_) {
      // Lượt xin camera đã bị hủy vẫn phải đợi phần nhả capture tới muộn.
    }
    try {
      await _cameraChange;
    } catch (_) {
      // Chờ replaceTrack/tắt camera thật sự kết thúc trước khi nhả reservation.
    }
    await _qualityChange;
    await _effects.waitUntilIdle();
  }
}
