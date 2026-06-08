part of '../../main_home_tab.dart';

// class _MainHomeAvatarSection extends StatelessWidget {
//   final _MainHomeTabState state;
//   final bool isSingle;
//   final String nameU1;
//   final String nameU2;
//   final String avtUser1;
//   final String avtUser2;
//   final String houseAvatar;
//
//   const _MainHomeAvatarSection({
//
//     required this.state,
//     required this.isSingle,
//     required this.nameU1,
//     required this.nameU2,
//     required this.avtUser1,
//     required this.avtUser2,
//     required this.houseAvatar,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final dobU1 = state._houseSettings?['dobU1']?.toString() ?? '';
//     final dobU2 = state._houseSettings?['dobU2']?.toString() ?? '';
//
//     final z1 = ZodiacUtils.getZodiac(dobU1);
//     final z2 = ZodiacUtils.getZodiac(dobU2);
//     final ageDaysU1 = state._extractAgeDays(dobU1);
//     final ageDaysU2 = state._extractAgeDays(dobU2);
//
//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.7),
//         borderRadius: BorderRadius.circular(35),
//         boxShadow: [
//           BoxShadow(
//               color: const Color(0xFFD81B60).withValues(alpha: 0.14),
//               blurRadius: 32,
//               offset: const Offset(0, 8)),
//         ],
//         border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2.5),
//       ),
//       child: isSingle
//           ? Column(
//               children: [
//                 Container(
//                   width: 140,
//                   height: 140,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     border:
//                         Border.all(color: const Color(0xFFFF80AB), width: 3),
//                     boxShadow: [
//                       BoxShadow(
//                           color: const Color(0xFFFF80AB).withValues(alpha: 0.4),
//                           blurRadius: 20,
//                           offset: const Offset(0, 4))
//                     ],
//                   ),
//                   child: ClipRRect(
//                     borderRadius: SLRadius.pillAll,
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             color: const Color(0xFF1E293B),
//                             child: const Icon(Icons.favorite,
//                                 color: Colors.white24, size: 40),
//                           ),
//                         ),
//                         Expanded(
//                           child: Container(
//                             color: const Color(0xFFFF80AB),
//                             child: const Icon(Icons.favorite,
//                                 color: Colors.white, size: 40),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 SLSpacing.h12,
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Flexible(
//                       child: Text(nameU1,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: SLTheme.quicksand(
//                               fontSize: 22,
//                               fontWeight: FontWeight.w900,
//                               color: const Color(0xFF9C27B0))),
//                     ),
//                     if (state._shouldShowAdminBadge('user1'))
//                       state._buildAdminBadge(
//                         iconSize: 15,
//                         padding: const EdgeInsets.only(left: 6),
//                       ),
//                   ],
//                 ),
//                 SLSpacing.h8,
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Container(
//                       width: 28,
//                       height: 28,
//                       alignment: Alignment.center,
//                       decoration: const BoxDecoration(
//                           color: Color(0xFFFFF4E5), shape: BoxShape.circle),
//                       child: Text(z1?['emoji'] ?? '✨',
//                           style: const TextStyle(fontSize: 14)),
//                     ),
//                     SLSpacing.w8,
//                     Container(
//                       constraints: const BoxConstraints(maxWidth: 120),
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 14, vertical: 4),
//                       decoration: BoxDecoration(
//                           color: const Color(0xFFFFE3F1),
//                           borderRadius: SLRadius.lgAll),
//                       child: Text(
//                           ageDaysU1 == '0'
//                               ? '--'
//                               : state._formatAgeForDisplay(ageDaysU1),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: SLTheme.quicksand(
//                               fontSize: 13,
//                               fontWeight: FontWeight.w900,
//                               color: const Color(0xFFD81B60))),
//                     ),
//                   ],
//                 ),
//               ],
//             )
//           : Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Expanded(
//                   child: _LegacyUserColumn(
//                     state: state,
//                     name: nameU1,
//                     avatarUrl: avtUser1,
//                     zodiacEmoji: z1?['emoji'] ?? '✦',
//                     ageDays: ageDaysU1,
//                     role: 'user1',
//                     weatherText: state._weatherTextForRole('user1', isUser1: true),
//                     statusText: state._presenceStatusText('user1'),
//                     statusColor: state._presenceStatusColor('user1'),
//                     isUser1: true,
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.only(top: 24),
//                   child: state._buildRelationshipCenterAction(isSingle: false),
//                 ),
//                 Expanded(
//                   child: _LegacyUserColumn(
//                     state: state,
//                     name: nameU2,
//                     avatarUrl: avtUser2,
//                     zodiacEmoji: z2?['emoji'] ?? '✦',
//                     ageDays: ageDaysU2,
//                     role: 'user2',
//                     weatherText: state._weatherTextForRole('user2', isUser1: false),
//                     statusText: state._presenceStatusText('user2'),
//                     statusColor: state._presenceStatusColor('user2'),
//                     isUser1: false,
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }

