import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Chỉ xem những URL đã có trong hội thoại, không truy vấn thêm lịch sử.
class SoulMergePhotoViewer extends StatefulWidget {
  const SoulMergePhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.imageProviderBuilder,
  });
  final List<String> urls;
  final int initialIndex;
  final ImageProvider Function(String)? imageProviderBuilder;

  static Future<void> show(
    BuildContext context, {
    required List<String> urls,
    required int initialIndex,
    ImageProvider Function(String)? imageProviderBuilder,
  }) {
    if (urls.isEmpty) return Future.value();
    return slPush<void>(
      context,
      SoulMergePhotoViewer(
        key: const ValueKey('soul-merge-photo-viewer'),
        urls: urls,
        initialIndex: initialIndex,
        imageProviderBuilder: imageProviderBuilder,
      ),
      fullscreenDialog: true,
    );
  }

  @override
  State<SoulMergePhotoViewer> createState() => _SoulMergePhotoViewerState();
}

class _SoulMergePhotoViewerState extends State<SoulMergePhotoViewer> {
  late final PageController _pages;
  final TransformationController _zoom = TransformationController();
  late int _index;
  bool _isZoomed = false;
  Offset _doubleTapPoint = Offset.zero;
  int _retry = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.urls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pages = PageController(initialPage: _index);
    _zoom.addListener(_onZoomChanged);
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _setZoom(double scale, Offset center) {
    final target = scale.clamp(1.0, 5.0);
    _zoom.value = Matrix4.identity()
      ..translateByDouble(
        -center.dx * (target - 1),
        -center.dy * (target - 1),
        0,
        1,
      )
      ..scaleByDouble(target, target, 1, 1);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17151B),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('soul-photo-close'),
                  tooltip: context.tr('close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
                Expanded(
                  child: Text(
                    context.tr('community_compose_action_photo'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 18),
                  child: Text(
                    '${widget.urls.isEmpty ? 0 : _index + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Color(0xFFD5C9D1)),
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final center = Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight / 2,
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: PageView.builder(
                          controller: _pages,
                          physics: _isZoomed
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(),
                          itemCount: widget.urls.length,
                          onPageChanged: (index) {
                            _zoom.value = Matrix4.identity();
                            setState(() => _index = index);
                          },
                          itemBuilder: (context, index) {
                            final provider =
                                widget.imageProviderBuilder?.call(
                                  widget.urls[index],
                                ) ??
                                CachedNetworkImageProvider(widget.urls[index]);
                            final image = Image(
                              key: ValueKey('soul-photo-$index-$_retry'),
                              image: provider,
                              fit: BoxFit.contain,
                              frameBuilder:
                                  (context, child, frame, synchronous) =>
                                      synchronous || frame != null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFF5A8B8),
                                            strokeWidth: 2,
                                          ),
                                        ),
                              errorBuilder: (context, error, stack) => Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 38,
                                      color: Color(0xFFE4C4CF),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      context.tr('core_image_load_failed'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await provider.evict();
                                        if (mounted) setState(() => _retry++);
                                      },
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(
                                        context.tr('calendar_retry_load'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (index != _index) return image;
                            return GestureDetector(
                              onDoubleTapDown: (details) =>
                                  _doubleTapPoint = details.localPosition,
                              onDoubleTap: () => _setZoom(
                                _isZoomed ? 1 : 2.5,
                                _doubleTapPoint,
                              ),
                              child: InteractiveViewer(
                                key: const ValueKey('soul-photo-zoom'),
                                transformationController: _zoom,
                                minScale: 1,
                                maxScale: 5,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: image,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (widget.urls.length > 1 && !_isZoomed) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: context.tr('p4_soul_photo_previous'),
                            color: Colors.white,
                            onPressed: _index > 0
                                ? () => _pages.previousPage(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: context.tr('p4_soul_photo_next'),
                            color: Colors.white,
                            onPressed: _index < widget.urls.length - 1
                                ? () => _pages.nextPage(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF302830),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: const ValueKey('soul-photo-zoom-out'),
                                tooltip: context.tr('p4_soul_photo_zoom_out'),
                                color: Colors.white,
                                onPressed: () => _setZoom(
                                  _zoom.value.getMaxScaleOnAxis() - 0.75,
                                  center,
                                ),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              IconButton(
                                key: const ValueKey('soul-photo-reset'),
                                tooltip: context.tr('p4_soul_photo_reset'),
                                color: Colors.white,
                                onPressed: () =>
                                    _zoom.value = Matrix4.identity(),
                                icon: const Icon(Icons.fit_screen_rounded),
                              ),
                              IconButton(
                                key: const ValueKey('soul-photo-zoom-in'),
                                tooltip: context.tr('p4_soul_photo_zoom_in'),
                                color: Colors.white,
                                onPressed: () => _setZoom(
                                  _zoom.value.getMaxScaleOnAxis() + 0.75,
                                  center,
                                ),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                context.tr('p4_soul_photo_zoom_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFC8B8C1), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
