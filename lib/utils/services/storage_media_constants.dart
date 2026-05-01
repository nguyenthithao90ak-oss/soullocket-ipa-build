const Map<String, String> storageContentTypesByExtension = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.bmp': 'image/bmp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
  '.svg': 'image/svg+xml',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.webm': 'video/webm',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
};

const String storageImmutableCacheControl = 'public,max-age=31536000,immutable';

const Set<String> storageBlockedVideoExtensions = {
  '.mp4',
  '.mov',
  '.webm',
  '.m4v',
  '.avi',
  '.mkv',
};

const List<String> storageMusicPickerExtensions = <String>[
  'mp3',
  'm4a',
  'aac',
  'wav',
  'ogg',
  'flac',
  'mp4',
];

const int storageMaxMusicUploadBytes = 10 * 1024 * 1024;
