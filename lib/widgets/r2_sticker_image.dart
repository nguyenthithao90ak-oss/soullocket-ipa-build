import 'dart:io';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';
import 'package:soullocket_app/core/constants/app_config.dart';

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

  // Lưu trữ in-memory cache của các sticker file đã được nạp thành công để tránh nháy khi rebuild
  static final Map<String, File> _resolvedStickerFiles = {};

  @override
  Widget build(BuildContext context) {
    // Chỉ các sticker tương tác (nằm trong thư mục interaction_stickers) mới chuyển sang nạp từ R2
    if (assetPath.startsWith('assets/images/interaction_stickers/')) {
      final String filename = assetPath.substring('assets/images/'.length);
      final String r2Url = '${AppConfig.r2PublicDomain}/stickers/$filename';
      
      // Nếu file đã được nạp và lưu trong RAM cache, trả về trực tiếp Image.file đồng bộ để không bị nháy
      final cachedFile = _resolvedStickerFiles[r2Url];
      if (cachedFile != null && cachedFile.existsSync()) {
        return Image.file(
          cachedFile,
          fit: fit,
          width: width,
          height: height,
        );
      }

      return FutureBuilder<File?>(
        future: const StorageDownloadCacheHelper().getCachedNetworkFile(
          r2Url,
          namespace: 'stickers',
          ttl: const Duration(days: 30),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
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
            );
          }

          final file = snapshot.data;
          if (file != null && file.existsSync()) {
            // Lưu vào RAM cache để các lần build tiếp theo nạp đồng bộ ngay lập tức
            _resolvedStickerFiles[r2Url] = file;
            return Image.file(
              file,
              fit: fit,
              width: width,
              height: height,
            );
          }

          return Image.network(
            r2Url,
            fit: fit,
            width: width,
            height: height,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
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
              );
            },
            errorBuilder: (context, error, stackTrace) {
              if (errorWidget != null) return errorWidget!;
              return Image.asset(
                assetPath,
                fit: fit,
                width: width,
                height: height,
                errorBuilder: (context, err, stack) => Container(
                  width: width,
                  height: height,
                  color: Colors.grey.withOpacity(0.05),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey.withOpacity(0.3),
                    size: width != null ? width! * 0.4 : 24,
                  ),
                ),
              );
            },
          );
        },
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
