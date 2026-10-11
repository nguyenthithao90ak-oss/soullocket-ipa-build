import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'storage_upload_progress.dart';

/// Gửi tệp lên bucket R2 riêng tư theo phiên do server ký (`transport: 'r2'`).
///
/// Chỉ chấp nhận URL tới đúng bucket riêng tư, đúng thư mục
/// `houses/{houseId}/{folder}/{ownerUid}/{sessionId}.ext`, và bộ header trùng khít
/// bộ đã ký (MD5 của chính các byte gửi đi, chủ/nhà, cấm cache công khai).
abstract final class PrivateR2Put {
  static const account = 'cb19b30ef636ede2f9d6083c61cd67fa';
  static const bucket = 'soullocket-private';
  static const cacheControl = 'private, no-store, max-age=0';
  static final _scopeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _sessionId = RegExp(r'^[a-f0-9]{64}$');

  static http.Request buildRequest({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
    required String? houseId,
    required String? ownerUid,
    required String folder,
    required Set<String> extensions,
    required int maxBytes,
  }) {
    final uri = Uri.tryParse(session['uploadUrl']?.toString() ?? '');
    final sessionId = session['sessionId']?.toString() ?? '';
    final storagePath = session['storagePath']?.toString() ?? '';
    final rawHeaders = session['headers'];
    const endpoint = '$account.r2.cloudflarestorage.com';
    if (houseId == null ||
        ownerUid == null ||
        !_scopeId.hasMatch(houseId) ||
        !_scopeId.hasMatch(ownerUid) ||
        !_scopeId.hasMatch(folder) ||
        bytes.isEmpty ||
        bytes.length > maxBytes ||
        session['ok'] != true ||
        session['transport'] != 'r2' ||
        session['method'] != 'PUT' ||
        !_sessionId.hasMatch(sessionId) ||
        !_pathMatches(
          storagePath,
          prefix: 'houses/$houseId/$folder/$ownerUid/$sessionId.',
          extensions: extensions,
        ) ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        !((uri.host == endpoint && uri.path == '/$bucket/$storagePath') ||
            (uri.host == '$bucket.$endpoint' && uri.path == '/$storagePath')) ||
        rawHeaders is! Map) {
      throw const FormatException('Invalid private upload session');
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid private upload header');
      }
      final name = (entry.key as String).toLowerCase();
      if (headers.containsKey(name)) {
        throw const FormatException('Invalid private upload header');
      }
      headers[name] = entry.value as String;
    }
    final required = <String, String>{
      'content-type': contentType,
      'content-md5': base64Encode(md5.convert(bytes).bytes),
      'if-none-match': '*',
      'cache-control': cacheControl,
      'x-amz-meta-session-id': sessionId,
      'x-amz-meta-house-id': houseId,
      'x-amz-meta-owner-uid': ownerUid,
    };
    if (headers.length != required.length ||
        required.entries.any((entry) => headers[entry.key] != entry.value)) {
      throw const FormatException('Invalid private upload header');
    }
    return http.Request('PUT', uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
  }

  /// 412: lần PUT trước đã tới R2 nhưng app mất phản hồi; server kiểm tra lại
  /// kích thước/MD5/chủ sở hữu khi finalize nên không coi đây là lỗi.
  static Future<void> send(
    http.Client client,
    http.Request request, {
    StorageUploadProgressCallback? onProgress,
  }) async {
    try {
      if (onProgress == null) {
        final response = await client
            .send(request)
            .timeout(const Duration(minutes: 2));
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 20),
        );
        final ok = response.statusCode >= 200 && response.statusCode < 300;
        if (!ok && response.statusCode != 412) {
          throw StateError('Private upload failed (${response.statusCode})');
        }
        return;
      }

      final bytes = request.bodyBytes;
      final streamed = http.StreamedRequest('PUT', request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..headers.addAll(request.headers)
        ..contentLength = bytes.length;
      final responseFuture = client.send(streamed).then((response) async {
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 20),
        );
        return response;
      });
      final producer = StorageUploadProgress.pumpBytes(
        sink: streamed.sink,
        bytes: bytes,
        onProgress: onProgress,
      );
      final results = await Future.wait<Object?>([
        responseFuture,
        producer,
      ]).timeout(const Duration(minutes: 2));
      final response = results.first as http.StreamedResponse;
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok && response.statusCode != 412) {
        throw StateError('Private upload failed (${response.statusCode})');
      }
    } on TimeoutException {
      throw TimeoutException('Private upload timed out');
    } on http.ClientException {
      throw http.ClientException('Private upload failed');
    }
  }

  static bool _pathMatches(
    String path, {
    required String prefix,
    required Set<String> extensions,
  }) {
    if (!path.startsWith(prefix)) return false;
    final extension = path.substring(prefix.length);
    return extensions.contains(extension);
  }
}
