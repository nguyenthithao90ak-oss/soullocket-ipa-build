import 'package:image_picker/image_picker.dart' show XFile;

import 'storage_content_policy.dart';
import 'storage_media_constants.dart';

class StorageImageUploadInput {
  const StorageImageUploadInput(this.fileName, this.contentType);

  final String fileName;
  final String contentType;

  factory StorageImageUploadInput.fromFile(XFile file) {
    final sourceName = file.name.isNotEmpty ? file.name : file.path;
    final mimeType = file.mimeType?.trim().toLowerCase();
    final fallback = storageContentTypesByExtension.values.contains(mimeType)
        ? mimeType!
        : 'image/jpeg';
    final contentType = detectStorageContentType(
      sourceName,
      fallback: fallback,
    );
    final extension = storageContentTypesByExtension.entries
        .where((entry) => entry.value == contentType)
        .first
        .key;
    return StorageImageUploadInput(
      sourceName.isEmpty ? 'image$extension' : sourceName,
      contentType,
    );
  }
}
