import 'package:flutter/services.dart';

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
    for (final item in SoulLocketStickerCatalog.originals)
      if (!activeOriginalIds.contains(item.id))
        SoulLocketStickerCatalog.originalReferenceFor(item.id),
  ];

  // Chỉ đưa ảnh đã thực sự đóng gói vào kho trong app. Nguồn chưa đóng gói
  // vẫn ở thư mục gốc và được liệt kê riêng trong tài liệu kiểm kê.
  static bool isArchiveAsset(String path) =>
      (path.endsWith('.png') ||
          path.endsWith('.webp') ||
          path.endsWith('.gif')) &&
      (path.startsWith('assets/images/anhtomau_stickers/') ||
          path.startsWith('assets/images/sticker_import/cutout/') ||
          path.startsWith('assets/images/interaction_stickers/') ||
          path.startsWith('assets/images/utility_stickers/') ||
          path.startsWith('assets/images/milestone_embedded/') ||
          path.startsWith('assets/icons/cute_3d/') ||
          path ==
              'assets/images/soullocket_stickers/soul_merge_mascot_v2.webp');

  static Future<List<String>> loadArchive({AssetBundle? bundle}) async {
    final manifest = await AssetManifest.loadFromAssetBundle(
      bundle ?? rootBundle,
    );
    final paths = manifest.listAssets().where(isArchiveAsset).toList()..sort();
    return [
      ...archivedOriginals,
      for (final path in paths)
        SoulLocketStickerCatalog.originalAssetReferenceFor(path),
    ];
  }
}
