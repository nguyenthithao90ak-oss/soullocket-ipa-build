import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../core/sl_theme.dart';
import '../../../models/diary_post.dart';
import '../../../utils/app_cache_manager.dart';
import '../../../utils/services/cloudflare_r2_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/r2_sticker_image.dart';
import '../../../widgets/soullocket_animated_sticker.dart';

class DiaryItem extends StatelessWidget {
  final DiaryPost post;
  final String activeRoleKey;
  final String nameU1;
  final String nameU2;
  final String resolvedAuthorName;
  final int? postImageCacheWidth;
  final Function(DiaryPost) onConfirmDelete;

  const DiaryItem({
    super.key,
    required this.post,
    required this.activeRoleKey,
    required this.nameU1,
    required this.nameU2,
    this.resolvedAuthorName = '',
    required this.postImageCacheWidth,
    required this.onConfirmDelete,
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
    final authorColor = authorRole == 'user1'
        ? const Color(0xFF349F91)
        : authorRole == 'user2'
        ? const Color(0xFF766FD0)
        : const Color(0xFFE28C6D);
    final moodColor = _getMoodColor(post.mood);
    final isShortText = post.content.trim().length < 30;
    final moodSize = isShortText ? 78.0 : 58.0;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFFDF8),
              Color.alphaBlend(
                moodColor.withValues(alpha: 0.09),
                const Color(0xFFF8FBFA),
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: moodColor.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -36,
                child: Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    color: moodColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 22,
                bottom: 22,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: moodColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 17, 17, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: authorColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: authorColor.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: authorColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy • HH:mm',
                          ).format(post.timestamp),
                          style: SLTheme.quicksand(
                            color: const Color(0xFF85899A),
                            fontSize: 11.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isMyPost) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onConfirmDelete(post),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3EF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                size: 17,
                                color: Color(0xFFC98275),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 13),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: moodColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              post.content,
                              textAlign: isShortText
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: SLTheme.quicksand(
                                fontWeight: isShortText
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: isShortText ? 17.5 : 14.7,
                                height: isShortText ? 1.4 : 1.55,
                                color: const Color(0xFF3B4354),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: moodSize + 8,
                            height: moodSize + 8,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: moodColor.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: R2StickerImage(
                                _getMoodAsset(post.mood),
                                width: moodSize,
                                height: moodSize,
                                fit: BoxFit.contain,
                                animateLocalSticker: isShortText,
                                errorWidget: Text(
                                  post.mood,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isShortText ? 34 : 25,
                                    color: moodColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                              color: moodColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('home_ghimtms_3f794c'),
                              style: SLTheme.quicksand(
                                color: moodColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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

class _DiaryItemVideoWidgetState extends State<_DiaryItemVideoWidget> {
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
      final String rawUrl = widget.url.trim();
      final playUrl = CloudflareR2Service.resolveVideoUrl(rawUrl);
      final uri = Uri.parse(playUrl);

      VideoPlayerController controller;
      try {
        final fileInfo = await AppCacheManager.instance.getFileFromCache(
          playUrl,
        );
        final cachedFile =
            fileInfo?.file ??
            await AppCacheManager.instance.getSingleFile(playUrl);
        controller = VideoPlayerController.file(cachedFile);
      } catch (_) {
        controller = VideoPlayerController.networkUrl(uri);
      }

      _controller = controller;
      await controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        controller.setLooping(true);
      }
    } catch (_) {
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
      return Container(
        height: 140,
        color: Colors.black26,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white70, size: 28),
            SizedBox(height: 4),
            Text(
              'Không thể phát video',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return Container(
        height: 160,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE98FB1)),
        ),
      );
    }

    final isPlaying = controller.value.isPlaying;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
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

String _getMoodAsset(String moodEmoji) {
  switch (moodEmoji) {
    case '😍':
      return SoulLocketStickerCatalog.referenceFor('diary_playful');
    case '💖':
      return SoulLocketStickerCatalog.referenceFor('diary_healing');
    case '🤩':
      return SoulLocketStickerCatalog.referenceFor('diary_proud');
    case '🤒':
      return SoulLocketStickerCatalog.referenceFor('diary_healing');
    case '🌧️':
      return SoulLocketStickerCatalog.referenceFor('diary_anxious');
    case '📝':
      return SoulLocketStickerCatalog.referenceFor('diary_reflective');
    case '🙈':
      return SoulLocketStickerCatalog.referenceFor('diary_shy');
    case '💌':
      return SoulLocketStickerCatalog.referenceFor('diary_missing');
    case '⭐':
      return SoulLocketStickerCatalog.referenceFor('diary_proud');
    case '🌙':
      return SoulLocketStickerCatalog.referenceFor('diary_sleepy');
    case '🥺':
      return SoulLocketStickerCatalog.referenceFor('diary_anxious');
    case '😤':
      return SoulLocketStickerCatalog.referenceFor('diary_grumpy');
    case '😉':
      return SoulLocketStickerCatalog.referenceFor('diary_playful');
    case '❤️‍🩹':
      return SoulLocketStickerCatalog.referenceFor('diary_healing');
    default:
      return SoulLocketStickerCatalog.referenceFor('diary_reflective');
  }
}

Color _getMoodColor(String moodEmoji) {
  switch (moodEmoji) {
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
