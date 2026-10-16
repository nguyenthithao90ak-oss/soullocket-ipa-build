import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/secure_storage_service.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/utils/services/critical_data_sync_service.dart';
import 'package:soullocket_app/utils/services/device_manager_service.dart';
import 'package:soullocket_app/utils/services/encryption_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/app_check_http_headers.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/utils/services/settings_sync_service.dart';
import 'package:soullocket_app/utils/services/security_verdict_cache_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/role_utils.dart';
import 'package:soullocket_app/utils/services/core/presence_service.dart';
import 'play_integrity_service.dart';
import 'auth_admin_service.dart';
import 'auth_house_context_service.dart';
import 'auth_support.dart';
import 'account_deletion_response.dart';
import '../../../models/account_deletion_status.dart';
import '../l10n_service.dart';

part 'auth_sign_in_service_social.dart';

class AuthSignInService {
  AuthSignInService({
    this._firebaseAuth,
    this._databaseRef,
    SharedPreferencesProvider? sharedPreferencesProvider,
    GoogleSignInBuilder? googleSignInBuilder,
    this._firebaseFunctions,
    HttpPost? httpPost,
    NowProvider? nowProvider,
    required this._adminService,
    required this._houseContextService,
  }) : _sharedPreferencesProvider =
           sharedPreferencesProvider ?? SharedPreferences.getInstance,
       _googleSignInBuilder =
           googleSignInBuilder ?? (() => GoogleSignIn.instance),
       _httpPost = httpPost ?? http.post,
       _nowProvider = nowProvider ?? DateTime.now,
       _playIntegrityService = PlayIntegrityService();

  static const String dailyLoginLimitMessage =
      'Thiết bị này chỉ được đăng nhập tối đa ${AppConfig.maxNewLoginsPerDay} tài khoản mới trong 1 ngày.';
  static const String accountNotFoundMessage =
      'Tài khoản không tồn tại. Vui lòng kiểm tra lại email hoặc tạo tài khoản mới.';
  static const String wrongPasswordMessage = 'Sai mật khẩu. Vui lòng thử lại.';
  static bool _isGoogleSignInInitialized = false;
  static final _pendingSignOuts = Expando<Future<void>>();
  // Firebase Auth không hủy native request khi Future phía Dart hết hạn.
  // Giữ request đang chạy để lần đăng nhập email kế tiếp không chạy song song
  // và không để phiên cũ xuất hiện muộn sau khi người dùng đã đổi tài khoản.
  static final _pendingEmailSignIns =
      Expando<Future<firebase_auth.UserCredential>>();
  static final _pendingEmailSignups =
      Expando<Future<firebase_auth.UserCredential?>>();
  static const Duration _emailSignInTimeout = Duration(seconds: 12);
  static const Duration _sessionFinalizeTimeout = Duration(seconds: 30);
  static const Duration _sessionFinalizePhaseTimeout = Duration(seconds: 12);
  static const String _dailyLoginTrackerPrefsKey = 'il_login_tracker';
  static const Set<String> _signOutPreservedPrefsKeys = {
    _dailyLoginTrackerPrefsKey,
    'il_device_id',
    'il_antispam_cooldown',
  };
  static const Set<String> _signOutClearedPrefsKeys = {
    'il_house_id',
    'il_house_name',
    'il_auth_uid',
    'il_role',
    'il_user_name',
    'il_rel_mode',
    'il_login_ts',
    'il_saved_gender',
    'il_pending_signup_recovery_question',
    'il_pending_signup_recovery_answer',
    'il_pending_signup_auto_create_house',
    'il_pending_signup_email',
    'il_imgbb_api_key',
    'il_app_lock_enabled',
    'il_use_biometrics',
    'il_lock_timeout',
    'il_military_mode',
    'il_custom_lock',
    'il_custom_lock_salt',
    'il_custom_lock_length',
    'il_custom_lock_configured_at',
    'il_lock_scope_app',
    'il_lock_scope_security',
    'il_lock_scope_diary',
    'il_lock_scope_chat',
    'il_lock_scope_private',
  };

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;
  final SharedPreferencesProvider _sharedPreferencesProvider;
  final GoogleSignInBuilder _googleSignInBuilder;
  final FirebaseFunctions? _firebaseFunctions;
  final HttpPost _httpPost;
  final NowProvider _nowProvider;
  final AuthAdminService _adminService;
  final AuthHouseContextService _houseContextService;
  final PlayIntegrityService _playIntegrityService;

  GoogleSignIn? _googleSignIn;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();
  FirebaseFunctions get _functions =>
      _firebaseFunctions ?? FirebaseFunctions.instance;

  Future<SharedPreferences> get _prefs => _sharedPreferencesProvider();