class _StableAvatarNetworkImage extends StatefulWidget {
  final String imageUrl;
  final String fallbackAsset;
  final BoxFit fit;

  const _StableAvatarNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
  });

  @override
  State<_StableAvatarNetworkImage> createState() =>
      _StableAvatarNetworkImageState();
}

class _StableAvatarNetworkImageState extends State<_StableAvatarNetworkImage> {
  ImageProvider<Object>? _currentProvider;
  ImageProvider<Object>? _lastSuccessfulProvider;
  ImageProvider<Object>? _diskCachedProvider;
  String _currentUrl = '';
  String _lastSuccessfulUrl = '';
  bool _isCurrentImageReady = false;
  bool _hasCurrentImageError = false;

  @override
  void initState() {
    super.initState();
    _syncImageProvider();
  }

  @override
  void didUpdateWidget(covariant _StableAvatarNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = oldWidget.imageUrl.trim();
    final newUrl = widget.imageUrl.trim();
    if (oldUrl != newUrl ||
        oldWidget.fallbackAsset != widget.fallbackAsset ||
        oldWidget.fit != widget.fit) {
      _syncImageProvider();
    }
  }

  void _syncImageProvider() {
    final normalizedUrl = widget.imageUrl.trim();
    _currentUrl = normalizedUrl;
    _hasCurrentImageError = false;

    if (normalizedUrl.isEmpty) {
      _currentProvider = null;
      _diskCachedProvider = null;
      _isCurrentImageReady = false;
      return;
    }

    _currentProvider = CachedNetworkImageProvider(
      normalizedUrl,
      maxWidth: 720,
      maxHeight: 720,
    );
    final startupFile = HomeStartupMediaCache.getFile(normalizedUrl);
    _diskCachedProvider = startupFile != null ? FileImage(startupFile) : null;
    _isCurrentImageReady = normalizedUrl == _lastSuccessfulUrl;
    if (_diskCachedProvider == null) {
      unawaited(_loadDiskCachedProvider(normalizedUrl));
    }
  }

  Future<void> _loadDiskCachedProvider(String url) async {
    try {
      final cachedFile = await DefaultCacheManager().getFileFromCache(url);
      if (!mounted || _currentUrl != url) return;
      final file = cachedFile?.file;
      if (file == null || !await file.exists()) return;
      setState(() {
        _diskCachedProvider = FileImage(file);
      });
    } catch (_) {}
  }

