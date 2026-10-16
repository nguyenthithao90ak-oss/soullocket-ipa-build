import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/services/device_manager_service.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'core/cloud_functions_helper.dart';
import 'offline_cache_service.dart';
import 'secure_storage_service.dart';
import 'device_installation_identity.dart';

class HouseService {
  HouseService({
    DatabaseReference? databaseRef,
    firebase_auth.FirebaseAuth? firebaseAuth,
  }) : _dbRef = databaseRef ?? FirebaseDatabase.instance.ref(),
       _auth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;

  static DateTime? _lastFetchTime;
  static Map<String, dynamic>? _cachedSettings;
  static String? _lastFirestoreMembershipSyncKey;
  static DateTime? _lastFirestoreMembershipSyncAt;
  static String? _activeFirestoreMembershipSyncKey;
  static Future<void>? _activeFirestoreMembershipSync;
  static const String _defaultHouseName = 'Chúng mình';
  static const String _defaultNameU1 = 'Bạn Nam';
  static const String _defaultNameU2 = 'Bạn Nữ';

  static const String _authUidPrefsKey = 'il_auth_uid';

  final DatabaseReference _dbRef;
  final firebase_auth.FirebaseAuth _auth;

  Map<String, dynamic>? _asStringDynamicMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  firebase_auth.User? get currentUser => _auth.currentUser;

  Future<void> _syncHouseIdToFirestore(
    String uid,
    String houseId, {
    bool throwOnError = false,
  }) async {
    if (houseId.isEmpty || _auth.currentUser?.uid != uid) return;
    final syncKey = '$uid|$houseId';
    final lastSyncAt = _lastFirestoreMembershipSyncAt;
    if (_lastFirestoreMembershipSyncKey == syncKey &&
        lastSyncAt != null &&
        DateTime.now().difference(lastSyncAt) < const Duration(minutes: 5)) {
      return;
    }

    final activeSync = _activeFirestoreMembershipSync;
    if (_activeFirestoreMembershipSyncKey == syncKey && activeSync != null) {
      try {
        await activeSync;
      } catch (error) {
        if (throwOnError) rethrow;
      }
      return;
    }

    final syncOperation = _ensureFirestoreMembershipOnServer(uid, houseId);
    _activeFirestoreMembershipSyncKey = syncKey;
    _activeFirestoreMembershipSync = syncOperation;
    try {
      await syncOperation;
      _lastFirestoreMembershipSyncKey = syncKey;
      _lastFirestoreMembershipSyncAt = DateTime.now();
    } catch (e) {
      debugPrint('[HouseService] Firestore houseId sync failed: $e');
      if (throwOnError) rethrow;
    } finally {
      if (identical(_activeFirestoreMembershipSync, syncOperation)) {
        _activeFirestoreMembershipSyncKey = null;
        _activeFirestoreMembershipSync = null;
      }
    }
  }

