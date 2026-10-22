import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/constants/app_config.dart';

import '../app_lifecycle_presence_guard.dart';
import '../image_picker_recovery_service.dart';
import 'storage_media_constants.dart';
import 'storage_web_picker_guard.dart';

class StoragePickerService {
  StoragePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const MethodChannel _memoryMediaPickerChannel = MethodChannel(
    'soullocket/memory_media_picker',
  );

  static const int pickerImageQuality = AppConfig.imageCompressQuality;
  static const double pickerMaxWidth = 1080;
  static const double pickerMaxHeight = 1080;
  static const int maxGallerySelectionPerBatch = 999;

  /// Tên tạm do picker native cấp; giữ được qua journal và khởi động lại app.
  static bool isLivePhotoFile(XFile file) => [file.name, file.path].any((value) {
    final name = value.replaceAll('\\', '/').split('/').last.toLowerCase();
    return name.startsWith('live_photo_') &&
        (name.endsWith('.mov') || name.endsWith('.mp4'));
  });

  static int clampImagePickLimit(
    int? requested, {
    int maxAllowed = maxGallerySelectionPerBatch,
  }) {
    final safeMax = maxAllowed > 0 ? maxAllowed : maxGallerySelectionPerBatch;
    if (requested == null) {
      return safeMax;
    }
    if (requested <= 0) {
      return 0;
    }
    return requested > safeMax ? safeMax : requested;
  }

