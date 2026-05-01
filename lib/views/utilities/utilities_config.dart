import 'package:flutter/material.dart';

const List<String> utilitiesHubDefaultOrder = <String>[
  'bucket',
  'note',
  'friendly_chat',
  'wish',
  'voice',
  'calendar',
  'finance',
  'habit',
  'capsule',
  'history',
  'gift',
  'love_card',
  'collage',
  'drawing',
  'creative_diary',
  'vault',
  'cinema',
  'wheel',
  'tarot',
  'age_zodiac',
  'sticker_library',
  'calculator',
  'diary_export',
  'store',
  'giftcode',
];

const Map<String, Map<String, dynamic>> appConfig = {
  'giftcode': {
    'icon': Icons.confirmation_number_rounded,
    'colors': [Color(0xFFFF8A65), Color(0xFFFF6F91)],
  },
  'voice': {
    'icon': Icons.graphic_eq_rounded,
    'colors': [Color(0xFF26A69A), Color(0xFF00897B)],
    'title': 'Ghi Âm',
  },
  'bucket': {
    'icon': Icons.checklist_rounded,
    'colors': [Color(0xFF66BB6A), Color(0xFF43A047)],
    'title': 'Bucket 100',
  },
  'note': {
    'icon': Icons.edit_note_rounded,
    'colors': [Color(0xFFFFB74D), Color(0xFFFF9800)],
    'title': 'Ghi Chú',
  },
  'friendly_chat': {
    'icon': Icons.smart_toy_rounded,
    'colors': [Color(0xFFD81B60), Color(0xFFFF8FB7)],
    'title': 'Chat thân thiện',
  },
  'wish': {
    'icon': Icons.star_rounded,
    'colors': [Color(0xFF48C774), Color(0xFF24B35B)],
    'title': 'Wish List',
  },
  'capsule': {
    'icon': Icons.mark_email_unread_rounded,
    'colors': [Color(0xFFEC407A), Color(0xFFD81B60)],
    'title': 'Hộp Thư',
  },
  'finance': {
    'icon': Icons.account_balance_wallet_rounded,
    'colors': [Color(0xFF42A5F5), Color(0xFF1E88E5)],
    'title': 'Tài Chính',
  },
  'habit': {
    'icon': Icons.local_fire_department_rounded,
    'colors': [Color(0xFF2D1B23), Color(0xFF120B12)],
    'iconColor': Color(0xFFFFF5F2),
    'title': 'Thói Quen',
  },
  'wheel': {
    'icon': Icons.pie_chart_rounded,
    'colors': [Color(0xFFFF6FA3), Color(0xFFFF5C93)],
    'title': 'Vòng Quay',
  },
  'vault': {
    'icon': Icons.lock_person_rounded,
    'colors': [Color(0xFFFF7A86), Color(0xFFF6A0C6)],
    'title': 'Kho Ảnh Mật',
  },
  'cinema': {
    'icon': Icons.local_movies_rounded,
    'colors': [Color(0xFFF2655A), Color(0xFFE74C3C)],
    'title': 'Rạp Phim',
  },
  'calendar': {
    'icon': Icons.event_note_rounded,
    'colors': [Color(0xFF5A6BDA), Color(0xFF4056C8)],
    'title': 'Lịch Chung',
  },
  'calculator': {
    'icon': Icons.calculate_rounded,
    'colors': [Color(0xFF6C7AE0), Color(0xFF8A98F4)],
    'title': 'Máy Tính',
  },
  'gift': {
    'icon': Icons.redeem_rounded,
    'colors': [Color(0xFFF48FB1), Color(0xFFF06292)],
    'title': 'Làm Quà',
  },
  'history': {
    'icon': Icons.history_rounded,
    'colors': [Color(0xFF90CAF9), Color(0xFF64B5F6)],
    'title': 'Lịch Sử',
  },
  'tarot': {
    'icon': Icons.auto_awesome_rounded,
    'colors': [Color(0xFFB388FF), Color(0xFF8E5CFF)],
    'title': 'Tarot',
  },
  'collage': {
    'icon': Icons.dashboard_customize_rounded,
    'colors': [Color(0xFFFFB74D), Color(0xFFFFCC80)],
    'title': 'Ghép Ảnh',
  },
  'store': {
    'icon': Icons.storefront_rounded,
    'colors': [Color(0xFF4DD0E1), Color(0xFFF06292)],
    'title': 'Cửa Hàng',
  },
  'age_zodiac': {
    'icon': Icons.stars_rounded,
    'colors': [Color(0xFFD8A9F5), Color(0xFFB96BDF)],
    'title': 'Hoàng Đạo',
  },
  'drawing': {
    'icon': Icons.brush_rounded,
    'colors': [Color(0xFFFF78AE), Color(0xFFE63A7A)],
    'title': 'Xưởng Vẽ',
  },
  'sticker_library': {
    'icon': Icons.emoji_emotions_rounded,
    'colors': [Color(0xFFFF8FB7), Color(0xFF8E7BFF)],
    'title': 'Kho sticker',
  },
  'diary_export': {
    'icon': Icons.language_rounded,
    'colors': [Color(0xFF69B7FF), Color(0xFF7B61FF)],
    'title': 'Xuất HTML',
  },
  'love_card': {
    'icon': Icons.style_rounded,
    'colors': [Color(0xFFE94057), Color(0xFFF27185)],
    'title': 'Love Card',
  },
  'creative_diary': {
    'icon': Icons.menu_book_rounded,
    'colors': [Color(0xFF5CC172), Color(0xFF2D8E47)],
    'title': 'Sổ Sáng Tạo',
  },
};

Map<String, dynamic> utilityConfigFor({
  required String utilityId,
  required IconData fallbackIcon,
  required List<Color> fallbackColors,
  required String fallbackTitle,
}) {
  final resolvedConfig = appConfig[utilityId];
  if (resolvedConfig == null) {
    return <String, dynamic>{
      'icon': fallbackIcon,
      'colors': fallbackColors,
      'title': fallbackTitle,
    };
  }

  return <String, dynamic>{
    'icon': resolvedConfig['icon'] ?? fallbackIcon,
    'colors': resolvedConfig['colors'] ?? fallbackColors,
    'title': fallbackTitle,
    if (resolvedConfig.containsKey('iconColor'))
      'iconColor': resolvedConfig['iconColor'],
    if (resolvedConfig.containsKey('isFire'))
      'isFire': resolvedConfig['isFire'],
  };
}
