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
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
import 'package:soullocket_app/utils/services/infrastructure/r2_upload_policy.dart';
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

  Future<Map<String, dynamic>> _createUploadSession({
    required String fileName,
    required String folder,
    required String contentType,
    required int fileSize,
  }) async {
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'generateUploadUrl',
      payload: <String, dynamic>{
        'folder': folder,
        'fileName': fileName,
        'contentType': contentType,
        'fileSize': fileSize,
      },
      timeout: const Duration(seconds: 30),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return result.data;
  }

  Future<Map<String, dynamic>> _finalizeUpload(String uploadId) async {
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'finalizeR2Upload',
      payload: <String, dynamic>{'uploadId': uploadId},
      timeout: const Duration(seconds: 30),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return result.data;
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

      final result = await uploadMedia(
        XFile.fromData(bytes, name: fileName, mimeType: contentType),
        folderPath: folderPath,
        storagePathOverride: '$folderPath/$fileName',
        contentType: contentType,
      );
      return result.downloadUrl;
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
    String? contentType,
  }) async {
    try {
      final result = await uploadMedia(
        XFile(file.path),
        folderPath: folderPath,
        storagePathOverride: storagePathOverride,
        contentType: contentType,
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
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    void guard() {
      if (ownerUid == null ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid) {
        throw FirebaseAuthException(code: 'user-token-expired');
      }
    }

    guard();
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
        guard();
        final extension = R2UploadPolicy.extensionForMimeType(mime);
        final originalPath =
            storagePathOverride ??
            '$folderPath/${DateTime.now().microsecondsSinceEpoch}_${_uploadSequence++}$extension';
        final targetPath = path.withoutExtension(originalPath) + extension;
        return await const R2MediaTransport().upload(
          file: prepared,
          contentType: mime,
          storagePath: targetPath.replaceAll('\\', '/'),
          createUploadSession:
              ({
                required fileName,
                required folder,
                required contentType,
                required fileSize,
              }) async {
                guard();
                final session = await _createUploadSession(
                  fileName: fileName,
                  folder: folder,
                  contentType: contentType,
                  fileSize: fileSize,
                );
                guard();
                return session;
              },
          finalizeUpload: (uploadId) async {
            guard();
            final result = await _finalizeUpload(uploadId);
            guard();
            return result;
          },
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
    final normalizedUrl = url.trim();
    final domain = publicDomain.trim().replaceFirst(RegExp(r'/+$'), '');
    if (domain.isEmpty || !normalizedUrl.startsWith('$domain/')) {
      return false;
    }
    final objectKey = normalizedUrl
        .substring(domain.length + 1)
        .split('?')
        .first;
    if (objectKey.isEmpty) return false;
    return deleteByPath(objectKey);
  }

  /// Xoá object trên R2 trực tiếp từ storage path
  Future<bool> deleteByPath(String objectName) async {
    try {
      final normalizedPath = objectName.trim();
      if (normalizedPath.isEmpty) return false;
      final result =
          await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
            'deleteR2Object',
            payload: <String, dynamic>{'objectKey': normalizedPath},
            timeout: const Duration(seconds: 30),
            requireAppCheck: true,
            throwOriginalException: true,
          );
      final data = result.data;
      return data['success'] == true;
    } catch (e) {
      debugPrint('[CloudflareR2] Lỗi xoá file: ${e.runtimeType}');
      return false;
    }
  }
}
