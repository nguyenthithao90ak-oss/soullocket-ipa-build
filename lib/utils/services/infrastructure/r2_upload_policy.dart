/// Quy tắc MIME và nơi nhận upload; không phụ thuộc Firebase/Flutter để dễ kiểm thử.
abstract final class R2UploadPolicy {
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
  };

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
    if (!(_mimeTypes[normalized]?.startsWith('image/') ?? false)) {
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
