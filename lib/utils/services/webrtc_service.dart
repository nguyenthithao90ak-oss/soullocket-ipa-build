import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'couple_call_signaling.dart';
import 'call_setup_failure.dart';
import 'call_media_session.dart';
import 'call_connection_quality.dart';
import 'call_ice_candidates.dart';
import 'call_ice_config_cache.dart';
import 'call_ice_recovery.dart';

/// Tách stream trước khi giải phóng renderer, kể cả khi chưa khởi tạo xong.
/// Lỗi Surface chưa từng nhận frame được vá riêng trong Android build.
Future<void> disposeVideoRendererSafely(RTCVideoRenderer renderer) async {
  final pending = <Future<void>>[];
  Future<void> waitNative(Future<void> operation) async {
    final guarded = operation.catchError((Object error) {
      debugPrint(
        'WebRTC renderer release failed: ${AppErrorMapper.resolve(error).message}',
      );
    });
    pending.add(guarded);
    await guarded.timeout(const Duration(seconds: 5));
  }

  try {
    if (kIsWeb || renderer.textureId != null) {
      await waitNative(renderer.setSrcObject(stream: null));
    }
  } catch (error) {
    debugPrint(
      'WebRTC renderer detach skipped: ${AppErrorMapper.resolve(error).message}',
    );
  }
  try {
    await waitNative(renderer.dispose());
  } catch (error) {
    debugPrint(
      'WebRTC renderer dispose failed: ${AppErrorMapper.resolve(error).message}',
    );
  }
  await Future.wait(pending);
}

/// ============================================================
///  WebRTCService — Gra (Logic/Data)
///  Hệ thống Đàm thoại Video/Audio Peer-to-Peer (Phase 4)
///
///  Chức năng:
///  1. Tạo luồng (MediaStream) lấy Camera + Mic.
///  2. Bắt tay (Signaling) kết nối 2 điện thoại qua Firebase.
///  3. Tối ưu hóa WebRTC DataChannel / IceCandidate.
/// ============================================================
class WebRTCService with WidgetsBindingObserver {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal()
    : _db = FirebaseDatabase.instance,
      _auth = FirebaseAuth.instance,
      _onPeerCreated = null {
    var observedUid = _auth.currentUser?.uid;
    _auth.authStateChanges().listen((user) {
      if (user?.uid == observedUid) return;
      observedUid = user?.uid;
      _iceConfigCache.clear();
      if (_activeUid != null && user?.uid != _activeUid) {
        unawaited(hangUp());
      }
    });
  }

  @visibleForTesting
  WebRTCService.testInstance(this._db, this._auth, [this._onPeerCreated]);

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  CallMediaSession? _mediaSession;
  CallMediaSession? get mediaSession => _mediaSession;
  final mediaSessionState = ValueNotifier<CallMediaSession?>(null);
  MediaStream? get localStream => _localStream;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;
  final void Function(RTCPeerConnection)? _onPeerCreated;
  String? _roomId; // ID của phòng gọi (giống houseId)
  String? _coupleHouseId;
  CallIceCandidates? _remoteCandidates;
  RtcCandidateQueue<Map<String, dynamic>>? _localCandidates;
  final _iceConfigCache = CallIceConfigCache();
  String? _activeUid;
  int _localIceGeneration = 0;
  CallIceRecovery? _recovery;
  CallQualityMonitor? _qualityMonitor;
  StreamSubscription<DatabaseEvent>? _recoverySub;
  StreamSubscription<DatabaseEvent>? _recoveryStatusSub;
  StreamSubscription<List<ConnectivityResult>>? _networkSub;
  Future<void> Function()? _resumeNetworkCheck;
  final connectionQuality = ValueNotifier<CallConnectionQuality?>(null);
  int _session = 0;
  bool _callReserved = false;
  bool _openingMedia = false;
  Future<void>? _hangUpOperation;
  Future<void>? _speakerOperation;
  Future<void>? _cameraSwitchOperation;
  final connectionState = ValueNotifier<RTCPeerConnectionState?>(null);
  bool get isBusy =>
      _localStream != null ||
      _peerConnection != null ||
      _callReserved ||
      _openingMedia ||
      _hangUpOperation != null;

  /// Giữ chỗ ngay khi mở màn gọi, trước hộp thoại quyền micro/camera.
  void reserveCall() {
    if (isBusy) throw const CallSetupFailure('setup', 'busy');
    _callReserved = true;
    unawaited(preloadRtcConfiguration());
  }

  void _checkSession(int session) {
    if (session != _session) {
      throw const CallSetupFailure('setup', 'cancelled');
    }
  }

