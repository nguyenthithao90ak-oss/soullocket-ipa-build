import 'dart:io';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';

class R2NetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const R2NetworkImage(
    this.imageUrl, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  // RAM cache tĩnh để tránh chớp nháy khi widget rebuild
  static final Map<String, File> _resolvedNetworkFiles = {};

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    if (cleanUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // Nếu là file asset cục bộ
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    // Nếu file đã có sẵn trong RAM cache và tồn tại trên đĩa, nạp đồng bộ ngay lập tức
    final cachedFile = _resolvedNetworkFiles[cleanUrl];
    if (cachedFile != null && cachedFile.existsSync()) {
      return Image.file(
        cachedFile,
        fit: fit,
        width: width,
        height: height,
      );
    }

    // Dùng Disk Cache cục bộ không qua SQLite
    return FutureBuilder<File?>(
      future: const StorageDownloadCacheHelper().getCachedNetworkFile(
        cleanUrl,
        namespace: 'network_images',
        ttl: const Duration(days: 14), // Cache 14 ngày
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _buildPlaceholder();
        }

        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          // Lưu vào RAM cache để lần rebuild sau nạp đồng bộ ngay lập tức
          _resolvedNetworkFiles[cleanUrl] = file;
          return Image.file(
            file,
            fit: fit,
            width: width,
            height: height,
          );
        }

        // Tải online trực tiếp nếu cache đĩa chưa sẵn sàng
        return Image.network(
          cleanUrl,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ?? _buildPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Colors.grey.withOpacity(0.05),
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

  Widget _buildErrorWidget() {
    if (errorWidget != null) return errorWidget!;
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withOpacity(0.05),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.withOpacity(0.3),
        size: width != null ? width! * 0.4 : 24,
      ),
    );
  }
}
