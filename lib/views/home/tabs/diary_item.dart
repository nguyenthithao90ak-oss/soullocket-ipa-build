import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/sl_theme.dart';
import '../../../models/diary_post.dart';
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
      rawName = isMyPost ? context.tr('home_ti_a843eb') : context.tr('home_ngiy_5bab37');
    }

    final displayName = rawName;

    // Phân biệt màu sắc theo vai (Nam: Xanh dương, Nữ: Hồng)
    final isMale = authorRole == 'user1';
    final isFemale = authorRole == 'user2';
    final Color accentColor = isMale 
        ? const Color(0xFF0288D1) 
        : (isFemale ? _diarySoftPink : const Color(0xFF7B1FA2));

    final isShortText = post.content.trim().length < 30;

    return Container(
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: SLRadius.mdAll,
                    border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$displayName ${post.mood}',
                    style: SLTheme.quicksand(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(post.timestamp),
                  style: SLTheme.quicksand(
                    color: SLColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isMyPost) ...[
                  SLSpacing.w12,
                  GestureDetector(
                    onTap: () => onConfirmDelete(post),
                    child: Icon(
                      Icons.delete_rounded,
                      size: 18,
                      color: Colors.grey.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ],
            ),
            SLSpacing.h16,
            // Quote Card cho bài viết ngắn, hiển thị dạng Quote to, in nghiêng, căn giữa kèm dấu ngoặc kép watermark mờ ảo
            if (isShortText)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -6,
                    top: -16,
                    child: Text(
                      '“',
                      style: TextStyle(
                        fontSize: 72,
                        color: accentColor.withValues(alpha: 0.07),
                        fontWeight: FontWeight.w900,
                        height: 0.8,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -32,
                    child: Text(
                      '”',
                      style: TextStyle(
                        fontSize: 72,
                        color: accentColor.withValues(alpha: 0.07),
                        fontWeight: FontWeight.w900,
                        height: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    child: Text(
                      post.content,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 17.5,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: SLColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                post.content,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  height: 1.6,
                  color: SLColors.textPrimary,
                ),
              ),
            if (post.imageUrl.isNotEmpty) ...[
              SLSpacing.h16,
              ClipRRect(
                borderRadius: SLRadius.lgAll,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE98FB1)),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.white.withValues(alpha: 0.08),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded, color: Color(0xFFE98FB1), size: 26),
                  ),
                ),
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
    );
  }
}

const Color _diarySoftPink = Color(0xFFE98FB1);
