import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/sl_theme.dart';
import '../../../../models/diary_post.dart';
import '../../../../utils/services/l10n_service.dart';

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
      if (lowered == 'người yêu' ||
          lowered == 'nguoi yeu' ||
          lowered == 'bạn nam' ||
          lowered == 'ban nam' ||
          lowered == 'bạn nữ' ||
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
      rawName = isMyPost ? 'Tôi' : 'Người ấy';
    }

    final displayName = rawName;
    const accentColor = _diarySoftPink;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SLTheme.glassCard(
        margin: EdgeInsets.zero,
        radius: 20,
        padding: SLSpacing.all20,
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
                    color: accentColor.withOpacity(0.15),
                    borderRadius: SLRadius.mdAll,
                    border: Border.all(color: accentColor.withOpacity(0.3)),
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
                      color: Colors.red.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
            SLSpacing.h16,
            Text(
              post.content,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.6,
                color: SLColors.textPrimary,
              ),
            ),
            if (post.imageUrl.isNotEmpty) ...[
              SLSpacing.h16,
              ClipRRect(
                borderRadius: SLRadius.lgAll,
                child: Hero(
                  tag: 'diary_image_${post.id}',
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: postImageCacheWidth,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: Colors.white.withOpacity(0.3),
                      child: const SkeletonContainer.rounded(width: double.infinity, height: 120),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.white.withOpacity(0.3),
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
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
                    L10nService().translate('Đã ghim tâm sự'),
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
