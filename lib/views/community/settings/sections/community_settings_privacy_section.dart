import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../widgets/community_settings_components.dart';

class CommunitySettingsPrivacySection extends StatelessWidget {
  final String privacy;
  final String privacyLabel;
  final String likedVisibility;
  final String likedVisibilityLabel;
  final String locketVisibility;
  final String locketVisibilityLabel;
  final String highlightSort;
  final bool allowDownload;
  final bool showCreationDate;
  final bool hideLikeCount;
  final ValueChanged<String?> onPrivacyChanged;
  final ValueChanged<String?> onLikedVisibilityChanged;
  final ValueChanged<String?> onLocketVisibilityChanged;
  final ValueChanged<String?> onHighlightSortChanged;
  final ValueChanged<bool> onAllowDownloadChanged;
  final ValueChanged<bool> onShowCreationDateChanged;
  final ValueChanged<bool> onHideLikeCountChanged;

  const CommunitySettingsPrivacySection({
    super.key,
    required this.privacy,
    required this.privacyLabel,
    required this.likedVisibility,
    required this.likedVisibilityLabel,
    required this.locketVisibility,
    required this.locketVisibilityLabel,
    required this.highlightSort,
    required this.allowDownload,
    required this.showCreationDate,
    required this.hideLikeCount,
    required this.onPrivacyChanged,
    required this.onLikedVisibilityChanged,
    required this.onLocketVisibilityChanged,
    required this.onHighlightSortChanged,
    required this.onAllowDownloadChanged,
    required this.onShowCreationDateChanged,
    required this.onHideLikeCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CommunitySettingsSectionCard(
      icon: Icons.lock_outline_rounded,
      accent: const Color(0xFF4C7EF3),
      title: context.tr('comm_quynringth_b64d5f'),
      subtitle:
          context.tr('comm_kimsotngin_40b662'),
      children: [
        CommunitySettingsStatusOverview(
          items: [
            CommunitySettingsStatusChipData(
              icon: Icons.public_rounded,
              label: privacyLabel,
              active: privacy == 'public',
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.favorite_rounded,
              label: likedVisibilityLabel,
              active: likedVisibility == 'public',
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.auto_stories_rounded,
              label: locketVisibilityLabel,
              active: locketVisibility == 'public',
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.visibility_outlined,
              label: hideLikeCount ? context.tr('comm_nlttim_8595c3') : context.tr('comm_hinlttim_952193'),
              active: !hideLikeCount,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CommunitySettingsSubsectionTitle(
          title: context.tr('comm_nhnggngikh_5200a5'),
        ),
        const SizedBox(height: 10),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_quynringth_b64d5f'),
          subtitle: context.tr('comm_chnaicthxe_5b94ae'),
          value: privacy,
          items: [
            DropdownMenuItem(
              value: 'public',
              child: Text(context.tr('comm_cngkhaicho_d9d2de')),
            ),
            DropdownMenuItem(
              value: 'friends',
              child: Text(context.tr('comm_chbnb_824805')),
            ),
            DropdownMenuItem(
              value: 'private',
              child: Text(context.tr('comm_chhaingitr_2acb90')),
            ),
          ],
          onChanged: onPrivacyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_hinthmcyut_1eeb26'),
          subtitle:
              context.tr('comm_quynhngikh_fa3de0'),
          value: likedVisibility,
          items: [
            DropdownMenuItem(
              value: 'private',
              child: Text(context.tr('comm_nvingikhc_b7c7fa')),
            ),
            DropdownMenuItem(
              value: 'public',
              child: Text(context.tr('comm_chophpxem_acb88c')),
            ),
          ],
          onChanged: onLikedVisibilityChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_hinthmckho_a0ecfe'),
          subtitle:
              context.tr('comm_chnmccngkh_bff15b'),
          value: locketVisibility,
          items: [
            DropdownMenuItem(
              value: 'private',
              child: Text(context.tr('comm_nvingikhc_b7c7fa')),
            ),
            DropdownMenuItem(
              value: 'public',
              child: Text(context.tr('comm_chophpxem_acb88c')),
            ),
          ],
          onChanged: onLocketVisibilityChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_thtknimnib_2903b3'),
          subtitle:
              context.tr('comm_kimsotcchc_071c0a'),
          value: highlightSort,
          items: [
            DropdownMenuItem(
              value: 'date_desc',
              child: Text(context.tr('comm_minhtlnu_e9f8eb')),
            ),
            DropdownMenuItem(
              value: 'likes_desc',
              child: Text(context.tr('comm_nhiutimlnu_4593bc')),
            ),
            DropdownMenuItem(
              value: 'manual',
              child: Text(context.tr('comm_tchnthcng_52db0b')),
            ),
          ],
          onChanged: onHighlightSortChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_chophpngik_32f691'),
          subtitle:
              context.tr('comm_ttnubnkhng_5e25ac'),
          value: allowDownload,
          onChanged: onAllowDownloadChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_hinthngyto_f1da41'),
          subtitle:
              context.tr('comm_gibtnumunh_d64bed'),
          value: showCreationDate,
          onChanged: onShowCreationDateChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_nslttimtrn_131b0b'),
          subtitle:
              context.tr('comm_dngkhibnmu_fe4181'),
          value: hideLikeCount,
          onChanged: onHideLikeCountChanged,
        ),
      ],
    );
  }
}
