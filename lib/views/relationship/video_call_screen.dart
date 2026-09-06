import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/webrtc_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/ad_suppression_guard.dart';
import '../../utils/services/purchase_service.dart';
import '../../core/constants/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoCallScreen extends StatefulWidget {
  final String houseId;
  final String targetHouseId;
  final String targetName;
  final String? targetAvatarUrl;
  final bool isVideo;
  final String? roomId;
  final Future<void> Function(String roomId)? onRoomCreated;

  const VideoCallScreen({
    super.key,
    required this.houseId,
    required this.targetHouseId,
    required this.targetName,
    this.targetAvatarUrl,
    this.isVideo = true,
    this.roomId,
    this.onRoomCreated,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCall = false;
  bool _isPreparing = true;
  String? _roomId;

  // Trạng thái các nút chức năng
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
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
    AdSuppressionGuard.instance.suppressAds();
    _isSpeakerOn = widget.isVideo;
    _webrtcService.toggleSpeaker(_isSpeakerOn);
    _initRenderers();
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
      SnackBar(
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
    _elapsedTimer?.cancel();
    AdSuppressionGuard.instance.resumeAds();
    _roomStatusSub?.cancel();
    _webrtcService.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    try {
      if (widget.targetHouseId == 'random_stranger_id') {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
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
      _localRenderer.srcObject = stream;

      if (widget.roomId == null) {
        _roomId = await _webrtcService.createRoom(
          _remoteRenderer,
          targetHouseId: widget.targetHouseId,
          callerHouseId: widget.houseId,
        );
        if (widget.onRoomCreated != null && _roomId != null) {
          await widget.onRoomCreated!(_roomId!);
        }
      } else {
        _roomId = widget.roomId;
        await _webrtcService.joinRoom(widget.roomId!, _remoteRenderer);
      }

      if (!mounted) return;
      setState(() {
        _inCall = true;
        _isPreparing = false;
      });
      _startElapsedTimer();

      if (widget.roomId == null) {
        _timeoutTimer = Timer(const Duration(seconds: 45), () {
          if (mounted && _roomId != null) {
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
                if (status == 'connected') {
                  _timeoutTimer?.cancel();
                } else if (status == 'ended') {
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
      if (!mounted) return;
      setState(() => _isPreparing = false);
      final msgErrorOccurred = context.tr('relationship_chathbtucu_cd4ee1');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msgErrorOccurred)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final callLabel = context.tr(
      widget.isVideo ? 'p4_call_video_label' : 'p4_call_audio_label',
    );
    final mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth < 360 ? 14.0 : 20.0;
          final previewWidth = (constraints.maxWidth * 0.30)
              .clamp(96.0, 128.0)
              .toDouble();
          final previewHeight = (previewWidth * 4 / 3)
              .clamp(128.0, 172.0)
              .toDouble();
          final previewTop = mediaPadding.top + 76;

          return Stack(
            children: [
              Positioned.fill(
                child: widget.isVideo
                    ? (_inCall
                          ? RTCVideoView(
                              _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          : _buildWaitingState(callLabel))
                    : _buildAudioBackdrop(callLabel),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      sidePadding,
                      12,
                      sidePadding,
                      0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: context.tr('p4_call_end_and_back'),
                          onPressed: _endCall,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: widget.isVideo ? previewWidth + 12 : 0,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.targetName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_inCall) ...[
                                      Icon(
                                        _isWarning
                                            ? Icons.timer_off_rounded
                                            : Icons.timer_outlined,
                                        color: _isWarning
                                            ? const Color(0xFFFF5252)
                                            : Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_formatElapsed()} / ${_formatDuration(_remainingSeconds)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.quicksand(
                                          color: _isWarning
                                              ? const Color(0xFFFF5252)
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: _isWarning
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ] else
                                      Text(
                                        _isPreparing
                                            ? context.tr(
                                                'relationship_angktni_e4af2e',
                                              )
                                            : callLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.quicksand(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.isVideo && !_isCameraOff)
                Positioned(
                  right: sidePadding,
                  top: previewTop,
                  width: previewWidth,
                  height: previewHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              Positioned(
                left: sidePadding,
                right: sidePadding,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _buildCallBtn(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        label: context.tr(
                          _isSpeakerOn
                              ? 'p4_call_speaker_off'
                              : 'p4_call_speaker_on',
                        ),
                        color: _isSpeakerOn
                            ? Colors.white24
                            : Colors.grey[800]!,
                        iconColor: Colors.white,
                        onTap: _toggleSpeaker,
                        size: 56,
                      ),
                      if (widget.isVideo)
                        _buildCallBtn(
                          icon: Icons.cameraswitch,
                          label: context.tr('p4_call_switch_camera'),
                          color: Colors.white24,
                          iconColor: Colors.white,
                          onTap: _switchCamera,
                          size: 56,
                        ),
                      if (widget.isVideo)
                        _buildCallBtn(
                          icon: _isCameraOff
                              ? Icons.videocam_off
                              : Icons.videocam,
                          label: context.tr(
                            _isCameraOff
                                ? 'p4_call_camera_on'
                                : 'p4_call_camera_off',
                          ),
                          color: _isCameraOff ? Colors.white : Colors.white24,
                          iconColor: _isCameraOff ? Colors.black : Colors.white,
                          onTap: _toggleCamera,
                          size: 56,
                        ),
                      _buildCallBtn(
                        icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                        label: context.tr(
                          _isMicMuted ? 'p4_call_mic_on' : 'p4_call_mic_off',
                        ),
                        color: _isMicMuted ? Colors.white : Colors.white24,
                        iconColor: _isMicMuted ? Colors.black : Colors.white,
                        onTap: _toggleMic,
                        size: 56,
                      ),
                      _buildCallBtn(
                        icon: Icons.call_end,
                        label: context.tr('p4_call_end'),
                        color: Colors.red,
                        iconColor: Colors.white,
                        onTap: _endCall,
                        size: 64,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    _webrtcService.toggleMic(_isMicMuted);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _webrtcService.toggleCamera(_isCameraOff);
  }

  void _switchCamera() {
    _webrtcService.switchCamera();
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _webrtcService.toggleSpeaker(_isSpeakerOn);
  }

  Widget _buildWaitingState(String callLabel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar với animated ring
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.5 + value * 0.5,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF6B9D).withValues(alpha: 0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B9D).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 15,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 67,
                  backgroundColor: const Color(0xFF1A1A2E),
                  backgroundImage: widget.targetAvatarUrl != null
                      ? CachedNetworkImageProvider(widget.targetAvatarUrl!)
                      : null,
                  child: widget.targetAvatarUrl == null
                      ? Text(
                          widget.targetName.isEmpty
                              ? '💕'
                              : widget.targetName[0].toUpperCase(),
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.targetName,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFFFF6B9D).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isPreparing
                      ? L10nService().format('p4_call_initializing', {
                          'type': callLabel,
                        })
                      : context.tr('p4_call_waiting'),
                  style: SLTheme.quicksand(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBackdrop(String callLabel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF3A0D24)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white12,
              backgroundImage: widget.targetAvatarUrl != null
                  ? CachedNetworkImageProvider(widget.targetAvatarUrl!)
                  : null,
              child: widget.targetAvatarUrl == null
                  ? Text(
                      widget.targetName.isEmpty
                          ? '?'
                          : widget.targetName[0].toUpperCase(),
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            SLSpacing.h16,
            Text(
              widget.targetName,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SLSpacing.h8,
            Text(
              _isPreparing
                  ? L10nService().format('p4_call_connecting', {
                      'type': callLabel,
                    })
                  : context.tr('relationship_micangbt_8c0d7f'),
              style: SLTheme.quicksand(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endCall() async {
    _elapsedTimer?.cancel();
    await _webrtcService.hangUp();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _buildCallBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.5),
          ),
        ),
      ),
    );
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
