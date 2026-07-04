import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/ad_suppression_guard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/services/webrtc_service.dart';
import '../../core/sl_theme.dart';

/// ============================================================
///  CallScreen — WebRTC Audio/Video Call UI
///  Hiển thị màn hình gọi điện (Incoming + Active)
/// ============================================================

// ─── Incoming Call Overlay ───────────────────────────────────
class IncomingCallOverlay extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final String roomId;
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallOverlay({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.roomId,
    required this.isVideo,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              const Color(0xFF1a0033).withValues(alpha: 0.98),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Text(
                widget.isVideo
                    ? L10nService().translate('chat_video_call_title')
                    : L10nService().translate('chat_voice_call_title'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              SLSpacing.h8,
              Text(
                L10nService().translate('chat_incoming_call'),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              SLSpacing.gapH(48),

              // Avatar with pulse
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE91E8C).withValues(alpha: 0.8),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E8C).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.callerAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            memCacheWidth: 250,
                            imageUrl: widget.callerAvatar,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            placeholder: (context, url) =>
                                Container(color: const Color(0xFF1F2937)),
                            errorWidget: (context, url, error) =>
                                _defaultAvatar(),
                          )
                        : _defaultAvatar(),
                  ),
                ),
              ),
              SLSpacing.gapH(32),

              // Caller name
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SLSpacing.gapH(72),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _CallButton(
                    icon: Icons.call_end,
                    label: L10nService().translate('chat_decline'),
                    color: Colors.red.shade600,
                    onTap: widget.onDecline,
                    size: 72,
                  ),
                  // Accept
                  _CallButton(
                    icon: widget.isVideo ? Icons.videocam : Icons.call,
                    label: L10nService().translate('chat_answer'),
                    color: Colors.green.shade500,
                    onTap: widget.onAccept,
                    size: 72,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        color: const Color(0xFFE91E8C),
        child: const Icon(Icons.person, size: 60, color: Colors.white),
      );
}

// ─── Active Call Screen ───────────────────────────────────────
class ActiveCallScreen extends StatefulWidget {
  final String partnerName;
  final String partnerAvatar;
  final String roomId;
  final bool isVideo;
  final bool isCaller; // true = người gọi, false = người bắt máy

  const ActiveCallScreen({
    super.key,
    required this.partnerName,
    required this.partnerAvatar,
    required this.roomId,
    required this.isVideo,
    required this.isCaller,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final _webrtc = WebRTCService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _micMuted = false;
  bool _camOff = false;
  bool _speakerOn = true;
  bool _connected = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AdSuppressionGuard.instance.suppressAds();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    try {
      await _webrtc.openUserMedia(includeVideo: widget.isVideo);
      _localRenderer.srcObject =
          await _webrtc.createLocalRenderer().then((r) => r.srcObject!);

      if (widget.isCaller) {
        await _webrtc.createRoom(_remoteRenderer, targetHouseId: widget.roomId);
      } else {
        await _webrtc.joinRoom(widget.roomId, _remoteRenderer);
      }

      if (!mounted) return;
      setState(() => _connected = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(L10nService().translate('chat_call_connect_failed')),
              backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  String get _duration {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _hangUp() async {
    _timer?.cancel();
    await _webrtc.hangUp();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    AdSuppressionGuard.instance.resumeAds();
    _timer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth < 360 ? 14.0 : 16.0;
          final previewWidth =
              (constraints.maxWidth * 0.28).clamp(96.0, 118.0).toDouble();
          final previewHeight =
              (previewWidth * 1.45).clamp(136.0, 170.0).toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.isVideo && _connected)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                _buildAudioBackground(),
              if (widget.isVideo)
                Positioned(
                  top: mediaPadding.top + 16,
                  right: sidePadding,
                  child: Container(
                    width: previewWidth,
                    height: previewHeight,
                    decoration: BoxDecoration(
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _camOff
                        ? Container(
                            color: Colors.grey.shade900,
                            child: const Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 32,
                            ),
                          )
                        : RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      widget.isVideo ? previewWidth + sidePadding + 12 : 20,
                      0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SLSpacing.h8,
                        Text(
                          _connected
                              ? _duration
                              : L10nService().translate('chat_connecting'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 32,
                        runSpacing: 12,
                        children: [
                          _SmallCallButton(
                            icon:
                                _speakerOn ? Icons.volume_up : Icons.volume_off,
                            label: _speakerOn
                                ? L10nService().translate('chat_speaker')
                                : L10nService().translate('chat_speaker_off'),
                            onTap: () =>
                                setState(() => _speakerOn = !_speakerOn),
                          ),
                          if (widget.isVideo)
                            _SmallCallButton(
                              icon:
                                  _camOff ? Icons.videocam_off : Icons.videocam,
                              label: _camOff
                                  ? L10nService().translate('chat_camera_on')
                                  : L10nService().translate('chat_camera_off'),
                              onTap: () => setState(() => _camOff = !_camOff),
                            ),
                        ],
                      ),
                      SLSpacing.h20,
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 14,
                        children: [
                          _CallButton(
                            icon: _micMuted ? Icons.mic_off : Icons.mic,
                            label: _micMuted
                                ? L10nService().translate('chat_mic_on')
                                : L10nService().translate('chat_mic_off'),
                            color: _micMuted
                                ? Colors.grey.shade700
                                : Colors.white24,
                            onTap: () => setState(() => _micMuted = !_micMuted),
                            size: 60,
                            iconColor: Colors.white,
                          ),
                          _CallButton(
                            icon: Icons.call_end,
                            label: L10nService().translate('chat_hang_up'),
                            color: Colors.red.shade600,
                            onTap: _hangUp,
                            size: 72,
                          ),
                          _CallButton(
                            icon: Icons.flip_camera_ios,
                            label:
                                L10nService().translate('chat_switch_camera'),
                            color: Colors.white24,
                            onTap: () {},
                            size: 60,
                            iconColor: Colors.white,
                          ),
                        ],
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

  Widget _buildAudioBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a0033), Color(0xFF0d001a)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.6),
                  width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: widget.partnerAvatar.isNotEmpty
                  ? CachedNetworkImage(
                      memCacheWidth: 250,
                      imageUrl: widget.partnerAvatar,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      placeholder: (context, url) =>
                          Container(color: const Color(0xFF1F2937)),
                      errorWidget: (context, url, error) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
          ),
          SLSpacing.h20,
          if (_connected)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AudioWave(),
                SLSpacing.w4,
                _AudioWave(),
                SLSpacing.w4,
                _AudioWave(),
                SLSpacing.w4,
                _AudioWave(),
                SLSpacing.w4,
                _AudioWave(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        color: const Color(0xFFE91E8C),
        child: const Icon(Icons.person, size: 60, color: Colors.white),
      );
}

// ─── Shared Widgets ───────────────────────────────────────────
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.size,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.44),
          ),
        ),
        SLSpacing.h8,
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _SmallCallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallCallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 26),
          SLSpacing.h4,
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AudioWave extends StatefulWidget {
  const _AudioWave();
  @override
  State<_AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<_AudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: 600 + (DateTime.now().millisecond % 400)),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 4, end: 20).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 4,
        height: _anim.value,
        decoration: BoxDecoration(
          color: const Color(0xFFE91E8C),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
