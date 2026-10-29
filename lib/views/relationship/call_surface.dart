import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../widgets/soul_merge_mark.dart';

@immutable
class SoulCallStatus {
  const SoulCallStatus(this.text, {this.warning = false});
  final String text;
  final bool warning;
}

/// Lớp trình bày thuần UI để kiểm tra bố cục mà không mở camera/cuộc gọi thật.
class SoulCallSurface extends StatelessWidget {
  const SoulCallSurface({
    super.key,
    required this.name,
    required this.status,
    required this.connected,
    required this.cameraOn,
    required this.remoteCameraOn,
    required this.micMuted,
    required this.speakerOn,
    required this.cameraBusy,
    required this.beautyAmount,
    required this.onCamera,
    required this.onMic,
    required this.onSpeaker,
    required this.onSwitchCamera,
    required this.onBeauty,
    required this.onEnd,
    this.avatarUrl,
    this.localVideo,
    this.remoteVideo,
    this.warning = false,
    this.statusListenable,
    this.speakerBusy = false,
    this.switchBusy = false,
    this.ending = false,
  });

  final String name;
  final String? avatarUrl;
  final String status;
  final bool connected;
  final bool cameraOn;
  final bool remoteCameraOn;
  final bool micMuted;
  final bool speakerOn;
  final bool cameraBusy;
  final double beautyAmount;
  final bool warning;
  final ValueListenable<SoulCallStatus>? statusListenable;
  final bool speakerBusy;
  final bool switchBusy;
  final bool ending;
  final Widget? localVideo;
  final Widget? remoteVideo;
  final VoidCallback? onCamera;
  final VoidCallback? onMic;
  final VoidCallback? onSpeaker;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onBeauty;
  final VoidCallback onEnd;

