import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_cache_manager.dart';

class R2StickerImage extends StatelessWidget {
  final String assetPath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const R2StickerImage(
    this.assetPath, {
    super.key,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Nếu đường dẫn chỉ đến sticker trong assets/images thì chuyển sang nạp từ R2
    if (assetPath.startsWith('assets/images/')) {
      final String filename = assetPath.substring('assets/images/'.length);
      final String r2Url = '${AppConfig.r2PublicDomain}/stickers/$filename';
      
      return CachedNetworkImage(
        imageUrl: r2Url,
        cacheManager: AppCacheManager.instance,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4F93)),
            ),
          ),
        ),
        errorWidget: errorWidget != null
            ? (context, url, error) => errorWidget!
            : (context, url, error) => Image.asset(
                  assetPath,
                  fit: fit,
                  width: width,
                  height: height,
                ),
      );
    }

    // Fallback cho ảnh asset thông thường khác
    return Image.asset(
      assetPath,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorWidget != null ? (context, error, stackTrace) => errorWidget! : null,
    );
  }
}
