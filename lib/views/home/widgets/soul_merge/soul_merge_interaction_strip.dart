import 'dart:math' as math;

import 'soul_merge_design.dart';
import 'soul_merge_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class SoulMergeInteractionStrip extends StatelessWidget {
  const SoulMergeInteractionStrip({
    super.key,
    required this.scale,
    required this.isMerged,
    required this.photoUrls,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    this.partnerName = '',
    this.isSelfReady = false,
    this.isPartnerReady = false,
    this.onAccessibleTap,
  });

  final ValueNotifier<double> scale;
  final bool isMerged;
  final List<String> photoUrls;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final String partnerName;
  final bool isSelfReady;
  final bool isPartnerReady;
  final VoidCallback? onAccessibleTap;

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    final title = context.tr(
      isMerged ? 'p4_soul_connected_title' : 'p4_soul_touch_title',
    );
    final hint = isMerged
        ? context.tr('p4_soul_touch_connected')
        : isPartnerReady
        ? L10nService().format('p4_soul_touch_partner_ready', {
            'name': partnerName,
          })
        : isSelfReady
        ? L10nService().format('p4_soul_touch_waiting', {'name': partnerName})
        : context.tr('p4_soul_touch_hint');
    return Container(
      key: const ValueKey('soul-merge-interaction-strip'),
      constraints: const BoxConstraints(minHeight: 90),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [colors.blush, colors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: title,
              hint: hint,
              onTap: onAccessibleTap,
              child: Listener(
                key: const ValueKey('soul-merge-touch-target'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: onPointerDown,
                onPointerMove: onPointerMove,
                onPointerUp: onPointerUp,
                onPointerCancel: onPointerCancel,
                child: ValueListenableBuilder<double>(
                  valueListenable: scale,
                  builder: (context, value, child) => Row(
                    children: [
                      AnimatedScale(
                        scale: value,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 100),
                        child: RepaintBoundary(
                          child: SizedBox.square(
                            dimension: 66,
                            child: CustomPaint(
                              painter: _TouchRingPainter(
                                colors: colors,
                                active: value < 1 || isMerged || isPartnerReady,
                              ),
                              child: Center(
                                child: Icon(
                                  isMerged
                                      ? Icons.favorite_rounded
                                      : Icons.fingerprint_rounded,
                                  size: 29,
                                  color: colors.rose,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hint,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (photoUrls.isNotEmpty)
            IconButton(
              tooltip: context.tr('p4_soul_photo_open'),
              color: colors.rose,
              onPressed: () => SoulMergePhotoViewer.show(
                context,
                urls: photoUrls,
                initialIndex: photoUrls.length - 1,
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
            ),
        ],
      ),
    );
  }
}

class _TouchRingPainter extends CustomPainter {
  const _TouchRingPainter({required this.colors, required this.active});
  final SoulMergeColors colors;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius - 6, Paint()..color = colors.surface);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final ring = Rect.fromCircle(center: center, radius: radius - 2);
    canvas.drawArc(
      ring,
      -math.pi * .42,
      math.pi * .82,
      false,
      stroke..color = colors.rose.withValues(alpha: active ? 1 : .55),
    );
    canvas.drawArc(
      ring,
      math.pi * .58,
      math.pi * .82,
      false,
      stroke
        ..color = const Color(0xFF9A8CB4).withValues(alpha: active ? 1 : .55),
    );
    canvas.drawCircle(Offset(center.dx, 2), 2.8, Paint()..color = colors.rose);
    canvas.drawCircle(
      Offset(center.dx, size.height - 2),
      2.8,
      Paint()..color = const Color(0xFF9A8CB4),
    );
  }

  @override
  bool shouldRepaint(covariant _TouchRingPainter oldDelegate) =>
      active != oldDelegate.active || colors.dark != oldDelegate.colors.dark;
}
