import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

const List<String> utilitiesHubDefaultOrder = <String>[
  'local_album',
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

final Map<String, Map<String, dynamic>> appConfig = {
  'local_album': {
    'icon': Icons.photo_library_rounded,
    'colors': [const Color(0xFF7C4DFF), const Color(0xFF448AFF)],
    'title': L10nService().translate('util_luunhtbit_6f4b4a'),
  },
  'giftcode': {
    'icon': Icons.confirmation_number_rounded,
    'colors': [const Color(0xFFFF8A65), const Color(0xFFFF6F91)],
  },
  'voice': {
    'icon': Icons.graphic_eq_rounded,
    'colors': [const Color(0xFF26A69A), const Color(0xFF00897B)],
    'title': L10nService().translate('util_ghim_b8035c'),
  },
  'bucket': {
    'icon': Icons.checklist_rounded,
    'colors': [const Color(0xFF66BB6A), const Color(0xFF43A047)],
    'title': 'Bucket 100',
  },
  'note': {
    'icon': Icons.edit_note_rounded,
    'colors': [const Color(0xFFFFB74D), const Color(0xFFFF9800)],
    'title': L10nService().translate('util_ghich_b2a40d'),
  },
  'friendly_chat': {
    'icon': Icons.smart_toy_rounded,
    'colors': [const Color(0xFFD81B60), const Color(0xFFFF8FB7)],
    'title': L10nService().translate('util_chatthnthi_c39699'),
  },
  'wish': {
    'icon': Icons.star_rounded,
    'colors': [const Color(0xFF48C774), const Color(0xFF24B35B)],
    'title': 'Wish List',
  },
  'capsule': {
    'icon': Icons.mark_email_unread_rounded,
    'colors': [const Color(0xFFEC407A), const Color(0xFFD81B60)],
    'title': L10nService().translate('util_hpth_2eb02b'),
  },
  'finance': {
    'icon': Icons.account_balance_wallet_rounded,
    'colors': [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
    'title': L10nService().translate('util_tichnh_3998ba'),
  },
  'habit': {
    'icon': Icons.local_fire_department_rounded,
    'colors': [const Color(0xFF2D1B23), const Color(0xFF120B12)],
    'iconColor': const Color(0xFFFFF5F2),
    'title': L10nService().translate('util_thiquen_b0785c'),
  },
  'wheel': {
    'icon': Icons.pie_chart_rounded,
    'colors': [const Color(0xFFFF6FA3), const Color(0xFFFF5C93)],
    'title': L10nService().translate('util_vngquay_5051d4'),
  },
  'vault': {
    'icon': Icons.lock_person_rounded,
    'colors': [const Color(0xFFFF7A86), const Color(0xFFF6A0C6)],
    'title': L10nService().translate('util_khonhmt_2e47ef'),
  },
  'cinema': {
    'icon': Icons.local_movies_rounded,
    'colors': [const Color(0xFFF2655A), const Color(0xFFE74C3C)],
    'title': L10nService().translate('util_rpphim_7652be'),
  },
  'calendar': {
    'icon': Icons.event_note_rounded,
    'colors': [const Color(0xFF5A6BDA), const Color(0xFF4056C8)],
    'title': L10nService().translate('util_lchchung_801c40'),
  },
  'calculator': {
    'icon': Icons.calculate_rounded,
    'colors': [const Color(0xFF6C7AE0), const Color(0xFF8A98F4)],
    'title': L10nService().translate('util_mytnh_a98ede'),
  },
  'gift': {
    'icon': Icons.redeem_rounded,
    'colors': [const Color(0xFFF48FB1), const Color(0xFFF06292)],
    'title': L10nService().translate('util_lmqu_940cc1'),
  },
  'history': {
    'icon': Icons.history_rounded,
    'colors': [const Color(0xFF90CAF9), const Color(0xFF64B5F6)],
    'title': L10nService().translate('util_lchs_f8ec3e'),
  },
  'tarot': {
    'icon': Icons.auto_awesome_rounded,
    'colors': [const Color(0xFFB388FF), const Color(0xFF8E5CFF)],
    'title': 'Tarot',
  },
  'collage': {
    'icon': Icons.dashboard_customize_rounded,
    'colors': [const Color(0xFFFFB74D), const Color(0xFFFFCC80)],
    'title': L10nService().translate('util_ghpnh_fb3a4a'),
  },
  'store': {
    'icon': Icons.storefront_rounded,
    'colors': [const Color(0xFF4DD0E1), const Color(0xFFF06292)],
    'title': L10nService().translate('util_cahng_c7fe00'),
  },
  'age_zodiac': {
    'icon': Icons.stars_rounded,
    'colors': [const Color(0xFFD8A9F5), const Color(0xFFB96BDF)],
    'title': L10nService().translate('util_hongo_67356c'),
  },
  'drawing': {
    'icon': Icons.brush_rounded,
    'colors': [const Color(0xFFFF78AE), const Color(0xFFE63A7A)],
    'title': L10nService().translate('util_xngv_5f1f18'),
  },
  'sticker_library': {
    'icon': Icons.emoji_emotions_rounded,
    'colors': [const Color(0xFFFF8FB7), const Color(0xFF8E7BFF)],
    'title': 'Kho sticker',
  },
  'diary_export': {
    'icon': Icons.language_rounded,
    'colors': [const Color(0xFF69B7FF), const Color(0xFF7B61FF)],
    'title': L10nService().translate('util_xuthtml_c57dd1'),
  },
  'love_card': {
    'icon': Icons.style_rounded,
    'colors': [const Color(0xFFE94057), const Color(0xFFF27185)],
    'title': 'Love Card',
  },
  'creative_diary': {
    'icon': Icons.menu_book_rounded,
    'colors': [const Color(0xFF5CC172), const Color(0xFF2D8E47)],
    'title': L10nService().translate('util_ssngto_1095a7'),
  },
};

Map<String, dynamic> utilityConfigFor({
  required String utilityId,
  required IconData fallbackIcon,
  required List<Color> fallbackColors,
  required String fallbackTitle,
}) {
  final resolvedConfig = appConfig[utilityId];
  final safeFallbackColors = fallbackColors.isNotEmpty
      ? fallbackColors
      : const <Color>[Color(0xFFFF8FB7), Color(0xFF8E7BFF)];
  if (resolvedConfig == null) {
    return <String, dynamic>{
      'icon': fallbackIcon,
      'colors': safeFallbackColors,
      'title': fallbackTitle,
    };
  }

  final resolvedColors = resolvedConfig['colors'];
  final colors = resolvedColors is List<Color> && resolvedColors.isNotEmpty
      ? resolvedColors
      : safeFallbackColors;

  return <String, dynamic>{
    'icon': resolvedConfig['icon'] ?? fallbackIcon,
    'colors': colors,
    'title': fallbackTitle,
    if (resolvedConfig.containsKey('iconColor'))
      'iconColor': resolvedConfig['iconColor'],
    if (resolvedConfig.containsKey('isFire'))
      'isFire': resolvedConfig['isFire'],
  };
}
