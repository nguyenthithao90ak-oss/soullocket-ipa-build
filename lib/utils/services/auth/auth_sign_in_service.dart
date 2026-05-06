import 'dart:async';
import 'dart:convert';

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

import '../../core/constants/app_config.dart';
import '../../utils/app_error_mapper.dart';
import '../../views/ui_prefs.dart';
import '../critical_data_sync_service.dart';
import '../device_manager_service.dart';
import '../encryption_service.dart';
import '../offline_cache_service.dart';
import '../app_check_http_headers.dart';
import '../revenue_security_telemetry_service.dart';
import '../settings_sync_service.dart';
import '../security_verdict_cache_service.dart';
import 'play_integrity_service.dart';
import 'auth_admin_service.dart';
import 'auth_house_context_service.dart';
import 'auth_support.dart';

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
            googleSignInBuilder ?? (() => GoogleSignIn(scopes: ['email'])),
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
    } catch (error, stackTrace) {
      debugPrint('checkDailyLoginLimit failed: $error\n$stackTrace');
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
    } catch (error, stackTrace) {
      debugPrint('recordDailyLoginLimit failed: $error\n$stackTrace');
      return true;
    }
  }

  Future<bool> _isProviderLinkedCurrentUser(String providerId) async {
    var user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
      user = _auth.currentUser ?? user;
    } catch (_) {}

    final providerData = user?.providerData ?? <firebase_auth.UserInfo>[];
    return providerData.any((provider) => provider.providerId == providerId);
  }

  Future<bool> isGoogleLinkedCurrentUser() {
    return _isProviderLinkedCurrentUser('google.com');
  }

  Future<bool> isAppleLinkedCurrentUser() {
    return _isProviderLinkedCurrentUser('apple.com');
  }

  Future<bool> isPasswordLinkedCurrentUser() {
    return _isProviderLinkedCurrentUser('password');
  }

  Future<void> linkGoogleToCurrentUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn cần đăng nhập trước khi liên kết Google.';
    }

    if (await isGoogleLinkedCurrentUser()) {
      return;
    }

    final provider = firebase_auth.GoogleAuthProvider()..addScope('email');
    provider.setCustomParameters({'prompt': 'select_account'});

    try {
      if (kIsWeb) {
        await user.linkWithPopup(provider);
      } else {
        final googleSignIn = _googleSignIn ??= _googleSignInBuilder();
        await googleSignIn.signOut();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw 'Bạn đã hủy chọn tài khoản Google.';
        }

        final googleAuth = await googleUser.authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw 'Google không trả về ID token hợp lệ. Hãy kiểm tra kết nối mạng và thử lại.';
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.linkWithCredential(credential);
      }

      await user.reload();
      user = _auth.currentUser ?? user;
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'provider-already-linked':
          return;
        case 'credential-already-in-use':
        case 'email-already-in-use':
        case 'account-exists-with-different-credential':
          throw 'Email Google này đã liên kết với tài khoản khác.';
        case 'requires-recent-login':
          throw 'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại trước khi liên kết Google.';
        case 'popup-closed-by-user':
          throw 'Bạn đã đóng cửa sổ đăng nhập Google.';
        case 'popup-blocked':
        case 'cancelled-popup-request':
          throw 'Popup Google đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'network-request-failed':
          throw 'Mạng đang lỗi hoặc bị chặn, chưa thể liên kết Google lúc này.';
        default:
          throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      final raw = error.toString();
      if (raw.contains('10') ||
          raw.contains('sign_in_failed') ||
          raw.contains('ApiException')) {
        throw 'Đăng nhập Google gặp sự cố ở bước xác thực tài khoản. Hãy kiểm tra tài khoản Google và kết nối mạng.';
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không liên kết Google được: hãy kiểm tra tài khoản Google, trạng thái đăng nhập và kết nối mạng.',
      ).message;
    }
  }

  Future<void> linkAppleToCurrentUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn cần đăng nhập trước khi liên kết Apple.';
    }

    if (await isAppleLinkedCurrentUser()) {
      return;
    }

    try {
      if (kIsWeb) {
        final provider = firebase_auth.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        await user.linkWithPopup(provider);
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
        await user.linkWithCredential(oauthCredential);
      }

      await user.reload();
      user = _auth.currentUser ?? user;
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'provider-already-linked':
          return;
        case 'credential-already-in-use':
        case 'email-already-in-use':
        case 'account-exists-with-different-credential':
          throw 'Email Apple này đã liên kết với tài khoản khác.';
        case 'requires-recent-login':
          throw 'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại trước khi liên kết Apple.';
        case 'popup-closed-by-user':
          return;
        case 'popup-blocked':
          throw 'Popup liên kết Apple đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'operation-not-allowed':
          throw kDebugMode
              ? 'Firebase Authentication chưa bật nhà cung cấp Apple.'
              : 'Liên kết Apple chưa sẵn sàng trên bản app này.';
        case 'network-request-failed':
          throw 'Mạng đang lỗi hoặc bị chặn, chưa thể liên kết Apple lúc này.';
        default:
          throw handleFirebaseAuthError(error);
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return;
      }
      throw kDebugMode
          ? 'Apple trả về lỗi xác thực (${error.code}). Hãy kiểm tra cấu hình Apple Sign In.'
          : 'Liên kết Apple chưa hoàn tất được. Hãy thử lại sau.';
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không liên kết Apple được: hãy kiểm tra Apple ID, quyền đăng nhập và kết nối mạng.',
      ).message;
    }
  }

  Future<void> createPasswordForCurrentUser(String newPassword) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn cần đăng nhập trước khi tạo mật khẩu.';
    }

    final email = user.email?.trim() ?? '';
    final normalizedPassword = newPassword.trim();
    if (email.isEmpty) {
      throw 'Tài khoản hiện tại chưa có email nên chưa thể tạo mật khẩu đăng nhập.';
    }
    if (normalizedPassword.length < 6) {
      throw 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    if (await isPasswordLinkedCurrentUser()) {
      throw 'Tài khoản này đã có mật khẩu đăng nhập. Hãy dùng phần đổi mật khẩu.';
    }

    Future<void> linkPasswordCredential() async {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: normalizedPassword,
      );
      await user!.linkWithCredential(credential);
    }

    try {
      await linkPasswordCredential();
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        await _reauthenticateCurrentUserWithLinkedProvider(user);
        user = _auth.currentUser ?? user;
        await linkPasswordCredential();
      } else if (error.code == 'provider-already-linked') {
        await user.reload();
      } else if (error.code == 'email-already-in-use' ||
          error.code == 'credential-already-in-use' ||
          error.code == 'account-exists-with-different-credential') {
        throw 'Email này đã gắn với một tài khoản khác nên chưa thể tạo mật khẩu ở đây.';
      } else {
        throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không tạo được mật khẩu đăng nhập: hãy kiểm tra mật khẩu mới, trạng thái đăng nhập và kết nối mạng.',
      ).message;
    }

    await user.reload();
    user = _auth.currentUser ?? user;
    try {
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } catch (_) {}
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

  Future<void> _reauthenticateCurrentUserWithLinkedProvider(
    firebase_auth.User user,
  ) async {
    final providerIds =
        user.providerData.map((provider) => provider.providerId).toSet();
    if (providerIds.contains('google.com')) {
      await _reauthenticateCurrentUserWithGoogle(user);
      return;
    }
    if (providerIds.contains('facebook.com')) {
      await _reauthenticateCurrentUserWithFacebook(user);
      return;
    }
    throw 'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại bằng Google hoặc Facebook trước khi tạo mật khẩu.';
  }

  Future<void> _reauthenticateCurrentUserWithGoogle(
    firebase_auth.User user,
  ) async {
    try {
      if (kIsWeb) {
        final provider = firebase_auth.GoogleAuthProvider()..addScope('email');
        provider.setCustomParameters({'prompt': 'select_account'});
        await user.reauthenticateWithPopup(provider);
        return;
      }

      final googleSignIn = _googleSignIn ??= _googleSignInBuilder();
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Bạn đã hủy xác minh lại Google.';
      }

      final googleAuth = await googleUser.authentication;
      if ((googleAuth.idToken ?? '').isEmpty) {
        throw 'Google không trả về ID token hợp lệ để xác minh lại tài khoản.';
      }

      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'user-mismatch':
          throw 'Bạn cần chọn đúng tài khoản Google đã dùng để đăng nhập trước đó.';
        case 'popup-closed-by-user':
          throw 'Bạn đã đóng cửa sổ xác minh lại Google.';
        case 'popup-blocked':
        case 'cancelled-popup-request':
          throw 'Popup Google đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'network-request-failed':
          throw 'Mạng đang lỗi hoặc bị chặn, chưa thể xác minh lại Google lúc này.';
        default:
          throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không xác minh lại Google được: hãy chọn đúng tài khoản Google đang liên kết và kiểm tra mạng.',
      ).message;
    }
  }

  Future<void> _reauthenticateCurrentUserWithFacebook(
    firebase_auth.User user,
  ) async {
    try {
      if (kIsWeb) {
        final provider = firebase_auth.FacebookAuthProvider();
        provider.addScope('email');
        provider.addScope('public_profile');
        provider.setCustomParameters({'display': 'popup'});
        await user.reauthenticateWithPopup(provider);
        return;
      }

      try {
        await _facebookAuth.logOut();
      } catch (_) {}

      final loginBehavior = defaultTargetPlatform == TargetPlatform.android
          ? LoginBehavior.dialogOnly
          : LoginBehavior.nativeWithFallback;
      final loginResult = await _facebookAuth.login(
        permissions: const ['email', 'public_profile'],
        loginBehavior: loginBehavior,
        loginTracking: LoginTracking.enabled,
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
          await user.reauthenticateWithCredential(credential);
          return;
        case LoginStatus.cancelled:
          throw 'Bạn đã hủy xác minh lại Facebook.';
        case LoginStatus.operationInProgress:
          throw 'Facebook đang xử lý đăng nhập. Vui lòng đợi một chút rồi thử lại.';
        case LoginStatus.failed:
          throw normalizeFacebookLoginFailureMessage(loginResult.message);
      }
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'user-mismatch') {
        throw 'Bạn cần chọn đúng tài khoản Facebook đã dùng để đăng nhập trước đó.';
      }
      if (error.code == 'network-request-failed') {
        throw 'Mạng đang lỗi hoặc bị chặn, chưa thể xác minh lại Facebook lúc này.';
      }
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không xác minh lại Facebook được: hãy chọn đúng tài khoản Facebook đang liên kết và kiểm tra mạng.',
      ).message;
    }
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
        await SettingsSyncService().restoreSettingsFromCloud(
          userCredential.user!.uid,
        );
        await _recordServerLoginSuccess(normalizedEmail);
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
        debugPrint('authLoginGuardHttp failed: $error');
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
      'emailHash': sha256.convert(utf8.encode(email.trim().toLowerCase())).toString(),
      'action': action.trim().toLowerCase(),
      if (reason.trim().isNotEmpty) 'reason': reason.trim().toLowerCase(),
    };
    return _playIntegrityService.buildIntegrityPayload(
      flow: 'auth_login_guard_${action.trim().toLowerCase()}',
      payload: payload,
      autoWarmUp: true,
    );
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
        await SettingsSyncService().restoreSettingsFromCloud(
          userCredential.user!.uid,
        );
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
        throw kDebugMode
            ? 'Apple trả về phản hồi không hợp lệ. Hãy kiểm tra Sign in with Apple capability, provisioning profile và cấu hình Apple trên Firebase.'
            : 'Đăng nhập Apple chưa sẵn sàng trên thiết bị này. Hãy thử lại sau.';
      }

      if (_usesNativeAppleFlow) {
        throw kDebugMode
            ? 'Đăng nhập Apple thất bại. Hãy kiểm tra capability "Sign in with Apple" trong Xcode/Apple Developer và thử lại.'
            : 'Đăng nhập Apple chưa dùng được trên bản app này. Hãy thử lại sau.';
      }

      throw kDebugMode
          ? 'Đăng nhập Apple trả về lỗi xác thực. Hãy kiểm tra APPLE_SIGN_IN_SERVICE_ID, APPLE_SIGN_IN_REDIRECT_URL và callback server của Apple.'
          : 'Đăng nhập Apple chưa hoàn tất được. Hãy thử lại sau.';
    } on SignInWithAppleNotSupportedException {
      throw kDebugMode
          ? 'Thiết bị hoặc bản build này chưa hỗ trợ Sign in with Apple. Trên iPhone/iPad, hãy bật capability "Sign in with Apple" và dùng provisioning profile hợp lệ.'
          : 'Thiết bị hoặc bản app này chưa hỗ trợ đăng nhập Apple.';
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
          throw kDebugMode
              ? 'Firebase Authentication chưa bật nhà cung cấp Apple. Hãy vào Firebase Console > Authentication > Sign-in method > Apple và hoàn tất cấu hình Apple Developer.'
              : 'Đăng nhập Apple chưa sẵn sàng trên bản app này. Hãy thử cách đăng nhập khác.';
        case 'network-request-failed':
          throw 'Mạng đang lỗi hoặc bị chặn, chưa thể đăng nhập Apple lúc này.';
        default:
          throw handleFirebaseAuthError(error);
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
        await googleSignIn.signOut();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          return null;
        }

        final refreshedGoogleUser = await googleSignIn.signInSilently(
          reAuthenticate: true,
        );
        final googleAuth =
            await (refreshedGoogleUser ?? googleUser).authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw 'Google không trả về ID token hợp lệ. Hãy kiểm tra cấu hình Firebase Google Sign-In.';
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      await _enforceNoNewAccountOnWeb(userCredential);

      if (userCredential.user != null) {
        await SettingsSyncService().restoreSettingsFromCloud(
          userCredential.user!.uid,
        );
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
      if (isGoogleSignInConfigMismatch(error)) {
        throw kDebugMode
            ? 'Lỗi Google Sign-In (Code 10/ApiException): SHA-1/SHA-256 trên Firebase chưa khớp với chứng chỉ Play App Signing của ứng dụng trên CH Play. Vui lòng lấy mã SHA từ Play Console và thêm vào Firebase, sau đó tải lại file google-services.json.'
            : 'Google chưa cho phép đăng nhập trên bản app này. Hãy cập nhật app hoặc thử lại sau.';
      }
      if (isGoogleSignInNetworkIssue(error)) {
        throw 'Mạng đang lỗi hoặc bị chặn, chưa thể đăng nhập Google lúc này.';
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không đăng nhập Google được: hãy kiểm tra tài khoản Google và kết nối mạng.',
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

      await SettingsSyncService().restoreSettingsFromCloud(
        userCredential.user!.uid,
      );
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
          } on firebase_auth.FirebaseAuthException catch (error, stackTrace) {
            debugPrint(
              'rollbackIncompleteEmailSignup delete failed: '
              '${error.code}\n$stackTrace',
            );
          } catch (error, stackTrace) {
            debugPrint(
              'rollbackIncompleteEmailSignup delete failed: '
              '$error\n$stackTrace',
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
    } catch (error, stackTrace) {
      debugPrint(
        '_hasKnownHouseContext failed for $uid: $error\n$stackTrace',
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
      await SettingsSyncService().clearLocalSyncedSettings();
      await _clearSensitiveLocalData(prefs);
      // ⚡ Clear all offline cache to prevent data leakage to next user
      await OfflineCacheService.clearAllCache();
      EncryptionService().clearCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
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

    try {
      return await _deleteAccountFromServer(user);
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw 'Vì lý do bảo mật, vui lòng đăng nhập lại trước khi xóa tài khoản.';
      }
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (error is String) rethrow;
      throw 'Không thể xóa tài khoản lúc này: $error';
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
      headers: await AppCheckHttpHeaders.withRequiredToken({
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
    final resolvedEmail = (user.email ?? fallbackEmail ?? '').trim();
    if (resolvedEmail.isNotEmpty) {
      final postLoginBlockReason = await _adminService.getSystemBlockReason(
        resolvedEmail,
        allowAdminBypass: true,
        forceRefreshAdmin: true,
      );
      if (postLoginBlockReason != null) {
        await signOut();
        throw postLoginBlockReason;
      }
    }

    await _ensureUserProfileExists(user);

    final userSnap = await _db.child('users/${user.uid}/houseId').get();
    final rawHouseId = userSnap.value?.toString().trim();
    final houseId =
        (rawHouseId == null || rawHouseId.isEmpty) ? null : rawHouseId;

    await _houseContextService.checkBanStatus(
      houseId,
      onForcedSignOut: signOut,
    );

    final prefs = await _prefs;
    if (houseId != null && houseId.isNotEmpty) {
      final role = await _houseContextService.detectAutoRole(houseId);
      await prefs.setString('il_house_id', houseId);
      await prefs.setString('il_auth_uid', user.uid);
      await prefs.setString('il_role', role);
    } else {
      await prefs.remove('il_house_id');
      await prefs.remove('il_auth_uid');
      await prefs.remove('il_role');
    }

    await prefs.setString(
      'il_login_ts',
      _nowProvider().millisecondsSinceEpoch.toString(),
    );
    await _houseContextService.syncRelationshipModeForCurrentUser(
      user: user,
      houseId: houseId,
    );

    if (houseId != null && houseId.isNotEmpty) {
      try {
        final settingsSnap = await _db.child('houses/$houseId/settings').get();
        if (settingsSnap.exists) {
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
        }
      } catch (error) {
        debugPrint('Failed to sync UI preferences: $error');
      }
    }

    if (resolvedEmail.contains('@')) {
      try {
        await _houseContextService.syncSecurityEmailForCurrentUser(
          user: user,
          email: resolvedEmail,
          houseId: houseId,
        );
      } catch (_) {}
    }
    try {
      await DeviceManagerService()
          .registerCurrentDevice()
          .timeout(const Duration(seconds: 4));
    } catch (error, stackTrace) {
      debugPrint(
        'registerCurrentDevice skipped during auth finalize: '
        '$error\n$stackTrace',
      );
    }

    if (houseId != null && houseId.isNotEmpty) {
      final isBlocked = await DeviceManagerService().isCurrentDeviceBlocked();
      if (isBlocked) {
        await signOut();
        throw 'Thiết bị này đã bị chặn truy cập vĩnh viễn.';
      }
    }

    unawaited(
      CriticalDataSyncService().syncCurrentUserData(
        houseId: houseId,
        force: true,
      ),
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
    } catch (error, stackTrace) {
      debugPrint('_getDailyLoginTracker failed: $error\n$stackTrace');
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
      if (idToken.isEmpty) {
        throw 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại rồi thử xóa tài khoản.';
      }

      final response = await _httpPost(
        Uri.parse(endpoint),
        headers: await AppCheckHttpHeaders.withRequiredToken({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        }, forceRefresh: true),
        body: jsonEncode({
          'source': 'flutter_app',
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
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
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Delete account endpoint error: $error');
        debugPrintStack(stackTrace: stackTrace);
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
