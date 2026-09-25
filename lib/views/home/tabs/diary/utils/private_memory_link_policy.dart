/// Link media đã ký là thông tin cấp quyền tạm thời, không phải dữ liệu offline.
abstract final class PrivateMemoryLinkPolicy {
  static const _urlKeys = {
    'url',
    'downloadUrl',
    'resolvedUrl',
    'previewUrl',
    'thumbUrl',
    'thumbnailUrl',
    'urlExpiresAt',
  };

  static bool isPrivate(Map<String, dynamic> item) =>
      item['privateMedia'] == true || item['storageAccess'] == 'signed' ||
      item['privateUploadVersion'] == 1 ||
      RegExp(r'^pm_[a-f0-9]{64}$').hasMatch(item['id']?.toString() ?? '');

  static bool isExpired(Map<String, dynamic> item, int nowMs) =>
      isPrivate(item) &&
      ((item['urlExpiresAt'] as num?)?.toInt() ?? 0) <= nowMs + 30000;

  static Map<String, dynamic> offlineMetadata(Map<String, dynamic> item) => {
    for (final entry in item.entries)
      if (!_urlKeys.contains(entry.key)) entry.key: entry.value,
  };

  static void normalizePrivate(Map<String, dynamic> item, int nowMs) {
    if (!isPrivate(item)) return;
    // Thumbnail/downloadUrl cũ không được thay thế URL đã được kiểm tra quyền.
    for (final key in _urlKeys) {
      if (key != 'url' && key != 'urlExpiresAt') item.remove(key);
    }
    if (isExpired(item, nowMs)) item.remove('url');
  }
}
