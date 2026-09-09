import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_compress/video_compress.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/infrastructure/r2_upload_policy.dart';

class CloudflareR2Service {
  static final CloudflareR2Service instance = CloudflareR2Service._internal();
  factory CloudflareR2Service() => instance;
  CloudflareR2Service._internal();

  static const String publicDomain = String.fromEnvironment('R2_PUBLIC_DOMAIN');

  // Luôn trả về true vì cấu hình khóa R2 hiện tại nằm ở Server (Cloud Functions)
  bool get isConfigured => true;

  void init() {
    // Không cần khởi tạo Minio client ở phía App
  }

  /// URL sinh ra từ R2 có thể đã bị gán vào weserv.nl (dành cho ảnh).
  /// Video_player sẽ lỗi nếu đi qua proxy ảnh. Hàm này bóc URL gốc ra để play.
  static String resolveVideoUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;
    if (rawUrl.contains('images.weserv.nl/?url=')) {
      final unproxied = rawUrl.split('images.weserv.nl/?url=').last;
      if (!unproxied.startsWith('http')) {
        return 'https://$unproxied';
      }
      return unproxied;
    }
    return rawUrl;
  }

  Future<http.Response> _sendBytes(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bytes,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    R2UploadPolicy.requireHttps(uri.toString());
    // Không theo redirect: tránh chuyển token hoặc nội dung riêng tư sang host khác.
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    final client = http.Client();
    try {
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } finally {
      client.close();
    }
  }

  /// Uploads base64 image data to Cloudflare R2
  Future<String?> uploadBase64(
    String base64Data, {
    required String folderPath,
    String extension = 'jpg',
  }) async {
    try {
      final imageExtension = R2UploadPolicy.imageExtension(extension);
      final fileName = 'image.$imageExtension';
      final contentType = R2UploadPolicy.mimeTypeForPath(fileName);
      String cleanBase64 = base64Data;
      if (base64Data.contains(',')) {
        cleanBase64 = base64Data.split(',').last;
      }

      final bytes = base64Decode(cleanBase64);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final url = R2UploadPolicy.requireHttps(
        '${AppConfig.cloudflareWorkerUrl}/api/getSignedUploadUrl',
      );
      final response = await _sendBytes(
        'POST',
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        bytes: utf8.encode(
          jsonEncode({
            'fileName': fileName,
            'contentType': contentType,
            'folderPath': folderPath,
            'fileSize': bytes.length,
          }),
        ),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[CloudflareR2] Worker returned error: ${response.statusCode}',
        );
        return null;
      }

      final resData = jsonDecode(response.body)['result'] as Map;
      final uploadUri = R2UploadPolicy.requireHttps(
        resData['uploadUrl'] as String,
      );
      final publicUrl = resData['publicUrl'] as String;
      final headers = R2UploadPolicy.uploadHeaders(
        workerUri: url,
        uploadUri: uploadUri,
        idToken: idToken,
        contentType: contentType,
        providedHeaders: resData['headers'],
      );

      // Tiến hành upload nhị phân trực tiếp bằng HTTP PUT qua proxy Worker hoặc R2
      final putResponse = await _sendBytes(
        'PUT',
        uploadUri,
        headers: headers,
        bytes: bytes,
      );

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        return publicUrl;
      } else {
        debugPrint('[CloudflareR2] PUT failed: ${putResponse.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudflareR2] Upload Base64 failed: ${e.runtimeType}');
      return null;
    }
  }

  /// Upload File lên R2 và trả về public link
  Future<String?> uploadFile(
    File file, {
    required String folderPath,
    String? storagePathOverride,
  }) async {
    try {
      String fileName = path.basename(file.path);
      final isVideo = R2UploadPolicy.mimeTypeForPath(
        file.path,
      ).startsWith('video/');

      File finalFile = file;

      if (isVideo) {
        if (!AppConfig.isVideoUploadEnabled) {
          debugPrint(
            '[CloudflareR2] TẠM THỜI TẮT UPLOAD VIDEO ĐỂ SỬA CHỮA / BẢO TRÌ (AppConfig.isVideoUploadEnabled = false). '
            'Để bật lại tính năng này, đổi isVideoUploadEnabled = true trong lib/core/constants/app_config.dart',
          );
          return null;
        }
        final isVip = await PurchaseService().isVip();
        if (!isVip) {
          debugPrint(
            '[CloudflareR2] Non-VIP user: Compressing video to 720p...',
          );
          try {
            final mediaInfo = await VideoCompress.compressVideo(
              file.path,
              quality: VideoQuality.Res1280x720Quality,
              deleteOrigin: false,
            );
            if (mediaInfo != null && mediaInfo.file != null) {
              finalFile = mediaInfo.file!;
              fileName = path.basename(finalFile.path);
              debugPrint('[CloudflareR2] Video compressed successfully.');
            }
          } catch (compressError) {
            debugPrint(
              '[CloudflareR2] Video compress failed: $compressError, falling back to original',
            );
          }
        } else {
          debugPrint('[CloudflareR2] VIP user: Uploading original video...');
        }
      }

      // VideoCompress có thể đổi MOV sang MP4; ký MIME của file thực sự được gửi.
      final contentType = R2UploadPolicy.mimeTypeForPath(finalFile.path);
      final fileSize = await finalFile.length();
      debugPrint(
        '[CloudflareR2] Upload file: $fileName, size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB, type: $contentType',
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[CloudflareR2] Upload failed: user not authenticated');
        return null;
      }
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final url = R2UploadPolicy.requireHttps(
        '${AppConfig.cloudflareWorkerUrl}/api/getSignedUploadUrl',
      );
      final response = await _sendBytes(
        'POST',
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        bytes: utf8.encode(
          jsonEncode({
            'fileName': fileName,
            'contentType': contentType,
            'folderPath': folderPath,
            'fileSize': fileSize,
            'exactPath': storagePathOverride,
          }),
        ),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[CloudflareR2] Worker returned error (${response.statusCode})',
        );
        return null;
      }

      final resData = jsonDecode(response.body)['result'] as Map;
      final uploadUri = R2UploadPolicy.requireHttps(
        resData['uploadUrl'] as String,
      );
      final publicUrl = resData['publicUrl'] as String;
      final headers = R2UploadPolicy.uploadHeaders(
        workerUri: url,
        uploadUri: uploadUri,
        idToken: idToken,
        contentType: contentType,
        providedHeaders: resData['headers'],
      );

      // Video lớn: dùng streamed request để không load hết vào RAM
      if (isVideo && fileSize > 5 * 1024 * 1024) {
        debugPrint(
          '[CloudflareR2] Using streamed upload for video ($fileName)...',
        );
        final streamedRequest = http.StreamedRequest('PUT', uploadUri)
          ..followRedirects = false;
        streamedRequest.headers.addAll(headers);
        streamedRequest.contentLength = fileSize;

        // Stream file trực tiếp không qua readAsBytes
        finalFile.openRead().listen(
          streamedRequest.sink.add,
          onDone: () => streamedRequest.sink.close(),
          onError: (e) => streamedRequest.sink.addError(e),
          cancelOnError: true,
        );

        final streamedResponse = await streamedRequest.send().timeout(
          const Duration(minutes: 5),
        );
        final statusCode = streamedResponse.statusCode;

        if (statusCode == 200 || statusCode == 201) {
          await streamedResponse.stream.drain<void>();
          debugPrint('[CloudflareR2] ✅ Video uploaded successfully');
          return publicUrl;
        } else {
          await streamedResponse.stream.drain<void>();
          debugPrint('[CloudflareR2] Video PUT failed ($statusCode)');
          return null;
        }
      }

      // Ảnh hoặc file nhỏ: dùng readAsBytes như cũ
      final bytes = await finalFile.readAsBytes();
      final putResponse = await _sendBytes(
        'PUT',
        uploadUri,
        headers: headers,
        bytes: bytes,
      );

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        debugPrint('[CloudflareR2] ✅ File uploaded successfully');
        return publicUrl;
      } else {
        debugPrint('[CloudflareR2] PUT failed: ${putResponse.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudflareR2] ❌ Lỗi khi upload: ${e.runtimeType}');
      return null;
    }
  }

  /// Kiểm tra URL có phải của R2 hay không
  bool isR2Url(String url) {
    return publicDomain.isNotEmpty && url.trim().startsWith(publicDomain);
  }

  /// Xoá object trên R2 từ public URL
  Future<bool> deleteFile(String url) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;

      final apiUrl = R2UploadPolicy.requireHttps(
        '${AppConfig.cloudflareWorkerUrl}/api/deleteR2Object',
      );
      final response = await _sendBytes(
        'POST',
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        bytes: utf8.encode(jsonEncode({'objectUrl': url})),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode != 200) return false;
      final resData = jsonDecode(response.body)['result'] as Map;
      return resData['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá file: ${e.runtimeType}');
      return false;
    }
  }

  /// Xoá object trên R2 trực tiếp từ storage path
  Future<bool> deleteByPath(String objectName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;

      final apiUrl = R2UploadPolicy.requireHttps(
        '${AppConfig.cloudflareWorkerUrl}/api/deleteR2Object',
      );
      final response = await _sendBytes(
        'POST',
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        bytes: utf8.encode(jsonEncode({'objectPath': objectName})),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode != 200) return false;
      final resData = jsonDecode(response.body)['result'] as Map;
      return resData['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá theo path: ${e.runtimeType}');
      return false;
    }
  }
}
