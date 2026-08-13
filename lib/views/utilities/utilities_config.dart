import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

const List<String> utilitiesHubDefaultOrder = <String>[
  'local_album',
  'note',
  'friendly_chat',
  'voice',
  'calendar',
  'finance',
  'habit',
  'health',
  'sleep_tracker',
  'capsule',
  'gift',
  'love_card',
  'collage',
  'drawing',
  'creative_diary',
  'vault',
  'cinema',
  'wheel',
  'tarot',
  'diary_export',
  'store',
  'giftcode',
];

final Map<String, Map<String, dynamic>> appConfig = {
  'local_album': {
    'icon': Icons.photo_library_rounded,
    'colors': [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
    'title': L10nService().translate('util_luunhtbit_6f4b4a'),
  },
  'giftcode': {
    'icon': Icons.confirmation_number_rounded,
    'colors': [const Color(0xFFFF512F), const Color(0xFFDD2476)],
  },
  'voice': {
    'icon': Icons.graphic_eq_rounded,
    'colors': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    'title': L10nService().translate('util_ghim_b8035c'),
  },
  'note': {
    'icon': Icons.menu_book_rounded,
    'colors': [const Color(0xFFFF8008), const Color(0xFFFFC837)],
    'title': 'Sổ tay chung',
  },
  'friendly_chat': {
    'icon': Icons.smart_toy_rounded,
    'colors': [const Color(0xFFFF2A85), const Color(0xFFFF758C)],
    'title': L10nService().translate('util_chatthnthi_c39699'),
  },
  'capsule': {
    'icon': Icons.mark_email_unread_rounded,
    'colors': [const Color(0xFFF857A6), const Color(0xFFFF5858)],
    'title': L10nService().translate('util_hpth_2eb02b'),
  },
  'finance': {
    'icon': Icons.account_balance_wallet_rounded,
    'colors': [const Color(0xFF00C6FF), const Color(0xFF0072FF)],
    'title': L10nService().translate('util_tichnh_3998ba'),
  },
  'habit': {
    'icon': Icons.local_fire_department_rounded,
    'colors': [const Color(0xFFFF512F), const Color(0xFFF09819)],
    'title': L10nService().translate('util_thiquen_b0785c'),
  },
  'health': {
    'icon': Icons.health_and_safety_rounded,
    'colors': [const Color(0xFF00F260), const Color(0xFF0575E6)],
    'title': L10nService().translate('health'),
  },
  'sleep_tracker': {
    'icon': Icons.bedtime_rounded,
    'colors': [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)],
    'title': 'Giấc ngủ',
  },
  'wheel': {
    'icon': Icons.pie_chart_rounded,
    'colors': [const Color(0xFFFF3366), const Color(0xFFFF655B)],
    'title': L10nService().translate('util_vngquay_5051d4'),
  },
  'vault': {
    'icon': Icons.lock_person_rounded,
    'colors': [const Color(0xFF232526), const Color(0xFF414345)],
    'iconColor': const Color(0xFFFFD700),
    'title': L10nService().translate('util_khonhmt_2e47ef'),
  },
  'cinema': {
    'icon': Icons.local_movies_rounded,
    'colors': [const Color(0xFFED213A), const Color(0xFF93291E)],
    'title': L10nService().translate('util_rpphim_7652be'),
  },
  'calendar': {
    'icon': Icons.event_note_rounded,
    'colors': [const Color(0xFF3A7BD5), const Color(0xFF3A6073)],
    'title': L10nService().translate('util_lchchung_801c40'),
  },
  'gift': {
    'icon': Icons.redeem_rounded,
    'colors': [const Color(0xFFFF4E50), const Color(0xFFF9D423)],
    'title': L10nService().translate('util_lmqu_940cc1'),
  },
  'tarot': {
    'icon': Icons.auto_awesome_rounded,
    'colors': [const Color(0xFFDA22FF), const Color(0xFF9733EE)],
    'title': 'Tarot',
  },
  'collage': {
    'icon': Icons.dashboard_customize_rounded,
    'colors': [const Color(0xFF2193B0), const Color(0xFF6DD5ED)],
    'title': L10nService().translate('util_ghpnh_fb3a4a'),
  },
  'store': {
    'icon': Icons.storefront_rounded,
    'colors': [const Color(0xFFE55D87), const Color(0xFF5FC3E4)],
    'title': L10nService().translate('util_cahng_c7fe00'),
  },
  'diary_export': {
    'icon': Icons.language_rounded,
    'colors': [const Color(0xFF4568DC), const Color(0xFFB06AB3)],
    'title': L10nService().translate('util_xuthtml_c57dd1'),
  },
  'love_card': {
    'icon': Icons.style_rounded,
    'colors': [const Color(0xFFF80759), const Color(0xFFBC4E9C)],
    'title': 'Love Card',
  },
  'creative_diary': {
    'icon': Icons.menu_book_rounded,
    'colors': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    'title': L10nService().translate('util_ssngto_1095a7'),
  },
  'drawing': {
    'icon': Icons.brush_rounded,
    'colors': [const Color(0xFFFF007F), const Color(0xFF7928CA)],
    'title': L10nService().translate('util_xngv_c89b3f'),
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
