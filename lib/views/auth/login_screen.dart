import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'login/auth_page_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../utils/services/anti_spam_service.dart';
import '../../core/sl_route.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/security_flow_guard.dart';
import '../../utils/services/security_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/secure_storage_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/flexible_date_input.dart';
import '../../utils/rapid_action_feedback_policy.dart';
import '../../utils/sl_notice.dart';
import '../../widgets/sensitive_content_guard.dart';

import 'dialogs/auth_feedback_dialogs.dart';
import 'dialogs/forgot_gmail_recovery_helper.dart';
import 'dialogs/math_captcha_dialog.dart';
import 'dialogs/support_dialog.dart';
import 'login/auth_panel_shell.dart';
import 'login/forgot_password_launcher.dart';
import 'login/login_shell.dart';
import 'login/social_auth_action_helper.dart';
import 'register/register_shell.dart';
import 'widgets/gender_selection_dialog.dart';
import 'widgets/relationship_mode_dialog.dart';
import '../home/screens/document_viewer_screen.dart';
import '../app_entry.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authService,
    this.houseService,
    this.securityService,
  });

  final AuthService? authService;
  final HouseService? houseService;
  final SecurityService? securityService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Cho người dùng sửa vài lần gõ nhầm trước khi yêu cầu CAPTCHA.
  // Firebase Auth và authLoginGuardHttp vẫn chịu trách nhiệm chống thử mật khẩu tự động.
  static const int _captchaAfterFailedAttempts = 4;
  static const int _authRateLimitMaxCalls = 5;
  static const int _authRateLimitWindowMs = 10000;

  static const String _pendingSignupRecoveryQuestionPrefsKey =
      'il_pending_signup_recovery_question';
  static const String _pendingSignupRecoveryAnswerPrefsKey =
      'il_pending_signup_recovery_answer';
  static const String _pendingSignupAutoCreateHousePrefsKey =
      'il_pending_signup_auto_create_house';
  static const String _pendingSignupEmailPrefsKey = 'il_pending_signup_email';

  static final int _copyrightYear = DateTime.now().year;

  SharedPreferences? _prefs;

  bool _isLoginTab = true;
  bool _obscurePassword = false;
  bool _isLoading = false;
  bool _authActionInProgress = false;
  bool _isSuccessTransition = false;
  bool _rememberMe = true;
  bool _acceptTerms = false;
  bool _showSecurityQuestion = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();

  int _failedAuthAttempts = 0;

  late final AuthService _authService = widget.authService ?? AuthService();
  late final HouseService _houseService = widget.houseService ?? HouseService();
  late final SecurityService _securityService =
      widget.securityService ?? SecurityService();
  final AntiSpamRateLimitService _authRateLimiter = AntiSpamRateLimitService();
  late final SecurityFlowGuard _securityFlowGuard = SecurityFlowGuard.instance;

  String _selectedSecurityQuestion = L10nService().translate(
    'Ngày sinh của bạn?',
  );

  List<String> get _cleanSecurityQuestions => const [
    'Ngày sinh của bạn?',
    'Con vật đầu tiên bạn nuôi?',
    'Tên giáo viên chủ nhiệm lớp 1?',
    'Nơi lần đầu tiên hai bạn gặp nhau?',
    'Món ăn yêu thích nhất của bạn?',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSecurityQuestion = _cleanSecurityQuestions.first;
    unawaited(_initPrefs().then((_) => _loadRememberedEmail()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKickReason();
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _checkKickReason() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final reason = prefs.getString('il_kick_reason');
    if (reason == null || reason.isEmpty || !mounted) return;

    await prefs.remove('il_kick_reason');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: Text(L10nService().translate('⚠️ Đã đăng xuất')),
        content: Text(L10nService().translate(reason)),
        actions: [
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L10nService().translate('Đóng')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRememberedEmail() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final savedEmail = prefs.getString('il_remembered_email');
    if (savedEmail == null || savedEmail.isEmpty || !mounted) return;

    setState(() {
      _emailController.text = savedEmail;
      _rememberMe = true;
    });
  }

  void _rememberProxyStateAtLogin() {
    unawaited(
      _securityService.isProxyOrVpnActive().then(
        _securityService.setProxyAtLogin,
        onError: (_) {},
      ),
    );
  }

  Future<String?> _ensureRelationshipModeSelected(String accountKey) async {
    final normalizedAccountKey = accountKey.trim().toLowerCase();
    if (normalizedAccountKey.isEmpty) {
      return null;
    }

    final cachedMode = await _authService.getCachedRelationshipModeForEmail(
      normalizedAccountKey,
    );
    if (cachedMode != null) {
      return cachedMode;
    }

    try {
      final existingHouseId = await _houseService.getCurrentHouseId(
        preferFresh: false,
      );
      if (existingHouseId != null && existingHouseId.isNotEmpty) {
        const defaultMode = 'couple';
        await _authService.cacheRelationshipModeForEmail(
          normalizedAccountKey,
          defaultMode,
        );
        return defaultMode;
      }
    } catch (error) {
      debugPrint('[LoginScreen] Cannot load relationship mode: $error');
    }

    if (!mounted) return null;

    final relationshipMode = _authService.normalizeRelationshipMode(
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => RelationshipModeDialog(
          onSelected: (value) {
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop(value);
            }
          },
        ),
      ),
    );

    if (relationshipMode != null) {
      await _authService.cacheRelationshipModeForEmail(
        normalizedAccountKey,
        relationshipMode,
      );
    }
    return relationshipMode;
  }

  Future<bool> _checkAuthRateLimit() async {
    // Không dùng bộ đếm chống spam dùng chung của Chat cho đăng nhập.
    // Login đã có tap-throttle riêng, authLoginGuardHttp và Firebase Auth.
    if (_isLoginTab) return true;

    final allowed = await _authRateLimiter.checkRateLimit(
      action: 'auth_register',
      maxCalls: _authRateLimitMaxCalls,
      timeWindowMs: _authRateLimitWindowMs,
    );
    if (allowed) return true;

    final cooldown = await _authRateLimiter.remainingCooldownSeconds;
    if (!mounted) return false;

    if (shouldShowRapidActionWarningSeconds(cooldown)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('chat_friendly_19')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  Future<String?> _readSavedGender([String? accountKey]) async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    if (accountKey != null && accountKey.trim().isNotEmpty) {
      final normalizedAccountKey = accountKey.trim().toLowerCase();
      final savedPerAccount = prefs
          .getString('il_saved_gender_$normalizedAccountKey')
          ?.trim();
      if (savedPerAccount == 'user1' || savedPerAccount == 'user2') {
        return savedPerAccount;
      }

      // Không dùng `il_role` chung cho email đang đăng nhập. Khóa này chỉ là
      // bản sao tạm của phiên trước; dùng nó ở đây sẽ mang role của tài khoản
      // A sang tài khoản B khi người dùng đổi tài khoản trên cùng thiết bị.
      return null;
    }

    final generalRole = prefs.getString('il_role')?.trim();
    if (generalRole == 'user1' || generalRole == 'user2') {
      return generalRole;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final houseId = await _houseService.getCurrentHouseId(
          preferFresh: false,
        );
        if (houseId != null && houseId.isNotEmpty) {
          final snap = await FirebaseDatabase.instance
              .ref('houses/$houseId/members/${user.uid}/role')
              .get()
              .timeout(const Duration(seconds: 2));
          final roleInDb = snap.value?.toString().trim();
          if (roleInDb == 'user1' || roleInDb == 'user2') {
            if (accountKey != null && accountKey.isNotEmpty) {
              final normalizedAccountKey = accountKey.trim().toLowerCase();
              await prefs.setString(
                'il_saved_gender_$normalizedAccountKey',
                roleInDb!,
              );
            }
            return roleInDb;
          }
          return 'user1';
        }
      } catch (error) {
        debugPrint('[LoginScreen] Cannot infer the current user role: $error');
      }
    }
    return null;
  }

  Future<void> _clearTransientRoleIfSignedOut() async {
    // Khi Auth đã có phiên thì role có thể là dữ liệu vừa được server xác nhận;
    // chỉ dọn bản sao tạm trong màn Login lúc Firebase chưa tạo phiên.
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove('il_role');
      await SecureStorageService.instance.delete(SecureStorageService.keyRole);
    } catch (error) {
      debugPrint('[LoginScreen] Cannot clear transient role: $error');
    }
  }

  Future<String?> _askGender([String? accountKey]) async {
    final savedGender = await _readSavedGender(accountKey);
    if (savedGender != null) {
      return savedGender;
    }
    if (!mounted) return null;

    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    if (!mounted) return null;
    final role = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => GenderSelectionDialog(
        onSelected: (value) {
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(value);
          }
        },
      ),
    );

    if (role != null) {
      await prefs.setString('il_saved_gender', role);
      if (accountKey != null && accountKey.isNotEmpty) {
        final normalizedAccountKey = accountKey.trim().toLowerCase();
        await prefs.setString('il_saved_gender_$normalizedAccountKey', role);
      }
    }
    return role;
  }

  Future<void> _persistPendingHouseSetupDraft({
    required String email,
    required String? role,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;

    if (role == 'user1' || role == 'user2') {
      await prefs.setString('il_role', role!);
      await SecureStorageService.instance.write(
        SecureStorageService.keyRole,
        role,
      );
    }

    final shouldSaveRecovery =
        _showSecurityQuestion &&
        _selectedSecurityQuestion.trim().isNotEmpty &&
        _securityAnswerController.text.trim().isNotEmpty;

    if (!shouldSaveRecovery) {
      await prefs.remove(_pendingSignupRecoveryQuestionPrefsKey);
      await prefs.remove(_pendingSignupRecoveryAnswerPrefsKey);
    } else {
      final normalizedAnswer =
          DateInputUtils.looksLikeBirthQuestion(_selectedSecurityQuestion)
          ? DateInputUtils.canonicalRecoveryAnswer(
              _securityAnswerController.text,
            )
          : _securityAnswerController.text.trim();
      await prefs.setString(
        _pendingSignupRecoveryQuestionPrefsKey,
        _selectedSecurityQuestion.trim(),
      );
      await prefs.setString(
        _pendingSignupRecoveryAnswerPrefsKey,
        normalizedAnswer,
      );
    }

    await prefs.setString(_pendingSignupEmailPrefsKey, email);
    await prefs.setBool(_pendingSignupAutoCreateHousePrefsKey, true);
  }

  Future<void> _clearPendingHouseSetupDraft() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    await prefs.remove(_pendingSignupRecoveryQuestionPrefsKey);
    await prefs.remove(_pendingSignupRecoveryAnswerPrefsKey);
    await prefs.remove(_pendingSignupAutoCreateHousePrefsKey);
    await prefs.remove(_pendingSignupEmailPrefsKey);
  }

  void _setAuthTab(bool isLoginTab) {
    if (_isLoginTab == isLoginTab) return;
    setState(() {
      _isLoginTab = isLoginTab;
    });
  }

  Future<void> _handleAuthAction() async {
    if (_authActionInProgress || _isLoading || _isSuccessTransition) return;
    _authActionInProgress = true;
    setState(() => _isLoading = true);
    try {
      await _performAuthAction();
    } catch (error) {
      if (!mounted) return;
      _showErrorDialog(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: L10nService().translate(
            _isLoginTab ? 'auth_login_unavailable' : 'auth_signup_unavailable',
          ),
        ).message,
      );
    } finally {
      _authActionInProgress = false;
      if (mounted && !_isSuccessTransition) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performAuthAction() async {
    FocusScope.of(context).unfocus();

    final isLoginAttempt = _isLoginTab;
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    var shouldClearPendingHouseSetupDraft = false;
    var handedOffToAppEntry = false;
    String? sessionRole;

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog(L10nService().translate('auth_err_empty_credentials'));
      return;
    }

    if (!email.contains('@')) {
      _showErrorDialog(
        L10nService().translate('Vui lòng sử dụng Email hợp lệ!'),
      );
      return;
    }

    final emailLower = email.toLowerCase();
    const allowedDomains = [
      '@gmail.com',
      '@hotmail.com',
      '@outlook.com',
      '@icloud.com',
      '@yahoo.com',
      '@live.com',
      '@msn.com',
      '@proton.me',
      '@protonmail.com',
    ];
    final isDomainAllowed = allowedDomains.any(
      (domain) => emailLower.endsWith(domain),
    );

    if (!isDomainAllowed) {
      _showErrorDialog(L10nService().translate('auth_supported_domains_only'));
      return;
    }

    if (!await _checkAuthRateLimit()) {
      return;
    }

    if (!isLoginAttempt) {
      if (!_acceptTerms) {
        _showErrorDialog(L10nService().translate('auth_err_must_agree_terms'));
        return;
      }

      if (password.length < 6) {
        _showErrorDialog(L10nService().translate('auth_password_min_length'));
        return;
      }

      if (_showSecurityQuestion &&
          DateInputUtils.looksLikeBirthQuestion(_selectedSecurityQuestion) &&
          _securityAnswerController.text.trim().isNotEmpty) {
        final validationError = DateInputUtils.validationError(
          _securityAnswerController.text,
          firstYear: 1900,
          lastYear: DateTime.now().year,
          allowMissingYear: true,
        );
        if (validationError != null) {
          _showErrorDialog(validationError);
          return;
        }
      }

      final relationshipMode = await _ensureRelationshipModeSelected(email);
      if (relationshipMode == null) {
        return;
      }

      sessionRole = await _askGender(email);
      if (sessionRole == null) {
        return;
      }

      if (_failedAuthAttempts >= _captchaAfterFailedAttempts) {
        final passed = await _showMathCaptcha();
        if (!passed) return;
        if (!mounted) return;
      }
    } else {
      sessionRole = await _readSavedGender(email);
      if (sessionRole == null && mounted) {
        sessionRole = await _askGender(email);
        if (sessionRole == null) {
          return;
        }
      }
    }

    if (!mounted) return;

    if (isLoginAttempt) {
      if (_failedAuthAttempts >= _captchaAfterFailedAttempts) {
        final passed = await _showMathCaptcha();
        if (!passed) return;
        if (!mounted) return;
      }

      final canContinue = await _securityFlowGuard.guard(
        context,
        action: SensitiveActionType.loginWithPassword,
        onWarnStepUp: _showMathCaptcha,
      );
      if (!canContinue) {
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (isLoginAttempt) {
        SLNotice.showInfo(
          context,
          L10nService().translate('Đang đăng nhập... 🔐'),
        );

        _rememberProxyStateAtLogin();

        await _authService.signInWithEmailPassword(email, password);

        _prefs ??= await SharedPreferences.getInstance();
        final prefs = _prefs!;
        if (_rememberMe) {
          await prefs.setString('il_remembered_email', email);
        } else {
          await prefs.remove('il_remembered_email');
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final cachedAuthUid =
              (await SecureStorageService.instance.read(
                SecureStorageService.keyAuthUid,
              ))?.trim() ??
              prefs.getString('il_auth_uid')?.trim() ??
              '';
          if (cachedAuthUid.isNotEmpty && cachedAuthUid != user.uid) {
            await SecureStorageService.instance.delete(
              SecureStorageService.keyHouseId,
            );
            await SecureStorageService.instance.delete(
              SecureStorageService.keyRole,
            );
            await prefs.remove('il_house_id');
            await prefs.remove('il_role');
          }
          await prefs.setString('il_auth_uid', user.uid);
          await SecureStorageService.instance.write(
            SecureStorageService.keyAuthUid,
            user.uid,
          );
        }

        String? resolvedHouseId;
        var houseLookupCompleted = false;
        if (user != null) {
          try {
            resolvedHouseId = await HouseService()
                .getCurrentHouseId(preferFresh: true)
                .timeout(const Duration(seconds: 15));
            houseLookupCompleted = true;
            final houseId = resolvedHouseId?.trim() ?? '';
            if (houseId.isNotEmpty) {
              await prefs.setString('il_house_id', houseId);
              await SecureStorageService.instance.write(
                SecureStorageService.keyHouseId,
                houseId,
              );
            }
          } catch (e) {
            debugPrint('[Auth][LoginScreen] Error fetching houseId: $e');
          }
        }

        // Auth finalize đã đồng bộ role từ member server nếu tài khoản có
        // House. Chỉ ghi role đã chọn cho tài khoản chưa có House (thường là
        // tài khoản mới đang chờ onboarding), tránh ghi đè role của người ấy.
        final cachedHouseId = prefs.getString('il_house_id')?.trim() ?? '';
        final cachedHouseUid = prefs.getString('il_auth_uid')?.trim() ?? '';
        final hasHouse =
            (resolvedHouseId?.trim().isNotEmpty ?? false) ||
            (houseLookupCompleted &&
                cachedHouseId.isNotEmpty &&
                cachedHouseUid == user?.uid);
        if (houseLookupCompleted && !hasHouse &&
            (sessionRole == 'user1' || sessionRole == 'user2')) {
          await prefs.setString('il_role', sessionRole!);
          await SecureStorageService.instance.write(
            SecureStorageService.keyRole,
            sessionRole,
          );
        }

        if (!mounted) return;
        _failedAuthAttempts = 0; // Reset on success
        debugPrint('[Auth][LoginScreen] login success -> navigate AppEntry');
        handedOffToAppEntry = true;
        setState(() {
          _isLoading = false;
          _isSuccessTransition = true;
        });
        await Future<void>.delayed(
          const Duration(milliseconds: 600),
        ); // wait for transition
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AppEntry()));
        return;
      } else {
        _rememberProxyStateAtLogin();

        shouldClearPendingHouseSetupDraft = true;
        await _persistPendingHouseSetupDraft(email: email, role: sessionRole);
        if (!mounted) {
          return;
        }
        debugPrint('[Auth][LoginScreen] start registerWithEmailPassword');
        await _authService.registerWithEmailPassword(email, password);
        debugPrint('[Auth][LoginScreen] register success');
        shouldClearPendingHouseSetupDraft = false;

        if (!mounted) return;
        _failedAuthAttempts = 0; // Reset on success
        debugPrint('[Auth][LoginScreen] register success -> navigate AppEntry');
        handedOffToAppEntry = true;
        setState(() {
          _isLoading = false;
          _isSuccessTransition = true;
        });
        await Future<void>.delayed(
          const Duration(milliseconds: 600),
        ); // wait for transition
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AppEntry()));
        return;
      }
    } catch (e) {
      if (!isLoginAttempt && shouldClearPendingHouseSetupDraft) {
        await _clearPendingHouseSetupDraft();
      }
      await _clearTransientRoleIfSignedOut();

      final l10n = L10nService();
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: isLoginAttempt
            ? l10n.translate('auth_login_unavailable')
            : l10n.translate('auth_signup_unavailable'),
      );

      final accountErrorText =
          '${AppErrorMapper.cleanMessage(e)} ${errorInfo.message}'.toLowerCase();
      final isAccountNotFound =
          isLoginAttempt &&
          (accountErrorText.contains('tài khoản không tồn tại') ||
              accountErrorText.contains('không tìm thấy tài khoản') ||
              accountErrorText.contains('account does not exist') ||
              accountErrorText.contains('account not found') ||
              accountErrorText.contains('user-not-found') ||
              accountErrorText.contains('user not found'));

      // Chỉ tính lỗi xác thực thật sự. Lỗi mạng, timeout, App Check hoặc
      // server bận không nên làm CAPTCHA xuất hiện ở lần thử kế tiếp.
      if (!isLoginAttempt ||
          _isCredentialLoginFailure(
            error: e,
            errorInfo: errorInfo,
            isAccountNotFound: isAccountNotFound,
          )) {
        _failedAuthAttempts++;
      }

      var displayMessage = errorInfo.message;
      if (!mounted) return;
      if (isAccountNotFound) {
        _prefs ??= await SharedPreferences.getInstance();
        final prefs = _prefs!;
        final savedEmail = prefs.getString('il_remembered_email');
        if (savedEmail != null && savedEmail.isNotEmpty) {
          final currentEmail = _emailController.text.trim().toLowerCase();
          final savedLower = savedEmail.toLowerCase();
          if (currentEmail != savedLower) {
            final dist = _levenshtein(currentEmail, savedLower);
            if (dist > 0 && dist <= 3) {
              displayMessage = l10n.format('auth_account_hint_email', {
                'email': savedEmail,
                'message': l10n.translate(errorInfo.message),
              });
            }
          }
        }
      }

      final showRecovery =
          !isAccountNotFound &&
          isLoginAttempt &&
          (AppErrorMapper.shouldOfferPasswordRecovery(e) ||
              AppErrorMapper.shouldOfferPasswordRecovery(errorInfo.message));
      if (!mounted) return;

      if (isAccountNotFound) {
        await AuthFeedbackDialogs.showAccountNotFoundDialog(
          context,
          message: displayMessage,
          onCreateNew: () => _setAuthTab(false),
        );
      } else if (showRecovery) {
        await AuthFeedbackDialogs.showLoginErrorWithRecovery(
          context,
          message: displayMessage,
          onRegister: () => _setAuthTab(false),
          onForgotPassword: _handleForgotPasswordAction,
          onForgotGmail: _handleForgotGmailFlow,
        );
      } else {
        _showErrorDialog(displayMessage);
      }
    } finally {
      if (mounted && !handedOffToAppEntry) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isCredentialLoginFailure({
    required Object error,
    required AppErrorInfo errorInfo,
    required bool isAccountNotFound,
  }) {
    if (isAccountNotFound ||
        AppErrorMapper.shouldOfferPasswordRecovery(error) ||
        AppErrorMapper.shouldOfferPasswordRecovery(errorInfo.message)) {
      return true;
    }

    if (error is FirebaseAuthException) {
      return const {
        'invalid-credential',
        'user-not-found',
        'wrong-password',
      }.contains(error.code);
    }

    return false;
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((minValue, value) => minValue < value ? minValue : value);
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return current[b.length];
  }

  void _showErrorDialog(String message) {
    AuthFeedbackDialogs.showError(context, message);
  }

  void _handleForgotPasswordAction() {
    unawaited(ForgotPasswordLauncher.launch(context));
  }

  Future<bool> _guardForgotPasswordReset() {
    return _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.forgotPasswordReset,
      onWarnStepUp: _showMathCaptcha,
    );
  }

  void _handleForgotGmailFlow() {
    unawaited(
      ForgotGmailRecoveryHelper.launch(
        context: context,
        authService: _authService,
        onGuardPasswordReset: _guardForgotPasswordReset,
      ),
    );
  }

  Future<bool> _showMathCaptcha() {
    return MathCaptchaDialog.show(context);
  }

  void _showContactDialog() {
    unawaited(AuthSupportDialog.show(context));
  }

  Future<void> _handleSocialLogin(String provider) async {
    if (_authActionInProgress || _isLoading || _isSuccessTransition) return;
    if (!SocialAuthActionHelper.isSupportedProvider(provider)) {
      return;
    }

    // Khóa đồng bộ ngay trước await đầu tiên, kể cả trong lúc guard/CAPTCHA và
    // hộp chọn giới tính đang mở, để hai lần chạm không tạo hai phiên Auth.
    _authActionInProgress = true;
    setState(() => _isLoading = true);
    var handedOffToAppEntry = false;
    var providerAttempted = false;
    try {
      final canContinue = await _securityFlowGuard.guard(
        context,
        action: SocialAuthActionHelper.sensitiveActionFor(provider),
        onWarnStepUp: _showMathCaptcha,
      );
      if (!canContinue) return;

      // Hỏi giới tính trước khi đăng nhập mạng xã hội để AppEntry không tự
      // chuyển hướng và che mất hộp thoại.
      final selectedRole = await _askGender();
      if (selectedRole == null) return;

      // Lưu vai trò trước khi gọi provider để phiên mới luôn có scope rõ ràng.
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      await prefs.setString('il_role', selectedRole);
      await SecureStorageService.instance.write(
        SecureStorageService.keyRole,
        selectedRole,
      );

      providerAttempted = true;
      final result = switch (provider) {
        'Facebook' => await _authService.signInWithFacebook(),
        'Apple' => await _authService.signInWithApple(),
        _ => await _authService.signInWithGoogle(),
      };
      if (!mounted) return;

      if (result == null || result.user == null) {
        await _clearTransientRoleIfSignedOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(SocialAuthActionHelper.cancelledMessage(provider)),
          ),
        );
        return;
      }

      final email = (result.user?.email ?? '').trim().toLowerCase();
      var storedRole = selectedRole;
      if (email.isNotEmpty) {
        final savedAccountRole = prefs
            .getString('il_saved_gender_$email')
            ?.trim();
        if (savedAccountRole == 'user1' || savedAccountRole == 'user2') {
          // Tài khoản đã có role riêng thì ưu tiên bản ghi của chính tài
          // khoản, không dùng lựa chọn còn sót từ màn Login.
          storedRole = savedAccountRole!;
        } else {
          await prefs.setString('il_saved_gender_$email', storedRole);
        }
      }
      final user = result.user;
      if (user != null) {
        final cachedAuthUid =
            (await SecureStorageService.instance.read(
              SecureStorageService.keyAuthUid,
            ))?.trim() ??
            prefs.getString('il_auth_uid')?.trim() ??
            '';
        if (cachedAuthUid.isNotEmpty && cachedAuthUid != user.uid) {
          await SecureStorageService.instance.delete(
            SecureStorageService.keyHouseId,
          );
          await SecureStorageService.instance.delete(
            SecureStorageService.keyRole,
          );
          await prefs.remove('il_house_id');
          await prefs.remove('il_role');
        }
        await prefs.setString('il_auth_uid', user.uid);
        await SecureStorageService.instance.write(
          SecureStorageService.keyAuthUid,
          user.uid,
        );
      }

      String? resolvedHouseId;
      var houseLookupCompleted = false;
      if (user != null) {
        try {
          resolvedHouseId = await HouseService()
              .getCurrentHouseId(preferFresh: true)
              .timeout(const Duration(seconds: 15));
          houseLookupCompleted = true;
          final houseId = resolvedHouseId?.trim() ?? '';
          if (houseId.isNotEmpty) {
            await prefs.setString('il_house_id', houseId);
            await SecureStorageService.instance.write(
              SecureStorageService.keyHouseId,
              houseId,
            );
          }
        } catch (e) {
          debugPrint('[Auth][LoginScreen] Error fetching houseId (Social): $e');
        }
      }

      // Với House hiện hữu, Auth finalize đã lấy role từ member server. Role
      // chọn trước provider chỉ được dùng cho onboarding tài khoản chưa có
      // House.
      final cachedHouseId = prefs.getString('il_house_id')?.trim() ?? '';
      final cachedHouseUid = prefs.getString('il_auth_uid')?.trim() ?? '';
      final hasHouse =
          (resolvedHouseId?.trim().isNotEmpty ?? false) ||
          (houseLookupCompleted &&
              cachedHouseId.isNotEmpty &&
              cachedHouseUid == user?.uid);
      if (houseLookupCompleted && !hasHouse &&
          (storedRole == 'user1' || storedRole == 'user2')) {
        await prefs.setString('il_role', storedRole);
        await SecureStorageService.instance.write(
          SecureStorageService.keyRole,
          storedRole,
        );
      }

      if (!mounted) return;
      _failedAuthAttempts = 0; // Reset on success
      debugPrint(
        '[Auth][LoginScreen] social login success -> navigate AppEntry',
      );
      handedOffToAppEntry = true;
      setState(() {
        _isLoading = false;
        _isSuccessTransition = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AppEntry()));
      return;
    } catch (e) {
      if (providerAttempted) {
        // Lỗi ở bước lưu scope hoặc đọc house sau khi provider đã cấp phiên
        // không được để lại một phiên đăng nhập nửa chừng trên màn Login.
        try {
          await _authService.signOut().timeout(const Duration(seconds: 4));
        } catch (cleanupError) {
          debugPrint(
            '[Auth][LoginScreen] social cleanup failed: $cleanupError',
          );
        }
      }
      await _clearTransientRoleIfSignedOut();
      _failedAuthAttempts++;
      final resolvedMessage = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('auth_login_unavailable'),
      ).message;
      debugPrint(
        '[Auth][LoginScreen] social login failed ($provider): $resolvedMessage',
      );
      if (!mounted) return;
      _showErrorDialog(
        resolvedMessage.isEmpty
            ? L10nService().translate('auth_login_unavailable')
            : resolvedMessage,
      );
    } finally {
      _authActionInProgress = false;
      if (mounted && !handedOffToAppEntry) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openTermsDocument() {
    final l10n = L10nService();
    slPush<void>(
      context,
      DocumentViewerScreen(
        title: l10n.locale.languageCode == 'vi'
            ? l10n.translate('Điều khoản sử dụng')
            : context.tr('update_hub_terms'),
        assetPath: 'assets/docs/terms.html',
      ),
    );
  }

  void _openPrivacyDocument() {
    final l10n = L10nService();
    slPush<void>(
      context,
      DocumentViewerScreen(
        title: l10n.locale.languageCode == 'vi'
            ? l10n.translate('Chính sách bảo mật')
            : context.tr('privacy_policy'),
        assetPath: 'assets/docs/privacy.html',
      ),
    );
  }

  void _openGuideDocument() {
    final l10n = L10nService();
    slPush<void>(
      context,
      DocumentViewerScreen(
        title: l10n.locale.languageCode == 'vi'
            ? l10n.translate('Hướng dẫn sử dụng')
            : context.tr('Hướng dẫn sử dụng'),
        assetPath: 'assets/docs/huong_dan.html',
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10nService(),
      builder: (context, _) => SensitiveContentGuard(
        child: AuthPageScaffold(
          copyrightYear: _copyrightYear.toString(),
          transitioning: _isSuccessTransition,
          onSyncGuide: () => _showSyncGuideDialog(context),
          contentBuilder: (compact) => AuthPanelShell(
            compact: compact,
            isLoginTab: _isLoginTab,
            onSelectLogin: () {
              if (!_authActionInProgress && !_isLoading) _setAuthTab(true);
            },
            onSelectRegister: () {
              if (!_authActionInProgress && !_isLoading) _setAuthTab(false);
            },
            authSection: _isLoginTab
                ? LoginShell(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    isLoading: _isLoading,
                    rememberMe: _rememberMe,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onRememberMeChanged: (value) =>
                        setState(() => _rememberMe = value ?? true),
                    onLogin: _handleAuthAction,
                    onForgotPassword: _handleForgotPasswordAction,
                    onSocialLogin: _handleSocialLogin,
                  )
                : RegisterShell(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    isLoading: _isLoading,
                    acceptTerms: _acceptTerms,
                    showSecurityQuestion: _showSecurityQuestion,
                    selectedSecurityQuestion: _selectedSecurityQuestion,
                    securityQuestions: _cleanSecurityQuestions,
                    securityAnswerController: _securityAnswerController,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onAcceptTermsChanged: (value) =>
                        setState(() => _acceptTerms = value ?? false),
                    onToggleSecurityQuestion: () => setState(
                      () => _showSecurityQuestion = !_showSecurityQuestion,
                    ),
                    onSecurityQuestionChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSecurityQuestion = value);
                    },
                    onRegister: _handleAuthAction,
                    onSocialLogin: _handleSocialLogin,
                    onTermsTap: _openTermsDocument,
                    onPrivacyTap: _openPrivacyDocument,
                  ),
            onOpenGuide: _openGuideDocument,
            onOpenContact: _showContactDialog,
          ),
        ),
      ),
    );
  }

  void _showSyncGuideDialog(BuildContext context, {bool enforceDelay = false}) {
    showDialog<void>(
      context: context,
      barrierDismissible: !enforceDelay,
      builder: (dialogContext) =>
          _SyncGuideDialogContent(enforceDelay: enforceDelay),
    );
  }
}

