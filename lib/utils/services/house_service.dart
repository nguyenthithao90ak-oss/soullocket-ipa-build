import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/device_manager_service.dart';
import '../../services/single_match_service.dart';

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
  static const String _defaultHouseName = 'Chúng mình';
  static const String _defaultNameU1 = 'Bạn Nam';
  static const String _defaultNameU2 = 'Bạn Nữ';

  static const String _authUidPrefsKey = 'il_auth_uid';

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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

  Future<Map<String, String>> _safeCurrentDeviceSnapshot() async {
    try {
      final deviceInfo = await DeviceManagerService().getCurrentDeviceSnapshot();
      return Map<String, String>.from(deviceInfo);
    } catch (error) {
      debugPrint('[HouseService] device snapshot unavailable: $error');
      return const <String, String>{};
    }
  }

  Future<void> _waitForAuthenticatedSessionReady({
    bool forceRefreshToken = false,
  }) async {
    firebase_auth.User? user = _auth.currentUser;
    for (var attempt = 0; attempt < 5; attempt++) {
      user = _auth.currentUser ?? user;
      if (user != null) {
        try {
          await user.reload().timeout(const Duration(seconds: 4));
        } catch (error) {
          debugPrint('[HouseService] user.reload skipped: $error');
        }

        user = _auth.currentUser ?? user;
        try {
          final token = await user
              .getIdToken(forceRefreshToken || attempt > 0)
              .timeout(const Duration(seconds: 5));
          if ((token ?? '').trim().isNotEmpty) {
            return;
          }
        } catch (error) {
          debugPrint('[HouseService] getIdToken skipped: $error');
        }
      }

      if (attempt < 4) {
        await Future.delayed(Duration(milliseconds: 450 + (attempt * 250)));
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
      debugPrint('[HouseService] App Check token warmup skipped: $error');
    }
  }

  Future<HttpsCallableResult<dynamic>> _callCreateHouseSecure(
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable('createHouseSecure');
    debugPrint('[HouseService] createHouseSecure start');
    final response = await callable.call(payload).timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw TimeoutException('createHouseSecure timed out');
      },
    );
    debugPrint('[HouseService] createHouseSecure success');
    return response;
  }

  bool _shouldRetryCreateHouse(FirebaseFunctionsException error) {
    final code = error.code.trim().toLowerCase();
    final message = (error.message ?? '').trim().toLowerCase();
    return code == 'unauthenticated' ||
        code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'failed-precondition' &&
            (message.contains('app check') ||
                message.contains('appcheck') ||
                message.contains('debug token') ||
                message.contains('play integrity') ||
                message.contains('attestation')) ||
        code == 'permission-denied' &&
            (message.contains('app check') ||
                message.contains('appcheck') ||
                message.contains('debug token') ||
                message.contains('play integrity') ||
                message.contains('attestation'));
  }

  HouseCreationOtpRequiredException? _otpRequiredFromError(
    FirebaseFunctionsException error,
  ) {
    final message = (error.message ?? '').trim();
    final details = error.details;
    Map<String, dynamic>? detailMap;
    if (details is Map) {
      detailMap = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(details));
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
    await _refreshCallableSecurityContext(force: true);
    try {
      return await _callCreateHouseSecure(payload);
    } on FirebaseFunctionsException catch (error) {
      final otpRequired = _otpRequiredFromError(error);
      if (otpRequired != null) {
        throw otpRequired;
      }
      if (!_shouldRetryCreateHouse(error)) {
        rethrow;
      }
      debugPrint('[HouseService] createHouseSecure security sync retry: $error');
      await Future.delayed(const Duration(milliseconds: 700));
      await _refreshCallableSecurityContext(force: true);
      return _callCreateHouseSecure(payload);
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
      );
    }

    Future<String> createAdminDebugFallback() async {
      final callable = _functions.httpsCallable('createHouseSecureAdminDebug');
      debugPrint('[HouseService] createHouseSecureAdminDebug start');
      final response = await callable.call(<String, dynamic>{
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
      }).timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException('createHouseSecureAdminDebug timed out');
      });
      debugPrint('[HouseService] createHouseSecureAdminDebug success');
      final payload = _asStringDynamicMap(response.data);
      final createdHouseId = payload?['houseId']?.toString().trim() ?? '';
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
        } catch (adminDebugError, stackTrace) {
          debugPrint(
            '[HouseService] createHouseSecureAdminDebug failed: $adminDebugError\n$stackTrace',
          );
        }
        debugPrint(
            '[HouseService] createHouseSecure blocked, using direct fallback: $error');
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
    } on TimeoutException catch (error, stackTrace) {
      debugPrint(
        '[HouseService] createHouseSecure timed out: $error\n$stackTrace',
      );
      if (_allowLegacyDirectCreateFallback) {
        return createDirectFallback();
      }
      throw Exception(
          'Tạo ngôi nhà đang mất quá nhiều thời gian. Vui lòng thử lại.');
    }
  }

  Future<String?> getCurrentHouseId({bool preferFresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedHouseId = prefs.getString('il_house_id')?.trim() ?? '';
    final cachedAuthUid = prefs.getString(_authUidPrefsKey)?.trim() ?? '';

    if (cachedHouseId.isNotEmpty) {
      if (cachedAuthUid != user.uid) {
        await prefs.remove('il_house_id');
        await prefs.remove('il_role');
      } else if (preferFresh) {
        final fresh = await _fetchAndCacheHouseId(
          user.uid,
          prefs,
          validateMembership: true,
        );
        if (fresh != null && fresh.isNotEmpty) {
          return fresh;
        }

        if (await _validateHouseMembership(user.uid, cachedHouseId)) {
          return cachedHouseId;
        }

        await prefs.remove('il_house_id');
      } else {
        _fetchAndCacheHouseId(
          user.uid,
          prefs,
          validateMembership: true,
        ).catchError((_) => null);
        return cachedHouseId;
      }
    }

    return _fetchAndCacheHouseId(
      user.uid,
      prefs,
      validateMembership: preferFresh,
    );
  }

  Future<String?> _fetchAndCacheHouseId(
    String uid,
    SharedPreferences prefs, {
    bool validateMembership = false,
  }) async {
    try {
      // ⚡ Parallelize reads of primary and legacy house IDs (2x faster)
      final results = await Future.wait([
        _dbRef
            .child('users/$uid/houseId')
            .get()
            .timeout(const Duration(seconds: 5)),
        _dbRef
            .child('users/$uid/house_id')
            .get()
            .timeout(const Duration(seconds: 5)),
      ]);

      final primarySnap = results[0];
      final primaryValue = primarySnap.value?.toString().trim();
      if (primarySnap.exists &&
          primaryValue != null &&
          primaryValue.isNotEmpty &&
          (!validateMembership ||
              await _validateHouseMembership(uid, primaryValue))) {
        await prefs.setString('il_house_id', primaryValue);
        await prefs.setString(_authUidPrefsKey, uid);
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
        await prefs.setString('il_house_id', legacyValue);
        await prefs.setString(_authUidPrefsKey, uid);
        return legacyValue;
      }
    } on TimeoutException {
      // Fallback cache below handles slow network without spamming logs.
    } catch (e) {
      debugPrint('Error resolving house id: $e');
    }


    final fallback = prefs.getString('il_house_id')?.trim() ?? '';
    if (fallback.isEmpty) {
      return null;
    }
    if (!validateMembership || await _validateHouseMembership(uid, fallback)) {
      await prefs.setString(_authUidPrefsKey, uid);
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
          .timeout(const Duration(seconds: 3));
      if ((ownerSnap.value?.toString().trim() ?? '') == uid) {
        return true;
      }

      final memberSnap = await _dbRef
          .child('houses/$normalizedHouseId/members/$uid')
          .get()
          .timeout(const Duration(seconds: 3));
      return memberSnap.exists;
    } on TimeoutException {
      return false;
    } catch (e) {
      debugPrint('Error validating house membership: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getHouseSettings(String houseId) async {
    try {
      final snap = await _dbRef
          .child('houses/$houseId/settings')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists) {
        final data = _asStringDynamicMap(snap.value);
        if (data != null) {
          return data;
        }
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('il_offline_cache_home_settings');
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is Map) {
            final data = _asStringDynamicMap(decoded['data']);
            if (data != null) {
              return data;
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  bool _isDebugAppCheckFailure(FirebaseFunctionsException error) {
    if (!kDebugMode) {
      return false;
    }
    final code = error.code.trim().toLowerCase();
    final message = (error.message ?? '').trim().toLowerCase();
    final isAppCheckCode = code == 'failed-precondition' ||
        code == 'permission-denied' ||
        code == 'unauthenticated';
    if (!isAppCheckCode) {
      return false;
    }
    if (code == 'unauthenticated' && _auth.currentUser != null) {
      return true;
    }
    return message.contains('app check') ||
        message.contains('appcheck') ||
        message.contains('debug token') ||
        message.contains('play integrity') ||
        message.contains('attestation');
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
    final newHouseId = await _generateUniqueHouseId();
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
          'countdownSizePx': 500,
          'startDate': startDate,
          'font': "'Quicksand', sans-serif",
          'privacy': 'public',
          'friendRequestPolicy': 'all',
          'friendRequestLimit': 30,
          'homeBlockTone': 'theme',
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
      final snapshot = await _dbRef.child('houses/$candidate').get();
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
