import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';

bool isAnimatedRabbitStickerAsset(String assetPath) {
  final path = assetPath.trim().toLowerCase();
  return path.startsWith('assets/images/anhtomau_stickers/') ||
      path.startsWith('assets/images/sticker_import/cutout/');
}

/// Giữ API cũ cho tin nhắn đã gửi. GIF tự phát khung hình, không rung thêm ảnh.
class AnimatedRabbitSticker extends StatelessWidget {
  const AnimatedRabbitSticker(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.isAntiAlias = true,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isAntiAlias;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => R2StickerImage(
    assetPath,
    width: width,
    height: height,
    fit: fit,
    errorWidget: errorBuilder == null
        ? null
        : Builder(
            builder: (context) =>
                errorBuilder!(context, StateError('Sticker unavailable'), null),
          ),
  );
}