  void _markCurrentImageReady() {
    if (!mounted || _isCurrentImageReady || _currentProvider == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isCurrentImageReady || _currentProvider == null) return;
      setState(() {
        _isCurrentImageReady = true;
        _lastSuccessfulProvider = _currentProvider;
        _lastSuccessfulUrl = _currentUrl;
      });
    });
  }

  void _markCurrentImageError() {
    if (!mounted || _hasCurrentImageError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasCurrentImageError) return;
      setState(() {
        _hasCurrentImageError = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProvider == null || _currentUrl.isEmpty) {
      return Image.asset(
        widget.fallbackAsset,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    final placeholderProvider = _lastSuccessfulProvider ?? _diskCachedProvider;
    final placeholder = placeholderProvider != null
        ? Image(
            image: placeholderProvider,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          )
        : Image.asset(
            widget.fallbackAsset,
            fit: widget.fit,
            gaplessPlayback: true,
          );

    if (_hasCurrentImageError) {
      return placeholder;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_isCurrentImageReady) placeholder,
        Image(
          image: _currentProvider!,
          fit: widget.fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              _markCurrentImageReady();
            }
            return child;
          },
          errorBuilder: (_, __, ___) {
            _markCurrentImageError();
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

extension _MainHomeAvatarSectionExt on _MainHomeTabState {
  // Web: .love-time-cell CSS clone
  // flex:0 0 98px; min-height:92px; border-radius:18px;
  // gradient alternating xanh/hồng, box-shadow 0 8px 20px rgba(37,99,235,0.16)
  Widget _buildTimeCell(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: SLTheme.quicksand(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    String name,
    String url, {
    required bool isUser1,
    double? size,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isUploading = false,
    bool isSinglePlaceholder = false,
  }) {
    // Nếu tham số size được truyền vào (từ _LegacyAvatarSection), dùng luôn size đó.
    // Nếu không có, mới lấy từ UiPrefs.
    final effectiveSize = size ?? UiPrefs.notifier.value.avatarSizePx;
    final avatarUrl = url.trim();
    final frameKey =
        isSinglePlaceholder ? 'circle' : UiPrefs.notifier.value.avatarFrameKey;
    final framePadding =
        LegacyWebUi.avatarFramePaddingForKey(frameKey, effectiveSize);
    final frameRadius =
        LegacyWebUi.avatarBorderRadiusForKey(frameKey, effectiveSize);
    final frameIsCircle = LegacyWebUi.avatarFrameIsCircle(frameKey);
    final fallbackAsset = isUser1
        ? 'assets/images/avatar_male.jpg'
        : 'assets/images/avatar_female.jpg';
    final avatarContent = isSinglePlaceholder
        ? const Center(
            child: Icon(
              Icons.question_mark_rounded,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
          )
        : _StableAvatarNetworkImage(
            key: ValueKey<String>(
              'home-avatar-${isUser1 ? 'user1' : 'user2'}',
            ),
            imageUrl: avatarUrl,
            fallbackAsset: fallbackAsset,
            fit: BoxFit.cover,
          );

    final showChooseImageHint =
        avatarUrl.isEmpty && !isUploading && !isSinglePlaceholder;
    final clippedAvatar = frameIsCircle
        ? ClipOval(child: avatarContent)
        : ClipRRect(
            borderRadius: frameRadius,
            child: avatarContent,
          );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        onLongPress: isUploading ? null : onLongPress,
        child: SizedBox(
          width: effectiveSize,
          height: effectiveSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Avatar Circle
              Align(
                alignment: Alignment.center,
                child: isSinglePlaceholder
                    ? Container(
                        width: effectiveSize,
                        height: effectiveSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3F4F6),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: framePadding,
                          child: clippedAvatar,
                        ),
                      )
                    : frameKey == 'vip'
                        ? SlAnimatedVipFrame(
                            size: effectiveSize,
                            padding: framePadding,
                            isCircle: frameIsCircle,
                            borderRadius: frameRadius,
                            child: avatarContent,
                          )
                        : Container(
                            width: effectiveSize,
                            height: effectiveSize,
                            decoration: LegacyWebUi.avatarFrameDecoration(
                              frameKey,
                              effectiveSize,
                              accentColor: isUser1
                                  ? LegacyWebUi.accentPink
                                  : LegacyWebUi.accentBlue,
                            ),
                            child: Padding(
                              padding: framePadding,
                              child: clippedAvatar,
                            ),
                          ),
              ),
              if (showChooseImageHint)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _BlinkingAvatarHint(),
                  ),
                ),
              // Uploading Indicator
              if (isUploading)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: effectiveSize,
                    height: effectiveSize,
                    decoration: BoxDecoration(
                      shape:
                          frameIsCircle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: frameIsCircle ? null : frameRadius,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.9)),
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

//   Widget _buildQuestionAvatarPlaceholder() {
//     return Container(
//       color: const Color(0xFFD1D5DB),
//       alignment: Alignment.center,
//       child: Text(
//         '?',
//         style: SLTheme.quicksand(
//           fontSize: 28,
//           fontWeight: FontWeight.w900,
//           color: const Color(0xFF6B7280),
//         ),
//       ),
//     );
//   }
}