  XFile? platformFileToXFile(PlatformFile file) {
    try {
      return file.xFile;
    } catch (_) {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        return XFile(path, name: file.name);
      }
      return null;
    }
  }

  Future<XFile?> pickMusicFile() async {
    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: storageMusicPickerExtensions,
        );
        if (file != null) {
          return platformFileToXFile(file);
        }
      } finally {
        StorageWebPickerGuard.arm();
      }
      return null;
    }

    return _guardedPicker(() async {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: storageMusicPickerExtensions,
      );
      if (file == null) {
        return null;
      }
      return platformFileToXFile(file);
    });
  }

  Future<List<XFile>> pickMultipleMusicFiles({int maxFiles = 5}) async {
    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: storageMusicPickerExtensions,
          allowMultiple: true,
        );
        if (files.isNotEmpty) {
          return files
              .take(maxFiles)
              .map((f) => platformFileToXFile(f))
              .whereType<XFile>()
              .toList();
        }
      } finally {
        StorageWebPickerGuard.arm();
      }
      return [];
    }

    final list = await _guardedPicker<List<XFile>>(() async {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: storageMusicPickerExtensions,
        allowMultiple: true,
      );
      if (files.isEmpty) {
        return <XFile>[];
      }
      return files
          .take(maxFiles)
          .map((f) => platformFileToXFile(f))
          .whereType<XFile>()
          .toList();
    });
    return list;
  }

  Future<XFile?> pickImage({bool preserveOriginal = false}) async {
    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final file = await FilePicker.pickFile(
          type: FileType.image,
        );
        if (file != null) {
          return platformFileToXFile(file);
        }
      } finally {
        StorageWebPickerGuard.arm();
      }
      return null;
    }
    return _guardedPicker(
      () => ImagePickerRecoveryService.instance.pickImage(
        picker: _picker,
        source: ImageSource.gallery,
        imageQuality: preserveOriginal ? null : pickerImageQuality,
        maxWidth: preserveOriginal ? null : pickerMaxWidth,
        maxHeight: preserveOriginal ? null : pickerMaxHeight,
      ),
    );
  }

  Future<List<XFile>> pickImages({
    int? limit,
    bool preserveOriginal = false,
  }) async {
    final normalizedLimit = clampImagePickLimit(limit);
    if (normalizedLimit <= 0) {
      return const <XFile>[];
    }

    final imageQuality = preserveOriginal ? null : pickerImageQuality;
    final maxWidth = preserveOriginal ? null : pickerMaxWidth;
    final maxHeight = preserveOriginal ? null : pickerMaxHeight;

    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.image,
        );
        final mapped = files
            .map(platformFileToXFile)
            .whereType<XFile>()
            .toList();
        if (mapped.length > normalizedLimit) {
          return mapped.take(normalizedLimit).toList();
        }
        return mapped;
      } finally {
        StorageWebPickerGuard.arm();
      }
    }

    final files = await _guardedPicker(
      () => ImagePickerRecoveryService.instance.pickMultiImage(
        picker: _picker,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    );
    if (files.length > normalizedLimit) {
      return files.take(normalizedLimit).toList();
    }
    return files;
  }

  Future<List<XFile>> pickMedia({
    int? limit,
    bool preserveOriginal = false,
  }) async {
    final normalizedLimit = clampImagePickLimit(limit);
    if (normalizedLimit <= 0) {
      return const <XFile>[];
    }

    final imageQuality = preserveOriginal ? null : pickerImageQuality;
    final maxWidth = preserveOriginal ? null : pickerMaxWidth;
    final maxHeight = preserveOriginal ? null : pickerMaxHeight;

    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.media,
          allowMultiple: true,
        );
        final mapped = files
            .map(platformFileToXFile)
            .whereType<XFile>()
            .toList();
        if (mapped.length > normalizedLimit) {
          return mapped.take(normalizedLimit).toList();
        }
        return mapped;
      } finally {
        StorageWebPickerGuard.arm();
      }
    }

    final files = await _guardedPicker(
      () => _picker.pickMultipleMedia(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    );
    if (files.length > normalizedLimit) {
      return files.take(normalizedLimit).toList();
    }
    return files;
  }

  /// Chọn media cho Kỷ niệm.
  ///
  /// Trên iOS, picker native trả Live Photo dưới dạng video ghép ngắn (.mov),
  /// nên pipeline upload hiện có có thể nén, tạo thumbnail và phát lặp như
  /// video dọc. Nếu channel chưa có (bản cũ/hot restart), dùng picker chung.
  Future<List<XFile>> pickMemoryMedia({
    int? limit,
    bool preserveOriginal = false,
  }) async {
    final normalizedLimit = clampImagePickLimit(limit);
    if (normalizedLimit <= 0) {
      return const <XFile>[];
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return pickMedia(
        limit: normalizedLimit,
        preserveOriginal: preserveOriginal,
      );
    }

    try {
      final raw = await _guardedPicker(
        () => _memoryMediaPickerChannel.invokeMethod<List<dynamic>>(
          'pickMemoryMedia',
          <String, dynamic>{
            'limit': normalizedLimit,
            'preserveOriginal': preserveOriginal,
          },
        ),
      );
      if (raw == null) {
        return const <XFile>[];
      }
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((entry) {
            final path = entry['path']?.toString().trim() ?? '';
            if (path.isEmpty) return null;
            final name = entry['name']?.toString().trim() ?? '';
            final mimeType = entry['mimeType']?.toString().trim();
            return XFile(
              path,
              name: name.isEmpty ? null : name,
              mimeType: mimeType?.isEmpty == true ? null : mimeType,
            );
          })
          .whereType<XFile>()
          .take(normalizedLimit)
          .toList(growable: false);
    } on MissingPluginException {
      return pickMedia(
        limit: normalizedLimit,
        preserveOriginal: preserveOriginal,
      );
    } on PlatformException catch (error) {
      if (error.code == 'unsupported' || error.code == 'not_implemented') {
        return pickMedia(
          limit: normalizedLimit,
          preserveOriginal: preserveOriginal,
        );
      }
      rethrow;
    }
  }

  Future<XFile?> snapPhoto() {
    return _guardedPicker(
      () => ImagePickerRecoveryService.instance.pickImage(
        picker: _picker,
        source: ImageSource.camera,
        imageQuality: pickerImageQuality,
        maxWidth: pickerMaxWidth,
        maxHeight: pickerMaxHeight,
      ),
    );
  }

  Future<T> _guardedPicker<T>(Future<T> Function() action) async {
    AppLifecyclePresenceGuard.arm();
    try {
      return await action();
    } finally {
      AppLifecyclePresenceGuard.settle();
    }
  }
}
