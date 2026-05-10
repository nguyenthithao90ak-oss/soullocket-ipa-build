import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/app_error_mapper.dart';
import '../../services/webrtc_service.dart';
import '../../core/sl_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _isSpeakerOn = widget.isVideo; // Video call mặc định mở loa ngoài
    _webrtcService.toggleSpeaker(_isSpeakerOn);
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    try {
      if (widget.targetHouseId == 'random_stranger_id') {
        // Mock connection for demo
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        setState(() {
          _inCall = true;
          _isPreparing = false;
        });
        return;
      }

      final stream =
          await _webrtcService.openUserMedia(includeVideo: widget.isVideo);
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
      // Đặt timeout 45s cho cuộc gọi chưa được bắt máy
      if (widget.roomId == null) {
        _timeoutTimer = Timer(const Duration(seconds: 45), () {
          if (mounted && _roomId != null) {
            _endCall();
          }
        });
      }

      // Lắng nghe trạng thái room để tự hủy timeout và tự kết thúc gọi
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
            debugPrint(
              'Video call room listener failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể theo dõi trạng thái cuộc gọi.',
              ).message}',
            );
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPreparing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể bắt đầu cuộc gọi lúc này. Vui lòng thử lại.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _webrtcService.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callLabel = widget.isVideo ? 'Video call' : 'Audio call';
    final mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth < 360 ? 14.0 : 20.0;
          final previewWidth =
              (constraints.maxWidth * 0.30).clamp(96.0, 128.0).toDouble();
          final previewHeight =
              (previewWidth * 4 / 3).clamp(128.0, 172.0).toDouble();
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
                          onPressed: _endCall,
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
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
                                Text(
                                  _isPreparing ? 'Đang kết nối...' : callLabel,
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
                        color:
                            _isSpeakerOn ? Colors.white24 : Colors.grey[800]!,
                        iconColor: Colors.white,
                        onTap: _toggleSpeaker,
                        size: 56,
                      ),
                      if (widget.isVideo)
                        _buildCallBtn(
                          icon: Icons.cameraswitch,
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
                          color: _isCameraOff ? Colors.white : Colors.white24,
                          iconColor: _isCameraOff ? Colors.black : Colors.white,
                          onTap: _toggleCamera,
                          size: 56,
                        ),
                      _buildCallBtn(
                        icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                        color: _isMicMuted ? Colors.white : Colors.white24,
                        iconColor: _isMicMuted ? Colors.black : Colors.white,
                        onTap: _toggleMic,
                        size: 56,
                      ),
                      _buildCallBtn(
                        icon: Icons.call_end,
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
    return Center(
      child: Text(
        _isPreparing ? 'Đang khởi tạo $callLabel...' : 'Đang chờ kết nối...',
        style: SLTheme.quicksand(color: Colors.white54, fontSize: 16),
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
                  ? NetworkImage(widget.targetAvatarUrl!)
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
              _isPreparing ? 'Đang kết nối $callLabel...' : 'Mic đang bật',
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
    await _webrtcService.hangUp();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _buildCallBtn({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
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
                offset: const Offset(0, 8))
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
