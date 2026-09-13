import 'soullocket_animated_sticker.dart';

/// Bộ gấu/thỏ ở khay tín hiệu Home, tách khỏi bộ nét vẽ mới trong chat.
abstract final class HomeInteractionStickers {
  static const originalIds = <String, String>{
    'miss': 'motion_missing',
    'angry': 'diary_grumpy',
    'furious': 'diary_grumpy',
    'kiss': 'motion_kiss',
    'tease': 'motion_tease',
    'hug': 'motion_cuddle',
    'cry': 'motion_comfort',
    'poop': 'diary_playful',
  };

  static String defaultFor(String type) =>
      SoulLocketStickerCatalog.originalReferenceFor(
        originalIds[type] ?? originalIds['miss']!,
      );

  static const _previousDefaults = <String, Set<String>>{
    'miss': {'novelty_star_love'},
    'angry': {'heart_healing', 'mood_pout'},
    'furious': {'heart_heartbeat', 'mood_furious'},
    'kiss': {'novelty_moon_kiss'},
    'tease': {'novelty_ghost_tease'},
    'hug': {'novelty_cloud_hug'},
    'cry': {'novelty_raindrop_comfort'},
    'poop': {'novelty_game_party'},
  };

  /// Chỉ phục hồi mặc định của bản trước một lần. Ảnh tự chọn không bị xóa;
  /// lựa chọn mới sau khi lưu vẫn được giữ, kể cả chọn lại bộ nét vẽ mới.
  static String resolve(String type, String? saved, {bool restored = false}) {
    final reference = saved?.trim() ?? '';
    if (reference.isEmpty) return defaultFor(type);
    if (!restored &&
        (_previousDefaults[type] ?? const <String>{}).any(
          (id) => reference == SoulLocketStickerCatalog.referenceFor(id),
        )) {
      return defaultFor(type);
    }
    return reference;
  }

  static const restoredPreference = 'home_original_stickers_restored_v1';
}
