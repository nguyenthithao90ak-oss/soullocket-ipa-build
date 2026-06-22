import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import 'package:minio/io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class CloudflareR2Service {
  static final CloudflareR2Service instance = CloudflareR2Service._internal();
  factory CloudflareR2Service() => instance;
  CloudflareR2Service._internal();

  // Chỉ dùng --dart-define khi build. Không có defaultValue.
  // Key được lưu trong file keys_r2.json (đã thêm .gitignore).
  // Dùng build_aab.bat hoặc flutter_run.bat để build/chạy tự động.
  static const String accessKey = String.fromEnvironment('R2_ACCESS_KEY_ID');
  static const String secretKey = String.fromEnvironment('R2_SECRET_ACCESS_KEY');
  static const String endpoint = String.fromEnvironment('R2_ENDPOINT_URL');
  static const String bucketName = String.fromEnvironment('R2_BUCKET_NAME', defaultValue: 'soullocket-media');
  static const String publicDomain = String.fromEnvironment('R2_PUBLIC_DOMAIN');

  Minio? _minio;

  bool get isConfigured => accessKey.isNotEmpty && secretKey.isNotEmpty && endpoint.isNotEmpty;

  void init() {
    if (!isConfigured) return;
    
    // Endpoint của Cloudflare R2 thường có dạng: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return;

    _minio = Minio(
      endPoint: uri.host,
      accessKey: accessKey,
      secretKey: secretKey,
      region: 'auto', // R2 luôn dùng region 'auto'
      useSSL: uri.scheme == 'https',
    );
  }

  /// Uploads base64 image data to Cloudflare R2
  Future<String?> uploadBase64(String base64Data, {required String folderPath, String extension = 'jpg'}) async {
    if (!isConfigured || _minio == null) {
      debugPrint('[CloudflareR2] R2 is not configured.');
      return null;
    }

    try {
      // Bỏ phần header data:image/jpeg;base64, nếu có
      String cleanBase64 = base64Data;
      if (base64Data.contains(',')) {
        cleanBase64 = base64Data.split(',').last;
      }

      // Decode base64 sang mảng byte
      final bytes = base64Decode(cleanBase64);
      
      // Tạo một file tạm thời
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_upload_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await tempFile.writeAsBytes(bytes);

      // Dùng hàm uploadFile đã có để đẩy lên R2
      final url = await uploadFile(tempFile, folderPath: folderPath);
      
      // Xóa file tạm để giải phóng bộ nhớ
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return url;
    } catch (e) {
      debugPrint('[CloudflareR2] Upload Base64 failed: $e');
      return null;
    }
  }

  /// Upload File lên R2 và trả về public link
  Future<String?> uploadFile(File file, {required String folderPath}) async {
    if (!isConfigured || _minio == null) {
      debugPrint('[CloudflareR2] R2 chưa được cấu hình. (Chưa có Key)');
      return null;
    }

    try {
      final fileName = path.basename(file.path);
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final objectName = '$folderPath/$uniqueFileName';

      // Upload file sử dụng Minio SDK
      await _minio!.fPutObject(
        bucketName,
        objectName,
        file.path,
      );

      // Trả về link ảnh công khai để lưu vào Firebase Realtime Database
      if (publicDomain.isNotEmpty) {
        return '$publicDomain/$objectName';
      } else {
        return objectName; // Fallback
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
  /// URL format: https://pub-xxx.r2.dev/media/1234567890_filename.jpg
  Future<bool> deleteFile(String url) async {
    if (!isConfigured || _minio == null) return false;

    try {
      final objectName = _extractObjectName(url);
      if (objectName == null || objectName.isEmpty) return false;

      await _minio!.removeObject(bucketName, objectName);
      debugPrint('[CloudflareR2] Đã xoá: $objectName');
      return true;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá file: $e');
      return false;
    }
  }

  /// Lấy object name từ public URL
  String? _extractObjectName(String url) {
    final normalized = url.trim();
    if (publicDomain.isEmpty || !normalized.startsWith(publicDomain)) return null;

    const prefix = '$publicDomain/';
    if (!normalized.startsWith(prefix)) return null;

    return normalized.substring(prefix.length);
  }
}
