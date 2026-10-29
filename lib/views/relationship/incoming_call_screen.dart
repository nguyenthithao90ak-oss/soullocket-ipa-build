import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/services/l10n_service.dart';

/// Màn nhận cuộc gọi không khởi tạo camera/micro trước khi người dùng đồng ý.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.callerName,
    required this.isVideo, required this.onAnswer, required this.onDecline,
    this.avatarUrl});
  final String callerName;
  final String? avatarUrl;
  final bool isVideo;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _decided = false;
  void _choose(VoidCallback action) {
    if (_decided) return;
    setState(() => _decided = true);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xff171b32),
          body: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _CallBackdrop())),
            SafeArea(child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxHeight < 560;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.favorite_rounded, size: 17, color: Color(0xffffa9c5)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(l10n.translate('home_cucgin_eff0b9'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 15))),
                        ]),
                        Padding(padding: EdgeInsets.symmetric(vertical: compact ? 26 : 48),
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xffffb4ce).withValues(alpha: .22)),
                                color: Colors.white.withValues(alpha: .04)),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: .15))),
                                child: ClipOval(child: SizedBox.square(dimension: compact ? 108 : 140,
                                  child: _avatar())),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(widget.callerName, textAlign: TextAlign.center,
                              style: TextStyle(fontSize: compact ? 26 : 32, height: 1.2,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 12),
                            Text(l10n.translate(widget.isVideo ? 'call_incoming_video' : 'call_incoming_audio'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xffffc6d9), fontSize: 16, height: 1.45)),
                          ])),
                        Column(children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              _CallChoice(key: const ValueKey('incoming-decline'),
                                label: l10n.translate('home_tchi_2119d8'),
                                icon: Icons.call_end_rounded, color: const Color(0xffec607a),
                                enabled: !_decided, onTap: () => _choose(widget.onDecline)),
                              const SizedBox(width: 20),
                              _CallChoice(key: const ValueKey('incoming-answer'),
                                label: l10n.translate('home_nghemy_e08606'),
                                icon: widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                color: const Color(0xff55bda5), enabled: !_decided,
                                onTap: () => _choose(widget.onAnswer)),
                            ]),
                          const SizedBox(height: 28),
                          Text(l10n.translate('call_incoming_privacy'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                        ]),
                      ]),
                  ),
                ),
              );
            })),
          ]),
        ),
      ),
    );
  }

  Widget _avatar() {
    const fallback = ColoredBox(color: Color(0xff343b59), child: Center(
      child: Icon(Icons.person_rounded, size: 74, color: Color(0xfff9c8d9))));
    final url = widget.avatarUrl?.trim() ?? '';
    if (!url.startsWith('https://')) return fallback;
    return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 320,
      placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback);
  }
}

class _CallChoice extends StatelessWidget {
  const _CallChoice({super.key, required this.label, required this.icon,
    required this.color, required this.enabled, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Flexible(child: Semantics(
    button: true, enabled: enabled, label: label, excludeSemantics: true,
    child: InkWell(onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(40), child: Column(children: [
    Container(width: 76, height: 76,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: enabled ? color : color.withValues(alpha: .5)),
      child: Icon(icon, size: 32, color: Colors.white)),
    const SizedBox(height: 13),
    Text(label, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
  ]))));
}

class _CallBackdrop extends CustomPainter {
  const _CallBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xff292239), Color(0xff191f36), Color(0xff132e39)]).createShader(rect));
    final radius = math.min(size.width, size.height) * .65;
    for (final center in [Offset(size.width * .1, size.height * .2), Offset(size.width, size.height * .65)]) {
      canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(
        colors: [const Color(0xffea96b7).withValues(alpha: .1), Colors.transparent])
        .createShader(Rect.fromCircle(center: center, radius: radius)));
    }
  }
  @override
  bool shouldRepaint(_CallBackdrop oldDelegate) => false;
}
