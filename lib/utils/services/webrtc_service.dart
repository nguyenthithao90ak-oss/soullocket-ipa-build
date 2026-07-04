import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

/// ============================================================
///  WebRTCService — Gra (Logic/Data)
///  Hệ thống Đàm thoại Video/Audio Peer-to-Peer (Phase 4)
///
///  Chức năng:
///  1. Tạo luồng (MediaStream) lấy Camera + Mic.
///  2. Bắt tay (Signaling) kết nối 2 điện thoại qua Firebase.
///  3. Tối ưu hóa WebRTC DataChannel / IceCandidate.
/// ============================================================
class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final _db = FirebaseDatabase.instance;
  String? _roomId; // ID của phòng gọi (giống houseId)

  // ⚡ Lưu StreamSubscription để cancel khi hangUp, tránh listener leak
  StreamSubscription<DatabaseEvent>? _answerSub;
  StreamSubscription<DatabaseEvent>? _calleeCandidatesSub;
  StreamSubscription<DatabaseEvent>? _callerCandidatesSub;
  StreamSubscription<DatabaseEvent>? _incomingCallChangeSub;

  final Map<String, dynamic> _fallbackConfiguration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302'
        ]
      },
    ],
  };

  Future<Map<String, dynamic>> _loadRtcConfiguration() async {
    final iceServers = <Map<String, dynamic>>[
      ...(_fallbackConfiguration['iceServers'] as List)
          .cast<Map<String, dynamic>>(),
    ];
    final turnUrl = const String.fromEnvironment('WEBRTC_TURN_URL').trim();
    final turnUsername =
        const String.fromEnvironment('WEBRTC_TURN_USERNAME').trim();
    final turnCredential =
        const String.fromEnvironment('WEBRTC_TURN_CREDENTIAL').trim();
    if (turnUrl.isNotEmpty) {
      final turnServer = <String, dynamic>{'urls': turnUrl};
      if (turnUsername.isNotEmpty) {
        turnServer['username'] = turnUsername;
      }
      if (turnCredential.isNotEmpty) {
        turnServer['credential'] = turnCredential;
      }
      iceServers.add(turnServer);
    }
    try {
      final snap = await _db.ref('appConfig/webrtc/iceServers').get();
      final raw = snap.value;
      final servers = _parseIceServers(raw);
      if (servers.isNotEmpty) {
        return {
          'iceServers': [...servers, ...iceServers]
        };
      }
    } catch (e) {
      debugPrint(
          'Failed to load WebRTC ICE servers: ${AppErrorMapper.resolve(e).message}');
    }
    return {'iceServers': iceServers};
  }

  List<Map<String, dynamic>> _parseIceServers(dynamic raw) {
    final result = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        final server = _parseIceServer(item);
        if (server != null) result.add(server);
      }
    } else if (raw is Map) {
      for (final item in raw.values) {
        final server = _parseIceServer(item);
        if (server != null) result.add(server);
      }
    }
    return result;
  }

  Map<String, dynamic>? _parseIceServer(dynamic raw) {
    if (raw is! Map) return null;
    final urls = raw['urls'];
    if (urls is! String || urls.trim().isEmpty) return null;
    final server = <String, dynamic>{'urls': urls.trim()};
    final username = raw['username']?.toString().trim() ?? '';
    final credential = raw['credential']?.toString().trim() ?? '';
    if (username.isNotEmpty) server['username'] = username;
    if (credential.isNotEmpty) server['credential'] = credential;
    return server;
  }

  /// Bật Camera và Mic
  Future<MediaStream> openUserMedia({bool includeVideo = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': includeVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    return _localStream!;
  }

  /// Renderer để hiển thị Local Video
  Future<RTCVideoRenderer> createLocalRenderer() async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = _localStream;
    return renderer;
  }

  /// Người A: Tạo phòng (Gọi người B)
  Future<String> createRoom(
    RTCVideoRenderer remoteRenderer, {
    required String targetHouseId,
    String? callerHouseId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');

    final resolvedTargetHouseId = targetHouseId.trim();
    final resolvedCallerHouseId = await _resolveCallerHouseId(
          user.uid,
          preferredHouseId: callerHouseId,
        ) ??
        resolvedTargetHouseId;

    _peerConnection = await createPeerConnection(await _loadRtcConfiguration());

    // Gắn local stream vào peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) return;
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };

    // Firebase refs
    final roomRef = _db.ref('calls').push();
    _roomId = roomRef.key;

    final callerCandidatesRef = roomRef.child('callerCandidates');
    // Gửi ICE Candidate của A lên Firebase
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      callerCandidatesRef.push().set(candidate.toMap());
    };

    // Tạo Offer cho B
    final offer = await _peerConnection!
        .createOffer()
        .timeout(const Duration(seconds: 12));
    await _peerConnection!
        .setLocalDescription(offer)
        .timeout(const Duration(seconds: 12));

    await roomRef.set({
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
      'callerId': user.uid,
      'calleeId': resolvedTargetHouseId,
      'houseId': resolvedCallerHouseId,
      'status': 'ringing',
      'timestamp': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 12));

    // Lắng nghe Answer từ B
    _cancelRoomSubscriptions();
    _answerSub = roomRef.child('answer').onValue.listen(
      (event) async {
        final val = event.snapshot.value as Map<dynamic, dynamic>?;
        if (val != null) {
          final currentRemoteDesc =
              await _peerConnection?.getRemoteDescription();
          if (currentRemoteDesc == null) {
            final answer = RTCSessionDescription(val['sdp'], val['type']);
            await _peerConnection?.setRemoteDescription(answer);
          }
        }
      },
      onError: (Object error) {
        debugPrint(
          'WebRTC answer listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể nhận tín hiệu trả lời.',
          ).message}',
        );
      },
    );

    _calleeCandidatesSub =
        roomRef.child('calleeCandidates').onChildAdded.listen(
      (event) {
        final val = event.snapshot.value;
        if (val is! Map) return;
        final candidate = RTCIceCandidate(
          val['candidate']?.toString(),
          val['sdpMid']?.toString(),
          val['sdpMLineIndex'] as int?,
        );
        _peerConnection?.addCandidate(candidate);
      },
      onError: (Object error) {
        debugPrint(
          'WebRTC callee candidate listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể nhận ICE candidate phía người nghe.',
          ).message}',
        );
      },
    );

    return _roomId!;
  }

  /// Người B: Tham gia phòng (Bắt máy người A)
  /// Resolve caller house id for call permissions.
  Future<String?> _resolveCallerHouseId(
    String uid, {
    String? preferredHouseId,
  }) async {
    final preferred = preferredHouseId?.trim() ?? '';
    if (preferred.isNotEmpty) {
      return preferred;
    }

    try {
      final primarySnap = await _db.ref('users/$uid/houseId').get();
      final primaryValue = primarySnap.value?.toString().trim() ?? '';
      if (primaryValue.isNotEmpty) {
        return primaryValue;
      }

      final legacySnap = await _db.ref('users/$uid/house_id').get();
      final legacyValue = legacySnap.value?.toString().trim() ?? '';
      if (legacyValue.isNotEmpty) {
        return legacyValue;
      }
    } catch (e) {
      debugPrint(
          'Failed to resolve caller house id for call room: ${AppErrorMapper.resolve(e).message}');
    }

    return null;
  }

  /// Người B: Tham gia phòng (Bắt máy người A)
  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    _roomId = roomId;
    final roomRef = _db.ref('calls/$roomId');
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw Exception('Phòng gọi không tồn tại');

    _peerConnection = await createPeerConnection(await _loadRtcConfiguration());

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) return;
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };

    final calleeCandidatesRef = roomRef.child('calleeCandidates');
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      calleeCandidatesRef.push().set(candidate.toMap());
    };

    // Lấy Offer từ A và tạo Answer
    final data = Map<String, dynamic>.from(roomSnap.value as Map);
    final offerData = Map<String, dynamic>.from(data['offer']);

    final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _peerConnection
        ?.setRemoteDescription(offer)
        .timeout(const Duration(seconds: 12));

    final answer = await _peerConnection!
        .createAnswer()
        .timeout(const Duration(seconds: 12));
    await _peerConnection!
        .setLocalDescription(answer)
        .timeout(const Duration(seconds: 12));

    await roomRef.child('answer').set({
      'type': answer.type,
      'sdp': answer.sdp,
    }).timeout(const Duration(seconds: 12));
    await roomRef
        .update({'status': 'connected'}).timeout(const Duration(seconds: 8));

    // Lắng nghe ICE Candidate của A
    _callerCandidatesSub =
        roomRef.child('callerCandidates').onChildAdded.listen(
      (event) {
        final raw = event.snapshot.value;
        if (raw is! Map) return;
        final val = Map<String, dynamic>.from(raw);
        final candidate = RTCIceCandidate(
          val['candidate']?.toString(),
          val['sdpMid']?.toString(),
          val['sdpMLineIndex'] as int?,
        );
        _peerConnection?.addCandidate(candidate);
      },
      onError: (Object error) {
        debugPrint(
          'WebRTC caller candidate listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể nhận ICE candidate phía người gọi.',
          ).message}',
        );
      },
    );
  }

  /// Hủy tất cả StreamSubscription để tránh listener leak
  void _cancelRoomSubscriptions() {
    _answerSub?.cancel();
    _answerSub = null;
    _calleeCandidatesSub?.cancel();
    _calleeCandidatesSub = null;
    _callerCandidatesSub?.cancel();
    _callerCandidatesSub = null;
  }

  /// Cúp máy và dọn dẹp
  Future<void> hangUp() async {
    if (_roomId != null) {
      final endedRoomId = _roomId!;
      await _db.ref('calls/$endedRoomId').update({
        'status': 'ended',
        'endedAt': ServerValue.timestamp,
      });
      Future.delayed(const Duration(seconds: 3), () {
        _db.ref('calls/$endedRoomId').remove();
      });
    }

    _cancelRoomSubscriptions();

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _remoteStream?.dispose();

    _peerConnection?.close();
    await _peerConnection?.dispose();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _roomId = null;
  }

  /// Tắt/Mở Mic
  void toggleMic(bool isMuted) {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !isMuted;
      }
    }
  }

  /// Tắt/Mở Camera
  void toggleCamera(bool isOff) {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !isOff;
      }
    }
  }

  /// Chuyển đổi Camera (Trước/Sau)
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  /// Bật/Tắt loa ngoài (Speakerphone)
  void toggleSpeaker(bool isSpeakerOn) {
    Helper.setSpeakerphoneOn(isSpeakerOn);
  }

  /// Lắng nghe cuộc gọi đến (Global Listener)
  StreamSubscription<DatabaseEvent> listenForIncomingCalls(
    String myHouseId,
    Function(String roomId, String callerId, Map data) onIncomingCall,
  ) {
    final callsRef =
        _db.ref('calls').orderByChild('calleeId').equalTo(myHouseId);

    _incomingCallChangeSub?.cancel();
    _incomingCallChangeSub = callsRef.onChildChanged.listen((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        return;
      }
      final val = Map<String, dynamic>.from(raw);
      if (val['status'] == 'ended') {
        // Có thể trigger thư viện tắt chuông hoặc ẩn Incoming Call Screen
      }
    }, onError: (error) {
      debugPrint(
          'Error listening for incoming calls (childChanged): ${AppErrorMapper.resolve(error).message}');
    });

    return callsRef.onChildAdded.listen((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        return;
      }
      final val = Map<String, dynamic>.from(raw);
      if (val['status'] != 'ringing') {
        return;
      }
      final roomId = event.snapshot.key?.trim() ?? '';
      if (roomId.isEmpty) {
        return;
      }
      final callerId = val['houseId']?.toString().trim().isNotEmpty == true
          ? val['houseId'].toString().trim()
          : val['callerId']?.toString().trim() ?? 'Người lạ';
      onIncomingCall(roomId, callerId, val);
    }, onError: (error) {
      debugPrint(
          'Error listening for incoming calls (childAdded): ${AppErrorMapper.resolve(error).message}');
    });
  }
}
