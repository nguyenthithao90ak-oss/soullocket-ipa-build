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
    'colors': [const Color(0xFFB07CE8), const Color(0xFF8B5CF6)],
    'title': L10nService().translate('util_luunhtbit_6f4b4a'),
  },
  'giftcode': {
    'icon': Icons.confirmation_number_rounded,
    'colors': [const Color(0xFFFF7E6B), const Color(0xFFE8507A)],
  },
  'friendly_chat': {
    'icon': Icons.smart_toy_rounded,
    'colors': [const Color(0xFFFF6B9D), const Color(0xFFF472B6)],
    'title': L10nService().translate('util_chatthnthi_c39699'),
  },
  'capsule': {
    'icon': Icons.mark_email_unread_rounded,
    'colors': [const Color(0xFFF472B6), const Color(0xFFEC4899)],
    'title': L10nService().translate('util_hpth_2eb02b'),
  },
  'finance': {
    'icon': Icons.account_balance_wallet_rounded,
    'colors': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
    'title': L10nService().translate('util_tichnh_3998ba'),
  },
  'habit': {
    'icon': Icons.local_fire_department_rounded,
    'colors': [const Color(0xFFFB923C), const Color(0xFFF97316)],
    'title': L10nService().translate('util_thiquen_b0785c'),
  },
  'health': {
    'icon': Icons.health_and_safety_rounded,
    'colors': [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
    'title': L10nService().translate('health'),
  },
  'sleep_tracker': {
    'icon': Icons.bedtime_rounded,
    'colors': [const Color(0xFF818CF8), const Color(0xFF6366F1)],
    'title': 'Giấc ngủ',
  },
  'wheel': {
    'icon': Icons.pie_chart_rounded,
    'colors': [const Color(0xFFFB7185), const Color(0xFFF43F5E)],
    'category': 'practical',
  },
  'calendar': {
    'icon': Icons.event_note_rounded,
    'colors': [const Color(0xFF90C8F0), const Color(0xFF5B9BD5)],
    'title': L10nService().translate('util_lchchung_801c40'),
    'category': 'practical',
  },
  'note': {
    'icon': Icons.menu_book_rounded,
    'colors': [const Color(0xFF94D0E8), const Color(0xFF5BA8C8)],
    'title': 'Sổ tay chung',
    'category': 'practical',
  },
  'voice': {
    'icon': Icons.graphic_eq_rounded,
    'colors': [const Color(0xFF7CC5C8), const Color(0xFF4AA8AC)],
    'title': L10nService().translate('util_ghim_b8035c'),
    'category': 'practical',
  },
  'store': {
    'icon': Icons.storefront_rounded,
    'colors': [const Color(0xFF88BDD8), const Color(0xFF5A9BBF)],
    'title': L10nService().translate('util_cahng_c7fe00'),
    'category': 'practical',
  },
  'gift': {
    'icon': Icons.redeem_rounded,
    'colors': [const Color(0xFF7DCAD0), const Color(0xFF4FAFB7)],
    'title': L10nService().translate('util_lmqu_940cc1'),
    'category': 'practical',
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
