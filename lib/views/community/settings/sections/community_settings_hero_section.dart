import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
            color: const Color(0xFF1F2A37).withValues(alpha: 0.08),
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
                  child: CachedNetworkImage(
                    imageUrl: headerImageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 
                          headerImageUrl.isNotEmpty ? 0.12 : 0.02,
                        ),
                        Colors.black.withValues(alpha: 
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
                              ? context.tr('comm_cnhnn_9e62ed')
                              : headerThemeLabel,
                        ),
                        CommunitySettingsHeroChip(
                          icon: Icons.verified_user_outlined,
                          label: searchPrivacy
                              ? context.tr('comm_chophptmki_81ba6e')
                              : context.tr('comm_nkhitmkim_08ab73'),
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
                                  color: Colors.white.withValues(alpha: 0.88),
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
                                  color: Colors.white.withValues(alpha: 0.92),
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
                              ? context.tr('comm_avatart_26ec1e')
                              : context.tr('comm_chacavatar_5f4c6f'),
                        ),
                        CommunitySettingsHeroMetricChip(
                          icon: Icons.wallpaper_rounded,
                          label: headerImageUrl.isNotEmpty
                              ? context.tr('comm_nhnnt_5c4808')
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