  Future<bool> checkDailyLoginLimit(String email) async {
    try {
      final normalizedEmail = normalizeEmailKey(email);
      final tracker = await _getDailyLoginTracker();
      final trackerDay = tracker['d']?.toString() ?? '';
      if (trackerDay != _currentLoginTrackerDay()) {
        return true;
      }
      final accounts = _trackerAccounts(tracker);
      if (accounts.contains(normalizedEmail)) {
        return true;
      }
      return accounts.length < AppConfig.maxNewLoginsPerDay;
    } catch (error) {
      debugPrint(
        'checkDailyLoginLimit failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể kiểm tra giới hạn đăng nhập hôm nay.').message}',
      );
      return true;
    }
  }

  Future<bool> recordDailyLoginLimit(String email) async {
    try {
      final normalizedEmail = normalizeEmailKey(email);
      final dayKey = _currentLoginTrackerDay();
      final tracker = await _getDailyLoginTracker();
      final existingDay = tracker['d']?.toString() ?? '';
      final accounts = existingDay == dayKey
          ? _trackerAccounts(tracker)
          : <String>[];

      if (!accounts.contains(normalizedEmail)) {
        if (accounts.length >= AppConfig.maxNewLoginsPerDay) {
          return false;
        }
        accounts.add(normalizedEmail);
      }

      final prefs = await _prefs;
      await prefs.setString(
        _dailyLoginTrackerPrefsKey,
        jsonEncode({'d': dayKey, 'acc': accounts}),
      );
      return true;
    } catch (error) {
      debugPrint(
        'recordDailyLoginLimit failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể ghi giới hạn đăng nhập hôm nay.').message}',
      );
      return true;
    }
  }

  Future<String> resolveLoginEmailAlias(
    String email, {
    bool allowFallbackOnFailure = false,
  }) async {
    final resolution = await _lookupLoginEmailResolution(
      email,
      allowFallbackOnFailure: allowFallbackOnFailure,
    );
    return resolution.email;
  }

  Future<void> validateLoginEmailAliasForCurrentUser(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }

    final currentPrimaryEmail = _auth.currentUser?.email?.trim().toLowerCase();
    if ((currentPrimaryEmail ?? '').isEmpty) {
      throw UiCopy.text('copy_d285d1bc9e19');
    }

    final resolution = await _lookupLoginEmailResolution(
      normalizedEmail,
      allowFallbackOnFailure: false,
    );
    if (resolution.source == 'input') {
      return;
    }

    if (resolution.email == currentPrimaryEmail &&
        (resolution.source == 'primary' ||
            resolution.source == 'user_alias' ||
            resolution.source == 'house_legacy')) {
      return;
    }

    if (resolution.source == 'primary') {
      throw UiCopy.text('copy_0d97d34a9fc3');
    }

    throw UiCopy.text('copy_862b22c47570');
  }

  Future<_LoginEmailResolution> _lookupLoginEmailResolution(
    String email, {
    required bool allowFallbackOnFailure,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      return _LoginEmailResolution(email: normalizedEmail, source: 'input');
    }

    try {
      final callable = _functions.httpsCallable('resolveLoginEmailAlias');
      final result = await callable.call(<String, dynamic>{
        'email': normalizedEmail,
      });
      final payload = _asStringDynamicMap(result.data);
      final resolvedEmail = (payload['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final source = (payload['source'] ?? 'input')
          .toString()
          .trim()
          .toLowerCase();

      return _LoginEmailResolution(
        email: resolvedEmail.contains('@') ? resolvedEmail : normalizedEmail,
        source: switch (source) {
          'primary' => 'primary',
          'user_alias' => 'user_alias',
          'house_legacy' => 'house_legacy',
          _ => 'input',
        },
      );
    } on FirebaseFunctionsException catch (error) {
      final code = error.code.trim().toLowerCase();
      final message = error.message?.trim() ?? '';
      if (code == 'invalid-argument' || code == 'failed-precondition') {
        throw message.isNotEmpty
            ? message
            : (code == 'invalid-argument'
                  ? UiCopy.text('copy_6bfc3556a3cb')
                  : UiCopy.text('copy_41d2b7f35096'));
      }
      if (!allowFallbackOnFailure) {
        throw message.isNotEmpty ? message : UiCopy.text('copy_f0a4328a17b2');
      }
      if (kDebugMode) {
        debugPrint(
          'resolveLoginEmailAlias fallback for $normalizedEmail: '
          '${error.code} ${error.message}',
        );
      }
    } catch (error) {
      if (!allowFallbackOnFailure) {
        throw AppErrorMapper.resolve(
          error,
          fallbackMessage: L10nService().translate(
            'auth_fallback_secondary_email_check',
          ),
        ).message;
      }
      if (kDebugMode) {
        debugPrint(
          'resolveLoginEmailAlias unexpected fallback for '
          '$normalizedEmail: $error',
        );
      }
    }

    return _LoginEmailResolution(email: normalizedEmail, source: 'input');
  }

  Future<firebase_auth.UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    await _pendingSignOuts[_auth];
    final requestedEmail = email.trim().toLowerCase();
    final loginResolution = await _lookupLoginEmailResolution(
      requestedEmail,
      allowFallbackOnFailure: true,
    );
    final normalizedEmail = loginResolution.email;

    if (!await checkDailyLoginLimit(normalizedEmail)) {
      throw dailyLoginLimitMessage;
    }

    bool? accountExistsHint;
    try {
      // Cổng kiểm tra phải hoàn tất trước khi tạo phiên Auth mới.
      final precheck = await _precheckServerLoginGuard(normalizedEmail);
      accountExistsHint = precheck.accountExists;
      if (!precheck.allowed) {
        throw precheck.message;
      }
      await _pendingSignOuts[_auth];
      final userCredential = await _signInWithEmailPasswordSerialized(
        email: normalizedEmail,
        password: password,
      );

      if (accountExistsHint == false) {
        await _recordServerLoginFailure(
          normalizedEmail,
          reason: 'account_not_found',
        );
        if (userCredential.user != null) {
          await signOut();
        }
        throw accountNotFoundMessage;
      }

      if (userCredential.user != null) {
        unawaited(_recordServerLoginSuccess(normalizedEmail));
        if (!await recordDailyLoginLimit(normalizedEmail)) {
          await signOut();
          throw dailyLoginLimitMessage;
        }
        await _finalizeAuthenticatedSession(
          userCredential.user!,
          fallbackEmail: normalizedEmail,
        );
      }

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        await _recordServerLoginFailure(
          normalizedEmail,
          reason: 'account_not_found',
        );
        throw accountNotFoundMessage;
      }

      if (error.code == 'wrong-password') {
        final serverFailure = await _recordServerLoginFailure(
          normalizedEmail,
          reason: 'wrong_password',
        );
        if (!serverFailure.allowed) {
          throw serverFailure.message;
        }
        throw wrongPasswordMessage;
      }

      if (error.code == 'invalid-credential') {
        if (accountExistsHint == false) {
          await _recordServerLoginFailure(
            normalizedEmail,
            reason: 'account_not_found',
          );
          throw accountNotFoundMessage;
        }

        final serverFailure = await _recordServerLoginFailure(
          normalizedEmail,
          reason: 'wrong_password',
        );
        if (!serverFailure.allowed) {
          throw serverFailure.message;
        }
        throw wrongPasswordMessage;
      }
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (isFacebookSignInConfigMismatch(error) ||
          isFacebookSignInNetworkIssue(error)) {
        throw normalizeFacebookLoginFailureMessage(error.toString());
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('auth_fallback_sign_in'),
      ).message;
    }
  }

  Future<firebase_auth.UserCredential> _signInWithEmailPasswordSerialized({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    await _waitForPendingEmailSignInBeforeSwitch();

    final request = auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    _pendingEmailSignIns[auth] = request;
    void clearPendingEmailSignIn() {
      if (identical(_pendingEmailSignIns[auth], request)) {
        _pendingEmailSignIns[auth] = null;
      }
    }
    unawaited(
      request.then<void>(
        (_) => clearPendingEmailSignIn(),
        onError: (Object _, StackTrace __) => clearPendingEmailSignIn(),
      ),
    );

    return request.timeout(
      _emailSignInTimeout,
      onTimeout: () => throw UiCopy.text('copy_b8239b73176f'),
    );
  }

  Future<void> _waitForPendingEmailSignInBeforeSwitch() async {
    final pending = _pendingEmailSignIns[_auth];
    if (pending == null) return;
    try {
      await pending;
    } catch (_) {
      // Request cũ thất bại vẫn phải được đợi tới khi native kết thúc.
    }
    // Một request cũ có thể đã tạo phiên sau khi caller của nó timeout.
    // Dọn phiên đó trước khi bắt đầu provider/login request mới.
    if (_auth.currentUser != null) {
      await signOut();
    }
  }

  Future<_ServerLoginGuardPrecheck> _precheckServerLoginGuard(
    String normalizedEmail,
  ) async {
    final payload = await _callServerLoginGuard(
      action: 'precheck',
      email: normalizedEmail,
    );
    if (payload == null) {
      return const _ServerLoginGuardPrecheck();
    }

    final allowed = payload['allowed'] == true;
    final accountExistsRaw = payload['accountExists'];
    final accountExists = accountExistsRaw is bool ? accountExistsRaw : null;
    final serverMessage = payload['message']?.toString().trim() ?? '';
    final message = serverMessage.isNotEmpty
        ? serverMessage
        : UiCopy.text('copy_d8645453617d');
    return _ServerLoginGuardPrecheck(
      allowed: allowed,
      message: message,
      accountExists: accountExists,
    );
  }

  Future<_ServerLoginGuardRecord> _recordServerLoginFailure(
    String normalizedEmail, {
    required String reason,
  }) async {
    final payload = await _callServerLoginGuard(
      action: 'failure',
      email: normalizedEmail,
      reason: reason,
    );

    if (payload == null) {
      return const _ServerLoginGuardRecord();
    }

    final allowed = payload['allowed'] == true;
    final serverMessage = payload['message']?.toString().trim() ?? '';
    return _ServerLoginGuardRecord(
      allowed: allowed,
      message: serverMessage.isNotEmpty
          ? serverMessage
          : UiCopy.text('copy_b645059ae63f'),
    );
  }

  Future<void> _recordServerLoginSuccess(String normalizedEmail) async {
    await _callServerLoginGuard(action: 'success', email: normalizedEmail);
  }

  Future<Map<String, dynamic>?> _callServerLoginGuard({
    required String action,
    required String email,
    String reason = '',
  }) async {
    final endpoint = AppConfig.authLoginGuardUrl.trim();
    if (endpoint.isEmpty) {
      return null;
    }

    final playIntegrityPayload = await _buildLoginGuardPlayIntegrityPayload(
      action: action,
      email: email,
      reason: reason,
    );
    if (playIntegrityPayload == null) {
      return null;
    }

    try {
      final user = _auth.currentUser;
      if ((playIntegrityPayload['uid'] ?? '') != (user?.uid ?? '')) {
        return null;
      }
      final idToken = await user?.getIdToken();
      if (action == 'success' && (idToken == null || idToken.isEmpty)) {
        return null;
      }
      final response = await _httpPost(
        Uri.parse(endpoint),
        headers: await AppCheckHttpHeaders.withRequiredToken(<String, String>{
          'Content-Type': 'application/json',
          if (idToken != null && idToken.isNotEmpty)
            'Authorization': 'Bearer $idToken',
        }, forceRefresh: false),
        body: jsonEncode(<String, dynamic>{
          'action': action,
          'email': email,
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
          'source': 'flutter_app',
          'playIntegrity': playIntegrityPayload,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 403) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final payload = Map<String, dynamic>.from(decoded);
          if (payload['enforcement'] == 'block') {
            try {
              await _cacheSecurityVerdictFromPayload(payload);
            } catch (_) {
              // Lỗi cache local không được biến quyết định chặn thành cho phép.
            }
            return <String, dynamic>{...payload, 'allowed': false};
          }
        }
        return null;
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'authLoginGuardHttp non-200: ${response.statusCode} ${response.body}',
          );
        }
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['ok'] != true) {
        return null;
      }
      return payload;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'authLoginGuardHttp failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể kiểm tra trạng thái đăng nhập lúc này.').message}',
        );
      }
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'auth_login_guard_failed',
          reason: error is StateError ? 'missing_app_check' : 'request_failed',
          severity: 'medium',
          extra: <String, Object?>{'action': action},
        ),
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _buildLoginGuardPlayIntegrityPayload({
    required String action,
    required String email,
    String reason = '',
  }) async {
    if (kIsWeb) {
      return <String, dynamic>{};
    }

    final payload = <String, dynamic>{
      'emailHash': sha256
          .convert(utf8.encode(email.trim().toLowerCase()))
          .toString(),
      'action': action.trim().toLowerCase(),
      if (reason.trim().isNotEmpty) 'reason': reason.trim().toLowerCase(),
    };
    return _playIntegrityService
        .buildIntegrityPayload(
          flow: 'auth_login_guard_${action.trim().toLowerCase()}',
          payload: payload,
          autoWarmUp: true,
        )
        .timeout(const Duration(seconds: 3), onTimeout: () => null)
        .catchError((_) => null);
  }

  Future<void> _cacheSecurityVerdictFromPayload(
    Map<String, dynamic> payload,
  ) async {
    await SecurityVerdictCacheService.instance.save(
      levelKey: (payload['riskLevel'] as String?) ?? 'block',
      code: (payload['error'] as String?) ?? 'play_integrity_blocked',
      message:
          (payload['message'] as String?) ?? UiCopy.text('copy_8226b13bc362'),
      payload: payload,
      ttl: const Duration(minutes: 5),
    );
  }

  bool get _usesNativeAppleFlow =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  WebAuthenticationOptions _buildAppleWebAuthenticationOptions() {
    final clientId = AppConfig.appleSignInServiceId.trim();
    if (clientId.isEmpty) {
      throw UiCopy.text('copy_06bad51d391c') + UiCopy.text('copy_08115ce9ee91');
    }

    final redirectUrl = AppConfig.appleSignInRedirectUrl.trim();
    final redirectUri = Uri.tryParse(redirectUrl);
    if (redirectUrl.isEmpty ||
        redirectUri == null ||
        !redirectUri.isAbsolute ||
        redirectUri.scheme.toLowerCase() != 'https' ||
        redirectUri.host.trim().isEmpty) {
      throw UiCopy.text('copy_3a48f98fe29d') + UiCopy.text('copy_1d4156a3883e');
    }

    return WebAuthenticationOptions(
      clientId: clientId,
      redirectUri: redirectUri,
    );
  }

  firebase_auth.OAuthCredential _buildAppleFirebaseCredential(
    AuthorizationCredentialAppleID credential,
    String rawNonce,
  ) {
    final identityToken = credential.identityToken?.trim() ?? '';
    if (identityToken.isEmpty) {
      throw UiCopy.text('copy_5893c1507f48') + UiCopy.text('copy_e2f409eebfcc');
    }

    final givenName = credential.givenName?.trim();
    final familyName = credential.familyName?.trim();
    final hasName =
        (givenName?.isNotEmpty ?? false) || (familyName?.isNotEmpty ?? false);

    if (hasName) {
      return firebase_auth.AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        firebase_auth.AppleFullPersonName(
          givenName: givenName,
          familyName: familyName,
        ),
      );
    }

    return firebase_auth.OAuthProvider('apple.com').credential(
      idToken: identityToken,
      accessToken: credential.authorizationCode,
      rawNonce: rawNonce,
    );
  }

  Future<firebase_auth.UserCredential?> signInWithApple() async {
    await _waitForPendingEmailSignInBeforeSwitch();
    await _pendingSignOuts[_auth];
    try {
      firebase_auth.UserCredential userCredential;

      if (kIsWeb) {
        final provider = firebase_auth.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        final isAvailable = await SignInWithApple.isAvailable();
        if (!isAvailable) {
          throw UiCopy.text('copy_422db9a6de1d');
        }

        final rawNonce = generateNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
          state: generateNonce(length: 12),
          webAuthenticationOptions: _usesNativeAppleFlow
              ? null
              : _buildAppleWebAuthenticationOptions(),
        );

        final oauthCredential = _buildAppleFirebaseCredential(
          appleCredential,
          rawNonce,
        );
        await _pendingSignOuts[_auth];
        userCredential = await _auth.signInWithCredential(oauthCredential);
      }

      await _enforceNoNewAccountOnWeb(userCredential);

      if (userCredential.user != null) {
        final resolvedEmail =
            userCredential.user?.email?.trim().toLowerCase() ?? '';
        if (resolvedEmail.isNotEmpty &&
            !await recordDailyLoginLimit(resolvedEmail)) {
          await signOut();
          throw dailyLoginLimitMessage;
        }
        await _finalizeAuthenticatedSession(
          userCredential.user!,
          fallbackEmail: userCredential.user?.email,
        );
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return null;
      }

      if (error.code == AuthorizationErrorCode.invalidResponse) {
        throw UiCopy.text('copy_ecb9f90aabd8') +
            UiCopy.text('copy_b953f60368eb');
      }

      if (_usesNativeAppleFlow) {
        throw UiCopy.text('copy_22ce6a6ffa09', {'value1': error.code}) +
            UiCopy.text('copy_021d77b59648');
      }

      throw UiCopy.text('copy_22ce6a6ffa09', {'value1': error.code}) +
          UiCopy.text('copy_80190e2b9375');
    } on SignInWithAppleNotSupportedException {
      throw UiCopy.text('copy_96bfe5a00337') + UiCopy.text('copy_4bd0996be5a9');
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
        case 'email-already-in-use':
        case 'credential-already-in-use':
          throw UiCopy.text('copy_ea3891f0e5eb') +
              UiCopy.text('copy_1b0666a3e858');
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return null;
        case 'popup-blocked':
          throw UiCopy.text('copy_926297a8f3b4');
        case 'operation-not-allowed':
          throw UiCopy.text('copy_07520d3b674c') +
              UiCopy.text('copy_258797cde736');
        case 'network-request-failed':
          throw UiCopy.text('copy_a04d1237b911');
        default:
          throw UiCopy.text('copy_1d6e61cd9d38', {'value1': error.code}) +
              '${handleFirebaseAuthError(error)}';
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('auth_fallback_apple_sign_in'),
      ).message;
    }
  }

  Future<firebase_auth.UserCredential?> signInWithGoogle() async {
    await _waitForPendingEmailSignInBeforeSwitch();
    await _pendingSignOuts[_auth];
    try {
      firebase_auth.UserCredential userCredential;

      if (kIsWeb) {
        final provider = firebase_auth.GoogleAuthProvider();
        provider.addScope('email');
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        final googleSignIn = _googleSignIn ??= _googleSignInBuilder();
        if (!_isGoogleSignInInitialized) {
          final initCompleter = Completer<void>();
          googleSignIn
              .initialize()
              .then((_) {
                if (!initCompleter.isCompleted) initCompleter.complete();
              })
              .catchError((error) {
                if (!initCompleter.isCompleted) {
                  initCompleter.completeError(error);
                } else {
                  debugPrint('Late Google init error swallowed: $error');
                }
              });
          await initCompleter.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw UiCopy.text('copy_90ca8dbde435'),
          );
          _isGoogleSignInInitialized = true;
        }

        // Sign out trước để xoá cache phiên cũ, tránh lỗi treo và sign_in_failed
        try {
          await googleSignIn.signOut();
        } catch (error) {
          debugPrint('[Auth] Không xóa được phiên Google cũ: $error');
        }

        final authCompleter = Completer<dynamic>();
        googleSignIn
            .authenticate(scopeHint: const ['email'])
            .then((user) {
              if (!authCompleter.isCompleted) authCompleter.complete(user);
            })
            .catchError((error) {
              if (!authCompleter.isCompleted) {
                authCompleter.completeError(error);
              } else {
                debugPrint('Late Google auth error swallowed: $error');
              }
            });

        final googleUser = await authCompleter.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw UiCopy.text('copy_fe32cbfef9b5'),
        );
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw UiCopy.text('copy_f82aa856e91f');
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await _pendingSignOuts[_auth];
        userCredential = await _auth.signInWithCredential(credential);
      }

      await _enforceNoNewAccountOnWeb(userCredential);

      if (userCredential.user != null) {
        final resolvedEmail =
            userCredential.user?.email?.trim().toLowerCase() ?? '';
        if (resolvedEmail.isNotEmpty &&
            !await recordDailyLoginLimit(resolvedEmail)) {
          await signOut();
          throw dailyLoginLimitMessage;
        }
        await _finalizeAuthenticatedSession(
          userCredential.user!,
          fallbackEmail: userCredential.user?.email,
        );
      }

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
        case 'email-already-in-use':
        case 'credential-already-in-use':
          throw UiCopy.text('copy_271245472cc4');
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return null;
        case 'popup-blocked':
          throw UiCopy.text('copy_83f706a8dbd7');
        case 'network-request-failed':
          throw UiCopy.text('copy_fefe38950597');
        default:
          debugPrint(
            'Google FirebaseAuthException: ${error.code} ${error.message}',
          );
          throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      final errStr = error.toString().toLowerCase();
      bool isRealCancel = true;
      if (error is PlatformException && error.code == 'sign_in_failed') {
        isRealCancel = false;
      }
      if (isRealCancel &&
          (errStr.contains('sign_in_canceled') ||
              errStr.contains('canceled') ||
              errStr.contains('cancelled'))) {
        return null;
      }
      if (isGoogleSignInConfigMismatch(error)) {
        throw kDebugMode
            ? UiCopy.text('copy_8e3988e7f900')
            : UiCopy.text('copy_9d40ddd37ba1');
      }
      if (isGoogleSignInNetworkIssue(error)) {
        throw UiCopy.text('copy_1202f512b42f');
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate(
          'auth_fallback_google_sign_in',
        ),
      ).message;
    }
  }

  Future<firebase_auth.UserCredential?> signInWithFacebook() async {
    throw UiCopy.text('copy_66ddc48da6eb');
  }

  Future<void> checkRollingRegisterLimit() async {
    final filtered = await _loadPrunedRollingRegisterTimestamps();

    if (filtered.length >= 10) {
      final oldestTs = int.parse(filtered.first);
      final now = _nowProvider().millisecondsSinceEpoch;
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      final leftMs = sevenDaysMs - (now - oldestTs);
      final leftDays = (leftMs / (24 * 60 * 60 * 1000)).ceil();
      throw UiCopy.text('copy_56918ee43866') +
          UiCopy.text('copy_c5ac4b9929e5') +
          UiCopy.text('copy_3da28b7c03a3', {'value1': leftDays});
    }
  }

  Future<void> recordRollingRegisterLimit() async {
    final prefs = await _prefs;
    final filtered = await _loadPrunedRollingRegisterTimestamps();
    filtered.add(_nowProvider().millisecondsSinceEpoch.toString());
    await prefs.setStringList('il_create_account_7d_v1', filtered);
  }

  Future<void> _enforceNoNewAccountOnWeb(
    firebase_auth.UserCredential credential,
  ) async {
    if (kIsWeb) {
      if (credential.additionalUserInfo?.isNewUser == true) {
        final user = credential.user;
        if (user != null) {
          try {
            await user.delete();
          } catch (error) {
            debugPrint('[Auth] Không xóa được tài khoản Web vừa tạo: $error');
          }
        }
        await signOut();
        throw UiCopy.text('copy_513d718cccb6');
      }
    }
  }

  Future<firebase_auth.UserCredential?> registerWithEmailPassword(
    String email,
    String password,
  ) {
    if (_pendingEmailSignups[_auth] != null) {
      return Future.error(
        firebase_auth.FirebaseAuthException(code: 'too-many-requests'),
      );
    }
    final operation = _registerWithEmailPassword(email, password);
    _pendingEmailSignups[_auth] = operation;
    return operation.whenComplete(() {
      if (identical(_pendingEmailSignups[_auth], operation)) {
        _pendingEmailSignups[_auth] = null;
      }
    });
  }

  Future<firebase_auth.UserCredential?> _registerWithEmailPassword(
    String email,
    String password,
  ) async {
    await _pendingSignOuts[_auth];
    if (_auth.currentUser != null) {
      throw firebase_auth.FirebaseAuthException(code: 'operation-not-allowed');
    }
    if (kIsWeb) {
      throw UiCopy.text('copy_513d718cccb6');
    }

    await checkRollingRegisterLimit();

    try {
      await _pendingSignOuts[_auth];
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final createdUser = userCredential.user;
      if (createdUser == null) {
        throw firebase_auth.FirebaseAuthException(code: 'user-token-expired');
      }
      try {
        await recordRollingRegisterLimit();
      } catch (_) {
        debugPrint(
          '[Auth] Signup succeeded; local counter could not be saved.',
        );
      }
      _requireCurrentSession(createdUser.uid);
      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('auth_fallback_register'),
      ).message;
    }
  }

  Future<bool> rollbackIncompleteEmailSignup(String email) async {
    var deletedAuthUser = false;
    final normalizedEmail = email.trim().toLowerCase();
    var currentUser = _auth.currentUser;

    if (currentUser != null) {
      try {
        await currentUser.reload();
        currentUser = _auth.currentUser ?? currentUser;
      } catch (error) {
        debugPrint('[Auth] Không tải lại được tài khoản đăng ký dở: $error');
      }

      final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();
      if (currentUser != null && currentEmail == normalizedEmail) {
        final hasKnownHouse = await _hasKnownHouseContext(currentUser.uid);
        if (hasKnownHouse == false) {
          try {
            await currentUser.delete();
            deletedAuthUser = true;
          } on firebase_auth.FirebaseAuthException catch (error) {
            debugPrint(
              'rollbackIncompleteEmailSignup delete failed: '
              '${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể xóa tài khoản đăng ký dang dở.').message}',
            );
          } catch (error) {
            debugPrint(
              'rollbackIncompleteEmailSignup delete failed: '
              '${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể xóa tài khoản đăng ký dang dở.').message}',
            );
          }
        }
      }
    }

    await signOut();

    if (deletedAuthUser) {
      await _rollbackLatestRollingRegisterLimit();
    }

    return deletedAuthUser;
  }

  Future<List<String>> _loadPrunedRollingRegisterTimestamps() async {
    final prefs = await _prefs;
    final rawTimestamps = prefs.getStringList('il_create_account_7d_v1') ?? [];
    final now = _nowProvider().millisecondsSinceEpoch;
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    final filtered = <String>[];

    for (final rawTs in rawTimestamps) {
      final parsedTs = int.tryParse(rawTs);
      if (parsedTs == null) {
        continue;
      }
      if (now - parsedTs < sevenDaysMs) {
        filtered.add(parsedTs.toString());
      }
    }

    filtered.sort();
    return filtered;
  }

  Future<bool?> _hasKnownHouseContext(String uid) async {
    final prefs = await _prefs;
    final cachedHouseId = (prefs.getString('il_house_id') ?? '').trim();
    final cachedAuthUid = (prefs.getString('il_auth_uid') ?? '').trim();
    if (cachedHouseId.isNotEmpty) {
      if (cachedAuthUid == uid) {
        return true;
      }
      await prefs.remove('il_house_id');
      await prefs.remove('il_auth_uid');
      await prefs.remove('il_role');
    }

    try {
      final houseIdSnap = await _db.child('users/$uid/houseId').get();
      final houseId = houseIdSnap.value?.toString().trim() ?? '';
      return houseId.isNotEmpty;
    } catch (error) {
      debugPrint(
        '_hasKnownHouseContext failed for $uid: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể kiểm tra ngữ cảnh nhà hiện tại.').message}',
      );
      return null;
    }
  }

  Future<void> _rollbackLatestRollingRegisterLimit() async {
    final filtered = await _loadPrunedRollingRegisterTimestamps();
    if (filtered.isEmpty) {
      return;
    }

    final lastTs = int.tryParse(filtered.last);
    if (lastTs == null) {
      return;
    }

    const rollbackWindowMs = 15 * 60 * 1000;
    final ageMs = _nowProvider().millisecondsSinceEpoch - lastTs;
    if (ageMs < 0 || ageMs > rollbackWindowMs) {
      return;
    }

    filtered.removeLast();
    final prefs = await _prefs;
    await prefs.setStringList('il_create_account_7d_v1', filtered);
  }

  Future<void> signOut() {
    final auth = _auth;
    final pending = _pendingSignOuts[auth];
    if (pending != null) return pending;
    final operation = _performSignOut().whenComplete(() {
      _pendingSignOuts[auth] = null;
    });
    _pendingSignOuts[auth] = operation;
    return operation;
  }

  Future<void> waitForPendingSignOut() async {
    await _pendingSignOuts[_auth];
  }

  Future<void> _performSignOut() async {
    final pendingEmailSignIn = _pendingEmailSignIns[_auth];
    if (pendingEmailSignIn != null) {
      try {
        // Đợi native request kết thúc trước khi signOut để request cũ không
        // đăng nhập lại sau khi người dùng đã yêu cầu thoát.
        await pendingEmailSignIn;
      } catch (_) {
        // Dù request lỗi vẫn tiếp tục dọn phiên local/Firebase.
      }
    }
    final prefs = await _prefs;
    // 1. Set presence offline with a very short timeout
    try {
      final houseId = await AuthHouseContextService.quickHouseId(
        firebaseAuth: _auth,
      );
      final role = RoleUtils.currentRoleSync();
      if (houseId != null && houseId.isNotEmpty) {
        await PresenceService()
            .goOffline(houseId: houseId, role: role)
            .timeout(const Duration(milliseconds: 300))
            .catchError(
              (error) => debugPrint('[Auth] Không đặt được offline: $error'),
            );
      }
    } catch (error) {
      debugPrint('[Auth] Không chuẩn bị được trạng thái offline: $error');
    }

    final List<Future<void>> asyncCleanups = [];
    asyncCleanups.add(
      Future<void>.sync(
        () => NotificationService().clearTokenOnSignOut(),
      ).timeout(const Duration(seconds: 4)).catchError(
        (error) => debugPrint('[Auth] Không xóa được push token: $error'),
      ),
    );

    try {
      if (!kIsWeb && _googleSignIn != null) {
        asyncCleanups.add(
          _googleSignIn!.signOut().timeout(const Duration(seconds: 4)).catchError(
            (error) => debugPrint('[Auth] Google sign-out lỗi: $error'),
          ),
        );
      }
    } catch (error) {
      debugPrint('[Auth] Không khởi tạo được Google sign-out: $error');
    }

    await Future.wait(asyncCleanups).catchError((error) {
      debugPrint('[Auth] Một tác vụ sign-out nền bị lỗi: $error');
      return <void>[];
    });

    await Future<void>.sync(
      () => SettingsSyncService().clearLocalSyncedSettings(),
    ).catchError(
      (error) => debugPrint('[Auth] Xóa settings cache lỗi: $error'),
    );
    await Future.wait([
      _clearSensitiveLocalData(prefs),
      SecureStorageService.instance.clearForSignOut(),
      OfflineCacheService.clearAllCache(),
    ]);
    AuthHouseContextService.clearMemHouseId();

    // 4. Các tác vụ UI/Memory nhẹ chạy đồng bộ lập tức
    try {
      EncryptionService().clearCache();
    } catch (error) {
      debugPrint('[Auth] Xóa encryption cache lỗi: $error');
    }
    try {
      RoleUtils.roleNotifier.value = null;
    } catch (error) {
      debugPrint('[Auth] Reset role notifier lỗi: $error');
    }
    try {
      RoleUtils.duplicateRoleNotifier.value = false;
    } catch (error) {
      debugPrint('[Auth] Reset duplicate-role notifier lỗi: $error');
    }
    try {
      PaintingBinding.instance.imageCache.clear();
    } catch (error) {
      debugPrint('[Auth] Xóa image cache lỗi: $error');
    }
    try {
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (error) {
      debugPrint('[Auth] Xóa live image cache lỗi: $error');
    }
    await _auth.signOut();
  }

  Future<String> verifyAccountDeletionOtp(
    String email,
    String otp, {
    required String expectedUid,
    String? partnerUid,
  }) async {
    if (_auth.currentUser?.uid != expectedUid) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: AppErrorMapper.authSyncMessage,
      );
    }
    final result = await _functions
        .httpsCallable(
          'verifyAccountDeletionOTP',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<dynamic>({
          'email': email,
          'otp': otp,
          'action': partnerUid == null ? 'request' : 'approve',
          'targetUid': ?partnerUid,
        })
        .timeout(const Duration(seconds: 15));
    if (_auth.currentUser?.uid != expectedUid) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: AppErrorMapper.authSyncMessage,
      );
    }
    final data = result.data;
    if (data is! Map ||
        data['proof'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['proof'] as String)) {
      throw AppErrorInfo(
        kind: AppErrorKind.server,
        message: L10nService().translate('account_deletion_verify_again'),
      );
    }
    return data['proof'] as String;
  }

  Future<int> approvePartnerDeletion({
    required String partnerUid,
    required String expectedUid,
    required String verificationProof,
  }) async {
    final user = _auth.currentUser;
    void checkIdentity() {
      if (user == null ||
          user.uid != expectedUid ||
          _auth.currentUser?.uid != expectedUid ||
          partnerUid == expectedUid ||
          partnerUid.isEmpty) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
    }

    checkIdentity();
    final token = await user!
        .getIdToken(true)
        .timeout(const Duration(seconds: 8));
    if (token == null || token.isEmpty) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: AppErrorMapper.authSyncMessage,
      );
    }
    final headers = await AppCheckHttpHeaders.withOptionalToken({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 8));
    checkIdentity();
    final response = await _httpPost(
      accountDeletionSiblingUri(
        AppConfig.deleteAccountUrl,
        'approvePartnerDeletionHttp',
      ),
      headers: headers,
      body: jsonEncode({
        'partnerUid': partnerUid,
        'verificationProof': verificationProof,
      }),
    ).timeout(const Duration(seconds: 15));
    checkIdentity();
    if (response.statusCode != 200) {
      throw accountDeletionError(response.body) ??
          AppErrorInfo(
            kind: AppErrorKind.server,
            message: L10nService().translate(
              'account_deletion_status_unavailable',
            ),
          );
    }
    final result = jsonDecode(response.body);
    final date = result is Map ? result['scheduledAt'] : null;
    if (result is! Map ||
        result['ok'] != true ||
        result['status'] != 'partner_approved' ||
        date is! int ||
        date <= 0 ||
        date > 8640000000000000) {
      throw AppErrorInfo(
        kind: AppErrorKind.server,
        message: L10nService().translate('account_deletion_status_unavailable'),
      );
    }
    return date;
  }

  Future<Map<String, dynamic>> deleteAccount({
    String? verificationProof,
    String? expectedUid,
  }) async {
    if (kIsWeb) {
      throw UiCopy.text('copy_3aeb67728be9');
    }

    final deleteEndpoint = AppConfig.deleteAccountUrl.trim();
    if (deleteEndpoint.isEmpty) {
      throw UiCopy.text('copy_cdff04e5e3f0');
    }
    final user = _auth.currentUser;
    if (verificationProof != null &&
        (expectedUid == null || user?.uid != expectedUid)) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: AppErrorMapper.authSyncMessage,
      );
    }
    if (user == null) {
      throw UiCopy.text('copy_880e7a68ffb9');
    }

    if (kDebugMode) {
      debugPrint(
        'deleteAccount(): start uid=${user.uid} endpoint=$deleteEndpoint',
      );
    }

    try {
      final result = await _deleteAccountFromServer(
        user,
        verificationProof: verificationProof,
      );
      if (kDebugMode) {
        debugPrint('deleteAccount(): success uid=${user.uid}');
      }
      return result;
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'deleteAccount(): FirebaseAuthException code=${error.code} '
          'message=${error.message}',
        );
      }
      if (error.code == 'requires-recent-login') {
        if (kDebugMode) {
          debugPrint('deleteAccount(): reauth required, retrying once');
        }
        await _reauthenticateCurrentUserWithLinkedProvider(user);
        final result = await _deleteAccountFromServer(
          user,
          verificationProof: verificationProof,
        );
        if (kDebugMode) {
          debugPrint('deleteAccount(): success after reauth uid=${user.uid}');
        }
        return result;
      }
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (error is AppErrorInfo) rethrow;
      final normalized = error.toString().toLowerCase();
      if (normalized.contains('đăng nhập lại trước khi xóa tài khoản') ||
          normalized.contains('đăng nhập lại rồi thử xóa tài khoản') ||
          normalized.contains('phiên đăng nhập đã hết hạn') ||
          normalized.contains('phiên đăng nhập không còn hợp lệ')) {
        if (kDebugMode) {
          debugPrint('deleteAccount(): retrying after session error: $error');
        }
        await _reauthenticateCurrentUserWithLinkedProvider(user);
        final result = await _deleteAccountFromServer(
          user,
          verificationProof: verificationProof,
        );
        if (kDebugMode) {
          debugPrint(
            'deleteAccount(): success after session retry uid=${user.uid}',
          );
        }
        return result;
      }
      if (kDebugMode) {
        debugPrint(
          'deleteAccount(): failed with error=${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể xóa tài khoản lúc này.').message}',
        );
      }
      if (error is String) rethrow;
      final resolvedError = AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate(
          'auth_fallback_account_delete',
        ),
      );
      throw resolvedError.message;
    }
  }

  Future<AccountDeletionStatus?> getOwnAccountDeletionStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: AppErrorMapper.authSyncMessage,
      );
    }
    try {
      final uri = accountDeletionSiblingUri(
        AppConfig.deleteAccountUrl,
        'getOwnAccountDeletionStatusHttp',
      );
      final token = await user.getIdToken().timeout(const Duration(seconds: 8));
      if (token == null || token.isEmpty) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      try {
        headers = await AppCheckHttpHeaders.withOptionalToken(
          headers,
        ).timeout(const Duration(seconds: 4));
      } catch (_) {
        // App Check lỗi/chậm: vẫn gọi tiếp, server quyết định.
      }
      if (_auth.currentUser?.uid != user.uid) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      final response = await _httpPost(
        uri,
        headers: headers,
        body: '{}',
      ).timeout(const Duration(seconds: 8));
      if (_auth.currentUser?.uid != user.uid) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      if (response.statusCode != 200) {
        final error = accountDeletionError(response.body);
        if (error != null) throw error;
        if (response.statusCode == 401) {
          throw AppErrorInfo(
            kind: AppErrorKind.user,
            message: AppErrorMapper.authSyncMessage,
          );
        }
        if (response.statusCode == 403) {
          // AppCheck hoac quyen hanh: tai khoan khong co lenh xoa chan
          return null;
        }
        throw const FormatException('deletion_status_failed');
      }
      return AccountDeletionStatus.fromOwnResponse(
        jsonDecode(response.body),
        uid: user.uid,
      );
    } catch (error) {
      if (error is AppErrorInfo) rethrow;
      throw AppErrorInfo(
        kind: AppErrorKind.server,
        message: L10nService().translate('account_deletion_status_unavailable'),
      );
    }
  }

  Future<void> undoScheduledDeletion() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: AppErrorMapper.authSyncMessage,
      );
    }
    try {
      final undoEndpoint = accountDeletionSiblingUri(
        AppConfig.deleteAccountUrl,
        'undoAccountDeletionHttp',
      );
      final idToken = await user
          .getIdToken(true)
          .timeout(const Duration(seconds: 8));
      if (idToken == null || idToken.isEmpty) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      final headers = await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }).timeout(const Duration(seconds: 8));
      if (_auth.currentUser?.uid != user.uid) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      final response = await _httpPost(
        undoEndpoint,
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      if (_auth.currentUser?.uid != user.uid) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      if (response.statusCode != 200) {
        final deletionError = accountDeletionError(response.body);
        if (deletionError != null) throw deletionError;
        unawaited(
          RevenueSecurityTelemetryService.instance.logEvent(
            type: 'undo_delete_failed',
            reason: 'server_rejected',
            severity: response.statusCode == 401 || response.statusCode == 403
                ? 'high'
                : 'medium',
            extra: <String, Object?>{'statusCode': response.statusCode},
          ),
        );
        if (response.statusCode == 401) {
          throw AppErrorInfo(
            kind: AppErrorKind.user,
            message: AppErrorMapper.authSyncMessage,
          );
        }
        throw const FormatException('deletion_cancel_failed');
      }
      final result = jsonDecode(response.body);
      if (result is! Map || result['ok'] != true) {
        throw const FormatException('invalid_deletion_cancel_response');
      }
    } catch (error) {
      if (error is AppErrorInfo) rethrow;
      throw AppErrorInfo(
        kind: AppErrorKind.server,
        message: L10nService().translate('account_deletion_cancel_unconfirmed'),
      );
    }
  }

  Future<void> revokeOtherSessionsAfterPasswordChange() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_5d6354a5c9ea');
    }

    final idToken = await user.getIdToken(true) ?? '';
    if (idToken.isEmpty) {
      throw UiCopy.text('copy_e9918327e062');
    }

    final endpoint = AppConfig.deleteAccountUrl.trim().replaceAll(
      'deleteUserDataHttp',
      'revokeOtherSessionsAfterPasswordChangeHttp',
    );
    final response = await _httpPost(
      Uri.parse(endpoint),
      headers: await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }),
      body: jsonEncode({'source': 'flutter_app'}),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        unawaited(
          RevenueSecurityTelemetryService.instance.logEvent(
            type: 'revoke_other_sessions_failed',
            reason: 'unauthorized',
            severity: 'high',
            extra: <String, Object?>{'statusCode': response.statusCode},
          ),
        );
        throw UiCopy.text('copy_da04a14910a6');
      }
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'revoke_other_sessions_failed',
          reason: 'server_rejected',
          severity: 'medium',
          extra: <String, Object?>{'statusCode': response.statusCode},
        ),
      );
      throw UiCopy.text('copy_8c1b274a58ce');
    }
  }

  Future<void> _ensureUserProfileExists(firebase_auth.User user) async {
    final userRef = _db.child('users/${user.uid}');
    final existingSnap = await userRef.get();

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email?.trim().toLowerCase(),
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'lastLoginAt': ServerValue.timestamp,
      'authProvider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
    }..removeWhere((key, value) => value == null);

    if (!existingSnap.exists) {
      payload['createdAt'] = ServerValue.timestamp;
    }

    await userRef.update(payload);
  }

  Future<void> _finalizeAuthenticatedSession(
    firebase_auth.User user, {
    String? fallbackEmail,
  }) async {
    try {
      await _finalizeAuthenticatedSessionInternal(
        user,
        fallbackEmail: fallbackEmail,
      ).timeout(_sessionFinalizeTimeout);
    } catch (error) {
      // Không để phiên đã đăng nhập nửa chừng tồn tại sau lỗi/timeout.
      try {
        await signOut().timeout(const Duration(seconds: 4));
      } catch (cleanupError) {
        debugPrint('[Auth] Finalize cleanup failed: $cleanupError');
      }
      rethrow;
    }
  }

  Future<void> _finalizeAuthenticatedSessionInternal(
    firebase_auth.User user, {
    String? fallbackEmail,
  }) async {
    _requireCurrentSession(user.uid);
    final resolvedEmail = (user.email ?? fallbackEmail ?? '').trim();

    // Parallel Phase 1: Check block reason, ensure user profile exists, fetch house ID, read prefs, and restore settings from cloud
    final phase1Results = await Future.wait([
      if (resolvedEmail.isNotEmpty)
        _adminService
            .getSystemBlockReason(
              resolvedEmail,
              allowAdminBypass: true,
              forceRefreshAdmin: true,
            )
            .catchError((error) {
              debugPrint('Failed to check system block reason: $error');
              return null;
            })
      else
        Future<String?>.value(null),
      _ensureUserProfileExists(user),
      _db.child('users/${user.uid}/houseId').get(),
      _prefs,
      SettingsSyncService().prepareForSignIn(user.uid),
    ]).timeout(_sessionFinalizePhaseTimeout);
    _requireCurrentSession(user.uid);

    final postLoginBlockReason = phase1Results[0] as String?;
    if (postLoginBlockReason != null) {
      await signOut();
      throw postLoginBlockReason;
    }

    final houseIdSnap = phase1Results[2] as DataSnapshot;
    final rawHouseId = houseIdSnap.value?.toString().trim();
    final houseId = (rawHouseId == null || rawHouseId.isEmpty)
        ? null
        : rawHouseId;

    final prefs = phase1Results[3] as SharedPreferences;

    String? existingRole;
    if (prefs.getString('il_auth_uid') != user.uid) {
      await prefs.remove('il_role');
      _requireCurrentSession(user.uid);
      await SecureStorageService.instance.delete(SecureStorageService.keyRole);
      _requireCurrentSession(user.uid);
    }
    if (houseId != null && houseId.isNotEmpty) {
      await prefs.setString('il_house_id', houseId);
      _requireCurrentSession(user.uid);
      await prefs.setString('il_auth_uid', user.uid);
      _requireCurrentSession(user.uid);
      await SecureStorageService.instance.write(
        SecureStorageService.keyHouseId,
        houseId,
      );
      _requireCurrentSession(user.uid);
      await SecureStorageService.instance.write(
        SecureStorageService.keyAuthUid,
        user.uid,
      );
      _requireCurrentSession(user.uid);
      existingRole = prefs.getString('il_role');
      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/houseId')
            .set(houseId);
      } catch (error) {
        debugPrint('[Auth] Không đồng bộ được houseId vào user: $error');
      }
    } else {
      await prefs.remove('il_house_id');
      _requireCurrentSession(user.uid);
      await prefs.remove('il_auth_uid');
      _requireCurrentSession(user.uid);
      await prefs.remove('il_role');
      _requireCurrentSession(user.uid);
      await SecureStorageService.instance.delete(
        SecureStorageService.keyHouseId,
      );
      _requireCurrentSession(user.uid);
      await SecureStorageService.instance.delete(
        SecureStorageService.keyAuthUid,
      );
      _requireCurrentSession(user.uid);
      await SecureStorageService.instance.delete(SecureStorageService.keyRole);
      _requireCurrentSession(user.uid);
      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/houseId')
            .remove();
      } catch (error) {
        debugPrint('[Auth] Không xóa được houseId cũ khỏi user: $error');
      }
    }

    _requireCurrentSession(user.uid);
    await prefs.setString(
      'il_login_ts',
      _nowProvider().millisecondsSinceEpoch.toString(),
    );
    _requireCurrentSession(user.uid);

    final shouldDetectRole =
        houseId != null &&
        houseId.isNotEmpty &&
        existingRole != 'user1' &&
        existingRole != 'user2';

    if (resolvedEmail.contains('@')) {
      unawaited(
        _houseContextService
            .syncSecurityEmailForCurrentUser(
              user: user,
              email: resolvedEmail,
              houseId: houseId,
            )
            .catchError((error) {
              debugPrint('Failed to sync security email: $error');
            }),
      );
    }

    unawaited(
      DeviceManagerService()
          .registerCurrentDevice()
          .timeout(const Duration(seconds: 4))
          .catchError((error) {
            debugPrint(
              'registerCurrentDevice skipped during auth finalize: '
              '${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể đăng ký thiết bị hiện tại lúc này.').message}',
            );
          }),
    );

    // Parallel Phase 2: Check ban status, sync relationship mode, fetch settings, detect auto role
    final phase2Results = await Future.wait([
      _houseContextService.checkBanStatus(houseId, onForcedSignOut: signOut),
      _houseContextService
          .syncRelationshipModeForCurrentUser(user: user, houseId: houseId)
          .catchError((error) {
            debugPrint('Failed to sync relationship mode: $error');
            return null;
          }),
      if (houseId != null && houseId.isNotEmpty)
        _db
            .child('houses/$houseId/settings')
            .get()
            .then<DataSnapshot?>((snap) => snap)
            .catchError((error) {
              debugPrint('Failed to fetch house settings: $error');
              return null;
            })
      else
        Future<DataSnapshot?>.value(null),
      if (shouldDetectRole)
        _houseContextService.detectAutoRole(houseId).catchError((error) {
          debugPrint('Failed to detect auto role: $error');
          return '';
        })
      else
        Future<String>.value(''),
    ]).timeout(_sessionFinalizePhaseTimeout);
    _requireCurrentSession(user.uid);

    final settingsSnap = phase2Results[2] as DataSnapshot?;
    if (settingsSnap != null && settingsSnap.exists) {
      try {
        final settings = settingsSnap.value is Map
            ? _asStringDynamicMap(settingsSnap.value)
            : null;
        if (settings != null) {
          final primaryBackgroundUrl =
              settings['customBackgroundUrl']?.toString().trim() ?? '';
          final legacyBackgroundUrl =
              settings['customHomeBackground']?.toString().trim() ?? '';
          final customBackgroundUrl = primaryBackgroundUrl.isNotEmpty
              ? primaryBackgroundUrl
              : legacyBackgroundUrl;
          if (customBackgroundUrl.isNotEmpty) {
            await UiPrefs.ensureLoaded();
            _requireCurrentSession(user.uid);
            await UiPrefs.saveState(
              UiPrefs.notifier.value.copyWith(
                customBackgroundUrl: customBackgroundUrl,
              ),
            );
          }
        }
      } catch (error) {
        debugPrint(
          'Failed to sync UI preferences: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể đồng bộ cài đặt giao diện lúc này.').message}',
        );
      }
    }

    if (shouldDetectRole) {
      _requireCurrentSession(user.uid);
      final role = phase2Results[3] as String;
      if (role == 'user1' || role == 'user2') {
        await prefs.setString('il_role', role);
      }
    }

    _requireCurrentSession(user.uid);
    unawaited(
      CriticalDataSyncService()
          .syncCurrentUserData(houseId: houseId, force: true)
          .catchError((error) {
            debugPrint(
              'CriticalDataSync skipped during auth finalize: '
              '${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể đồng bộ dữ liệu quan trọng lúc này.').message}',
            );
          }),
    );
  }

  Future<Map<String, dynamic>> _getDailyLoginTracker() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_dailyLoginTrackerPrefsKey);
      if (raw == null || raw.trim().isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = await compute(jsonDecode, raw);
      return _asStringDynamicMap(decoded);
    } catch (error) {
      debugPrint(
        '_getDailyLoginTracker failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể đọc bộ đếm đăng nhập hôm nay.').message}',
      );
      try {
        final prefs = await _prefs;
        await prefs.remove(_dailyLoginTrackerPrefsKey);
      } catch (cleanupError) {
        debugPrint('[Auth] Không xóa được bộ đếm đăng nhập lỗi: $cleanupError');
      }
      return <String, dynamic>{};
    }
  }

  List<String> _trackerAccounts(Map<String, dynamic> tracker) {
    final raw = tracker['acc'];
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }
    return <String>[];
  }

  String _currentLoginTrackerDay() {
    final now = _nowProvider();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _deleteAccountFromServer(
    firebase_auth.User user, {
    String? verificationProof,
  }) async {
    final endpoint = AppConfig.deleteAccountUrl.trim();
    if (endpoint.isEmpty) {
      throw UiCopy.text('copy_cdff04e5e3f0');
    }

    try {
      final idToken = await user.getIdToken(true) ?? '';
      if (kDebugMode) {
        debugPrint(
          '_deleteAccountFromServer(): uid=${user.uid} '
          'tokenEmpty=${idToken.isEmpty}',
        );
      }
      if (idToken.isEmpty) {
        throw UiCopy.text('copy_cf9baffedf61');
      }

      final deviceId = await _houseContextService.getDeviceId();
      if (kDebugMode) {
        debugPrint(
          '_deleteAccountFromServer(): endpoint=$endpoint deviceId=$deviceId',
        );
      }
      final headers = await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      });
      if (_auth.currentUser?.uid != user.uid) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }
      final response = await _httpPost(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode({
          'source': 'flutter_app',
          'deviceId': deviceId,
          'verificationProof': ?verificationProof,
        }),
      ).timeout(const Duration(seconds: 20));
      if (_auth.currentUser?.uid != user.uid) {
        throw AppErrorInfo(
          kind: AppErrorKind.user,
          message: AppErrorMapper.authSyncMessage,
        );
      }

      if (kDebugMode) {
        debugPrint(
          '_deleteAccountFromServer(): status=${response.statusCode} '
          'body=${response.body}',
        );
      }

      if (response.statusCode != 200) {
        final deletionError = accountDeletionError(response.body);
        if (deletionError != null) throw deletionError;
        if (response.statusCode == 409) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map &&
                decoded['error'] == 'deletion_already_scheduled') {
              final scheduledAt = decoded['scheduledAt'];
              final delayDays = scheduledAt is num
                  ? DateTime.fromMillisecondsSinceEpoch(
                      scheduledAt.toInt(),
                    ).difference(DateTime.now()).inDays.clamp(0, 30)
                  : 3;
              return <String, dynamic>{
                'ok': true,
                'scheduledAt': scheduledAt,
                'status': decoded['status'] ?? 'scheduled',
                'delayDays': delayDays,
              };
            }
          } catch (parseError) {
            debugPrint(
              '[Auth] Không đọc được phản hồi xóa tài khoản: $parseError',
            );
          }
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          unawaited(
            RevenueSecurityTelemetryService.instance.logEvent(
              type: 'delete_account_failed',
              reason: 'unauthorized',
              severity: 'high',
              extra: <String, Object?>{'statusCode': response.statusCode},
            ),
          );
          throw UiCopy.text('copy_ed257df55575');
        }
        if (kDebugMode) {
          debugPrint(
            'Delete account endpoint failed: ${response.statusCode} ${response.body}',
          );
        }
        unawaited(
          RevenueSecurityTelemetryService.instance.logEvent(
            type: 'delete_account_failed',
            reason: 'server_rejected',
            severity: 'medium',
            extra: <String, Object?>{'statusCode': response.statusCode},
          ),
        );
        throw UiCopy.text('copy_6a1f86e07400');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        throw UiCopy.text('copy_b19a41b1c6a1');
      }
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw UiCopy.text('copy_14c2fb0aa26a');
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Delete account endpoint error: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể gọi máy chủ xóa tài khoản lúc này.').message}',
        );
      }
      if (error is String || error is AppErrorInfo) rethrow;
      throw UiCopy.text('copy_7c1e6549c141');
    }
  }

  @visibleForTesting
  Future<void> clearLocalDataForSignOutTesting() async {
    final prefs = await _prefs;
    await _clearSensitiveLocalData(prefs);
  }

  Future<void> _clearSensitiveLocalData(SharedPreferences prefs) async {
    final keysToRemove = <String>{
      ..._signOutClearedPrefsKeys,
      ...prefs.getKeys().where(
        (key) =>
            key.startsWith('il_rel_mode_') ||
            key.startsWith('il_diary_privacy_seen_') ||
            key.startsWith('il_first_setup_guide_pending_'),
      ),
    };
    keysToRemove.removeAll(_signOutPreservedPrefsKeys);
    for (final key in keysToRemove) {
      if (!await prefs.remove(key)) {
        throw StateError('Failed to clear local authentication state');
      }
    }
  }

  void _requireCurrentSession(String uid) {
    if (_auth.currentUser?.uid != uid || _pendingSignOuts[_auth] != null) {
      throw firebase_auth.FirebaseAuthException(code: 'user-token-expired');
    }
  }
}

class _ServerLoginGuardPrecheck {
  const _ServerLoginGuardPrecheck({
    this.allowed = true,
    this.message = '',
    this.accountExists,
  });

  final bool allowed;
  final String message;
  final bool? accountExists;
}

class _ServerLoginGuardRecord {
  const _ServerLoginGuardRecord({this.allowed = true, this.message = ''});

  final bool allowed;
  final String message;
}

class _LoginEmailResolution {
  const _LoginEmailResolution({required this.email, required this.source});

  final String email;
  final String source;
}