  static const _ink = Color(0xFF181B2C);
  static const _accent = Color(0xFFE5B9CC);
  static const _muted = Color(0xFFC1BED2);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CallBackdrop()),
        if (remoteCameraOn && remoteVideo != null)
          Positioned.fill(child: remoteVideo!),
        if (remoteCameraOn)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Colors.transparent,
                      Color(0xBB101222),
                    ],
                    stops: [0, 0.42, 1],
                  ),
                ),
              ),
            ),
          ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 620;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        const SoulMergeMark(size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('p4_soul_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('p4_call_end_and_back'),
                          onPressed: ending ? null : onEnd,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white10,
                          ),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (!remoteCameraOn)
                          Positioned.fill(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  cameraOn ? 124 : 12,
                                  24,
                                  12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _CallPortrait(
                                      name: name,
                                      url: avatarUrl,
                                      size: compact ? 108 : 144,
                                    ),
                                    SizedBox(height: compact ? 16 : 26),
                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      style: SLTheme.quicksand(
                                        color: Colors.white,
                                        fontSize: compact ? 25 : 30,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _statusChip(context),
                                    const SizedBox(height: 14),
                                    Text(
                                      context.tr(
                                        cameraOn
                                            ? 'call_camera_only_you'
                                            : 'call_voice_camera_hint',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: SLTheme.quicksand(
                                        color: _muted,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (remoteCameraOn)
                          Positioned(
                            left: 24,
                            right: cameraOn ? 142 : 24,
                            top: 22,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _statusChip(context),
                              ],
                            ),
                          ),
                        if (cameraOn && localVideo != null)
                          PositionedDirectional(
                            end: 18,
                            top: 16,
                            width: compact ? 86 : 108,
                            height: compact ? 114 : 144,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white38),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(21),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    localVideo!,
                                    if (beautyAmount > 0)
                                      PositionedDirectional(
                                        bottom: 8,
                                        start: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: _ink.withValues(alpha: 0.8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.auto_awesome_rounded,
                                            color: _accent,
                                            size: 15,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _controls(context, compact),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context) {
    final listenable = statusListenable;
    if (listenable == null) {
      return _buildStatusChip(SoulCallStatus(status, warning: warning));
    }
    return ValueListenableBuilder<SoulCallStatus>(
      valueListenable: listenable,
      builder: (context, value, _) => _buildStatusChip(value),
    );
  }

  Widget _buildStatusChip(SoulCallStatus value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ending
              ? Icons.call_end_rounded
              : connected
              ? Icons.graphic_eq_rounded
              : Icons.ring_volume_rounded,
          size: 16,
          color: value.warning ? const Color(0xFFFF9A9A) : _accent,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value.text,
            style: SLTheme.quicksand(
              color: value.warning ? const Color(0xFFFF9A9A) : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _controls(BuildContext context, bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 10 : 20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cameraOn)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      key: const ValueKey('call-switch-camera'),
                      onPressed: onSwitchCamera,
                      style: _pillStyle(),
                      icon: switchBusy
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cameraswitch_rounded, size: 19),
                      label: Text(
                        context.tr('p4_call_switch_camera'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: OutlinedButton.icon(
                      key: const ValueKey('call-beauty'),
                      onPressed: onBeauty,
                      style: _pillStyle(active: beautyAmount > 0),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                      label: Text(
                        context.tr('call_beauty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: compact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF26283B).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CallAction(
                  actionKey: const ValueKey('call-speaker'),
                  icon: speakerOn
                      ? Icons.volume_up_rounded
                      : Icons.hearing_rounded,
                  label: context.tr('call_speaker'),
                  tooltip: context.tr(
                    speakerOn ? 'p4_call_speaker_off' : 'p4_call_speaker_on',
                  ),
                  selected: speakerOn,
                  busy: speakerBusy,
                  onTap: onSpeaker,
                ),
                _CallAction(
                  actionKey: const ValueKey('call-mic'),
                  icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: context.tr('call_microphone'),
                  tooltip: context.tr(
                    micMuted ? 'p4_call_mic_on' : 'p4_call_mic_off',
                  ),
                  selected: micMuted,
                  onTap: onMic,
                ),
                _CallAction(
                  actionKey: const ValueKey('call-camera'),
                  icon: cameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  label: context.tr('call_camera'),
                  tooltip: context.tr(
                    cameraOn ? 'p4_call_camera_off' : 'p4_call_camera_on',
                  ),
                  selected: cameraOn,
                  busy: cameraBusy,
                  onTap: onCamera,
                ),
                _CallAction(
                  actionKey: const ValueKey('call-end'),
                  icon: Icons.call_end_rounded,
                  label: context.tr('call_hang_up'),
                  tooltip: context.tr('p4_call_end'),
                  destructive: true,
                  busy: ending,
                  onTap: ending ? null : onEnd,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  ButtonStyle _pillStyle({bool active = false}) => OutlinedButton.styleFrom(
    foregroundColor: active ? _ink : Colors.white,
    backgroundColor: active ? _accent : Colors.white.withValues(alpha: 0.06),
    disabledForegroundColor: Colors.white30,
    side: const BorderSide(color: Colors.white12),
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    textStyle: SLTheme.quicksand(fontSize: 12, fontWeight: FontWeight.w700),
  );
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
    this.busy = false,
  });
  final Key actionKey;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        IconButton.filled(
          key: actionKey,
          tooltip: tooltip,
          isSelected: selected,
          onPressed: busy ? null : onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size(52, 52),
            backgroundColor: destructive
                ? const Color(0xFFEF6478)
                : selected
                ? SoulCallSurface._accent
                : Colors.white10,
            foregroundColor: destructive || !selected
                ? Colors.white
                : SoulCallSurface._ink,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
            disabledForegroundColor: Colors.white30,
          ),
          icon: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : Icon(icon, size: 25),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: onTap == null ? Colors.white30 : SoulCallSurface._muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _CallPortrait extends StatelessWidget {
  const _CallPortrait({
    required this.name,
    required this.url,
    required this.size,
  });
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size + 36,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SoulCallSurface._accent.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: SoulCallSurface._accent.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: SoulCallSurface._accent.withValues(alpha: 0.12),
                blurRadius: 42,
              ),
            ],
          ),
          child: ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: url?.trim().isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: url!,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      errorWidget: (_, _, _) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),
        ),
        PositionedDirectional(
          end: 10,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
              color: Color(0xFF3E3B55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: SoulCallSurface._accent,
              size: 19,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fallback() => ColoredBox(
    color: const Color(0xFF44435B),
    child: Center(
      child: name.trim().isEmpty
          ? const Icon(
              Icons.favorite_rounded,
              color: SoulCallSurface._accent,
              size: 42,
            )
          : Text(
              name.trim().characters.first.toUpperCase(),
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
              ),
            ),
    ),
  );
}

class _CallBackdrop extends StatelessWidget {
  const _CallBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF25283F), Color(0xFF171A2C), Color(0xFF30283C)],
      ),
    ),
  );
}
