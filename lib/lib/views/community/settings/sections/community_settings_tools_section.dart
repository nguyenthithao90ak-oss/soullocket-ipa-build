import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../widgets/community_settings_components.dart';

class CommunitySettingsToolsSection extends StatelessWidget {
  final bool searchPrivacy;
  final bool dndMode;
  final VoidCallback onOpenQr;
  final VoidCallback onOpenBlockList;
  final VoidCallback onToggleSearchPrivacy;
  final VoidCallback onToggleDndMode;

  const CommunitySettingsToolsSection({
    super.key,
    required this.searchPrivacy,
    required this.dndMode,
    required this.onOpenQr,
    required this.onOpenBlockList,
    required this.onToggleSearchPrivacy,
    required this.onToggleDndMode,
  });

  @override
  Widget build(BuildContext context) {
    return CommunitySettingsSectionCard(
      icon: Icons.dashboard_customize_outlined,
      accent: const Color(0xFF9B5CF6),
      title: context.tr('comm_cngccngng_7b08a4'),
      subtitle: context.tr('comm_mnhanhcccn_fbc81a'),
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 0.9,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            CommunitySettingsActionTile(
              icon: Icons.qr_code_2_rounded,
              color: const Color(0xFF111827),
              title: context.tr('comm_qrnh_440628'),
              subtitle:
                  context.tr('comm_mtrnhqunlq_d58fc7'),
              badge: context.tr('comm_qunl_ca8eb6'),
              onTap: onOpenQr,
            ),
            CommunitySettingsActionTile(
              icon: Icons.person_off_rounded,
              color: const Color(0xFF334155),
              title: context.tr('comm_danhschchn_a78b3d'),
              subtitle: context.tr('comm_xemlicctik_ab3ace'),
              badge: context.tr('comm_bov_5f36e8'),
              onTap: onOpenBlockList,
            ),
            CommunitySettingsActionTile(
              icon: Icons.search_off_rounded,
              color: const Color(0xFF0E9F8F),
              title: context.tr('comm_tmthyhs_a19be2'),
              subtitle: searchPrivacy
                  ? context.tr('comm_nhbnangcth_b6af47')
                  : context.tr('comm_hsangnkhit_96cc08'),
              badge: searchPrivacy ? context.tr('comm_angbt_f045a7') : context.tr('comm_angtt_2bcec5'),
              onTap: onToggleSearchPrivacy,
            ),
            CommunitySettingsActionTile(
              icon: Icons.do_not_disturb_on_rounded,
              color: const Color(0xFFE57A2E),
              title: context.tr('comm_chnglmphin_109ed0'),
              subtitle: dndMode
                  ? context.tr('comm_thngbocngn_db54d4')
                  : context.tr('comm_nhbnvnnhnt_d7c0f5'),
              badge: dndMode ? context.tr('comm_angbt_f045a7') : context.tr('comm_angtt_2bcec5'),
              onTap: onToggleDndMode,
            ),
          ],
        ),
      ],
    );
  }
}