class _SyncGuideDialogContent extends StatefulWidget {
  final bool enforceDelay;

  const _SyncGuideDialogContent({required this.enforceDelay});

  @override
  State<_SyncGuideDialogContent> createState() =>
      _SyncGuideDialogContentState();
}

class _SyncGuideDialogContentState extends State<_SyncGuideDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _countdownController;
  final L10nService _l10n = L10nService();

  @override
  void initState() {
    super.initState();
    final countdownMs = widget.enforceDelay ? (kDebugMode ? 500 : 3000) : 1;
    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: countdownMs),
    );
    if (widget.enforceDelay) {
      _countdownController
        ..addListener(_onCountdownTick)
        ..forward();
    } else {
      _countdownController.value = 1;
    }
  }

  void _onCountdownTick() {
    if (mounted) setState(() {});
  }

  bool get _isCountdownActive =>
      widget.enforceDelay && !_countdownController.isCompleted;

  int get _remainingSeconds {
    if (!_isCountdownActive) return 0;
    final durationMs = _countdownController.duration?.inMilliseconds ?? 0;
    final remaining = durationMs * (1 - _countdownController.value);
    return (remaining / 1000).ceil().clamp(1, 99).toInt();
  }

  @override
  void dispose() {
    _countdownController
      ..removeListener(_onCountdownTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCountdownActive,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.96),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA65370).withValues(alpha: 0.18),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EE),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFEEC2CE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 12,
                            color: Color(0xFFD85879),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _l10n.translate('auth_pairing_title'),
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 9.8,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFC64E6E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2EDFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        size: 18,
                        color: Color(0xFF806BC1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const SizedBox(
                  height: 126,
                  width: double.infinity,
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _LegacySyncLoveThreadPainter()),
                  ),
                ),
                Text(
                  _l10n.translate('auth_pairing_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4D3D44),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _l10n.translate('auth_pairing_account_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11.2,
                    height: 1.42,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF89757D),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStep(
                  number: '1',
                  title: _l10n.translate('auth_pairing_account_title'),
                  description: _l10n.translate('auth_pairing_account_desc'),
                  icon: Icons.person_outline_rounded,
                  accent: const Color(0xFFE06686),
                ),
                _buildStep(
                  number: '2',
                  title: _l10n.translate('auth_pairing_code_title'),
                  description: _l10n.translate('auth_pairing_code_desc'),
                  icon: Icons.qr_code_2_rounded,
                  accent: const Color(0xFF8771C7),
                ),
                _buildStep(
                  number: '3',
                  title: _l10n.translate('auth_pairing_sync_title'),
                  description: _l10n.translate('auth_pairing_sync_desc'),
                  icon: Icons.favorite_outline_rounded,
                  accent: const Color(0xFF4F9B90),
                  isLast: true,
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0D49E)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 17,
                        color: Color(0xFFC88B30),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _l10n.translate('auth_pairing_restore_hint'),
                          style: const TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 10.4,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF926621),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _LegacyCuteDialogButton(
                    label: _isCountdownActive
                        ? '${_l10n.translate('Đã hiểu')} ($_remainingSeconds)'
                        : _l10n.translate('Đã hiểu'),
                    onPressed: _isCountdownActive
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Color accent,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 38,
              child: Column(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.42)),
                    ),
                    child: Text(
                      number,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: accent.withValues(alpha: 0.24),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 17, color: accent),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF5B4850),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 10.3,
                              height: 1.34,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A757D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyCuteDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _LegacyCuteDialogButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE9698B), Color(0xFFF38FA8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE9698B).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegacySyncLoveThreadPainter extends CustomPainter {
  const _LegacySyncLoveThreadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.53;
    final left = Offset(size.width * 0.20, centerY);
    final right = Offset(size.width * 0.80, centerY);

    final thread = Paint()
      ..color = const Color(0xFFE79AAF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(left.dx + 29, left.dy)
      ..cubicTo(
        size.width * 0.38,
        centerY - 30,
        size.width * 0.62,
        centerY + 30,
        right.dx - 29,
        right.dy,
      );
    canvas.drawPath(path, thread);

    _drawPerson(canvas, left, const Color(0xFFFFD9E2), const Color(0xFFE76B8C));
    _drawPerson(
      canvas,
      right,
      const Color(0xFFE6DFFF),
      const Color(0xFF7E6CC1),
    );

    final heartCenter = Offset(size.width * 0.50, centerY - 1);
    _drawHeart(canvas, heartCenter, 19, const Color(0xFFF06D8D));

    final sparkle = Paint()
      ..color = const Color(0xFFF0C66E)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final point in <Offset>[
      Offset(size.width * 0.35, centerY - 35),
      Offset(size.width * 0.66, centerY - 32),
      Offset(size.width * 0.53, centerY + 37),
    ]) {
      canvas.drawLine(point.translate(-4, 0), point.translate(4, 0), sparkle);
      canvas.drawLine(point.translate(0, -4), point.translate(0, 4), sparkle);
    }
  }

  void _drawPerson(Canvas canvas, Offset center, Color fill, Color accent) {
    final shadow = Paint()
      ..color = const Color(0xFF7B5F68).withValues(alpha: 0.10);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 28), width: 55, height: 12),
      shadow,
    );

    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 58, height: 70),
      const Radius.circular(22),
    );
    canvas.drawRRect(card, Paint()..color = fill);
    canvas.drawRRect(
      card,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      center.translate(0, -9),
      10,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center.translate(-3.5, -10),
      1.3,
      Paint()..color = accent,
    );
    canvas.drawCircle(center.translate(3.5, -10), 1.3, Paint()..color = accent);
    final smile = Path()
      ..moveTo(center.dx - 3.5, center.dy - 5)
      ..quadraticBezierTo(
        center.dx,
        center.dy - 1,
        center.dx + 3.5,
        center.dy - 5,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    _drawHeart(canvas, center.translate(0, 17), 7, accent);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.46)
      ..cubicTo(
        center.dx - size * 0.58,
        center.dy + size * 0.05,
        center.dx - size * 0.52,
        center.dy - size * 0.42,
        center.dx,
        center.dy - size * 0.12,
      )
      ..cubicTo(
        center.dx + size * 0.52,
        center.dy - size * 0.42,
        center.dx + size * 0.58,
        center.dy + size * 0.05,
        center.dx,
        center.dy + size * 0.46,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LegacySyncLoveThreadPainter oldDelegate) =>
      false;
}
