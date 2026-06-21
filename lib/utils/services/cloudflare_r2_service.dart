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

  // Các biến môi trường này sẽ được cấu hình khi build app (hoặc cấu hình thẳng trong AppConfig)
  static const String accessKey = String.fromEnvironment('R2_ACCESS_KEY_ID', defaultValue: '064d1866e0790f09783f0b99e50c1394');
  static const String secretKey = String.fromEnvironment('R2_SECRET_ACCESS_KEY', defaultValue: '851a055aa0b3a01927e0bac830084fffcbce6deb9ab367458c845d1c161b4ffd');
  static const String endpoint = String.fromEnvironment('R2_ENDPOINT_URL', defaultValue: 'https://cb19b30ef636ede2f9d6083c61cd67fa.r2.cloudflarestorage.com');
  static const String bucketName = String.fromEnvironment('R2_BUCKET_NAME', defaultValue: 'soullocket-media');
  static const String publicDomain = String.fromEnvironment('R2_PUBLIC_DOMAIN', defaultValue: 'https://pub-e3f21ed5012d4c02ba42d23dd6d01dfa.r2.dev'); // Link pub-xxx.r2.dev

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
}
