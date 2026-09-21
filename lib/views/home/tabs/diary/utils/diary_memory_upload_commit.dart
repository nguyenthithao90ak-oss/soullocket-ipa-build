class DiaryMemoryQuotaExceeded implements Exception {
  const DiaryMemoryQuotaExceeded();
}

/// Ghi kỷ niệm và bộ đếm trong cùng một lần cập nhật nguyên tử.
/// ID được giữ trong nhật ký chờ để lần thử lại không cộng dung lượng lần hai.
abstract final class DiaryMemoryUploadCommit {
  static Future<bool> commit({
    required String houseId,
    required String uid,
    required String day,
    required String memoryId,
    required Map<String, dynamic> payload,
    required Future<bool> Function(String path) exists,
    required Future<void> Function(Map<String, dynamic> values) update,
    required Object Function(int bytes) increment,
  }) async {
    final root = 'houses/$houseId';
    final memoryPath = '$root/memories/$memoryId';
    if (await exists(memoryPath)) return false;
    final mediaBytes = (payload['fileSize'] as num?)?.toInt() ?? 0;
    final thumbnailBytes = (payload['thumbnailBytes'] as num?)?.toInt() ?? 0;
    final isVideo = payload['type'] == 'video';
    final counts = {
      'image': (isVideo ? 0 : mediaBytes) + thumbnailBytes,
      'video': isVideo ? mediaBytes : 0,
    };
    await update({
      memoryPath: payload,
      for (final entry in counts.entries)
        if (entry.value > 0)
          '$root/memoryUploadBytes/$day/$uid/${entry.key}': increment(
            entry.value,
          ),
      for (final entry in counts.entries)
        if (entry.value > 0)
          '$root/memoryStorageBytes/${entry.key}': increment(entry.value),
    });
    return true;
  }
}
