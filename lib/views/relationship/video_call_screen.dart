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
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final VoidCallback _releaseSoundQuiet;
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCall = false;
  bool _ending = false;
  bool _endCallRequested = false;
  bool _ownsCall = false;
  Future<void>? _rendererInitialization;
  Future<void>? _cleanupFuture;
  String? _permissionError;
  bool _isPreparing = true;
  String? _roomId;

  // Trạng thái các nút chức năng
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _cameraBusy = false;
  bool _switchBusy = false;
  bool _usingFrontCamera = true;
  CallMediaSession? _media;
  Timer? _timeoutTimer;
  // ignore: unused_field
  StreamSubscription<DatabaseEvent>? _roomStatusSub;

  // Timer + giới hạn cuộc gọi
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  int _maxCallSeconds = 0;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _releaseSoundQuiet = SoundService().holdQuiet();
    AdSuppressionGuard.instance.suppressAds();
    _isSpeakerOn = widget.isVideo;
    _isCameraOff = !widget.isVideo;
    _webrtcService.connectionState.addListener(_onConnectionState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_ending) unawaited(_initRenderers());
    });
    _checkVip();
  }

  Future<void> _checkVip() async {
    try {
      final isVip = await PurchaseService().isVip();
      if (mounted) {
        setState(() {
          _isVip = isVip;
          if (isVip && AppConfig.vipCallDurationMinutes > 0) {
            _maxCallSeconds = AppConfig.vipCallDurationMinutes * 60;
          } else if (!isVip && AppConfig.freeCallDurationMinutes > 0) {
            _maxCallSeconds = AppConfig.freeCallDurationMinutes * 60;
          }
        });
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/relationship/video_call_screen.dart: $error',
      );
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _elapsedTimer?.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });

      if (_maxCallSeconds > 0 && _elapsedSeconds >= _maxCallSeconds) {
        // Hết giờ — tự động kết thúc
        _elapsedTimer?.cancel();
        _showTimeUpSnack();
        _endCall();
      }
    });
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
      if (widget.isVideo || kIsWeb) {
        await _localRenderer.setSrcObject(stream: stream);
        // Chỉ tắt tiếng preview sau khi đã gắn stream. Với cuộc gọi thoại
        // native, renderer không cần giữ stream local nên không đụng vào nó.
        _localRenderer.muted = true;
      }
      if (!mounted || _ending) return;
      _webrtcService.toggleSpeaker(_isSpeakerOn);

      if (widget.roomId == null) {
        _roomId = await _webrtcService.createRoom(
          _remoteRenderer,
          targetHouseId: widget.targetHouseId,
          callerHouseId: widget.houseId,
          isVideo: widget.isVideo,
          callerName: widget.callerName,
        );
        if (!mounted || _ending) return;
        if (widget.onRoomCreated != null && _roomId != null) {
          await widget.onRoomCreated!(_roomId!);
        }
      } else {
        _roomId = widget.roomId;
        await _webrtcService.joinRoom(widget.roomId!, _remoteRenderer);
      }

      if (!mounted || _ending) return;
      _media = _webrtcService.mediaSession;
      _media?.cameraEnabled.addListener(_onMediaState);
      _media?.remoteCameraEnabled.addListener(_onMediaState);
      setState(() {
        _isPreparing = false;
      });

      if (widget.roomId == null) {
        _timeoutTimer = Timer(const Duration(seconds: 45), () {
          if (mounted && !_inCall && _roomId != null) {
            _endCall();
          }
        });
      }

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
      if (!_inCall) {
        setState(() {
          _inCall = true;
          _isPreparing = false;
        });
        _startElapsedTimer();
      }
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      SLNotice.showError(context, context.tr('p4_call_connection_failed'));
      unawaited(_endCall());
    }
  }

  @override
  Widget build(BuildContext context) {
    final callLabel = context.tr(
      widget.isVideo ? 'p4_call_video_label' : 'p4_call_audio_label',
    );
    final mediaPadding = MediaQuery.paddingOf(context);

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
            : _buildCallBody(callLabel, mediaPadding),
      ),
    );
  }

  Widget _buildCallBody(String callLabel, EdgeInsets mediaPadding) {
    final media = _media;
    final remoteVideo = media?.remoteCameraEnabled.value ?? widget.isVideo;
    final controlsReady = !_isPreparing && !_ending;
    return SoulCallSurface(
      name: widget.targetName,
      avatarUrl: widget.targetAvatarUrl,
      connected: _inCall,
      status: _inCall
          ? (_maxCallSeconds > 0
                ? '${_formatElapsed()} · ${_formatDuration(_remainingSeconds)}'
                : _formatElapsed())
          : context.tr(
              _isPreparing ? 'relationship_angktni_e4af2e' : 'p4_call_waiting',
            ),
      warning: _isWarning,
      cameraOn: !_isCameraOff,
      remoteCameraOn: _inCall && remoteVideo,
      micMuted: _isMicMuted,
      speakerOn: _isSpeakerOn,
      cameraBusy: _cameraBusy,
      beautyAmount: media?.skinBrightening ?? 0,
      onCamera: controlsReady && media != null ? _toggleCamera : null,
      onMic: controlsReady ? _toggleMic : null,
      onSpeaker: controlsReady ? _toggleSpeaker : null,
      onSwitchCamera: controlsReady && !_cameraBusy && !_switchBusy
          ? _switchCamera
          : null,
      onBeauty: controlsReady && !_cameraBusy ? _showBeauty : null,
      onEnd: _endCall,
      remoteVideo: RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
      localVideo: _isCameraOff
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

  void _toggleMic() {
    if (_ending) return;
    setState(() => _isMicMuted = !_isMicMuted);
    _webrtcService.toggleMic(_isMicMuted);
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
      await _localRenderer.setSrcObject(
        stream: enable ? _webrtcService.localStream : null,
      );
      if (!mounted || _ending) return;
      setState(() {
        _isCameraOff = !enable;
        _usingFrontCamera = true;
      });
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
      }
    } catch (_) {
      if (mounted && !_ending) {
        SLNotice.showError(context, context.tr('p4_call_media_unavailable'));
      }
    } finally {
      if (mounted && !_ending) setState(() => _switchBusy = false);
    }
  }

  void _toggleSpeaker() {
    if (_ending) return;
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _webrtcService.toggleSpeaker(_isSpeakerOn);
  }

  Future<void> _showBeauty() async {
    final media = _media;
    if (media == null || _isCameraOff || _ending) return;
    if (!media.supportsBeauty) {
      SLNotice.showError(context, context.tr('call_beauty_unavailable'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF26283B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => CallBeautySheet(
        amount: media.skinBrightening,
        onApply: (amount) async {
          if (_ending || !mounted) return;
          await media.setSkinBrightening(amount);
          if (mounted && !_ending) setState(() {});
        },
      ),
    );
  }

  Future<void> _endCall() async {
    if (_endCallRequested) return;
    _endCallRequested = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    await _cleanupCall();
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
    _timeoutTimer?.cancel();
    _elapsedTimer?.cancel();
    _webrtcService.connectionState.removeListener(_onConnectionState);
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
