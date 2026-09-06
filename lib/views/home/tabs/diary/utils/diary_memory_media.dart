// Tiện ích dùng chung cho dữ liệu media của mục Nhật ký.
//
// Firebase cũ có thể lưu mỗi bản ghi với tên trường khác nhau. Các hàm ở đây
// đọc được cả dữ liệu mới lẫn dữ liệu cũ, đồng thời không nhầm URL video đã ký
// (có query string) với ảnh tĩnh.

const Set<String> diaryMemoryVideoExtensions = <String>{
  '.mp4',
  '.mov',
  '.webm',
  '.m4v',
  '.3gp',
  '.mkv',
  '.avi',
};

const List<String> _sourceUrlKeys = <String>[
  'url',
  'videoUrl',
  'video_url',
  'mediaUrl',
  'media_url',
  'downloadUrl',
  'download_url',
  'fileUrl',
  'file_url',
  'contentUrl',
  'content_url',
];

const List<String> _videoTypeKeys = <String>[
  'type',
  'mediaType',
  'media_type',
  'fileType',
  'file_type',
  'mimeType',
  'mime_type',
  'contentType',
  'content_type',
  'format',
  'kind',
];

const List<String> _videoFlagKeys = <String>['isVideo', 'is_video'];

const List<String> _extensionKeys = <String>[
  'extension',
  'fileExtension',
  'file_extension',
];

const List<String> _thumbnailUrlKeys = <String>[
  'thumbnailUrl',
  'thumbnail_url',
  'videoThumbnailUrl',
  'video_thumbnail_url',
  'previewUrl',
  'preview_url',
  'posterUrl',
  'poster_url',
  'coverUrl',
  'cover_url',
  'thumbUrl',
  'thumb_url',
];

/// Trả về URL media chính của bản ghi, nếu có.
String? resolveDiaryMemoryMediaUrl(final Map<Object?, Object?> memory) {
  return _firstNonEmptyString(memory, _sourceUrlKeys);
}

/// Nhận diện URL video, kể cả URL R2/Firebase có query string hoặc fragment.
bool isDiaryMemoryVideoUrl(final String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return false;
  }

  final path = _pathWithoutQueryOrFragment(rawUrl);
  return diaryMemoryVideoExtensions.any(path.endsWith);
}

/// Xác định một bản ghi nhật ký có phải video hay không.
///
/// Ưu tiên các cờ/mime type đã lưu, sau đó kiểm tra phần mở rộng của URL để hỗ
/// trợ các bản ghi cũ không có trường [type].
bool isDiaryMemoryVideo(final Map<Object?, Object?> memory) {
  for (final key in _videoFlagKeys) {
    if (_isTruthy(_valueForKey(memory, key))) {
      return true;
    }
  }

  for (final key in _videoTypeKeys) {
    final value = _asNonEmptyString(_valueForKey(memory, key));
    if (value != null && _isVideoMetadata(value)) {
      return true;
    }
  }

  for (final key in _extensionKeys) {
    final value = _asNonEmptyString(_valueForKey(memory, key));
    if (value != null && _isVideoExtension(value)) {
      return true;
    }
  }

  return isDiaryMemoryVideoUrl(resolveDiaryMemoryMediaUrl(memory));
}

/// Trả về URL ảnh xem trước hợp lệ của video.
///
/// URL video chính hoặc một URL video khác không được coi là thumbnail, để UI
/// không cố giải mã video bằng [ImageProvider].
String? resolveDiaryMemoryVideoThumbnailUrl(
  final Map<Object?, Object?> memory,
) {
  final sourceUrl = resolveDiaryMemoryMediaUrl(memory)?.trim();

  for (final key in _thumbnailUrlKeys) {
    final candidate = _asNonEmptyString(_valueForKey(memory, key));
    if (candidate == null) {
      continue;
    }

    final normalizedCandidate = candidate.trim();
    if (normalizedCandidate == sourceUrl ||
        isDiaryMemoryVideoUrl(normalizedCandidate)) {
      continue;
    }

    return normalizedCandidate;
  }

  return null;
}

String _pathWithoutQueryOrFragment(final String rawUrl) {
  final trimmedUrl = rawUrl.trim();
  final uri = Uri.tryParse(trimmedUrl);
  final path = uri?.path;
  if (path != null && path.isNotEmpty) {
    return path.toLowerCase();
  }

  final separatorIndex = trimmedUrl.indexOf(RegExp(r'[?#]'));
  final rawPath = separatorIndex == -1
      ? trimmedUrl
      : trimmedUrl.substring(0, separatorIndex);
  return rawPath.toLowerCase();
}

bool _isVideoMetadata(final String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'video' ||
      normalized == 'video/*' ||
      normalized.startsWith('video/') ||
      normalized == 'memory_video' ||
      normalized == 'memory-video' ||
      normalized == 'video_message' ||
      normalized == 'video-message';
}

bool _isVideoExtension(final String rawExtension) {
  final extension = rawExtension.trim().toLowerCase();
  final normalizedExtension = extension.startsWith('.')
      ? extension
      : '.$extension';
  return diaryMemoryVideoExtensions.contains(normalizedExtension);
}

bool _isTruthy(final Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  return false;
}

String? _firstNonEmptyString(
  final Map<Object?, Object?> memory,
  final Iterable<String> keys,
) {
  for (final key in keys) {
    final value = _asNonEmptyString(_valueForKey(memory, key));
    if (value != null) {
      return value;
    }
  }
  return null;
}

Object? _valueForKey(final Map<Object?, Object?> memory, final String key) {
  final directValue = memory[key];
  if (directValue != null) {
    return directValue;
  }

  final normalizedKey = key.toLowerCase();
  for (final entry in memory.entries) {
    final entryKey = entry.key;
    if (entryKey is String && entryKey.toLowerCase() == normalizedKey) {
      return entry.value;
    }
  }

  return null;
}

String? _asNonEmptyString(final Object? value) {
  if (value == null) {
    return null;
  }

  final stringValue = value is String ? value : value.toString();
  return stringValue.trim().isEmpty ? null : stringValue.trim();
}