  Future<void> _ensureFirestoreMembershipOnServer(
    String uid,
    String houseId,
  ) async {
    try {
      final membership = await FirebaseFirestore.instance
          .collection('house_memberships')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      final verifiedHouseId = membership.data()?['houseId']?.toString().trim();
      if (membership.exists && verifiedHouseId == houseId) {
        return;
      }
    } catch (error) {
      debugPrint(
        '[HouseService] Firestore membership preflight skipped: '
        '${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể kiểm tra quyền truy cập nhà.').message}',
      );
    }

    await _refreshCallableSecurityContext(
      force: false,
      throwOnAppCheckError: true,
    );
    try {
      await _callFirestoreMembershipSync(houseId);
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldRetryCreateHouse(error)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _refreshCallableSecurityContext(
        force: true,
        throwOnAppCheckError: true,
      );
      await _callFirestoreMembershipSync(houseId);
    }
  }

  Future<void> _callFirestoreMembershipSync(String houseId) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      'syncMyHouseMembership',
      payload: <String, dynamic>{'houseId': houseId},
      timeout: const Duration(seconds: 15),
      fallbackErrorMessage: UiCopy.text('copy_ea439e6a6264'),
      throwOriginalException: true,
    );
  }

  /// Đảm bảo Firestore đã có membership do server xác minh trước khi
  /// các tính năng dữ liệu theo nhà (như nhật ký) bắt đầu đọc hoặc ghi.
  Future<void> ensureFirestoreMembership(String houseId) async {
    final normalizedHouseId = houseId.trim();
    final user = _auth.currentUser;
    if (normalizedHouseId.isEmpty || user == null) return;
    await _syncHouseIdToFirestore(
      user.uid,
      normalizedHouseId,
      throwOnError: true,
    );
  }

  Future<Map<String, String>> _safeCurrentDeviceSnapshot() async {
    try {
      final deviceInfo = await DeviceManagerService()
          .getCurrentDeviceSnapshot();
      return Map<String, String>.from(deviceInfo);
    } catch (error) {
      debugPrint(
        '[HouseService] device snapshot unavailable: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể đọc thông tin thiết bị.').message}',
      );
      return const <String, String>{};
    }
  }

  Future<void> _waitForAuthenticatedSessionReady({
    bool forceRefreshToken = false,
  }) async {
    firebase_auth.User? user = _auth.currentUser;
    if (user == null) return;

    // Fast path: Lấy token trực tiếp không cần reload user profile để tránh một cuộc gọi mạng chậm dư thừa
    try {
      final token = await user
          .getIdToken(forceRefreshToken)
          .timeout(const Duration(seconds: 5));
      if ((token ?? '').trim().isNotEmpty) {
        return;
      }
    } catch (error) {
      debugPrint(
        '[HouseService] Fast getIdToken failed: $error. Falling back to retry loop.',
      );
    }

    // Slow retry path (nếu gặp lỗi mạng hoặc token trống)
    for (var attempt = 0; attempt < 3; attempt++) {
      user = _auth.currentUser ?? user;
      if (user != null) {
        try {
          await user.reload().timeout(const Duration(seconds: 3));
        } catch (error) {
          debugPrint(
            '[HouseService] user.reload skipped: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể làm mới phiên đăng nhập.').message}',
          );
        }

        user = _auth.currentUser ?? user;
        try {
          final token = await user
              .getIdToken(forceRefreshToken || attempt > 0)
              .timeout(const Duration(seconds: 4));
          if ((token ?? '').trim().isNotEmpty) {
            return;
          }
        } catch (error) {
          debugPrint(
            '[HouseService] getIdToken skipped: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể làm mới token đăng nhập.').message}',
          );
        }
      }

      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 300 + (attempt * 150)));
      }
    }
  }

  Future<void> _refreshCallableSecurityContext({
    bool force = false,
    bool throwOnAppCheckError = false,
  }) async {
    await _waitForAuthenticatedSessionReady(forceRefreshToken: force);
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseAppCheck.instance
          .getToken(force)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint(
        '[HouseService] App Check token warmup skipped: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể chuẩn bị App Check.').message}',
      );
      if (throwOnAppCheckError) {
        throw AppErrorInfo(
          kind: AppErrorKind.server,
          message: L10nService().translate(
            kDebugMode
                ? 'err_appcheck_debug_blocked'
                : 'err_appcheck_verifying_device',
          ),
        );
      }
    }
  }

  bool _isDebugAppCheckFailure(FirebaseFunctionsException error) {
    final message = (error.message ?? '').trim().toLowerCase();
    return message.contains('app check') ||
        message.contains('appcheck') ||
        message.contains('debug token') ||
        message.contains('play integrity') ||
        message.contains('attestation');
  }

  bool _shouldRetryCreateHouse(FirebaseFunctionsException error) {
    final code = error.code.trim().toLowerCase();
    return code == 'unauthenticated' ||
        code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        (_isDebugAppCheckFailure(error));
  }

  bool _isDeviceRequiredError(FirebaseFunctionsException error) {
    final message = (error.message ?? '').trim();
    final details = error.details;
    if (message == 'HOUSE_CREATION_DEVICE_REQUIRED') {
      return true;
    }
    if (details is Map) {
      final detailMap = Map<String, dynamic>.from(
        Map<dynamic, dynamic>.from(details),
      );
      final reason = detailMap['reason']?.toString().trim() ?? '';
      return reason == 'house_creation_device_required';
    }
    return false;
  }

  // iPhone mở app lần đầu phải lấy mã DeviceCheck trước khi gửi, còn máy chủ
  // cần ~7–8 giây để tạo nhà; mức 12 giây cũ từng hết giờ đúng lúc nhà vừa tạo xong.
  static const Duration _createHouseCallTimeout = Duration(seconds: 40);

  bool _mayHaveCreatedHouse(FirebaseFunctionsException error) {
    final code = error.code.trim().toLowerCase();
    return code == 'deadline-exceeded' ||
        code == 'unavailable' ||
        code == 'aborted' ||
        code == 'internal' ||
        code == 'unknown';
  }

  /// Lượt gọi tạo nhà bị hết giờ/mất kết nối vẫn có thể đã được máy chủ làm xong
  /// (`createHouseSecure` idempotent theo UID). Đọc lại vài lần trước khi báo lỗi
  /// để người dùng không bị kẹt ở màn tạo nhà dù nhà đã có.
  @visibleForTesting
  Future<String?> recoverHouseCreatedByServer(
    String uid, {
    List<Duration> delays = const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  }) async {
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (_auth.currentUser?.uid != uid) return null;
      try {
        final snap = await _dbRef
            .child('users/$uid/houseId')
            .get()
            .timeout(const Duration(seconds: 5));
        if (_auth.currentUser?.uid != uid) return null;
        final houseId = snap.value?.toString().trim() ?? '';
        if (houseId.isNotEmpty &&
            await _validateHouseMembership(uid, houseId)) {
          if (_auth.currentUser?.uid != uid) return null;
          return houseId;
        }
      } catch (error) {
        debugPrint('[HouseService] Recover created house skipped: $error');
      }
    }
    return null;
  }

  Future<HttpsCallableResult<dynamic>> _callCreateHouseSecureWithRetry(
    Map<String, dynamic> payload, {
    required String expectedUid,
  }) async {
    _requireCreationSession(expectedUid);
    await _refreshCallableSecurityContext(force: false);
    _requireCreationSession(expectedUid);
    try {
      return await CloudFunctionsHelper.callSecure<dynamic>(
        'createHouseSecure',
        payload: payload,
        timeout: _createHouseCallTimeout,
        throwOriginalException: true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldRetryCreateHouse(error)) {
        rethrow;
      }
      debugPrint(
        '[HouseService] createHouseSecure security sync retry: ${AppErrorMapper.resolve(error, fallbackMessage: 'Đang thử lại đồng bộ bảo mật.').message}',
      );
      await Future.delayed(const Duration(milliseconds: 700));
      _requireCreationSession(expectedUid);
      await _refreshCallableSecurityContext(force: true);
      _requireCreationSession(expectedUid);
      return await CloudFunctionsHelper.callSecure<dynamic>(
        'createHouseSecure',
        payload: payload,
        timeout: _createHouseCallTimeout,
        throwOriginalException: true,
      );
    }
  }

  void _requireCreationSession(String uid) {
    if (_auth.currentUser?.uid != uid) {
      throw firebase_auth.FirebaseAuthException(code: 'user-token-expired');
    }
  }

  Future<String> createHouseForCurrentUser({
    required String email,
    required String houseName,
    required String nameU1,
    required String nameU2,
    required String relationshipMode,
    String? recoveryQuestion,
    String? recoveryAnswer,
    String? houseCreationOtp,
    String createdWith = 'email',
    String? customHouseId,
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      await _waitForAuthenticatedSessionReady(forceRefreshToken: true);
      user = _auth.currentUser;
    }

    if (user == null) {
      throw UiCopyException('copy_5d6354a5c9ea');
    }

    final creationUid = user.uid;
    await _waitForAuthenticatedSessionReady(forceRefreshToken: true);
    _requireCreationSession(creationUid);

    final normalizedEmail = email.trim().toLowerCase();
    final rawHouseName = houseName.trim();
    final normalizedNameU1 = nameU1.trim().isNotEmpty
        ? nameU1.trim()
        : _defaultNameU1;
    final normalizedNameU2 = nameU2.trim().isNotEmpty
        ? nameU2.trim()
        : _defaultNameU2;
    final normalizedRelationshipMode =
        relationshipMode.trim().toLowerCase() == 'single' ? 'single' : 'couple';
    final normalizedRecoveryQuestion = (recoveryQuestion ?? '').trim();
    final normalizedRecoveryAnswer = (recoveryAnswer ?? '').trim();
    final normalizedCreatedWith = createdWith.trim().isNotEmpty
        ? createdWith.trim()
        : 'email';
    final deviceSnapshot = await _safeCurrentDeviceSnapshot();
    _requireCreationSession(creationUid);
    final identity = await DeviceInstallationIdentity.forUid(creationUid);
    _requireCreationSession(creationUid);
    final deviceId = identity.deviceId;
    final deviceModel = (deviceSnapshot['model'] ?? '').trim();
    final devicePlatform = (deviceSnapshot['platform'] ?? '').trim();
    if (deviceId.isEmpty) {
      throw UiCopyException('copy_457a7add0800');
    }

    try {
      final response = await _callCreateHouseSecureWithRetry(<String, dynamic>{
        'expectedUid': creationUid,
        'email': normalizedEmail,
        'houseName': rawHouseName,
        'nameU1': normalizedNameU1,
        'nameU2': normalizedNameU2,
        'relationshipMode': normalizedRelationshipMode,
        'recoveryQuestion': normalizedRecoveryQuestion,
        'recoveryAnswer': normalizedRecoveryAnswer,
        if ((houseCreationOtp ?? '').trim().isNotEmpty)
          'houseCreationOtp': houseCreationOtp!.trim(),
        'createdWith': normalizedCreatedWith,
        if (deviceId.isNotEmpty) 'deviceId': deviceId,
        'deviceProof': identity.proof,
        if (deviceModel.isNotEmpty) 'model': deviceModel,
        if (devicePlatform.isNotEmpty) 'platform': devicePlatform,
        if ((customHouseId ?? '').trim().isNotEmpty)
          'customHouseId': customHouseId!.trim(),
      }, expectedUid: creationUid);
      _requireCreationSession(creationUid);
      debugPrint('[HouseService] createHouseSecure success');
      final payload = _asStringDynamicMap(response.data);
      if (payload == null) {
        throw UiCopyException('copy_7af94c91604b');
      }
      final createdHouseId = payload['houseId']?.toString().trim() ?? '';
      if (createdHouseId.isEmpty) {
        throw UiCopyException('copy_7af94c91604b');
      }
      if (rawHouseName.isEmpty) {
        await _syncCreatedHouseDefaults(
          houseId: createdHouseId,
          houseName: _defaultHouseName,
          nameU1: normalizedNameU1,
          nameU2: normalizedNameU2,
          relationshipMode: normalizedRelationshipMode,
        );
        _requireCreationSession(creationUid);
      }
      return createdHouseId;
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      if (_mayHaveCreatedHouse(error)) {
        final recovered = await recoverHouseCreatedByServer(creationUid);
        if (recovered != null) return recovered;
      }
      if (message == 'house_creation_in_progress' ||
          message == 'house_creation_lease_expired' ||
          message == 'house_creation_membership_requires_review') {
        throw Exception(L10nService().translate('auth_signup_unavailable'));
      }
      if (_isDeviceRequiredError(error)) {
        throw UiCopyException('copy_457a7add0800');
      }
      if (message == 'house_creation_otp_required') {
        rethrow;
      }
      // Tạo nhà không còn bước xác minh Gmail: mã cũ kiểu HOUSE_CREATION_* (nếu
      // máy chủ cũ còn trả) chỉ hiện câu lỗi chung, không hiện mã thô hay đòi mã Gmail.
      if (message != null && message.startsWith('HOUSE_CREATION_')) {
        throw UiCopyException('copy_7af94c91604b');
      }
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      throw UiCopyException('copy_7af94c91604b');
    } on TimeoutException catch (error) {
      debugPrint(
        '[HouseService] createHouseSecure timed out: ${AppErrorMapper.resolve(error, fallbackMessage: 'Tạo nhà đang mất quá nhiều thời gian.').message}',
      );
      final recovered = await recoverHouseCreatedByServer(creationUid);
      if (recovered != null) return recovered;
      throw UiCopyException('copy_d106c4f33dee');
    }
  }

  Future<Map<String, dynamic>> checkHouseIdAvailability(
    String customHouseId,
  ) async {
    try {
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'checkHouseIdAvailability',
        payload: <String, dynamic>{'customHouseId': customHouseId.trim()},
      );
      final map = _asStringDynamicMap(response.data);
      if (map != null) {
        final suggestionsRaw = map['suggestions'];
        final suggestionsList = suggestionsRaw is List
            ? suggestionsRaw.map((e) => e.toString()).toList()
            : <String>[];
        return <String, dynamic>{
          'available': map['available'] == true,
          'reason': map['reason']?.toString(),
          'suggestions': suggestionsList,
        };
      }
      return <String, dynamic>{'available': false, 'suggestions': <String>[]};
    } catch (e) {
      debugPrint('[HouseService] checkHouseIdAvailability error: $e');
      return <String, dynamic>{
        'available': false,
        'reason': AppErrorMapper.resolve(e).message,
        'suggestions': <String>[],
      };
    }
  }

  Future<bool> changeHouseId(String newHouseId) async {
    try {
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'changeHouseIdSecure',
        payload: <String, dynamic>{'newHouseId': newHouseId.trim()},
      );
      final map = _asStringDynamicMap(response.data);
      final success = map?['success'] == true;
      if (success) {
        final updatedId = map?['newHouseId']?.toString().trim();
        if (updatedId != null && updatedId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('il_house_id', updatedId);
        }
      } else {
        final reason =
            map?['reason'] ?? map?['message'] ?? UiCopy.text('copy_351defc82d77');
        throw Exception(reason);
      }
      return success;
    } catch (e) {
      debugPrint('[HouseService] changeHouseId error: $e');
      throw Exception(AppErrorMapper.resolve(e).message);
    }
  }

  Future<void> joinHouseByAcceptedInvite() async {
    try {
      await _refreshCallableSecurityContext(force: false);
      final uid = _auth.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'joinHouseByInvite',
        requireAppCheck: true,
        payload: const <String, dynamic>{},
        fallbackErrorMessage:
            UiCopy.text('copy_fae030b2a9fa'),
      );

      final map = _asStringDynamicMap(response.data);
      if (map != null && map['houseId'] != null) {
        final newHouseId = map['houseId'].toString();
        // getCurrentHouseId ưu tiên secure storage; phải cập nhật cùng nơi
        // sau khi server chuyển nhà, tránh màn ghép nối đọc lại nhà cũ.
        if (uid != null && _auth.currentUser?.uid == uid) {
          await SecureStorageService.instance.write(
            SecureStorageService.keyHouseId,
            newHouseId,
          );
          await SecureStorageService.instance.write(
            SecureStorageService.keyAuthUid,
            uid,
          );
          if (map['assignedRole'] != null) {
            await SecureStorageService.instance.write(
              SecureStorageService.keyRole,
              map['assignedRole'].toString(),
            );
          }
          await SecureStorageService.instance.write(
            SecureStorageService.keyRelMode,
            'couple',
          );
          await prefs.remove('il_house_id');
          await prefs.remove('il_role');
          await prefs.remove(_authUidPrefsKey);
          _cachedSettings = null;
          await prefs.remove('il_offline_cache_home_settings');
        }
        return;
      }
      throw UiCopyException('copy_6c393420932f');
    } catch (e) {
      debugPrint('[HouseService] joinHouse error: $e');
      throw Exception(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              'Yêu cầu ghép nối chưa được chấp nhận hoặc đã hết hạn.',
        ).message,
      );
    }
  }

  Future<String?> getCurrentHouseId({bool preferFresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (_auth.currentUser?.uid != user.uid) return null;
    final prefsHouseId = prefs.getString('il_house_id')?.trim() ?? '';
    final prefsAuthUid = prefs.getString(_authUidPrefsKey)?.trim() ?? '';
    final usePrefs = prefsHouseId.isNotEmpty && prefsAuthUid == user.uid;
    final cachedHouseId = usePrefs
        ? prefsHouseId
        : (await SecureStorageService.instance.read(
                SecureStorageService.keyHouseId,
              ))?.trim() ??
              '';
    final cachedAuthUid = usePrefs
        ? prefsAuthUid
        : (await SecureStorageService.instance.read(
                SecureStorageService.keyAuthUid,
              ))?.trim() ??
              '';
    if (_auth.currentUser?.uid != user.uid) return null;

    if (cachedHouseId.isNotEmpty) {
      if (cachedAuthUid != user.uid) {
        await prefs.remove('il_house_id');
        if (_auth.currentUser?.uid != user.uid) return null;
        await prefs.remove('il_role');
      } else if (preferFresh) {
        final fresh = await _fetchAndCacheHouseId(
          user.uid,
          prefs,
          validateMembership: true,
        );
        if (_auth.currentUser?.uid != user.uid) return null;
        if (fresh != null && fresh.isNotEmpty) {
          _syncHouseIdToFirestore(user.uid, fresh).catchError((_) => null);
          return fresh;
        }

        final isMember = await _validateHouseMembership(
          user.uid,
          cachedHouseId,
        );
        if (_auth.currentUser?.uid != user.uid) return null;
        if (isMember) {
          _syncHouseIdToFirestore(
            user.uid,
            cachedHouseId,
          ).catchError((_) => null);
          return cachedHouseId;
        }

        await SecureStorageService.instance.delete(
          SecureStorageService.keyHouseId,
        );
        if (_auth.currentUser?.uid != user.uid) return null;
        await prefs.remove('il_house_id');
      } else {
        final now = DateTime.now();
        if (_lastFetchTime == null ||
            now.difference(_lastFetchTime!) > const Duration(minutes: 15)) {
          _fetchAndCacheHouseId(
            user.uid,
            prefs,
            validateMembership: true,
          ).catchError((_) => null);
        }
        _syncHouseIdToFirestore(
          user.uid,
          cachedHouseId,
        ).catchError((_) => null);
        return cachedHouseId;
      }
    }

    if (_auth.currentUser?.uid != user.uid) return null;
    final resolved = await _fetchAndCacheHouseId(
      user.uid,
      prefs,
      validateMembership: preferFresh,
    );
    if (resolved != null && resolved.isNotEmpty) {
      _syncHouseIdToFirestore(user.uid, resolved).catchError((_) => null);
    }
    return resolved;
  }

  Future<bool> isHouseUnpaired(String houseId) async {
    try {
      final snap = await _dbRef.child('houses/$houseId/members').get();
      if (snap.exists && snap.value is Map) {
        return (snap.value as Map).length <= 1;
      }
    } catch (e) {
      debugPrint('[HouseService] isHouseUnpaired error: $e');
    }
    return true; // Default to unpaired if we can't fetch or it has 1/0 members.
  }

  Future<String?> _fetchAndCacheHouseId(
    String uid,
    SharedPreferences prefs, {
    bool validateMembership = false,
  }) async {
    try {
      _lastFetchTime = DateTime.now();
      // ⚡ Parallelize reads of primary and legacy house IDs (2x faster)
      final results = await Future.wait([
        _dbRef
            .child('users/$uid/houseId')
            .get()
            .timeout(const Duration(seconds: 4)),
        _dbRef
            .child('users/$uid/house_id')
            .get()
            .timeout(const Duration(seconds: 4)),
      ]);
      if (_auth.currentUser?.uid != uid) return null;

      final primarySnap = results[0];
      final primaryValue = primarySnap.value?.toString().trim();
      if (primarySnap.exists &&
          primaryValue != null &&
          primaryValue.isNotEmpty &&
          (!validateMembership ||
              await _validateHouseMembership(uid, primaryValue))) {
        if (!await _cacheHouseIdForSession(uid, primaryValue, prefs)) {
          return null;
        }
        _syncHouseIdToFirestore(uid, primaryValue).catchError((_) => null);
        return primaryValue;
      }

      final legacySnap = results[1];
      final legacyValue = legacySnap.value?.toString().trim();
      if (legacySnap.exists &&
          legacyValue != null &&
          legacyValue.isNotEmpty &&
          (!validateMembership ||
              await _validateHouseMembership(uid, legacyValue))) {
        if (_auth.currentUser?.uid != uid) return null;
        await _dbRef.child('users/$uid').update({'houseId': legacyValue});
        if (!await _cacheHouseIdForSession(uid, legacyValue, prefs)) {
          return null;
        }
        _syncHouseIdToFirestore(uid, legacyValue).catchError((_) => null);
        return legacyValue;
      }

      // 🔍 Firestore fallback: Kiểm tra collection('users').doc(uid)
      try {
        final firestoreDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));
        if (_auth.currentUser?.uid != uid) return null;
        if (firestoreDoc.exists && firestoreDoc.data() != null) {
          final fsHouseId =
              (firestoreDoc.data()!['houseId'] ??
                      firestoreDoc.data()!['house_id'])
                  ?.toString()
                  .trim();
          if (fsHouseId != null &&
              fsHouseId.isNotEmpty &&
              (!validateMembership ||
                  await _validateHouseMembership(uid, fsHouseId))) {
            if (_auth.currentUser?.uid != uid) return null;
            await _dbRef.child('users/$uid').update({'houseId': fsHouseId});
            if (!await _cacheHouseIdForSession(uid, fsHouseId, prefs)) {
              return null;
            }
            return fsHouseId;
          }
        }
      } catch (e) {
        debugPrint('[HouseService] Firestore houseId lookup error: $e');
      }

      try {
        final ownerQuerySnap = await _dbRef
            .child('houses')
            .orderByChild('owner_uid')
            .equalTo(uid)
            .limitToFirst(1)
            .get()
            .timeout(const Duration(seconds: 4));
        if (_auth.currentUser?.uid != uid) return null;
        if (ownerQuerySnap.exists && ownerQuerySnap.children.isNotEmpty) {
          final foundHouseId = ownerQuerySnap.children.first.key?.trim() ?? '';
          if (foundHouseId.isNotEmpty) {
            await _dbRef.child('users/$uid').update({'houseId': foundHouseId});
            if (!await _cacheHouseIdForSession(uid, foundHouseId, prefs)) {
              return null;
            }
            return foundHouseId;
          }
        }
      } catch (error) {
        debugPrint('[HouseService] Fallback house query failed: $error');
      }
    } on TimeoutException {
      // Fallback cache below handles slow network without spamming logs.
    } catch (e) {
      debugPrint(
        'Error resolving house id: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể xác định mã nhà.').message}',
      );
    }

    if (_auth.currentUser?.uid != uid) return null;
    final fallbackUid = await SecureStorageService.instance.read(
      SecureStorageService.keyAuthUid,
    );
    final fallback =
        (await SecureStorageService.instance.read(
          SecureStorageService.keyHouseId,
        ))?.trim() ??
        '';
    if (fallback.isEmpty ||
        fallbackUid != uid ||
        _auth.currentUser?.uid != uid) {
      return null;
    }
    if (!validateMembership || await _validateHouseMembership(uid, fallback)) {
      if (_auth.currentUser?.uid != uid) return null;
      await SecureStorageService.instance.write(
        SecureStorageService.keyAuthUid,
        uid,
      );
      _syncHouseIdToFirestore(uid, fallback).catchError((_) => null);
      return fallback;
    }
    return null;
  }

  Future<bool> _cacheHouseIdForSession(
    String uid,
    String houseId,
    SharedPreferences prefs,
  ) async {
    if (_auth.currentUser?.uid != uid) return false;
    await SecureStorageService.instance.write(
      SecureStorageService.keyHouseId,
      houseId,
    );
    if (_auth.currentUser?.uid != uid) return false;
    await SecureStorageService.instance.write(
      SecureStorageService.keyAuthUid,
      uid,
    );
    if (_auth.currentUser?.uid != uid) return false;
    await prefs.remove('il_house_id');
    if (_auth.currentUser?.uid != uid) return false;
    await prefs.remove(_authUidPrefsKey);
    return _auth.currentUser?.uid == uid;
  }

  Future<bool> _validateHouseMembership(String uid, String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return false;
    }

    try {
      final ownerSnap = await _dbRef
          .child('houses/$normalizedHouseId/owner_uid')
          .get()
          .timeout(const Duration(seconds: 5));
      final ownerUid = ownerSnap.value?.toString().trim() ?? '';
      if (ownerUid.isNotEmpty && ownerUid == uid) {
        return true;
      }

      final memberSnap = await _dbRef
          .child('houses/$normalizedHouseId/members/$uid')
          .get()
          .timeout(const Duration(seconds: 5));
      if (memberSnap.exists) {
        return true;
      }
    } catch (e) {
      debugPrint('[HouseService] Error validating house membership: $e');
      return false;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getHouseSettings(String houseId) async {
    if (_cachedSettings != null) {
      return _cachedSettings;
    }

    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final cached = prefs.getString('il_offline_cache_home_settings');
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          final data = _asStringDynamicMap(decoded['data']);
          if (data != null) {
            _cachedSettings = data;
            // Fetch newest from server in background to refresh local cache
            unawaited(_fetchSettingsFromServerAndCache(houseId, prefs));
            return data;
          }
        }
      } catch (error) {
        debugPrint('[HouseService] Home settings cache hỏng: $error');
        await prefs.remove('il_offline_cache_home_settings');
      }
    }

    return await _fetchSettingsFromServerAndCache(houseId, prefs);
  }

  Future<Map<String, dynamic>?> _fetchSettingsFromServerAndCache(
    String houseId,
    SharedPreferences prefs,
  ) async {
    try {
      final snap = await _dbRef
          .child('houses/$houseId/settings')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists) {
        final data = _asStringDynamicMap(snap.value);
        if (data != null) {
          _cachedSettings = data;
          await prefs.setString(
            'il_offline_cache_home_settings',
            jsonEncode({
              'data': data,
              'ts': DateTime.now().millisecondsSinceEpoch,
            }),
          );
          return data;
        }
      }
    } catch (error) {
      debugPrint('[HouseService] Không tải được settings từ server: $error');
    }
    return null;
  }

  Future<void> _syncCreatedHouseDefaults({
    required String houseId,
    required String houseName,
    required String nameU1,
    required String nameU2,
    required String relationshipMode,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _dbRef.update(<String, dynamic>{
      'houses/$houseId/houseName': houseName,
      'houses/$houseId/settings/houseName': houseName,
      'houses/$houseId/settings/nameU1': nameU1,
      'houses/$houseId/settings/nameU2': nameU2,
      'houses/$houseId/settings/relationshipMode': relationshipMode,
      'houses/$houseId/updatedAt': nowMs,
      'houses/$houseId/settings/updatedAt': nowMs,
      'house_profiles/$houseId/houseName': houseName,
      'house_profiles/$houseId/nameU1': nameU1,
      'house_profiles/$houseId/nameU2': nameU2,
      'house_profiles/$houseId/settings/houseName': houseName,
      'house_profiles/$houseId/settings/nameU1': nameU1,
      'house_profiles/$houseId/settings/nameU2': nameU2,
      'house_profiles/$houseId/settings/relationshipMode': relationshipMode,
      'house_profiles/$houseId/updatedAt': nowMs,
      'house_profiles/$houseId/updated_at': nowMs,
      'houses_public/$houseId/houseName': houseName,
      'houses_public/$houseId/settings/houseName': houseName,
      'houses_public/$houseId/settings/relationshipMode': relationshipMode,
      'houses_public/$houseId/updatedAt': nowMs,
      'houses_public/$houseId/updated_at': nowMs,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        displayName: nameU1,
        houseName: houseName,
        avatarUrl: '',
        bio: '',
        dobU1: '',
        relationshipMode: relationshipMode,
        privacy: 'public',
        searchPrivacy: true,
        updatedAt: nowMs,
      ),
    });
  }
}
