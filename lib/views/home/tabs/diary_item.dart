import 'dart:io';
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
    final isMyPost = (currentUid.isNotEmpty && authorId == currentUid) ||
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

    // Phân biệt màu sắc theo vai (Nam: Xanh dương, Nữ: Hồng)
    final isMale = authorRole == 'user1';
    final isFemale = authorRole == 'user2';
    final Color accentColor = isMale
        ? const Color(0xFF0288D1)
        : (isFemale ? _diarySoftPink : const Color(0xFF7B1FA2));

    final isShortText = post.content.trim().length < 30;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SLTheme.glassCard(
          margin: EdgeInsets.zero,
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayName,
                    style: SLTheme.quicksand(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(post.timestamp),
                  style: SLTheme.quicksand(
                    color: SLColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMyPost) ...[
                  SLSpacing.w12,
                  GestureDetector(
                    onTap: () => onConfirmDelete(post),
                    child: Icon(
                      Icons.delete_rounded,
                      size: 20,
                      color: SLColors.textTertiary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
            SLSpacing.h16,
            if (isShortText) ...[
              Center(
                child: Text(
                  post.content,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.4,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
              SLSpacing.h16,
              Center(
                child: Image.asset(
                  _getMoodAsset(post.mood),
                  width: 84,
                  height: 84,
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      post.mood,
                      style: TextStyle(fontSize: 36, color: accentColor),
                    );
                  },
                ),
              ),
            ] else ...[
              Text(
                post.content,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.6,
                  color: SLColors.textPrimary,
                ),
              ),
              SLSpacing.h12,
              Image.asset(
                _getMoodAsset(post.mood),
                width: 32,
                height: 32,
                gaplessPlayback: true,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    post.mood,
                    style: TextStyle(fontSize: 20, color: accentColor),
                  );
                },
              ),
            ],
            if (post.imageUrl.isNotEmpty) ...[
              SLSpacing.h16,
              ClipRRect(
                borderRadius: SLRadius.lgAll,
                child: () {
                  final url = post.imageUrl.toLowerCase();
                  final isVideo = url.endsWith('.mp4') ||
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
                      color: Colors.white.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFE98FB1)),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.white.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_rounded,
                          color: Color(0xFFE98FB1), size: 26),
                    ),
                  );
                }(),
              ),
            ],
            if (post.pinned) ...[
              SLSpacing.h16,
              Row(
                children: [
                  const Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: SLColors.accent,
                  ),
                  SLSpacing.w8,
                  Text(
                    L10nService().translate(context.tr('home_ghimtms_3f794c')),
                    style: SLTheme.quicksand(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

const Color _diarySoftPink = Color(0xFFE98FB1);

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
        File? cachedFile;
        final fileInfo = await AppCacheManager.instance.getFileFromCache(playUrl);
        if (fileInfo != null) {
          cachedFile = fileInfo.file;
        } else {
          cachedFile = await AppCacheManager.instance.getSingleFile(playUrl);
        }
        if (cachedFile != null) {
          controller = VideoPlayerController.file(cachedFile);
        } else {
          controller = VideoPlayerController.networkUrl(uri);
        }
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
    case '😍': return 'assets/images/anhtomau_stickers/sticker_20.gif';
    case '💖': return 'assets/images/anhtomau_stickers/sticker_9.gif';
    case '🤩': return 'assets/images/anhtomau_stickers/sticker_3.gif';
    case '🤒': return 'assets/images/anhtomau_stickers/sticker_8.gif';
    case '🌧️': return 'assets/images/anhtomau_stickers/sticker_24.gif';
    default: return 'assets/images/anhtomau_stickers/sticker_9.gif';
  }
}
