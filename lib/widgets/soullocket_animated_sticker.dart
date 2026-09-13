import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'living_sticker.dart';
import 'living_sticker_scene.dart';
import 'original_sticker.dart';

enum SoulLocketStickerMotion {
  gentleFloat,
  pulse,
  bounce,
  sway,
  heartbeat,
  breathe,
  drift,
  wobble,
}

@immutable
class SoulLocketStickerSpec {
  final String id;
  final String assetPath;
  final int column;
  final int row;
  final int columns;
  final int rows;
  final SoulLocketStickerMotion motion;
  final Duration duration;

  const SoulLocketStickerSpec({
    required this.id,
    required this.assetPath,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
    required this.motion,
    this.duration = const Duration(milliseconds: 2600),
  });

  const SoulLocketStickerSpec.living(this.id)
    : assetPath = '',
      column = 0,
      row = 0,
      columns = 1,
      rows = 1,
      motion = SoulLocketStickerMotion.breathe,
      duration = const Duration(milliseconds: 4800);
}

/// Kho sticker nội bộ có URI ổn định để thay asset mà không đổi dữ liệu đã lưu.
abstract final class SoulLocketStickerCatalog {
  static const String uriPrefix = 'soullocket://sticker/';
  // Tách phiên bản hình để việc chọn bộ cũ không bị renderer bộ mới ghi đè.
  static const String originalPrefix = 'soullocket://original-sticker/';
  static const String originalAssetPrefix = 'soullocket://original-asset/';
  static const String motionAtlas =
      'assets/images/soullocket_stickers/motion_couple_atlas_v1.webp';
  static const String heartAtlas =
      'assets/images/soullocket_stickers/heart_atlas_v1.webp';
  static const String noveltyAtlas =
      'assets/images/soullocket_stickers/novelty_atlas_v1.webp';
  static const String diaryMoodAtlas =
      'assets/images/transparent_stickers/diary_mood_atlas_v2_transparent.webp';
  static const String soulMergeJoyAtlas =
      'assets/images/soullocket_stickers/soul_merge_joy_atlas_v1.webp';
  static const String soulMergeComfortAtlas =
      'assets/images/transparent_stickers/soul_merge_comfort_atlas_v2_transparent.webp';
  static const String soulMergeLoveAtlas =
      'assets/images/transparent_stickers/soul_merge_love_atlas_v2_transparent.webp';
  static const String soulMergePlayfulAtlas =
      'assets/images/transparent_stickers/soul_merge_playful_atlas_v2_transparent.webp';

