import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class DiaryPublicMemoryImage extends StatefulWidget {
  const DiaryPublicMemoryImage({
    super.key,
    required this.imageProvider,
    this.previewImageProvider,
    this.loadTimeout = const Duration(seconds: 15),
  });

  final ImageProvider<Object>? imageProvider;
  final ImageProvider<Object>? previewImageProvider;
  final Duration loadTimeout;

  @override
  State<DiaryPublicMemoryImage> createState() => _DiaryPublicMemoryImageState();
}

class _DiaryPublicMemoryImageState extends State<DiaryPublicMemoryImage> {
  final List<({ImageStream stream, ImageStreamListener listener})> _listeners = [];
  ImageInfo? _fullImage;
  ImageInfo? _previewImage;
  ImageInfo? _retainedImage;
  Timer? _deadline;
  int _generation = 0;
  bool _started = false;
  bool _subscribing = false;
  bool _fullFailed = false;
  bool _previewFailed = false;
  bool _timedOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) _start();
  }

  @override
  void didUpdateWidget(covariant DiaryPublicMemoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.previewImageProvider != widget.previewImageProvider) {
      _start();
    }
  }

  void _disconnect() {
    _deadline?.cancel();
    for (final entry in _listeners) {
      entry.stream.removeListener(entry.listener);
    }
    _listeners.clear();
  }

  void _releaseAfterFrame(ImageInfo? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  void _start() {
    _started = true;
    final generation = ++_generation;
    _disconnect();
    final previousImage = _fullImage ?? _previewImage;
    if (widget.imageProvider == null) {
      _releaseAfterFrame(previousImage);
      _releaseAfterFrame(_retainedImage);
      _retainedImage = null;
    } else if (previousImage != null) {
      _releaseAfterFrame(_retainedImage);
      _retainedImage = previousImage;
    }
    _fullImage = null;
    _previewImage = null;
    _fullFailed = widget.imageProvider == null;
    _previewFailed = widget.previewImageProvider == null;
    _timedOut = false;
    if (widget.imageProvider == null) return;
    _deadline = Timer(widget.loadTimeout, () {
      if (!mounted || generation != _generation || _fullImage != null) return;
      setState(() {
        _timedOut = true;
        _releaseAfterFrame(_retainedImage);
        _retainedImage = null;
      });
    });
    _subscribing = true;
    try {
      final preview = widget.previewImageProvider;
      if (preview != null) _listen(preview, generation, preview: true);
      _listen(widget.imageProvider!, generation, preview: false);
    } finally {
      _subscribing = false;
    }
  }

  void _listen(ImageProvider<Object> provider, int generation, {required bool preview}) {
    try {
      final stream = provider.resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener(
        (image, synchronous) {
          if (!mounted || generation != _generation) {
            image.dispose();
            return;
          }
          void apply() {
            if (preview) {
              _releaseAfterFrame(_previewImage);
              _previewImage = image;
              _previewFailed = false;
            } else {
              _releaseAfterFrame(_fullImage);
              _fullImage = image;
              _fullFailed = false;
              _timedOut = false;
              _deadline?.cancel();
            }
            if (_retainedImage != null) {
              _releaseAfterFrame(_retainedImage);
              _retainedImage = null;
            }
          }
          if (_subscribing) {
            apply();
          } else {
            setState(apply);
          }
        },
        onError: (Object error, StackTrace? stack) {
          if (!mounted || generation != _generation) return;
          void apply() {
            if (preview) {
              _previewFailed = true;
            } else {
              _fullFailed = true;
            }
            if (_fullFailed && _previewFailed) {
              _deadline?.cancel();
              _releaseAfterFrame(_retainedImage);
              _retainedImage = null;
            }
          }
          if (_subscribing) {
            apply();
          } else {
            setState(apply);
          }
        },
      );
      _listeners.add((stream: stream, listener: listener));
      stream.addListener(listener);
    } catch (_) {
      if (preview) {
        _previewFailed = true;
      } else {
        _fullFailed = true;
      }
    }
  }

  Future<void> _retry() async {
    final generation = ++_generation;
    _disconnect();
    try {
      await widget.imageProvider?.evict();
      await widget.previewImageProvider?.evict();
    } catch (_) {}
    if (!mounted || generation != _generation) return;
    setState(_start);
  }

  @override
  void dispose() {
    _generation++;
    _disconnect();
    _fullImage?.dispose();
    _previewImage?.dispose();
    _retainedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Khi đổi ảnh, ưu tiên frame cũ cho tới khi ảnh đầy đủ mới sẵn sàng;
    // preview mới không được thay thế đột ngột bằng một frame đang giải mã.
    final image = _fullImage ?? _retainedImage ?? _previewImage;
    if (image != null) {
      return RawImage(
        image: image.image,
        scale: image.scale,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }
    if (_timedOut || (_fullFailed && _previewFailed)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 42),
              const SizedBox(height: 12),
              Text(context.tr('core_image_load_failed'), style: const TextStyle(color: Colors.white70)),
              if (widget.imageProvider != null)
                TextButton.icon(
                  onPressed: _retry,
                  style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('retry')),
                ),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}
