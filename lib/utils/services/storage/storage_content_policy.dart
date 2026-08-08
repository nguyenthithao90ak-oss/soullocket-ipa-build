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
  // Cloudflare R2 hỗ trợ upload video
}
