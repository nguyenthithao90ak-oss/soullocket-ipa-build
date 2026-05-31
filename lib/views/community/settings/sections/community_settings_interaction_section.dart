import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../widgets/community_settings_components.dart';

class CommunitySettingsInteractionSection extends StatelessWidget {
  final bool searchPrivacy;
  final String friendRequestPolicy;
  final String friendRequestPolicyLabel;
  final String commentPolicy;
  final String commentPolicyLabel;
  final bool msgPrivacy;
  final int friendRequestLimit;
  final bool taggingPolicy;
  final ValueChanged<bool> onSearchPrivacyChanged;
  final ValueChanged<String?> onFriendRequestPolicyChanged;
  final ValueChanged<String?> onCommentPolicyChanged;
  final ValueChanged<String?> onFriendRequestLimitChanged;
  final ValueChanged<bool> onMsgPrivacyChanged;
  final ValueChanged<bool> onTaggingPolicyChanged;

  const CommunitySettingsInteractionSection({
    super.key,
    required this.searchPrivacy,
    required this.friendRequestPolicy,
    required this.friendRequestPolicyLabel,
    required this.commentPolicy,
    required this.commentPolicyLabel,
    required this.msgPrivacy,
    required this.friendRequestLimit,
    required this.taggingPolicy,
    required this.onSearchPrivacyChanged,
    required this.onFriendRequestPolicyChanged,
    required this.onCommentPolicyChanged,
    required this.onFriendRequestLimitChanged,
    required this.onMsgPrivacyChanged,
    required this.onTaggingPolicyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final friendLimitValue = friendRequestLimit <= 0 ? 30 : friendRequestLimit;
    final friendLimitItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: '30', child: Text(context.tr('comm_tia30bn_f614cc'))),
      DropdownMenuItem(value: '50', child: Text(context.tr('comm_tia50bn_fabbe8'))),
      DropdownMenuItem(value: '100', child: Text(context.tr('comm_tia100bn_83c322'))),
      DropdownMenuItem(value: '500', child: Text(context.tr('comm_tia500bn_a4f988'))),
    ];
    if (!friendLimitItems
        .any((item) => item.value == friendLimitValue.toString())) {
      friendLimitItems.add(
        DropdownMenuItem(
          value: friendLimitValue.toString(),
          child: Text('Tối đa $friendLimitValue bạn'),
        ),
      );
    }

    return CommunitySettingsSectionCard(
      icon: Icons.group_outlined,
      accent: const Color(0xFF0E9F8F),
      title: context.tr('comm_ktninhmrin_66bf85'),
      subtitle:
          context.tr('comm_gomlimibnh_9f4e3b'),
      children: [
        CommunitySettingsStatusOverview(
          items: [
            CommunitySettingsStatusChipData(
              icon: Icons.search_rounded,
              label: searchPrivacy ? context.tr('comm_ctmkim_b43760') : context.tr('comm_nkhitmkim_08ab73'),
              active: searchPrivacy,
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.person_add_alt_1_rounded,
              label: friendRequestPolicyLabel,
              active: friendRequestPolicy != 'none',
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.chat_bubble_outline_rounded,
              label: commentPolicyLabel,
              active: commentPolicy != 'none',
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.mail_lock_rounded,
              label: msgPrivacy ? context.tr('comm_khatinnhnl_c1af9f') : context.tr('comm_nhntinnhnl_324287'),
              active: !msgPrivacy,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CommunitySettingsSubsectionTitle(
          title: context.tr('comm_khnngctmth_ea42fb'),
        ),
        const SizedBox(height: 10),
        CommunitySettingsToggleCard(
          title: context.tr('comm_chophptmki_a2501f'),
          subtitle:
              context.tr('comm_ttnubnchmu_de045e'),
          value: searchPrivacy,
          onChanged: onSearchPrivacyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_aicthgilim_e49f0c'),
          subtitle: context.tr('comm_giihnvngkt_efc737'),
          value: friendRequestPolicy,
          items: [
            DropdownMenuItem(value: 'all', child: Text(context.tr('comm_mingi_d524fb'))),
            DropdownMenuItem(value: 'mutual', child: Text(context.tr('comm_chbnchung_b9c944'))),
            DropdownMenuItem(value: 'none', child: Text(context.tr('comm_khngchophp_635c83'))),
          ],
          onChanged: onFriendRequestPolicyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_aicthbnhlu_80deb5'),
          subtitle:
              context.tr('comm_tchringphn_5c14f5'),
          value: commentPolicy,
          items: [
            DropdownMenuItem(value: 'all', child: Text(context.tr('comm_mingi_d524fb'))),
            DropdownMenuItem(value: 'friends', child: Text(context.tr('comm_chbnb_824805'))),
            DropdownMenuItem(value: 'none', child: Text(context.tr('comm_ttbnhlun_85f22c'))),
          ],
          onChanged: onCommentPolicyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: context.tr('comm_giihndanhs_1a409f'),
          subtitle:
              context.tr('comm_giquymphhp_6a78c2'),
          value: friendLimitValue.toString(),
          items: friendLimitItems,
          onChanged: onFriendRequestLimitChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_khatinnhnt_e0f848'),
          subtitle:
              context.tr('comm_btnubnchmu_60ffd7'),
          value: msgPrivacy,
          onChanged: onMsgPrivacyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: context.tr('comm_khngchophp_ce31c1'),
          subtitle:
              context.tr('comm_gimvicbkov_4df570'),
          value: taggingPolicy,
          onChanged: onTaggingPolicyChanged,
        ),
      ],
    );
  }
}