  // ⚡ Lưu StreamSubscription để cancel khi hangUp, tránh listener leak
  StreamSubscription<DatabaseEvent>? _answerSub;
  StreamSubscription<DatabaseEvent>? _calleeCandidatesSub;
  StreamSubscription<DatabaseEvent>? _callerCandidatesSub;
  StreamSubscription<DatabaseEvent>? _incomingCallChangeSub;
  int _incomingCallGeneration = 0;
  static const int _incomingCallQueryLimit = 10;

  final Map<String, dynamic> _fallbackConfiguration = {
    'iceServers': [
      {
        // Chỉ giữ một endpoint dự phòng. Năm alias tạo các lỗi UDP trùng nhau
        // trên emulator hoặc mạng chặn STUN; production có thể cấp TURN/STUN
        // qua appConfig/webrtc/iceServers hoặc dart-define.
        'urls': 'stun:stun.l.google.com:19302',
      },
    ],
  };

  Future<void> preloadRtcConfiguration() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) await _loadRtcConfiguration(uid);
    } catch (_) {
      // Preload là tùy chọn, không chặn xin quyền hoặc media trên máy.
    }
  }

  Future<Map<String, dynamic>> _loadRtcConfiguration(String uid) async {
    final fallbackServers = <Map<String, dynamic>>[
      ...(_fallbackConfiguration['iceServers'] as List)
          .cast<Map<String, dynamic>>(),
    ];
    final configuredServers = <Map<String, dynamic>>[];
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
      configuredServers.add(turnServer);
    }
    try {
      final servers = await _iceConfigCache.load(
        uid,
        () async => (await _db.ref('appConfig/webrtc/iceServers').get()).value,
      );
      if (servers.isNotEmpty) {
        return {
          // Danh sách phía server thay thế các alias dự phòng. TURN được cấp
          // rõ bằng dart-define vẫn được giữ như relay bổ sung.
          'iceServers': [...servers, ...configuredServers],
        };
      }
    } catch (e) {
      // Không che lỗi quyền/config; chỉ log mã, tuyệt đối không log TURN secret.
      debugPrint(
        'WebRTC ICE config fallback: ${CallSetupFailure.from(e, 'ice_config')}; '
        'turnConfigured=${configuredServers.isNotEmpty}',
      );
    }
    return {
      'iceServers': [...fallbackServers, ...configuredServers],
    };
  }

  /// Bật Camera và Mic
  Future<MediaStream> openUserMedia({bool includeVideo = true}) async {
    final pendingHangUp = _hangUpOperation;
    if (pendingHangUp != null) await pendingHangUp;
    final session = _session;
    _openingMedia = true;
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': includeVideo
          ? {'width': 640, 'height': 480, 'frameRate': 24, 'facingMode': 'user'}
          : false,
    };

    late final MediaStream stream;
    try {
      stream = await runCallSetupStep(
        'media',
        () => navigator.mediaDevices.getUserMedia(mediaConstraints),
      );
    } finally {
      if (session == _session) _openingMedia = false;
    }
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

  /// Dùng đúng House đích và ID phòng thật khi bật thoại ở màn xem cùng.
  /// Chỉ đọc cửa sổ lời mời của mình, không dò ID phòng chat ở nhánh calls.
  Future<({String roomId, bool outgoing})> connectOrCreateAudioRoom(
    RTCVideoRenderer remoteRenderer, {
    required String callerHouseId,
    required String targetHouseId,
  }) async {
    final session = _session;
    final uid = _auth.currentUser?.uid;
    final myHouseId = callerHouseId.trim();
    final otherHouseId = targetHouseId.trim();
    final validHouse = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (uid == null ||
        !validHouse.hasMatch(myHouseId) ||
        !validHouse.hasMatch(otherHouseId) ||
        myHouseId == otherHouseId) {
      throw const CallSetupFailure('room_read', 'invalid_target');
    }
    final offsetFuture = _readServerTimeOffset();
    final snapshot = await _db
        .ref('calls')
        .orderByChild('calleeId')
        .equalTo(myHouseId)
        .limitToLast(_incomingCallQueryLimit)
        .get()
        .timeout(const Duration(seconds: 8));
    final now = DateTime.now().millisecondsSinceEpoch + await offsetFuture;
    _checkSession(session);
    if (_auth.currentUser?.uid != uid) {
      throw const CallSetupFailure('room_read', 'unauthenticated');
    }
    final incomingRoomId = _latestIncomingAudioRoom(
      snapshot,
      uid: uid,
      myHouseId: myHouseId,
      otherHouseId: otherHouseId,
      now: now,
    );
    if (incomingRoomId != null) {
      await joinRoom(incomingRoomId, remoteRenderer);
      return (roomId: incomingRoomId, outgoing: false);
    }
    final roomId = await createRoom(
      remoteRenderer,
      targetHouseId: otherHouseId,
      callerHouseId: myHouseId,
      isVideo: false,
    );
    return (roomId: roomId, outgoing: true);
  }

  /// Listener riêng của Watch, không thay listener incoming của Home.
  /// Chỉ dùng khi người dùng đã chủ động bật thoại để giải quyết gọi chéo.
  Stream<String> watchIncomingAudioRooms({
    required String callerHouseId,
    required String targetHouseId,
  }) {
    final uid = _auth.currentUser?.uid;
    final myHouseId = callerHouseId.trim();
    final otherHouseId = targetHouseId.trim();
    final validHouse = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (uid == null ||
        !validHouse.hasMatch(myHouseId) ||
        !validHouse.hasMatch(otherHouseId) ||
        myHouseId == otherHouseId) {
      return const Stream<String>.empty();
    }
    return _db
        .ref('calls')
        .orderByChild('calleeId')
        .equalTo(myHouseId)
        .limitToLast(_incomingCallQueryLimit)
        .onValue
        .asyncMap((event) async {
          final offset = await _readServerTimeOffset();
          if (_auth.currentUser?.uid != uid) return null;
          return _latestIncomingAudioRoom(
            event.snapshot,
            uid: uid,
            myHouseId: myHouseId,
            otherHouseId: otherHouseId,
            now: DateTime.now().millisecondsSinceEpoch + offset,
          );
        })
        .where((roomId) => roomId != null)
        .cast<String>()
        .distinct();
  }

  String? _latestIncomingAudioRoom(
    DataSnapshot snapshot, {
    required String uid,
    required String myHouseId,
    required String otherHouseId,
    required int now,
  }) {
    String? incomingRoomId;
    var latestTimestamp = 0;
    for (final child in snapshot.children) {
      final room = child.value;
      final id = child.key?.trim() ?? '';
      if (room is! Map ||
          id.isEmpty ||
          RegExp(r'[.#$\[\]/]').hasMatch(id) ||
          room['status'] != 'ringing' ||
          room['houseId'] != otherHouseId ||
          room['calleeId'] != myHouseId ||
          room['callerId'] == uid ||
          room['callerId'] is! String ||
          (room['callerId'] as String).isEmpty ||
          room['isVideo'] != false ||
          !isFreshCallTimestamp(room['timestamp'], now: now)) {
        continue;
      }
      final timestamp = (room['timestamp'] as num).toInt();
      if (timestamp > latestTimestamp) {
        latestTimestamp = timestamp;
        incomingRoomId = id;
      }
    }
    return incomingRoomId;
  }

  /// Người A: Tạo phòng (Gọi người B)
  Future<String> createRoom(
    RTCVideoRenderer remoteRenderer, {
    required String targetHouseId,
    String? callerHouseId,
    bool isVideo = true,
    String callerName = '',
  }) async {
    final pendingHangUp = _hangUpOperation;
    if (pendingHangUp != null) await pendingHangUp;
    final session = _session;
    final user = _auth.currentUser;
    if (user == null) throw const UiCopyException('copy_3bbf8095e7db');
    _activeUid = user.uid;
    final configurationFuture = _loadRtcConfiguration(user.uid);

    final resolvedTargetHouseId = targetHouseId.trim();
    final resolvedCallerHouseId =
        await _resolveCallerHouseId(
          user.uid,
          preferredHouseId: callerHouseId,
        ) ??
        resolvedTargetHouseId;
    _checkSession(session);
    final configuration = await configurationFuture;
    _checkSession(session);
    final peer = await createPeerConnection(configuration);
    if (session != _session) {
      await peer.dispose();
      throw StateError(UiCopy.text('copy_f68819406a61'));
    }
    _peerConnection = peer;
    _onPeerCreated?.call(peer);
    final media = CallMediaSession();
    _mediaSession = media;
    media.bind(
      peer,
      _localStream!,
      isCurrent: () =>
          session == _session &&
          _peerConnection == peer &&
          _auth.currentUser?.uid == user.uid,
      initialRemoteVideo: isVideo,
    );
    peer.onConnectionState = (state) {
      if (_peerConnection == peer) _publishConnectionState(state);
    };
    final remoteCandidates = CallIceCandidates(peer.addCandidate);
    _remoteCandidates = remoteCandidates;

    // Gắn local stream vào peer connection
    final local = _localStream;
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      await peer.addTrack(track, local!);
      _checkSession(session);
    }

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (_peerConnection != peer) return;
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) return;
      _remoteStream = stream;
      if (kIsWeb || remoteRenderer.textureId != null) {
        unawaited(
          remoteRenderer
              .setSrcObject(stream: stream)
              .catchError(_logSignalingError),
        );
      }
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
    final localCandidates = RtcCandidateQueue<Map<String, dynamic>>((
      candidate,
    ) async {
      if (session != _session || _auth.currentUser?.uid != user.uid) return;
      await callerCandidatesRef.push().set(candidate);
    });
    _localCandidates = localCandidates;
    peer.onIceCandidate = (candidate) {
      if (session != _session ||
          _auth.currentUser?.uid != user.uid ||
          candidate.candidate?.isNotEmpty != true) {
        return;
      }
      unawaited(
        localCandidates
            .add({
              ...Map<String, dynamic>.from(candidate.toMap()),
              if (_localIceGeneration > 0) 'generation': _localIceGeneration,
            })
            .catchError(_logSignalingError),
      );
    };

    // Tạo Offer cho B
    await media.prepareOffer();
    _checkSession(session);
    mediaSessionState.value = media;
    final offer = await peer.createOffer().timeout(const Duration(seconds: 12));
    _checkSession(session);
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
    }

    // Không để setup cũ gỡ listener của cuộc gọi mới sau khi chờ thông báo.
    _checkSession(session);
    // Lắng nghe Answer từ B
    _cancelRoomSubscriptions();
    _attachConnectionTools(
      peer,
      media,
      roomRef,
      remoteCandidates,
      session: session,
      uid: user.uid,
      isCaller: true,
    );
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
                  if (session != _session ||
                      _auth.currentUser?.uid != user.uid) {
                    return;
                  }
                  await remoteCandidates.descriptionReady();
                  unawaited(_recovery?.start());
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
              remoteCandidates
                  .add(
                    candidate,
                    generation: val['generation'] is int
                        ? val['generation'] as int
                        : 0,
                  )
                  .catchError(_logSignalingError),
            );
          },
          onError: (Object error) {
            debugPrint(
              'WebRTC callee candidate listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể nhận ICE candidate phía người nghe.').message}',
            );
          },
        );

    // Push có thể phải làm mới App Check/retry. Không để tác vụ phụ này chặn
    // answer/ICE, nút điều khiển hoặc thời gian chờ của cuộc gọi.
    if (resolvedTargetHouseId == resolvedCallerHouseId) {
      unawaited(
        _notifyCoupleCall(
          session: session,
          uid: user.uid,
          houseId: resolvedCallerHouseId,
          roomId: roomId,
          callerName: callerName,
          isVideo: isVideo,
        ),
      );
    }
    return roomId;
  }

  Future<void> _notifyCoupleCall({
    required int session,
    required String uid,
    required String houseId,
    required String roomId,
    required String callerName,
    required bool isVideo,
  }) async {
    if (session != _session || _auth.currentUser?.uid != uid) return;
    try {
      await NotificationService().sendPartnerNotification(
        houseId: houseId,
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
          'houseId': houseId,
          'callerName': callerName.trim(),
          'isVideo': isVideo.toString(),
        },
        idempotencyKey: 'call_$roomId',
        throwOriginalException: true,
      );
    } catch (error) {
      // Không in payload/token hoặc làm thất bại media vì hàng đợi push.
      _logSignalingError(error);
    }
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
    final pendingHangUp = _hangUpOperation;
    if (pendingHangUp != null) await pendingHangUp;
    final session = _session;
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const CallSetupFailure('room_read', 'unauthenticated');
    }
    _activeUid = uid;
    final offsetFuture = _readServerTimeOffset();
    final roomRef = _db.ref('calls/$roomId');
    final roomSnap = await roomRef.get().timeout(const Duration(seconds: 8));
    final offset = await offsetFuture;
    _checkSession(session);
    if (_auth.currentUser?.uid != uid) {
      throw const CallSetupFailure('room_read', 'unauthenticated');
    }
    if (!roomSnap.exists) throw const UiCopyException('copy_9ee77d4b3d6f');
    final data = Map<String, dynamic>.from(roomSnap.value as Map);
    if (data['status'] != 'ringing' || data['callerId'] == uid) {
      throw StateError(UiCopy.text('copy_af1996becb05'));
    }
    if (!isFreshCallTimestamp(
      data['timestamp'],
      now: DateTime.now().millisecondsSinceEpoch + offset,
    )) {
      throw const CallSetupFailure('room_read', 'expired');
    }
    if (session != _session) throw StateError(UiCopy.text('copy_f68819406a61'));
    _roomId = roomId;
    if (data['houseId'] == data['calleeId']) {
      _coupleHouseId = data['houseId']?.toString();
    }

    final configuration = await _loadRtcConfiguration(uid);
    _checkSession(session);
    final peer = await createPeerConnection(configuration);
    if (session != _session) {
      await peer.dispose();
      throw StateError(UiCopy.text('copy_f68819406a61'));
    }
    _peerConnection = peer;
    _onPeerCreated?.call(peer);
    final media = CallMediaSession();
    _mediaSession = media;
    media.bind(
      peer,
      _localStream!,
      isCurrent: () =>
          session == _session &&
          _peerConnection == peer &&
          _auth.currentUser?.uid == uid,
      initialRemoteVideo: data['isVideo'] == true,
    );
    peer.onConnectionState = (state) {
      if (_peerConnection == peer) _publishConnectionState(state);
    };
    final remoteCandidates = CallIceCandidates(peer.addCandidate);
    _remoteCandidates = remoteCandidates;

    final local = _localStream;
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      await peer.addTrack(track, local!);
      _checkSession(session);
    }

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (_peerConnection != peer) return;
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream == null) return;
      _remoteStream = stream;
      if (kIsWeb || remoteRenderer.textureId != null) {
        unawaited(
          remoteRenderer
              .setSrcObject(stream: stream)
              .catchError(_logSignalingError),
        );
      }
    };

    final calleeCandidatesRef = roomRef.child('calleeCandidates');
    final localCandidates = RtcCandidateQueue<Map<String, dynamic>>((
      candidate,
    ) async {
      if (session != _session || _auth.currentUser?.uid != uid) return;
      await calleeCandidatesRef.push().set(candidate);
    });
    _localCandidates = localCandidates;
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (_peerConnection != peer ||
          session != _session ||
          _auth.currentUser?.uid != uid ||
          candidate.candidate?.isNotEmpty != true) {
        return;
      }
      unawaited(
        localCandidates
            .add({
              ...Map<String, dynamic>.from(candidate.toMap()),
              if (_localIceGeneration > 0) 'generation': _localIceGeneration,
            })
            .catchError(_logSignalingError),
      );
    };

    // Lấy Offer từ A và tạo Answer
    final offerData = Map<String, dynamic>.from(data['offer']);

    final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await peer.setRemoteDescription(offer).timeout(const Duration(seconds: 12));
    _checkSession(session);
    await media.prepareAnswer();
    _checkSession(session);
    mediaSessionState.value = media;
    await remoteCandidates.descriptionReady();
    _checkSession(session);

    final answer = await peer.createAnswer().timeout(
      const Duration(seconds: 12),
    );
    _checkSession(session);
    await peer.setLocalDescription(answer).timeout(const Duration(seconds: 12));

    if (session != _session) throw StateError(UiCopy.text('copy_f68819406a61'));
    // Bắt máy chỉ khi phòng vẫn đang đổ chuông; không mở lại phòng đã hủy.
    final accepted = await roomRef
        .runTransaction((current) {
          if (session != _session || _auth.currentUser?.uid != uid) {
            return Transaction.abort();
          }
          // Lần đầu cache có thể chưa có dữ liệu; để Firebase lấy lại từ server.
          if (current == null) return Transaction.success(null);
          if (current is! Map ||
              current['status'] != 'ringing' ||
              !isFreshCallTimestamp(
                current['timestamp'],
                now: DateTime.now().millisecondsSinceEpoch + offset,
              )) {
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

    await localCandidates.markReady();
    _checkSession(session);
    _attachConnectionTools(
      peer,
      media,
      roomRef,
      remoteCandidates,
      session: session,
      uid: uid,
      isCaller: false,
    );
    unawaited(_recovery?.start());

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
              remoteCandidates
                  .add(
                    candidate,
                    generation: val['generation'] is int
                        ? val['generation'] as int
                        : 0,
                  )
                  .catchError(_logSignalingError),
            );
          },
          onError: (Object error) {
            debugPrint(
              'WebRTC caller candidate listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể nhận ICE candidate phía người gọi.').message}',
            );
          },
        );
  }

  void _publishConnectionState(RTCPeerConnectionState state) {
    _recovery?.stateChanged(state);
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _qualityMonitor?.start();
    }
    connectionState.value =
        state == RTCPeerConnectionState.RTCPeerConnectionStateFailed &&
            _recovery?.isRecovering == true
        ? RTCPeerConnectionState.RTCPeerConnectionStateDisconnected
        : state;
  }

  void _attachConnectionTools(
    RTCPeerConnection peer,
    CallMediaSession media,
    DatabaseReference room,
    CallIceCandidates candidates, {
    required int session,
    required String uid,
    required bool isCaller,
  }) {
    bool isCurrent() =>
        session == _session &&
        _peerConnection == peer &&
        _roomId == room.key &&
        _auth.currentUser?.uid == uid;
    final adaptation = CallVideoAdaptation();
    _qualityMonitor = CallQualityMonitor(
      read: peer.getStats,
      isCurrent: isCurrent,
      onSample: (stats) async {
        if (!isCurrent()) return;
        connectionQuality.value = stats;
        await media.setVideoQuality(adaptation.update(stats));
      },
    );
    final recoveryRef = room.child('recovery');
    final recovery = CallIceRecovery(
      peer: peer,
      isCaller: isCaller,
      isCurrent: isCurrent,
      prepareRestart: () async {
        final configuration = await _loadRtcConfiguration(uid);
        if (isCurrent()) await peer.setConfiguration(configuration);
      },
      write: (changes) async {
        if (isCurrent()) await recoveryRef.update(changes);
      },
      onLocalGeneration: (generation) {
        if (isCurrent()) _localIceGeneration = generation;
      },
      onRemoteGeneration: candidates.descriptionReady,
      onRecovering: (recovering) {
        if (!isCurrent()) return;
        if (recovering &&
            peer.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          return;
        }
        connectionState.value = recovering
            ? RTCPeerConnectionState.RTCPeerConnectionStateDisconnected
            : peer.connectionState;
      },
      onFailure: () {
        if (isCurrent()) {
          connectionState.value =
              RTCPeerConnectionState.RTCPeerConnectionStateFailed;
        }
      },
    );
    _recovery = recovery;
    _recoverySub = recoveryRef.onValue.listen((event) {
      if (isCurrent()) recovery.receive(event.snapshot.value);
    }, onError: (Object _) => recovery.close());
    _recoveryStatusSub = room.child('status').onValue.listen((event) {
      if (!isCurrent()) return;
      if (event.snapshot.value == 'ended' || event.snapshot.value == null) {
        recovery.close();
        _qualityMonitor?.close();
      }
    }, onError: (Object _) => recovery.close());

    String? lastNetwork;
    var offline = false;
    var events = 0;
    void observeNetwork(List<ConnectivityResult> results) {
      if (!isCurrent()) return;
      final usable =
          results
              .where((r) => r != ConnectivityResult.none)
              .map((r) => r.name)
              .toList()
            ..sort();
      if (usable.isEmpty) {
        offline = true;
        return;
      }
      final key = usable.join(',');
      final changed = offline || (lastNetwork != null && key != lastNetwork);
      lastNetwork = key;
      offline = false;
      if (changed) recovery.networkChanged();
    }

    Future<void> checkNetwork() async {
      final before = events;
      try {
        final results = await Connectivity().checkConnectivity();
        if (before == events) observeNetwork(results);
      } catch (_) {
        // Plugin không có mặt/mạng chưa sẵn sàng vẫn có ICE state làm dự phòng.
      }
    }

    _networkSub = Connectivity().onConnectivityChanged.listen((results) {
      events++;
      observeNetwork(results);
    }, onError: (Object _) {});
    _resumeNetworkCheck = checkNetwork;
    WidgetsBinding.instance.addObserver(this);
    unawaited(checkNetwork());
    final state = peer.connectionState;
    if (state != null) _publishConnectionState(state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final check = _resumeNetworkCheck;
      if (check != null) unawaited(check());
    }
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
  Future<void> hangUp({
    Future<void> Function()? beforeMediaRelease,
    bool keepReservation = false,
  }) async {
    final pending = _hangUpOperation;
    if (pending != null) {
      // Dừng/dispose trong lúc chuyển phòng phải hủy cả chỗ đang được giữ.
      if (!keepReservation) _callReserved = false;
      await pending;
      return;
    }
    final operation = _hangUpInternal(
      beforeMediaRelease,
      keepReservation: keepReservation,
    );
    _hangUpOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_hangUpOperation, operation)) {
        _hangUpOperation = null;
      }
    }
  }

  Future<void> _hangUpInternal(
    Future<void> Function()? beforeMediaRelease, {
    required bool keepReservation,
  }) async {
    _session++;
    _callReserved = keepReservation;
    _openingMedia = false;
    final endedRoomId = _roomId;
    final endedUid = endedRoomId == null ? null : _activeUid;
    final coupleHouseId = _coupleHouseId;
    final local = _localStream;
    final remote = _remoteStream;
    final peer = _peerConnection;
    final media = _mediaSession;
    final recovery = _recovery;
    recovery?.close();
    _recovery = null;
    _qualityMonitor?.close();
    _qualityMonitor = null;
    _recoverySub?.cancel();
    _recoverySub = null;
    _recoveryStatusSub?.cancel();
    _recoveryStatusSub = null;
    _networkSub?.cancel();
    _networkSub = null;
    _resumeNetworkCheck = null;
    WidgetsBinding.instance.removeObserver(this);
    _activeUid = null;
    _localIceGeneration = 0;
    connectionQuality.value = null;
    // Dừng phát tiếng/hình đồng bộ trước mọi await (renderer hoặc native có
    // thể trả chậm). Reservation vẫn giữ đến khi cleanup thực sự hoàn tất.
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        track.enabled = false;
      } catch (error) {
        _logSignalingError(error);
      }
    }
    _mediaSession = null;
    mediaSessionState.value = null;
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
    if (endedRoomId != null && endedUid != null) {
      // Báo phía kia ngay, độc lập với thời gian native đóng camera/renderer.
      unawaited(_finishEndedRoom(endedRoomId, coupleHouseId, endedUid));
    }
    final nativeReleases = <Future<void>>[
      if (_speakerOperation != null)
        _speakerOperation!.catchError(_logSignalingError),
      if (_cameraSwitchOperation != null)
        _cameraSwitchOperation!.catchError(_logSignalingError),
    ];
    Future<void> releaseNative(
      Future<void> Function() release, {
      Duration timeout = const Duration(seconds: 5),
    }) async {
      final operation = Future<void>.sync(
        release,
      ).catchError(_logSignalingError);
      nativeReleases.add(operation);
      try {
        await operation.timeout(timeout);
      } catch (error) {
        // Tiếp tục dọn tài nguyên khác, nhưng giữ busy đến khi native gốc trả
        // về; timeout không phải bằng chứng micro/camera đã được giải phóng.
        _logSignalingError(error);
      }
    }

    // Phiên đã bị vô hiệu hóa đồng bộ; mọi setup/onTrack tới muộn bị bỏ qua.
    // Tách renderer trước khi đóng media, tránh track đã dispose còn gắn vào UI.
    if (beforeMediaRelease != null) {
      await releaseNative(
        beforeMediaRelease,
        timeout: const Duration(seconds: 8),
      );
    }
    // Luôn nhả micro/camera dù ghi trạng thái lên mạng thất bại.
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      await releaseNative(track.stop);
    }
    for (final release in <Future<void> Function()>[
      if (media != null) media.close,
      if (media != null) media.waitUntilIdle,
      if (peer != null) peer.close,
      if (peer != null) peer.dispose,
      if (recovery != null) recovery.waitUntilIdle,
      if (local != null) local.dispose,
      if (remote != null) remote.dispose,
    ]) {
      await releaseNative(release);
    }
    await Future.wait(nativeReleases);
  }

  Future<void> _finishEndedRoom(
    String endedRoomId,
    String? coupleHouseId,
    String endedUid,
  ) async {
    if (_auth.currentUser?.uid != endedUid) return;
    try {
      final roomRef = _db.ref('calls/$endedRoomId');
      final room = await roomRef.get().timeout(const Duration(seconds: 8));
      if (_auth.currentUser?.uid != endedUid) return;
      if (room.exists) {
        await roomRef
            .update({'status': 'ended', 'endedAt': ServerValue.timestamp})
            .timeout(const Duration(seconds: 8));
      }
      if (coupleHouseId != null && _auth.currentUser?.uid == endedUid) {
        await _clearCoupleInvite(coupleHouseId, endedRoomId);
      }
    } catch (error) {
      _logSignalingError(error);
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

  Future<int> _readServerTimeOffset() async {
    try {
      final event = await _db
          .ref('.info/serverTimeOffset')
          .onValue
          .where((event) {
            final value = event.snapshot.value;
            return value is num && value.isFinite;
          })
          .timeout(const Duration(seconds: 2))
          .first;
      return (event.snapshot.value as num).round();
    } catch (_) {
      // Khi offline/chưa có offset, vẫn chặn lời mời cũ bằng giờ thiết bị.
      return 0;
    }
  }

  Stream<Map<String, dynamic>> watchIncomingCoupleCalls(String houseId) {
    final uid = _auth.currentUser?.uid ?? '';
    return _db
        .ref(CoupleCallInvite.inboxPath(houseId))
        .onValue
        .asyncMap((event) async {
          if (event.snapshot.value == null) return null;
          final serverOffset = await _readServerTimeOffset();
          final invite = CoupleCallInvite.incoming(
            event.snapshot.value,
            houseId: houseId,
            uid: uid,
            now: DateTime.now().millisecondsSinceEpoch + serverOffset,
          );
          if (invite == null || _auth.currentUser?.uid != uid || isBusy) {
            return null;
          }
          final snap = await _db
              .ref('calls/${invite.roomId}')
              .get()
              .timeout(const Duration(seconds: 8));
          final deviceNow = DateTime.now().millisecondsSinceEpoch;
          final expiresAt = localCallExpiresAt(
            invite.timestamp,
            serverNow: deviceNow + serverOffset,
            deviceNow: deviceNow,
          );
          if (!invite.matchesRingingRoom(snap.value) ||
              expiresAt == null ||
              expiresAt <= deviceNow ||
              _auth.currentUser?.uid != uid ||
              isBusy) {
            return null;
          }
          return <String, dynamic>{
            ...Map<String, dynamic>.from(snap.value as Map),
            'roomId': invite.roomId,
            'localExpiresAt': expiresAt,
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
    final previous = _cameraSwitchOperation;
    final session = _session;
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // Không giữ khóa nếu lần chuyển trước gặp lỗi native.
        }
      }
      _checkSession(session);
      final videoTracks =
          _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
      if (videoTracks.isEmpty) return;
      await Helper.switchCamera(videoTracks.first);
      _checkSession(session);
    }();
    _cameraSwitchOperation = operation;
    unawaited(
      operation.then(
        (_) {
          if (identical(_cameraSwitchOperation, operation)) {
            _cameraSwitchOperation = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_cameraSwitchOperation, operation)) {
            _cameraSwitchOperation = null;
          }
        },
      ),
    );
    await operation.timeout(const Duration(seconds: 5));
  }

  /// Bật/Tắt loa ngoài (Speakerphone)
  Future<void> toggleSpeaker(bool isSpeakerOn) {
    final previous = _speakerOperation;
    final session = _session;
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // Một thao tác lỗi không làm kẹt các lần chọn loa tiếp theo.
        }
      }
      _checkSession(session);
      await Helper.setSpeakerphoneOn(isSpeakerOn);
      _checkSession(session);
    }();
    _speakerOperation = operation;
    unawaited(
      operation.then(
        (_) {
          if (identical(_speakerOperation, operation)) _speakerOperation = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_speakerOperation, operation)) _speakerOperation = null;
        },
      ),
    );
    return operation.timeout(const Duration(seconds: 5));
  }

  /// Lắng nghe cuộc gọi đến (Global Listener)
  StreamSubscription<DatabaseEvent> listenForIncomingCalls(
    String myHouseId,
    Function(String roomId, String callerId, Map data) onIncomingCall,
  ) {
    final normalizedHouseId = myHouseId.trim();
    final uid = _auth.currentUser?.uid;
    final generation = ++_incomingCallGeneration;
    if (normalizedHouseId.isEmpty || uid == null || uid.trim().isEmpty) {
      final emptySub = const Stream<DatabaseEvent>.empty().listen((_) {});
      _incomingCallChangeSub = emptySub;
      return emptySub;
    }
    final callsRef = _db
        .ref('calls')
        .orderByChild('calleeId')
        .equalTo(normalizedHouseId)
        // Giới hạn cửa sổ để không phát lại các phòng gọi cũ. Rules đã khóa
        // cùng orderBy/equalTo và `.indexOn` cho calleeId.
        .limitToLast(_incomingCallQueryLimit);
    final localExpiryByRoom = <String, int>{};

    // Chỉ giữ một subscription foreground; tránh listener childChanged bị rò
    // và tạo cảm giác giật/lag khi Home khởi tạo lại.
    _incomingCallChangeSub?.cancel();
    final incomingSub = callsRef.onChildAdded
        // Đưa phần chờ vào stream để cancel cũng loại kết quả đang xử lý.
        .asyncMap<DatabaseEvent?>((event) async {
          if (_auth.currentUser?.uid != uid ||
              generation != _incomingCallGeneration ||
              isBusy) {
            return null;
          }
          final raw = event.snapshot.value;
          if (raw is! Map) {
            return null;
          }
          final val = Map<String, dynamic>.from(raw);
          final callerUid = val['callerId']?.toString().trim() ?? '';
          final callerHouseId = val['houseId']?.toString().trim() ?? '';
          if (val['status'] != 'ringing' ||
              val['calleeId'] != normalizedHouseId ||
              callerUid.isEmpty ||
              callerUid == uid ||
              callerHouseId.isEmpty ||
              // Cuộc gọi trong cùng House có inbox riêng; bỏ bản sao legacy
              // ở `/calls` nhưng vẫn giữ đường gọi khác House.
              callerHouseId == normalizedHouseId) {
            return null;
          }
          final roomId = event.snapshot.key?.trim() ?? '';
          if (roomId.isEmpty || RegExp(r'[.#$\[\]/]').hasMatch(roomId)) {
            return null;
          }
          final offset = await _readServerTimeOffset();
          final deviceNow = DateTime.now().millisecondsSinceEpoch;
          final expiresAt = localCallExpiresAt(
            val['timestamp'],
            serverNow: deviceNow + offset,
            deviceNow: deviceNow,
          );
          // Callback có thể đang chờ giờ server khi đổi tài khoản/House hoặc gọi khác.
          if (_auth.currentUser?.uid != uid ||
              generation != _incomingCallGeneration ||
              isBusy ||
              expiresAt == null ||
              expiresAt <= deviceNow) {
            return null;
          }
          localExpiryByRoom[roomId] = expiresAt;
          return event;
        })
        .where((event) => event != null)
        .cast<DatabaseEvent>()
        .listen(
          (event) {
            final val = Map<String, dynamic>.from(event.snapshot.value as Map);
            final roomId = event.snapshot.key!.trim();
            val['localExpiresAt'] = localExpiryByRoom.remove(roomId);
            final callerId =
                val['houseId']?.toString().trim().isNotEmpty == true
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

  /// Hủy listener incoming đã tạo bởi [listenForIncomingCalls].
  /// Tăng generation trước khi cancel để kết quả đang chờ giờ server không
  /// thể gọi callback sau khi Home đổi House hoặc bị dispose.
  void stopIncomingCallListener() {
    _incomingCallGeneration++;
    final subscription = _incomingCallChangeSub;
    _incomingCallChangeSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
