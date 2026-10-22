import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:io';
import 'dart:convert';
import '../storage/secret_vault_put.dart';
import '../encryption_service.dart';

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
import 'package:soullocket_app/utils/services/storage/storage_upload_progress.dart';
import 'package:soullocket_app/utils/services/storage/storage_picker_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_raw_upload_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_result.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_session_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_upload_result_mapper.dart';
import 'package:soullocket_app/utils/services/storage/storage_web_picker_guard.dart';
import 'package:soullocket_app/utils/services/storage/storage_private_memory_upload_helper.dart';
import 'package:soullocket_app/utils/services/storage/storage_video_optimizer.dart';

class StorageService {
  StorageService();

  static int _uploadSequence = 0;

  static StorageService get instance => StorageService();

  static const int pickerImageQuality = StoragePickerService.pickerImageQuality;
  static const double pickerMaxWidth = StoragePickerService.pickerMaxWidth;
  static const double pickerMaxHeight = StoragePickerService.pickerMaxHeight;
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

  Future<List<XFile>> pickImages({int? limit, bool preserveOriginal = false}) =>
      _pickerService.pickImages(
        limit: limit,
        preserveOriginal: preserveOriginal,
      );

  Future<List<XFile>> pickMedia({int? limit, bool preserveOriginal = false}) =>
      _pickerService.pickMedia(
        limit: limit,
        preserveOriginal: preserveOriginal,
      );

  Future<List<XFile>> pickMemoryMedia({
    int? limit,
    bool preserveOriginal = false,
  }) =>
      _pickerService.pickMemoryMedia(
        limit: limit,
        preserveOriginal: preserveOriginal,
      );

  static bool isLivePhotoFile(XFile file) => StoragePickerService.isLivePhotoFile(file);

  Future<List<XFile>> pickMultipleMusicFiles({int maxFiles = 5}) =>
      _pickerService.pickMultipleMusicFiles(maxFiles: maxFiles);

  bool isSupportedMusicFileName(String fileNameOrPath) {
    final extension = p.extension(fileNameOrPath).toLowerCase();
    return storageMusicPickerExtensions.contains(
      extension.replaceFirst('.', ''),
    );
  }

