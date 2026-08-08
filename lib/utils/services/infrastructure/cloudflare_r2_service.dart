import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_compress/video_compress.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/core/constants/app_config.dart';

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

  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      case '.m4v':
        return 'video/x-m4v';
      case '.3gp':
        return 'video/3gpp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  /// Uploads base64 image data to Cloudflare R2
  Future<String?> uploadBase64(String base64Data,
      {required String folderPath, String extension = 'jpg'}) async {
    try {
      String cleanBase64 = base64Data;
      if (base64Data.contains(',')) {
        cleanBase64 = base64Data.split(',').last;
      }

      final bytes = base64Decode(cleanBase64);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();

      final url = Uri.parse('${AppConfig.cloudflareWorkerUrl}/api/getSignedUploadUrl');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'fileName': 'image_$extension',
          'contentType': 'image/$extension',
          'folderPath': folderPath,
          'fileSize': bytes.length,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('[CloudflareR2] Worker returned error: ${response.body}');
        return null;
      }

      final resData = jsonDecode(response.body)['result'] as Map;
      final uploadUrl = resData['uploadUrl'] as String;
      final publicUrl = resData['publicUrl'] as String;
      final headers = Map<String, String>.from(resData['headers'] ?? {});
      headers['Authorization'] = 'Bearer $idToken';

      // Tiến hành upload nhị phân trực tiếp bằng HTTP PUT qua proxy Worker hoặc R2
      final putResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      );

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        return publicUrl;
      } else {
        debugPrint(
            '[CloudflareR2] PUT failed: ${putResponse.statusCode} - ${putResponse.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudflareR2] Upload Base64 failed: $e');
      return null;
    }
  }

  /// Upload File lên R2 và trả về public link
  Future<String?> uploadFile(File file,
      {required String folderPath, String? storagePathOverride}) async {
    try {
      String fileName = path.basename(file.path);
      final contentType = _getMimeType(file.path);
      final isVideo = contentType.startsWith('video/');
      
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
          debugPrint('[CloudflareR2] Non-VIP user: Compressing video to 720p...');
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
            debugPrint('[CloudflareR2] Video compress failed: $compressError, falling back to original');
          }
        } else {
          debugPrint('[CloudflareR2] VIP user: Uploading original video...');
        }
      }

      final fileSize = await finalFile.length();
      debugPrint('[CloudflareR2] Upload file: $fileName, size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB, type: $contentType');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[CloudflareR2] Upload failed: user not authenticated');
        return null;
      }
      final idToken = await user.getIdToken();

      final url = Uri.parse('${AppConfig.cloudflareWorkerUrl}/api/getSignedUploadUrl');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'fileName': fileName,
          'contentType': contentType,
          'folderPath': folderPath,
          'fileSize': fileSize,
          if (storagePathOverride != null) 'exactPath': storagePathOverride,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('[CloudflareR2] Worker returned error (${response.statusCode}): ${response.body}');
        return null;
      }

      final resData = jsonDecode(response.body)['result'] as Map;
      final uploadUrl = resData['uploadUrl'] as String;
      final publicUrl = resData['publicUrl'] as String;
      final headers = Map<String, String>.from(resData['headers'] ?? {});
      headers['Authorization'] = 'Bearer $idToken';

      // Video lớn: dùng streamed request để không load hết vào RAM
      if (isVideo && fileSize > 5 * 1024 * 1024) {
        debugPrint('[CloudflareR2] Using streamed upload for video ($fileName)...');
        final streamedRequest = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
        streamedRequest.headers.addAll(headers);
        streamedRequest.contentLength = fileSize;

        // Stream file trực tiếp không qua readAsBytes
        finalFile.openRead().listen(
          streamedRequest.sink.add,
          onDone: () => streamedRequest.sink.close(),
          onError: (e) => streamedRequest.sink.addError(e),
          cancelOnError: true,
        );

        final streamedResponse = await streamedRequest.send()
            .timeout(const Duration(minutes: 5));
        final statusCode = streamedResponse.statusCode;

        if (statusCode == 200 || statusCode == 201) {
          debugPrint('[CloudflareR2] ✅ Video uploaded successfully: $publicUrl');
          return publicUrl;
        } else {
          final body = await streamedResponse.stream.bytesToString();
          debugPrint('[CloudflareR2] Video PUT failed ($statusCode): $body');
          return null;
        }
      }

      // Ảnh hoặc file nhỏ: dùng readAsBytes như cũ
      final bytes = await finalFile.readAsBytes();
      final putResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      ).timeout(const Duration(minutes: 2));

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        debugPrint('[CloudflareR2] ✅ File uploaded successfully: $publicUrl');
        return publicUrl;
      } else {
        debugPrint(
            '[CloudflareR2] PUT failed: ${putResponse.statusCode} - ${putResponse.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudflareR2] ❌ Lỗi khi upload: $e');
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

      final apiUrl = Uri.parse('${AppConfig.cloudflareWorkerUrl}/api/deleteR2Object');
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'objectUrl': url,
        }),
      );

      if (response.statusCode != 200) return false;
      final resData = jsonDecode(response.body)['result'] as Map;
      return resData['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá file: $e');
      return false;
    }
  }

  /// Xoá object trên R2 trực tiếp từ storage path
  Future<bool> deleteByPath(String objectName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final apiUrl = Uri.parse('${AppConfig.cloudflareWorkerUrl}/api/deleteR2Object');
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'objectPath': objectName,
        }),
      );

      if (response.statusCode != 200) return false;
      final resData = jsonDecode(response.body)['result'] as Map;
      return resData['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá theo path: $e');
      return false;
    }
  }
}
