import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final Map<String, dynamic> _fallbackConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  Future<Map<String, dynamic>> _loadRtcConfiguration() async {
    try {
      final snap = await _db.ref('appConfig/webrtc/iceServers').get();
      final raw = snap.value;
      final servers = _parseIceServers(raw);
      if (servers.isNotEmpty) {
        return {'iceServers': servers};
      }
    } catch (e) {
      debugPrint('Failed to load WebRTC ICE servers: $e');
    }
    return _fallbackConfiguration;
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
                'minWidth': '1280',
                'minHeight': '720',
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
    if (user == null) throw Exception("Chưa đăng nhập");

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
    final offer = await _peerConnection?.createOffer();
    await _peerConnection?.setLocalDescription(offer!);

    await roomRef.set({
      'offer': {
        'sdp': offer?.sdp,
        'type': offer?.type,
      },
      'callerId': user.uid,
      'calleeId': resolvedTargetHouseId,
      'houseId': resolvedCallerHouseId,
      'status': 'ringing',
      'timestamp': ServerValue.timestamp,
    });

    // Lắng nghe Answer từ B
    roomRef.child('answer').onValue.listen((event) async {
      final val = event.snapshot.value as Map<dynamic, dynamic>?;
      if (val != null) {
        final currentRemoteDesc = await _peerConnection?.getRemoteDescription();
        if (currentRemoteDesc == null) {
          final answer = RTCSessionDescription(val['sdp'], val['type']);
          await _peerConnection?.setRemoteDescription(answer);
        }
      }
    });

    roomRef.child('calleeCandidates').onChildAdded.listen((event) {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final candidate = RTCIceCandidate(
        val['candidate']?.toString(),
        val['sdpMid']?.toString(),
        val['sdpMLineIndex'] as int?,
      );
      _peerConnection?.addCandidate(candidate);
    });

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
      debugPrint('Failed to resolve caller house id for call room: $e');
    }

    return null;
  }

  /// Người B: Tham gia phòng (Bắt máy người A)
  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    _roomId = roomId;
    final roomRef = _db.ref('calls/$roomId');
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw Exception("Phòng gọi không tồn tại");

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
    await _peerConnection?.setRemoteDescription(offer);

    final answer = await _peerConnection?.createAnswer();
    await _peerConnection?.setLocalDescription(answer!);

    await roomRef.child('answer').set({
      'type': answer?.type,
      'sdp': answer?.sdp,
    });
    await roomRef.update({'status': 'connected'});

    // Lắng nghe ICE Candidate của A
    roomRef.child('callerCandidates').onChildAdded.listen((event) {
      final val = Map<String, dynamic>.from(event.snapshot.value as Map);
      final candidate = RTCIceCandidate(
          val['candidate'], val['sdpMid'], val['sdpMLineIndex']);
      _peerConnection?.addCandidate(candidate);
    });
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
  void listenForIncomingCalls(String myHouseId,
      Function(String roomId, String callerId, Map data) onIncomingCall) {
    try {
      _db
          .ref('calls')
          .orderByChild('calleeId')
          .equalTo(myHouseId)
          .onChildAdded
          .listen((event) {
        final val = event.snapshot.value as Map<dynamic, dynamic>?;
        if (val != null && val['status'] == 'ringing') {
          final roomId = event.snapshot.key;
          final callerId = val['callerId']?.toString() ?? 'Người lạ';
          if (roomId != null) {
            onIncomingCall(roomId, callerId, Map<String, dynamic>.from(val));
          }
        }
      }, onError: (error) {
        debugPrint('Error listening for incoming calls (childAdded): $error');
      });

      // Lắng nghe thay đổi trạng thái cuộc gọi (VD: người gọi đã cúp máy)
      _db
          .ref('calls')
          .orderByChild('calleeId')
          .equalTo(myHouseId)
          .onChildChanged
          .listen((event) {
        final val = event.snapshot.value as Map<dynamic, dynamic>?;
        if (val != null && val['status'] == 'ended') {
          // Có thể trigger thư viện tắt chuông hoặc ẩn Incoming Call Screen
        }
      }, onError: (error) {
        debugPrint('Error listening for incoming calls (childChanged): $error');
      });
    } catch (e) {
      debugPrint('Failed to attach global incoming call listener: $e');
    }
  }
}
