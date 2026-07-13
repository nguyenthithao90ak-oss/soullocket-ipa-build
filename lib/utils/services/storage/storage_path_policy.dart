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
    throw Exception('Đường dẫn upload không hợp lệ.');
  }

  if (normalized.startsWith('uploads/')) {
    return normalized;
  }

  final uid = currentUid.trim();
  if (uid.isEmpty) {
    throw Exception('Cần đăng nhập để tải tệp lên đám mây.');
  }

  return 'uploads/$uid/$normalized';
}
