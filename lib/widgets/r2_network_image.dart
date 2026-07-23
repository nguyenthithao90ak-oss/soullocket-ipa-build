import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';

class R2NetworkImage extends StatefulWidget {
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

  // RAM cache tĩnh để tránh chớp nháy tuyệt đối khi bất kỳ widget nào rebuild
  static final Map<String, File> _resolvedNetworkFiles = {};

  @override
  State<R2NetworkImage> createState() => _R2NetworkImageState();
}

class _R2NetworkImageState extends State<R2NetworkImage> {
  Future<File?>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _initFutureIfNeeded();
  }

  @override
  void didUpdateWidget(covariant R2NetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initFutureIfNeeded();
    }
  }

  void _initFutureIfNeeded() {
    final cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.isEmpty || cleanUrl.startsWith('assets/')) {
      _fileFuture = null;
      return;
    }
    if (R2NetworkImage._resolvedNetworkFiles.containsKey(cleanUrl)) {
      _fileFuture = null;
      return;
    }
    _fileFuture = const StorageDownloadCacheHelper().getCachedNetworkFile(
      cleanUrl,
      namespace: 'network_images',
      ttl: const Duration(days: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.imageUrl.trim();

    if (cleanUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // Nếu là file asset cục bộ
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    // Nạp đồng bộ ngay lập tức từ RAM cache nếu đã sẵn sàng (0ms flicker)
    final cachedFile = R2NetworkImage._resolvedNetworkFiles[cleanUrl];
    if (cachedFile != null && cachedFile.existsSync()) {
      return Image.file(
        cachedFile,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    // Nếu không có future (trường hợp khẩn cấp), nạp trực tiếp bằng CachedNetworkImage
    if (_fileFuture == null) {
      return _buildCachedNetworkImage(cleanUrl);
    }

    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ?? _buildPlaceholder();
        }

        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          R2NetworkImage._resolvedNetworkFiles[cleanUrl] = file;
          return Image.file(
            file,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            cacheWidth: widget.width != null ? (widget.width! * 2).toInt() : 800,
          );
        }

        return _buildCachedNetworkImage(cleanUrl);
      },
    );
  }

  Widget _buildCachedNetworkImage(String cleanUrl) {
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: widget.width != null ? (widget.width! * 2).toInt() : 800,
      placeholder: (context, url) => widget.placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      color: Colors.grey.withValues(alpha: 0.05),
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
    if (widget.errorWidget != null) return widget.errorWidget!;
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.withValues(alpha: 0.05),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.withValues(alpha: 0.3),
        size: widget.width != null ? widget.width! * 0.4 : 24,
      ),
    );
  }
}
