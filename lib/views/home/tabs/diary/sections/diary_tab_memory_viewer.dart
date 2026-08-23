part of '../../diary_tab.dart';

extension DiaryTabMemoryViewer on _DiaryTabState {
  void _showMemoryZoom(
    Map<String, dynamic> initialItem,
    List<Map<String, dynamic>> allPhotos,
  ) {
    // Refresh signed URL cho item hiện tại trước khi mở viewer
    unawaited(_memoryController.ensureMemoryPhotoUrl(
      houseId: _houseId ?? '',
      item: initialItem,
    ));

    final initialIndex =
        allPhotos.indexWhere((photo) => photo['id'] == initialItem['id']);
    int currentIndex = initialIndex < 0 ? 0 : initialIndex;
    final pageController = PageController(initialPage: currentIndex);
    _warmMemoryViewerAroundIndex(allPhotos, currentIndex);

    Navigator.push<void>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final bgOpacityNotifier = ValueNotifier<double>(1.0);
          final isZoomedInNotifier = ValueNotifier<bool>(false);
          final dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
          final dragScaleNotifier = ValueNotifier<double>(1.0);

          return StatefulBuilder(
            builder: (context, setState) {
              final currentItem =
                  allPhotos.isNotEmpty ? allPhotos[currentIndex] : initialItem;

              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: bgOpacityNotifier,
                        builder: (context, dragOpacity, _) {
                          // Nền xung quanh tối hẳn (1.0) để làm nổi bật ảnh
                          final double opacity =
                              1.0 * dragOpacity * animation.value;
                          return Container(
                            color: Colors.black.withValues(alpha: opacity),
                          );
                        },
                      );
                    },
                  ),
                  _MemoryZoomDraggableWrapper(
                    onDismiss: () => Navigator.pop(dialogContext),
                    bgOpacityNotifier: bgOpacityNotifier,
                    isZoomedInNotifier: isZoomedInNotifier,
                    dragOffsetNotifier: dragOffsetNotifier,
                    dragScaleNotifier: dragScaleNotifier,
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      body: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(color: Colors.transparent),
                          ),
                          if (allPhotos.isNotEmpty)
                            PageView.builder(
                              controller: pageController,
                              physics: const ClampingScrollPhysics(),
                              itemCount: allPhotos.length,
                              onPageChanged: (index) {
                                setState(() {
                                  currentIndex = index;
                                });
                                isZoomedInNotifier.value = false;
                                _warmMemoryViewerAroundIndex(allPhotos, index);
                                // Refresh signed URL cho item mới
                                unawaited(_memoryController.ensureMemoryPhotoUrl(
                                  houseId: _houseId ?? '',
                                  item: allPhotos[index],
                                ));
                              },
                              itemBuilder: (context, index) {
                                return _MemoryViewerPage(
                                  item: allPhotos[index],
                                  dragOffsetNotifier: dragOffsetNotifier,
                                  dragScaleNotifier: dragScaleNotifier,
                                  isZoomedInNotifier: isZoomedInNotifier,
                                  onLongPress: () => _showMemoryViewerActions(
                                      dialogContext, allPhotos[index]),
                                  imageProviderBuilder: _memoryImageProvider,
                                );
                              },
                            )
                          else
                            Builder(
                              builder: (context) => _MemoryViewerPage(
                                item: initialItem,
                                dragOffsetNotifier: dragOffsetNotifier,
                                dragScaleNotifier: dragScaleNotifier,
                                isZoomedInNotifier: isZoomedInNotifier,
                                onLongPress: () => _showMemoryViewerActions(
                                    dialogContext, initialItem),
                                imageProviderBuilder: _memoryImageProvider,
                              ),
                            ),
                          AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) {
                              return ValueListenableBuilder<double>(
                                valueListenable: bgOpacityNotifier,
                                builder: (context, dragOpacity, _) {
                                  final double baseUiOpacity =
                                      ((dragOpacity - 0.82) / 0.18)
                                          .clamp(0.0, 1.0);
                                  final double uiOpacity =
                                      baseUiOpacity * animation.value;
                                  return Opacity(
                                    opacity: uiOpacity,
                                    child: IgnorePointer(
                                      ignoring: uiOpacity < 0.5,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.black.withValues(
                                                          alpha: 0.45),
                                                      Colors.transparent,
                                                      Colors.transparent,
                                                      Colors.black.withValues(
                                                          alpha: 0.45),
                                                    ],
                                                    stops: const [
                                                      0.0,
                                                      0.15,
                                                      0.85,
                                                      1.0
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 18,
                                            right: 86,
                                            bottom: MediaQuery.of(context)
                                                    .padding
                                                    .bottom +
                                                18,
                                            child: IgnorePointer(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.42),
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.10),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFF6F91),
                                                            Color(0xFF7C8BFF)
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons.favorite_rounded,
                                                        color: Colors.white,
                                                        size: 17,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '${currentIndex + 1}/${allPhotos.isEmpty ? 1 : allPhotos.length} kỷ niệm',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: SLTheme
                                                                .quicksand(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            _formatMemoryTimestamp(
                                                                currentItem),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: SLTheme
                                                                .quicksand(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.68),
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: MediaQuery.of(context)
                                                    .padding
                                                    .top +
                                                16,
                                            left: 12,
                                            child: IconButton(
                                              tooltip:
                                                  context.tr('home_ng_f63d1e'),
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 26,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: MediaQuery.of(context)
                                                    .padding
                                                    .top +
                                                16,
                                            right: 12,
                                            child: PopupMenuButton<String>(
                                              tooltip: context
                                                  .tr('home_tychnnh_5e18e0'),
                                              padding: const EdgeInsets.all(11),
                                              icon: const Icon(
                                                Icons.more_vert_rounded,
                                                color: Colors.white,
                                                size: 23,
                                              ),
                                              color: const Color(0xFF171A21),
                                              surfaceTintColor:
                                                  const Color(0xFF171A21),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              itemBuilder: (menuContext) => [
                                                PopupMenuItem<String>(
                                                  value: 'save',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.download_rounded,
                                                        color: Colors.white,
                                                        size: 19,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        context.tr(
                                                            'home_lunh_9088ba'),
                                                        style:
                                                            SLTheme.quicksand(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'share',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.link_rounded,
                                                        color: Colors.white,
                                                        size: 19,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        context.tr(
                                                            'home_chiasnh_003604'),
                                                        style:
                                                            SLTheme.quicksand(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'info',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .info_outline_rounded,
                                                        color: Colors.white,
                                                        size: 19,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        context.tr(
                                                            'home_chititnh_958bbd'),
                                                        style:
                                                            SLTheme.quicksand(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color:
                                                            Color(0xFFFF6B6B),
                                                        size: 19,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        context.tr(
                                                            'home_xanh_0b98d1'),
                                                        style:
                                                            SLTheme.quicksand(
                                                          color: const Color(
                                                              0xFFFF6B6B),
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              onSelected: (value) async {
                                                switch (value) {
                                                  case 'save':
                                                    await _downloadSingleImage(
                                                        currentItem['url']);
                                                    break;
                                                  case 'share':
                                                    Navigator.pop(
                                                        dialogContext);
                                                    await _shareSingleMemory(
                                                        currentItem);
                                                    break;
                                                  case 'info':
                                                    await _showMemoryInfoSheet(
                                                        dialogContext,
                                                        currentItem);
                                                    break;
                                                  case 'delete':
                                                    Navigator.pop(
                                                        dialogContext);
                                                    await _deleteMemory(
                                                        currentItem);
                                                    break;
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  String _formatMemoryTimestamp(Map<String, dynamic> item) {
    final timestamp = item['ts'] as int? ?? 0;
    return DateFormat('dd/MM/yyyy • HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  Future<void> _showMemoryInfoSheet(
    BuildContext dialogContext,
    Map<String, dynamic> item,
  ) async {
    final authorName = _resolveMemoryAuthorName(item).trim();
    final postedAt = _formatMemoryTimestamp(item);

    await showModalBottomSheet<void>(
      context: dialogContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15181F).withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('home_chititnh_958bbd'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MemoryInfoTile(
                    icon: Icons.person_outline_rounded,
                    label: context.tr('home_nging_c93b87'),
                    value: authorName.isEmpty
                        ? context.tr('home_chacthngti_ad20b9')
                        : authorName,
                  ),
                  const SizedBox(height: 12),
                  _MemoryInfoTile(
                    icon: Icons.schedule_rounded,
                    label: context.tr('home_ngyng_d1c813'),
                    value: postedAt,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveMemoryAuthorName(Map<String, dynamic> item) {
    return _feedController.resolveMemoryAuthorName(item);
  }

  void _warmMemoryViewerAroundIndex(
    List<Map<String, dynamic>> allPhotos,
    int index,
  ) {
    if (!mounted || allPhotos.isEmpty) {
      return;
    }
    final int start = (index - 1).clamp(0, allPhotos.length - 1);
    final int end = (index + 1).clamp(0, allPhotos.length - 1);
    for (int i = start; i <= end; i++) {
      final url = (allPhotos[i]['url']?.toString() ?? '').trim();
      if (url.isEmpty) {
        continue;
      }
      final key = '2200|$url';
      if (!_warmedMemoryViewerKeys.add(key)) {
        continue;
      }
      unawaited(
        precacheImage(
          _memoryImageProvider(url, maxWidth: 2200),
          context,
        ),
      );
    }
  }
}

class _MemoryZoomDraggableWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final ValueNotifier<double> bgOpacityNotifier;
  final ValueNotifier<bool> isZoomedInNotifier;
  final ValueNotifier<Offset> dragOffsetNotifier;
  final ValueNotifier<double> dragScaleNotifier;

  const _MemoryZoomDraggableWrapper({
    required this.child,
    required this.onDismiss,
    required this.bgOpacityNotifier,
    required this.isZoomedInNotifier,
    required this.dragOffsetNotifier,
    required this.dragScaleNotifier,
  });

  @override
  State<_MemoryZoomDraggableWrapper> createState() =>
      _MemoryZoomDraggableWrapperState();
}

class _MemoryZoomDraggableWrapperState
    extends State<_MemoryZoomDraggableWrapper>
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

class _MemoryViewerPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final ValueNotifier<Offset> dragOffsetNotifier;
  final ValueNotifier<double> dragScaleNotifier;
  final ValueNotifier<bool> isZoomedInNotifier;
  final VoidCallback onLongPress;
  final ImageProvider<Object> Function(String, {int? maxWidth})
      imageProviderBuilder;

  const _MemoryViewerPage({
    required this.item,
    required this.dragOffsetNotifier,
    required this.dragScaleNotifier,
    required this.isZoomedInNotifier,
    required this.onLongPress,
    required this.imageProviderBuilder,
  });

  @override
  State<_MemoryViewerPage> createState() => _MemoryViewerPageState();
}

class _MemoryViewerPageState extends State<_MemoryViewerPage> {
  late final TransformationController _transformationController;
  late final ValueNotifier<bool> _panEnabledVN;
  String _lastResolvedUrl = '';
  ImageProvider<Object>? _imageProvider;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _panEnabledVN = ValueNotifier<bool>(false);
    _transformationController.addListener(_handleTransformChanged);
    _resolveImageProvider();
  }

  void _resolveImageProvider() {
    final url = widget.item['url']?.toString() ?? '';
    if (url.isNotEmpty && url != _lastResolvedUrl) {
      _lastResolvedUrl = url;
      _imageProvider = widget.imageProviderBuilder(url, maxWidth: 2200);
    }
  }

  void _handleTransformChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final shouldEnablePan = scale > 1.02;
    if (_panEnabledVN.value != shouldEnablePan) {
      _panEnabledVN.value = shouldEnablePan;
      widget.isZoomedInNotifier.value = shouldEnablePan;
    }
  }

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
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    _panEnabledVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.item['url']?.toString() ?? '';

    // Cập nhật imageProvider nếu URL đã thay đổi (do ensureMemoryPhotoUrl refresh)
    _resolveImageProvider();

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
                            url: url,
                            houseId: widget.item['houseId']?.toString() ??
                                widget.item['house_id']?.toString(),
                            memoryId: widget.item['id']?.toString(),
                          )
                        : _imageProvider != null
                            ? Hero(
                                tag: 'memory_image_${widget.item['id']}',
                                child: Image(
                                  image: _imageProvider!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
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
              label: Text(context.tr('Thử lại')),
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
                Text(
                  context.tr('Không thể phát video'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                  label: Text(context.tr('Thử lại')),
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
