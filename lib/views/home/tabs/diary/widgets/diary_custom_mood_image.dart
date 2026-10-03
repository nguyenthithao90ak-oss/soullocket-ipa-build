import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/services/custom_mood_sticker_service.dart';
import '../../../../../utils/services/l10n_service.dart';

class DiaryCustomMoodImage extends StatelessWidget {
  const DiaryCustomMoodImage({
    super.key,
    required this.url,
    required this.size,
    this.stickerService,
  });

  final String? url;
  final double size;
  final CustomMoodStickerService? stickerService;

  @override
  Widget build(BuildContext context) {
    final stickers = stickerService ?? CustomMoodStickerService.instance;
    final imageUrl = url?.trim() ?? '';
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(1, CustomMoodStickerService.maxImageSize);
    Widget unavailable() => Tooltip(
      message: context.tr('core_image_load_failed'),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF8873BD),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ValueListenableBuilder<String?>(
        valueListenable: stickers.customStickerUrlVN,
        builder: (context, _, _) {
          if (imageUrl.isEmpty) return unavailable();
          final preview = stickers.previewBytesFor(imageUrl);
          if (preview != null) {
            return Image.memory(
              preview,
              width: size,
              height: size,
              cacheWidth: cacheWidth,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => unavailable(),
            );
          }
          return CachedNetworkImage(
            imageUrl: imageUrl,
            width: size,
            height: size,
            memCacheWidth: cacheWidth,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => const Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8873BD),
                ),
              ),
            ),
            errorWidget: (_, _, _) => unavailable(),
          );
        },
      ),
    );
  }
}
