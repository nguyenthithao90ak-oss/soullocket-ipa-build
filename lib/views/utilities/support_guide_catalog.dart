import 'package:flutter/material.dart';

import '../../widgets/app_help_center.dart' show normalizeHelpQuery;
import '../../widgets/sl_settings_kit.dart';

/// Một vấn đề thường gặp: tiêu đề, nguyên nhân ngắn và các bước xử lý
/// (mỗi bước một dòng trong khóa `_steps`). Nội dung đóng gói trong app nên
/// trả lời được ngay cả khi mất mạng hoặc trợ lý AI không phản hồi.
class SupportGuideIssue {
  const SupportGuideIssue(this.categoryId, this.id);

  final String categoryId;
  final String id;

  String get key => '${categoryId}_$id';
  String get titleKey => 'support_guide_${key}_title';
  String get whyKey => 'support_guide_${key}_why';
  String get stepsKey => 'support_guide_${key}_steps';
}

class SupportGuideCategory {
  const SupportGuideCategory({
    required this.id,
    required this.icon,
    required this.color,
    required this.issueIds,
    required this.ticketTopicId,
  });

  final String id;
  final IconData icon;
  final Color color;
  final List<String> issueIds;

  /// Mã chủ đề ticket cũ để đội ngũ lọc yêu cầu theo nhóm.
  final String ticketTopicId;

  String get titleKey => 'support_guide_cat_$id';
  String get descKey => 'support_guide_cat_${id}_desc';

  List<SupportGuideIssue> get issues => [
    for (final issueId in issueIds) SupportGuideIssue(id, issueId),
  ];
}

const supportGuideCategories = <SupportGuideCategory>[
  SupportGuideCategory(
    id: 'account',
    icon: Icons.key_rounded,
    color: SLSettingsColors.amber,
    issueIds: ['forgot', 'no_code', 'change_password', 'logged_out'],
    ticketTopicId: '1',
  ),
  SupportGuideCategory(
    id: 'pairing',
    icon: Icons.favorite_border_rounded,
    color: SLSettingsColors.rose,
    issueIds: ['how', 'code_fail', 'not_synced'],
    ticketTopicId: '2',
  ),
  SupportGuideCategory(
    id: 'photos',
    icon: Icons.photo_library_outlined,
    color: SLSettingsColors.violet,
    issueIds: ['upload_fail', 'not_showing', 'deleted'],
    ticketTopicId: '3',
  ),
  SupportGuideCategory(
    id: 'sync',
    icon: Icons.phonelink_ring_outlined,
    color: SLSettingsColors.sky,
    issueIds: ['new_phone', 'missing_data'],
    ticketTopicId: '5',
  ),
  SupportGuideCategory(
    id: 'notify',
    icon: Icons.notifications_none_rounded,
    color: SLSettingsColors.coral,
    issueIds: ['no_notification', 'widget'],
    ticketTopicId: '6',
  ),
  SupportGuideCategory(
    id: 'location',
    icon: Icons.location_on_outlined,
    color: SLSettingsColors.indigo,
    issueIds: ['partner_location', 'battery'],
    ticketTopicId: '6',
  ),
  SupportGuideCategory(
    id: 'pro',
    icon: Icons.workspace_premium_outlined,
    color: SLSettingsColors.premium,
    issueIds: ['bought_missing', 'points', 'giftcode'],
    ticketTopicId: '4',
  ),
  SupportGuideCategory(
    id: 'bug',
    icon: Icons.bug_report_outlined,
    color: SLSettingsColors.red,
    issueIds: ['crash', 'slow', 'connection'],
    ticketTopicId: '6',
  ),
  SupportGuideCategory(
    id: 'privacy',
    icon: Icons.lock_outline_rounded,
    color: SLSettingsColors.teal,
    issueIds: ['forgot_pin', 'vault', 'export'],
    ticketTopicId: '4',
  ),
  SupportGuideCategory(
    id: 'delete',
    icon: Icons.delete_outline_rounded,
    color: SLSettingsColors.slate,
    issueIds: ['account', 'space'],
    ticketTopicId: '8',
  ),
];

SupportGuideCategory? supportGuideCategoryById(String? id) {
  for (final category in supportGuideCategories) {
    if (category.id == id) return category;
  }
  return null;
}

