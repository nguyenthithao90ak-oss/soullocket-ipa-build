import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../widgets/community_settings_components.dart';

class CommunitySettingsHeroSection extends StatelessWidget {
  final List<Color> headerThemeColors;
  final String headerImageUrl;
  final String privacyLabel;
  final String headerThemeLabel;
  final bool searchPrivacy;
  final int profileCompletion;
  final String previewName;
  final String previewHandle;
  final String previewBio;
  final String avatarUrl;
  final String avatarInitials;
  final String friendLimitLabel;

  const CommunitySettingsHeroSection({
    super.key,
    required this.headerThemeColors,
    required this.headerImageUrl,
    required this.privacyLabel,
    required this.headerThemeLabel,
    required this.searchPrivacy,
    required this.profileCompletion,
    required this.previewName,
    required this.previewHandle,
    required this.previewBio,
    required this.avatarUrl,
    required this.avatarInitials,
    required this.friendLimitLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCommunitySettingsHeroRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2A37).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCommunitySettingsHeroRadius),
        child: SizedBox(
          height: 228,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerThemeColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              if (headerImageUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    headerImageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(
                          headerImageUrl.isNotEmpty ? 0.12 : 0.02,
                        ),
                        Colors.black.withOpacity(
                          headerImageUrl.isNotEmpty ? 0.28 : 0.12,
                        ),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CommunitySettingsHeroChip(
                          icon: Icons.public_rounded,
                          label: privacyLabel,
                        ),
                        CommunitySettingsHeroChip(
                          icon: Icons.palette_outlined,
                          label: headerImageUrl.isNotEmpty
                              ? 'Có ảnh nền'
                              : headerThemeLabel,
                        ),
                        CommunitySettingsHeroChip(
                          icon: Icons.verified_user_outlined,
                          label: searchPrivacy
                              ? 'Cho phép tìm kiếm'
                              : 'Ẩn khỏi tìm kiếm',
                        ),
                        CommunitySettingsHeroChip(
                          icon: Icons.insights_rounded,
                          label: '$profileCompletion% hoàn thiện',
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CommunitySettingsAvatarPreview(
                          avatarUrl: avatarUrl,
                          fallbackText: avatarInitials,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                previewName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  height: 1.14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                previewHandle,
                                style: SLTheme.quicksand(
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                previewBio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: Colors.white.withOpacity(0.92),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.42,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CommunitySettingsHeroMetricChip(
                          icon: Icons.account_circle_outlined,
                          label: avatarUrl.isNotEmpty
                              ? 'Avatar đã đặt'
                              : 'Chưa có avatar',
                        ),
                        CommunitySettingsHeroMetricChip(
                          icon: Icons.wallpaper_rounded,
                          label: headerImageUrl.isNotEmpty
                              ? 'Ảnh nền đã đặt'
                              : headerThemeLabel,
                        ),
                        CommunitySettingsHeroMetricChip(
                          icon: Icons.people_outline_rounded,
                          label: friendLimitLabel,
                        ),
                      ],
                    ),
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