  /// Bộ sticker đồ vật và nhân vật tưởng tượng, tránh lặp lại gấu/thỏ.
  static const List<SoulLocketStickerSpec> noveltyStickers = [
    SoulLocketStickerSpec(
      id: 'novelty_star_love',
      assetPath: noveltyAtlas,
      column: 0,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.drift,
    ),
    SoulLocketStickerSpec(
      id: 'novelty_planet_crush',
      assetPath: noveltyAtlas,
      column: 1,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'novelty_robot_laugh',
      assetPath: noveltyAtlas,
      column: 2,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
      duration: Duration(milliseconds: 2200),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_moon_kiss',
      assetPath: noveltyAtlas,
      column: 3,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'novelty_ghost_tease',
      assetPath: noveltyAtlas,
      column: 0,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
      duration: Duration(milliseconds: 2100),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_cloud_hug',
      assetPath: noveltyAtlas,
      column: 1,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3200),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_raindrop_comfort',
      assetPath: noveltyAtlas,
      column: 2,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
      duration: Duration(milliseconds: 3000),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_game_party',
      assetPath: noveltyAtlas,
      column: 3,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
      duration: Duration(milliseconds: 1900),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_coffee_date',
      assetPath: noveltyAtlas,
      column: 0,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'novelty_music_mix',
      assetPath: noveltyAtlas,
      column: 1,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
      duration: Duration(milliseconds: 2300),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_mushroom_cuddle',
      assetPath: noveltyAtlas,
      column: 2,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3400),
    ),
    SoulLocketStickerSpec(
      id: 'novelty_love_plane',
      assetPath: noveltyAtlas,
      column: 3,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.drift,
      duration: Duration(milliseconds: 2400),
    ),
  ];

  static const List<SoulLocketStickerSpec> motionStickers = [
    SoulLocketStickerSpec(
      id: 'motion_missing',
      assetPath: motionAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'motion_cuddle',
      assetPath: motionAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'motion_kiss',
      assetPath: motionAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'motion_tease',
      assetPath: motionAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
      duration: Duration(milliseconds: 2200),
    ),
    SoulLocketStickerSpec(
      id: 'motion_comfort',
      assetPath: motionAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3200),
    ),
    SoulLocketStickerSpec(
      id: 'motion_celebrate',
      assetPath: motionAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'motion_sleep',
      assetPath: motionAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3600),
    ),
    SoulLocketStickerSpec(
      id: 'motion_send_love',
      assetPath: motionAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.drift,
    ),
    SoulLocketStickerSpec(
      id: 'motion_dance',
      assetPath: motionAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
      duration: Duration(milliseconds: 2100),
    ),
  ];

  static const List<SoulLocketStickerSpec> heartStickers = [
    SoulLocketStickerSpec(
      id: 'heart_scrapbook',
      assetPath: heartAtlas,
      column: 0,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'heart_plush',
      assetPath: heartAtlas,
      column: 1,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
    ),
    SoulLocketStickerSpec(
      id: 'heart_glass',
      assetPath: heartAtlas,
      column: 2,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'heart_letter',
      assetPath: heartAtlas,
      column: 3,
      row: 0,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'heart_locket',
      assetPath: heartAtlas,
      column: 0,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'heart_healing',
      assetPath: heartAtlas,
      column: 1,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3300),
    ),
    SoulLocketStickerSpec(
      id: 'heart_sleep',
      assetPath: heartAtlas,
      column: 2,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
      duration: Duration(milliseconds: 3400),
    ),
    SoulLocketStickerSpec(
      id: 'heart_celebrate',
      assetPath: heartAtlas,
      column: 3,
      row: 1,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'heart_thread',
      assetPath: heartAtlas,
      column: 0,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'heart_calendar',
      assetPath: heartAtlas,
      column: 1,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'heart_heartbeat',
      assetPath: heartAtlas,
      column: 2,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
      duration: Duration(milliseconds: 1800),
    ),
    SoulLocketStickerSpec(
      id: 'heart_gift',
      assetPath: heartAtlas,
      column: 3,
      row: 2,
      columns: 4,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
  ];

  static const List<SoulLocketStickerSpec> diaryMoodStickers = [
    SoulLocketStickerSpec(
      id: 'diary_reflective',
      assetPath: diaryMoodAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'diary_shy',
      assetPath: diaryMoodAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'diary_missing',
      assetPath: diaryMoodAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'diary_proud',
      assetPath: diaryMoodAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'diary_sleepy',
      assetPath: diaryMoodAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
      duration: Duration(milliseconds: 3400),
    ),
    SoulLocketStickerSpec(
      id: 'diary_anxious',
      assetPath: diaryMoodAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
    ),
    SoulLocketStickerSpec(
      id: 'diary_grumpy',
      assetPath: diaryMoodAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
      duration: Duration(milliseconds: 2100),
    ),
    SoulLocketStickerSpec(
      id: 'diary_playful',
      assetPath: diaryMoodAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'diary_healing',
      assetPath: diaryMoodAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
    ),
  ];

  /// Bộ sticker riêng cho Soul Merge, chia theo cảm xúc để tìm nhanh trong chat.
  static const List<SoulLocketStickerSpec> soulMergeJoyStickers = [
    SoulLocketStickerSpec(
      id: 'merge_joy_confetti',
      assetPath: soulMergeJoyAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_laugh',
      assetPath: soulMergeJoyAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_dance',
      assetPath: soulMergeJoyAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_high_five',
      assetPath: soulMergeJoyAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_big_heart',
      assetPath: soulMergeJoyAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_wave',
      assetPath: soulMergeJoyAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_coffee_date',
      assetPath: soulMergeJoyAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_cake',
      assetPath: soulMergeJoyAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_joy_send_hearts',
      assetPath: soulMergeJoyAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.drift,
    ),
  ];

  static const List<SoulLocketStickerSpec> soulMergeComfortStickers = [
    SoulLocketStickerSpec(
      id: 'merge_comfort_hold',
      assetPath: soulMergeComfortAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_tissues',
      assetPath: soulMergeComfortAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_blanket',
      assetPath: soulMergeComfortAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_rainy',
      assetPath: soulMergeComfortAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_holding_hands',
      assetPath: soulMergeComfortAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_healing',
      assetPath: soulMergeComfortAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_goodnight',
      assetPath: soulMergeComfortAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_sorry',
      assetPath: soulMergeComfortAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'merge_comfort_hug',
      assetPath: soulMergeComfortAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
  ];

  static const List<SoulLocketStickerSpec> soulMergeLoveStickers = [
    SoulLocketStickerSpec(
      id: 'merge_love_big_heart',
      assetPath: soulMergeLoveAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.heartbeat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_cheek_kiss',
      assetPath: soulMergeLoveAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_umbrella',
      assetPath: soulMergeLoveAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_letter',
      assetPath: soulMergeLoveAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.drift,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_pinky',
      assetPath: soulMergeLoveAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.pulse,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_dance',
      assetPath: soulMergeLoveAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_locket',
      assetPath: soulMergeLoveAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_flowers',
      assetPath: soulMergeLoveAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_love_cuddle',
      assetPath: soulMergeLoveAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
  ];

  static const List<SoulLocketStickerSpec> soulMergePlayfulStickers = [
    SoulLocketStickerSpec(
      id: 'merge_playful_tease',
      assetPath: soulMergePlayfulAtlas,
      column: 0,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_peekaboo',
      assetPath: soulMergePlayfulAtlas,
      column: 1,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_game',
      assetPath: soulMergePlayfulAtlas,
      column: 2,
      row: 0,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_photo',
      assetPath: soulMergePlayfulAtlas,
      column: 0,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.gentleFloat,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_snack',
      assetPath: soulMergePlayfulAtlas,
      column: 1,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_faces',
      assetPath: soulMergePlayfulAtlas,
      column: 2,
      row: 1,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.wobble,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_shopping',
      assetPath: soulMergePlayfulAtlas,
      column: 0,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.sway,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_singing',
      assetPath: soulMergePlayfulAtlas,
      column: 1,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.bounce,
    ),
    SoulLocketStickerSpec(
      id: 'merge_playful_movie',
      assetPath: soulMergePlayfulAtlas,
      column: 2,
      row: 2,
      columns: 3,
      rows: 3,
      motion: SoulLocketStickerMotion.breathe,
    ),
  ];

  static const List<SoulLocketStickerSpec> sulkingStickers = [
    SoulLocketStickerSpec.living('mood_pout'),
    SoulLocketStickerSpec.living('mood_crossed_arms'),
    SoulLocketStickerSpec.living('mood_angry'),
    SoulLocketStickerSpec.living('mood_furious'),
    SoulLocketStickerSpec.living('mood_sulking'),
    SoulLocketStickerSpec.living('mood_sorry'),
    SoulLocketStickerSpec.living('mood_make_up'),
    SoulLocketStickerSpec.living('mood_jealous'),
    SoulLocketStickerSpec.living('mood_peace'),
  ];

  static const List<SoulLocketStickerSpec> all = [
    ...noveltyStickers,
    ...motionStickers,
    ...heartStickers,
    ...diaryMoodStickers,
    ...soulMergeJoyStickers,
    ...soulMergeComfortStickers,
    ...soulMergeLoveStickers,
    ...soulMergePlayfulStickers,
    ...sulkingStickers,
  ];

  static String referenceFor(String id) => '$uriPrefix$id';

  static String originalReferenceFor(String id) => '$originalPrefix$id';

  static String originalAssetReferenceFor(String path) =>
      '$originalAssetPrefix$path';

  static Iterable<SoulLocketStickerSpec> get originals =>
      all.where((sticker) => sticker.assetPath.isNotEmpty);

  static SoulLocketStickerSpec? find(String idOrReference) {
    final original = idOrReference.startsWith(originalPrefix);
    final id = original
        ? idOrReference.substring(originalPrefix.length)
        : idOrReference.startsWith(uriPrefix)
        ? idOrReference.substring(uriPrefix.length)
        : idOrReference;
    for (final sticker in all) {
      if (sticker.id == id && (!original || sticker.assetPath.isNotEmpty)) {
        return sticker;
      }
    }
    return null;
  }
}

class SoulLocketAnimatedSticker extends StatelessWidget {
  final SoulLocketStickerSpec sticker;
  final double size;
  final bool animate;
  final String? semanticLabel;
  final FilterQuality filterQuality;
  final bool originalArtwork;

  const SoulLocketAnimatedSticker({
    super.key,
    required this.sticker,
    required this.size,
    this.animate = true,
    this.semanticLabel,
    this.filterQuality = FilterQuality.medium,
    this.originalArtwork = false,
  });

  @override
  Widget build(BuildContext context) {
    final scene = originalArtwork
        ? null
        : LivingStickerCatalog.find(sticker.id);
    final visual = scene != null
        ? LivingSticker(
            scene: scene,
            width: size,
            height: size,
            animate: animate,
          )
        : OriginalSticker(
            assetPath: sticker.assetPath,
            stickerId: sticker.id,
            column: sticker.column,
            row: sticker.row,
            columns: sticker.columns,
            rows: sticker.rows,
            width: size,
            height: size,
            animate: animate,
            filterQuality: filterQuality,
          );
    if (semanticLabel == null) return visual;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: visual),
    );
  }
}

