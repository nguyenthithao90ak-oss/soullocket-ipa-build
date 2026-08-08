import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'cloudflare_r2_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/secret_vault_media_policy.dart'
    as secret_vault_policy;
import 'package:soullocket_app/utils/services/storage/storage_app_check_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_content_policy.dart';
import 'package:soullocket_app/utils/services/storage/storage_delete_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_finalize_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_managed_upload_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_media_constants.dart';
import 'package:soullocket_app/utils/services/storage/storage_path_policy.dart';
import 'package:soullocket_app/utils/services/storage/storage_picker_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_raw_upload_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_result.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_session_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_result_mapper.dart';
import 'package:soullocket_app/utils/services/storage/storage_web_picker_guard.dart';

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
  static const int secretVaultTotalCap =
      secret_vault_policy.secretVaultTotalCap;

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

  Future<List<XFile>> pickImages({int? limit}) =>
      _pickerService.pickImages(limit: limit);

  Future<List<XFile>> pickMedia({int? limit}) =>
      _pickerService.pickMedia(limit: limit);

  Future<List<XFile>> pickMultipleMusicFiles({int maxFiles = 5}) =>
      _pickerService.pickMultipleMusicFiles(maxFiles: maxFiles);

  bool isSupportedMusicFileName(String fileNameOrPath) {
    final extension = p.extension(fileNameOrPath).toLowerCase();
    return storageMusicPickerExtensions
        .contains(extension.replaceFirst('.', ''));
  }

  Future<XFile?> pickImage() => _pickerService.pickImage();

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

  Future<void> purgeStaleCache(
      {Duration staleThreshold = const Duration(days: 3)}) {
    return _downloadCacheHelper.purgeStaleCache(staleThreshold: staleThreshold);
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
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      await prefs.remove('il_imgbb_api_key');
      _legacyImgBBKeyPurged = true;
    } catch (e) {
      debugPrint('Legacy ImgBB key purge failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể dọn khóa ImgBB cũ.',
      ).message}');
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
          .timeout(const Duration(seconds: 6));
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
          final message = (error.message ?? '').trim();
          throw Exception(
            Platform.isIOS || Platform.isMacOS
                ? 'Kho ảnh mật chưa sẵn sàng trên thiết bị này.'
                : message.isNotEmpty
                    ? message
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
      final errorText = AppErrorMapper.cleanMessage(e).toLowerCase();
      // Bỏ qua lỗi mạng / App Check / session — bình thường khi offline hoặc debug token chưa đăng ký
      if (errorText.contains('unauthenticated') ||
          errorText.contains('internal') ||
          errorText.contains('app check') ||
          errorText.contains('too many attempts') ||
          errorText.contains('unavailable')) {
        return;
      }
      debugPrint('Cleanup expired memory trash failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể dọn thùng rác Kỷ niệm hết hạn.',
      ).message}');
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

  Future<Map<String, dynamic>> finalizeCollageUpload({
    required String houseId,
    required String sessionId,
    String template = '',
    String style = '',
    String caption = '',
  }) {
    return _finalizeHelper.finalizeUpload(
      invokeCallable: (name, payload) => _callWithAppCheckRetry(
        () => _functions.httpsCallable(name).call(payload),
        allowUnauthenticatedWithoutMarkers: true,
      ),
      functionName: 'finalizeCollageUpload',
      payload: <String, dynamic>{
        'houseId': houseId.trim(),
        'sessionId': sessionId.trim(),
        if (template.trim().isNotEmpty) 'template': template.trim(),
        if (style.trim().isNotEmpty) 'style': style.trim(),
        if (caption.trim().isNotEmpty) 'caption': caption.trim(),
      },
      label: 'Collage finalize response',
    );
  }

  Future<String> uploadFileToPath(
    String storagePath,
    XFile file, {
    String? contentType,
    ValueChanged<double>? onProgress,
  }) async {
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
      onProgress: onProgress,
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
      // buildStorageRef removed — R2 không dùng ref
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
      // buildStorageRef removed — R2 không dùng ref
    );
  }

  Future<Map<String, dynamic>> uploadCollageBytes({
    required String houseId,
    required Uint8List bytes,
    required String fileName,
    String template = '',
    String style = '',
    String caption = '',
  }) async {
    _requireCurrentUid();
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const ext = '.png';
      final currentUid = _requireCurrentUid();
      final path = 'uploads/$currentUid/collage/$nowMs$ext';
      final normalizedStoragePath = _normalizeStorageWritePath(path);

      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'collage_${nowMs}_$fileName');
      final tempFile = File(tempPath);
      try {
        await tempFile.writeAsBytes(bytes, flush: true);
        CloudflareR2Service.instance.init();
        final r2Url = await CloudflareR2Service.instance.uploadFile(
          tempFile,
          folderPath: 'uploads/$currentUid/collage',
        );
        if (r2Url == null || r2Url.isEmpty) {
          throw Exception('R2 upload thất bại.');
        }
        return <String, dynamic>{
          'downloadUrl': r2Url,
          'storagePath': normalizedStoragePath,
        };
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    } catch (e) {
      debugPrint('Collage R2 upload error: $e');
      throw Exception('Không thể tải ảnh ghép lên đám mây.');
    }
  }

  Future<StorageUploadResult?> uploadManagedImage(
    String houseId,
    String folderName,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
    ValueChanged<double>? onProgress,
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
      onProgress: onProgress,
    );
  }

  Future<String?> uploadImage(
    String houseId,
    String folderName,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
    ValueChanged<double>? onProgress,
  }) async {
    final result = await uploadManagedImage(
      houseId,
      folderName,
      file,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      onProgress: onProgress,
    );
    return result?.downloadUrl;
  }

  Future<StorageUploadResult?> uploadPublicImage(
    String houseId,
    String target,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
    ValueChanged<double>? onProgress,
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
      onProgress: onProgress,
    );
  }

  Future<StorageUploadResult?> uploadChatImage(
    String houseId,
    XFile file, {
    required bool isInternal,
    String? targetHouseId,
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
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
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
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
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
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
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
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
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
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

  /// Upload ảnh trực tiếp lên R2 thay vì dùng Signed URL (Cloud Function).
  /// Dùng cho tất cả các loại ảnh: public, chat, memory, album, gift, love card, secret vault.
  Future<StorageUploadResult?> _uploadDirectToR2({
    required XFile file,
    required String folderName,
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final originalFileName = file.name.isNotEmpty ? file.name : file.path;
      String fileExtension = p.extension(originalFileName).toLowerCase();
      XFile uploadFile = file;
      String? tempCompressedPath;

      final contentType = detectContentType(originalFileName);
      final isImage = contentType.startsWith('image/');

      if (!kIsWeb && file.path.isNotEmpty && isImage && fileExtension != '.gif') {
        try {
          if (onProgress != null) onProgress(0.05);
          final tempDir = await getTemporaryDirectory();
          tempCompressedPath = p.join(
            tempDir.path,
            'r2_${nowMs}_${DateTime.now().microsecondsSinceEpoch}.webp',
          );
          if (onProgress != null) onProgress(0.1);
          final targetWidth = minWidth < 1080 ? 1080 : minWidth;
          final targetHeight = minHeight < 1920 ? 1920 : minHeight;
          final targetQuality = quality < 70 ? 70 : quality;

          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            file.path,
            tempCompressedPath,
            minWidth: targetWidth,
            minHeight: targetHeight,
            quality: targetQuality,
            format: CompressFormat.webp,
          );
          if (onProgress != null) onProgress(0.35);
          if (compressedFile != null) {
            uploadFile = compressedFile;
            fileExtension = '.webp';
          } else {
            tempCompressedPath = null;
          }
        } catch (_) {
          tempCompressedPath = null;
        }
      }

      if (fileExtension.isEmpty) {
        fileExtension = p.extension(uploadFile.name).toLowerCase();
      }
      if (fileExtension.isEmpty) {
        fileExtension = '.jpg';
      }

      final currentUid = _requireCurrentUid();
      final path = 'uploads/$currentUid/$folderName/$nowMs$fileExtension';
      final normalizedStoragePath = _normalizeStorageWritePath(path);

      if (onProgress != null) onProgress(0.4);

      final finalContentType = detectContentType(path);

      try {
        final downloadUrl = _rawUploadHelper.uploadFileToPath(
          storagePath: path,
          file: uploadFile,
          resolvedContentType: finalContentType,
          rejectVideoUpload: _rejectVideoUpload,
          purgeLegacyCache: _purgeLegacyImgBBKeyCache,
          onProgress:
              onProgress != null ? (p) => onProgress(0.4 + (p * 0.6)) : null,
        );

        final url = await downloadUrl;
        if (onProgress != null) onProgress(1.0);

        return StorageUploadResult(
          downloadUrl: url,
          storagePath: normalizedStoragePath,
        );
      } finally {
        if (tempCompressedPath != null) {
          final f = File(tempCompressedPath);
          if (await f.exists()) await f.delete();
        }
      }
    } catch (e) {
      debugPrint('R2 upload error ($folderName): $e');
      throw 'Không thể tải ảnh lên đám mây, vui lòng kiểm tra kết nối mạng.';
    }
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
    ValueChanged<double>? onProgress,
  }) {
    // CHUYỂN SANG R2: bỏ qua Signed URL, upload trực tiếp qua R2
    return _uploadDirectToR2(
      file: file,
      folderName: tempPrefix,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      onProgress: onProgress,
    );
  }

  Future<StorageUploadResult?> uploadSecretVaultImage(
    String houseId,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
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

  Future<bool> deleteFileByPath(String storagePath) async {
    final normalizedPath = storagePath.trim();
    if (normalizedPath.isEmpty) return true;
    try {
      CloudflareR2Service.instance.init();
      return await CloudflareR2Service.instance.deleteByPath(normalizedPath);
    } catch (e) {
      debugPrint('deleteFileByPath error: $e');
      return false;
    }
  }

  Future<bool> deleteLocalFile(String path) {
    return _deleteHelper.deleteLocalFile(path);
  }

  Future<bool> deleteImageByUrl(String url) {
    return _deleteHelper.deleteImageByUrl(url: url);
  }
}
