import 'package:flutter/material.dart';

import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/soullocket_animated_sticker.dart';

abstract final class DiaryMoodCatalog {
  static List<Map<String, dynamic>> withCustom(String? customUrl) {
    final defaultMoods = <Map<String, dynamic>>[
      {
        'icon': '📝',
        'asset': SoulLocketStickerCatalog.originalReferenceFor(
          'diary_reflective',
        ),
        'label': L10nService().translate('diary_mood_calm'),
        'color': const Color(0xFF8D6E63),
      },
      {
        'icon': '🙈',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_shy'),
        'label': L10nService().translate('diary_mood_gentle'),
        'color': const Color(0xFFF06292),
      },
      {
        'icon': '💌',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_missing'),
        'label': L10nService().translate('diary_mood_missing'),
        'color': const Color(0xFFE91E63),
      },
      {
        'icon': '⭐',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_proud'),
        'label': L10nService().translate('diary_mood_proud'),
        'color': const Color(0xFFFFB300),
      },
      {
        'icon': '🌙',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_sleepy'),
        'label': L10nService().translate('diary_mood_sleepy'),
        'color': const Color(0xFF7E57C2),
      },
      {
        'icon': '🥺',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_anxious'),
        'label': L10nService().translate('diary_mood_hug'),
        'color': const Color(0xFF9575CD),
      },
      {
        'icon': '😤',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_grumpy'),
        'label': L10nService().translate('diary_mood_grumpy'),
        'color': const Color(0xFFEF5350),
      },
      {
        'icon': '😉',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_playful'),
        'label': L10nService().translate('diary_mood_playful'),
        'color': const Color(0xFF42A5F5),
      },
      {
        'icon': '❤️‍🩹',
        'asset': SoulLocketStickerCatalog.originalReferenceFor('diary_healing'),
        'label': L10nService().translate('diary_mood_healing'),
        'color': const Color(0xFF66BB6A),
      },
    ];

    return [
      {
        'icon': '📷',
        'isCustom': true,
        'asset': null,
        'customUrl': customUrl,
        'label': L10nService().translate('diary_custom_sticker_label'),
        'color': const Color(0xFF78909C),
      },
      ...defaultMoods,
    ];
  }
}
