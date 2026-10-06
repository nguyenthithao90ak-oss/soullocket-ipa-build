import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/storage/private_memory_lifecycle_policy.dart';
import 'package:soullocket_app/utils/services/storage/private_memory_download_helper.dart';
import 'package:soullocket_app/utils/services/private_media_url_service.dart';
import 'cloudflare_r2_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/secret_vault_media_policy.dart'
    as secret_vault_policy;
import 'package:soullocket_app/utils/services/storage/storage_app_check_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_content_policy.dart';
import 'package:soullocket_app/utils/services/storage/storage_delete_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_finalize_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_image_upload_input.dart';
import 'package:soullocket_app/utils/services/storage/storage_managed_upload_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_media_constants.dart';
import 'package:soullocket_app/utils/services/storage/storage_path_policy.dart';
import 'package:soullocket_app/utils/services/storage/private_r2_put.dart';
import 'package:soullocket_app/utils/services/storage/storage_picker_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_raw_upload_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_result.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_session_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_result_mapper.dart';
import 'package:soullocket_app/utils/services/storage/storage_web_picker_guard.dart';
import 'package:soullocket_app/utils/services/storage/storage_private_memory_upload_helper.dart';

class StorageService {
  StorageService();

  static int _uploadSequence = 0;

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
    return storageMusicPickerExtensions.contains(
      extension.replaceFirst('.', ''),
    );
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

