import 'home_interaction_stickers.dart';
import 'soullocket_animated_sticker.dart';

/// Phân loại theo cấu hình app, không suy đoán lịch sử gửi của người dùng.
abstract final class StickerCollection {
  static Set<String> get activeOriginalIds => {
    ...SoulLocketStickerCatalog.diaryMoodStickers.map((item) => item.id),
    ...HomeInteractionStickers.originalIds.values,
  };

  static List<String> get activeOriginals => [
    for (final id in activeOriginalIds)
      SoulLocketStickerCatalog.originalReferenceFor(id),
  ];

  static List<String> get archivedOriginals => [
    for (final item in [
      ...SoulLocketStickerCatalog.noveltyStickers,
      ...SoulLocketStickerCatalog.motionStickers,
      ...SoulLocketStickerCatalog.heartStickers,
    ])
      if (!activeOriginalIds.contains(item.id))
        SoulLocketStickerCatalog.originalReferenceFor(item.id),
  ];

  static Future<List<String>> loadArchive() async =>
      List.unmodifiable(archivedOriginals);
}
