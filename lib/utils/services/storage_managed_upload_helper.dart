import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'storage_upload_result.dart';

typedef StorageCurrentUidProvider = String Function();
typedef StorageContentTypeDetector = String Function(
  String fileNameOrPath, {
  String fallback,
});
typedef StorageWritePathNormalizer = String Function(String storagePath);
typedef StorageFileUploader = Future<String> Function(
  String storagePath,
  XFile file, {
  String? contentType,
  ValueChanged<double>? onProgress,
});

class StorageManagedUploadRequest {
  const StorageManagedUploadRequest({
    required this.houseId,
    required this.folderName,
    required this.file,
    required this.minWidth,
    required this.minHeight,
    required this.quality,
  });

  final String houseId;
  final String folderName;
  final XFile file;
  final int minWidth;
  final int minHeight;
  final int quality;
}

class StorageManagedUploadHelper {
  const StorageManagedUploadHelper();

  Future<StorageUploadResult?> uploadManagedImage({
    required StorageManagedUploadRequest request,
    required StorageCurrentUidProvider requireCurrentUid,
    required StorageContentTypeDetector detectContentType,
    required StorageWritePathNormalizer normalizeStorageWritePath,
    required StorageFileUploader uploadFileToPath,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final originalFileName =
          request.file.name.isNotEmpty ? request.file.name : request.file.path;
      String fileExtension = p.extension(originalFileName).toLowerCase();
      XFile uploadFile = request.file;
      String? tempCompressedPath;

      String finalContentType = detectContentType(
        originalFileName,
        fallback: 'image/webp',
      );

      if (!kIsWeb && request.file.path.isNotEmpty && fileExtension != '.gif') {
        try {
          final tempDir = await getTemporaryDirectory();
          tempCompressedPath = p.join(
            tempDir.path,
            'sl_upload_${nowMs}_${DateTime.now().microsecondsSinceEpoch}.webp',
          );

          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            request.file.path,
            tempCompressedPath,
            minWidth: request.minWidth,
            minHeight: request.minHeight,
            quality: request.quality,
            format: CompressFormat.webp,
          );

          if (compressedFile != null) {
            uploadFile = compressedFile;
            fileExtension = '.webp';
            finalContentType = 'image/webp';
          } else {
            tempCompressedPath = null;
          }
        } catch (compressError) {
          debugPrint('Lỗi khi nén ảnh WebP: ${AppErrorMapper.resolve(
            compressError,
            fallbackMessage: 'Không thể nén ảnh WebP.',
          ).message}');
          tempCompressedPath = null;
        }
      }

      if (fileExtension.isEmpty) {
        fileExtension = p.extension(uploadFile.name).toLowerCase();
      }
      if (fileExtension.isEmpty) {
        fileExtension = '.jpg';
      }

      final currentUid = requireCurrentUid();
      final path =
          'uploads/$currentUid/houses/${request.houseId}/${request.folderName}/$nowMs$fileExtension';
      final normalizedStoragePath = normalizeStorageWritePath(path);
      try {
        final downloadUrl =
            tempCompressedPath != null && uploadFile.path == tempCompressedPath
                ? await uploadFileToPath(
                    path,
                    XFile(tempCompressedPath),
                    contentType: finalContentType,
                    onProgress: onProgress,
                  )
                : await uploadFileToPath(
                    path,
                    uploadFile,
                    contentType: finalContentType,
                    onProgress: onProgress,
                  );

        return StorageUploadResult(
          downloadUrl: downloadUrl,
          storagePath: normalizedStoragePath,
        );
      } finally {
        if (tempCompressedPath != null) {
          final tempFile = File(tempCompressedPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi khi upload ảnh: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không tải ảnh lên đám mây được.',
      ).message}');
      throw 'Không thể tải ảnh lên đám mây, vui lòng kiểm tra kết nối mạng.';
    }
  }
}
