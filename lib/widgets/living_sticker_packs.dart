import 'package:flutter/material.dart';

import 'soullocket_animated_sticker.dart';

@immutable
class LivingStickerPack {
  const LivingStickerPack(
    this.id,
    this.titleKey,
    this.icon,
    this.accent,
    this.surface,
    this.stickers,
  );
  final String id;
  final String titleKey;
  final IconData icon;
  final Color accent;
  final Color surface;
  final List<SoulLocketStickerSpec> stickers;
  String get styleKey => _styleKeys[id]!;
  static const _styleKeys = {
    'joy': 'p4_soul_sticker_style_joy',
    'love': 'p4_soul_sticker_style_love',
    'sulking': 'p4_soul_sticker_style_sulking',
    'sad': 'p4_soul_sticker_style_sad',
    'playful': 'p4_soul_sticker_style_playful',
    'novelty': 'p4_soul_sticker_style_novelty',
    'hearts': 'p4_soul_sticker_style_hearts',
    'couple': 'p4_soul_sticker_style_couple',
    'emotions': 'p4_soul_sticker_style_emotions',
    'diary': 'p4_soul_sticker_style_diary',
  };
}

/// Cùng bộ và cùng thứ tự trong chat, Soul Merge, Home và thư viện.
const livingStickerPacks = [
  LivingStickerPack(
    'emotions',
    'p4_soul_sticker_pack_emotions',
    Icons.emoji_emotions_rounded,
    Color(0xFF9B631A),
    Color(0xFFFFF4DD),
    SoulLocketStickerCatalog.soulMergeCuteEmotionStickers,
  ),
  LivingStickerPack(
    'joy',
    'p4_soul_sticker_pack_joy',
    Icons.sentiment_very_satisfied_rounded,
    Color(0xFFB67A27),
    Color(0xFFFFF3DF),
    SoulLocketStickerCatalog.soulMergeJoyStickers,
  ),
  LivingStickerPack(
    'love',
    'p4_soul_sticker_pack_love',
    Icons.favorite_rounded,
    Color(0xFFCA4C75),
    Color(0xFFFFEAF0),
    SoulLocketStickerCatalog.soulMergeLoveStickers,
  ),
  // Giữ trong catalog để URI cũ vẫn đọc được, nhưng không đưa vào picker.
  LivingStickerPack(
    'sulking',
    'p4_soul_sticker_pack_sulking',
    Icons.sentiment_dissatisfied_rounded,
    Color(0xFFC36E48),
    Color(0xFFFFEDDF),
    SoulLocketStickerCatalog.sulkingStickers,
  ),
  LivingStickerPack(
    'sad',
    'p4_soul_sticker_pack_sad',
    Icons.cloud_rounded,
    Color(0xFF7E81B8),
    Color(0xFFF0F0FB),
    SoulLocketStickerCatalog.soulMergeComfortStickers,
  ),
  LivingStickerPack(
    'playful',
    'p4_soul_sticker_pack_playful',
    Icons.auto_awesome_rounded,
    Color(0xFF6389C8),
    Color(0xFFEAF3FF),
    SoulLocketStickerCatalog.soulMergePlayfulStickers,
  ),
  LivingStickerPack(
    'novelty',
    'interaction_sticker_category_novelty',
    Icons.bubble_chart_rounded,
    Color(0xFF8065BA),
    Color(0xFFF3EDFF),
    SoulLocketStickerCatalog.noveltyStickers,
  ),
  LivingStickerPack(
    'hearts',
    'interaction_sticker_category_hearts',
    Icons.favorite_border_rounded,
    Color(0xFFCA4C75),
    Color(0xFFFFEAF0),
    SoulLocketStickerCatalog.heartStickers,
  ),
  LivingStickerPack(
    'couple',
    'interaction_sticker_category_couple',
    Icons.diversity_1_rounded,
    Color(0xFF488E7F),
    Color(0xFFEAF7F1),
    SoulLocketStickerCatalog.motionStickers,
  ),
  LivingStickerPack(
    'diary',
    'sticker_pack_diary',
    Icons.auto_stories_rounded,
    Color(0xFF8065BA),
    Color(0xFFF3EDFF),
    SoulLocketStickerCatalog.diaryMoodStickers,
  ),
];

/// Bộ Dỗi cũ: chỉ giữ dự phòng cho dữ liệu đã lưu, không hiển thị trong UI.
final livingStickerPacksBackup = List.unmodifiable(
  livingStickerPacks.where((pack) => pack.id == 'sulking'),
);

/// Các bộ được phép chọn trong Soul Merge và thư viện sticker hiện tại.
final livingStickerPickerPacks = List.unmodifiable(
  livingStickerPacks.where((pack) => pack.id != 'sulking'),
);
