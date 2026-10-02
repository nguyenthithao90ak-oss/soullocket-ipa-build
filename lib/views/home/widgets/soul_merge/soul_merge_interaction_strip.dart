import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soul_merge_mascot.dart';

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
  });

  final ValueNotifier<double> scale;
  final bool isMerged;
  final List<String> photoUrls;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('soul-merge-interaction-strip'),
      height: 94,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.96)),
      ),
      child: Row(
        children: [
          Listener(
            key: const ValueKey('soul-merge-touch-target'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: onPointerDown,
            onPointerMove: onPointerMove,
            onPointerUp: onPointerUp,
            onPointerCancel: onPointerCancel,
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: scale,
                builder: (context, value, child) => AnimatedScale(
                  scale: value,
                  duration: const Duration(milliseconds: 100),
                  child: child,
                ),
                child: const SizedBox.square(
                  dimension: 76,
                  child: Center(child: SoulMergeMascot(size: 68, framed: true)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(
                isMerged ? 'p4_soul_connected_title' : 'p4_soul_status_waiting',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A4966),
              ),
            ),
          ),
          for (final url in photoUrls.take(3))
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 38,
                  height: 50,
                  memCacheWidth: 114,
                  memCacheHeight: 150,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox(width: 38, height: 50),
                  errorWidget: (_, _, _) => const SizedBox(
                    width: 38,
                    height: 50,
                    child: Icon(Icons.image_outlined, size: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
