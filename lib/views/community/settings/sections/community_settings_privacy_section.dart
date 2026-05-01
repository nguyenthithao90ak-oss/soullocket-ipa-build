import 'package:flutter/material.dart';

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
      title: 'Quyền riêng tư hồ sơ',
      subtitle:
          'Kiểm soát người ngoài nhìn thấy gì khi mở hồ sơ, mục yêu thích và các khoảnh khắc nổi bật.',
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
              label: hideLikeCount ? 'Ẩn lượt tim' : 'Hiện lượt tim',
              active: !hideLikeCount,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const CommunitySettingsSubsectionTitle(
          title: 'Những gì người khác được nhìn thấy',
        ),
        const SizedBox(height: 10),
        CommunitySettingsDropdownCard(
          title: 'Quyền riêng tư hồ sơ',
          subtitle: 'Chọn ai có thể xem toàn bộ hồ sơ cộng đồng của nhà bạn.',
          value: privacy,
          items: const [
            DropdownMenuItem(
              value: 'public',
              child: Text('Công khai cho mọi người'),
            ),
            DropdownMenuItem(
              value: 'friends',
              child: Text('Chỉ bạn bè'),
            ),
            DropdownMenuItem(
              value: 'private',
              child: Text('Chỉ hai người trong nhà'),
            ),
          ],
          onChanged: onPrivacyChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: 'Hiển thị mục Yêu thích',
          subtitle:
              'Quy định người khác có thấy danh sách bài bạn đã thích hay không.',
          value: likedVisibility,
          items: const [
            DropdownMenuItem(
              value: 'private',
              child: Text('Ẩn với người khác'),
            ),
            DropdownMenuItem(
              value: 'public',
              child: Text('Cho phép xem'),
            ),
          ],
          onChanged: onLikedVisibilityChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: 'Hiển thị mục Khoảnh khắc',
          subtitle:
              'Chọn mức công khai cho album khoảnh khắc và kỷ niệm nổi bật.',
          value: locketVisibility,
          items: const [
            DropdownMenuItem(
              value: 'private',
              child: Text('Ẩn với người khác'),
            ),
            DropdownMenuItem(
              value: 'public',
              child: Text('Cho phép xem'),
            ),
          ],
          onChanged: onLocketVisibilityChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsDropdownCard(
          title: 'Thứ tự kỷ niệm nổi bật',
          subtitle:
              'Kiểm soát cách các bài được ưu tiên khi xuất hiện trên hồ sơ.',
          value: highlightSort,
          items: const [
            DropdownMenuItem(
              value: 'date_desc',
              child: Text('Mới nhất lên đầu'),
            ),
            DropdownMenuItem(
              value: 'likes_desc',
              child: Text('Nhiều tim lên đầu'),
            ),
            DropdownMenuItem(
              value: 'manual',
              child: Text('Tự chọn thủ công'),
            ),
          ],
          onChanged: onHighlightSortChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Cho phép người khác lưu ảnh hoặc video',
          subtitle:
              'Tắt nếu bạn không muốn nội dung bị tải xuống trực tiếp từ hồ sơ.',
          value: allowDownload,
          onChanged: onAllowDownloadChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Hiển thị ngày tạo nhà trên hồ sơ',
          subtitle:
              'Giữ bật nếu muốn hồ sơ có chiều sâu và rõ hành trình của hai bạn.',
          value: showCreationDate,
          onChanged: onShowCreationDateChanged,
        ),
        const SizedBox(height: 12),
        CommunitySettingsToggleCard(
          title: 'Ẩn số lượt tim trên bài viết',
          subtitle:
              'Dùng khi bạn muốn feed gọn hơn và bớt tập trung vào số liệu tương tác.',
          value: hideLikeCount,
          onChanged: onHideLikeCountChanged,
        ),
      ],
    );
  }
}
