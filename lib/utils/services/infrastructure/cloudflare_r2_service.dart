import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

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

  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
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

      // Yêu cầu sinh Presigned URL từ backend
      final callable =
          FirebaseFunctions.instance.httpsCallable('getSignedUploadUrlSecure');
      final result = await callable.call(<String, dynamic>{
        'fileName': 'image_$extension',
        'contentType': 'image/$extension',
        'folderPath': folderPath,
      });

      final resData = result.data as Map;
      final uploadUrl = resData['uploadUrl'] as String;
      final publicUrl = resData['publicUrl'] as String;
      final headers = Map<String, String>.from(resData['headers'] ?? {});

      // Tiến hành upload nhị phân trực tiếp bằng HTTP PUT
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
      final fileName = path.basename(file.path);
      final contentType = _getMimeType(file.path);
      final bytes = await file.readAsBytes();

      // Yêu cầu sinh Presigned URL từ backend
      final callable =
          FirebaseFunctions.instance.httpsCallable('getSignedUploadUrlSecure');
      final result = await callable.call(<String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
        'folderPath': folderPath,
        if (storagePathOverride != null) 'exactPath': storagePathOverride,
      });

      final resData = result.data as Map;
      final uploadUrl = resData['uploadUrl'] as String;
      final publicUrl = resData['publicUrl'] as String;
      final headers = Map<String, String>.from(resData['headers'] ?? {});

      // Tiến hành upload nhị phân trực tiếp bằng HTTP PUT
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
      debugPrint('[CloudflareR2] Lỗi khi upload: $e');
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
      final callable =
          FirebaseFunctions.instance.httpsCallable('deleteR2ObjectSecure');
      final result = await callable.call(<String, dynamic>{
        'objectUrl': url,
      });
      final resData = result.data as Map;
      return resData['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá file: $e');
      return false;
    }
  }

  /// Xoá object trên R2 trực tiếp từ storage path
  Future<bool> deleteByPath(String objectName) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('deleteR2ObjectSecure');
      final result = await callable.call(<String, dynamic>{
        'objectPath': objectName,
      });
      final resData = result.data as Map;
      return resData['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá theo path: $e');
      return false;
    }
  }
}
