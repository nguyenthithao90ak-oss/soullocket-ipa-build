import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:http/http.dart' as http;

typedef PrivateMemoryInvoke =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> payload,
    );

class PrivateMemoryUploadReceipt {
  const PrivateMemoryUploadReceipt({
    required this.memoryId,
    required this.sessionId,
    required this.alreadyFinalized,
  });

  final String memoryId;
  final String sessionId;
  final bool alreadyFinalized;
}

/// Transport riêng tư, được StorageService cấp Auth/App Check và HTTP client.
/// Caller phải lưu requestId trước khi gọi; không lưu URL ký vào journal.
class StoragePrivateMemoryUploadHelper {
  const StoragePrivateMemoryUploadHelper();

  static const _account = 'cb19b30ef636ede2f9d6083c61cd67fa';
  static const _bucket = 'soullocket-private';

  Never _fail(String code) =>
      throw FirebaseFunctionsException(code: code, message: '');

  Future<PrivateMemoryUploadReceipt> upload({
    required String uid,
    required String houseId,
    required String requestId,
    required String authorName,
    required String? Function() currentUid,
    required Stream<String?> authChanges,
    required bool Function() scopeIsCurrent,
    required PrivateMemoryInvoke invoke,
    required Future<({XFile file, String contentType})> Function() prepareFile,
    required http.Client client,
    Future<void> Function(int bytes, bool isVideo)? beforeUpload,
    double? latitude,
    double? longitude,
    DateTime Function()? now,
  }) async {
    final clock = now ?? DateTime.now;
    final validId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (!validId.hasMatch(uid) ||
        !validId.hasMatch(houseId) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId)) {
      _fail('invalid-argument');
    }
    var changed = false;
    final subscription = authChanges.listen(
      (next) {
        if (next != uid) changed = true;
      },
      onError: (Object _) {
        changed = true;
      },
    );
    void guard() {
      if (changed || currentUid() != uid) _fail('unauthenticated');
      if (!scopeIsCurrent()) _fail('cancelled');
    }

    final sessionId = sha256
        .convert(utf8.encode('$uid:$houseId:$requestId'))
        .toString();
    final expectedMediaId = 'pm_$sessionId';
    final scope = <String, dynamic>{'houseId': houseId, 'requestId': requestId};
    final finalizePayload = <String, dynamic>{
      ...scope,
      'authorName': authorName,
      if (latitude != null && longitude != null) 'lat': latitude,
      if (latitude != null && longitude != null) 'lng': longitude,
    };
    PrivateMemoryUploadReceipt receipt(Map<String, dynamic> data) {
      if (data['ok'] != true ||
          data['sessionId'] != sessionId ||
          data['memoryId'] != expectedMediaId ||
          data['alreadyFinalized'] is! bool) {
        _fail('unavailable');
      }
      return PrivateMemoryUploadReceipt(
        memoryId: expectedMediaId,
        sessionId: sessionId,
        alreadyFinalized: data['alreadyFinalized'] as bool,
      );
    }

