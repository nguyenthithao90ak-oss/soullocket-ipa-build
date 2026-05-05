import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'app_lifecycle_presence_guard.dart';
import 'image_picker_recovery_service.dart';
import 'storage_media_constants.dart';
import 'storage_web_picker_guard.dart';

class StoragePickerService {
  StoragePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int pickerImageQuality = 94;
  static const double pickerMaxWidth = 1080;
  static const double pickerMaxHeight = 1080;
  static const int maxGallerySelectionPerBatch = 30;

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
    final bytes = file.bytes;
    if (bytes != null) {
      return XFile.fromData(bytes, name: file.name);
    }
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return XFile(path, name: file.name);
    }
    return null;
  }

  Future<XFile?> pickMusicFile() async {
    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowMultiple: false,
          allowedExtensions: storageMusicPickerExtensions,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          return platformFileToXFile(result.files.first);
        }
      } finally {
        StorageWebPickerGuard.arm();
      }
      return null;
    }

    return _guardedPicker(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: storageMusicPickerExtensions,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      return platformFileToXFile(result.files.first);
    });
  }

  Future<XFile?> pickImage() async {
    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          return platformFileToXFile(result.files.first);
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
        imageQuality: pickerImageQuality,
        maxWidth: pickerMaxWidth,
        maxHeight: pickerMaxHeight,
      ),
    );
  }

  Future<List<XFile>> pickImages({int? limit}) async {
    final normalizedLimit = clampImagePickLimit(limit);
    if (normalizedLimit <= 0) {
      return const <XFile>[];
    }

    if (kIsWeb) {
      StorageWebPickerGuard.arm(const Duration(seconds: 4));
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          withData: true,
        );
        final files = (result?.files ?? const <PlatformFile>[])
            .map(platformFileToXFile)
            .whereType<XFile>()
            .toList();
        if (files.length > normalizedLimit) {
          return files.take(normalizedLimit).toList();
        }
        return files;
      } finally {
        StorageWebPickerGuard.arm();
      }
    }

    final files = await _guardedPicker(
      () => ImagePickerRecoveryService.instance.pickMultiImage(
        picker: _picker,
        imageQuality: pickerImageQuality,
        maxWidth: pickerMaxWidth,
        maxHeight: pickerMaxHeight,
      ),
    );
    if (files.length > normalizedLimit) {
      return files.take(normalizedLimit).toList();
    }
    return files;
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
