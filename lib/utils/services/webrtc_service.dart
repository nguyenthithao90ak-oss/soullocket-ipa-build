import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'couple_call_signaling.dart';
import 'call_setup_failure.dart';

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
  WebRTCService._internal()
    : _db = FirebaseDatabase.instance,
      _auth = FirebaseAuth.instance,
      _onPeerCreated = null;

  @visibleForTesting
  WebRTCService.testInstance(this._db, this._auth, [this._onPeerCreated]);

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  final void Function(RTCPeerConnection)? _onPeerCreated;
  String? _roomId; // ID của phòng gọi (giống houseId)
  String? _coupleHouseId;
  RtcCandidateQueue<RTCIceCandidate>? _remoteCandidates;
  RtcCandidateQueue<RTCIceCandidate>? _localCandidates;
  int _session = 0;
  final connectionState = ValueNotifier<RTCPeerConnectionState?>(null);
  bool get isBusy => _localStream != null || _peerConnection != null;

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
          'stun:stun4.l.google.com:19302',
        ],
      },
    ],
  };

  Future<Map<String, dynamic>> _loadRtcConfiguration() async {
    final iceServers = <Map<String, dynamic>>[
      ...(_fallbackConfiguration['iceServers'] as List)
          .cast<Map<String, dynamic>>(),
    ];
    final turnUrl = const String.fromEnvironment('WEBRTC_TURN_URL').trim();
    final turnUsername = const String.fromEnvironment(
      'WEBRTC_TURN_USERNAME',
    ).trim();
    final turnCredential = const String.fromEnvironment(
      'WEBRTC_TURN_CREDENTIAL',
    ).trim();
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
      final snap = await _db
          .ref('appConfig/webrtc/iceServers')
          .get()
          .timeout(const Duration(seconds: 5));
      final raw = snap.value;
      final servers = RtcIceServers.parse(raw);
      if (servers.isNotEmpty) {
        return {
          'iceServers': [...servers, ...iceServers],
        };
      }
    } catch (e) {
      debugPrint(
        'Failed to load WebRTC ICE servers: ${AppErrorMapper.resolve(e).message}',
      );
    }
    return {'iceServers': iceServers};
  }

  /// Bật Camera và Mic
  Future<MediaStream> openUserMedia({bool includeVideo = true}) async {
    final session = _session;
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

    final stream = await runCallSetupStep(
      'media',
      () => navigator.mediaDevices.getUserMedia(mediaConstraints),
    );
    if (session != _session) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      throw StateError(UiCopy.text('copy_fdaa024832ca'));
    }
    _localStream = stream;
    return stream;
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
    bool isVideo = true,
    String callerName = '',
  }) async {
    final session = _session;
    final user = _auth.currentUser;
    if (user == null) throw const UiCopyException('copy_3bbf8095e7db');

    final resolvedTargetHouseId = targetHouseId.trim();
    final resolvedCallerHouseId =
        await _resolveCallerHouseId(
          user.uid,
          preferredHouseId: callerHouseId,
        ) ??
        resolvedTargetHouseId;

    final peer = await createPeerConnection(await _loadRtcConfiguration());
    if (session != _session) {
      await peer.dispose();
      throw StateError(UiCopy.text('copy_f68819406a61'));
    }
    _peerConnection = peer;
    _onPeerCreated?.call(peer);
    peer.onConnectionState = (state) {
      if (_peerConnection == peer) connectionState.value = state;
    };
    final remoteCandidates = RtcCandidateQueue(peer.addCandidate);
    _remoteCandidates = remoteCandidates;

    // Gắn local stream vào peer connection
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await peer.addTrack(track, _localStream!);
    }

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (_peerConnection != peer) return;
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) return;
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };

    // Firebase refs
    final roomRef = _db.ref('calls').push();
    final roomId = roomRef.key!;
    _roomId = roomId;
    if (resolvedTargetHouseId == resolvedCallerHouseId) {
      _coupleHouseId = resolvedCallerHouseId;
    }

    final callerCandidatesRef = roomRef.child('callerCandidates');
    // Gửi ICE Candidate của A lên Firebase
    final localCandidates = RtcCandidateQueue<RTCIceCandidate>(
      (candidate) => callerCandidatesRef.push().set(candidate.toMap()),
    );
    _localCandidates = localCandidates;
    peer.onIceCandidate = (candidate) => unawaited(
      localCandidates.add(candidate).catchError(_logSignalingError),
    );

    // Tạo Offer cho B
    final offer = await peer.createOffer().timeout(const Duration(seconds: 12));
    await peer.setLocalDescription(offer).timeout(const Duration(seconds: 12));
    if (session != _session || _auth.currentUser?.uid != user.uid) {
      throw StateError(UiCopy.text('copy_54e3d751d003'));
    }

    await runCallSetupStep(
      'room_write',
      () => roomRef
          .set({
            'offer': {'sdp': offer.sdp, 'type': offer.type},
            'callerId': user.uid,
            'calleeId': resolvedTargetHouseId,
            'houseId': resolvedCallerHouseId,
            'status': 'ringing',
            'timestamp': ServerValue.timestamp,
            'isVideo': isVideo,
            'callerName': callerName,
          })
          .timeout(const Duration(seconds: 12)),
    );
    if (session != _session) {
      await roomRef
          .update({'status': 'ended'})
          .timeout(const Duration(seconds: 8));
      throw StateError(UiCopy.text('copy_f68819406a61'));
    }
    await runCallSetupStep('candidate_write', localCandidates.markReady);
    if (session != _session) throw StateError(UiCopy.text('copy_f68819406a61'));
    if (resolvedTargetHouseId == resolvedCallerHouseId) {
      await runCallSetupStep(
        'invite_write',
        () => _db
            .ref(CoupleCallInvite.inboxPath(resolvedCallerHouseId))
            .set({
              'roomId': roomId,
              'houseId': resolvedCallerHouseId,
              'callerUid': user.uid,
              'callerName': callerName,
              'isVideo': isVideo,
              'timestamp': ServerValue.timestamp,
            })
            .timeout(const Duration(seconds: 8)),
      );
      if (session != _session) {
        await _clearCoupleInvite(resolvedCallerHouseId, roomId);
        throw StateError(UiCopy.text('copy_f68819406a61'));
      }

      // FCM hiển thị cuộc gọi khi thiết bị kia đang ở nền/đã khóa màn hình.
      // Nếu hàng đợi thông báo lỗi, lời mời RTDB vẫn còn để listener foreground
      // nhận được cuộc gọi và không làm hỏng việc tạo phòng WebRTC.
      try {
        await NotificationService().sendPartnerNotification(
          houseId: resolvedCallerHouseId,
          title: L10nService().translate('home_cucgin_eff0b9'),
          body: L10nService().format('home_incoming_call_from', {
            'name': callerName.trim().isEmpty
                ? L10nService().translate('home_ngigi_f1117f')
                : callerName.trim(),
          }),
          data: {
            'screen': 'soul_merge_call',
            'type': 'soul_merge_call',
            'roomId': roomId,
            'houseId': resolvedCallerHouseId,
            'callerName': callerName.trim(),
            'isVideo': isVideo.toString(),
          },
        );
      } catch (error) {
        debugPrint(
          'WebRTC call notification skipped: ${AppErrorMapper.resolve(error).message}',
        );
      }
    }

    // Lắng nghe Answer từ B
    _cancelRoomSubscriptions();
    _answerSub = roomRef
        .child('answer')
        .onValue
        .listen(
          (event) async {
            final val = event.snapshot.value as Map<dynamic, dynamic>?;
            if (val != null) {
              try {
                final currentRemoteDesc = await peer.getRemoteDescription();
                if (currentRemoteDesc == null && _peerConnection == peer) {
                  final answer = RTCSessionDescription(val['sdp'], val['type']);
                  await peer.setRemoteDescription(answer);
                  await remoteCandidates.markReady();
                }
              } catch (error) {
                _logSignalingError(error);
              }
            }
          },
          onError: (Object error) {
            debugPrint(
              'WebRTC answer listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể nhận tín hiệu trả lời.').message}',
            );
          },
        );

    _calleeCandidatesSub = roomRef
        .child('calleeCandidates')
        .onChildAdded
        .listen(
          (event) {
            final val = event.snapshot.value;
            if (val is! Map) return;
            final candidate = RTCIceCandidate(
              val['candidate']?.toString(),
              val['sdpMid']?.toString(),
              val['sdpMLineIndex'] as int?,
            );
            unawaited(
              remoteCandidates.add(candidate).catchError(_logSignalingError),
            );
          },
          onError: (Object error) {
            debugPrint(
              'WebRTC callee candidate listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể nhận ICE candidate phía người nghe.').message}',
            );
          },
        );

    return roomId;
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
        'Failed to resolve caller house id for call room: ${AppErrorMapper.resolve(e).message}',
      );
    }

    return null;
  }

  /// Người B: Tham gia phòng (Bắt máy người A)
  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    final session = _session;
    final roomRef = _db.ref('calls/$roomId');
    final roomSnap = await roomRef.get().timeout(const Duration(seconds: 8));
    if (!roomSnap.exists) throw const UiCopyException('copy_9ee77d4b3d6f');
    final data = Map<String, dynamic>.from(roomSnap.value as Map);
    if (data['status'] != 'ringing' ||
        data['callerId'] == _auth.currentUser?.uid) {
      throw StateError(UiCopy.text('copy_af1996becb05'));
    }
    if (session != _session) throw StateError(UiCopy.text('copy_f68819406a61'));
    _roomId = roomId;
    if (data['houseId'] == data['calleeId']) {
      _coupleHouseId = data['houseId']?.toString();
    }

    final peer = await createPeerConnection(await _loadRtcConfiguration());
    if (session != _session) {
      await peer.dispose();
      throw StateError(UiCopy.text('copy_f68819406a61'));
    }
    _peerConnection = peer;
    _onPeerCreated?.call(peer);
    peer.onConnectionState = (state) {
      if (_peerConnection == peer) connectionState.value = state;
    };
    final remoteCandidates = RtcCandidateQueue(peer.addCandidate);
    _remoteCandidates = remoteCandidates;

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await peer.addTrack(track, _localStream!);
    }

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (_peerConnection != peer) return;
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) return;
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };

    final calleeCandidatesRef = roomRef.child('calleeCandidates');
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      unawaited(
        calleeCandidatesRef
            .push()
            .set(candidate.toMap())
            .catchError(_logSignalingError),
      );
    };

    // Lấy Offer từ A và tạo Answer
    final offerData = Map<String, dynamic>.from(data['offer']);

    final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await peer.setRemoteDescription(offer).timeout(const Duration(seconds: 12));
    await remoteCandidates.markReady();

    final answer = await peer.createAnswer().timeout(
      const Duration(seconds: 12),
    );
    await peer.setLocalDescription(answer).timeout(const Duration(seconds: 12));

    if (session != _session) throw StateError(UiCopy.text('copy_f68819406a61'));
    // Bắt máy chỉ khi phòng vẫn đang đổ chuông; không mở lại phòng đã hủy.
    final accepted = await roomRef
        .runTransaction((current) {
          if (session != _session) return Transaction.abort();
          // Lần đầu cache có thể chưa có dữ liệu; để Firebase lấy lại từ server.
          if (current == null) return Transaction.success(null);
          if (current is! Map || current['status'] != 'ringing') {
            return Transaction.abort();
          }
          return Transaction.success({
            ...Map<String, dynamic>.from(current),
            'answer': {'type': answer.type, 'sdp': answer.sdp},
            'status': 'ongoing',
          });
        }, applyLocally: false)
        .timeout(const Duration(seconds: 12));
    final acceptedData = accepted.snapshot.value;
    if (!accepted.committed ||
        acceptedData is! Map ||
        acceptedData['status'] != 'ongoing' ||
        session != _session) {
      throw StateError(UiCopy.text('copy_af1996becb05'));
    }

    // Lắng nghe ICE Candidate của A
    _callerCandidatesSub = roomRef
        .child('callerCandidates')
        .onChildAdded
        .listen(
          (event) {
            final raw = event.snapshot.value;
            if (raw is! Map) return;
            final val = Map<String, dynamic>.from(raw);
            final candidate = RTCIceCandidate(
              val['candidate']?.toString(),
              val['sdpMid']?.toString(),
              val['sdpMLineIndex'] as int?,
            );
            unawaited(
              remoteCandidates.add(candidate).catchError(_logSignalingError),
            );
          },
          onError: (Object error) {
            debugPrint(
              'WebRTC caller candidate listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể nhận ICE candidate phía người gọi.').message}',
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
    _session++;
    final endedRoomId = _roomId;
    final coupleHouseId = _coupleHouseId;
    final local = _localStream;
    final remote = _remoteStream;
    final peer = _peerConnection;
    _roomId = null;
    _coupleHouseId = null;
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _remoteCandidates?.close();
    _remoteCandidates = null;
    _localCandidates?.close();
    _localCandidates = null;
    connectionState.value = null;
    _cancelRoomSubscriptions();
    // Luôn nhả micro/camera dù ghi trạng thái lên mạng thất bại.
    local?.getTracks().forEach((track) => track.stop());
    for (final release in <Future<void> Function()>[
      if (peer != null) peer.close,
      if (peer != null) peer.dispose,
      if (local != null) local.dispose,
      if (remote != null) remote.dispose,
    ]) {
      try {
        await release().timeout(const Duration(seconds: 5));
      } catch (error) {
        _logSignalingError(error);
      }
    }
    if (endedRoomId != null) {
      try {
        final roomRef = _db.ref('calls/$endedRoomId');
        final room = await roomRef.get().timeout(const Duration(seconds: 8));
        if (room.exists) {
          await roomRef
              .update({'status': 'ended', 'endedAt': ServerValue.timestamp})
              .timeout(const Duration(seconds: 8));
        }
        if (coupleHouseId != null) {
          await _clearCoupleInvite(coupleHouseId, endedRoomId);
        }
      } catch (error) {
        _logSignalingError(error);
      }
    }
  }

  Future<void> _clearCoupleInvite(String houseId, String roomId) => _db
      .ref(CoupleCallInvite.inboxPath(houseId))
      .runTransaction((data) {
        if (data == null) return Transaction.success(null);
        if (data is Map && data['roomId'] == roomId) {
          return Transaction.success(null);
        }
        return Transaction.abort();
      }, applyLocally: false)
      .timeout(const Duration(seconds: 8))
      .then((_) {});

  void _logSignalingError(Object error) => debugPrint(
    'WebRTC signaling: ${CallSetupFailure.from(error, 'signaling')}',
  );

  Stream<Map<String, dynamic>> watchIncomingCoupleCalls(String houseId) {
    final uid = _auth.currentUser?.uid ?? '';
    return _db
        .ref(CoupleCallInvite.inboxPath(houseId))
        .onValue
        .asyncMap((event) async {
          if (event.snapshot.value == null) return null;
          var serverOffset = 0;
          try {
            final offset = await _db
                .ref('.info/serverTimeOffset')
                .onValue
                .firstWhere((event) => event.snapshot.value is num)
                .timeout(const Duration(seconds: 2));
            serverOffset = (offset.snapshot.value as num).round();
          } catch (_) {
            // Khi chưa có offset, vẫn kiểm tra độ mới bằng đồng hồ hiện tại.
          }
          final invite = CoupleCallInvite.incoming(
            event.snapshot.value,
            houseId: houseId,
            uid: uid,
            now: DateTime.now().millisecondsSinceEpoch + serverOffset,
          );
          if (invite == null || _auth.currentUser?.uid != uid || isBusy) {
            return null;
          }
          final snap = await _db.ref('calls/${invite.roomId}').get();
          if (!invite.matchesRingingRoom(snap.value) ||
              _auth.currentUser?.uid != uid ||
              isBusy) {
            return null;
          }
          return <String, dynamic>{
            ...Map<String, dynamic>.from(snap.value as Map),
            'roomId': invite.roomId,
          };
        })
        .where((event) => event != null)
        .cast<Map<String, dynamic>>();
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
    final normalizedHouseId = myHouseId.trim();
    final callsRef = _db
        .ref('calls')
        .orderByChild('calleeId')
        .equalTo(normalizedHouseId)
        // Giới hạn cửa sổ để không phát lại các phòng gọi cũ.
        .limitToLast(10);

    // Chỉ giữ một subscription foreground; tránh listener childChanged bị rò
    // và tạo cảm giác giật/lag khi Home khởi tạo lại.
    _incomingCallChangeSub?.cancel();
    final incomingSub = callsRef.onChildAdded.listen(
      (event) {
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
            : val['callerId']?.toString().trim() ??
                  UiCopy.text('copy_0a3126b85a42');
        onIncomingCall(roomId, callerId, val);
      },
      onError: (error) {
        final msg = AppErrorMapper.resolve(error).message;
        // Rules có thể chặn listener trong thời gian chuyển tiếp; không spam
        // log và không làm UI dựng lại liên tục.
        if (!msg.contains('permission to access')) {
          debugPrint('Error listening for incoming calls: $msg');
        }
      },
    );
    _incomingCallChangeSub = incomingSub;
    return incomingSub;
  }
}
