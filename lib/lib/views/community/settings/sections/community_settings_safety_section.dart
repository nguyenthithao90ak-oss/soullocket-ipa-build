import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../widgets/community_settings_components.dart';

class CommunitySettingsSafetySection extends StatelessWidget {
  final bool keywordFilter;
  final bool hideActiveStatus;
  final bool dndMode;
  final ValueChanged<bool> onKeywordFilterChanged;
  final ValueChanged<bool> onHideActiveStatusChanged;
  final ValueChanged<bool> onDndModeChanged;

  const CommunitySettingsSafetySection({
    super.key,
    required this.keywordFilter,
    required this.hideActiveStatus,
    required this.dndMode,
    required this.onKeywordFilterChanged,
    required this.onHideActiveStatusChanged,
    required this.onDndModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CommunitySettingsSectionCard(
      icon: Icons.verified_user_outlined,
      accent: const Color(0xFFE57A2E),
      title: context.tr('comm_antonvchng_dc11f5'),
      subtitle:
          context.tr('comm_ccthitlpfe_234e48'),
      children: [
        CommunitySettingsStatusOverview(
          items: [
            CommunitySettingsStatusChipData(
              icon: Icons.filter_alt_rounded,
              label: keywordFilter ? context.tr('comm_lctkhabt_55780c') : context.tr('comm_lctkhatt_c797fa'),
              active: keywordFilter,
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.wifi_tethering_off_rounded,
              label: hideActiveStatus
                  ? context.tr('comm_ntrngthion_d94d8d')
                  : context.tr('comm_hintrngthi_f702b4'),
              active: hideActiveStatus,
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.do_not_disturb_on_total_silence_rounded,
              label: dndMode ? context.tr('comm_angchnglmp_5444a2') : context.tr('comm_thngbobnht_d0d7e0'),
              active: dndMode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_lctkhanhyc_2c5c16'),
          subtitle:
              context.tr('comm_nbtnidungv_bcfa8b'),
          value: keywordFilter,
          onChanged: onKeywordFilterChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_ntrngthiho_423be3'),
          subtitle:
              context.tr('comm_ngikhcskhb_94a1ec'),
          value: hideActiveStatus,
          onChanged: onHideActiveStatusChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_chchnglmph_0be573'),
          subtitle:
              context.tr('comm_tmgimbtthn_aa2552'),
          value: dndMode,
          onChanged: onDndModeChanged,
        ),
      ],
    );
  }
}