  Future<XFile?> pickImage({bool preserveOriginal = false}) =>
      _pickerService.pickImage(preserveOriginal: preserveOriginal);

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
      throw const UiCopyException('copy_0d17dba25af1');
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
            fallbackMessage: UiCopy.text('copy_d8769088f9cd'),
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw const UiCopyException('copy_3b1a55a37917');
        case 'invalid-argument':
          throw const UiCopyException('copy_6561892964ac');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_4eddadaf393b'),
          );
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_43b8e078d49e'),
          );
        case 'resource-exhausted':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_a474359238f5'),
          );
        case 'permission-denied':
          throw const UiCopyException('copy_8a24722de890');
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_87c69d5f9627');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_d8769088f9cd'),
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
            fallbackMessage: UiCopy.text('copy_eab9ad5c7371'),
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw const UiCopyException('copy_b44a30bfef88');
        case 'invalid-argument':
          throw const UiCopyException('copy_1a801c2953b4');
        case 'permission-denied':
          throw const UiCopyException('copy_dd37c52a99a6');
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_dd8932601953');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_eab9ad5c7371'),
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
            fallbackMessage: UiCopy.text('copy_10be00596ae0'),
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw const UiCopyException('copy_f7bbe23f6145');
        case 'invalid-argument':
          throw const UiCopyException('copy_07b57ae1291a');
        case 'permission-denied':
          throw const UiCopyException('copy_0a0e82c2da65');
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_98cbed0ef403');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_10be00596ae0'),
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
            fallbackMessage: UiCopy.text('copy_d8232a854797'),
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw const UiCopyException('copy_3e75f7405247');
        case 'invalid-argument':
          throw const UiCopyException('copy_c62167c0e18b');
        case 'permission-denied':
          throw const UiCopyException('copy_89a73767f9fc');
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_f8b58a3bc941');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_d8232a854797'),
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
          throw const UiCopyException('copy_90a477ac6e83');
        case 'invalid-argument':
          throw const UiCopyException('copy_c6d946b85ebe');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_434b65142912'),
          );
        case 'permission-denied':
          throw const UiCopyException('copy_6c6006ba38ea');
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_911c5a651794'),
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_67d933ac8ea6');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_b00ea75234bf'),
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
          throw const UiCopyException('copy_e51f8753446e');
        case 'invalid-argument':
          throw const UiCopyException('copy_7d96fae4af62');
        case 'resource-exhausted':
          throw const UiCopyException('copy_5470f87bf0a1');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_d53ece706e72'),
          );
        case 'permission-denied':
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_65566be85752'),
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_4efcae934e53');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_bc4b444de59c'),
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
      throw const UiCopyException('copy_5128b4443dbd');
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
          throw const UiCopyException('copy_34e1b3d650e7');
        case 'invalid-argument':
          throw const UiCopyException('copy_2f7fb878a0de');
        case 'permission-denied':
          throw const UiCopyException('copy_febe3f9cb924');
        case 'not-found':
          throw Exception(
            (resolvedError.message ?? '').trim().isNotEmpty
                ? resolvedError.message!.trim()
                : UiCopy.text('copy_e4f4b31ebb17'),
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_8f44baa3f6f7');
        default:
          throw Exception(
            (resolvedError.message ?? '').trim().isNotEmpty
                ? resolvedError.message!.trim()
                : UiCopy.text('copy_f6339bd5b947'),
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
          throw const UiCopyException('copy_d4788b9ad5cb');
        case 'invalid-argument':
          throw const UiCopyException('copy_342a1ad34a6a');
        case 'permission-denied':
          throw const UiCopyException('copy_fffaee0b9efd');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_116f932f2fef'),
          );
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_93c7f90ed214'),
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_f077e76c9760');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_d10920183db5'),
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
          throw const UiCopyException('copy_66a39337300e');
        case 'invalid-argument':
          throw const UiCopyException('copy_7b3f71abbf6b');
        case 'permission-denied':
          throw const UiCopyException('copy_e52c27bcd89e');
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_ba3af1f1f4ce');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_cfe91d96d169'),
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
            fallbackMessage: UiCopy.text('copy_748909ef83bb'),
          ).message,
        );
      }
      switch (error.code.trim().toLowerCase()) {
        case 'unauthenticated':
          throw const UiCopyException('copy_d63f7c5741da');
        case 'invalid-argument':
          throw const UiCopyException('copy_cd208658eecf');
        case 'not-found':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_3303f1fbd57c'),
          );
        case 'permission-denied':
        case 'failed-precondition':
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_228e5c9a8b73'),
          );
        case 'deadline-exceeded':
        case 'unavailable':
          throw const UiCopyException('copy_56d7893f7c4e');
        default:
          throw Exception(
            (error.message ?? '').trim().isNotEmpty
                ? error.message!.trim()
                : UiCopy.text('copy_748909ef83bb'),
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
      throw const UiCopyException('copy_97d441d22938');
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
    int minWidth = 1080,
    int minHeight = 1920,
    bool requestIsFresh = false,
    bool isLivePhoto = false,
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
        requestIsFresh: requestIsFresh,
        isLivePhoto: isLivePhoto,
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
          if (!kIsWeb && contentType.startsWith('video/')) {
            final optimized = await StorageVideoOptimizer.prepareVideoForUpload(
              file,
              isLivePhoto: isLivePhoto,
            );
            compressedPath = optimized.temporaryPath;
            return (
              file: optimized.videoFile,
              contentType: optimized.temporaryPath != null ? 'video/mp4' : contentType,
            );
          }
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
                minWidth: minWidth,
                minHeight: minHeight,
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
      onProgress?.call(0);
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
      var lastByteProgress = 0.0;
      void reportByteProgress(double progress) {
        final next = progress
            .clamp(0.0, StorageUploadProgress.putProgressCeiling)
            .toDouble();
        if (next <= lastByteProgress) return;
        lastByteProgress = next;
        onProgress?.call(next);
      }

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
          onProgress: onProgress == null || kIsWeb
              ? null
              : (progress) => reportByteProgress(
                  progress * StorageUploadProgress.putProgressCeiling,
                ),
        );
      } else {
        await _putFirebaseSignedImage(
          session: session,
          bytes: bytes,
          contentType: contentType,
          onProgress: onProgress == null || kIsWeb
              ? null
              : (progress) => reportByteProgress(
                  progress * StorageUploadProgress.putProgressCeiling,
                ),
        );
      }

      requireUploadOwner();
      // Byte progress kết thúc ở 95%; 5% cuối là finalize server và kiểm tra
      // scope. Trên Web, BrowserClient không có upload progress nên chỉ nhảy
      // tới mốc này sau khi PUT hoàn tất.
      reportByteProgress(StorageUploadProgress.putProgressCeiling);
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
    StorageUploadProgressCallback? onProgress,
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
      await PrivateR2Put.send(client, request, onProgress: onProgress);
    } finally {
      client.close();
    }
  }

  /// PUT ảnh lên Firebase Storage theo URL ký V4 (luồng cũ, giữ cho server chưa bật R2).
  Future<void> _putFirebaseSignedImage({
    required Map<String, dynamic> session,
    required Uint8List bytes,
    required String contentType,
    StorageUploadProgressCallback? onProgress,
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

    final client = http.Client();
    try {
      if (kIsWeb || onProgress == null) {
        final request = http.Request('PUT', uploadUri)
          ..followRedirects = false
          ..headers.addAll(headers)
          ..bodyBytes = bytes;
        final response = await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(minutes: 2));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('Upload failed (${response.statusCode})');
        }
        return;
      }

      final request = http.StreamedRequest('PUT', uploadUri)
        ..followRedirects = false
        ..headers.addAll(headers)
        ..contentLength = bytes.length;
      final responseFuture = client
          .send(request)
          .then(http.Response.fromStream);
      final producer = StorageUploadProgress.pumpBytes(
        sink: request.sink,
        bytes: bytes,
        onProgress: onProgress,
      );
      final results = await Future.wait<Object?>([
        responseFuture,
        producer,
      ]).timeout(const Duration(minutes: 2));
      final response = results.first as http.Response;
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
    required String requestId,
    required String encryptedCaption,
    int minWidth = 960,
    int minHeight = 960,
    int quality = 62,
  }) async {
    final normalizedHouseId = houseId.trim();
    final uploadUid = _requireCurrentUid();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedHouseId) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId)) {
      throw const FormatException('Invalid Secret Vault upload scope');
    }
    var scopeChanged = false;
    final authSubscription = _auth.authStateChanges().listen((user) {
      if (user?.uid != uploadUid) scopeChanged = true;
    }, onError: (_) => scopeChanged = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final journalKey =
          'vault_private_upload_v2_${uploadUid}_${normalizedHouseId}_$requestId';
      void requireScope() {
        if (scopeChanged ||
            _auth.currentUser?.uid != uploadUid ||
            (prefs.getString('il_house_id')?.isNotEmpty == true &&
                prefs.getString('il_house_id') != normalizedHouseId)) {
          throw StateError('Secret Vault upload scope changed');
        }
      }

      requireScope();
      var journal = <String, dynamic>{};
      final saved = prefs.getString(journalKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map) journal = Map<String, dynamic>.from(decoded);
      }
      if (journal.isNotEmpty &&
          (journal['uid'] != uploadUid ||
              journal['houseId'] != normalizedHouseId ||
              journal['caption'] != encryptedCaption)) {
        throw StateError('Secret Vault journal does not match this request');
      }
      Future<Map<String, dynamic>> finalize(String uploadId) async {
        requireScope();
        final result = await _callWithAppCheckRetry(
          () => _functions
              .httpsCallable(
                'finalizeR2Upload',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 120),
                ),
              )
              .call({'uploadId': uploadId}),
        );
        requireScope();
        if (result.data is! Map || result.data['success'] != true) {
          throw const FormatException('Invalid Secret Vault upload receipt');
        }
        return Map<String, dynamic>.from(result.data as Map);
      }

      Future<StorageUploadResult> complete(Map<String, dynamic> receipt) async {
        requireScope();
        final mediaId = receipt['mediaId']?.toString() ?? '';
        final path = receipt['path']?.toString() ?? '';
        if (mediaId.isEmpty ||
            !path.startsWith(
              'users/$uploadUid/secret_vault/$normalizedHouseId/',
            )) {
          throw const FormatException('Invalid Secret Vault media receipt');
        }
        await prefs.remove(journalKey);
        final prepared = journal['preparedPath']?.toString() ?? '';
        if (prepared.isNotEmpty) await _deleteHelper.deleteLocalFile(prepared);
        requireScope();
        return StorageUploadResult(
          downloadUrl: '',
          storagePath: path,
          mediaId: mediaId,
          sessionId: journal['uploadId']?.toString(),
          uploadedBytes: (journal['size'] as num?)?.toInt(),
        );
      }

      final savedUploadId = journal['uploadId']?.toString() ?? '';
      if (savedUploadId.isNotEmpty) {
        try {
          return await complete(await finalize(savedUploadId));
        } on FirebaseFunctionsException catch (error) {
          // Chỉ PUT khi object chưa tới server. Các lỗi quyền/quota/reset giữ
          // journal để thử lại đúng phiên, không phát sinh ảnh thứ hai.
          if (error.code != 'not-found') rethrow;
        }
      }
      Uint8List bytes;
      var contentType = journal['contentType']?.toString() ?? '';
      final preparedPath = journal['preparedPath']?.toString() ?? '';
      if (!kIsWeb && preparedPath.isNotEmpty) {
        final encrypted = await File(preparedPath).readAsString();
        bytes = base64Decode(
          await EncryptionService().decryptMessage(
            normalizedHouseId,
            encrypted,
          ),
        );
      } else {
        bytes = await file.readAsBytes();
        final originalName = file.name.isNotEmpty
            ? file.name
            : p.basename(file.path);
        contentType = detectContentType(originalName, fallback: 'image/jpeg');
        if (!kIsWeb &&
            contentType.startsWith('image/') &&
            p.extension(originalName).toLowerCase() != '.gif') {
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
            }
          } catch (_) {
            debugPrint('[SecretVault] Giữ ảnh gốc khi không nén được.');
          }
        }
        requireScope();
        journal = {
          'uid': uploadUid,
          'houseId': normalizedHouseId,
          'caption': encryptedCaption,
          'contentType': contentType,
          'size': bytes.length,
          'md5': md5.convert(bytes).toString(),
        };
        if (!kIsWeb) {
          final directory = await getApplicationSupportDirectory();
          final prepared = File(
            p.join(
              directory.path,
              'vault_${uploadUid}_${normalizedHouseId}_$requestId.bin',
            ),
          );
          final encrypted = await EncryptionService().encryptMessage(
            normalizedHouseId,
            base64Encode(bytes),
          );
          await prepared.writeAsString(encrypted, flush: true);
          journal['preparedPath'] = prepared.path;
        }
        requireScope();
        await prefs.setString(journalKey, jsonEncode(journal));
      }
      requireScope();
      final created = await _callWithAppCheckRetry(
        () => _functions
            .httpsCallable(
              'generateUploadUrl',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 120),
              ),
            )
            .call({
              'folder': 'secret_vault',
              'houseId': normalizedHouseId,
              'requestId': requestId,
              'contentType': contentType,
              'fileSize': bytes.length,
              'md5': md5.convert(bytes).toString(),
              'encryptedCaption': encryptedCaption,
            }),
      );
      requireScope();
      if (created.data is! Map)
        throw const FormatException('Invalid Secret Vault session');
      final session = Map<String, dynamic>.from(created.data as Map);
      journal['uploadId'] = session['uploadId'];
      await prefs.setString(journalKey, jsonEncode(journal));
      requireScope();
      if (session['complete'] == true) return complete(session);
      final request = SecretVaultPut.buildRequest(
        session: session,
        bytes: bytes,
        uid: uploadUid,
        houseId: normalizedHouseId,
        contentType: contentType,
      );
      final client = http.Client();
      try {
        await PrivateR2Put.send(client, request);
      } finally {
        client.close();
      }
      requireScope();
      return complete(await finalize(session['uploadId'].toString()));
    } finally {
      await authSubscription.cancel();
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
    if (normalizedHouseId.isEmpty || normalizedMediaId.isEmpty) {
      return false;
    }
    try {
      final result = await _callWithAppCheckRetry(
        () => _functions.httpsCallable('deleteR2Object').call({
          'houseId': normalizedHouseId,
          'mediaId': normalizedMediaId,
          if (normalizedPath.isNotEmpty) 'objectKey': normalizedPath,
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

  Future<void> syncHomeBackground(String houseId, String url) async {
    final requestId = 'bg_${DateTime.now().microsecondsSinceEpoch}';
    final result = await _callWithAppCheckRetry(
      () => _functions.httpsCallable('syncHomeBackground').call({
        'houseId': houseId.trim(),
        'url': url.trim(),
        'requestId': requestId,
      }),
      allowUnauthenticatedWithoutMarkers: true,
    );
    if (result.data is! Map || result.data['success'] != true) {
      throw StateError('Home background sync not confirmed');
    }
  }

  /// URL đã ký chỉ dùng để tải ảnh, không lưu vào cài đặt hoặc database.
  Future<String> resolveHomeBackgroundReadUrl(String houseId, String url) async {
    final uid = _requireCurrentUid();
    final result = await _callWithAppCheckRetry(
      () => _functions.httpsCallable('resolveHomeBackground').call({
        'houseId': houseId.trim(),
        'url': url.trim(),
      }),
      allowUnauthenticatedWithoutMarkers: true,
    );
    if (_auth.currentUser?.uid != uid) {
      throw StateError('Home background session changed');
    }
    final data = result.data;
    final signedUrl = data is Map ? data['url']?.toString().trim() ?? '' : '';
    final uri = Uri.tryParse(signedUrl);
    final expiresAt = data is Map ? data['expiresAt'] : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.host.endsWith('.r2.cloudflarestorage.com') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        expiresAt is! num ||
        expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      throw StateError('Home background read not confirmed');
    }
    return signedUrl;
  }

  /// Xóa ảnh public cũ sau khi đã commit URL mới.
  ///
  /// Ảnh Home avatar legacy/public nằm trên Firebase Storage, còn một số
  /// avatar cũ có thể nằm trên R2. Chọn backend theo URL để không gọi nhầm
  /// helper R2 cho object Firebase.
  Future<bool> deletePublicImageByUrl(String houseId, String url) async {
    final normalizedHouseId = houseId.trim();
    final normalizedUrl = url.trim();
    if (normalizedHouseId.isEmpty || normalizedUrl.isEmpty) {
      return false;
    }

    try {
      CloudflareR2Service.instance.init();
      if (CloudflareR2Service.instance.isR2Url(normalizedUrl)) {
        return await CloudflareR2Service.instance.deleteFile(normalizedUrl);
      }

      // Server xác minh cả bucket, host và đường dẫn trước khi xóa.
      final uri = Uri.tryParse(normalizedUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'firebasestorage.googleapis.com' ||
          uri.userInfo.isNotEmpty ||
          (uri.hasPort && uri.port != 443)) {
        return false;
      }
      final storagePath = extractStoragePathFromUrl(normalizedUrl);
      if (storagePath == null || storagePath.isEmpty) {
        return false;
      }

      final result = await _callWithAppCheckRetry(
        () => _functions.httpsCallable('deletePublicImageAsset').call({
          'houseId': normalizedHouseId,
          'storagePath': storagePath,
          'url': normalizedUrl,
        }),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final data = result.data;
      return data is Map && data['success'] == true;
    } catch (error) {
      debugPrint('Failed to delete public image: ${error.runtimeType}');
      return false;
    }
  }
}
