import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/webrtc_service.dart';
import '../../utils/services/call_setup_failure.dart';
import '../../utils/services/call_media_session.dart';
import '../../utils/services/call_audio_feedback.dart';
import '../../utils/services/system_call_bridge.dart';
import '../../utils/incoming_call_payload.dart';
import 'call_surface.dart';
import 'call_beauty_sheet.dart';
import '../../utils/services/ad_suppression_guard.dart';
import '../../utils/services/purchase_service.dart';
import '../../core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String houseId;
  final String targetHouseId;
  final String targetName;
  final String? targetAvatarUrl;
  final bool isVideo;
  final String? roomId;
  final Future<void> Function(String roomId)? onRoomCreated;
  final String callerName;
  @visibleForTesting
  final WebRTCService? serviceOverride;
  @visibleForTesting
  final Future<bool> Function()? vipStatusOverride;
  @visibleForTesting
  final Duration Function()? elapsedOverride;
  @visibleForTesting
  final RTCVideoRenderer Function()? rendererFactoryOverride;

  const VideoCallScreen({
    super.key,
    required this.houseId,
    required this.targetHouseId,
    required this.targetName,
    this.targetAvatarUrl,
    this.isVideo = true,
    this.roomId,
    this.onRoomCreated,
    this.callerName = '',
    this.serviceOverride,
    this.vipStatusOverride,
    this.elapsedOverride,
    this.rendererFactoryOverride,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  late final VoidCallback _releaseSoundQuiet;
  final CallAudioFeedback _audioFeedback = CallAudioFeedback();
  late final WebRTCService _webrtcService =
      widget.serviceOverride ?? WebRTCService();
  late final RTCVideoRenderer _localRenderer =
      widget.rendererFactoryOverride?.call() ?? RTCVideoRenderer();
  late final RTCVideoRenderer _remoteRenderer =
      widget.rendererFactoryOverride?.call() ?? RTCVideoRenderer();
  bool _inCall = false;
  bool _ending = false;
  bool _endCallRequested = false;
  bool _ownsCall = false;
  Future<void>? _rendererInitialization;
  Future<void>? _cleanupFuture;
  String? _permissionError;
  bool _isPreparing = true;
  bool _localMediaReady = false;
  String? _roomId;

  // Trạng thái các nút chức năng
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _cameraBusy = false;
  bool _switchBusy = false;
  bool _speakerBusy = false;
  bool _beautyOpen = false;
  ModalBottomSheetRoute<void>? _beautyRoute;
  bool _reconnecting = false;
  bool _usingFrontCamera = true;
  CallMediaSession? _media;
  Timer? _timeoutTimer;
  Timer? _reconnectTimer;
  // ignore: unused_field
  StreamSubscription<DatabaseEvent>? _roomStatusSub;
  StreamSubscription<IncomingCallRequest>? _systemCallSub;
  bool? _systemMuted;

  // Timer + giới hạn cuộc gọi
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  int _maxCallSeconds = AppConfig.freeCallDurationMinutes * 60;
  bool _isVip = false;
  final Stopwatch _callClock = Stopwatch();
  final ValueNotifier<SoulCallStatus> _status = ValueNotifier(
    const SoulCallStatus(''),
  );

  @override
  void initState() {
    super.initState();
    _releaseSoundQuiet = SoundService().holdQuiet();
    AdSuppressionGuard.instance.suppressAds();
    _isSpeakerOn = widget.isVideo;
    _isCameraOff = !widget.isVideo;
    WidgetsBinding.instance.addObserver(this);
    _webrtcService.connectionState.addListener(_onConnectionState);
    _webrtcService.mediaSessionState.addListener(_onMediaSessionReady);
    _systemCallSub = SystemCallBridge.instance.events.listen((request) {
      if (!mounted || _ending || request.roomId != (_roomId ?? widget.roomId)) return;
      if (request.action == IncomingCallAction.end) {
        unawaited(_endCall());
      } else if (request.action == IncomingCallAction.mute) {
        _systemMuted = request.data['muted'] == true;
        _applySystemMute();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_ending) {
        if (widget.roomId != null) unawaited(SystemCallBridge.instance.setIncomingVisible(true));
        unawaited(_initRenderers());
      }
    });
    _checkVip();
  }

  Future<void> _checkVip() async {
    try {
      final isVip =
          await (widget.vipStatusOverride?.call() ?? PurchaseService().isVip());
      if (mounted) {
        _isVip = isVip;
        _maxCallSeconds =
            (isVip
                ? AppConfig.vipCallDurationMinutes
                : AppConfig.freeCallDurationMinutes) *
            60;
        _refreshCallStatus();
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/relationship/video_call_screen.dart: $error',
      );
    }
  }

  void _startElapsedTimer() {
    if (_elapsedTimer != null) return;
    _callClock.start();
    _refreshCallStatus();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _elapsedTimer?.cancel();
        return;
      }
      _updateElapsed();
    });
  }

  void _updateElapsed() {
    if (!mounted || !_inCall || _ending) return;
    // Stopwatch vẫn tính thời gian ở nền; không đếm thiếu khi timer bị hoãn.
    _elapsedSeconds =
        (widget.elapsedOverride?.call() ?? _callClock.elapsed).inSeconds;
    _refreshCallStatus();
    if (_maxCallSeconds > 0 && _elapsedSeconds >= _maxCallSeconds) {
      _elapsedTimer?.cancel();
      _showTimeUpSnack();
      unawaited(_endCall());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateElapsed();
  }

  void _refreshCallStatus() {
    if (!mounted || _ending) return;
    final text = _reconnecting
        ? context.tr('p4_call_waiting')
        : _inCall
        ? (_maxCallSeconds > 0
              ? '${_formatElapsed()} · ${_formatDuration(_remainingSeconds)}'
              : _formatElapsed())
        : context.tr(
            _isPreparing ? 'relationship_angktni_e4af2e' : 'p4_call_waiting',
          );
    final warning = _isWarning || _reconnecting;
    if (_status.value.text != text || _status.value.warning != warning) {
      _status.value = SoulCallStatus(text, warning: warning);
    }
  }

  void _showTimeUpSnack() {
    if (!mounted) return;
    final limitMin = _isVip
        ? AppConfig.vipCallDurationMinutes
        : AppConfig.freeCallDurationMinutes;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
        content: Text(
          L10nService().format('p4_call_time_up', {'minutes': limitMin}),
        ),
        backgroundColor: const Color(0xFFD81B60),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatElapsed() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get _remainingSeconds => _maxCallSeconds > 0
      ? (_maxCallSeconds - _elapsedSeconds).clamp(0, _maxCallSeconds)
      : 0;

  bool get _isWarning =>
      _maxCallSeconds > 0 &&
      _remainingSeconds > 0 &&
      _remainingSeconds <= AppConfig.callEndWarningSeconds;

  @override
  void dispose() {
    unawaited(_cleanupCall());
    unawaited(_audioFeedback.dispose());
    _status.dispose();
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    // Chuẩn bị renderer cả khi gọi thoại để nhận video mà không mở lại phòng.
    // Chưa gắn stream thì native renderer không có audio track để mute; gọi
    // setter ở đây làm Android/iOS ném lỗi trước khi cuộc gọi được tạo.
    await runCallSetupStep('renderer', _localRenderer.initialize);
    await runCallSetupStep('renderer', _remoteRenderer.initialize);
  }

  Future<void> _initRenderers() async {
    try {
      _webrtcService.reserveCall();
      _ownsCall = true;
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final microphone = await Permission.microphone.request();
        final camera = widget.isVideo
            ? await Permission.camera.request()
            : PermissionStatus.granted;
        if (!mounted || _ending) return;
        if (!microphone.isGranted || !camera.isGranted) {
          setState(() {
            _isPreparing = false;
            _permissionError = context.tr('p4_call_media_permission');
          });
          return;
        }
      }
      if (!mounted || _ending) return;
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (mounted && !_inCall && !_ending) {
          SLNotice.showError(context, context.tr('p4_call_connection_failed'));
          unawaited(_endCall());
        }
      });
      final rendererInitialization = _rendererInitialization ??=
          _initializeRenderers();
      await rendererInitialization;
      if (!mounted || _ending) return;
      if (widget.targetHouseId == 'random_stranger_id') {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _ending) return;
        setState(() {
          _inCall = true;
          _isPreparing = false;
        });
        _startElapsedTimer();
        return;
      }

      final stream = await _webrtcService.openUserMedia(
        includeVideo: widget.isVideo,
      );
      if (!mounted || _ending) {
        await _cleanupCall();
        return;
      }
      // Micro và loa chỉ phụ thuộc media trên máy, không chờ preview/signaling.
      setState(() => _localMediaReady = true);
      _applySystemMute();
      unawaited(_applyInitialSpeaker());
      if (widget.isVideo || kIsWeb) {
        await _localRenderer
            .setSrcObject(stream: stream)
            .timeout(const Duration(seconds: 5));
        // Chỉ tắt tiếng preview sau khi đã gắn stream. Với cuộc gọi thoại
        // native, renderer không cần giữ stream local nên không đụng vào nó.
        _localRenderer.muted = true;
      }
      if (!mounted || _ending) return;

      if (widget.roomId == null) {
        _roomId = await _webrtcService.createRoom(
          _remoteRenderer,
          targetHouseId: widget.targetHouseId,
          callerHouseId: widget.houseId,
          isVideo: widget.isVideo,
          callerName: widget.callerName,
        );
        if (!mounted || _ending) return;
        if (!_inCall) _audioFeedback.startRinging();
        if (widget.onRoomCreated != null && _roomId != null) {
          await widget.onRoomCreated!(_roomId!);
        }
      } else {
        _roomId = widget.roomId;
        await _webrtcService.joinRoom(widget.roomId!, _remoteRenderer);
        if (mounted && !_ending) unawaited(SystemCallBridge.instance.mediaReady(widget.roomId!));
      }

      if (!mounted || _ending) return;
      _onMediaSessionReady();
      setState(() {
        _isPreparing = false;
      });

      _refreshCallStatus();

      if (_roomId != null) {
        _roomStatusSub = FirebaseDatabase.instance
            .ref('calls/$_roomId/status')
            .onValue
            .listen(
              (event) {
                final status = event.snapshot.value as String?;
                if (status == 'ended' ||
                    status == 'declined' ||
                    status == null) {
                  if (mounted) {
                    _endCall();
                  }
                }
              },
              onError: (Object error) {
                String msg = 'relationship_khngththeo_dec6d3';
                if (mounted) msg = context.tr(msg);
                debugPrint(
                  'Video call room listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: msg).message}',
                );
              },
            );
      }
    } catch (e) {
      if (!mounted || _ending) return;
      setState(() => _isPreparing = false);
      final failure = CallSetupFailure.from(e, 'setup');
      debugPrint('Call setup: $failure');
      final msgErrorOccurred = context.tr(failure.messageKey);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SLSnackBar(content: Text(msgErrorOccurred)));
      await _endCall();
    }
  }

  void _onConnectionState() {
    if (!mounted || _ending) return;
    final state = _webrtcService.connectionState.value;
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _timeoutTimer?.cancel();
      _reconnectTimer?.cancel();
      if (_reconnecting) setState(() => _reconnecting = false);
      if (!_inCall) {
        _audioFeedback.connected();
        setState(() {
          _inCall = true;
          _isPreparing = false;
        });
        _startElapsedTimer();
      }
      _refreshCallStatus();
    } else if (state ==
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
      if (!_inCall || _reconnecting) return;
      setState(() => _reconnecting = true);
      _refreshCallStatus();
      _reconnectTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted || _ending || !_reconnecting) return;
        SLNotice.showError(context, context.tr('p4_call_connection_failed'));
        unawaited(_endCall());
      });
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
      SLNotice.showError(context, context.tr('p4_call_connection_failed'));
      unawaited(_endCall());
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshCallStatus();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_endCall());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _permissionError != null
            ? SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mic_off_rounded,
                          size: 48,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _permissionError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          child: Text(
                            context.tr('ui_map_permission_settings_fffa2a'),
                          ),
                        ),
                        TextButton(
                          onPressed: _endCall,
                          child: Text(context.tr('p4_call_end_and_back')),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _buildCallBody(),
      ),
    );
  }

  Widget _buildCallBody() {
    final media = _media;
    final remoteVideo = media?.remoteCameraEnabled.value ?? widget.isVideo;
    final controlsReady = _localMediaReady && !_ending;
    return SoulCallSurface(
      name: widget.targetName,
      avatarUrl: widget.targetAvatarUrl,
      connected: _inCall,
      status: _status.value.text,
      statusListenable: _status,
      warning: _isWarning,
      cameraOn: _localMediaReady && !_isCameraOff,
      remoteCameraOn: _inCall && remoteVideo,
      micMuted: _isMicMuted,
      speakerOn: _isSpeakerOn,
      cameraBusy: _cameraBusy,
      speakerBusy: _speakerBusy,
      switchBusy: _switchBusy,
      ending: _ending,
      beautyAmount: media?.skinBrightening ?? 0,
      onCamera: controlsReady && media != null && !_switchBusy
          ? _toggleCamera
          : null,
      onMic: controlsReady ? _toggleMic : null,
      onSpeaker: controlsReady && !_speakerBusy ? _toggleSpeaker : null,
      onSwitchCamera: controlsReady && !_cameraBusy && !_switchBusy
          ? _switchCamera
          : null,
      onBeauty: controlsReady && !_cameraBusy && !_switchBusy && !_beautyOpen
          ? _showBeauty
          : null,
      onEnd: _endCall,
      remoteVideo: RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
      localVideo: !_localMediaReady || _isCameraOff
          ? null
          : RTCVideoView(
              _localRenderer,
              mirror: _usingFrontCamera,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
    );
  }

  void _onMediaState() {
    if (!mounted || _ending) return;
    setState(() => _isCameraOff = !(_media?.cameraEnabled.value ?? false));
  }

  void _onMediaSessionReady() {
    if (!mounted || _ending) return;
    final media = _webrtcService.mediaSessionState.value;
    if (identical(media, _media)) return;
    _media?.cameraEnabled.removeListener(_onMediaState);
    _media?.remoteCameraEnabled.removeListener(_onMediaState);
    _media = media;
    media?.cameraEnabled.addListener(_onMediaState);
    media?.remoteCameraEnabled.addListener(_onMediaState);
    setState(() {
      if (media != null) _isCameraOff = !media.cameraEnabled.value;
    });
  }

  void _toggleMic() {
    if (_ending || !_localMediaReady) return;
    final next = !_isMicMuted;
    try {
      _webrtcService.toggleMic(next);
      setState(() => _isMicMuted = next);
      final roomId = widget.roomId;
      if (roomId != null) unawaited(SystemCallBridge.instance.setMuted(roomId, next));
      _audioFeedback.control(enabled: !next);
    } catch (_) {
      SLNotice.showError(context, context.tr('p4_call_media_unavailable'));
    }
  }

  void _applySystemMute() {
    final muted = _systemMuted;
    if (muted == null || !_localMediaReady || _ending) return;
    try {
      _webrtcService.toggleMic(muted);
      setState(() => _isMicMuted = muted);
      _systemMuted = null;
    } catch (_) {
      // Giữ yêu cầu để áp dụng khi media sẵn sàng.
    }
  }

  Future<void> _toggleCamera() async {
    final media = _media;
    if (_ending || _cameraBusy || _switchBusy || media == null) return;
    final enable = _isCameraOff;
    setState(() => _cameraBusy = true);
    try {
      if (enable &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final permission = await Permission.camera.request();
        if (!mounted || _ending) return;
        if (!permission.isGranted) {
          SLNotice.showError(context, context.tr('call_camera_permission'));
          return;
        }
      }
      await media.setCameraEnabled(enable);
      if (!mounted || _ending) return;
      await _localRenderer
          .setSrcObject(stream: enable ? _webrtcService.localStream : null)
          .timeout(const Duration(seconds: 5));
      if (!mounted || _ending) return;
      setState(() {
        _isCameraOff = !enable;
        _usingFrontCamera = true;
      });
      _audioFeedback.control(enabled: enable);
    } catch (error) {
      if (mounted && !_ending) {
        SLNotice.showError(
          context,
          context.tr(
            error is UnsupportedError
                ? 'call_video_upgrade_unavailable'
                : 'p4_call_media_unavailable',
          ),
        );
      }
    } finally {
      if (mounted && !_ending) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_ending || _switchBusy || _cameraBusy || _isCameraOff) return;
    setState(() => _switchBusy = true);
    try {
      await _webrtcService.switchCamera();
      if (mounted && !_ending) {
        setState(() => _usingFrontCamera = !_usingFrontCamera);
        _audioFeedback.control(enabled: true);
      }
    } catch (_) {
      if (mounted && !_ending) {
        SLNotice.showError(context, context.tr('p4_call_media_unavailable'));
      }
    } finally {
      if (mounted && !_ending) setState(() => _switchBusy = false);
    }
  }

  Future<void> _applyInitialSpeaker() async {
    try {
      await _webrtcService.toggleSpeaker(_isSpeakerOn);
    } catch (_) {
      if (mounted && !_ending) {
        SLNotice.showError(context, context.tr('p4_call_media_unavailable'));
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    if (_ending || !_localMediaReady || _speakerBusy) return;
    final previous = _isSpeakerOn;
    setState(() {
      _speakerBusy = true;
      _isSpeakerOn = !previous;
    });
    try {
      await _webrtcService.toggleSpeaker(!previous);
      if (mounted && !_ending) _audioFeedback.control(enabled: !previous);
    } catch (_) {
      if (mounted && !_ending) {
        setState(() => _isSpeakerOn = previous);
        SLNotice.showError(context, context.tr('p4_call_media_unavailable'));
      }
    } finally {
      if (mounted && !_ending) setState(() => _speakerBusy = false);
    }
  }

  Future<void> _showBeauty() async {
    final media = _media;
    if (media == null || _isCameraOff || _ending || _beautyOpen) return;
    if (!media.supportsBeauty) {
      SLNotice.showError(context, context.tr('call_beauty_unavailable'));
      return;
    }
    setState(() => _beautyOpen = true);
    final navigator = Navigator.of(context);
    final route = ModalBottomSheetRoute<void>(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF26283B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => CallBeautySheet(
        amount: media.skinBrightening,
        onApply: (amount) async {
          if (_ending || !mounted || !identical(media, _media)) {
            throw StateError('call_media_cancelled');
          }
          await media.setSkinBrightening(amount);
          if (mounted && !_ending) {
            setState(() {});
            _audioFeedback.control(enabled: amount > 0);
          }
        },
      ),
    );
    _beautyRoute = route;
    try {
      await navigator.push(route);
    } finally {
      if (identical(_beautyRoute, route)) _beautyRoute = null;
      if (mounted && !_ending) setState(() => _beautyOpen = false);
    }
  }

  Future<void> _endCall() async {
    if (_endCallRequested) return;
    _endCallRequested = true;
    unawaited(_audioFeedback.finish());
    // Phản hồi ngay trong frame kế tiếp trong khi native đang nhả media.
    setState(() => _ending = true);
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    final beautyRoute = _beautyRoute;
    _beautyRoute = null;
    if (beautyRoute != null && beautyRoute.isActive) {
      navigator.removeRoute(beautyRoute);
    }
    try {
      // Service tắt track và vô hiệu hóa phiên trước await đầu tiên. UI chỉ
      // đợi ngắn cho native; cleanup tiếp tục giữ chỗ nếu driver trả lời chậm.
      await _cleanupCall().timeout(
        const Duration(milliseconds: 600),
        onTimeout: () {},
      );
    } catch (error) {
      debugPrint('Video call cleanup failed: $error');
    }
    if (!mounted || route == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  Future<void> _cleanupCall() {
    final existing = _cleanupFuture;
    if (existing != null) return existing;

    final cleanup = _cleanupCallInternal();
    _cleanupFuture = cleanup;
    return cleanup;
  }

  Future<void> _cleanupCallInternal() async {
    _ending = true;
    unawaited(_systemCallSub?.cancel());
    _systemCallSub = null;
    final systemRoomId = _roomId ?? widget.roomId;
    if (systemRoomId != null) unawaited(SystemCallBridge.instance.end(systemRoomId));
    unawaited(SystemCallBridge.instance.setIncomingVisible(false));
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _elapsedTimer?.cancel();
    _callClock.stop();
    _webrtcService.connectionState.removeListener(_onConnectionState);
    _webrtcService.mediaSessionState.removeListener(_onMediaSessionReady);
    _media?.cameraEnabled.removeListener(_onMediaState);
    _media?.remoteCameraEnabled.removeListener(_onMediaState);
    final roomStatusSub = _roomStatusSub;
    _roomStatusSub = null;
    Future<void> releaseRenderers() async {
      try {
        await roomStatusSub?.cancel();
      } catch (error) {
        debugPrint('Video call room listener cleanup failed: $error');
      }
      final rendererInitialization = _rendererInitialization;
      if (rendererInitialization != null) {
        try {
          await rendererInitialization;
        } catch (_) {
          // Vẫn giải phóng renderer khởi tạo dở.
        }
      }
      await disposeVideoRendererSafely(_localRenderer);
      await disposeVideoRendererSafely(_remoteRenderer);
    }

    try {
      if (_ownsCall) {
        // hangUp vô hiệu hóa setup trước await đầu tiên trong releaseRenderers.
        await _webrtcService.hangUp(beforeMediaRelease: releaseRenderers);
      } else {
        await releaseRenderers();
      }
    } finally {
      AdSuppressionGuard.instance.resumeAds();
      _releaseSoundQuiet();
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
