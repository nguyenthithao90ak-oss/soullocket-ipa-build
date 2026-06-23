part of '../../community_tab.dart';

class _FeedImagePreview extends StatefulWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;
  final String imageUrl;

  const _FeedImagePreview({
    required this.state,
    required this.post,
    required this.imageUrl,
  });

  @override
  State<_FeedImagePreview> createState() => _FeedImagePreviewState();
}

class _FeedImagePreviewState extends State<_FeedImagePreview> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImageRatio();
  }

  @override
  void didUpdateWidget(covariant _FeedImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _detachImageListener();
      _resolvedAspectRatio = null;
      _resolveImageRatio();
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    super.dispose();
  }

  void _detachImageListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _resolveImageRatio() {
    if (widget.imageUrl.isEmpty) {
      return;
    }

    final provider = CachedNetworkImageProvider(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (width <= 0 || height <= 0) {
          return;
        }

        final nextRatio = (width / height).clamp(0.72, 1.28).toDouble();
        if (!mounted || _resolvedAspectRatio == nextRatio) {
          return;
        }
        setState(() => _resolvedAspectRatio = nextRatio);
      },
      onError: (_, __) {},
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeightCap =
        (MediaQuery.sizeOf(context).height * 0.68).clamp(320.0, 620.0);

    return GestureDetector(
      onDoubleTapDown: (details) {
        widget.state._toggleLike(widget.post, position: details.globalPosition);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final aspectRatio = _resolvedAspectRatio ?? 0.92;
            final previewHeight = (constraints.maxWidth / aspectRatio)
                .clamp(260.0, mediaHeightCap);

            return Container(
              width: double.infinity,
              height: previewHeight,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.98),
                    const Color(0xFFF7F9FE).withValues(alpha: 0.96),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.96),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 24,
                    spreadRadius: -12,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ManualRetryCachedImage(
                      imageUrl: widget.imageUrl,
                      width: double.infinity,
                      height: previewHeight,
                      fit: BoxFit.cover,
                      backgroundColor: const Color(0xFFF3F5FB),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.02),
                              Colors.transparent,
                              const Color(0xFF0F172A).withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0, 0.58, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeedVideoPreview extends StatelessWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;

  const _FeedVideoPreview({
    required this.state,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) {
        state._toggleLike(post, position: details.globalPosition);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: SLRadius.xlAll,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 54,
                ),
                SLSpacing.h8,
                Text(
                  _ct(
                    context.tr('home_bivitcvide_9dd50b'),
                    'This post has an attached video',
                  ),
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
