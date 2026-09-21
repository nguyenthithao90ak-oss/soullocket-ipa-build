import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../storage/storage_upload_queue.dart';
import '../storage/storage_upload_result.dart';
import 'r2_media_transport.dart';
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

  static final _videoQueue = StorageUploadQueue();
  static int _uploadSequence = 0;

  /// Giữ API cũ cho caller native, nhưng dùng chung đường truyền với Web.
  Future<String?> uploadFile(
    File file, {
    required String folderPath,
    String? storagePathOverride,
  }) async {
    try {
      final result = await uploadMedia(
        XFile(file.path),
        folderPath: folderPath,
        storagePathOverride: storagePathOverride,
      );
      return result.downloadUrl;
    } catch (error) {
      debugPrint('[CloudflareR2] Upload failed: ${error.runtimeType}');
      return null;
    }
  }

  Future<StorageUploadResult> uploadMedia(
    XFile file, {
    required String folderPath,
    String? storagePathOverride,
    String? contentType,
    Future<void> Function(int bytes)? beforeUpload,
    ValueChanged<double>? onProgress,
  }) async {
    var prepared = file;
    var mime = contentType ?? R2UploadPolicy.mimeTypeForPath(file.name);
    String? compressedPath;
    final isVideo = mime.startsWith('video/');
    if (isVideo && !AppConfig.isVideoUploadEnabled) {
      throw StateError('Video uploads disabled');
    }
    // Mỗi tác vụ giữ quyền nén tới khi gửi xong và dọn đúng tệp của nó.
    Future<StorageUploadResult> send() async {
      final client = http.Client();
      try {
        if (isVideo &&
            !kIsWeb &&
            file.path.isNotEmpty &&
            !await PurchaseService().isVip()) {
          if (VideoCompress.isCompressing) {
            throw StateError('Video compressor is busy');
          }
          MediaInfo? info;
          try {
            info = await VideoCompress.compressVideo(
              file.path,
              quality: VideoQuality.Res1280x720Quality,
              deleteOrigin: false,
            ).timeout(const Duration(minutes: 5));
          } catch (_) {
            try {
              await VideoCompress.cancelCompression();
            } finally {
              // Plugin 3.1.4 không reset cờ này khi native ném lỗi.
              // Chỉ reset tác vụ đã được hàng đợi này khởi chạy.
              // ignore: invalid_use_of_protected_member
              VideoCompress.setProcessingStatus(false);
            }
            rethrow;
          }
          if (info?.file == null) throw StateError('Video compression failed');
          prepared = XFile(info!.file!.path);
          if (prepared.path != file.path) compressedPath = prepared.path;
          mime = R2UploadPolicy.mimeTypeForPath(prepared.name);
        }
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();
        if (token == null || token.isEmpty) {
          throw StateError('Authentication required');
        }
        final extension = R2UploadPolicy.extensionForMimeType(mime);
        final originalPath =
            storagePathOverride ??
            '$folderPath/${DateTime.now().microsecondsSinceEpoch}_${_uploadSequence++}$extension';
        // Chỉ đổi đuôi khi bytes thực sự đã chuyển định dạng.
        final targetPath = path.withoutExtension(originalPath) + extension;
        return await const R2MediaTransport().upload(
          file: prepared,
          contentType: mime,
          storagePath: targetPath.replaceAll('\\', '/'),
          workerUri: Uri.parse(
            '${AppConfig.cloudflareWorkerUrl}/api/getSignedUploadUrl',
          ),
          idToken: token,
          client: client,
          beforeUpload: beforeUpload,
          onProgress: onProgress,
        );
      } finally {
        client.close();
        if (compressedPath != null) {
          try {
            await File(compressedPath!).delete();
          } catch (_) {
            /* Tệp tạm có thể đã được hệ điều hành dọn. */
          }
        }
      }
    }

    return isVideo && !kIsWeb ? _videoQueue.run(send) : send();
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