/// Dùng chung chuyển động cho sticker atlas và hình tĩnh, không đổi asset gốc.
class SoulLocketStickerMotionView extends StatefulWidget {
  final Widget child;
  final SoulLocketStickerMotion motion;
  final Duration duration;
  final bool animate;
  final double phaseOffset;

  const SoulLocketStickerMotionView({
    super.key,
    required this.child,
    this.motion = SoulLocketStickerMotion.gentleFloat,
    this.duration = const Duration(milliseconds: 2800),
    this.animate = true,
    this.phaseOffset = 0,
  }) : assert(duration > Duration.zero),
       assert(phaseOffset >= 0 && phaseOffset < 1);

  @override
  State<SoulLocketStickerMotionView> createState() =>
      _SoulLocketStickerMotionViewState();
}

class _SoulLocketStickerMotionViewState
    extends State<SoulLocketStickerMotionView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _motionEnabled = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant SoulLocketStickerMotionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (_motionEnabled) _controller.repeat();
    }
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    setState(() {
      _foreground = foreground;
      _syncMotion();
    });
  }

  void _syncMotion() {
    final enabled =
        widget.animate &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motionEnabled == enabled) return;
    _motionEnabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = RepaintBoundary(child: widget.child);
    return _motionEnabled
        ? AnimatedBuilder(
            animation: _controller,
            child: sprite,
            builder: (context, child) {
              final phase =
                  (_controller.value + widget.phaseOffset) * math.pi * 2;
              var scale = 1.0;
              var rotation = 0.0;
              var offset = Offset.zero;

              switch (widget.motion) {
                case SoulLocketStickerMotion.gentleFloat:
                  offset = Offset(math.cos(phase) * 0.8, math.sin(phase) * 2.4);
                  rotation = math.sin(phase) * 0.018;
                  break;
                case SoulLocketStickerMotion.pulse:
                  scale = 1 + ((math.sin(phase) + 1) * 0.022);
                  break;
                case SoulLocketStickerMotion.bounce:
                  offset = Offset(0, -math.max(0, math.sin(phase)) * 4.2);
                  rotation = math.sin(phase) * 0.018;
                  break;
                case SoulLocketStickerMotion.sway:
                  rotation = math.sin(phase) * 0.045;
                  offset = Offset(0, math.cos(phase) * 1.0);
                  break;
                case SoulLocketStickerMotion.heartbeat:
                  final beat = math
                      .pow(math.max(0, math.sin(phase * 2)), 7)
                      .toDouble();
                  scale = 1 + beat * 0.075;
                  break;
                case SoulLocketStickerMotion.breathe:
                  scale = 1 + ((math.sin(phase) + 1) * 0.012);
                  offset = Offset(0, math.sin(phase) * 1.1);
                  break;
                case SoulLocketStickerMotion.drift:
                  offset = Offset(
                    math.sin(phase) * 3.0,
                    -math.cos(phase) * 1.7,
                  );
                  rotation = math.sin(phase) * 0.026;
                  break;
                case SoulLocketStickerMotion.wobble:
                  rotation = math.sin(phase * 2) * 0.055;
                  scale = 1 + math.max(0, math.sin(phase)) * 0.018;
                  break;
              }

              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
          )
        : sprite;
  }
}
