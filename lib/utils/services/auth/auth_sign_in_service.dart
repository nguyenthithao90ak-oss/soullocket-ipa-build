import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tiktok_business_sdk/tiktok_business_sdk.dart';
import 'package:tiktok_business_sdk/tiktok_business_sdk_platform_interface.dart';

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
import 'package:soullocket_app/utils/services/house_service.dart';
import 'play_integrity_service.dart';
import 'auth_admin_service.dart';
import 'auth_house_context_service.dart';
import 'auth_support.dart';

part 'auth_sign_in_service_social.dart';

class AuthSignInService {
  AuthSignInService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    DatabaseReference? databaseRef,
    SharedPreferencesProvider? sharedPreferencesProvider,
    GoogleSignInBuilder? googleSignInBuilder,
    FirebaseFunctions? firebaseFunctions,
    HttpPost? httpPost,
    NowProvider? nowProvider,
    required AuthAdminService adminService,
    required AuthHouseContextService houseContextService,
  })  : _firebaseAuth = firebaseAuth,
        _databaseRef = databaseRef,
        _sharedPreferencesProvider =
            sharedPreferencesProvider ?? SharedPreferences.getInstance,
        _googleSignInBuilder =
            googleSignInBuilder ?? (() => GoogleSignIn.instance),
        _firebaseFunctions = firebaseFunctions,
        _httpPost = httpPost ?? http.post,
        _nowProvider = nowProvider ?? DateTime.now,
        _adminService = adminService,
        _houseContextService = houseContextService,
        _playIntegrityService = PlayIntegrityService();

  static const String dailyLoginLimitMessage =
      'Thiết bị này chỉ được đăng nhập tối đa 3 tài khoản mới trong 1 ngày.';
  static const String accountNotFoundMessage =
      'Tài khoản không tồn tại. Vui lòng kiểm tra lại email hoặc tạo tài khoản mới.';
  static const String wrongPasswordMessage = 'Sai mật khẩu. Vui lòng thử lại.';
  static bool _isGoogleSignInInitialized = false;
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

  FacebookAuth get _facebookAuth => FacebookAuth.instance;

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
      debugPrint('checkDailyLoginLimit failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể kiểm tra giới hạn đăng nhập hôm nay.',
      ).message}');
      return true;
    }
  }

  Future<bool> recordDailyLoginLimit(String email) async {
    try {
      final normalizedEmail = normalizeEmailKey(email);
      final dayKey = _currentLoginTrackerDay();
      final tracker = await _getDailyLoginTracker();
      final existingDay = tracker['d']?.toString() ?? '';
      final accounts =
          existingDay == dayKey ? _trackerAccounts(tracker) : <String>[];

      if (!accounts.contains(normalizedEmail)) {
        if (accounts.length >= AppConfig.maxNewLoginsPerDay) {
          return false;
        }
        accounts.add(normalizedEmail);
      }

      final prefs = await _prefs;
      await prefs.setString(
        _dailyLoginTrackerPrefsKey,
        jsonEncode({
          'd': dayKey,
          'acc': accounts,
        }),
      );
      return true;
    } catch (error) {
      debugPrint('recordDailyLoginLimit failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể ghi giới hạn đăng nhập hôm nay.',
      ).message}');
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
      throw 'Bạn cần đăng nhập lại trước khi lưu email phụ.';
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
      throw 'Email này đã là email đăng nhập chính của tài khoản khác. Hãy chọn email khác.';
    }

    throw 'Email phụ này đã được dùng để đăng nhập cho tài khoản khác. Hãy chọn email khác.';
  }

  Future<_LoginEmailResolution> _lookupLoginEmailResolution(
    String email, {
    required bool allowFallbackOnFailure,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      return _LoginEmailResolution(
        email: normalizedEmail,
        source: 'input',
      );
    }

    try {
      final callable = _functions.httpsCallable('resolveLoginEmailAlias');
      final result = await callable.call(<String, dynamic>{
        'email': normalizedEmail,
      });
      final payload = _asStringDynamicMap(result.data);
      final resolvedEmail =
          (payload['email'] ?? '').toString().trim().toLowerCase();
      final source =
          (payload['source'] ?? 'input').toString().trim().toLowerCase();

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
                ? 'Email đăng nhập không hợp lệ.'
                : 'Email phụ này chưa thể dùng để đăng nhập.');
      }
      if (!allowFallbackOnFailure) {
        throw message.isNotEmpty
            ? message
            : 'Không kiểm tra được email phụ: hãy kiểm tra email đã nhập, trạng thái đăng nhập và kết nối mạng.';
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
          fallbackMessage:
              'Không kiểm tra được email phụ: hãy kiểm tra email đã nhập, trạng thái đăng nhập và kết nối mạng.',
        ).message;
      }
      if (kDebugMode) {
        debugPrint(
          'resolveLoginEmailAlias unexpected fallback for '
          '$normalizedEmail: $error',
        );
      }
    }

    return _LoginEmailResolution(
      email: normalizedEmail,
      source: 'input',
    );
  }

  Future<firebase_auth.UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
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
      final precheck = await _precheckServerLoginGuard(normalizedEmail);
      accountExistsHint = precheck.accountExists;
      if (!precheck.allowed) {
        throw precheck.message;
      }
      if (accountExistsHint == false) {
        await _recordServerLoginFailure(
          normalizedEmail,
          reason: 'account_not_found',
        );
        throw accountNotFoundMessage;
      }

      final userCredential = await _auth
          .signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password.trim(),
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw 'Lỗi kết nối máy chủ! Vui lòng kiểm tra lại mạng.',
          );

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
        fallbackMessage:
            'Không đăng nhập được: hãy kiểm tra email, mật khẩu, trạng thái tài khoản và kết nối mạng.',
      ).message;
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
        : 'Bạn đã thử đăng nhập quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.';
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
          : 'Bạn đã thử quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.',
    );
  }

  Future<void> _recordServerLoginSuccess(String normalizedEmail) async {
    await _callServerLoginGuard(
      action: 'success',
      email: normalizedEmail,
    );
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
      final response = await _httpPost(
        Uri.parse(endpoint),
        headers: await AppCheckHttpHeaders.withRequiredToken(
          <String, String>{
            'Content-Type': 'application/json',
          },
          forceRefresh: false,
        ),
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
          await _cacheSecurityVerdictFromPayload(payload);
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
        debugPrint('authLoginGuardHttp failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể kiểm tra trạng thái đăng nhập lúc này.',
        ).message}');
      }
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'auth_login_guard_failed',
          reason: error is StateError ? 'missing_app_check' : 'request_failed',
          severity: 'medium',
          extra: <String, Object?>{
            'action': action,
          },
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
      'emailHash':
          sha256.convert(utf8.encode(email.trim().toLowerCase())).toString(),
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
      message: (payload['message'] as String?) ??
          'Thiết bị hoặc bản cài đặt này không đủ tin cậy để đăng nhập.',
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
      throw 'Chưa cấu hình APPLE_SIGN_IN_SERVICE_ID. '
          'Hãy thêm Service ID Apple dùng cho Sign in with Apple.';
    }

    final redirectUrl = AppConfig.appleSignInRedirectUrl.trim();
    final redirectUri = Uri.tryParse(redirectUrl);
    if (redirectUrl.isEmpty ||
        redirectUri == null ||
        !redirectUri.isAbsolute ||
        redirectUri.scheme.toLowerCase() != 'https' ||
        redirectUri.host.trim().isEmpty) {
      throw 'Chưa cấu hình APPLE_SIGN_IN_REDIRECT_URL hợp lệ. '
          'Giá trị này phải là một URL HTTPS tuyệt đối trên máy chủ của bạn.';
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
      throw 'Apple không trả về identity token hợp lệ. '
          'Hãy kiểm tra cấu hình Sign in with Apple trên Apple Developer và Firebase.';
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
      rawNonce: rawNonce,
    );
  }

  Future<firebase_auth.UserCredential?> signInWithApple() async {
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
          throw 'Thiết bị hoặc bản build này chưa hỗ trợ Sign in with Apple.';
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

        final oauthCredential =
            _buildAppleFirebaseCredential(appleCredential, rawNonce);
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
        throw 'Apple trả về phản hồi không hợp lệ (invalidResponse). '
            'Hãy kiểm tra Sign in with Apple capability, provisioning profile và Firebase Apple provider.';
      }

      if (_usesNativeAppleFlow) {
        throw 'Đăng nhập Apple thất bại (${error.code}). '
            'Hãy kiểm tra Apple ID trên máy, capability Sign in with Apple và provisioning profile của bản iOS này.';
      }

      throw 'Đăng nhập Apple thất bại (${error.code}). '
          'Hãy kiểm tra APPLE_SIGN_IN_SERVICE_ID, APPLE_SIGN_IN_REDIRECT_URL và callback server của Apple.';
    } on SignInWithAppleNotSupportedException {
      throw 'Thiết bị hoặc bản build này chưa hỗ trợ Sign in with Apple. '
          'Trên iPhone/iPad, hãy kiểm tra capability Sign in with Apple và provisioning profile hợp lệ.';
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
        case 'email-already-in-use':
        case 'credential-already-in-use':
          throw 'Email Apple này đã gắn với phương thức đăng nhập khác. '
              'Hãy đăng nhập bằng phương thức cũ trước.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return null;
        case 'popup-blocked':
          throw 'Popup đăng nhập Apple đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'operation-not-allowed':
          throw 'Firebase Authentication chưa bật hoặc chưa cấu hình đúng nhà cung cấp Apple. '
              'Vào Firebase Console > Authentication > Sign-in method > Apple để kiểm tra.';
        case 'network-request-failed':
          throw 'Mạng đang lỗi hoặc bị chặn, chưa thể đăng nhập Apple lúc này.';
        default:
          throw 'Đăng nhập Apple lỗi Firebase (${error.code}). '
              '${handleFirebaseAuthError(error)}';
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không đăng nhập Apple được: hãy kiểm tra Apple ID, quyền đăng nhập và kết nối mạng.',
      ).message;
    }
  }

  Future<firebase_auth.UserCredential?> signInWithGoogle() async {
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
          googleSignIn.initialize().then((_) {
            if (!initCompleter.isCompleted) initCompleter.complete();
          }).catchError((error) {
            if (!initCompleter.isCompleted) {
              initCompleter.completeError(error);
            } else {
              debugPrint('Late Google init error swallowed: $error');
            }
          });
          await initCompleter.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw 'Thời gian chờ Google quá lâu. Vui lòng thử lại.',
          );
          _isGoogleSignInInitialized = true;
        }

        // Sign out trước để xoá cache phiên cũ, tránh lỗi treo và sign_in_failed
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final authCompleter = Completer<dynamic>();
        googleSignIn.authenticate(
          scopeHint: const ['email'],
        ).then((user) {
          if (!authCompleter.isCompleted) authCompleter.complete(user);
        }).catchError((error) {
          if (!authCompleter.isCompleted) {
            authCompleter.completeError(error);
          } else {
            debugPrint('Late Google auth error swallowed: $error');
          }
        });

        final googleUser = await authCompleter.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw 'Bạn đã để màn hình đăng nhập Google quá lâu hoặc chưa hoàn tất thao tác. Vui lòng thử lại.',
        );
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw 'Google không trả về ID token hợp lệ. Vui lòng thử lại.';
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
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
      debugPrint(
        'Google FirebaseAuthException: ${error.code} ${error.message}',
      );
      throw handleFirebaseAuthError(error);
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
            ? 'Lỗi Google Sign-In (Code 10/ApiException): SHA-1/SHA-256 trên Firebase chưa khớp với chứng chỉ Play App Signing của ứng dụng trên CH Play. Vui lòng lấy mã SHA từ Play Console và thêm vào Firebase, sau đó tải lại file google-services.json.'
            : 'Google chưa cho phép đăng nhập trên bản app này. Hãy cập nhật app hoặc thử lại sau.';
      }
      if (isGoogleSignInNetworkIssue(error)) {
        throw 'Lỗi kết nối hoặc sự cố từ Google, chưa thể đăng nhập Google lúc này.';
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không đăng nhập Google được, vui lòng thử lại sau.',
      ).message;
    }
  }

  Future<firebase_auth.UserCredential?> signInWithFacebook() async {
    try {
      firebase_auth.UserCredential userCredential;

      if (kIsWeb) {
        final provider = firebase_auth.FacebookAuthProvider();
        provider.addScope('email');
        provider.addScope('public_profile');
        provider.setCustomParameters({
          'display': 'popup',
        });
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        try {
          await _facebookAuth.logOut();
        } catch (_) {}

        // Custom Tab login has been the unreliable path on some Android
        // emulators/devices for this app, so prefer the in-app dialog flow.
        final loginBehavior = defaultTargetPlatform == TargetPlatform.android
            ? LoginBehavior.dialogOnly
            : LoginBehavior.nativeWithFallback;
        final loginResult = await _facebookAuth.login(
          permissions: const ['public_profile'],
          loginBehavior: loginBehavior,
          loginTracking: LoginTracking.enabled,
        );
        debugPrint(
          'Facebook login result: behavior=$loginBehavior '
          'status=${loginResult.status} message=${loginResult.message}',
        );

        switch (loginResult.status) {
          case LoginStatus.success:
            final accessToken = loginResult.accessToken;
            if (accessToken == null) {
              throw 'Facebook không trả về access token hợp lệ.';
            }
            final credential = accessToken is LimitedToken
                ? firebase_auth.OAuthProvider('facebook.com').credential(
                    idToken: accessToken.tokenString,
                    rawNonce: accessToken.nonce,
                  )
                : firebase_auth.FacebookAuthProvider.credential(
                    accessToken.tokenString.trim(),
                  );
            userCredential = await _auth.signInWithCredential(credential);
            break;
          case LoginStatus.cancelled:
            return null;
          case LoginStatus.operationInProgress:
            throw 'Đăng nhập Facebook đang được xử lý. Vui lòng đợi một chút rồi thử lại.';
          case LoginStatus.failed:
            debugPrint(
              'Facebook login failed: status=${loginResult.status}, message=${loginResult.message}',
            );
            throw normalizeFacebookLoginFailureMessage(loginResult.message);
        }
      }

      await _enforceNoNewAccountOnWeb(userCredential);

      final resolvedEmail =
          userCredential.user?.email?.trim().toLowerCase() ?? '';
      final loginLimitKey = resolvedEmail.isNotEmpty
          ? resolvedEmail
          : 'facebook:${userCredential.user!.uid}';

      if (!await recordDailyLoginLimit(loginLimitKey)) {
        await signOut();
        throw dailyLoginLimitMessage;
      }
      await _finalizeAuthenticatedSession(
        userCredential.user!,
        fallbackEmail: resolvedEmail,
      );

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
        case 'email-already-in-use':
        case 'credential-already-in-use':
          throw 'Email Facebook này đã gắn với phương thức đăng nhập khác. Hãy đăng nhập bằng phương thức cũ trước.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return null;
        case 'operation-not-allowed':
          throw kDebugMode
              ? 'Firebase Authentication chưa bật nhà cung cấp Facebook. Hãy vào Firebase Console > Authentication > Sign-in method > Facebook và nhập đúng App ID/App Secret.'
              : 'Đăng nhập Facebook chưa sẵn sàng trên bản app này. Hãy thử cách đăng nhập khác.';
        case 'popup-blocked':
          throw 'Popup đăng nhập Facebook đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'network-request-failed':
          throw 'Mạng đang lỗi hoặc bị chặn, chưa thể đăng nhập Facebook lúc này.';
        default:
          throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (isFacebookSignInConfigMismatch(error) ||
          isFacebookSignInNetworkIssue(error)) {
        throw normalizeFacebookLoginFailureMessage(error.toString());
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không đăng nhập Facebook được: hãy kiểm tra tài khoản Facebook, quyền app và kết nối mạng.',
      ).message;
    }
  }

  Future<void> checkRollingRegisterLimit() async {
    final filtered = await _loadPrunedRollingRegisterTimestamps();

    if (filtered.length >= 10) {
      final oldestTs = int.parse(filtered.first);
      final now = _nowProvider().millisecondsSinceEpoch;
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      final leftMs = sevenDaysMs - (now - oldestTs);
      final leftDays = (leftMs / (24 * 60 * 60 * 1000)).ceil();
      throw 'Thiết bị này đã tạo quá nhiều tài khoản trong 7 ngày gần đây. '
          'Bạn chỉ có thể tạo tối đa 10 tài khoản mới trên cùng thiết bị trong 7 ngày. '
          'Hãy thử đăng nhập bằng tài khoản hiện có hoặc quay lại sau khoảng $leftDays ngày.';
    }
  }

  Future<void> recordRollingRegisterLimit() async {
    final prefs = await _prefs;
    final filtered = await _loadPrunedRollingRegisterTimestamps();
    filtered.add(_nowProvider().millisecondsSinceEpoch.toString());
    await prefs.setStringList('il_create_account_7d_v1', filtered);
  }

  Future<void> _enforceNoNewAccountOnWeb(
      firebase_auth.UserCredential credential) async {
    if (kIsWeb) {
      if (credential.additionalUserInfo?.isNewUser == true) {
        final user = credential.user;
        if (user != null) {
          try {
            await user.delete();
          } catch (_) {}
        }
        await signOut();
        throw 'Tính năng tạo tài khoản hiện không khả dụng trên nền tảng này. Vui lòng đăng nhập bằng tài khoản đã có.';
      }
    }
  }

  Future<firebase_auth.UserCredential?> registerWithEmailPassword(
    String email,
    String password,
  ) async {
    if (kIsWeb) {
      throw 'Tính năng tạo tài khoản hiện không khả dụng trên nền tảng này. Vui lòng đăng nhập bằng tài khoản đã có.';
    }

    await checkRollingRegisterLimit();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await recordRollingRegisterLimit();
      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không tạo được tài khoản: hãy kiểm tra email, mật khẩu, kết nối mạng hoặc email đã được dùng.',
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
      } catch (_) {}

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
              '${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể xóa tài khoản đăng ký dang dở.',
              ).message}',
            );
          } catch (error) {
            debugPrint(
              'rollbackIncompleteEmailSignup delete failed: '
              '${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể xóa tài khoản đăng ký dang dở.',
              ).message}',
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
        '_hasKnownHouseContext failed for $uid: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể kiểm tra ngữ cảnh nhà hiện tại.',
        ).message}',
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

  Future<void> signOut() async {
    final prefs = await _prefs;
    try {
      final houseId = await HouseService().getCurrentHouseId();
      final role = RoleUtils.currentRoleSync();
      if (houseId != null && houseId.isNotEmpty && role != null) {
        await PresenceService().goOffline(
          houseId: houseId,
          role: role,
        );
      }
    } catch (_) {}
    try {
      await NotificationService().clearTokenOnSignOut();
    } catch (_) {}
    try {
      if (!kIsWeb) {
        await _googleSignIn?.signOut();
      }
    } catch (_) {}
    try {
      await _facebookAuth.logOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } finally {
      try { await SettingsSyncService().clearLocalSyncedSettings(); } catch (_) {}
      try { await _clearSensitiveLocalData(prefs); } catch (_) {}
      try { await SecureStorageService.instance.deleteAll(); } catch (_) {}
      try { RoleUtils.roleNotifier.value = null; } catch (_) {}
      try { RoleUtils.duplicateRoleNotifier.value = false; } catch (_) {}
      // ⚡ Clear all offline cache to prevent data leakage to next user
      try { await OfflineCacheService.clearAllCache(); } catch (_) {}
      try { EncryptionService().clearCache(); } catch (_) {}
      try { PaintingBinding.instance.imageCache.clear(); } catch (_) {}
      try { PaintingBinding.instance.imageCache.clearLiveImages(); } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    if (kIsWeb) {
      throw 'Tính năng xóa tài khoản không được hỗ trợ trên phiên bản Web. Vui lòng sử dụng ứng dụng di động để thực hiện thao tác này.';
    }

    final deleteEndpoint = AppConfig.deleteAccountUrl.trim();
    if (deleteEndpoint.isEmpty) {
      throw 'Chưa cấu hình máy chủ xóa tài khoản.';
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn chưa đăng nhập. Không thể xóa tài khoản.';
    }

    if (kDebugMode) {
      debugPrint(
        'deleteAccount(): start uid=${user.uid} endpoint=$deleteEndpoint',
      );
    }

    try {
      final result = await _deleteAccountFromServer(user);
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
        final result = await _deleteAccountFromServer(user);
        if (kDebugMode) {
          debugPrint('deleteAccount(): success after reauth uid=${user.uid}');
        }
        return result;
      }
      throw handleFirebaseAuthError(error);
    } catch (error) {
      final normalized = error.toString().toLowerCase();
      if (normalized.contains('đăng nhập lại trước khi xóa tài khoản') ||
          normalized.contains('đăng nhập lại rồi thử xóa tài khoản') ||
          normalized.contains('phiên đăng nhập đã hết hạn') ||
          normalized.contains('phiên đăng nhập không còn hợp lệ')) {
        if (kDebugMode) {
          debugPrint(
            'deleteAccount(): retrying after session error: $error',
          );
        }
        await _reauthenticateCurrentUserWithLinkedProvider(user);
        final result = await _deleteAccountFromServer(user);
        if (kDebugMode) {
          debugPrint(
              'deleteAccount(): success after session retry uid=${user.uid}');
        }
        return result;
      }
      if (kDebugMode) {
        debugPrint('deleteAccount(): failed with error=${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể xóa tài khoản lúc này.',
        ).message}');
      }
      if (error is String) rethrow;
      final resolvedError = AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không thể xóa tài khoản lúc này: hãy kiểm tra mạng và đăng nhập lại nếu cần.',
      );
      throw resolvedError.message;
    }
  }

  Future<void> undoScheduledDeletion() async {
    final user = _auth.currentUser;
    if (user == null) throw 'Bạn chưa đăng nhập.';
    final idToken = await user.getIdToken(true) ?? '';
    final undoEndpoint = AppConfig.deleteAccountUrl
        .trim()
        .replaceAll('deleteUserDataHttp', 'undoAccountDeletionHttp');
    final response = await _httpPost(
      Uri.parse(undoEndpoint),
      headers: await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }),
    );
    if (response.statusCode != 200) {
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'undo_delete_failed',
          reason: 'server_rejected',
          severity: response.statusCode == 401 || response.statusCode == 403
              ? 'high'
              : 'medium',
          extra: <String, Object?>{
            'statusCode': response.statusCode,
          },
        ),
      );
      throw 'Không hoàn tác được: trạng thái tài khoản chưa khôi phục được, hãy kiểm tra mạng rồi thử lại.';
    }
  }

  Future<void> revokeOtherSessionsAfterPasswordChange() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn chưa đăng nhập.';
    }

    final idToken = await user.getIdToken(true) ?? '';
    if (idToken.isEmpty) {
      throw 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';
    }

    final endpoint = AppConfig.deleteAccountUrl.trim().replaceAll(
        'deleteUserDataHttp', 'revokeOtherSessionsAfterPasswordChangeHttp');
    final response = await _httpPost(
      Uri.parse(endpoint),
      headers: await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }),
      body: jsonEncode({
        'source': 'flutter_app',
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        unawaited(
          RevenueSecurityTelemetryService.instance.logEvent(
            type: 'revoke_other_sessions_failed',
            reason: 'unauthorized',
            severity: 'high',
            extra: <String, Object?>{
              'statusCode': response.statusCode,
            },
          ),
        );
        throw 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để áp dụng thay đổi bảo mật.';
      }
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'revoke_other_sessions_failed',
          reason: 'server_rejected',
          severity: 'medium',
          extra: <String, Object?>{
            'statusCode': response.statusCode,
          },
        ),
      );
      throw 'Không thể đăng xuất các thiết bị khác lúc này. Vui lòng thử lại sau ít phút.';
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
      try {
        await TiktokBusinessSdk().trackTTEvent(
          event: EventName.Registration,
        );
      } catch (e) {
        debugPrint('Failed to track TikTok registration: $e');
      }
    }

    await userRef.update(payload);
  }

  Future<void> _finalizeAuthenticatedSession(
    firebase_auth.User user, {
    String? fallbackEmail,
  }) async {
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
      SettingsSyncService().restoreSettingsFromCloud(user.uid),
    ]);

    final postLoginBlockReason = phase1Results[0] as String?;
    if (postLoginBlockReason != null) {
      await signOut();
      throw postLoginBlockReason;
    }

    final houseIdSnap = phase1Results[2] as DataSnapshot;
    final rawHouseId = houseIdSnap.value?.toString().trim();
    final houseId =
        (rawHouseId == null || rawHouseId.isEmpty) ? null : rawHouseId;

    final prefs = phase1Results[3] as SharedPreferences;

    String? existingRole;
    if (houseId != null && houseId.isNotEmpty) {
      await prefs.setString('il_house_id', houseId);
      await prefs.setString('il_auth_uid', user.uid);
      await SecureStorageService.instance
          .write(SecureStorageService.keyHouseId, houseId);
      await SecureStorageService.instance
          .write(SecureStorageService.keyAuthUid, user.uid);
      existingRole = prefs.getString('il_role');
    } else {
      await prefs.remove('il_house_id');
      await prefs.remove('il_auth_uid');
      await prefs.remove('il_role');
      await SecureStorageService.instance
          .delete(SecureStorageService.keyHouseId);
      await SecureStorageService.instance
          .delete(SecureStorageService.keyAuthUid);
      await SecureStorageService.instance.delete(SecureStorageService.keyRole);
    }

    await prefs.setString(
      'il_login_ts',
      _nowProvider().millisecondsSinceEpoch.toString(),
    );

    final shouldDetectRole = houseId != null &&
        houseId.isNotEmpty &&
        existingRole != 'user1' &&
        existingRole != 'user2';

    // Parallel Phase 2: Check ban status, sync relationship mode, fetch settings, sync security email, register device, detect auto role
    final phase2Results = await Future.wait([
      _houseContextService.checkBanStatus(
        houseId,
        onForcedSignOut: signOut,
      ),
      _houseContextService
          .syncRelationshipModeForCurrentUser(
        user: user,
        houseId: houseId,
      )
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
      if (resolvedEmail.contains('@'))
        _houseContextService
            .syncSecurityEmailForCurrentUser(
          user: user,
          email: resolvedEmail,
          houseId: houseId,
        )
            .catchError((error) {
          debugPrint('Failed to sync security email: $error');
        })
      else
        Future<void>.value(null),
      DeviceManagerService()
          .registerCurrentDevice()
          .timeout(const Duration(seconds: 4))
          .catchError((error) {
        debugPrint(
          'registerCurrentDevice skipped during auth finalize: '
          '${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể đăng ký thiết bị hiện tại lúc này.',
          ).message}',
        );
      }),
      if (shouldDetectRole)
        _houseContextService.detectAutoRole(houseId).catchError((error) {
          debugPrint('Failed to detect auto role: $error');
          return '';
        })
      else
        Future<String>.value(''),
    ]);

    final settingsSnap = phase2Results[2] as DataSnapshot?;
    if (settingsSnap != null && settingsSnap.exists) {
      try {
        final settings = settingsSnap.value is Map
            ? _asStringDynamicMap(settingsSnap.value)
            : null;
        if (settings != null) {
          final customBackgroundUrl = (settings['customBackgroundUrl'] ??
                  settings['customHomeBackground'] ??
                  '')
              .toString();
          if (customBackgroundUrl.isNotEmpty) {
            await UiPrefs.ensureLoaded();
            await UiPrefs.saveState(
              UiPrefs.notifier.value.copyWith(
                customBackgroundUrl: customBackgroundUrl,
              ),
            );
          }
        }
      } catch (error) {
        debugPrint('Failed to sync UI preferences: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể đồng bộ cài đặt giao diện lúc này.',
        ).message}');
      }
    }

    if (shouldDetectRole) {
      final role = phase2Results[5] as String;
      if (role == 'user1' || role == 'user2') {
        await prefs.setString('il_role', role);
      }
    }

    unawaited(
      CriticalDataSyncService()
          .syncCurrentUserData(
        houseId: houseId,
        force: true,
      )
          .catchError((error) {
        debugPrint(
          'CriticalDataSync skipped during auth finalize: '
          '${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể đồng bộ dữ liệu quan trọng lúc này.',
          ).message}',
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
      debugPrint('_getDailyLoginTracker failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể đọc bộ đếm đăng nhập hôm nay.',
      ).message}');
      try {
        final prefs = await _prefs;
        await prefs.remove(_dailyLoginTrackerPrefsKey);
      } catch (_) {}
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
    firebase_auth.User user,
  ) async {
    final endpoint = AppConfig.deleteAccountUrl.trim();
    if (endpoint.isEmpty) {
      throw 'Chưa cấu hình máy chủ xóa tài khoản.';
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
        throw 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại rồi thử xóa tài khoản.';
      }

      final deviceId = await _houseContextService.getDeviceId();
      if (kDebugMode) {
        debugPrint(
          '_deleteAccountFromServer(): endpoint=$endpoint deviceId=$deviceId',
        );
      }
      final response = await _httpPost(
        Uri.parse(endpoint),
        headers: await AppCheckHttpHeaders.withOptionalToken({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        }),
        body: jsonEncode({
          'source': 'flutter_app',
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 20));

      if (kDebugMode) {
        debugPrint(
          '_deleteAccountFromServer(): status=${response.statusCode} '
          'body=${response.body}',
        );
      }

      if (response.statusCode != 200) {
        if (response.statusCode == 409) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map &&
                decoded['error'] == 'deletion_already_scheduled') {
              final scheduledAt = decoded['scheduledAt'];
              final delayDays = scheduledAt is num
                  ? DateTime.fromMillisecondsSinceEpoch(scheduledAt.toInt())
                      .difference(DateTime.now())
                      .inDays
                      .clamp(0, 30)
                  : 3;
              return <String, dynamic>{
                'ok': true,
                'scheduledAt': scheduledAt,
                'status': decoded['status'] ?? 'scheduled',
                'delayDays': delayDays,
              };
            }
          } catch (_) {}
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          unawaited(
            RevenueSecurityTelemetryService.instance.logEvent(
              type: 'delete_account_failed',
              reason: 'unauthorized',
              severity: 'high',
              extra: <String, Object?>{
                'statusCode': response.statusCode,
              },
            ),
          );
          throw 'Phiên đăng nhập đã hết hạn hoặc không còn hợp lệ. Vui lòng đăng nhập lại trước khi xóa tài khoản.';
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
            extra: <String, Object?>{
              'statusCode': response.statusCode,
            },
          ),
        );
        throw 'Máy chủ chưa thể xóa hết dữ liệu tài khoản lúc này. Vui lòng thử lại sau ít phút.';
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        throw 'Máy chủ trả về phản hồi xóa tài khoản không hợp lệ.';
      }
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw 'Máy chủ xóa tài khoản phản hồi quá chậm. Vui lòng thử lại khi mạng ổn định hơn.';
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Delete account endpoint error: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể gọi máy chủ xóa tài khoản lúc này.',
        ).message}');
      }
      if (error is String) rethrow;
      throw 'Không hoàn tất xóa tài khoản: hãy kiểm tra mạng và đăng nhập lại nếu cần.';
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
      await prefs.remove(key);
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
  const _ServerLoginGuardRecord({
    this.allowed = true,
    this.message = '',
  });

  final bool allowed;
  final String message;
}

class _LoginEmailResolution {
  const _LoginEmailResolution({
    required this.email,
    required this.source,
  });

  final String email;
  final String source;
}
