import 'package:flutter/material.dart';

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
      title: 'Công cụ cộng đồng',
      subtitle: 'Mở nhanh các công cụ quản lý, riêng tư và bảo vệ cộng đồng.',
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
              title: 'QR nhà',
              subtitle:
                  'Mở trình quản lý QR để quét, chia sẻ và phân biệt đúng loại mã.',
              badge: 'Quản lý',
              onTap: onOpenQr,
            ),
            CommunitySettingsActionTile(
              icon: Icons.person_off_rounded,
              color: const Color(0xFF334155),
              title: 'Danh sách chặn',
              subtitle: 'Xem lại các tài khoản đã chặn và gỡ chặn khi cần.',
              badge: 'Bảo vệ',
              onTap: onOpenBlockList,
            ),
            CommunitySettingsActionTile(
              icon: Icons.search_off_rounded,
              color: const Color(0xFF0E9F8F),
              title: 'Tìm thấy hồ sơ',
              subtitle: searchPrivacy
                  ? 'Nhà bạn đang có thể được tìm thấy trong cộng đồng.'
                  : 'Hồ sơ đang ẩn khỏi tìm kiếm.',
              badge: searchPrivacy ? 'Đang bật' : 'Đang tắt',
              onTap: onToggleSearchPrivacy,
            ),
            CommunitySettingsActionTile(
              icon: Icons.do_not_disturb_on_rounded,
              color: const Color(0xFFE57A2E),
              title: 'Chống làm phiền',
              subtitle: dndMode
                  ? 'Thông báo cộng đồng đang được hạn chế.'
                  : 'Nhà bạn vẫn nhận thông báo cộng đồng bình thường.',
              badge: dndMode ? 'Đang bật' : 'Đang tắt',
              onTap: onToggleDndMode,
            ),
          ],
        ),
      ],
    );
  }
}
