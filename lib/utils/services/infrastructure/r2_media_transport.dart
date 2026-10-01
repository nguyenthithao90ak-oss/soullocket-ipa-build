import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../storage/storage_upload_result.dart';
import 'r2_upload_policy.dart';

typedef R2UploadSessionCreator =
    Future<Map<String, dynamic>> Function({
      required String fileName,
      required String folder,
      required String contentType,
      required int fileSize,
    });

typedef R2UploadFinalizer =
    Future<Map<String, dynamic>> Function(String uploadId);

/// Gửi đúng tệp sau xử lý; Web dùng bytes, native dùng stream có giới hạn bộ nhớ.
class R2MediaTransport {
  const R2MediaTransport();

  Future<StorageUploadResult> upload({
    required XFile file,
    required String contentType,
    required String storagePath,
    required R2UploadSessionCreator createUploadSession,
    required R2UploadFinalizer finalizeUpload,
    required http.Client client,
    bool useBytes = kIsWeb,
    Future<void> Function(int bytes)? beforeUpload,
    ValueChanged<double>? onProgress,
  }) async {
    final bytes = await file.length();
    final maxBytes = R2UploadPolicy.maxUploadBytes(contentType);
    final folder = R2UploadPolicy.publicFolderForPath(storagePath);
    if (bytes <= 0 || bytes > maxBytes) {
      throw const FormatException('Invalid media upload size');
    }
    // Kiểm tra hạn mức trước cả bước tạo URL và PUT, không tạo object mồ côi.
    await beforeUpload?.call(bytes);
    final data = await createUploadSession(
      fileName: p.posix.basename(storagePath),
      folder: folder,
      contentType: contentType,
      fileSize: bytes,
    );
    final uploadId = data['uploadId']?.toString().trim() ?? '';
    final uploadUrl = data['url']?.toString().trim() ?? '';
    final serverPath = data['path']?.toString().trim() ?? '';
    if (uploadId.isEmpty || uploadUrl.isEmpty || serverPath.isEmpty) {
      throw StateError('Upload session response is incomplete');
    }
    final target = R2UploadPolicy.requireHttps(uploadUrl);
    final headers = R2UploadPolicy.signedUploadHeaders(
      uploadUri: target,
      contentType: contentType,
      fileSize: bytes,
      providedHeaders: data['requiredHeaders'],
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
    final finalized = await finalizeUpload(uploadId);
    final downloadUrl = finalized['publicUrl']?.toString().trim() ?? '';
    final finalizedPath = finalized['path']?.toString().trim() ?? '';
    if (finalized['success'] != true ||
        downloadUrl.isEmpty ||
        finalizedPath != serverPath) {
      throw StateError('Finalized upload response is incomplete');
    }
    R2UploadPolicy.requireHttps(downloadUrl);
    onProgress?.call(1);
    return StorageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: finalizedPath,
      uploadedBytes: bytes,
    );
  }
}
