part of 'short_video_feed_screen.dart';

// ─── Single Short Video Post ──────────────────────────────────
class _ShortVideoFeedPostCard extends StatefulWidget {
  final SocialPost post;
  final String houseId;
  final Map<String, dynamic> blockedUsers;
  final bool isActive;
  final Function(Offset) onDoubleTap;

  const _ShortVideoFeedPostCard({
    super.key,
    required this.post,
    required this.houseId,
    required this.blockedUsers,
    required this.isActive,
    required this.onDoubleTap,
  });

  @override
  State<_ShortVideoFeedPostCard> createState() =>
      _ShortVideoFeedPostCardState();
}

class _ShortVideoFeedPostCardState extends State<_ShortVideoFeedPostCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _likeCtrl;
  late Animation<double> _likeAnim;
  bool _liked = false;
  int _likeCount = 0;
  bool _showHeart = false;
  VideoPlayerController? _videoCtrl;
  bool _isVideoInitialized = false;
  bool _isPreparingVideo = false;
  int _videoLoadToken = 0;

  String get _mediaUrl => widget.post.videoUrl.isNotEmpty
      ? widget.post.videoUrl
      : widget.post.imageUrl;
  bool get _isVideo => widget.post.videoUrl.isNotEmpty;
  String _mediaUrlFor(SocialPost post) =>
      post.videoUrl.isNotEmpty ? post.videoUrl : post.imageUrl;
  bool _isVideoPost(SocialPost post) => post.videoUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _likeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _likeCtrl, curve: Curves.elasticOut),
    );
    _syncPostState();

    if (_isVideo && widget.isActive) {
      unawaited(_ensureVideoReady());
    }
  }

  void _syncPostState() {
    _likeCount = widget.post.likesCount;
    _liked = false;
    _showHeart = false;
    unawaited(_checkIfLiked());
  }

  void _resetVideoState({bool disposeController = false}) {
    _videoLoadToken++;
    _isPreparingVideo = false;
    _isVideoInitialized = false;
    final controller = _videoCtrl;
    _videoCtrl = null;
    if (disposeController && controller != null) {
      unawaited(controller.dispose());
    }
  }

  Future<void> _ensureVideoReady() async {
    if (!_isVideo ||
        _mediaUrl.isEmpty ||
        _isVideoInitialized ||
        _isPreparingVideo) {
      return;
    }
    final loadToken = ++_videoLoadToken;
    _isPreparingVideo = true;

    VideoPlayerController controller;
    File? cachedFile;
    try {
      final fileInfo =
          await AppCacheManager.instance.getFileFromCache(_mediaUrl);
      if (fileInfo != null) {
        cachedFile = fileInfo.file;
      } else {
        cachedFile = await AppCacheManager.instance.getSingleFile(_mediaUrl);
      }
    } catch (e) {
      debugPrint('Failed to cache video: $e');
    }

    if (cachedFile != null) {
      controller = VideoPlayerController.file(cachedFile);
    } else {
      controller = VideoPlayerController.networkUrl(Uri.parse(_mediaUrl));
    }

    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted || loadToken != _videoLoadToken) {
        await controller.dispose();
        return;
      }
      final previousController = _videoCtrl;
      _videoCtrl = controller;
      _isVideoInitialized = true;
      if (previousController != null) {
        unawaited(previousController.dispose());
      }
      if (widget.isActive) {
        unawaited(controller.play());
      }
      setState(() {});
    } catch (_) {
      await controller.dispose();
    } finally {
      if (loadToken == _videoLoadToken) {
        _isPreparingVideo = false;
      }
    }
  }

  Future<void> _checkIfLiked() async {
    final postId = widget.post.id;
    if (postId.isEmpty) return;
    try {
      final isLiked = await SocialService().hasLiked(
        postId,
        widget.houseId,
      );

      if (isLiked && mounted) {
        setState(() {
          _liked = true;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isVideoInitialized || _videoCtrl == null) return;
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_videoCtrl!.play());
      return;
    }
    unawaited(_videoCtrl!.pause());
  }

  @override
  void didUpdateWidget(covariant _ShortVideoFeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final didPostChange = widget.post.id != oldWidget.post.id ||
        _mediaUrlFor(widget.post) != _mediaUrlFor(oldWidget.post) ||
        _isVideoPost(widget.post) != _isVideoPost(oldWidget.post);

    if (didPostChange) {
      _resetVideoState(disposeController: true);
      _syncPostState();
      if (mounted) {
        setState(() {});
      }
      if (_isVideo && widget.isActive) {
        unawaited(_ensureVideoReady());
      }
      return;
    }

    if (widget.post.likesCount != oldWidget.post.likesCount &&
        !_likeCtrl.isAnimating) {
      _likeCount = widget.post.likesCount;
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        unawaited(_ensureVideoReady());
        if (_videoCtrl != null) {
          unawaited(_videoCtrl!.play());
        }
      } else {
        if (_videoCtrl != null) {
          unawaited(_videoCtrl!.pause());
          unawaited(_videoCtrl!.seekTo(Duration.zero));
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoLoadToken++;
    _likeCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _doLike({Offset? pos}) async {
    final postId = widget.post.id;
    if (postId.isEmpty) return;

    if (_likeCtrl.isAnimating) return;

    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });

    if (_liked) {
      if (pos != null) widget.onDoubleTap(pos);
      setState(() => _showHeart = true);
      _likeCtrl.forward(from: 0).then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _showHeart = false);
        });
      });
    } else {
      _likeCtrl.reverse();
    }

    try {
      await SocialService().toggleLike(
        postId: postId,
        myHouseId: widget.houseId,
      );
    } catch (_) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likeCount += _liked ? 1 : -1;
        });
      }
    }
  }

  void _showComments() {
    if (!widget.post.commentsEnabled && widget.post.houseId != widget.houseId) {
      SLNotice.showInfo(context, context.tr('home_bivitnyang_350b57'));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentSheet(
        postId: widget.post.id,
        houseId: widget.houseId,
        blockedUsers: widget.blockedUsers,
      ),
    );
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (widget.post.houseId == widget.houseId)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(context.tr('home_xabivit_2c7199'),
                      style: SLTheme.quicksand()),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await SocialService().deletePost(
                        postId: widget.post.id,
                        requestingHouseId: widget.houseId,
                      );
                      if (!mounted || !context.mounted) return;
                      SLNotice.showSuccess(
                          context, context.tr('home_xabivit_55f95f'));
                    } catch (e) {
                      debugPrint(
                        'Delete post failed: ${AppErrorMapper.resolve(
                          e,
                          fallbackMessage: context.tr('home_clixyra_775791'),
                        ).message}',
                      );
                      if (!mounted || !context.mounted) return;
                      SLNotice.showError(
                        context,
                        context.tr('home_chathxabiv_72f417'),
                      );
                    }
                  },
                )
              else ...[
                ListTile(
                  leading:
                      const Icon(Icons.flag_outlined, color: Colors.orange),
                  title: Text(context.tr('home_bocobivit_08313a'),
                      style: SLTheme.quicksand()),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await SocialService().reportPost(
                        postId: widget.post.id,
                        reporterHouseId: widget.houseId,
                        reason: 'reported_by_user',
                      );
                      if (!mounted || !context.mounted) return;
                      SLNotice.showSuccess(
                        context,
                        context.tr('home_gibocotiqu_efe49e'),
                      );
                    } catch (e) {
                      debugPrint(
                        'Report post failed: ${AppErrorMapper.resolve(
                          e,
                          fallbackMessage: context.tr('home_clixyra_775791'),
                        ).message}',
                      );
                      if (!mounted || !context.mounted) return;
                      SLNotice.showError(
                        context,
                        context.tr('home_chathgiboc_05046c'),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.red),
                  title: Text(context.tr('home_chnngidngn_27d0c8'),
                      style: SLTheme.quicksand(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    final targetHouseId = widget.post.houseId;
                    if (targetHouseId.isEmpty) return;
                    final genericErrorMessage =
                        context.tr('home_clixyra_775791');

                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.tr('home_xcnhnchn_ae00a6'),
                            style:
                                SLTheme.quicksand(fontWeight: FontWeight.w900)),
                        content: Text(
                            'Bạn có chắc muốn chặn người này không?\nHọ sẽ không thể xem nhà bạn nữa.',
                            style: SLTheme.quicksand()),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(context.tr('home_hy_1e4050'))),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(context.tr('home_chn_483b6f'),
                                  style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    try {
                      await SocialService().blockHouse(
                        sourceHouseId: widget.houseId,
                        targetHouseId: targetHouseId,
                      );
                    } catch (e) {
                      debugPrint(
                        'Block house failed: ${AppErrorMapper.resolve(
                          e,
                          fallbackMessage: genericErrorMessage,
                        ).message}',
                      );
                      if (!mounted || !context.mounted) return;
                      SLNotice.showError(
                        context,
                        context.tr('home_chathchnng_81d840'),
                      );
                      return;
                    }

                    if (!mounted || !context.mounted) return;
                    SLNotice.showSuccess(
                        context, context.tr('home_chnngidngn_adcaff'));
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String get _caption => widget.post.content;
  String get _houseName => widget.post.houseName;
  String get _avatar => widget.post.authorAvt;
  bool get _isImagePost => !_isVideo && _mediaUrl.isNotEmpty;

  Widget _buildMediaBackground() {
    if (_isVideo) {
      if (_isVideoInitialized && _videoCtrl != null) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoCtrl!.value.size.width,
              height: _videoCtrl!.value.size.height,
              child: RepaintBoundary(
                child: VideoPlayer(_videoCtrl!),
              ),
            ),
          ),
        );
      }

      return Container(
        color: const Color(0xFF120716),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E8C)),
        ),
      );
    }

    if (_mediaUrl.isEmpty) {
      return Container(color: const Color(0xFF120716));
    }

    final uiState = UiPrefs.notifier.value;
    final graphicsQuality = uiState.liteMode
        ? 'low'
        : (uiState.graphicsQualityKey == 'auto'
            ? UiPrefs.getAutoGraphicsQuality()
            : uiState.graphicsQualityKey);
    final useLiteBackdrop = kIsWeb || graphicsQuality == 'low';
    final mediaCacheWidth = switch (graphicsQuality) {
      'high' => 1800,
      'low' => 900,
      _ => 1280,
    };
    final mediaFilterQuality =
        graphicsQuality == 'low' ? FilterQuality.low : FilterQuality.medium;

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          cacheManager: AppCacheManager.instance,
          maxWidthDiskCache: mediaCacheWidth,
          memCacheWidth: mediaCacheWidth,
          imageUrl: _mediaUrl,
          fit: BoxFit.cover,
          filterQuality: mediaFilterQuality,
          fadeInDuration: const Duration(milliseconds: 150),
          fadeOutDuration: Duration.zero,
          placeholder: (_, _) => Container(color: const Color(0xFF120716)),
          errorWidget: (_, _, _) =>
              Container(color: const Color(0xFF120716)),
        ),
        if (!useLiteBackdrop)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Transform.scale(
                scale: 1.08,
                child: Opacity(
                  opacity: 0.82,
                  child: CachedNetworkImage(
                    cacheManager: AppCacheManager.instance,
                    maxWidthDiskCache: mediaCacheWidth,
                    memCacheWidth: mediaCacheWidth,
                    imageUrl: _mediaUrl,
                    fit: BoxFit.cover,
                    filterQuality: mediaFilterQuality,
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFF120716)),
                    errorWidget: (context, url, error) =>
                        Container(color: const Color(0xFF120716)),
                  ),
                ),
              ),
            ),
          ),
        if (!useLiteBackdrop) ...[
          Positioned(
            top: -110,
            right: -50,
            child: _buildAmbientOrb(
              const [Color(0xFFFF729D), Color(0x00FF729D)],
              220,
            ),
          ),
          Positioned(
            bottom: 120,
            left: -70,
            child: _buildAmbientOrb(
              const [Color(0xFF7BE0FF), Color(0x007BE0FF)],
              240,
            ),
          ),
        ],
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.22, 0.62, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmbientOrb(List<Color> colors, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }

  Widget _buildImageShowcase(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, kToolbarHeight + 18, 18, 148),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFF9AC2).withValues(alpha: 0.52),
                            const Color(0xFF7BE0FF).withValues(alpha: 0.26),
                            const Color(0xFFFFD58C).withValues(alpha: 0.24),
                          ],
                        ),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF6F9F).withValues(alpha: 0.22),
                            blurRadius: 28,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 34,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF09060A)
                                    .withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF161018),
                                            Color(0xFF09060A),
                                          ],
                                        ),
                                      ),
                                    ),
                                    InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 4,
                                      child: SizedBox.expand(
                                        child: CachedNetworkImage(
                                          cacheManager:
                                              AppCacheManager.instance,
                                          maxWidthDiskCache: 2400,
                                          memCacheWidth:
                                              1800, // RAM optimization
                                          imageUrl: _mediaUrl,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          filterQuality: FilterQuality.medium,
                                          placeholder: (context, url) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFFFF7EA8),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Center(
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.white30,
                                              size: 60,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel({required bool highlightImage}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF8AB2).withValues(alpha: 0.95),
                    const Color(0xFF7BE0FF).withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE91E8C),
                backgroundImage: _avatar.isNotEmpty
                    ? CachedNetworkImageProvider(_avatar,
                        maxWidth: 128, maxHeight: 128)
                    : null,
                child: _avatar.isEmpty
                    ? const Icon(Icons.home, size: 18, color: Colors.white)
                    : null,
              ),
            ),
            SLSpacing.w10,
            Expanded(
              child: Text(
                _houseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_caption.isNotEmpty) ...[
          SLSpacing.h10,
          Text(
            _caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            maxLines: highlightImage ? 4 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (highlightImage) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildActionRail({required bool highlightImage}) {
    final content = Column(
      children: [
        _SideAction(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          label: '$_likeCount',
          color: _liked ? const Color(0xFFFF5A86) : Colors.white,
          onTap: _doLike,
        ),
        SLSpacing.h20,
        _SideAction(
          icon: Icons.comment_outlined,
          label: '${widget.post.comments}',
          onTap: _showComments,
        ),
        SLSpacing.h20,
        _SideAction(
          icon: Icons.share_outlined,
          label: context.tr('home_chias_569031'),
          onTap: () {},
        ),
        SLSpacing.h20,
        _SideAction(
          icon: Icons.more_horiz,
          label: context.tr('home_thm_d9cb42'),
          onTap: _showPostOptions,
        ),
      ],
    );

    if (highlightImage) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightImage = _isImagePost;

    return GestureDetector(
      onDoubleTapDown: (details) => _doLike(pos: details.globalPosition),
      onDoubleTap:
          () {}, // Triggered by onDoubleTapDown for Gray's precise timing
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildMediaBackground(),
          if (highlightImage) _buildImageShowcase(context),
          if (_showHeart)
            Center(
              child: ScaleTransition(
                scale: _likeAnim,
                child:
                    const Icon(Icons.favorite, color: Colors.white, size: 100),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 98,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildInfoPanel(highlightImage: highlightImage),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 80,
            child: SafeArea(
              child: _buildActionRail(highlightImage: highlightImage),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color == Colors.white
                      ? Colors.white.withValues(alpha: 0.20)
                      : color.withValues(alpha: 0.92),
                  color == Colors.white
                      ? Colors.white.withValues(alpha: 0.06)
                      : color.withValues(alpha: 0.56),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          SLSpacing.h6,
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              shadows: [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
