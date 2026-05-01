import 'package:flutter/material.dart';

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
        value: avatarUrl.isNotEmpty ? 'Đã có ảnh' : 'Chưa có ảnh',
      ),
      CommunitySettingsQuickInfoData(
        icon: Icons.wallpaper_rounded,
        title: 'Ảnh nền',
        value: headerImageUrl.isNotEmpty ? 'Đã có nền' : headerThemeLabel,
      ),
      CommunitySettingsQuickInfoData(
        icon: Icons.alternate_email_rounded,
        title: 'Username',
        value: previewHandle,
      ),
      CommunitySettingsQuickInfoData(
        icon: Icons.auto_stories_rounded,
        title: 'Tiểu sử',
        value: bioController.text.trim().isNotEmpty
            ? 'Đã thêm mô tả'
            : 'Chưa có mô tả',
      ),
    ];

    return CommunitySettingsSectionCard(
      floating: true,
      icon: Icons.account_circle_outlined,
      accent: const Color(0xFFEC5E7B),
      title: 'Hồ sơ cộng đồng',
      subtitle:
          'Avatar, ảnh nền, tên hiển thị, username và tiểu sử được gom chung để dễ quản lý như một hồ sơ riêng.',
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
          title: 'Ảnh đại diện và ảnh nền',
          message: avatarUrl.isNotEmpty || headerImageUrl.isNotEmpty
              ? 'Màn này đang lấy đúng dữ liệu avatar và nền hiện có của hồ sơ cộng đồng. Muốn thay ảnh, hãy chỉnh trực tiếp ở màn hồ sơ để xem trước đúng kích thước.'
              : 'Hồ sơ của bạn chưa đủ ảnh đại diện hoặc ảnh nền. Nên thêm ảnh ở màn hồ sơ cộng đồng để trang cá nhân nổi bật hơn.',
        ),
        const SizedBox(height: 12),
        CommunitySettingsTextFieldCard(
          title: 'Tên nhà hiển thị',
          subtitle:
              'Tên xuất hiện ở feed cộng đồng, visitor profile và các khu vực chia sẻ.',
          controller: nameController,
          hintText: 'Ví dụ: Nhà Mây Hồng',
          maxLength: 30,
        ),
        const SizedBox(height: 12),
        CommunitySettingsTextFieldCard(
          title: 'Username cộng đồng',
          subtitle:
              'Định danh ngắn gọn để tìm kiếm, gắn link và hiển thị dưới tên hồ sơ.',
          controller: usernameController,
          hintText: 'nha-cua-ban',
          prefixText: '@',
          maxLength: 20,
        ),
        const SizedBox(height: 12),
        CommunitySettingsTextFieldCard(
          title: 'Tiểu sử',
          subtitle:
              'Mô tả ngắn về câu chuyện, phong cách hoặc điều bạn muốn người khác biết khi ghé hồ sơ.',
          controller: bioController,
          hintText: 'Viết một vài dòng thật dễ nhớ...',
          maxLines: 3,
          maxLength: 150,
        ),
        const SizedBox(height: 12),
        CommunitySettingsInfoBanner(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFE57A2E),
          title: 'Quy tắc đổi tên',
          message: renameRuleText,
        ),
      ],
    );
  }
}
