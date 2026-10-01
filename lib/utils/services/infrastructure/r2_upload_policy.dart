/// Quy tắc MIME và nơi nhận upload; không phụ thuộc Firebase/Flutter để dễ kiểm thử.
abstract final class R2UploadPolicy {
  static int maxUploadBytes(String contentType) {
    if (const {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
    }.contains(contentType)) {
      return 15 * 1024 * 1024;
    }
    if (const {
      'audio/mpeg',
      'audio/mp4',
      'audio/aac',
      'audio/flac',
      'audio/ogg',
      'audio/wav',
    }.contains(contentType)) {
      return 25 * 1024 * 1024;
    }
    if (const {
      'video/mp4',
      'video/quicktime',
      'video/webm',
      'video/x-m4v',
      'video/3gpp',
    }.contains(contentType)) {
      return 50 * 1024 * 1024;
    }
    throw const FormatException('Unsupported media content type');
  }

  static String publicFolderForPath(String storagePath) {
    final segments = storagePath.replaceAll('\\', '/').split('/');
    if (segments.length < 2 ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw const FormatException('Invalid media path');
    }
    var folderIndex = 0;
    if (segments.first == 'uploads' || segments.first == 'users') {
      folderIndex = 2;
      if (segments.length > 2 && segments[2] == 'houses') {
        folderIndex = 4;
      }
    }
    if (folderIndex >= segments.length - 1) {
      throw const FormatException('Invalid media folder');
    }
    final folder = segments[folderIndex];
    if (folder == 'diary' &&
        segments.length > folderIndex + 2 &&
        segments[folderIndex + 1] == 'custom_stickers') {
      return 'images';
    }
    if (const {
      'avatars',
      'themes',
      'collage',
      'chat_backgrounds',
      'images',
      'public',
    }.contains(folder)) {
      return folder == 'avatars' ? 'avatars' : 'images';
    }
    if (folder == 'music') {
      return 'uploads';
    }
    throw const FormatException('Media requires a dedicated upload session');
  }

  static Map<String, String> signedUploadHeaders({
    required Uri uploadUri,
    required String contentType,
    required int fileSize,
    required Object? providedHeaders,
  }) {
    requireHttps(uploadUri.toString());
    if (!uploadUri.host.endsWith('.r2.cloudflarestorage.com') ||
        uploadUri.port != 443 ||
        uploadUri.queryParameters['X-Amz-Signature']?.isNotEmpty != true) {
      throw const FormatException('Untrusted upload destination');
    }
    if (providedHeaders is! Map) {
      throw const FormatException('Invalid upload headers');
    }
    final headers = <String, String>{};
    for (final entry in providedHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid upload header');
      }
      final name = (entry.key as String).toLowerCase();
      final value = entry.value as String;
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name + value) ||
          headers.containsKey(name)) {
        throw const FormatException('Invalid upload header');
      }
      if (name == 'content-length') {
        if (int.tryParse(value) != fileSize) {
          throw const FormatException('Upload size mismatch');
        }
        continue;
      }
      if (_storageHeaders.contains(name)) headers[name] = value;
    }
    if (headers['content-type'] != contentType) {
      throw const FormatException('Upload content type mismatch');
    }
    return headers;
  }

  static const _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'm4v': 'video/x-m4v',
    '3gp': 'video/3gpp',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'flac': 'audio/flac',
  };

  static String extensionForMimeType(String mime) {
    if (mime == 'application/octet-stream') return '.bin';
    for (final entry in _mimeTypes.entries) {
      if (entry.value == mime) return '.${entry.key}';
    }
    throw const FormatException('Unsupported media content type');
  }

  static String mimeTypeForPath(String filePath) {
    final fileName = filePath.replaceAll('\\', '/').split('/').last;
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return _mimeTypes[extension] ?? 'application/octet-stream';
  }

  static String imageExtension(String extension) {
    final normalized = extension.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    if (!const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(normalized)) {
      throw const FormatException('Unsupported image extension');
    }
    return normalized;
  }

  static Uri requireHttps(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      // Không đưa URL có chữ ký/token vào thông báo lỗi hoặc log.
      throw const FormatException('Invalid secure upload endpoint');
    }
    return uri;
  }

  static Map<String, String> uploadHeaders({
    required Uri workerUri,
    required Uri uploadUri,
    required String idToken,
    required String contentType,
    required Object? providedHeaders,
  }) {
    requireHttps(workerUri.toString());
    requireHttps(uploadUri.toString());
    final sameOrigin = workerUri.origin == uploadUri.origin;
    final isSignedR2 =
        uploadUri.host.endsWith('.r2.cloudflarestorage.com') &&
        uploadUri.port == 443 &&
        uploadUri.queryParameters['X-Amz-Signature']?.isNotEmpty == true;
    if (!sameOrigin && !isSignedR2) {
      throw const FormatException('Untrusted upload destination');
    }
    if (idToken.trim().isEmpty ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(idToken)) {
      throw const FormatException('Invalid upload authentication');
    }
    if (providedHeaders != null && providedHeaders is! Map) {
      throw const FormatException('Invalid upload headers');
    }

    final headers = <String, String>{};
    for (final entry in (providedHeaders as Map? ?? const {}).entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid upload header');
      }
      final name = (entry.key as String).toLowerCase();
      final value = entry.value as String;
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
        throw const FormatException('Invalid upload header');
      }
      // Chỉ chuyển header mô tả object/chữ ký S3. Không tin Authorization,
      // Cookie, App Check hay header xác thực do response cung cấp.
      if (!_storageHeaders.contains(name)) continue;
      if (headers.containsKey(name)) {
        throw const FormatException('Duplicate upload header');
      }
      headers[name] = value;
    }
    if (headers.containsKey('content-type') &&
        headers['content-type']!.toLowerCase() != contentType.toLowerCase()) {
      throw const FormatException('Upload content type mismatch');
    }
    headers['content-type'] = contentType;
    // R2 đã xác thực bằng chữ ký query; Firebase token chỉ dành cho Worker.
    if (sameOrigin) headers['authorization'] = 'Bearer $idToken';
    return headers;
  }

  static const _storageHeaders = {
    'content-type',
    'content-md5',
    'content-disposition',
    'cache-control',
    'x-amz-content-sha256',
    'x-amz-checksum-crc32',
    'x-amz-checksum-crc32c',
    'x-amz-checksum-sha1',
    'x-amz-checksum-sha256',
    'x-amz-security-token',
    'x-amz-date',
    'x-amz-meta-owneruid',
    'x-amz-meta-uploadid',
  };
}
