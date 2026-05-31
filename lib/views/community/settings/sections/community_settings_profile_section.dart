import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../widgets/community_settings_components.dart';

class CommunitySettingsProfileSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final String avatarUrl;
  final String headerImageUrl;
  final String headerThemeLabel;
  final String previewHandle;
  final String renameRuleText;

  const CommunitySettingsProfileSection({
    super.key,
    required this.nameController,
    required this.usernameController,
    required this.bioController,
    required this.avatarUrl,
    required this.headerImageUrl,
    required this.headerThemeLabel,
    required this.previewHandle,
    required this.renameRuleText,
  });

  @override
  Widget build(BuildContext context) {
    final quickInfoItems = [
      CommunitySettingsQuickInfoData(
        icon: Icons.account_circle_outlined,
        title: 'Avatar',
        value: avatarUrl.isNotEmpty ? context.tr('comm_cnh_cb87b4') : context.tr('comm_chacnh_911bb6'),
      ),
      CommunitySettingsQuickInfoData(
        icon: Icons.wallpaper_rounded,
        title: context.tr('comm_nhnn_a07223'),
        value: headerImageUrl.isNotEmpty ? context.tr('comm_cnn_5d22e4') : headerThemeLabel,
      ),
      CommunitySettingsQuickInfoData(
        icon: Icons.alternate_email_rounded,
        title: 'Username',
        value: previewHandle,
      ),
      CommunitySettingsQuickInfoData(
        icon: Icons.auto_stories_rounded,
        title: context.tr('comm_tius_6b0498'),
        value: bioController.text.trim().isNotEmpty
            ? context.tr('comm_thmmt_da2bb8')
            : context.tr('comm_chacmt_fa50c1'),
      ),
    ];

    return CommunitySettingsSectionCard(
      floating: true,
      icon: Icons.account_circle_outlined,
      accent: const Color(0xFFEC5E7B),
      title: context.tr('comm_hscngng_3150e1'),
      subtitle:
          context.tr('comm_avatarnhnn_076e5f'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth > 404
                ? 170.0
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: quickInfoItems
                  .map(
                    (item) => SizedBox(
                      width: tileWidth,
                      child: CommunitySettingsQuickInfoTile(item: item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        CommunitySettingsInfoBanner(
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF6D5CF6),
          title: context.tr('comm_nhidinvnhn_5cfaef'),
          message: avatarUrl.isNotEmpty || headerImageUrl.isNotEmpty
              ? context.tr('comm_mnnyanglyn_838fc4')
              : context.tr('comm_hscabnchan_8f8484'),
        ),
        const SizedBox(height: 12),
        CommunitySettingsTextFieldCard(
          title: context.tr('comm_tnnhhinth_65d2a5'),
          subtitle:
              context.tr('comm_tnxuthinfe_fd1753'),
          controller: nameController,
          hintText: context.tr('comm_vdnhmyhng_9cc448'),
          maxLength: 30,
        ),
        const SizedBox(height: 12),
        CommunitySettingsTextFieldCard(
          title: context.tr('comm_usernamecn_35e07f'),
          subtitle:
              context.tr('comm_nhdanhngng_65eaf8'),
          controller: usernameController,
          hintText: 'nha-cua-ban',
          prefixText: '@',
          maxLength: 20,
        ),
        const SizedBox(height: 12),
        CommunitySettingsTextFieldCard(
          title: context.tr('comm_tius_6b0498'),
          subtitle:
              context.tr('comm_mtngnvcuch_3d1ec8'),
          controller: bioController,
          hintText: context.tr('comm_vitmtvidng_d07517'),
          maxLines: 3,
          maxLength: 150,
        ),
        const SizedBox(height: 12),
        CommunitySettingsInfoBanner(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFE57A2E),
          title: context.tr('comm_quytcitn_f32bc6'),
          message: renameRuleText,
        ),
      ],
    );
  }
}
