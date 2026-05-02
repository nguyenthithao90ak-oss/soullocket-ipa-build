import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_error_mapper.dart';
import 'secret_vault_media_policy.dart' as secret_vault_policy;
import 'storage_app_check_helper.dart';
import 'storage_content_policy.dart';
import 'storage_delete_helper.dart';
import 'storage_download_cache_helper.dart';
import 'storage_finalize_helper.dart';
import 'storage_managed_upload_helper.dart';
import 'storage_media_constants.dart';
import 'storage_path_policy.dart';
import 'storage_picker_service.dart';
import 'storage_raw_upload_helper.dart';
import 'storage_signed_upload_helper.dart';
import 'storage_upload_result.dart';
import 'storage_upload_session_helper.dart';
import 'storage_upload_result_mapper.dart';
import 'storage_web_picker_guard.dart';

class StorageService {
  StorageService();

  static StorageService get instance => StorageService();

  static const int pickerImageQuality = StoragePickerService.pickerImageQuality;
  static const double pickerMaxWidth = StoragePickerService.pickerMaxWidth;
  static const double pickerMaxHeight = StoragePickerService.pickerMaxHeight;
  static const int secretVaultDailyLimitFree =
      secret_vault_policy.secretVaultDailyLimitFree;
  static const int secretVaultDailyLimitVip =
      secret_vault_policy.secretVaultDailyLimitVip;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final StoragePickerService _pickerService = StoragePickerService();
  static bool _legacyImgBBKeyPurged = false;

  static const int maxGallerySelectionPerBatch =
      StoragePickerService.maxGallerySelectionPerBatch;
  static const int maxSecretVaultSelectionPerBatch =
      secret_vault_policy.maxSecretVaultSelectionPerBatch;
  static const int secretVaultPageSize =
      secret_vault_policy.secretVaultPageSize;
  static const Duration defaultDownloadCacheTtl = Duration(hours: 18);

  final StorageDeleteHelper _deleteHelper = const StorageDeleteHelper();
  final StorageDownloadCacheHelper _downloadCacheHelper =
      const StorageDownloadCacheHelper();
  final StorageFinalizeHelper _finalizeHelper = const StorageFinalizeHelper();
  final StorageAppCheckHelper _appCheckHelper = const StorageAppCheckHelper();
  final StorageManagedUploadHelper _managedUploadHelper =
      const StorageManagedUploadHelper();
  final StorageSignedUploadHelper _signedUploadHelper =
      const StorageSignedUploadHelper();
  final StorageUploadSessionHelper _uploadSessionHelper =
      const StorageUploadSessionHelper();
  final StorageRawUploadHelper _rawUploadHelper =
      const StorageRawUploadHelper();

  static bool get shouldIgnoreWebLifecyclePulse =>
      StorageWebPickerGuard.shouldIgnoreLifecyclePulse;

  static int clampImagePickLimit(
    int? requested, {
    int maxAllowed = maxGallerySelectionPerBatch,
  }) {
    return StoragePickerService.clampImagePickLimit(
      requested,
      maxAllowed: maxAllowed,
    );
  }

  Future<T> _callWithAppCheckRetry<T>(
    Future<T> Function() action, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) {
    return _appCheckHelper.callWithRetry(
      action,
      allowUnauthenticatedWithoutMarkers: allowUnauthenticatedWithoutMarkers,
    );
  }

  Future<XFile?> pickMusicFile() => _pickerService.pickMusicFile();

  bool isSupportedMusicFileName(String fileNameOrPath) {
    final extension = p.extension(fileNameOrPath).toLowerCase();
    return storageMusicPickerExtensions
        .contains(extension.replaceFirst('.', ''));
  }

  Future<XFile?> pickImage() => _pickerService.pickImage();

  Future<List<XFile>> pickImages({int? limit}) =>
      _pickerService.pickImages(limit: limit);