  Future<({Uint8List bytes, String url})> downloadPrivateMemory({
    required String houseId,
    required String memoryId,
    required bool Function() scopeIsCurrent,
  }) async {
    final client = http.Client();
    final urlService = PrivateMediaUrlService();
    try {
      return await const PrivateMemoryDownloadHelper().download(
        resolve: () => urlService.resolve(
          houseId: houseId,
          mediaId: memoryId,
          kind: 'memory_image',
        ),
        client: client,
        currentUid: () => _auth.currentUser?.uid,
        authChanges: _auth.authStateChanges().map((user) => user?.uid),
        scopeIsCurrent: scopeIsCurrent,
      );
    } finally {
      urlService.dispose();
      client.close();
    }
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

  Future<void> purgeStaleCache({
    Duration staleThreshold = StorageDownloadCacheHelper.diskRetention,
  }) {
    return _downloadCacheHelper.purgeStaleCache(staleThreshold: staleThreshold);
  }

  Future<XFile?> snapPhoto() => _pickerService.snapPhoto();

  String detectContentType(
    String fileNameOrPath, {
    String fallback = 'application/octet-stream',
  }) {
    return detectStorageContentType(fileNameOrPath, fallback: fallback);
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
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      await prefs.remove('il_imgbb_api_key');
      _legacyImgBBKeyPurged = true;
    } catch (e) {
      debugPrint(
        'Legacy ImgBB key purge failed: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể dọn khóa ImgBB cũ.').message}',
      );
    }
  }

  String _normalizeStorageRefPath(String storagePath) =>
      normalizeStorageRefPath(storagePath);

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw UiCopyException('copy_0d17dba25af1');
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
          throw UiCopyException('copy_3b1a55a37917');
        case 'invalid-argument':
          throw UiCopyException('copy_6561892964ac');
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
          throw UiCopyException('copy_8a24722de890');
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_87c69d5f9627');
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
          throw UiCopyException('copy_b44a30bfef88');
        case 'invalid-argument':
          throw UiCopyException('copy_1a801c2953b4');
        case 'permission-denied':
          throw UiCopyException('copy_dd37c52a99a6');
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_dd8932601953');
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
          throw UiCopyException('copy_f7bbe23f6145');
        case 'invalid-argument':
          throw UiCopyException('copy_07b57ae1291a');
        case 'permission-denied':
          throw UiCopyException('copy_0a0e82c2da65');
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_98cbed0ef403');
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
    int? fileSize,
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
          'fileSize': ?fileSize,
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
          throw UiCopyException('copy_3e75f7405247');
        case 'invalid-argument':
          throw UiCopyException('copy_c62167c0e18b');
        case 'permission-denied':
          throw UiCopyException('copy_89a73767f9fc');
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_f8b58a3bc941');
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
          throw UiCopyException('copy_90a477ac6e83');
        case 'invalid-argument':
          throw UiCopyException('copy_c6d946b85ebe');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không tìm thấy phiên tải ảnh Album.',
          );
        case 'permission-denied':
          throw UiCopyException('copy_6c6006ba38ea');
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Ảnh Album chưa sẵn sàng để hoàn tất.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_67d933ac8ea6');
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
          throw UiCopyException('copy_e51f8753446e');
        case 'invalid-argument':
          throw UiCopyException('copy_7d96fae4af62');
        case 'resource-exhausted':
          throw UiCopyException('copy_5470f87bf0a1');
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
          throw UiCopyException('copy_4efcae934e53');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : 'Không thể hoàn tất ảnh Kỷ niệm.',
          );
      }
    }
  }

  Future<Map<String, dynamic>> _invokePrivateMemoryAction(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
    }
    var scopeChanged = false;
    final subscription = _auth.authStateChanges().listen((user) {
      if (user?.uid != uid) scopeChanged = true;
    });
    void checkScope() {
      if (scopeChanged || _auth.currentUser?.uid != uid) {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
      }
    }

    try {
      // Payload và operationId giữ nguyên qua retry App Check; không gọi
      // server của phiên mới nếu người dùng đổi tài khoản giữa thao tác.
      final result = await _finalizeHelper.invokeMapResult(
        invokeCallable: (functionName, data) => _callWithAppCheckRetry(() {
          checkScope();
          return _functions
              .httpsCallable(
                functionName,
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 120),
                ),
              )
              .call(data);
        }),
        functionName: name,
        payload: payload,
        invalidResponseMessage: 'Invalid private media response.',
      );
      checkScope();
      return result;
    } finally {
      await subscription.cancel();
    }
  }

  Future<Map<String, dynamic>> moveMemoryImagesToTrash({
    required String houseId,
    required List<String> memoryIds,
  }) async {
    if (AppConfig.privateMemoryUploadEnabled ||
        memoryIds.any(PrivateMemoryLifecyclePolicy.isPrivateId)) {
      return _invokePrivateMemoryAction('trashPrivateMemories', {
        'houseId': houseId.trim(),
        'memoryIds': memoryIds.map((id) => id.trim()).toSet().toList(),
        'operationId': PrivateMemoryLifecyclePolicy.newOperationId(),
        'operationCreatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    const authRequiredMessage = 'Cần đăng nhập để xóa ảnh Kỷ niệm.';
    final normalizedIds = memoryIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedIds.isEmpty) {
      throw UiCopyException('copy_5128b4443dbd');
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
          throw UiCopyException('copy_34e1b3d650e7');
        case 'invalid-argument':
          throw UiCopyException('copy_2f7fb878a0de');
        case 'permission-denied':
          throw UiCopyException('copy_febe3f9cb924');
        case 'not-found':
          throw Exception(
            (resolvedError.message ?? '').trim().isNotEmpty
                ? resolvedError.message!.trim()
                : 'Không tìm thấy ảnh Kỷ niệm cần xóa.',
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_8f44baa3f6f7');
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
    if (AppConfig.privateMemoryUploadEnabled ||
        PrivateMemoryLifecyclePolicy.isPrivateId(memoryId)) {
      return _invokePrivateMemoryAction('restorePrivateMemory', {
        'houseId': houseId.trim(),
        'memoryId': memoryId.trim(),
        'operationId': PrivateMemoryLifecyclePolicy.newOperationId(),
        'operationCreatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
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
          throw UiCopyException('copy_d4788b9ad5cb');
        case 'invalid-argument':
          throw UiCopyException('copy_342a1ad34a6a');
        case 'permission-denied':
          throw UiCopyException('copy_fffaee0b9efd');
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
          throw UiCopyException('copy_f077e76c9760');
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
    if (AppConfig.privateMemoryUploadEnabled) {
      return _invokePrivateMemoryAction('cleanupPrivateMemoryTrash', {
        'houseId': houseId.trim(),
      });
    }
    try {
      return await _finalizeHelper.invokeMapResult(
        invokeCallable: (name, payload) => _callWithAppCheckRetry(
          () => _functions.httpsCallable(name).call(payload),
          allowUnauthenticatedWithoutMarkers: true,
        ),
        functionName: 'cleanupExpiredMemoryImagesTrash',
        payload: <String, dynamic>{'houseId': houseId.trim()},
        invalidResponseMessage: 'Memory trash cleanup response is invalid.',
      );
    } on FirebaseFunctionsException catch (error) {
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw UiCopyException('copy_66a39337300e');
        case 'invalid-argument':
          throw UiCopyException('copy_7b3f71abbf6b');
        case 'permission-denied':
          throw UiCopyException('copy_e52c27bcd89e');
        case 'deadline-exceeded':
        case 'unavailable':
          throw UiCopyException('copy_ba3af1f1f4ce');
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
      debugPrint(
        'Cleanup expired memory trash failed: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể dọn thùng rác Kỷ niệm hết hạn.').message}',
      );
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
          throw UiCopyException('copy_d63f7c5741da');
        case 'invalid-argument':
          throw UiCopyException('copy_cd208658eecf');
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
          throw UiCopyException('copy_56d7893f7c4e');
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

  Future<StorageUploadResult> uploadFileToPath(
    String storagePath,
    XFile file, {
    String? contentType,
    ValueChanged<double>? onProgress,
  }) async {
    final safeStoragePath = _normalizeStorageWritePath(storagePath);
    final originalFileName = file.name.isNotEmpty ? file.name : file.path;
    final resolvedContentType =
        contentType ??
        detectContentType(
          originalFileName.isNotEmpty ? originalFileName : storagePath,
          fallback: 'application/octet-stream',
        );
    return _rawUploadHelper.uploadFileResult(
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
    final sourceName = originalFileName.isNotEmpty
        ? originalFileName
        : storagePath;
    final resolvedContentType =
        contentType ??
        detectContentType(sourceName, fallback: 'application/octet-stream');
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
    final resolvedContentType =
        contentType ??
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
      final currentUid = _requireCurrentUid();
      final path =
          'uploads/$currentUid/collage/${DateTime.now().microsecondsSinceEpoch}_${_uploadSequence++}.png';
      final normalizedStoragePath = _normalizeStorageWritePath(path);
      final result = await _rawUploadHelper.uploadFileResult(
        storagePath: normalizedStoragePath,
        file: XFile.fromData(bytes, name: 'collage.png', mimeType: 'image/png'),
        resolvedContentType: 'image/png',
        rejectVideoUpload: _rejectVideoUpload,
        purgeLegacyCache: _purgeLegacyImgBBKeyCache,
      );
      return <String, dynamic>{
        'downloadUrl': result.downloadUrl,
        'storagePath': result.storagePath,
      };
    } catch (e) {
      debugPrint('Collage R2 upload error: $e');
      throw UiCopyException('copy_97d441d22938');
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
    String role = '',
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
    ValueChanged<double>? onProgress,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName, _, _) async =>
          _createPublicImageUploadSession(
            houseId: houseId,
            target: target,
            contentType: contentType,
            fileName: preferredFileName,
            fileSize: target == 'custom_mood_sticker'
                ? await file.length()
                : null,
          ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_public',
      errorLabel: 'Public image',
      mapResult: mapPublicStorageUploadResult,
      finalizeSession:
          const {
            'home_avatar',
            'house_avatar',
            'profile_header',
            'soul_merge',
            'custom_mood_sticker',
          }.contains(target)
          ? (session) async {
              final result = await finalizePublicImageUpload(
                houseId: houseId,
                sessionId: session['sessionId']?.toString() ?? '',
                target: target,
                role: role,
              );
              if (result['ok'] != true) {
                throw StateError('Public image finalize was not confirmed');
              }
            }
          : null,
      errorMessage: UiCopy.text('copy_bfaa60aee417'),
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
      sessionBuilder: (contentType, preferredFileName, _, _) =>
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
      errorMessage: UiCopy.text('copy_668d3addf2f9'),
    );
  }

  /// Luồng mới: server commit record/quota, không trả URL công khai cho client ghi.
  /// requestId phải được controller lưu vào journal trước khi gọi phương thức này.
  Future<PrivateMemoryUploadReceipt> uploadPrivateMemory({
    required String houseId,
    required String requestId,
    required XFile file,
    required String authorName,
    required bool Function() scopeIsCurrent,
    int quality = 78,
    Future<void> Function(int bytes, bool isVideo)? beforeUpload,
    double? latitude,
    double? longitude,
  }) async {
    final uid = _requireCurrentUid();
    String? compressedPath;
    final client = http.Client();
    try {
      return await const StoragePrivateMemoryUploadHelper().upload(
        uid: uid,
        houseId: houseId,
        requestId: requestId,
        authorName: authorName,
        currentUid: () => _auth.currentUser?.uid,
        authChanges: _auth.authStateChanges().map((user) => user?.uid),
        scopeIsCurrent: scopeIsCurrent,
        invoke: (name, payload) async {
          final result = await _callWithAppCheckRetry(
            () => _functions
                .httpsCallable(
                  name,
                  options: HttpsCallableOptions(
                    timeout: const Duration(seconds: 120),
                  ),
                )
                .call<Map<String, dynamic>>(payload),
          );
          return result.data;
        },
        client: client,
        beforeUpload: beforeUpload,
        latitude: latitude,
        longitude: longitude,
        prepareFile: () async {
          final name = file.name.isNotEmpty ? file.name : file.path;
          final contentType = detectContentType(name);
          _rejectVideoUpload(
            storagePath: name,
            resolvedContentType: contentType,
            originalFileName: name,
          );
          if (!kIsWeb &&
              file.path.isNotEmpty &&
              contentType.startsWith('image/') &&
              contentType != 'image/gif') {
            try {
              final temp = await getTemporaryDirectory();
              compressedPath = p.join(
                temp.path,
                'private_memory_${requestId}_${DateTime.now().microsecondsSinceEpoch}.webp',
              );
              final compressed = await FlutterImageCompress.compressAndGetFile(
                file.path,
                compressedPath!,
                minWidth: 1080,
                minHeight: 1920,
                quality: quality.clamp(70, 100),
                format: CompressFormat.webp,
              );
              if (compressed != null)
                return (file: compressed, contentType: 'image/webp');
            } catch (_) {
              // File gốc vẫn được kiểm tra MIME/kích thước và checksum bởi server.
            }
          }
          return (file: file, contentType: contentType);
        },
      );
    } finally {
      client.close();
      if (compressedPath != null) {
        try {
          final temporaryFile = File(compressedPath!);
          if (await temporaryFile.exists()) await temporaryFile.delete();
        } catch (_) {
          // Không biến commit thành công thành lỗi do dọn file tạm.
        }
      }
    }
  }

  Future<StorageUploadResult?> uploadMemoryImage(
    String houseId,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
    Future<void> Function(int bytes)? beforeUpload,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName, _, _) =>
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
      errorMessage: UiCopy.text('copy_6f4cc17c0717'),
      beforeUpload: beforeUpload,
    );
  }

  Future<StorageUploadResult?> uploadTimeCapsuleImage(
    String houseId,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
  }) {
    return _uploadSignedImageWithCompression(
      file: file,
      sessionBuilder: (contentType, preferredFileName, size, md5Hex) =>
          _uploadSessionHelper.createUploadSession(
            invokeCallable: (name, payload) => _callWithAppCheckRetry(
              () => _functions.httpsCallable(name).call(payload),
              allowUnauthenticatedWithoutMarkers: true,
            ),
            functionName: 'createTimeCapsuleImageUploadSession',
            payload: <String, dynamic>{
              'houseId': houseId.trim(),
              'contentType': contentType.trim(),
              'fileName': preferredFileName.trim(),
              'transport': 'r2',
              'size': size,
              'md5': md5Hex,
            },
            label: 'Time capsule image upload session',
            requireSessionId: true,
            requireDownloadUrl: false,
          ),
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      tempPrefix: 'sl_time_capsule',
      r2Folder: 'time_capsules',
      r2HouseId: houseId,
      errorLabel: 'Time capsule image',
      mapResult: mapBasicStorageUploadResult,
      finalizeSession: (session) async {
        final response = await _callWithAppCheckRetry(
          () =>
              _functions.httpsCallable('finalizeTimeCapsuleImageUpload').call({
                'houseId': houseId.trim(),
                'sessionId': session['sessionId']?.toString().trim() ?? '',
              }),
          allowUnauthenticatedWithoutMarkers: true,
        );
        if (response.data is! Map || response.data['ok'] != true) {
          throw StateError('Time capsule image finalize was not confirmed');
        }
      },
      errorMessage: UiCopy.text('copy_3d3563928844'),
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
      sessionBuilder: (contentType, preferredFileName, _, _) =>
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
      errorMessage: UiCopy.text('copy_cf39b1f1b5a6'),
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
      sessionBuilder: (contentType, preferredFileName, _, _) =>
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
      errorMessage: UiCopy.text('copy_e05dbe307913'),
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
      sessionBuilder: (contentType, preferredFileName, _, _) =>
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
      errorMessage: UiCopy.text('copy_0d1384921d39'),
    );
  }

  Future<StorageUploadResult?> _uploadSignedImageWithCompression({
    required XFile file,
    required Future<Map<String, dynamic>> Function(
      String contentType,
      String preferredFileName,
      int size,
      String md5Hex,
    )
    sessionBuilder,
    // Thư mục R2 riêng tư khi server trả phiên `transport: 'r2'` (ví dụ time_capsules).
    String? r2Folder,
    String? r2HouseId,
    required int minWidth,
    required int minHeight,
    required int quality,
    required String tempPrefix,
    required String errorLabel,
    required StorageUploadResult Function(Map<String, dynamic> session)
    mapResult,
    Future<void> Function(Map<String, dynamic> session)? finalizeSession,
    required String errorMessage,
    ValueChanged<double>? onProgress,
    Future<void> Function(int bytes)? beforeUpload,
  }) async {
    String? tempCompressedPath;
    final uploadUid = _requireCurrentUid();
    void requireUploadOwner() {
      if (_auth.currentUser?.uid != uploadUid) {
        throw FirebaseAuthException(code: 'user-token-expired');
      }
    }

    try {
      final input = StorageImageUploadInput.fromFile(file);
      final originalFileName = input.fileName;
      var fileExtension = p.extension(originalFileName).toLowerCase();
      var contentType = input.contentType;
      XFile uploadFile = file;

      if (!kIsWeb &&
          file.path.isNotEmpty &&
          contentType.startsWith('image/') &&
          fileExtension != '.gif') {
        try {
          onProgress?.call(0.05);
          final tempDir = await getTemporaryDirectory();
          tempCompressedPath = p.join(
            tempDir.path,
            '${tempPrefix}_${DateTime.now().microsecondsSinceEpoch}.webp',
          );
          final compressed = await FlutterImageCompress.compressAndGetFile(
            file.path,
            tempCompressedPath,
            minWidth: minWidth,
            minHeight: minHeight,
            quality: quality,
            format: CompressFormat.webp,
          );
          if (compressed != null) {
            uploadFile = compressed;
            fileExtension = '.webp';
            contentType = 'image/webp';
          } else {
            tempCompressedPath = null;
          }
        } catch (error) {
          tempCompressedPath = null;
          debugPrint(
            '$errorLabel compression skipped: ${AppErrorMapper.resolve(error).message}',
          );
        }
      }

      if (fileExtension.isEmpty) {
        fileExtension = p.extension(uploadFile.name).toLowerCase();
      }
      if (fileExtension.isEmpty) fileExtension = '.jpg';
      final preferredFileName =
          '${p.basenameWithoutExtension(originalFileName.isEmpty ? 'image' : originalFileName)}$fileExtension';
      final bytes = await uploadFile.readAsBytes();
      if (bytes.isEmpty) throw StateError('Empty upload file');
      await beforeUpload?.call(bytes.length);
      requireUploadOwner();
      onProgress?.call(0.4);

      final session = await sessionBuilder(
        contentType,
        preferredFileName,
        bytes.length,
        md5.convert(bytes).toString(),
      );
      requireUploadOwner();
      if (session['transport'] == 'r2') {
        await _putPrivateR2Image(
          session: session,
          bytes: bytes,
          contentType: contentType,
          folder: r2Folder,
          houseId: r2HouseId,
          ownerUid: uploadUid,
        );
      } else {
        await _putFirebaseSignedImage(
          session: session,
          bytes: bytes,
          contentType: contentType,
        );
      }

      requireUploadOwner();
      await finalizeSession?.call(session);
      requireUploadOwner();
      final mapped = mapResult(session);
      onProgress?.call(1);
      return StorageUploadResult(
        downloadUrl: mapped.downloadUrl,
        storagePath: mapped.storagePath,
        sessionId: mapped.sessionId,
        expiresAt: mapped.expiresAt,
        dailyLimit: mapped.dailyLimit,
        remainingToday: mapped.remainingToday,
        blurHash: mapped.blurHash,
        width: mapped.width,
        height: mapped.height,
        uploadedBytes: bytes.length,
      );
    } catch (error) {
      debugPrint('$errorLabel upload failed (${error.runtimeType})');
      throw Exception(errorMessage);
    } finally {
      if (tempCompressedPath != null) {
        try {
          final tempFile = File(tempCompressedPath);
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// PUT ảnh lên bucket R2 riêng tư theo phiên server ký; kiểm tra đúng nhà/chủ/thư mục.
  Future<void> _putPrivateR2Image({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
    required String? folder,
    required String? houseId,
    required String ownerUid,
  }) async {
    final request = PrivateR2Put.buildRequest(
      session: session,
      bytes: bytes,
      contentType: contentType,
      houseId: houseId?.trim(),
      ownerUid: ownerUid,
      folder: folder ?? '',
      extensions: const {'jpg', 'png', 'webp', 'gif', 'heic', 'heif'},
      maxBytes: 15 * 1024 * 1024,
    );
    final client = http.Client();
    try {
      await PrivateR2Put.send(client, request);
    } finally {
      client.close();
    }
  }

  /// PUT ảnh lên Firebase Storage theo URL ký V4 (luồng cũ, giữ cho server chưa bật R2).
  Future<void> _putFirebaseSignedImage({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uploadUrl = session['uploadUrl']?.toString().trim() ?? '';
    final rawHeaders = session['headers'];
    if (uploadUrl.isEmpty || rawHeaders is! Map) {
      throw StateError('Invalid upload session');
    }
    final uploadUri = Uri.tryParse(uploadUrl);
    if (uploadUri == null ||
        uploadUri.scheme != 'https' ||
        uploadUri.port != 443 ||
        uploadUri.userInfo.isNotEmpty ||
        uploadUri.hasFragment ||
        !(uploadUri.host == 'storage.googleapis.com' ||
            uploadUri.host.endsWith('.storage.googleapis.com'))) {
      throw StateError('Invalid upload destination');
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw StateError('Invalid upload headers');
      }
      final name = (entry.key as String).toLowerCase();
      final value = entry.value as String;
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name + value) ||
          headers.containsKey(name)) {
        throw StateError('Invalid upload headers');
      }
      if (name == 'content-type' || name.startsWith('x-goog-meta-')) {
        headers[name] = value;
      }
    }
    if (headers['content-type'] != contentType) {
      throw StateError('Upload content type mismatch');
    }

    final request = http.Request('PUT', uploadUri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Upload failed (${response.statusCode})');
      }
    } finally {
      client.close();
    }
  }

  Future<StorageUploadResult?> uploadSecretVaultImage(
    String houseId,
    XFile file, {
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
  }) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      throw UiCopyException('copy_57a524aa6dd1');
    }
    _requireCurrentUid();

    try {
      final originalName = file.name.trim().isNotEmpty
          ? file.name.trim()
          : p.basename(file.path);
      var uploadName = originalName.isEmpty ? 'vault_image.jpg' : originalName;
      var contentType = detectContentType(uploadName, fallback: 'image/jpeg');
      var bytes = await file.readAsBytes();

      final extension = p.extension(uploadName).toLowerCase();
      if (!kIsWeb &&
          file.path.isNotEmpty &&
          contentType.startsWith('image/') &&
          extension != '.gif') {
        try {
          final compressed = await FlutterImageCompress.compressWithFile(
            file.path,
            minWidth: minWidth,
            minHeight: minHeight,
            quality: quality,
            format: CompressFormat.webp,
          );
          if (compressed != null && compressed.isNotEmpty) {
            bytes = compressed;
            contentType = 'image/webp';
            uploadName = '${p.basenameWithoutExtension(uploadName)}.webp';
          }
        } catch (error) {
          debugPrint(
            'Secret Vault compression skipped: ${AppErrorMapper.resolve(error).message}',
          );
        }
      }

      final sessionResult = await _callWithAppCheckRetry(
        () => _functions.httpsCallable('generateUploadUrl').call({
          'folder': 'secret_vault',
          'houseId': normalizedHouseId,
          'fileName': uploadName,
          'contentType': contentType,
          'fileSize': bytes.length,
        }),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final rawSession = sessionResult.data;
      if (rawSession is! Map) {
        throw UiCopyException('copy_dd1fed82cddc');
      }
      final session = Map<String, dynamic>.from(rawSession);
      final uploadId = session['uploadId']?.toString().trim() ?? '';
      final uploadUrl = session['url']?.toString().trim() ?? '';
      final storagePath = session['path']?.toString().trim() ?? '';
      if (uploadId.isEmpty || uploadUrl.isEmpty || storagePath.isEmpty) {
        throw UiCopyException('copy_3081f058c454');
      }

      final headers = <String, String>{};
      final rawHeaders = session['requiredHeaders'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((key, value) {
          if (key != null && value != null) {
            headers[key.toString()] = value.toString();
          }
        });
      }
      headers.putIfAbsent('Content-Type', () => contentType);

      final uploadResponse = await http
          .put(Uri.parse(uploadUrl), headers: headers, body: bytes)
          .timeout(const Duration(minutes: 2));
      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw UiCopyException('copy_f36e2a41b72a', {'value1': uploadResponse.statusCode});
      }

      final finalized = await _callWithAppCheckRetry(
        () => _functions.httpsCallable('finalizeR2Upload').call({
          'uploadId': uploadId,
        }),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final finalizeData = finalized.data;
      if (finalizeData is! Map || finalizeData['success'] != true) {
        throw UiCopyException('copy_a72d2688a7b4');
      }

      return StorageUploadResult(
        downloadUrl: '',
        storagePath: storagePath,
        sessionId: uploadId,
        uploadedBytes: bytes.length,
      );
    } catch (error) {
      debugPrint(
        'Secret Vault private upload failed: ${AppErrorMapper.resolve(error).message}',
      );
      throw Exception(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể tải ảnh lên kho bí mật.',
        ).message,
      );
    }
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
      final encodedPath = pathSegments
          .sublist(objectSegmentIndex + 1)
          .join('/');
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

  Future<bool> deleteSecretVaultFileByPath({
    required String houseId,
    required String mediaId,
    required String storagePath,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedMediaId = mediaId.trim();
    final normalizedPath = storagePath.trim();
    if (normalizedHouseId.isEmpty ||
        normalizedMediaId.isEmpty ||
        normalizedPath.isEmpty) {
      return false;
    }
    try {
      final result = await _callWithAppCheckRetry(
        () => _functions.httpsCallable('deleteR2Object').call({
          'houseId': normalizedHouseId,
          'mediaId': normalizedMediaId,
          'objectKey': normalizedPath,
        }),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final data = result.data;
      return data is Map && data['success'] == true;
    } catch (error) {
      debugPrint(
        'Secret Vault private delete failed: ${AppErrorMapper.resolve(error).message}',
      );
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
