/// Header PUT GCS đã được server ký; không chuyển tiếp thông tin xác thực.
abstract final class FirebaseSignedPutHeaders {
  static Map<String, String> parse({
    required Object? rawHeaders,
    required String contentType,
    required int fileSize,
    required Uri uploadUri,
  }) {
    if (rawHeaders is! Map || fileSize <= 0) {
      throw const FormatException('Invalid upload headers');
    }
    final seen = <String>{};
    final headers = <String, String>{};
    var fixedLength = false;
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid upload header');
      }
      final name = (entry.key as String).toLowerCase();
      final value = entry.value as String;
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name + value) ||
          !seen.add(name)) {
        throw const FormatException('Invalid upload header');
      }
      if (name == 'content-length') {
        if (value != '$fileSize') {
          throw const FormatException('Upload size mismatch');
        }
        // http tự tính Content-Length; browser không cho đặt header này.
        fixedLength = true;
      } else if (name == 'x-goog-if-generation-match') {
        if (value != '0') {
          throw const FormatException('Invalid upload condition');
        }
        headers[name] = value;
      } else if (name == 'x-goog-content-length-range') {
        if (value != '$fileSize,$fileSize') {
          throw const FormatException('Upload size range mismatch');
        }
        headers[name] = value;
      } else if (name == 'content-type' || name.startsWith('x-goog-meta-')) {
        headers[name] = value;
      }
    }
    if (headers['content-type'] != contentType) {
      throw const FormatException('Upload content type mismatch');
    }
    final conditional = headers.containsKey('x-goog-if-generation-match');
    final bounded = headers.containsKey('x-goog-content-length-range');
    final signed = (uploadUri.queryParameters['X-Goog-SignedHeaders'] ?? '')
        .split(';')
        .toSet();
    if (conditional ||
        bounded ||
        signed.contains('x-goog-if-generation-match') ||
        signed.contains('x-goog-content-length-range')) {
      if (!conditional ||
          !bounded ||
          !fixedLength ||
          !signed.containsAll({
            'content-length',
            'x-goog-if-generation-match',
            'x-goog-content-length-range',
          })) {
        throw const FormatException('Incomplete signed upload conditions');
      }
    }
    return headers;
  }
}
