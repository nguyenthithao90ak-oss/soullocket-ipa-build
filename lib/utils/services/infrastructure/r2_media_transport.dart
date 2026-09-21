import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../storage/storage_upload_result.dart';
import 'r2_upload_policy.dart';

/// Gửi đúng tệp sau xử lý; Web dùng bytes, native dùng stream có giới hạn bộ nhớ.
class R2MediaTransport {
  const R2MediaTransport();

  Future<StorageUploadResult> upload({
    required XFile file,
    required String contentType,
    required String storagePath,
    required Uri workerUri,
    required String idToken,
    required http.Client client,
    bool useBytes = kIsWeb,
    Future<void> Function(int bytes)? beforeUpload,
    ValueChanged<double>? onProgress,
  }) async {
    final bytes = await file.length();
    if (bytes <= 0 ||
        bytes > (contentType.startsWith('video/') ? 50 : 25) * 1024 * 1024) {
      throw const FormatException('Invalid media upload size');
    }
    // Kiểm tra hạn mức trước cả bước tạo URL và PUT, không tạo object mồ côi.
    await beforeUpload?.call(bytes);
    final endpoint = R2UploadPolicy.requireHttps(workerUri.toString());
    final request = http.Request('POST', endpoint)
      ..followRedirects = false
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      })
      ..body = jsonEncode({
        'fileName': p.posix.basename(storagePath),
        'contentType': contentType,
        'folderPath': p.posix.dirname(storagePath),
        'fileSize': bytes,
        'exactPath': storagePath,
      });
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Upload session rejected (${response.statusCode})');
    }
    final data = jsonDecode(response.body)['result'] as Map;
    final target = R2UploadPolicy.requireHttps(data['uploadUrl'] as String);
    final downloadUrl = data['publicUrl'] as String;
    R2UploadPolicy.requireHttps(downloadUrl);
    final headers = R2UploadPolicy.uploadHeaders(
      workerUri: endpoint,
      uploadUri: target,
      idToken: idToken,
      contentType: contentType,
      providedHeaders: data['headers'],
    );
    onProgress?.call(0);
    Future<http.Response> send() async {
      if (useBytes) {
        final body = await file.readAsBytes();
        if (body.length != bytes) throw StateError('Upload file changed');
        final put = http.Request('PUT', target)
          ..followRedirects = false
          ..headers.addAll(headers)
          ..bodyBytes = body;
        return client.send(put).then(http.Response.fromStream);
      }
      final put = http.StreamedRequest('PUT', target)
        ..followRedirects = false
        ..headers.addAll(headers)
        ..contentLength = bytes;
      // Bắt đầu đọc response trước khi bơm stream để không chờ buffer vô hạn.
      final response = client.send(put).then(http.Response.fromStream);
      final producer = () async {
        try {
          await put.sink.addStream(file.openRead());
        } finally {
          await put.sink.close();
        }
      }();
      final results = await Future.wait<Object?>([response, producer]);
      return results.first as http.Response;
    }

    final uploaded = await send().timeout(const Duration(minutes: 5));
    if (uploaded.statusCode != 200 && uploaded.statusCode != 201) {
      throw StateError('Upload failed (${uploaded.statusCode})');
    }
    onProgress?.call(1);
    return StorageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      uploadedBytes: bytes,
    );
  }
}
