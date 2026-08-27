import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';
import 'package:lottie/lottie.dart';

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

  static const Set<String> _bundledHomeStickers = {
    'assets/images/interaction_stickers/custom/numbered/sticker_001.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_002.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_003.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_004.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_045.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_046.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_047.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_048.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_049.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_050.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_051.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_052.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_053.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_054.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_055.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_056.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_057.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_058.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_059.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_060.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_108.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_158.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_160.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_162.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_165.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_173.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_228.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_270.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_276.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_291.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_339.png',
    'assets/images/interaction_stickers/custom/numbered/sticker_343.png'
  };

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    if (_bundledHomeStickers.contains(assetPath)) {
      return Image.asset(
        assetPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorWidget != null
            ? (context, error, stackTrace) => errorWidget!
            : null,
      );
    }

    if (assetPath.startsWith('assets/images/interaction_stickers/') || assetPath.startsWith('http')) {
      final r2Url = assetPath.startsWith('http') 
          ? assetPath 
          : '${AppConfig.r2PublicDomain}/stickers/${assetPath.substring('assets/images/'.length)}';
      
      final isLottieUrl = r2Url.toLowerCase().endsWith('.json') || r2Url.toLowerCase().endsWith('.lottie');

      // Nếu file đã được nạp và lưu trong RAM cache, trả về trực tiếp Image.file (hoặc Lottie.file) đồng bộ để không bị nháy
      final cachedFile = _resolvedStickerFiles[r2Url];

      if (cachedFile != null && cachedFile.existsSync()) {
        if (isLottieUrl) {
          return Lottie.file(
            cachedFile,
            fit: fit,
            width: width,
            height: height,
          );
        }
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
            if (isLottieUrl) {
              return Lottie.file(
                file,
                fit: fit,
                width: width,
                height: height,
              );
            }
            return Image.file(
              file,
              fit: fit,
              width: width,
              height: height,
              cacheWidth: width != null ? (width! * 2).toInt() : 400,
            );
          }

          if (isLottieUrl) {
            return Lottie.network(
              r2Url,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: errorWidget != null
                  ? (context, error, stackTrace) => errorWidget!
                  : null,
            );
          }

          return CachedNetworkImage(
            imageUrl: r2Url,
            fit: fit,
            width: width,
            height: height,
            memCacheWidth: width != null ? (width! * 2).toInt() : 400,
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
            errorWidget: (context, url, error) {
              if (errorWidget != null) return errorWidget!;
              return Image.asset(
                assetPath,
                fit: fit,
                width: width,
                height: height,
                errorBuilder: (context, err, stack) => Container(
                  width: width,
                  height: height,
                  color: Colors.grey.withValues(alpha: 0.05),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey.withValues(alpha: 0.3),
                    size: width != null ? width! * 0.4 : 24,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // Fallback cho ảnh asset thông thường (hoặc Lottie)
    final lowerPath = assetPath.toLowerCase();
    if (lowerPath.endsWith('.json') || lowerPath.endsWith('.lottie')) {
      return Lottie.asset(
        assetPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorWidget != null
            ? (context, error, stackTrace) => errorWidget!
            : null,
      );
    }

    return Image.asset(
      assetPath,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorWidget != null
          ? (context, error, stackTrace) => errorWidget!
          : null,
    );
  }
}
