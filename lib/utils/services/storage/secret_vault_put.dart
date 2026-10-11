import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'private_r2_put.dart';

abstract final class SecretVaultPut {
  static http.Request buildRequest({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String uid,
    required String houseId,
    required String contentType,
  }) {
    final uri = Uri.tryParse(session['url']?.toString() ?? '');
    final uploadId = session['uploadId']?.toString() ?? '';
    final path = session['path']?.toString() ?? '';
    final extension = <String, String>{
      'image/jpeg': 'jpg', 'image/png': 'png',
      'image/webp': 'webp', 'image/gif': 'gif',
    }[contentType];
    const endpoint = '${PrivateR2Put.account}.r2.cloudflarestorage.com';
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(uploadId) ||
        extension == null || bytes.isEmpty || bytes.length > 15 * 1024 * 1024 ||
        path != 'users/$uid/secret_vault/$houseId/$uploadId.$extension' ||
        uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.hasFragment || uri.port != 443 ||
        !((uri.host == endpoint && uri.path == '/${PrivateR2Put.bucket}/$path') ||
          (uri.host == '${PrivateR2Put.bucket}.$endpoint' && uri.path == '/$path'))) {
      throw const FormatException('Invalid Secret Vault upload session');
    }
    final rawHeaders = session['requiredHeaders'];
    if (rawHeaders is! Map) throw const FormatException('Missing upload headers');
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid upload header');
      }
      final name = (entry.key as String).toLowerCase();
      if (headers.containsKey(name)) throw const FormatException('Duplicate upload header');
      headers[name] = entry.value as String;
    }
    final expected = <String, String>{
      'content-type': contentType, 'content-length': '${bytes.length}',
      'content-md5': base64Encode(md5.convert(bytes).bytes),
      'x-amz-meta-owneruid': uid, 'x-amz-meta-uploadid': uploadId,
      'if-none-match': '*', 'cache-control': PrivateR2Put.cacheControl,
    };
    if (headers.length != expected.length ||
        expected.entries.any((entry) => headers[entry.key] != entry.value)) {
      throw const FormatException('Signed upload headers do not match');
    }
    return http.Request('PUT', uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
  }
}