SupportGuideIssue? supportGuideIssue(String? categoryId, String? issueId) {
  final category = supportGuideCategoryById(categoryId);
  if (category == null || !category.issueIds.contains(issueId)) return null;
  return SupportGuideIssue(category.id, issueId!);
}

/// Chủ đề ticket cũ (mở từ màn khác) → nhóm hướng dẫn tương ứng.
SupportGuideCategory? supportGuideCategoryForTicketTopic(String? topicId) =>
    switch (topicId) {
      '1' => supportGuideCategoryById('account'),
      '2' => supportGuideCategoryById('pairing'),
      '3' => supportGuideCategoryById('photos'),
      '4' => supportGuideCategoryById('privacy'),
      '5' => supportGuideCategoryById('sync'),
      '6' => supportGuideCategoryById('bug'),
      '8' => supportGuideCategoryById('delete'),
      _ => null,
    };

/// Tên nút/mục thật trong app, chèn vào câu hướng dẫn qua placeholder để
/// đường dẫn luôn khớp giao diện ở mọi ngôn ngữ.
const supportGuidePlaceholderKeys = <String, String>{
  'settings': 'settings',
  'home': 'nav_home',
  'apps': 'nav_apps',
  'update': 'nav_update',
  'security': 'settings_menu_security_title',
  'pairing': 'settings_partner_connect',
  'data': 'settings_menu_data_title',
  'widget': 'settings_menu_widget_title',
  'notifications': 'settings_notifications_interactions',
  'permissions': 'settings_menu_permissions_title',
  'gps': 'settings_gps_mode_title',
  'gps_foreground': 'settings_gps_mode_foreground',
  'gps_always': 'settings_gps_mode_always',
  'account': 'settings_profile_manage',
  'restore_purchases': 'home_khiphc_efda66',
  'restore_backup': 'settings_restore_from_cloud',
  'download_data': 'home_tidliucati_f2139a',
  'performance': 'settings_performance_mode_title',
  'perf_smoother': 'settings_perf_preset_smoother',
  'history': 'settings_activity_history',
  'delete': 'settings_delete_account_data',
  'countdown': 'settings_countdown_space_label',
  'delete_space': 'home_xakhnggian_e79cf3',
  'rewards': 'utility_title_store',
  'giftcode': 'utility_title_giftcode',
  'forgot': 'forgot_password',
  'pin_forgot': 'security_pin_forgot_title',
};

String _fillPlaceholders(String text, String Function(String) translate) =>
    text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final key = supportGuidePlaceholderKeys[match.group(1)];
      return key == null ? match.group(0)! : translate(key).trim();
    });

String supportGuideText(String key, String Function(String) translate) =>
    _fillPlaceholders(translate(key), translate);

List<String> supportGuideSteps(
  SupportGuideIssue issue,
  String Function(String) translate,
) => supportGuideText(issue.stepsKey, translate)
    .split('\n')
    .map((step) => step.trim())
    .where((step) => step.isNotEmpty)
    .toList(growable: false);

/// Tìm hướng dẫn khớp câu người dùng gõ (không dấu, mọi từ đều phải có).
List<SupportGuideIssue> searchSupportGuide(
  String query,
  String Function(String) translate, {
  int limit = 3,
}) {
  final words = normalizeHelpQuery(query)
      .split(' ')
      .where((word) => word.length >= 3)
      .toSet();
  if (words.isEmpty) return const [];
  final scored = <(SupportGuideIssue, int)>[];
  for (final category in supportGuideCategories) {
    final categoryText = normalizeHelpQuery(translate(category.titleKey));
    for (final issue in category.issues) {
      final title = normalizeHelpQuery(supportGuideText(issue.titleKey, translate));
      final body = normalizeHelpQuery(
        '${supportGuideText(issue.whyKey, translate)} '
        '${supportGuideText(issue.stepsKey, translate)}',
      );
      var score = 0;
      for (final word in words) {
        if (title.contains(word)) {
          score += 3;
        } else if (categoryText.contains(word)) {
          score += 2;
        } else if (body.contains(word)) {
          score += 1;
        }
      }
      if (score >= 2) scored.add((issue, score));
    }
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final item in scored.take(limit)) item.$1];
}
