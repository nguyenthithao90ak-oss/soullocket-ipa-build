import 'package:flutter/material.dart';

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
                    child: Hero(
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
