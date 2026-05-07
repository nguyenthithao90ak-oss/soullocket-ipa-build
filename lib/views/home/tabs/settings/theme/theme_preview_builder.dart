import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../core/sl_theme.dart';

@immutable
class ThemePreviewProfileData {
  final String name;
  final String subtitle;
  final String? avatarUrl;

  const ThemePreviewProfileData({
    required this.name,
    required this.subtitle,
    this.avatarUrl,
  });
}

@immutable
class ThemePreviewData {
  final String themeKey;
  final String effectKey;
  final String countdownLabel;
  final String countdownValue;
  final String dateCaption;
  final String dockCaption;
  final String? backgroundImageUrl;
  final Color accentColor;
  final bool isDark;
  final ThemePreviewProfileData leadingProfile;
  final ThemePreviewProfileData trailingProfile;

  const ThemePreviewData({
    required this.themeKey,
    required this.effectKey,
    required this.countdownLabel,
    required this.countdownValue,
    required this.dateCaption,
    required this.dockCaption,
    required this.accentColor,
    required this.leadingProfile,
    required this.trailingProfile,
    this.backgroundImageUrl,
    this.isDark = false,
  });
}

class ThemePreviewBuilder extends StatelessWidget {
  const ThemePreviewBuilder({
    super.key,
    required this.data,
    this.height = 360,
    this.headerTitle = 'Bản xem trước',
    this.headerSubtitle =
        'Giữ preview tách riêng để shell có thể thay theme/effect/background theo draft mới.',
  });

  final ThemePreviewData data;
  final double height;
  final String headerTitle;
  final String headerSubtitle;

  @override
  Widget build(BuildContext context) {
    final textColor = data.isDark ? Colors.white : const Color(0xFF2A2431);
    final secondaryTextColor =
        data.isDark ? Colors.white70 : const Color(0xFF6B6370);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2D7E3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B2A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerTitle,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            headerSubtitle,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7B7080),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: _themeGradient(data.themeKey, data.isDark),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  if ((data.backgroundImageUrl ?? '').trim().isNotEmpty)
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: data.backgroundImageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(data.isDark ? 0.02 : 0.1),
                            Colors.black.withOpacity(data.isDark ? 0.28 : 0.08),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _PreviewEffectLayer(
                        accentColor: data.accentColor,
                        effectKey: data.effectKey,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewPill(
                                icon: Icons.auto_awesome_rounded,
                                label: data.themeKey,
                                foregroundColor: textColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PreviewPill(
                                icon: Icons.blur_circular_rounded,
                                label: data.effectKey,
                                foregroundColor: textColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(data.isDark ? 0.12 : 0.3),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.42),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                data.countdownLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: secondaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [
                                      data.accentColor.withOpacity(0.82),
                                      Colors.white,
                                    ],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  data.countdownValue,
                                  style: SLTheme.quicksand(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                data.dateCaption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewProfileCard(
                                profile: data.leadingProfile,
                                accentColor: data.accentColor,
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PreviewProfileCard(
                                profile: data.trailingProfile,
                                accentColor: data.accentColor,
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(data.isDark ? 0.1 : 0.26),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.34),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.widgets_outlined,
                                size: 16,
                                color: data.accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data.dockCaption,
                                  style: SLTheme.quicksand(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: secondaryTextColor,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _themeGradient(String themeKey, bool isDark) {
    switch (themeKey) {
      case 'theme-night':
        return const [
          Color(0xFF111827),
          Color(0xFF2E1065),
          Color(0xFF312E81),
        ];
      case 'theme-ocean':
        return const [
          Color(0xFFB9F4FF),
          Color(0xFF7DD3FC),
          Color(0xFF22D3EE),
        ];
      case 'theme-sunset':
        return const [
          Color(0xFFFFE29F),
          Color(0xFFFF719A),
          Color(0xFFFF5F6D),
        ];
      case 'theme-dark':
      case 'theme-mystic-dark':
        return const [
          Color(0xFF1F1B2E),
          Color(0xFF30203F),
          Color(0xFF463059),
        ];
      case 'theme-default':
        return const [
          Color(0xFFFFF1F5),
          Color(0xFFFFE4EC),
          Color(0xFFF8E8FF),
        ];
      case 'off':
        return const [
          Color(0xFFF7F8FA),
          Color(0xFFF1F4F8),
          Color(0xFFE8EDF4),
        ];
      case 'theme-pink-glow':
      default:
        return isDark
            ? const [
                Color(0xFF2A1630),
                Color(0xFF4A1D4A),
                Color(0xFF5E2E56),
              ]
            : const [
                Color(0xFFFFF2F6),
                Color(0xFFFFE1EB),
                Color(0xFFFDE2FF),
              ];
    }
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.icon,
    required this.label,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.34)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 10.8,
                fontWeight: FontWeight.w800,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewProfileCard extends StatelessWidget {
  const _PreviewProfileCard({
    required this.profile,
    required this.accentColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  final ThemePreviewProfileData profile;
  final Color accentColor;
  final Color textColor;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          _PreviewAvatar(
            name: profile.name,
            avatarUrl: profile.avatarUrl,
            accentColor: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({
    required this.name,
    required this.avatarUrl,
    required this.accentColor,
  });

  final String name;
  final String? avatarUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final safeUrl = (avatarUrl ?? '').trim();
    final trimmedName = name.trim();
    final fallback = trimmedName.isEmpty ? '?' : trimmedName.substring(0, 1);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.9),
            accentColor.withOpacity(0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: safeUrl.isEmpty
            ? ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Text(
                    fallback,
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: safeUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: Text(
                      fallback,
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PreviewEffectLayer extends StatelessWidget {
  const _PreviewEffectLayer({
    required this.accentColor,
    required this.effectKey,
  });

  final Color accentColor;
  final String effectKey;

  @override
  Widget build(BuildContext context) {
    final bubbles = switch (effectKey) {
      'stars' => 16,
      'hearts' => 10,
      'meteors' => 7,
      'bubbles' => 12,
      _ => 8,
    };

    return Stack(
      children: List<Widget>.generate(bubbles, (index) {
        final left = (index * 31.0) % 260;
        final top = (index * 47.0) % 300;
        final size = 6.0 + (index % 4) * 4.0;
        return Positioned(
          left: left,
          top: top,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14 + (index % 3) * 0.04),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
