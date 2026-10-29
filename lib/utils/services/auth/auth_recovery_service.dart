import 'dart:async';

import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'auth_support.dart' as auth_support;
import '../core/cloud_functions_helper.dart';

class AuthRecoveryService {
  AuthRecoveryService({
    this._firebaseAuth,
    this._databaseRef,
    this._firebaseFunctions,
  });

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;
  final FirebaseFunctions? _firebaseFunctions;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();

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

  static const Duration _appCheckRetryDelay = Duration(milliseconds: 350);

  bool _isAppCheckFailure(
    FirebaseFunctionsException error, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) {
    final code = error.code.trim().toLowerCase();
    final isPossibleAppCheckCode =
        code == 'failed-precondition' ||
        code == 'permission-denied' ||
        code == 'unauthenticated';
    if (!isPossibleAppCheckCode) {
      return false;
    }

    final message = '${error.message ?? ''} ${error.details ?? ''}'
        .trim()
        .toLowerCase();

    const appCheckMarkers = <String>[
      'app check',
      'appcheck',
      'debug token',
      'play integrity',
      'attestation',
      'firebase app check api',
      'x-firebase-appcheck',
      'recaptcha',
      'app attest',
      'device check',
      'missing appcheck token',
      'invalid appcheck token',
    ];
    final hasAppCheckMarker = appCheckMarkers.any(message.contains);
    if (hasAppCheckMarker) {
      return true;
    }

    if (!allowUnauthenticatedWithoutMarkers || code != 'unauthenticated') {
      return false;
    }

    const authRequiredMarkers = <String>[
      'user must be authenticated',
      'must be authenticated',
      'requires authentication',
      'requires login',
      'requires sign in',
      'dang nhap',
      'đăng nhập',
      'sign in again',
      'login again',
    ];
    return !authRequiredMarkers.any(message.contains);
  }

