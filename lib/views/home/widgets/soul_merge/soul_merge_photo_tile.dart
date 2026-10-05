import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'soul_merge_design.dart';

class SoulMergePhotoTile extends StatefulWidget {
  const SoulMergePhotoTile({
    super.key,
    required this.url,
    required this.onOpen,
    this.imageProvider,
  });
  final String url;
  final VoidCallback onOpen;
  final ImageProvider? imageProvider;

  @override
  State<SoulMergePhotoTile> createState() => _SoulMergePhotoTileState();
}

class _SoulMergePhotoTileState extends State<SoulMergePhotoTile> {
  int _retry = 0;
  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    final provider =
        widget.imageProvider ?? CachedNetworkImageProvider(widget.url);
    return Semantics(
      button: true,
      label: context.tr('p4_soul_photo_open'),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 218,
            height: 174,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colors.blush),
                Image(
                  key: ValueKey(_retry),
                  image: ResizeImage.resizeIfNeeded(654, null, provider),
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, synchronous) =>
                      synchronous || frame != null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.rose,
                          ),
                        ),
                  errorBuilder: (context, error, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.muted,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('core_image_load_failed'),
                          style: TextStyle(fontSize: 12, color: colors.ink),
                        ),
                        TextButton(
                          onPressed: () async {
                            await provider.evict();
                            if (mounted) setState(() => _retry++);
                          },
                          child: Text(context.tr('calendar_retry_load')),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
