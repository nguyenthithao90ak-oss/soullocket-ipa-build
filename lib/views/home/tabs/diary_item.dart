import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/sl_theme.dart';
import '../../../models/diary_post.dart';
import '../../../utils/app_cache_manager.dart';
import '../../../utils/services/cloudflare_r2_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/locale_date_format.dart';
import '../../../widgets/r2_sticker_image.dart';
import '../../../widgets/soullocket_animated_sticker.dart';
import 'diary/widgets/diary_custom_mood_image.dart';
import 'diary/widgets/diary_item_art.dart';
import 'diary/widgets/diary_reaction_picker.dart';
import '../../../utils/screen_activity_mixin.dart';
import 'short_video_cached_video_controller.dart'
    if (dart.library.html) 'short_video_cached_video_controller_web.dart';

class DiaryItem extends StatelessWidget {
  final DiaryPost post;
  final String? houseId;
  final String activeRoleKey;
  final String nameU1;
  final String nameU2;
  final String resolvedAuthorName;
  final int? postImageCacheWidth;
  final Function(DiaryPost) onConfirmDelete;
  final VoidCallback? onLongPressReaction;
  final String? myReactionId;
  final Map<String, int> reactionCounts;

  const DiaryItem({
    super.key,
    this.houseId,
    required this.post,
    required this.activeRoleKey,
    required this.nameU1,
    required this.nameU2,
    this.resolvedAuthorName = '',
    required this.postImageCacheWidth,
    required this.onConfirmDelete,
    this.onLongPressReaction,
    this.myReactionId,
    this.reactionCounts = const <String, int>{},
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final authorId = post.authorId.trim();
    final authorRole = post.authorRole.trim().isNotEmpty
        ? post.authorRole.trim()
        : ((authorId == 'user1' || authorId == 'user2') ? authorId : '');
    final isMyPost =
        (currentUid.isNotEmpty && authorId == currentUid) ||
        (authorRole.isNotEmpty && authorRole == activeRoleKey);

    String houseNameForRole(String role) {
      switch (role) {
        case 'user1':
          return nameU1.trim();
        case 'user2':
          return nameU2.trim();
        default:
          return '';
      }
    }

    String normalizeDisplayName(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      if (trimmed == authorId ||
          trimmed == authorRole ||
          trimmed == 'user1' ||
          trimmed == 'user2') {
        return '';
      }

      final lowered = trimmed.toLowerCase();
      if (lowered == context.tr('home_ngiyu_ef6c08') ||
          lowered == 'nguoi yeu' ||
          lowered == context.tr('home_bnnam_b57724') ||
          lowered == 'ban nam' ||
          lowered == context.tr('home_bnn_be46dc') ||
          lowered == 'ban nu') {
        return '';
      }

      if (trimmed.contains('@')) {
        return trimmed.split('@').first.trim();
      }

      return trimmed;
    }

    var rawName = normalizeDisplayName(resolvedAuthorName);
    if (rawName.isEmpty) {
      rawName = normalizeDisplayName(post.authorName);
    }
    if (rawName.isEmpty) {
      rawName = normalizeDisplayName(houseNameForRole(authorRole));
    }
    if (rawName.isEmpty) {
      rawName = isMyPost
          ? context.tr('home_ti_a843eb')
          : context.tr('home_ngiy_5bab37');
    }

    final displayName = rawName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authorColor = authorRole == 'user1'
        ? const Color(0xFFB65C86)
        : authorRole == 'user2'
        ? const Color(0xFF8873BD)
        : const Color(0xFFE28C6D);
    final moodColor = _getMoodColor(post.mood);
    final nameInk = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.35), authorColor)
        : authorColor;
    final moodInk = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.32), moodColor)
        : moodColor;
    final cardBase = isDark ? SLColors.darkBgCard : SLColors.paperBlush;
    final cardTint = isDark
        ? Color.alphaBlend(
            moodColor.withValues(alpha: 0.16),
            SLColors.darkBgElevated,
          )
        : Color.alphaBlend(moodColor.withValues(alpha: 0.09), SLColors.paper);
    final contentColor = isDark
        ? SLColors.darkTextPrimary
        : SLColors.textPrimary;
    final dateColor = isDark ? SLColors.darkTextSecond : SLColors.textSecondary;
    final isShortText = post.content.trim().length < 30;
    final moodSize = isShortText ? 70.0 : 56.0;
    final contentFontSize = isShortText ? 18.0 : 15.0;
    final contentLineHeight = isShortText ? 1.45 : 1.6;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPressReaction,
      child: RepaintBoundary(
        child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cardBase, cardTint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white,
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: moodColor.withValues(alpha: isDark ? 0.20 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: [
              Positioned.fill(
                child: DiaryPostCanvasDecor(
                  accent: moodColor,
                  mood: post.mood,
                  isMine: isMyPost,
                  pinned: post.pinned,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 22, 42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: authorColor.withValues(
                                    alpha: isDark ? 0.20 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: authorColor.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    color: nameInk,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                LocaleDateFormat.dateTime(post.timestamp),
                                style: SLTheme.quicksand(
                                  color: dateColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isMyPost) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            key: ValueKey('diary-post-delete-${post.id}'),
                            tooltip: context.tr('home_xa_4ed187'),
                            onPressed: () => onConfirmDelete(post),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              fixedSize: const Size(48, 48),
                              backgroundColor: isDark
                                  ? SLColors.darkBgElevated
                                  : SLColors.paperPeach.withValues(alpha: 0.55),
                              foregroundColor: isDark
                                  ? const Color(0xFFFFB4A8)
                                  : const Color(0xFFAB6257),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    DiaryPostPaperSurface(
                      accent: moodColor,
                      lineSpacing:
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(contentFontSize) *
                          contentLineHeight,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          22,
                          18,
                          32,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final content = Text(
                              post.content,
                              key: ValueKey('diary-post-content-${post.id}'),
                              textAlign: isShortText
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: SLTheme.quicksand(
                                fontWeight: isShortText
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: contentFontSize,
                                height: contentLineHeight,
                                color: contentColor,
                              ),
                            );
                            final mood = DiaryPostMoodFrame(
                              key: ValueKey('diary-post-mood-${post.id}'),
                              accent: moodColor,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: post.mood == '📷'
                                    ? DiaryCustomMoodImage(
                                        url: post.customMoodUrl,
                                        size: moodSize,
                                      )
                                    : R2StickerImage(
                                        _getMoodAsset(
                                          post.mood,
                                          customMoodUrl: post.customMoodUrl,
                                          houseId: houseId,
                                          authorId: post.authorId,
                                        ),
                                        width: moodSize,
                                        height: moodSize,
                                        fit: BoxFit.contain,
                                        animateLocalSticker: true,
                                        errorWidget: Text(
                                          post.mood,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: isShortText ? 34 : 25,
                                            color: moodInk,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                            // Chữ lớn hoặc màn hẹp được dùng trọn chiều ngang.
                            final stacked =
                                constraints.maxWidth < 240 ||
                                MediaQuery.textScalerOf(context).scale(15) >
                                    21 ||
                                post.content.length > 110;
                            if (stacked) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  content,
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: isShortText
                                        ? Alignment.center
                                        : AlignmentDirectional.centerEnd,
                                    child: mood,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: content),
                                const SizedBox(width: 16),
                                mood,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (post.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: () {
                          final url = post.imageUrl.toLowerCase();
                          final isVideo =
                              url.endsWith('.mp4') ||
                              url.endsWith('.mov') ||
                              url.endsWith('.webm') ||
                              url.endsWith('.m4v') ||
                              url.endsWith('.3gp');
                          if (isVideo) {
                            return _DiaryItemVideoWidget(url: post.imageUrl);
                          }
                          return CachedNetworkImage(
                            cacheManager: AppCacheManager.instance,
                            imageUrl: post.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            maxWidthDiskCache: postImageCacheWidth,
                            memCacheWidth: postImageCacheWidth,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholderFadeInDuration: Duration.zero,
                            placeholder: (context, url) => Container(
                              height: 120,
                              color: moodColor.withValues(alpha: 0.06),
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    moodColor,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              height: 120,
                              color: moodColor.withValues(alpha: 0.06),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: moodColor.withValues(alpha: 0.55),
                                size: 26,
                              ),
                            ),
                          );
                        }(),
                      ),
                    ],
                    if (post.pinned) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: moodColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              size: 13,
                              color: moodInk,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                context.tr('home_ghimtms_3f794c'),
                                style: SLTheme.quicksand(
                                  color: moodInk,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (reactionCounts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DiaryReactionSummary(
                        counts: reactionCounts,
                        selectedId: myReactionId,
                      ),
                    ],
                  ],
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

class _DiaryItemVideoWidget extends StatefulWidget {
  final String url;

  const _DiaryItemVideoWidget({required this.url});

  @override
  State<_DiaryItemVideoWidget> createState() => _DiaryItemVideoWidgetState();
}

class _DiaryItemVideoWidgetState extends State<_DiaryItemVideoWidget>
    with ScreenActivityMixin<_DiaryItemVideoWidget> {
  VideoPlayerController? _controller;
  VideoPlayerController? _loadingController;
  bool _initialized = false;
  bool _hasError = false;
  bool _isLoading = false;
  bool _playAfterInitialization = false;
  bool _resumeOnActive = false;
  int _loadGeneration = 0;

  @override
  void didUpdateWidget(covariant _DiaryItemVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resetVideoState();
    }
  }

  void _resetVideoState() {
    ++_loadGeneration;
    final oldController = _controller;
    final oldLoading = _loadingController;
    _controller = null;
    _loadingController = null;
    _initialized = false;
    _hasError = false;
    _isLoading = false;
    _playAfterInitialization = false;
    _resumeOnActive = false;
    oldController?.dispose();
    if (!identical(oldLoading, oldController)) oldLoading?.dispose();
  }

  Future<void> _initVideo() async {
    if (_isLoading || _initialized) return;
    final generation = ++_loadGeneration;
    final oldController = _controller;
    final oldLoading = _loadingController;
    _loadingController = null;
    _controller = null;
    _initialized = false;
    _hasError = false;
    _isLoading = true;
    _resumeOnActive = false;
    oldController?.dispose();
    oldLoading?.dispose();
    VideoPlayerController? candidate;
    try {
      final String rawUrl = widget.url.trim();
      final playUrl = CloudflareR2Service.resolveVideoUrl(rawUrl);
      if (playUrl.isEmpty) throw const FormatException('Empty video URL');
      final uri = Uri.parse(playUrl);

      // Chỉ dùng file đã có trong cache; cache miss phát trực tiếp URL để
      // tránh tải toàn bộ video trước khi người dùng bấm phát.
      candidate = await createCachedVideoController(playUrl);
      if (!mounted || generation != _loadGeneration) {
        candidate?.dispose();
        return;
      }
      candidate ??= VideoPlayerController.networkUrl(uri);
      _loadingController = candidate;
      await candidate.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || generation != _loadGeneration) {
        await candidate.dispose();
        return;
      }
      await candidate.setLooping(true);

      if (!mounted || generation != _loadGeneration) {
        candidate.dispose();
        return;
      }
      _controller = candidate;
      _loadingController = null;
      _initialized = true;
      _hasError = false;
      _isLoading = false;
      setState(() {});
      if (_playAfterInitialization && isScreenActive) {
        _playAfterInitialization = false;
        await candidate.play();
      }
    } catch (_) {
      candidate?.dispose();
      if (mounted && generation == _loadGeneration) {
        _loadingController = null;
        _isLoading = false;
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void onScreenActivityChanged(bool active) {
    final controller = _controller;
    if (!active) {
      if (controller?.value.isPlaying == true) {
        _resumeOnActive = true;
        controller?.pause();
      }
      return;
    }
    if ((_resumeOnActive || _playAfterInitialization) &&
        _initialized &&
        controller != null &&
        controller.value.isInitialized) {
      _resumeOnActive = false;
      _playAfterInitialization = false;
      controller.play();
    }
  }

  @override
  void dispose() {
    _resetVideoState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: () {
          _hasError = false;
          _playAfterInitialization = true;
          _initVideo();
          setState(() {});
        },
        child: Container(
          height: 140,
          color: Colors.black26,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.refresh_rounded,
                color: Colors.white70,
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('ui_home_cannot_play_video_e932b6'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return GestureDetector(
        onTap: () {
          if (_isLoading) return;
          _playAfterInitialization = true;
          _initVideo();
          setState(() {});
        },
        child: Container(
          height: 160,
          color: Colors.black12,
          alignment: Alignment.center,
          child: _isLoading
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE98FB1)),
                )
              : const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white70,
                  size: 42,
                ),
        ),
      );
    }

    final isPlaying = controller.value.isPlaying;

    return GestureDetector(
      onTap: () {
        final shouldPlay = !controller.value.isPlaying;
        _resumeOnActive = false;
        if (shouldPlay) {
          controller.play();
        } else {
          controller.pause();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(controller),
          ),
          if (!isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
        ],
      ),
    );
  }
}

String _getMoodAsset(
  String moodEmoji, {
  String? customMoodUrl,
  String? houseId,
  String? authorId,
}) {
  switch (moodEmoji) {
    case '📷':
      if (customMoodUrl != null && customMoodUrl.isNotEmpty) {
        return customMoodUrl;
      }
      return SoulLocketStickerCatalog.originalReferenceFor('diary_reflective');
    case '😍':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_playful');
    case '💖':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_healing');
    case '🤩':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_proud');
    case '🤒':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_healing');
    case '🌧️':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_anxious');
    case '📝':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_reflective');
    case '🙈':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_shy');
    case '💌':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_missing');
    case '⭐':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_proud');
    case '🌙':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_sleepy');
    case '🥺':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_anxious');
    case '😤':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_grumpy');
    case '😉':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_playful');
    case '❤️‍🩹':
      return SoulLocketStickerCatalog.originalReferenceFor('diary_healing');
    default:
      return SoulLocketStickerCatalog.originalReferenceFor('diary_reflective');
  }
}

Color _getMoodColor(String moodEmoji) {
  switch (moodEmoji) {
    case '📷':
      return const Color(0xFF78909C);
    case '📝':
      return const Color(0xFF9B806E);
    case '🙈':
      return const Color(0xFFE8879D);
    case '💌':
    case '💖':
      return const Color(0xFFE0708D);
    case '⭐':
    case '🤩':
      return const Color(0xFFE7A83F);
    case '🌙':
      return const Color(0xFF7674C7);
    case '🥺':
    case '🌧️':
      return const Color(0xFF8A83C8);
    case '😤':
      return const Color(0xFFE17E68);
    case '😉':
    case '😍':
      return const Color(0xFF4E9FC4);
    case '❤️‍🩹':
    case '🤒':
      return const Color(0xFF4FAF8F);
    default:
      return const Color(0xFF6F86C9);
  }
}
