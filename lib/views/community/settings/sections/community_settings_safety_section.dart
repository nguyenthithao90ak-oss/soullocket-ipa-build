import 'package:flutter/material.dart';

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
      title: 'An toàn và chống làm phiền',
      subtitle:
          'Các thiết lập để feed sạch hơn, ít quấy rối hơn và giảm nhiễu từ cộng đồng khi cần nghỉ.',
      children: [
        CommunitySettingsStatusOverview(
          items: [
            CommunitySettingsStatusChipData(
              icon: Icons.filter_alt_rounded,
              label: keywordFilter ? 'Lọc từ khóa bật' : 'Lọc từ khóa tắt',
              active: keywordFilter,
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.wifi_tethering_off_rounded,
              label: hideActiveStatus
                  ? 'Ẩn trạng thái online'
                  : 'Hiện trạng thái online',
              active: hideActiveStatus,
            ),
            CommunitySettingsStatusChipData(
              icon: Icons.do_not_disturb_on_total_silence_rounded,
              label: dndMode ? 'Đang chống làm phiền' : 'Thông báo bình thường',
              active: dndMode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Lọc từ khóa nhạy cảm',
          subtitle:
              'Ẩn bớt nội dung và bình luận dễ gây khó chịu trong cộng đồng.',
          value: keywordFilter,
          onChanged: onKeywordFilterChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Ẩn trạng thái hoạt động',
          subtitle:
              'Người khác sẽ khó biết khi nào nhà bạn đang online hoặc đang xem cộng đồng.',
          value: hideActiveStatus,
          onChanged: onHideActiveStatusChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Chế độ chống làm phiền',
          subtitle:
              'Tạm giảm bớt thông báo cộng đồng để giữ không gian riêng và tập trung.',
          value: dndMode,
          onChanged: onDndModeChanged,
        ),
      ],
    );
  }
}
