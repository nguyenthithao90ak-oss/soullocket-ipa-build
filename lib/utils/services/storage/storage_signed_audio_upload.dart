import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

abstract final class StorageSignedAudioUpload {
  static const _r2Account = 'cb19b30ef636ede2f9d6083c61cd67fa';
  static const _r2Bucket = 'soullocket-private';
  static const _r2CacheControl = 'private, no-store, max-age=0';

  /// Phiên `transport: 'r2'` (server mới) ghi vào bucket R2 riêng tư; phiên còn lại
  /// là Firebase Storage kiểu cũ. [houseId]/[ownerUid] bắt buộc với R2 để kiểm tra
  /// URL ký đúng thư mục của chính người dùng trong nhà hiện tại.
  static Future<void> put({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
    required http.Client client,
    String? houseId,
    String? ownerUid,
  }) async {
    if (session['transport'] == 'r2') {
      return _putR2(
        session: session,
        bytes: bytes,
        contentType: contentType,
        client: client,
        houseId: houseId,
        ownerUid: ownerUid,
      );
    }
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
    await _send(client, request, allowAlreadyUploaded: false);
  }

  static Future<void> _putR2({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
    required http.Client client,
    required String? houseId,
    required String? ownerUid,
  }) async {
    final uri = Uri.tryParse(session['uploadUrl']?.toString() ?? '');
    final sessionId = session['sessionId']?.toString() ?? '';
    final storagePath = session['storagePath']?.toString() ?? '';
    final rawHeaders = session['headers'];
    const endpoint = '$_r2Account.r2.cloudflarestorage.com';
    final validScope =
        houseId != null &&
        ownerUid != null &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(houseId) &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(ownerUid);
    if (bytes.isEmpty ||
        bytes.length > 6 * 1024 * 1024 ||
        session['ok'] != true ||
        session['method'] != 'PUT' ||
        !validScope ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sessionId) ||
        !RegExp(
          '^houses/$houseId/voices/$ownerUid/$sessionId'
          r'\.(m4a|mp3|aac|ogg|wav)$',
        ).hasMatch(storagePath) ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        !((uri.host == endpoint && uri.path == '/$_r2Bucket/$storagePath') ||
            (uri.host == '$_r2Bucket.$endpoint' &&
                uri.path == '/$storagePath')) ||
        rawHeaders is! Map) {
      throw const FormatException('Invalid audio upload session');
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid audio upload header');
      }
      final name = (entry.key as String).toLowerCase();
      if (headers.containsKey(name)) {
        throw const FormatException('Invalid audio upload header');
      }
      headers[name] = entry.value as String;
    }
    // Header phải trùng khít bộ đã ký: đúng file (MD5), đúng chủ/nhà, cấm cache công khai.
    final required = <String, String>{
      'content-type': contentType,
      'content-md5': base64Encode(md5.convert(bytes).bytes),
      'if-none-match': '*',
      'cache-control': _r2CacheControl,
      'x-amz-meta-session-id': sessionId,
      'x-amz-meta-house-id': houseId!,
      'x-amz-meta-owner-uid': ownerUid!,
    };
    if (headers.length != required.length ||
        required.entries.any((entry) => headers[entry.key] != entry.value)) {
      throw const FormatException('Invalid audio upload header');
    }
    final request = http.Request('PUT', uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    // 412: lần PUT trước đã tới R2 nhưng app mất phản hồi; server sẽ kiểm tra lại
    // kích thước/MD5/chủ sở hữu khi finalize nên không coi đây là lỗi.
    await _send(client, request, allowAlreadyUploaded: true);
  }

  static Future<void> _send(
    http.Client client,
    http.Request request, {
    required bool allowAlreadyUploaded,
  }) async {
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 2));
      await response.stream.drain<void>().timeout(const Duration(seconds: 20));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok && !(allowAlreadyUploaded && response.statusCode == 412)) {
        throw StateError('Audio upload failed (${response.statusCode})');
      }
    } on TimeoutException {
      throw TimeoutException('Audio upload timed out');
    } on http.ClientException {
      throw http.ClientException('Audio upload failed');
    }
  }
}