  Future<File?> getCachedNetworkFile(
    String url, {
    String namespace = 'downloads',
    String? cacheKey,
    Duration ttl = defaultDownloadCacheTtl,
    bool forceRefresh = false,
  }) {
    return _downloadCacheHelper.getCachedNetworkFile(
      url,
      namespace: namespace,
      cacheKey: cacheKey,
      ttl: ttl,
      forceRefresh: forceRefresh,
    );
  }

  Future<Uint8List?> downloadBytesWithCache(
    String url, {
    String namespace = 'downloads',
    String? cacheKey,
    Duration ttl = defaultDownloadCacheTtl,
    bool forceRefresh = false,
  }) {
    return _downloadCacheHelper.downloadBytesWithCache(
      url,
      namespace: namespace,
      cacheKey: cacheKey,
      ttl: ttl,
      forceRefresh: forceRefresh,
    );
  }

  Future<XFile?> snapPhoto() => _pickerService.snapPhoto();

  String detectContentType(
    String fileNameOrPath, {
    String fallback = 'application/octet-stream',
  }) {
    return detectStorageContentType(
      fileNameOrPath,
      fallback: fallback,
    );
  }

  void _rejectVideoUpload({
    required String storagePath,
    required String resolvedContentType,
    String? originalFileName,
  }) {
    rejectUnsupportedStorageVideoUpload(
      storagePath: storagePath,
      resolvedContentType: resolvedContentType,
      originalFileName: originalFileName,
    );
  }

