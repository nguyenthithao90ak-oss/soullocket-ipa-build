import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import '../../../../../utils/services/cloudflare_r2_service.dart';
class MemoryZoomDraggableWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final ValueNotifier<double> bgOpacityNotifier;
  final ValueNotifier<bool> isZoomedInNotifier;
  final ValueNotifier<Offset> dragOffsetNotifier;
  final ValueNotifier<double> dragScaleNotifier;

  const MemoryZoomDraggableWrapper({
    super.key,
    required this.child,
    required this.onDismiss,
    required this.bgOpacityNotifier,
    required this.isZoomedInNotifier,
    required this.dragOffsetNotifier,
    required this.dragScaleNotifier,
  });

  @override
  State<MemoryZoomDraggableWrapper> createState() =>
      _MemoryZoomDraggableWrapperState();
}

class _MemoryZoomDraggableWrapperState extends State<MemoryZoomDraggableWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragY = 0.0;
  double _dragStartAnimY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _controller.addListener(() {
      setState(() {
        final double curveValue = CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ).value;
        _dragY = _dragStartAnimY * (1.0 - curveValue);
        _updateOpacity();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateOpacity() {
    widget.bgOpacityNotifier.value = (1.0 - (_dragY / 320.0)).clamp(0.0, 1.0);
    widget.dragOffsetNotifier.value = Offset(0, _dragY);
    widget.dragScaleNotifier.value = (1.0 - (_dragY / 380.0)).clamp(0.35, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (details) {
        if (widget.isZoomedInNotifier.value) return;
        _controller.stop();
        _dragStartAnimY = _dragY;
      },
      onVerticalDragUpdate: (details) {
        if (widget.isZoomedInNotifier.value) return;
        setState(() {
          _dragY += details.delta.dy;
          if (_dragY < 0.0) _dragY = 0.0;
          _updateOpacity();
        });
      },
      onVerticalDragEnd: (details) {
        if (widget.isZoomedInNotifier.value) return;
        final velocity = details.primaryVelocity ?? 0;
        if (_dragY > 140 || velocity > 250) {
          widget.onDismiss();
        } else {
          _dragStartAnimY = _dragY;
          _controller.forward(from: 0.0);
        }
      },
      child: widget.child,
    );
  }
}

class MemoryViewerPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final ValueNotifier<Offset> dragOffsetNotifier;
  final ValueNotifier<double> dragScaleNotifier;
  final ValueNotifier<bool> isZoomedInNotifier;
  final VoidCallback onLongPress;
  final ImageProvider<Object> Function(String, {int? maxWidth})
      imageProviderBuilder;

  const MemoryViewerPage({
    super.key,
    required this.item,
    required this.dragOffsetNotifier,
    required this.dragScaleNotifier,
    required this.isZoomedInNotifier,
    required this.onLongPress,
    required this.imageProviderBuilder,
  });

  @override
  State<MemoryViewerPage> createState() => _MemoryViewerPageState();
}

class _MemoryViewerPageState extends State<MemoryViewerPage> {
  late final ImageProvider<Object> _imageProvider;
  late final TransformationController _transformationController;
  late final ValueNotifier<bool> _panEnabledVN;

  bool get _isVideo {
    final type = widget.item['type']?.toString().toLowerCase();
    if (type == 'video') return true;
    final url = (widget.item['url']?.toString() ?? '').toLowerCase();
    return url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.webm') ||
        url.endsWith('.m4v') ||
        url.endsWith('.3gp') ||
        url.endsWith('.mkv') ||
        url.endsWith('.avi');
  }

  @override
  void initState() {
    super.initState();
    _imageProvider = widget.imageProviderBuilder(
      widget.item['url']?.toString() ?? '',
      maxWidth: 2200,
    );
    _transformationController = TransformationController();
    _panEnabledVN = ValueNotifier<bool>(false);

    _transformationController.addListener(_handleTransformChanged);
  }

  void _handleTransformChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final shouldEnablePan = scale > 1.02;
    if (_panEnabledVN.value != shouldEnablePan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _panEnabledVN.value = shouldEnablePan;
          widget.isZoomedInNotifier.value = shouldEnablePan;
        }
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    _panEnabledVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      child: ValueListenableBuilder<bool>(
        valueListenable: _panEnabledVN,
        builder: (context, panEnabled, _) {
          return AnimatedBuilder(
            animation: Listenable.merge(
                [widget.dragOffsetNotifier, widget.dragScaleNotifier]),
            builder: (context, child) {
              return Transform.translate(
                offset: widget.dragOffsetNotifier.value,
                child: Transform.scale(
                  scale: widget.dragScaleNotifier.value,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: panEnabled,
                    minScale: 1.0,
                    maxScale: 4.5,
                    boundaryMargin:
                        panEnabled ? const EdgeInsets.all(24) : EdgeInsets.zero,
                    clipBehavior: Clip.none,
                    interactionEndFrictionCoefficient: 0.00008,
                    child: _isVideo
                        ? _MemoryVideoWidget(
                            url: widget.item['url']?.toString() ?? '',
                            houseId: widget.item['houseId']?.toString() ??
                                widget.item['house_id']?.toString(),
                            memoryId: widget.item['id']?.toString(),
                          )
                        : Hero(
                            tag: 'memory_image_${widget.item['id']}',
                            child: Image(
                              image: _imageProvider,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              filterQuality: FilterQuality.medium,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MemoryVideoWidget extends StatefulWidget {
  final String url;
  final String? houseId;
  final String? memoryId;

  const _MemoryVideoWidget({
    required this.url,
    this.houseId,
    this.memoryId,
  });

  @override
  State<_MemoryVideoWidget> createState() => _MemoryVideoWidgetState();
}

class _MemoryVideoWidgetState extends State<_MemoryVideoWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      String playUrl = widget.url.trim();
      if (playUrl.isEmpty &&
          widget.houseId != null &&
          widget.houseId!.isNotEmpty &&
          widget.memoryId != null &&
          widget.memoryId!.isNotEmpty) {
        try {
          final res = await PrivateMediaUrlService().resolve(
            houseId: widget.houseId!,
            mediaId: widget.memoryId!,
            kind: 'memory_image',
          );
          playUrl = res.url;
        } catch (_) {}
      }

      if (playUrl.isEmpty) {
        if (mounted) setState(() => _hasError = true);
        return;
      }

      playUrl = CloudflareR2Service.resolveVideoUrl(playUrl);

      final uri = Uri.parse(playUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        controller.setLooping(true);
        controller.play();
      }
    } catch (e) {
      debugPrint('[MemoryVideo] Play error: $e');
      if (widget.houseId != null &&
          widget.houseId!.isNotEmpty &&
          widget.memoryId != null &&
          widget.memoryId!.isNotEmpty) {
        try {
          final res = await PrivateMediaUrlService().resolve(
            houseId: widget.houseId!,
            mediaId: widget.memoryId!,
            kind: 'memory_image',
          );
          final freshPlayUrl = CloudflareR2Service.resolveVideoUrl(res.url);
          final freshUri = Uri.parse(freshPlayUrl);
          final controller = VideoPlayerController.networkUrl(freshUri);
          _controller = controller;
          await controller.initialize();
          if (mounted) {
            setState(() => _initialized = true);
            controller.setLooping(true);
            controller.play();
            return;
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Không thể phát video',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _initialized = false;
                });
                _initVideo();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (value.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'Không thể phát video',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _initialized = false;
                    });
                    _initVideo();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final isPlaying = value.isPlaying;
        final isBuffering = value.isBuffering;
        final size = value.size;
        final hasValidSize = size.width > 0 && size.height > 0;

        return GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: hasValidSize
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio:
                              value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                          child: VideoPlayer(controller),
                        ),
                      ),
              ),
              if (isBuffering)
                const CircularProgressIndicator(color: Colors.white)
              else if (!isPlaying)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
