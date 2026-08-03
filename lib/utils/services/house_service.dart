import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
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
import 'core/cloud_functions_helper.dart';
import 'offline_cache_service.dart';
import 'secure_storage_service.dart';

class HouseCreationOtpRequiredException implements Exception {
  final String maskedEmail;
  final int createdCount;

  const HouseCreationOtpRequiredException({
    required this.maskedEmail,
    required this.createdCount,
  });

  @override
  String toString() => 'Cần xác minh Gmail để tiếp tục tạo nhà.';
}

class HouseService {
  static DateTime? _lastFetchTime;
  static Map<String, dynamic>? _cachedSettings;
  static const String _defaultHouseName = 'Chúng mình';
  static const String _defaultNameU1 = 'Bạn Nam';
  static const String _defaultNameU2 = 'Bạn Nữ';

  static const String _authUidPrefsKey = 'il_auth_uid';

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

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
  bool get _allowLegacyDirectCreateFallback => false;

  Future<void> _syncHouseIdToFirestore(String uid, String houseId) async {
    if (houseId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'houseId': houseId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HouseService] Firestore houseId sync failed: $e');
    }
  }

  Future<Map<String, String>> _safeCurrentDeviceSnapshot() async {
    try {
      final deviceInfo =
          await DeviceManagerService().getCurrentDeviceSnapshot();
      return Map<String, String>.from(deviceInfo);
    } catch (error) {
      debugPrint(
          '[HouseService] device snapshot unavailable: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể đọc thông tin thiết bị.',
      ).message}');
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
          '[HouseService] Fast getIdToken failed: $error. Falling back to retry loop.');
    }

    // Slow retry path (nếu gặp lỗi mạng hoặc token trống)
    for (var attempt = 0; attempt < 3; attempt++) {
      user = _auth.currentUser ?? user;
      if (user != null) {
        try {
          await user.reload().timeout(const Duration(seconds: 3));
        } catch (error) {
          debugPrint(
              '[HouseService] user.reload skipped: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể làm mới phiên đăng nhập.',
          ).message}');
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
              '[HouseService] getIdToken skipped: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể làm mới token đăng nhập.',
          ).message}');
        }
      }

      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 300 + (attempt * 150)));
      }
    }
  }

  Future<void> _refreshCallableSecurityContext({bool force = false}) async {
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
          '[HouseService] App Check token warmup skipped: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể chuẩn bị App Check.',
      ).message}');
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

  HouseCreationOtpRequiredException? _otpRequiredFromError(
    FirebaseFunctionsException error,
  ) {
    final message = (error.message ?? '').trim();
    final details = error.details;
    Map<String, dynamic>? detailMap;
    if (details is Map) {
      detailMap =
          Map<String, dynamic>.from(Map<dynamic, dynamic>.from(details));
    }
    final reason = detailMap?['reason']?.toString().trim() ?? '';
    if (message != 'HOUSE_CREATION_OTP_REQUIRED' &&
        reason != 'house_creation_otp_required') {
      return null;
    }
    return HouseCreationOtpRequiredException(
      maskedEmail: detailMap?['maskedEmail']?.toString().trim() ?? '',
      createdCount: int.tryParse(
            detailMap?['createdCount']?.toString() ?? '',
          ) ??
          3,
    );
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

  Future<HttpsCallableResult<dynamic>> _callCreateHouseSecureWithRetry(
    Map<String, dynamic> payload,
  ) async {
    await _refreshCallableSecurityContext(force: false);
    try {
      return await CloudFunctionsHelper.callSecure<dynamic>(
        'createHouseSecure',
        payload: payload,
        timeout: const Duration(seconds: 12),
        throwOriginalException: true,
      );
    } on FirebaseFunctionsException catch (error) {
      final otpRequired = _otpRequiredFromError(error);
      if (otpRequired != null) {
        throw otpRequired;
      }
      if (!_shouldRetryCreateHouse(error)) {
        rethrow;
      }
      debugPrint(
          '[HouseService] createHouseSecure security sync retry: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Đang thử lại đồng bộ bảo mật.',
      ).message}');
      await Future.delayed(const Duration(milliseconds: 700));
      await _refreshCallableSecurityContext(force: true);
      return await CloudFunctionsHelper.callSecure<dynamic>(
        'createHouseSecure',
        payload: payload,
        timeout: const Duration(seconds: 12),
        throwOriginalException: true,
      );
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
    String createdWith = 'email',
    String? otp,
    String? customHouseId,
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      await _waitForAuthenticatedSessionReady(forceRefreshToken: true);
      user = _auth.currentUser;
    }

    if (user == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    await _waitForAuthenticatedSessionReady(forceRefreshToken: true);
    user = _auth.currentUser ?? user;

    final normalizedEmail = email.trim().toLowerCase();
    final rawHouseName = houseName.trim();
    final normalizedNameU1 =
        nameU1.trim().isNotEmpty ? nameU1.trim() : _defaultNameU1;
    final normalizedNameU2 =
        nameU2.trim().isNotEmpty ? nameU2.trim() : _defaultNameU2;
    final normalizedRelationshipMode =
        relationshipMode.trim().toLowerCase() == 'single' ? 'single' : 'couple';
    final normalizedRecoveryQuestion = (recoveryQuestion ?? '').trim();
    final normalizedRecoveryAnswer = (recoveryAnswer ?? '').trim();
    final normalizedCreatedWith =
        createdWith.trim().isNotEmpty ? createdWith.trim() : 'email';
    final deviceSnapshot = await _safeCurrentDeviceSnapshot();
    final deviceId = (deviceSnapshot['deviceId'] ?? '').trim();
    final deviceModel = (deviceSnapshot['model'] ?? '').trim();
    final devicePlatform = (deviceSnapshot['platform'] ?? '').trim();
    if (deviceId.isEmpty) {
      throw Exception(
        'Không thể xác thực thiết bị để tạo nhà. Vui lòng mở lại ứng dụng và thử lại.',
      );
    }

    Future<String> createDirectFallback() {
      return _createHouseDirectly(
        email: normalizedEmail,
        houseName: rawHouseName,
        nameU1: normalizedNameU1,
        nameU2: normalizedNameU2,
        relationshipMode: normalizedRelationshipMode,
        recoveryQuestion: normalizedRecoveryQuestion,
        recoveryAnswer: normalizedRecoveryAnswer,
        createdWith: normalizedCreatedWith,
        customHouseId: customHouseId,
      );
    }

    Future<String> createAdminDebugFallback() async {
      final payload = <String, dynamic>{
        'email': normalizedEmail,
        'houseName': rawHouseName,
        'nameU1': normalizedNameU1,
        'nameU2': normalizedNameU2,
        'relationshipMode': normalizedRelationshipMode,
        'recoveryQuestion': normalizedRecoveryQuestion,
        'recoveryAnswer': normalizedRecoveryAnswer,
        'createdWith': normalizedCreatedWith,
        if (deviceId.isNotEmpty) 'deviceId': deviceId,
        if (deviceModel.isNotEmpty) 'model': deviceModel,
        if (devicePlatform.isNotEmpty) 'platform': devicePlatform,
        if ((customHouseId ?? '').trim().isNotEmpty)
          'customHouseId': customHouseId!.trim(),
      };
      debugPrint('[HouseService] Admin debug createHouseSecure start');
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'createHouseSecureAdminDebug',
        payload: payload,
        timeout: const Duration(seconds: 12),
      );
      debugPrint('[HouseService] Admin debug createHouseSecure success');
      final resultPayload = _asStringDynamicMap(response.data);
      final createdHouseId = resultPayload?['houseId']?.toString().trim() ?? '';
      if (createdHouseId.isEmpty) {
        throw Exception('Không thể tạo nhà mới lúc này.');
      }
      return createdHouseId;
    }

    try {
      final response = await _callCreateHouseSecureWithRetry(<String, dynamic>{
        'email': normalizedEmail,
        'houseName': rawHouseName,
        'nameU1': normalizedNameU1,
        'nameU2': normalizedNameU2,
        'relationshipMode': normalizedRelationshipMode,
        'recoveryQuestion': normalizedRecoveryQuestion,
        'recoveryAnswer': normalizedRecoveryAnswer,
        'createdWith': normalizedCreatedWith,
        if (deviceId.isNotEmpty) 'deviceId': deviceId,
        if (deviceModel.isNotEmpty) 'model': deviceModel,
        if (devicePlatform.isNotEmpty) 'platform': devicePlatform,
        if ((otp ?? '').trim().isNotEmpty) 'otp': otp!.trim(),
        if ((customHouseId ?? '').trim().isNotEmpty)
          'customHouseId': customHouseId!.trim(),
      });
      debugPrint('[HouseService] createHouseSecure success');
      final payload = _asStringDynamicMap(response.data);
      if (payload == null) {
        throw Exception('Không thể tạo nhà mới lúc này.');
      }
      final createdHouseId = payload['houseId']?.toString().trim() ?? '';
      if (createdHouseId.isEmpty) {
        throw Exception('Không thể tạo nhà mới lúc này.');
      }
      if (rawHouseName.isEmpty) {
        await _syncCreatedHouseDefaults(
          houseId: createdHouseId,
          houseName: _defaultHouseName,
          nameU1: normalizedNameU1,
          nameU2: normalizedNameU2,
          relationshipMode: normalizedRelationshipMode,
        );
      }
      return createdHouseId;
    } on HouseCreationOtpRequiredException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      final otpRequired = _otpRequiredFromError(error);
      if (otpRequired != null) {
        throw otpRequired;
      }
      if (_isDebugAppCheckFailure(error) && _allowLegacyDirectCreateFallback) {
        try {
          return await createAdminDebugFallback();
        } catch (adminDebugError) {
          debugPrint(
            '[HouseService] createHouseSecureAdminDebug failed: ${AppErrorMapper.resolve(
              adminDebugError,
              fallbackMessage: 'Không thể tạo nhà bằng kênh dự phòng.',
            ).message}',
          );
        }
        debugPrint(
            '[HouseService] createHouseSecure blocked, using direct fallback: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Tạo nhà bảo mật bị chặn.',
        ).message}');
        return createDirectFallback();
      }

      final message = error.message?.trim();
      if (_isDeviceRequiredError(error)) {
        throw Exception(
          'Không thể xác thực thiết bị để tạo nhà. Vui lòng mở lại ứng dụng và thử lại.',
        );
      }
      if (message == 'HOUSE_CREATION_EMAIL_VERIFICATION_REQUIRED') {
        throw Exception(
          'Bạn cần xác minh email trước khi tạo thêm nhà trên thiết bị này.',
        );
      }
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      throw Exception('Không thể tạo nhà mới lúc này.');
    } on TimeoutException catch (error) {
      debugPrint(
        '[HouseService] createHouseSecure timed out: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Tạo nhà đang mất quá nhiều thời gian.',
        ).message}',
      );
      if (_allowLegacyDirectCreateFallback) {
        return createDirectFallback();
      }
      throw Exception(
          'Tạo ngôi nhà đang mất quá nhiều thời gian. Vui lòng thử lại.');
    }
  }

  Future<Map<String, dynamic>> checkHouseIdAvailability(
      String customHouseId) async {
    try {
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'checkHouseIdAvailability',
        payload: <String, dynamic>{
          'customHouseId': customHouseId.trim(),
        },
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
        payload: <String, dynamic>{
          'newHouseId': newHouseId.trim(),
        },
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
            map?['reason'] ?? map?['message'] ?? 'Đổi mã nhà không thành công.';
        throw Exception(reason);
      }
      return success;
    } catch (e) {
      debugPrint('[HouseService] changeHouseId error: $e');
      throw Exception(AppErrorMapper.resolve(e).message);
    }
  }

  Future<void> joinHouseWithCoupleCode(String coupleCode) async {
    try {
      final code = coupleCode.trim();
      if (code.isEmpty) {
        throw Exception('Vui lòng nhập mã ghép nối.');
      }

      await _refreshCallableSecurityContext(force: false);

      final prefs = await SharedPreferences.getInstance();
      final oldHouseId = prefs.getString('il_house_id');

      // Kiểm tra tính hợp lệ của mã trước khi dọn dẹp dữ liệu tránh xoá nhầm
      bool isCodeOrHouseValid = false;
      if (code.length == 12 && int.tryParse(code) != null) {
        isCodeOrHouseValid = await FirebaseDatabase.instance
            .ref('pairing_codes/$code')
            .get()
            .then((snap) => snap.exists);
      } else {
        isCodeOrHouseValid = await FirebaseDatabase.instance
            .ref('houses/$code/settings')
            .get()
            .then((snap) => snap.exists);
      }

      if (isCodeOrHouseValid &&
          oldHouseId != null &&
          oldHouseId.isNotEmpty &&
          oldHouseId != code) {
        // Chỉ dọn dẹp khi người dùng cũ ở chế độ độc thân (chỉ có tối đa 1 thành viên)
        try {
          final oldMembersSnap = await FirebaseDatabase.instance
              .ref('houses/$oldHouseId/members')
              .get();
          if (!oldMembersSnap.exists ||
              (oldMembersSnap.value is Map &&
                  (oldMembersSnap.value as Map).length <= 1)) {
            // Thực hiện xoá vật lý dữ liệu Firestore trước khi cập nhật quyền (houseId) mới
            final diariesSnap = await FirebaseFirestore.instance
                .collection('houses')
                .doc(oldHouseId)
                .collection('diaries')
                .get();
            final albumSnap = await FirebaseFirestore.instance
                .collection('houses')
                .doc(oldHouseId)
                .collection('album')
                .get();
            final trashSnap = await FirebaseFirestore.instance
                .collection('houses')
                .doc(oldHouseId)
                .collection('album_trash')
                .get();
            final chatSnap = await FirebaseFirestore.instance
                .collection('houses')
                .doc(oldHouseId)
                .collection('chat_room_messages')
                .get();

            final batch = FirebaseFirestore.instance.batch();
            for (var doc in diariesSnap.docs) {
              batch.delete(doc.reference);
            }
            for (var doc in albumSnap.docs) {
              batch.delete(doc.reference);
            }
            for (var doc in trashSnap.docs) {
              batch.delete(doc.reference);
            }
            for (var doc in chatSnap.docs) {
              batch.delete(doc.reference);
            }
            await batch.commit();
            debugPrint(
                '[HouseService] Old house Firestore data deleted: $oldHouseId');
          }
        } catch (e) {
          debugPrint(
              '[HouseService] Failed to delete old house Firestore data: $e');
        }
      }

      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'joinHouseSecure',
        payload: <String, dynamic>{
          'houseId': code,
        },
      );

      final map = _asStringDynamicMap(response.data);
      if (map != null && map['houseId'] != null) {
        // Success
        final newHouseId = map['houseId'].toString();

        // Dọn dẹp nhà cũ (nhà độc thân) trước khi nhận token mới
        if (oldHouseId != null &&
            oldHouseId.isNotEmpty &&
            oldHouseId != newHouseId) {
          try {
            final oldMembersSnap = await FirebaseDatabase.instance
                .ref('houses/$oldHouseId/members')
                .get();
            if (!oldMembersSnap.exists ||
                (oldMembersSnap.value is Map &&
                    (oldMembersSnap.value as Map).length <= 1)) {
              await FirebaseDatabase.instance
                  .ref('houses/$oldHouseId')
                  .remove();
              await FirebaseDatabase.instance
                  .ref('houses_public/$oldHouseId')
                  .remove();
            }
          } catch (_) {}
        }

        await prefs.setString('il_house_id', newHouseId);
        if (map['assignedRole'] != null) {
          await prefs.setString('il_role', map['assignedRole'].toString());
        }
        return;
      }
      throw Exception('Không thể ghép nối mã nhà lúc này.');
    } catch (e) {
      debugPrint('[HouseService] joinHouse error: $e');
      throw Exception(AppErrorMapper.resolve(e,
              fallbackMessage: 'Mã ghép nối không hợp lệ hoặc đã hết hạn.')
          .message);
    }
  }

  Future<String?> getCurrentHouseId({bool preferFresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await SecureStorageService.instance.migrateFromPrefs(
        SecureStorageService.keyHouseId, prefs.getString('il_house_id'));
    await SecureStorageService.instance.migrateFromPrefs(
        SecureStorageService.keyAuthUid, prefs.getString(_authUidPrefsKey));
    final cachedHouseId = (await SecureStorageService.instance
                .read(SecureStorageService.keyHouseId))
            ?.trim() ??
        '';
    final cachedAuthUid = (await SecureStorageService.instance
                .read(SecureStorageService.keyAuthUid))
            ?.trim() ??
        '';

    if (cachedHouseId.isNotEmpty) {
      if (cachedAuthUid != user.uid) {
        await SecureStorageService.instance
            .delete(SecureStorageService.keyHouseId);
        await SecureStorageService.instance
            .delete(SecureStorageService.keyRole);
        await prefs.remove('il_house_id');
        await prefs.remove('il_role');
      } else if (preferFresh) {
        final fresh = await _fetchAndCacheHouseId(
          user.uid,
          prefs,
          validateMembership: true,
        );
        if (fresh != null && fresh.isNotEmpty) {
          _syncHouseIdToFirestore(user.uid, fresh).catchError((_) => null);
          return fresh;
        }

        if (await _validateHouseMembership(user.uid, cachedHouseId)) {
          _syncHouseIdToFirestore(user.uid, cachedHouseId)
              .catchError((_) => null);
          return cachedHouseId;
        }

        await SecureStorageService.instance
            .delete(SecureStorageService.keyHouseId);
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
        _syncHouseIdToFirestore(user.uid, cachedHouseId)
            .catchError((_) => null);
        return cachedHouseId;
      }
    }

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
            .timeout(const Duration(seconds: 10)),
        _dbRef
            .child('users/$uid/house_id')
            .get()
            .timeout(const Duration(seconds: 10)),
      ]);

      final primarySnap = results[0];
      final primaryValue = primarySnap.value?.toString().trim();
      if (primarySnap.exists &&
          primaryValue != null &&
          primaryValue.isNotEmpty &&
          (!validateMembership ||
              await _validateHouseMembership(uid, primaryValue))) {
        await SecureStorageService.instance
            .write(SecureStorageService.keyHouseId, primaryValue);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, uid);
        await prefs.remove('il_house_id');
        await prefs.remove(_authUidPrefsKey);
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
        await _dbRef.child('users/$uid').update({'houseId': legacyValue});
        await SecureStorageService.instance
            .write(SecureStorageService.keyHouseId, legacyValue);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, uid);
        await prefs.remove('il_house_id');
        await prefs.remove(_authUidPrefsKey);
        _syncHouseIdToFirestore(uid, legacyValue).catchError((_) => null);
        return legacyValue;
      }

      try {
        final ownerQuerySnap = await _dbRef
            .child('houses')
            .orderByChild('owner_uid')
            .equalTo(uid)
            .limitToFirst(1)
            .get()
            .timeout(const Duration(seconds: 4));
        if (ownerQuerySnap.exists && ownerQuerySnap.children.isNotEmpty) {
          final foundHouseId = ownerQuerySnap.children.first.key?.trim() ?? '';
          if (foundHouseId.isNotEmpty) {
            await _dbRef.child('users/$uid').update({'houseId': foundHouseId});
            await SecureStorageService.instance
                .write(SecureStorageService.keyHouseId, foundHouseId);
            await SecureStorageService.instance
                .write(SecureStorageService.keyAuthUid, uid);
            await prefs.remove('il_house_id');
            await prefs.remove(_authUidPrefsKey);
            return foundHouseId;
          }
        }
      } catch (_) {}
    } on TimeoutException {
      // Fallback cache below handles slow network without spamming logs.
    } catch (e) {
      debugPrint('Error resolving house id: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xác định mã nhà.',
      ).message}');
    }

    final fallback = (await SecureStorageService.instance
                .read(SecureStorageService.keyHouseId))
            ?.trim() ??
        '';
    if (fallback.isEmpty) {
      return null;
    }
    if (!validateMembership || await _validateHouseMembership(uid, fallback)) {
      await SecureStorageService.instance
          .write(SecureStorageService.keyAuthUid, uid);
      _syncHouseIdToFirestore(uid, fallback).catchError((_) => null);
      return fallback;
    }
    return null;
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
          .timeout(const Duration(seconds: 8));
      if ((ownerSnap.value?.toString().trim() ?? '') == uid) {
        return true;
      }

      final memberSnap = await _dbRef
          .child('houses/$normalizedHouseId/members/$uid')
          .get()
          .timeout(const Duration(seconds: 8));
      return memberSnap.exists;
    } on TimeoutException {
      return false;
    } catch (e) {
      debugPrint('Error validating house membership: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xác minh thành viên nhà.',
      ).message}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getHouseSettings(String houseId) async {
    if (_cachedSettings != null) {
      return _cachedSettings;
    }

    final prefs = OfflineCacheService.getPrefsSync() ??
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
      } catch (_) {}
    }

    return await _fetchSettingsFromServerAndCache(houseId, prefs);
  }

  Future<Map<String, dynamic>?> _fetchSettingsFromServerAndCache(
      String houseId, SharedPreferences prefs) async {
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
    } catch (_) {}
    return null;
  }

  Future<String> _createHouseDirectly({
    required String email,
    required String houseName,
    required String nameU1,
    required String nameU2,
    required String relationshipMode,
    required String recoveryQuestion,
    required String recoveryAnswer,
    required String createdWith,
    String? customHouseId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Bạn chưa đăng nhập.');
    }

    final currentHouseId = await getCurrentHouseId(preferFresh: true);
    if (currentHouseId != null && currentHouseId.isNotEmpty) {
      final ownerUid =
          (await _dbRef.child('houses/$currentHouseId/owner_uid').get())
                  .value
                  ?.toString()
                  .trim() ??
              '';
      if (ownerUid == user.uid) {
        throw Exception('Tài khoản này đã có nhà. Vui lòng vào nhà hiện tại.');
      }
    }

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final startDate = now.toIso8601String().substring(0, 10);

    String newHouseId;
    if (customHouseId != null && customHouseId.trim().isNotEmpty) {
      newHouseId = customHouseId.trim().toUpperCase();
      if (!RegExp(r'^[A-Z0-9_]{3,20}$').hasMatch(newHouseId)) {
        throw Exception(
            'Mã nhà tự chọn chỉ gồm chữ, số, dấu gạch dưới và từ 3 đến 20 ký tự.');
      }
      final existsSnap =
          await _dbRef.child('houses/$newHouseId/owner_uid').get();
      if (existsSnap.exists) {
        throw Exception('Mã nhà này đã tồn tại, vui lòng chọn mã khác.');
      }
    } else {
      newHouseId = await _generateUniqueHouseId();
    }
    final resolvedHouseName =
        houseName.trim().isNotEmpty ? houseName.trim() : _defaultHouseName;
    final hasRecovery =
        recoveryQuestion.isNotEmpty && recoveryAnswer.isNotEmpty;

    final updates = <String, dynamic>{
      'houses/$newHouseId': {
        'houseName': resolvedHouseName,
        'owner_uid': user.uid,
        'security': {
          'email': email,
          if (hasRecovery)
            'recovery': {
              'question': recoveryQuestion,
              'answerHash': _hashRecoveryAnswer(recoveryAnswer),
              'configuredAt': nowMs,
            },
        },
        'members': {
          user.uid: {
            'uid': user.uid,
            'displayName': (user.displayName ?? '').trim(),
            'photoURL': (user.photoURL ?? '').trim(),
            'role': 'user1',
            'joinedAt': nowMs,
          },
        },
        'createdWith': createdWith,
        'createdAt': nowMs,
        'updatedAt': nowMs,
        'settings': {
          'theme': 'theme-auto',
          'countdownSizePx': 400,
          'startDate': startDate,
          'font': "'Quicksand', sans-serif",
          'privacy': 'public',
          'friendRequestPolicy': 'all',
          'friendRequestLimit': 30,
          'homeBlockTone': 'theme',
          'countdownStyle': 'default',
          'houseName': resolvedHouseName,
          'nameU1': nameU1,
          'nameU2': nameU2,
          'dayUnit': 'ngày yêu',
          'avtUser1': '',
          'avtUser2': '',
          'houseAvatar': '',
          'relationshipMode': relationshipMode,
          'updatedAt': nowMs,
        },
      },
      'house_profiles/$newHouseId': {
        'houseName': resolvedHouseName,
        'nameU1': nameU1,
        'nameU2': nameU2,
        'startDate': startDate,
        'dayUnit': 'ngày yêu',
        'relationshipMode': relationshipMode,
        'houseAvatar': '',
        'avatar': '',
        'settings': {
          'houseName': resolvedHouseName,
          'houseAvatar': '',
          'relationshipMode': relationshipMode,
          'startDate': startDate,
          'dayUnit': 'ngày yêu',
          'nameU1': nameU1,
          'nameU2': nameU2,
        },
        'updatedAt': nowMs,
        'updated_at': nowMs,
      },
      'houses_public/$newHouseId': {
        'houseName': resolvedHouseName,
        'startDate': startDate,
        'dayUnit': 'ngày yêu',
        'relationshipMode': relationshipMode,
        'houseAvatar': '',
        'avatar': '',
        'settings': {
          'houseName': resolvedHouseName,
          'houseAvatar': '',
          'relationshipMode': relationshipMode,
          'startDate': startDate,
          'dayUnit': 'ngày yêu',
        },
        'recovery_hint': _maskEmail(email),
        'recovery_ready': email.isNotEmpty,
        'updatedAt': nowMs,
        'updated_at': nowMs,
      },
      'users/${user.uid}/houseId': newHouseId,
      'users/${user.uid}/house_id': newHouseId,
      'users/${user.uid}/email': email,
      'users/${user.uid}/role': 'owner',
    };

    if (currentHouseId != null && currentHouseId.isNotEmpty) {
      updates['houses/$currentHouseId/members/${user.uid}'] = null;
      updates['houses/$currentHouseId/fcmTokens/${user.uid}'] = null;
    }

    await _dbRef.update(updates);
    return newHouseId;
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

  Future<String> _generateUniqueHouseId() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final candidate = _generateHouseId();
      final snapshot = await _dbRef.child('houses/$candidate/owner_uid').get();
      if (!snapshot.exists) {
        return candidate;
      }
    }
    throw Exception('Không thể tạo mã nhà mới lúc này.');
  }

  String _generateHouseId() {
    final base36 =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final suffix = Random.secure()
        .nextInt(0x10000)
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return 'NH_$base36$suffix';
  }

  String _hashRecoveryAnswer(String answer) {
    return crypto.sha256
        .convert(utf8.encode(answer.trim().toLowerCase()))
        .toString();
  }

  String _maskEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final parts = normalized.split('@');
    if (parts.length != 2 || parts.first.isEmpty) {
      return '';
    }
    final local = parts.first;
    final domain = parts.last;
    if (local.length <= 4) {
      return '${local[0]}${List.filled(local.length - 1, '*').join()}@$domain';
    }
    final firstTwo = local.substring(0, 2);
    final lastTwo = local.substring(local.length - 2);
    final middleMask = List.filled(local.length - 4, '*').join();
    return '$firstTwo$middleMask$lastTwo@$domain';
  }
}
