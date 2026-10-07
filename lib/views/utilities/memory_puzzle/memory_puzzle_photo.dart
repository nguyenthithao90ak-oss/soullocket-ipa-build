import 'dart:ui' as ui;

/// Ảnh đã được nguồn dữ liệu kiểm tra quyền và tải đúng phạm vi phiên.
/// Màn chơi sở hữu [image] và giải phóng khi thay ảnh hoặc đóng màn.
class MemoryPuzzlePhoto {
  const MemoryPuzzlePhoto({
    required this.id,
    required this.image,
    this.fromCache = false,
    this.offline = false,
    this.availablePhotos = 1,
  });

  final String id;
  final ui.Image image;
  final bool fromCache;
  final bool offline;
  final int availablePhotos;
}

typedef MemoryPuzzlePhotoLoader =
    Future<MemoryPuzzlePhoto?> Function({
      String? excludePhotoId,
      String? preferredPhotoId,
    });
