import 'package:flutter/material.dart';

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
      const DropdownMenuItem(value: '30', child: Text('Tối đa 30 bạn')),
      const DropdownMenuItem(value: '50', child: Text('Tối đa 50 bạn')),
      const DropdownMenuItem(value: '100', child: Text('Tối đa 100 bạn')),
      const DropdownMenuItem(value: '500', child: Text('Tối đa 500 bạn')),
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
      title: 'Kết nối, nhóm riêng tư và tương tác',
      subtitle:
          'Gom lời mời, bình luận, nhắn tin lạ và khả năng được tìm thấy vào cùng một chỗ để dễ kiểm soát.',
      children: [
        CommunitySettingsStatusOverview(
          items: [
            CommunitySettingsStatusChipData(
              icon: Icons.search_rounded,
              label: searchPrivacy ? 'Được tìm kiếm' : 'Ẩn khỏi tìm kiếm',
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
              label: msgPrivacy ? 'Khóa tin nhắn lạ' : 'Nhận tin nhắn lạ',
              active: !msgPrivacy,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const CommunitySettingsSubsectionTitle(
          title: 'Khả năng được tìm thấy',
        ),
        const SizedBox(height: 10),
        CommunitySettingsToggleCard(
          title: 'Cho phép tìm kiếm hồ sơ',
          subtitle:
              'Tắt nếu bạn chỉ muốn người đã biết nhà bạn mới có thể vào hồ sơ.',
          value: searchPrivacy,
          onChanged: onSearchPrivacyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: 'Ai có thể gửi lời mời kết bạn',
          subtitle: 'Giới hạn vòng kết nối để giữ cộng đồng riêng tư hơn.',
          value: friendRequestPolicy,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Mọi người')),
            DropdownMenuItem(value: 'mutual', child: Text('Chỉ bạn chung')),
            DropdownMenuItem(value: 'none', child: Text('Không cho phép')),
          ],
          onChanged: onFriendRequestPolicyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: 'Ai có thể bình luận trên bài viết',
          subtitle:
              'Tách riêng phần bình luận để tránh nhiễu hoặc giữ bài viết riêng tư hơn.',
          value: commentPolicy,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Mọi người')),
            DropdownMenuItem(value: 'friends', child: Text('Chỉ bạn bè')),
            DropdownMenuItem(value: 'none', child: Text('Tắt bình luận')),
          ],
          onChanged: onCommentPolicyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: 'Giới hạn danh sách bạn bè',
          subtitle:
              'Giữ quy mô phù hợp để feed và quan hệ trong cộng đồng dễ quản lý hơn.',
          value: friendLimitValue.toString(),
          items: friendLimitItems,
          onChanged: onFriendRequestLimitChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Khóa tin nhắn từ người lạ',
          subtitle:
              'Bật nếu bạn chỉ muốn nhận tin nhắn khi đã có kết nối rõ ràng.',
          value: msgPrivacy,
          onChanged: onMsgPrivacyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Không cho phép tag hoặc nhắc tên',
          subtitle:
              'Giảm việc bị kéo vào nội dung không liên quan trong cộng đồng.',
          value: taggingPolicy,
          onChanged: onTaggingPolicyChanged,
        ),
      ],
    );
  }
}