  Future<void> _purgeLegacyImgBBKeyCache() async {
    if (_legacyImgBBKeyPurged) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('il_imgbb_api_key');
      _legacyImgBBKeyPurged = true;
    } catch (e) {
      debugPrint('Legacy ImgBB key purge failed: $e');
    }
  }

  String _normalizeStorageRefPath(String storagePath) =>
      normalizeStorageRefPath(storagePath);

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw Exception('Cần đăng nhập để tải tệp lên đám mây.');
    }
    return uid;
  }

  Future<User?> _resolveCallableUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return _auth.currentUser;
    }
  }

  Future<void> _requireCallableAuth(
    String message, {
    bool forceRefresh = false,
  }) async {
    final user = await _resolveCallableUser();
    final uid = user?.uid.trim() ?? '';
    if (user == null || uid.isEmpty) {
      throw Exception(message);
    }

    try {
      await user.getIdToken(forceRefresh);
    } on FirebaseAuthException {
      throw Exception(message);
    }
  }

  String _normalizeStorageWritePath(String storagePath) {
    return normalizeStorageWritePath(
      storagePath: storagePath,
      currentUid: _auth.currentUser?.uid.trim() ?? '',
    );
  }

  Map<String, String> _stringMapFromDynamicMap(Object? value) {
    if (value is! Map) {
      return <String, String>{};
    }

    final mapped = <String, String>{};
    value.forEach((key, item) {
      final normalizedKey = key?.toString().trim() ?? '';
      final normalizedValue = item?.toString().trim() ?? '';
      if (normalizedKey.isNotEmpty && normalizedValue.isNotEmpty) {
        mapped[normalizedKey] = normalizedValue;
      }
    });
    return mapped;
  }

  Future<Map<String, dynamic>> _createSecretVaultUploadSession({
    required String houseId,
    required String contentType,
    required String fileName,
  }) async {
    try {
      return _uploadSessionHelper.createUploadSession(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'createSecretVaultUploadSession',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'contentType': contentType.trim(),
          'fileName': fileName.trim(),
        },
        label: 'Secret Vault upload session',
      );
    } on FirebaseFunctionsException catch (error) {
      if (_appCheckHelper.isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: true,
      )) {
        throw Exception(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tạo phiên tải ảnh kho bí mật.',
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để tải ảnh kho bí mật.');
        case 'invalid-argument':
          throw Exception('Thiếu thông tin tải ảnh kho bí mật.');
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Secret Vault yêu cầu PRO đang hoạt động.',
          );
        case 'permission-denied':
          throw Exception('Bạn không có quyền tải ảnh vào kho bí mật này.');
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception(
            'Không thể kết nối máy chủ tạo phiên tải ảnh kho bí mật.',
          );
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể tạo phiên tải ảnh kho bí mật.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> _createChatImageUploadSession({
    required String houseId,
    required String scope,
    required String contentType,
    required String fileName,
    String? targetHouseId,
  }) async {
    try {
      return _uploadSessionHelper.createUploadSession(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'createChatImageUploadSession',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'scope': scope.trim(),
          'contentType': contentType.trim(),
          'fileName': fileName.trim(),
          if ((targetHouseId ?? '').trim().isNotEmpty)
            'targetHouseId': targetHouseId!.trim(),
        },
        label: 'Chat image upload session',
        requireSessionId: true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (_appCheckHelper.isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: true,
      )) {
        throw Exception(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tạo phiên gửi ảnh chat.',
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để gửi ảnh chat.');
        case 'invalid-argument':
          throw Exception('Thiếu thông tin gửi ảnh chat.');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy cuộc chat cần gửi ảnh.',
          );
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Đoạn chat này chưa sẵn sàng để gửi ảnh.',
          );
        case 'resource-exhausted':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Bạn đã dùng hết lượt gửi ảnh chat hôm nay.',
          );
        case 'permission-denied':
          throw Exception('Bạn không có quyền gửi ảnh vào cuộc chat này.');
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ gửi ảnh chat.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể tạo phiên gửi ảnh chat.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> _createMemoryImageUploadSession({
    required String houseId,
    required String contentType,
    required String fileName,
  }) async {
    try {
      return _uploadSessionHelper.createUploadSession(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'createMemoryImageUploadSession',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'contentType': contentType.trim(),
          'fileName': fileName.trim(),
        },
        label: 'Memory image upload session',
        requireSessionId: true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (_appCheckHelper.isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: true,
      )) {
        throw Exception(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tạo phiên tải ảnh Kỷ niệm.',
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để tải ảnh Kỷ niệm.');
        case 'invalid-argument':
          throw Exception('Thiếu thông tin tải ảnh Kỷ niệm.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền tải ảnh vào Kỷ niệm này.');
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception(
              'Không thể kết nối máy chủ tạo phiên tải ảnh Kỷ niệm.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể tạo phiên tải ảnh Kỷ niệm.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> _createAlbumImageUploadSession({
    required String houseId,
    required String contentType,
    required String fileName,
  }) async {
    try {
      return _uploadSessionHelper.createUploadSession(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'createAlbumImageUploadSession',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'contentType': contentType.trim(),
          'fileName': fileName.trim(),
        },
        label: 'Album image upload session',
        requireSessionId: true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (_appCheckHelper.isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: true,
      )) {
        throw Exception(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tạo phiên tải ảnh Album.',
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để tải ảnh Album.');
        case 'invalid-argument':
          throw Exception('Thiếu thông tin tải ảnh Album.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền tải ảnh vào Album này.');
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ tạo phiên tải ảnh Album.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể tạo phiên tải ảnh Album.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> _createGiftImageUploadSession({
    required String houseId,
    required String contentType,
    required String fileName,
  }) {
    return _uploadSessionHelper.createUploadSession(
      invokeCallable: (name, payload) =>
          _functions.httpsCallable(name).call(payload),
      functionName: 'createGiftImageUploadSession',
      payload: <String, dynamic>{
        'houseId': houseId.trim(),
        'contentType': contentType.trim(),
        'fileName': fileName.trim(),
      },
      label: 'Gift image upload session',
    );
  }

  Future<Map<String, dynamic>> _createLoveCardImageUploadSession({
    required String houseId,
    required String contentType,
    required String fileName,
  }) {
    return _uploadSessionHelper.createUploadSession(
      invokeCallable: (name, payload) =>
          _functions.httpsCallable(name).call(payload),
      functionName: 'createLoveCardImageUploadSession',
      payload: <String, dynamic>{
        'houseId': houseId.trim(),
        'contentType': contentType.trim(),
        'fileName': fileName.trim(),
      },
      label: 'Love card image upload session',
    );
  }

  Future<Map<String, dynamic>> _createPublicImageUploadSession({
    required String houseId,
    required String target,
    required String contentType,
    required String fileName,
  }) async {
    try {
      return _uploadSessionHelper.createUploadSession(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'createPublicImageUploadSession',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'target': target.trim(),
          'contentType': contentType.trim(),
          'fileName': fileName.trim(),
        },
        label: 'Public image upload session',
        requireSessionId: true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (_appCheckHelper.isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: true,
      )) {
        throw Exception(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tạo phiên tải ảnh công khai.',
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để tải ảnh công khai.');
        case 'invalid-argument':
          throw Exception('Thiếu thông tin tải ảnh công khai.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền tải ảnh công khai này.');
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception(
              'Không thể kết nối máy chủ tạo phiên tải ảnh công khai.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể tạo phiên tải ảnh công khai.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> finalizeAlbumImageUpload({
    required String houseId,
    required String sessionId,
    required String role,
    required String authorName,
    String caption = '',
    String thumbUrl = '',
    String type = 'image',
    String? blurHash,
  }) async {
    try {
      return _finalizeHelper.finalizeUpload(
        invokeCallable: (name, payload) =>
            _functions.httpsCallable(name).call(payload),
        functionName: 'finalizeAlbumImageUpload',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'sessionId': sessionId.trim(),
          'role': role.trim(),
          'authorName': authorName.trim(),
          'caption': caption.trim(),
          'thumbUrl': thumbUrl.trim(),
          'type': type.trim(),
          if (blurHash != null) 'blurHash': blurHash,
        },
        label: 'Album finalize response',
      );
    } on FirebaseFunctionsException catch (error) {
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để hoàn tất ảnh Album.');
        case 'invalid-argument':
          throw Exception('Thiếu thông tin hoàn tất ảnh Album.');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy phiên tải ảnh Album.',
          );
        case 'permission-denied':
          throw Exception('Bạn không có quyền hoàn tất ảnh Album này.');
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Ảnh Album chưa sẵn sàng để hoàn tất.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ hoàn tất ảnh Album.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể hoàn tất ảnh Album.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> finalizeMemoryImageUpload({
    required String houseId,
    required String sessionId,
    required String authorName,
    required String authorEmail,
    required String authorRole,
    double? lat,
    double? lng,
    String? blurHash,
  }) async {
    try {
      final response = await _finalizeHelper.finalizeUpload(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'finalizeMemoryImageUpload',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'sessionId': sessionId.trim(),
          'authorName': authorName.trim(),
          'authorEmail': authorEmail.trim(),
          'authorRole': authorRole.trim(),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (blurHash != null) 'blurHash': blurHash,
        },
        label: 'Memory finalize response',
      );
      
      final isOk = response['ok'] == true;
      final memoryId = response['memoryId']?.toString().trim() ?? '';
      if (isOk && memoryId.isNotEmpty) {
        debugPrint('✅ UPLOAD THÀNH CÔNG: Memory ID = $memoryId');
      }
      
      return response;
    } on FirebaseFunctionsException catch (error) {
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để hoàn tất ảnh Kỷ niệm.');
        case 'invalid-argument':
          throw Exception('Thiếu dữ liệu để hoàn tất ảnh Kỷ niệm.');
        case 'resource-exhausted':
          throw Exception('Bạn đã đạt giới hạn đăng ảnh Kỷ niệm hôm nay.');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy phiên tải ảnh Kỷ niệm.',
          );
        case 'permission-denied':
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Phiên tải ảnh Kỷ niệm không còn hợp lệ.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ hoàn tất ảnh Kỷ niệm.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể hoàn tất ảnh Kỷ niệm.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> moveMemoryImagesToTrash({
    required String houseId,
    required List<String> memoryIds,
  }) async {
    const authRequiredMessage = 'Cần đăng nhập để xóa ảnh Kỷ niệm.';
    final normalizedIds = memoryIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedIds.isEmpty) {
      throw Exception('Thiếu ảnh Kỷ niệm để xóa.');
    }

    Future<Map<String, dynamic>> callMoveToTrash() {
      return _finalizeHelper.invokeMapResult(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'moveMemoryImagesToTrash',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'memoryIds': normalizedIds,
        },
        invalidResponseMessage: 'Memory delete response is invalid.',
      );
    }

    try {
      await _requireCallableAuth(authRequiredMessage);
      return await callMoveToTrash();
    } on FirebaseFunctionsException catch (error) {
      var resolvedError = error;
      final currentUser = await _resolveCallableUser();
      if (resolvedError.code.trim().toLowerCase() == 'unauthenticated' &&
          currentUser != null) {
        await _requireCallableAuth(authRequiredMessage, forceRefresh: true);
        try {
          return await callMoveToTrash();
        } on FirebaseFunctionsException catch (retryError) {
          resolvedError = retryError;
        }
      }
      switch (resolvedError.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để xóa ảnh Kỷ niệm.');
        case 'invalid-argument':
          throw Exception('Thiếu dữ liệu để xóa ảnh Kỷ niệm.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền xóa ảnh Kỷ niệm này.');
        case 'not-found':
          throw Exception(
            (resolvedError.message ?? '').trim().isNotEmpty
                ? resolvedError.message!.trim()
                : 'Không tìm thấy ảnh Kỷ niệm cần xóa.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ để xóa ảnh Kỷ niệm.');
        default:
          throw Exception(
            (resolvedError.message ?? '').trim().isNotEmpty
                ? resolvedError.message!.trim()
                : 'Không thể xóa ảnh Kỷ niệm.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> restoreMemoryImageFromTrash({
    required String houseId,
    required String memoryId,
  }) async {
    try {
      return await _finalizeHelper.invokeMapResult(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'restoreMemoryImageFromTrash',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'memoryId': memoryId.trim(),
        },
        invalidResponseMessage: 'Memory restore response is invalid.',
      );
    } on FirebaseFunctionsException catch (error) {
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để khôi phục ảnh Kỷ niệm.');
        case 'invalid-argument':
          throw Exception('Thiếu dữ liệu để khôi phục ảnh Kỷ niệm.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền khôi phục ảnh Kỷ niệm này.');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy ảnh Kỷ niệm trong thùng rác.',
          );
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Ảnh Kỷ niệm đã quá hạn khôi phục.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception(
              'Không thể kết nối máy chủ để khôi phục ảnh Kỷ niệm.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể khôi phục ảnh Kỷ niệm.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> cleanupExpiredMemoryImagesTrash({
    required String houseId,
  }) async {
    try {
      return await _finalizeHelper.invokeMapResult(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'cleanupExpiredMemoryImagesTrash',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
        },
        invalidResponseMessage: 'Memory trash cleanup response is invalid.',
      );
    } on FirebaseFunctionsException catch (error) {
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để dọn thùng rác Kỷ niệm.');
        case 'invalid-argument':
          throw Exception('Thiếu dữ liệu để dọn thùng rác Kỷ niệm.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền dọn thùng rác Kỷ niệm.');
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception(
              'Không thể kết nối máy chủ để dọn thùng rác Kỷ niệm.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể dọn thùng rác Kỷ niệm.',
          );
      }
    }
  }

  Future<void> cleanupExpiredMemoryTrashIfNeeded(String? houseId) async {
    final normalizedHouseId = houseId?.trim() ?? '';
    if (normalizedHouseId.isEmpty || _auth.currentUser == null) {
      return;
    }

    try {
      await cleanupExpiredMemoryImagesTrash(houseId: normalizedHouseId);
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('unauthenticated')) {
        return;
      }
      debugPrint('Cleanup expired memory trash failed: $e');
    }
  }

  Future<Map<String, dynamic>> finalizePublicImageUpload({
    required String houseId,
    required String sessionId,
    required String target,
    String role = '',
    String authorName = '',
    String authorEmail = '',
    String authorRole = '',
    String houseName = '',
    String authorAvt = '',
    String content = '',
    String privacy = 'public',
    String mood = '',
    String moodEmoji = '',
    String location = '',
    String postType = 'mood',
    bool isAnon = false,
    bool isLocket = false,
    bool commentsEnabled = true,
    bool flagged = false,
    String? blurHash,
  }) async {
    try {
      return _finalizeHelper.finalizeUpload(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'finalizePublicImageUpload',
        payload: <String, dynamic>{
          'houseId': houseId.trim(),
          'sessionId': sessionId.trim(),
          'target': target.trim(),
          if (role.trim().isNotEmpty) 'role': role.trim(),
          if (authorName.trim().isNotEmpty) 'authorName': authorName.trim(),
          if (authorEmail.trim().isNotEmpty) 'authorEmail': authorEmail.trim(),
          if (authorRole.trim().isNotEmpty) 'authorRole': authorRole.trim(),
          if (houseName.trim().isNotEmpty) 'houseName': houseName.trim(),
          if (authorAvt.trim().isNotEmpty) 'authorAvt': authorAvt.trim(),
          if (content.trim().isNotEmpty) 'content': content.trim(),
          'privacy': privacy.trim(),
          if (mood.trim().isNotEmpty) 'mood': mood.trim(),
          if (moodEmoji.trim().isNotEmpty) 'moodEmoji': moodEmoji.trim(),
          if (location.trim().isNotEmpty) 'location': location.trim(),
          if (postType.trim().isNotEmpty) 'postType': postType.trim(),
          'isAnon': isAnon,
          'isLocket': isLocket,
          'commentsEnabled': commentsEnabled,
          'flagged': flagged,
          if (blurHash != null) 'blurHash': blurHash,
        },
        label: 'Public image finalize response',
      );
    } on FirebaseFunctionsException catch (error) {
      if (_appCheckHelper.isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: true,
      )) {
        throw Exception(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể hoàn tất ảnh công khai.',
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw Exception('Cần đăng nhập để hoàn tất ảnh công khai.');
        case 'invalid-argument':
          throw Exception('Thiếu dữ liệu để hoàn tất ảnh công khai.');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy phiên tải ảnh công khai.',
          );
        case 'permission-denied':
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Phiên tải ảnh công khai không còn hợp lệ.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw Exception('Không thể kết nối máy chủ hoàn tất ảnh công khai.');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể hoàn tất ảnh công khai.',
          );
      }
    }
  }

  Future<void> _uploadBytesToSignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required Map<String, String> headers,
  }) async {
    final response = await http
        .put(
          Uri.parse(uploadUrl),
          headers: headers,
          body: bytes,
        )
        .timeout(const Duration(minutes: 2));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Máy chủ lưu trữ từ chối ảnh kho bí mật (${response.statusCode}).',
      );
    }
  }

  Future<String> uploadFileToPath(
    String storagePath,
    XFile file, {
    String? contentType,
  }) {
    final safeStoragePath = _normalizeStorageWritePath(storagePath);
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    final resolvedContentType = contentType ??
        detectContentType(
          originalFileName.isNotEmpty ? originalFileName : storagePath,
          fallback: 'application/octet-stream',
        );
    return _rawUploadHelper.uploadFileToPath(
      storagePath: safeStoragePath,
      file: file,
      resolvedContentType: resolvedContentType,
      rejectVideoUpload: _rejectVideoUpload,
      purgeLegacyCache: _purgeLegacyImgBBKeyCache,
      buildStorageRef: (path) => _storage.ref().child(path),
    );
  }

  Future<String> uploadMusicFileToPath(
    String storagePath,
    XFile file, {
    String? contentType,
  }) {
    final safeStoragePath = _normalizeStorageWritePath(storagePath);
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    final sourceName =
        originalFileName.isNotEmpty ? originalFileName : storagePath;
    final resolvedContentType = contentType ??
        detectContentType(
          sourceName,
          fallback: 'application/octet-stream',
        );
    return _rawUploadHelper.uploadMusicFileToPath(
      storagePath: safeStoragePath,
      file: file,
      resolvedContentType: resolvedContentType,
      isSupportedMusicFileName: isSupportedMusicFileName,
      purgeLegacyCache: _purgeLegacyImgBBKeyCache,
      buildStorageRef: (path) => _storage.ref().child(path),
    );
  }

  Future<String> saveMusicFileLocally(XFile file) {
    return _rawUploadHelper.saveMusicFileLocally(
      file: file,
      isSupportedMusicFileName: isSupportedMusicFileName,
    );
  }

  Future<String> uploadBytesToPath(
    String storagePath,
    Uint8List fileBytes, {
    String? contentType,
    String? originalFileName,
  }) {
    final safeStoragePath = _normalizeStorageWritePath(storagePath);
    final resolvedContentType = contentType ??
        detectContentType(
          originalFileName ?? storagePath,
          fallback: 'application/octet-stream',
        );
    return _rawUploadHelper.uploadBytesToPath(
      storagePath: safeStoragePath,
      fileBytes: fileBytes,
      resolvedContentType: resolvedContentType,
      originalFileName: originalFileName ?? storagePath,
      rejectVideoUpload: _rejectVideoUpload,
      purgeLegacyCache: _purgeLegacyImgBBKeyCache,
      buildStorageRef: (path) => _storage.ref().child(path),
    );
  }

  Future<StorageUploadResult?> uploadManagedImage(
    String houseId,
    String folderName,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 70,
  }) {
    return _managedUploadHelper.uploadManagedImage(
      request: StorageManagedUploadRequest(
        houseId: houseId,
        folderName: folderName,
        file: file,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      ),
      requireCurrentUid: _requireCurrentUid,
      detectContentType: detectContentType,
      normalizeStorageWritePath: _normalizeStorageWritePath,
      uploadFileToPath: uploadFileToPath,
    );
  }

  Future<String?> uploadImage(
    String houseId,
    String folderName,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) async {
    final result = await uploadManagedImage(
      houseId,
      folderName,
      file,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
    );
    return result?.downloadUrl;
  }

  Future<StorageUploadResult?> uploadPublicImage(
    String houseId,
    String target,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createPublicImageUploadSession(
        houseId: houseId,
        target: target,
        contentType: contentType,
        fileName: preferredFileName,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_public',
      errorLabel: 'Public image',
      mapResult: mapPublicStorageUploadResult,
      errorMessage: 'Không thể tải ảnh công khai lên máy chủ.',
    );
  }

  Future<StorageUploadResult?> uploadChatImage(
    String houseId,
    XFile file, {
    required bool isInternal,
    String? targetHouseId,
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createChatImageUploadSession(
        houseId: houseId,
        scope: isInternal ? 'internal' : 'direct',
        contentType: contentType,
        fileName: preferredFileName,
        targetHouseId: isInternal ? null : targetHouseId,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_chat',
      errorLabel: 'Chat image',
      mapResult: mapChatStorageUploadResult,
      errorMessage: 'Không thể tải ảnh chat lên máy chủ.',
    );
  }

  Future<StorageUploadResult?> uploadMemoryImage(
    String houseId,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createMemoryImageUploadSession(
        houseId: houseId,
        contentType: contentType,
        fileName: preferredFileName,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_memory',
      errorLabel: 'Memory image',
      mapResult: mapBasicStorageUploadResult,
      errorMessage: 'Lỗi tải ảnh đám mây.',
    );
  }

  Future<StorageUploadResult?> uploadAlbumImage(
    String houseId,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createAlbumImageUploadSession(
        houseId: houseId,
        contentType: contentType,
        fileName: preferredFileName,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_album',
      errorLabel: 'Album image',
      mapResult: mapBasicStorageUploadResult,
      errorMessage: 'Không thể tải ảnh Album lên đám mây.',
    );
  }

  Future<StorageUploadResult?> uploadGiftImage(
    String houseId,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) async {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createGiftImageUploadSession(
        houseId: houseId,
        contentType: contentType,
        fileName: preferredFileName,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_gift',
      errorLabel: 'Gift image',
      mapResult: mapBasicStorageUploadResult,
      errorMessage: 'Không thể tải ảnh quà tặng lên đám mây.',
    );
  }

  Future<StorageUploadResult?> uploadLoveCardImage(
    String houseId,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) async {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createLoveCardImageUploadSession(
        houseId: houseId,
        contentType: contentType,
        fileName: preferredFileName,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_love_card',
      errorLabel: 'Love card image',
      mapResult: mapBasicStorageUploadResult,
      errorMessage: 'Không thể tải ảnh love card lên đám mây.',
    );
  }

  Future<StorageUploadResult?> _uploadSignedImageWithCompression({
    required XFile file,
    required Future<Map<String, dynamic>> Function(
      String contentType,
      String preferredFileName,
    ) sessionBuilder,
    required int minWidth,
    required int minHeight,
    required int quality,
    required String tempPrefix,
    required String errorLabel,
    required StorageUploadResult Function(Map<String, dynamic> session)
        mapResult,
    required String errorMessage,
  }) {
    return _signedUploadHelper.uploadSignedImageWithCompression(
      request: StorageSignedUploadRequest(
        file: file,
        sessionBuilder: sessionBuilder,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        tempPrefix: tempPrefix,
        errorLabel: errorLabel,
        errorMessage: errorMessage,
        mapResult: mapResult,
      ),
      requireCurrentUid: _requireCurrentUid,
      detectContentType: detectContentType,
      stringMapFromDynamicMap: _stringMapFromDynamicMap,
      uploadBytesToSignedUrl: _uploadBytesToSignedUrl,
    );
  }

  Future<StorageUploadResult?> uploadSecretVaultImage(
    String houseId,
    XFile file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 75,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName) =>
          _createSecretVaultUploadSession(
        houseId: houseId,
        contentType: contentType,
        fileName: preferredFileName,
      ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_vault',
      errorLabel: 'Secret vault image',
      mapResult: mapSecretVaultStorageUploadResult,
      errorMessage: 'Không thể tải ảnh lên kho bí mật.',
    );
  }

  String? extractStoragePathFromUrl(String url) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return null;
    }

    if (uri.scheme.toLowerCase() == 'gs') {
      final normalizedPath = _normalizeStorageRefPath(uri.path);
      return normalizedPath.isEmpty ? null : normalizedPath;
    }

    final pathSegments = uri.pathSegments;
    final objectSegmentIndex = pathSegments.indexOf('o');
    if (objectSegmentIndex >= 0 &&
        objectSegmentIndex + 1 < pathSegments.length) {
      final encodedPath =
          pathSegments.sublist(objectSegmentIndex + 1).join('/');
      final normalizedPath = _normalizeStorageRefPath(
        Uri.decodeComponent(encodedPath),
      );
      if (normalizedPath.isNotEmpty) {
        return normalizedPath;
      }
    }

    final queryName = uri.queryParameters['name']?.trim() ?? '';
    if (queryName.isNotEmpty) {
      final normalizedPath = _normalizeStorageRefPath(
        Uri.decodeComponent(queryName),
      );
      if (normalizedPath.isNotEmpty) {
        return normalizedPath;
      }
    }

    return null;
  }

  Future<bool> deleteFileByPath(String storagePath) {
    return _deleteHelper.deleteFileByPath(
      storage: _storage,
      storagePath: storagePath,
      normalizeStorageRefPath: _normalizeStorageRefPath,
    );
  }

  Future<bool> deleteLocalFile(String path) {
    return _deleteHelper.deleteLocalFile(path);
  }

  Future<bool> deleteImageByUrl(String url) {
    return _deleteHelper.deleteImageByUrl(
      storage: _storage,
      url: url,
    );
  }
}
