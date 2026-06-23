import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

class ImagePickerRecoveryService {
  ImagePickerRecoveryService._();

  static final ImagePickerRecoveryService instance =
      ImagePickerRecoveryService._();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pendingRecoveredImages = <XFile>[];

  bool _didPrimeLostData = false;
  Future<void>? _primeLostDataFuture;

  bool get hasPendingRecoveredImages => _pendingRecoveredImages.isNotEmpty;

  Future<void> primeLostData() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _didPrimeLostData = true;
      return;
    }
    if (_didPrimeLostData) {
      return;
    }

    final inFlight = _primeLostDataFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _primeLostDataInternal();
    _primeLostDataFuture = future;
    try {
      await future;
    } finally {
      if (identical(_primeLostDataFuture, future)) {
        _primeLostDataFuture = null;
      }
    }
  }

  Future<XFile?> pickImage({
    required ImageSource source,
    ImagePicker? picker,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    await primeLostData();
    final recovered = _takeNextRecoveredImage();
    if (recovered != null) {
      return recovered;
    }

    final resolvedPicker = picker ?? _picker;
    return resolvedPicker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: preferredCameraDevice,
      requestFullMetadata: requestFullMetadata,
    );
  }

  Future<List<XFile>> pickMultiImage({
    ImagePicker? picker,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    await primeLostData();
    final recovered = _takeRecoveredImages(limit: limit);
    if (recovered.isNotEmpty) {
      return recovered;
    }

    final resolvedPicker = picker ?? _picker;
    final files = await resolvedPicker.pickMultiImage(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      limit: limit,
      requestFullMetadata: requestFullMetadata,
    );
    if (limit != null && limit > 0 && files.length > limit) {
      return files.take(limit).toList();
    }
    return files;
  }

  Future<void> _primeLostDataInternal() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return;
      }

      final files = response.files ??
          (response.file == null ? const <XFile>[] : <XFile>[response.file!]);
      if (files.isNotEmpty) {
        _pendingRecoveredImages.addAll(files);
      } else if (response.exception != null) {
        debugPrint(
          'Image picker lost data recovery failed: ${response.exception}',
        );
      }
    } catch (error) {
      debugPrint('Image picker lost data check failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể kiểm tra ảnh chưa khôi phục.',
      ).message}');
    } finally {
      _didPrimeLostData = true;
    }
  }

  XFile? _takeNextRecoveredImage() {
    if (_pendingRecoveredImages.isEmpty) {
      return null;
    }
    return _pendingRecoveredImages.removeAt(0);
  }

  List<XFile> _takeRecoveredImages({int? limit}) {
    if (_pendingRecoveredImages.isEmpty) {
      return const <XFile>[];
    }

    if (limit == null ||
        limit <= 0 ||
        limit >= _pendingRecoveredImages.length) {
      final files = List<XFile>.from(_pendingRecoveredImages);
      _pendingRecoveredImages.clear();
      return files;
    }

    final files = _pendingRecoveredImages.take(limit).toList();
    _pendingRecoveredImages.removeRange(0, limit);
    return files;
  }
}
