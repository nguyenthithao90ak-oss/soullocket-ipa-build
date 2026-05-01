import 'package:path/path.dart' as p;

import 'storage_media_constants.dart';

String detectStorageContentType(
  String fileNameOrPath, {
  String fallback = 'application/octet-stream',
}) {
  final extension = p.extension(fileNameOrPath).toLowerCase();
  return storageContentTypesByExtension[extension] ?? fallback;
}

bool looksLikeBlockedStorageVideoFile(String fileNameOrPath) {
  final extension = p.extension(fileNameOrPath).toLowerCase();
  return storageBlockedVideoExtensions.contains(extension);
}

void rejectUnsupportedStorageVideoUpload({
  required String storagePath,
  required String resolvedContentType,
  String? originalFileName,
}) {
  final normalizedContentType = resolvedContentType.trim().toLowerCase();
  final sourceName = (originalFileName ?? '').trim();
  if (normalizedContentType.startsWith('video/') ||
      looksLikeBlockedStorageVideoFile(storagePath) ||
      (sourceName.isNotEmpty && looksLikeBlockedStorageVideoFile(sourceName))) {
    throw Exception('Ứng dụng hiện không hỗ trợ tải video lên.');
  }
}
