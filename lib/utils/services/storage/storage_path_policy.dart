import 'package:soullocket_app/utils/ui_copy.dart';
String normalizeStorageRefPath(String storagePath) {
  return storagePath
      .trim()
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '');
}

String normalizeStorageWritePath({
  required String storagePath,
  required String currentUid,
}) {
  final normalized = normalizeStorageRefPath(storagePath);
  if (normalized.isEmpty) {
    throw UiCopyException('copy_4b4db5cfdc9e');
  }

  if (normalized.startsWith('uploads/')) {
    return normalized;
  }

  final uid = currentUid.trim();
  if (uid.isEmpty) {
    throw UiCopyException('copy_0d17dba25af1');
  }

  return 'uploads/$uid/$normalized';
}
