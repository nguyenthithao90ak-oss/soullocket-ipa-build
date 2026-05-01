import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import 'profile_action_widgets.dart';
import 'profile_section_models.dart';

class VisitorProfileHeaderSection extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String bio;
  final bool isMe;
  final bool isPro;
  final bool isSingle;
  final String partnerAvatar1;
  final String partnerAvatar2;
  final double avatarSize;
  final String headerImageUrl;
  final VisitorProfileHeaderThemeData theme;
  final bool isUpdatingProfileAppearance;
  final bool isDroppingHeart;
  final bool isHeartDroppedToday;
  final int heartCount;
  final Animation<double> heartScale;
  final VoidCallback onOpenAppearance;
  final VoidCallback? onPickAvatar;
  final VoidCallback onToggleHeart;

  const VisitorProfileHeaderSection({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.isMe,
    required this.isPro,
    required this.isSingle,
    required this.partnerAvatar1,
    required this.partnerAvatar2,
    required this.avatarSize,
    required this.headerImageUrl,
    required this.theme,
    required this.isUpdatingProfileAppearance,
    required this.isDroppingHeart,
    required this.isHeartDroppedToday,
    required this.heartCount,
    required this.heartScale,
    required this.onOpenAppearance,
    required this.onPickAvatar,
    required this.onToggleHeart,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedAvatar = avatarUrl?.trim() ?? '';
    final avatarBadgeOffset = (avatarSize * 0.13).clamp(10.0, 14.0).toDouble();
    final avatarShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.25),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (headerImageUrl.isNotEmpty)
          CachedNetworkImage(
            memCacheWidth: 1440,
            imageUrl: headerImageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 180),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black
                      .withOpacity(headerImageUrl.isNotEmpty ? 0.12 : 0),
                  Colors.black.withOpacity(
                    headerImageUrl.isNotEmpty ? 0.26 : 0.05,
                  ),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: _VisitorProfileMeshPatternPainter()),
        ),
        if (isMe)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenAppearance,
                splashColor: Colors.white.withOpacity(0.06),
                highlightColor: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
        if (isMe)
          Positioned(
            right: 16,
            bottom: 18,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(SLRadius.pill),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wallpaper_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chạm nền để đổi',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SLSpacing.h20,
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  GestureDetector(
                    onTap: onPickAvatar,
                    child: Container(
                      padding: SLSpacing.all4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Colors.white, Color(0xFFFFB3C6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: avatarShadow,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: avatarSize,
                              height: avatarSize,
                              child: trimmedAvatar.isNotEmpty
                                  ? CachedNetworkImage(
                                      memCacheWidth: 420,
                                      imageUrl: trimmedAvatar,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          SLTheme.avatarPlaceholder(
                                        name,
                                        size: avatarSize,
                                      ),
                                    )
                                  : SLTheme.avatarPlaceholder(
                                      name,
                                      size: avatarSize,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isSingle)
                    Positioned(
                      bottom: -avatarBadgeOffset,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _VisitorProfileSmallHouseAvatarBadge(
                            avatarUrl: partnerAvatar1,
                            fallbackLabel: 'U1',
                          ),
                          Container(
                            width: 12,
                            height: 2,
                            color: Colors.white,
                          ),
                          _VisitorProfileSmallHouseAvatarBadge(
                            avatarUrl: partnerAvatar2,
                            fallbackLabel: 'U2',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: isSingle
                    ? 12
                    : (avatarSize * 0.21).clamp(14.0, 20.0).toDouble(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isPro) ...[
                    SLSpacing.w8,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(SLRadius.pill),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        'PRO',
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (bio.isNotEmpty) ...[
                SLSpacing.h4,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.84),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              SLSpacing.h16,
              if (!isMe)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VisitorProfileHeartButton(
                      isDropping: isDroppingHeart,
                      isHeartDroppedToday: isHeartDroppedToday,
                      heartCount: heartCount,
                      heartScale: heartScale,
                      onTap: onToggleHeart,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitorProfileSmallHouseAvatarBadge extends StatelessWidget {
  final String avatarUrl;
  final String fallbackLabel;

  const _VisitorProfileSmallHouseAvatarBadge({
    required this.avatarUrl,
    required this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: Colors.grey.shade300,
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                memCacheWidth: 240,
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    SLTheme.avatarPlaceholder(fallbackLabel, size: 32),
              )
            : SLTheme.avatarPlaceholder(fallbackLabel, size: 32),
      ),
    );
  }
}

class _VisitorProfileMeshPatternPainter extends CustomPainter {
  const _VisitorProfileMeshPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -0.5),
        radius: 0.7,
        colors: [Colors.white.withOpacity(0.12), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p1);

    final p2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, 0.8),
        radius: 0.6,
        colors: [Colors.white.withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