  Future<bool> _warmUpAppCheck({bool forceRefresh = false}) async {
    try {
      final token = await FirebaseAppCheck.instance
          .getToken(forceRefresh)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      return (token ?? '').trim().isNotEmpty;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'AuthRecoveryService App Check warm-up failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể chuẩn bị App Check.').message}',
        );
      }
    }
    return false;
  }

  Future<void> _refreshCurrentUserSession({
    bool forceRefreshIdToken = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await user.reload();
    } catch (error) {
      debugPrint('[AuthRecovery] Không thể reload phiên người dùng: $error');
    }

    if (!forceRefreshIdToken) {
      return;
    }

    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (error) {
      debugPrint('[AuthRecovery] Không thể làm mới ID token: $error');
    }
  }

  Future<T> _callOtpFunction<T>(
    Future<T> Function() action, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) async {
    await _warmUpAppCheck();
    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      if (!_isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: allowUnauthenticatedWithoutMarkers,
      )) {
        rethrow;
      }

      final refreshed = await _warmUpAppCheck(forceRefresh: true);
      if (refreshed) {
        await Future<void>.delayed(_appCheckRetryDelay);
      }
      return await action();
    }
  }

  Future<HttpsCallableResult<T>> _callRecoveryFunction<T>(
    String name, {
    required dynamic payload,
    Duration timeout = const Duration(seconds: 12),
  }) {
    final injectedFunctions = _firebaseFunctions;
    if (injectedFunctions == null) {
      return CloudFunctionsHelper.callSecure<T>(
        name,
        payload: payload,
        timeout: timeout,
        throwOriginalException: true,
      );
    }
    return injectedFunctions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: timeout),
        )
        .call<T>(payload)
        .timeout(timeout);
  }

  String _messageFromFunctionsError(
    FirebaseFunctionsException error, {
    required String fallbackMessage,
    String? permissionDeniedMessage,
    String? deadlineExceededMessage,
    String? failedPreconditionMessage,
    String? resourceExhaustedMessage,
    String? unauthenticatedMessage,
    String? invalidArgumentMessage,
    String? appCheckMessage,
    bool allowUnauthenticatedWithoutMarkers = false,
  }) {
    if (_isAppCheckFailure(
      error,
      allowUnauthenticatedWithoutMarkers: allowUnauthenticatedWithoutMarkers,
    )) {
      return appCheckMessage ??
          AppErrorMapper.resolve(
            error,
            fallbackMessage: fallbackMessage,
          ).message;
    }

    switch (error.code) {
      case 'permission-denied':
        return permissionDeniedMessage ??
            AppErrorMapper.resolve(
              error,
              fallbackMessage: UiCopy.text('copy_8d9f3b1f9ea4'),
            ).message;
      case 'deadline-exceeded':
        return deadlineExceededMessage ??
            AppErrorMapper.resolve(
              error,
              fallbackMessage: UiCopy.text('copy_ce8b53085ba9'),
            ).message;
      case 'failed-precondition':
        return failedPreconditionMessage ??
            AppErrorMapper.resolve(
              error,
              fallbackMessage: UiCopy.text('copy_7e839d438d88'),
            ).message;
      case 'resource-exhausted':
        return resourceExhaustedMessage ??
            AppErrorMapper.resolve(
              error,
              fallbackMessage: UiCopy.text('copy_3fc83e0151c2'),
            ).message;
      case 'unauthenticated':
        return unauthenticatedMessage ??
            AppErrorMapper.resolve(
              error,
              fallbackMessage: UiCopy.text('copy_dce241e0d961'),
            ).message;
      case 'invalid-argument':
        return invalidArgumentMessage ??
            AppErrorMapper.resolve(
              error,
              fallbackMessage: UiCopy.text('copy_011c0f11b574'),
            ).message;
      default:
        return AppErrorMapper.resolve(
          error,
          fallbackMessage: fallbackMessage,
        ).message;
    }
  }

  Map<String, dynamic>? _cachedSecurityData;
  String? _cachedSecurityHouseId;
  String? _cachedSecurityUid;
  DateTime? _lastSecurityCacheTime;
  String? _lastObservedUid;
  bool _hasObservedAuthState = false;

  Future<Map<String, dynamic>?> getHouseSecurityData(String houseId) async {
    final normalizedHouseId = houseId.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) return null;
    final now = DateTime.now();
    final currentUid = _auth.currentUser?.uid;
    if (_hasObservedAuthState && _lastObservedUid != currentUid) {
      _cachedSecurityData = null;
      _cachedSecurityHouseId = null;
      _cachedSecurityUid = null;
      _lastSecurityCacheTime = null;
    }
    _lastObservedUid = currentUid;
    _hasObservedAuthState = true;
    if (_cachedSecurityData != null &&
        _cachedSecurityHouseId == normalizedHouseId &&
        _cachedSecurityUid == currentUid &&
        _lastSecurityCacheTime != null &&
        now.difference(_lastSecurityCacheTime!).inSeconds < 5) {
      return _cachedSecurityData;
    }

    // Người chưa đăng nhập không có quyền đọc houses/*/security theo RTDB
    // Rules. Callable chỉ trả câu hỏi và email đã che cho trường hợp này.
    if (currentUid == null && _databaseRef == null) {
      return _fetchHouseRecoveryInfo(normalizedHouseId);
    }

    try {
      final snaps = await Future.wait([
        _db
            .child('houses/$normalizedHouseId/security')
            .get()
            .timeout(const Duration(seconds: 3)),
        _db
            .child('houses/$normalizedHouseId/email')
            .get()
            .timeout(const Duration(seconds: 3)),
      ]);

      final securitySnap = snaps[0];
      final emailSnap = snaps[1];

      if (!securitySnap.exists && !emailSnap.exists) {
        return null;
      }

      final security =
          _asStringDynamicMap(securitySnap.value) ?? <String, dynamic>{};
      final recovery =
          _asStringDynamicMap(security['recovery']) ?? <String, dynamic>{};
      final question = (recovery['question'] ?? security['question'] ?? '')
          .toString()
          .trim();
      final answerHash =
          (recovery['answerHash'] ??
                  security['answer'] ??
                  security['answerHash'] ??
                  '')
              .toString()
              .trim();
      if (question.isNotEmpty) {
        security['question'] = question;
      }
      if (answerHash.isNotEmpty) {
        security['answer'] = answerHash;
        security['answerHash'] = answerHash;
      }
      if (question.isNotEmpty || answerHash.isNotEmpty) {
        security['recovery'] = {
          ...recovery,
          if (question.isNotEmpty) 'question': question,
          if (answerHash.isNotEmpty) 'answerHash': answerHash,
        };
      }
      if (emailSnap.value != null && security['email'] == null) {
        security['email'] = emailSnap.value;
      }
      final backupEmail =
          (security['backupEmail'] ?? security['secondaryEmail'] ?? '')
              .toString()
              .trim();
      if (backupEmail.isNotEmpty) {
        security['backupEmail'] = backupEmail;
        security['secondaryEmail'] = backupEmail;
      }

      _cachedSecurityData = security;
      _cachedSecurityHouseId = normalizedHouseId;
      _cachedSecurityUid = currentUid;
      _lastSecurityCacheTime = now;
      return security;
    } catch (_) {
      return _fetchHouseRecoveryInfo(normalizedHouseId);
    }
  }

  Future<Map<String, dynamic>?> _fetchHouseRecoveryInfo(
    String normalizedHouseId,
  ) async {
    try {
      final result = await _callOtpFunction(
        () => _callRecoveryFunction<dynamic>(
          'getHouseRecoveryInfo',
          payload: {'houseId': normalizedHouseId},
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final payload = _asStringDynamicMap(result.data);
      if (payload == null || payload['found'] != true) return null;

      final question = payload['question']?.toString().trim() ?? '';
      final maskedEmail = payload['maskedEmail']?.toString().trim() ?? '';
      final email = payload['email']?.toString().trim().toLowerCase() ?? '';
      final security = <String, dynamic>{
        if (question.isNotEmpty) 'question': question,
        if (maskedEmail.isNotEmpty) 'maskedEmail': maskedEmail,
        if (email.isNotEmpty) 'email': email,
        'recoveryAvailable': payload['recoveryAvailable'] == true,
        if (payload['recoveryAvailable'] == true)
          'recovery': <String, dynamic>{'question': question},
      };
      _cachedSecurityData = security;
      _cachedSecurityHouseId = normalizedHouseId;
      _cachedSecurityUid = _auth.currentUser?.uid;
      _lastSecurityCacheTime = DateTime.now();
      return security;
    } catch (_) {
      return null;
    }
  }

  String maskEmail(String email) => auth_support.maskEmail(email);

  Future<String?> findEmailByHouseId(String houseId) async {
    final normalizedHouseId = houseId.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) return null;
    try {
      final securitySnap = await _db
          .child('houses/$normalizedHouseId/security/email')
          .get()
          .timeout(const Duration(seconds: 3));
      final securityEmail = securitySnap.value?.toString().trim();
      if (securityEmail != null && securityEmail.isNotEmpty) {
        return securityEmail;
      }
      final snapshot = await _db
          .child('houses/$normalizedHouseId/email')
          .get()
          .timeout(const Duration(seconds: 3));
      final email = snapshot.value?.toString().trim();
      return (email == null || email.isEmpty) ? null : email;
    } catch (_) {
      return null;
    }
  }

  Future<bool> verifySecurityAnswer(String houseId, String answer) async {
    try {
      final normalizedHouseId = houseId.trim().toUpperCase();
      final security = await getHouseSecurityData(normalizedHouseId);
      final storedAnswer = (security?['answerHash'] ?? security?['answer'])
          ?.toString();
      if (storedAnswer != null && storedAnswer.trim().isNotEmpty) {
        return matchesRecoveryAnswer(storedAnswer, answer);
      }

      final result = await _callOtpFunction(
        () => _callRecoveryFunction<dynamic>(
          'verifyHouseRecoveryAnswer',
          payload: {'houseId': normalizedHouseId, 'answer': answer.trim()},
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final payload = _asStringDynamicMap(result.data);
      return payload?['verified'] == true;
    } catch (_) {
      return false;
    }
  }

  bool matchesRecoveryAnswer(String? storedAnswer, String inputAnswer) {
    return auth_support.matchesRecoveryAnswer(storedAnswer, inputAnswer);
  }

  Future<bool> verifyPin(String houseId, String pin) async {
    try {
      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'verifyHousePin',
          payload: {'houseId': houseId.trim(), 'pin': pin.trim()},
          throwOriginalException: true,
        ),
      );
      final rawData = result.data;
      if (rawData is! Map) {
        return false;
      }
      final data = Map<String, dynamic>.from(rawData);
      return data['success'] == true;
    } on FirebaseFunctionsException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: auth_support.buildPasswordResetActionCodeSettings(),
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-email':
          throw UiCopy.text('copy_633fb684c625');
        case 'missing-email':
          throw UiCopy.text('copy_80a91804e836');
        case 'user-not-found':
          throw UiCopy.text('copy_8e67c589c00c');
        case 'network-request-failed':
          throw UiCopy.text('copy_60c58bba9040');
        case 'too-many-requests':
          throw UiCopy.text('copy_8cebb78c51c1');
        default:
          throw auth_support.handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            L10nService().translate('auth_fallback_reset_link_send'),
      ).message;
    }
  }

  Future<void> sendOtpEmail(String email) async {
    try {
      final deviceId = await SecurityService().getDeviceId();
      final result = await _callOtpFunction(
        () => _callRecoveryFunction<dynamic>(
          'requestEmailOTP',
          // Server có deadline 60 giây; chừa thêm thời gian kết nối/khởi động
          // để thư gửi thành công sau 15 giây không bị app báo thất bại sớm.
          timeout: const Duration(seconds: 75),
          payload: {
            'email': email.trim(),
            'locale': L10nService().localeCode,
            if (deviceId.trim().isNotEmpty) 'deviceId': deviceId.trim(),
          },
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
      if (_asStringDynamicMap(result.data)?['success'] != true) {
        throw AppErrorInfo(
          kind: AppErrorKind.server,
          message: L10nService().translate(
            'auth_fallback_verification_code_send',
          ),
        );
      }
    } catch (error) {
      if (error is TimeoutException ||
          (error is FirebaseFunctionsException &&
              error.code == 'deadline-exceeded')) {
        // Timeout chưa chứng minh thư không được gửi. Giữ kiểu lỗi để dialog
        // không diễn giải lại câu đã dịch thành lỗi mất Wi-Fi chung chung.
        throw AppErrorInfo(
          kind: AppErrorKind.network,
          message: L10nService().translate('settings_email_send_timeout'),
        );
      }
      if (error is FirebaseFunctionsException) {
        throw AppErrorInfo(
          kind: AppErrorMapper.resolve(error).kind,
          message: _messageFromFunctionsError(
            error,
            fallbackMessage: L10nService().translate(
              'auth_fallback_verification_code_send',
            ),
            permissionDeniedMessage: UiCopy.text('copy_fd3b19bd52c2'),
            failedPreconditionMessage: UiCopy.text('copy_aa51e7b93807'),
            resourceExhaustedMessage: UiCopy.text('copy_0e4a181a798a'),
            unauthenticatedMessage: UiCopy.text('copy_e687147b4e28'),
            invalidArgumentMessage: UiCopy.text('copy_0196a75224f3'),
            appCheckMessage: kDebugMode
                ? UiCopy.text('copy_21eaeaa66ac6')
                : UiCopy.text('copy_bb2c1fe6f42a'),
            allowUnauthenticatedWithoutMarkers: true,
          ),
        );
      }
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate(
          'auth_fallback_verification_code_send',
        ),
      );
    }
  }

  Future<String> verifyOtpAndGetToken(String email, String otp) async {
    try {
      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'verifyEmailOTP',
          payload: {'email': email.trim(), 'otp': otp.trim()},
          throwOriginalException: true,
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final rawData = result.data;
      if (rawData is! Map) {
        throw UiCopy.text('copy_77e1b62cba70');
      }
      final data = Map<String, dynamic>.from(rawData);
      if (data['success'] == true) {
        final token = data['customToken'];
        if (token == null || token.toString().isEmpty) {
          throw UiCopy.text('copy_4bdb38497394');
        }
        return token.toString();
      }
      throw data['message'] ?? UiCopy.text('copy_46c002d23c60');
    } catch (error) {
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage:
              L10nService().translate('auth_fallback_verification_code_check'),
          appCheckMessage: kDebugMode
              ? UiCopy.text('copy_988dfd5c5227')
              : UiCopy.text('copy_23f6e3c6977a'),
          allowUnauthenticatedWithoutMarkers: true,
        );
      }
      if (error is String) rethrow;
      throw UiCopy.text('copy_18cc86a81b2c');
    }
  }

  Future<void> verifyPrimaryEmailOTP(String email, String otp) async {
    final normalizedEmail = auth_support.normalizeSecurityEmail(email);
    try {
      await _refreshCurrentUserSession(forceRefreshIdToken: true);

      final currentEmail = auth_support.normalizeSecurityEmail(
        _auth.currentUser?.email ?? '',
      );
      if (currentEmail.isEmpty) {
        throw UiCopy.text('copy_cc40be154171');
      }
      if (currentEmail != normalizedEmail) {
        throw UiCopy.text('copy_7e839d438d88');
      }

      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'verifyPrimaryEmailOTP',
          payload: {'email': normalizedEmail, 'otp': otp.trim()},
          throwOriginalException: true,
        ),
      );
      final data = _asStringDynamicMap(result.data);
      if (data == null) {
        throw UiCopy.text('copy_0b33f3dbe3a6');
      }
      if (data['success'] != true) {
        throw UiCopy.text('copy_556dd063c013');
      }
    } catch (error) {
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage:
              L10nService().translate('auth_fallback_primary_email_verify'),
          appCheckMessage: kDebugMode
              ? UiCopy.text('copy_ec710fce2940')
              : UiCopy.text('copy_6ca4f267ea45'),
        );
      }
      if (error is String) rethrow;
      throw UiCopy.text('copy_0c9ab11b345f');
    }
  }

  Future<void> validateEmailOTP(
    String email,
    String otp, {
    String? aliasExpectedUid,
  }) async {
    try {
      final result = await _callOtpFunction(() {
        if (aliasExpectedUid != null) _assertAliasSession(aliasExpectedUid);
        return CloudFunctionsHelper.callSecure<dynamic>(
          'validateEmailOTP',
          payload: {
            'email': email.trim(),
            'otp': otp.trim(),
            if (aliasExpectedUid != null) ...{
              'purpose': 'login_alias',
              'expectedUid': aliasExpectedUid,
            },
          },
          throwOriginalException: true,
        );
      }, allowUnauthenticatedWithoutMarkers: true);
      if (aliasExpectedUid != null) _assertAliasSession(aliasExpectedUid);
      final data = _asStringDynamicMap(result.data);
      if (aliasExpectedUid != null &&
          (data == null || data['success'] != true)) {
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'login_alias_verification_required',
        );
      }
      if (data == null) {
        throw UiCopy.text('copy_46c002d23c60');
      }
      if (data['success'] != true) {
        throw UiCopy.text('copy_46c002d23c60');
      }
    } catch (error) {
      if (aliasExpectedUid != null) rethrow;
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage: L10nService().translate('auth_fallback_verification_code_expired'),
          appCheckMessage: kDebugMode
              ? UiCopy.text('copy_ec710fce2940')
              : UiCopy.text('copy_6ca4f267ea45'),
          allowUnauthenticatedWithoutMarkers: true,
        );
      }
      throw UiCopy.text('copy_46c002d23c60');
    }
  }

  void _assertAliasSession(String expectedUid) {
    if (expectedUid.isEmpty || _auth.currentUser?.uid != expectedUid) {
      throw firebase_auth.FirebaseAuthException(code: 'user-token-expired');
    }
  }

  Future<String> getLoginAliasForCurrentUser({
    required String expectedUid,
  }) async {
    _assertAliasSession(expectedUid);
    final result = await _callOtpFunction(() {
      _assertAliasSession(expectedUid);
      return CloudFunctionsHelper.callSecure<dynamic>(
        'getLoginAlias',
        payload: {'expectedUid': expectedUid},
        throwOriginalException: true,
      );
    });
    _assertAliasSession(expectedUid);
    final data = _asStringDynamicMap(result.data);
    if (data == null || data['email'] is! String) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'login_alias_response_invalid',
      );
    }
    return (data['email'] as String).trim().toLowerCase();
  }

  Future<void> setLoginAliasForCurrentUser(
    String email, {
    required String expectedUid,
  }) async {
    _assertAliasSession(expectedUid);
    final normalizedEmail = email.trim().toLowerCase();
    await _refreshCurrentUserSession(forceRefreshIdToken: true);
    final result = await _callOtpFunction(() {
      _assertAliasSession(expectedUid);
      return CloudFunctionsHelper.callSecure<dynamic>(
        'setLoginAlias',
        payload: {'email': normalizedEmail, 'expectedUid': expectedUid},
        throwOriginalException: true,
      );
    });
    _assertAliasSession(expectedUid);
    final data = _asStringDynamicMap(result.data);
    if (data == null ||
        data['success'] != true ||
        data['email'] != normalizedEmail) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'login_alias_response_invalid',
      );
    }
  }

  Future<void> completePasswordRecovery(
    firebase_auth.UserCredential userCredential,
    String newPassword,
  ) async {
    final user = userCredential.user;
    if (user != null) {
      void requireRecoverySession() {
        if (_auth.currentUser?.uid != user.uid) {
          throw firebase_auth.FirebaseAuthException(code: 'user-token-expired');
        }
      }

      requireRecoverySession();
      final hasPasswordProvider = user.providerData.any(
        (provider) => provider.providerId == 'password',
      );
      if (hasPasswordProvider) {
        await user.updatePassword(newPassword);
        requireRecoverySession();
        return;
      }

      final email = user.email?.trim() ?? '';
      if (email.isEmpty) {
        throw UiCopy.text('copy_4202a22da8cd');
      }

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: newPassword,
      );
      await user.linkWithCredential(credential);
      requireRecoverySession();
      return;
    }
    throw UiCopy.text('copy_42987feddb6e');
  }

  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code.trim());
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-action-code':
          throw UiCopy.text('copy_7ffff27f51f2');
        case 'expired-action-code':
          throw UiCopy.text('copy_8c31ffed0ab2');
        case 'user-disabled':
          throw UiCopy.text('copy_a082a2271b95');
        case 'user-not-found':
          throw UiCopy.text('copy_573a47ec6955');
        default:
          throw auth_support.handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            L10nService().translate('auth_fallback_reset_link_check'),
      ).message;
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(
        code: code.trim(),
        newPassword: newPassword,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-action-code':
          throw UiCopy.text('copy_7ffff27f51f2');
        case 'expired-action-code':
          throw UiCopy.text('copy_8c31ffed0ab2');
        case 'weak-password':
          throw UiCopy.text('copy_fd113f1198f9');
        case 'user-disabled':
          throw UiCopy.text('copy_a082a2271b95');
        case 'user-not-found':
          throw UiCopy.text('copy_573a47ec6955');
        default:
          throw auth_support.handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            L10nService().translate('auth_fallback_password_update'),
      ).message;
    }
  }

  String hashRecoveryAnswer(String input) {
    return auth_support.hashRecoveryAnswer(input);
  }

  String hashHousePin(String input) {
    return auth_support.hashHousePin(input);
  }
}