    try {
      guard();
      // Hồi phục ACK bị mất trước khi đọc/nén lại file; file cục bộ có thể đã mất.
      final status = await invoke('getPrivateMemoryUploadStatus', scope);
      guard();
      if (status['ok'] != true || status['sessionId'] != sessionId) {
        _fail('unavailable');
      }
      if (status['status'] == 'finalized') return receipt(status);
      if (status['status'] == 'expired') _fail('deadline-exceeded');
      if (!const {'missing', 'pending'}.contains(status['status'])) {
        _fail('unavailable');
      }
      if (status['status'] == 'pending') {
        try {
          // PUT có thể đã tới R2 dù app chưa nhận ACK. Server kiểm tra file
          // trước; nếu đủ chứng cứ thì không cần file cục bộ hoặc PUT lần hai.
          final recovered = await invoke(
            'finalizePrivateMemoryUpload',
            finalizePayload,
          );
          guard();
          return receipt(recovered);
        } on FirebaseFunctionsException catch (error) {
          guard();
          if (error.code != 'failed-precondition') rethrow;
        }
      }

      final prepared = await prepareFile();
      guard();
      final size = await prepared.file.length();
      if (size <= 0 || size > 100 * 1024 * 1024) _fail('invalid-argument');
      final digest = await md5.bind(prepared.file.openRead()).first;
      guard();
      await beforeUpload?.call(size, prepared.contentType.startsWith('video/'));
      guard();
      final created = await invoke('createPrivateMemoryUpload', {
        ...scope,
        'contentType': prepared.contentType,
        'size': size,
        'md5': digest.toString(),
      });
      guard();
      final uri = Uri.tryParse(created['uploadUrl']?.toString() ?? '');
      const endpoint = '$_account.r2.cloudflarestorage.com';
      final path = created['storagePath']?.toString() ?? '';
      final expiresAt = (created['uploadExpiresAt'] as num?)?.toInt() ?? 0;
      final rawHeaders = created['headers'];
      if (created['ok'] != true ||
          created['method'] != 'PUT' ||
          created['sessionId'] != sessionId ||
          created['mediaId'] != expectedMediaId ||
          !RegExp(
            '^houses/$houseId/memories/$uid/$sessionId'
            r'\.[a-z0-9]+$',
          ).hasMatch(path) ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.fragment.isNotEmpty ||
          (uri.hasPort && uri.port != 443) ||
          !((uri.host == endpoint && uri.path == '/$_bucket/$path') ||
              (uri.host == '$_bucket.$endpoint' && uri.path == '/$path')) ||
          expiresAt <= clock().millisecondsSinceEpoch ||
          rawHeaders is! Map) {
        _fail('unavailable');
      }
      final headers = <String, String>{};
      for (final entry in rawHeaders.entries) {
        if (entry.key is! String || entry.value is! String) {
          _fail('unavailable');
        }
        final key = (entry.key as String).toLowerCase();
        if (headers.containsKey(key)) _fail('unavailable');
        headers[key] = entry.value as String;
      }
      final requiredHeaders = {
        'content-type': prepared.contentType,
        'content-md5': base64Encode(digest.bytes),
        'if-none-match': '*',
        'cache-control': 'private, no-store, max-age=0',
        'x-amz-meta-session-id': sessionId,
        'x-amz-meta-house-id': houseId,
        'x-amz-meta-owner-uid': uid,
      };
      if (headers.length != requiredHeaders.length ||
          requiredHeaders.entries.any(
            (entry) => headers[entry.key] != entry.value,
          )) {
        _fail('unavailable');
      }
      guard();
      // Stream trên Android; không đọc nguyên video 100 MB vào RAM.
      final request = _PrivateMemoryPut(uri, prepared.file, size, headers);
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 3));
      await response.stream.drain<void>().timeout(const Duration(seconds: 20));
      guard();
      // 412: lần PUT trước đã tới R2 nhưng app mất ACK; server HEAD sẽ xác minh
      // checksum/metadata, không ghi đè object và không tin status HTTP đơn thuần.
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          response.statusCode != 412) {
        _fail('unavailable');
      }
      final finished = await invoke(
        'finalizePrivateMemoryUpload',
        finalizePayload,
      );
      guard();
      return receipt(finished);
    } on FirebaseFunctionsException catch (error) {
      _fail(error.code);
    } catch (_) {
      _fail('unavailable');
    } finally {
      await subscription.cancel();
    }
  }
}

class _PrivateMemoryPut extends http.BaseRequest {
  _PrivateMemoryPut(Uri url, this.file, int size, Map<String, String> values)
    : super('PUT', url) {
    contentLength = size;
    headers.addAll(values);
    followRedirects = false;
  }
  final XFile file;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(file.openRead());
  }
}
