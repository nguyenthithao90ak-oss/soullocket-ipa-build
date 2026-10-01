import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

abstract final class StorageSignedAudioUpload {
  static Future<void> put({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
    required http.Client client,
  }) async {
    final uri = Uri.tryParse(session['uploadUrl']?.toString() ?? '');
    final rawHeaders = session['headers'];
    if (bytes.isEmpty ||
        bytes.length > 6 * 1024 * 1024 ||
        session['ok'] != true ||
        session['method'] != 'PUT' ||
        (session['sessionId']?.toString().trim() ?? '').isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(uri.host == 'storage.googleapis.com' ||
            uri.host.endsWith('.storage.googleapis.com')) ||
        rawHeaders is! Map) {
      throw const FormatException('Invalid audio upload session');
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid audio upload header');
      }
      final name = (entry.key as String).toLowerCase();
      final value = entry.value as String;
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name + value) ||
          headers.containsKey(name)) {
        throw const FormatException('Invalid audio upload header');
      }
      if (name == 'content-type' || name.startsWith('x-goog-meta-')) {
        headers[name] = value;
      }
    }
    if (headers['content-type'] != contentType) {
      throw const FormatException('Audio upload content type mismatch');
    }
    final request = http.Request('PUT', uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 2));
      await response.stream.drain<void>().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Audio upload failed (${response.statusCode})');
      }
    } on TimeoutException {
      throw TimeoutException('Audio upload timed out');
    } on http.ClientException {
      throw http.ClientException('Audio upload failed');
    }
  }
}
