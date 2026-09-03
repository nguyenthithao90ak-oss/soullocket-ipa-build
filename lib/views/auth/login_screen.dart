import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/anti_spam_service.dart';
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
import 'login/auth_language_toggle.dart';
import 'login/auth_panel_shell.dart';
import 'login/forgot_password_launcher.dart';
import 'login/login_shell.dart';
import 'login/social_auth_action_helper.dart';
import 'login/aurora_login_screen.dart';
import 'login/aurora_hero_background.dart';
import 'login/aurora_decorative_orbs.dart';
import '../../views/ui_prefs.dart';
import 'register/register_shell.dart';
import 'widgets/gender_selection_dialog.dart';
import 'widgets/relationship_mode_dialog.dart';
import '../home/screens/document_viewer_screen.dart';
import '../app_entry.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _pendingSignupRecoveryQuestionPrefsKey =
      'il_pending_signup_recovery_question';
  static const String _pendingSignupRecoveryAnswerPrefsKey =
      'il_pending_signup_recovery_answer';
  static const String _pendingSignupAutoCreateHousePrefsKey =
      'il_pending_signup_auto_create_house';

  static final int _copyrightYear = DateTime.now().year;

  SharedPreferences? _prefs;

  bool _isLoginTab = true;
  bool _obscurePassword = false;
  bool _isLoading = false;
  bool _isSuccessTransition = false;
  bool _rememberMe = true;
  bool _acceptTerms = false;
  bool _showSecurityQuestion = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _securityAnswerController =
      TextEditingController();

  int _failedAuthAttempts = 0;

  final AuthService _authService = AuthService();
  final HouseService _houseService = HouseService();
  final AntiSpamRateLimitService _authRateLimiter = AntiSpamRateLimitService();
  final SecurityFlowGuard _securityFlowGuard = SecurityFlowGuard.instance;

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
      _checkFirstTimeSyncGuide();
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _checkFirstTimeSyncGuide() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _isLoading) return;
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final hasSeen = prefs.getBool('il_has_seen_sync_guide_v2') ?? false;
    if (!hasSeen) {
      await prefs.setBool('il_has_seen_sync_guide_v2', true);
      if (!mounted) return;
      _showSyncGuideDialog(context, enforceDelay: true);
    }
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
      builder: (dialogContext) => AlertDialog(
        title: Text(L10nService().translate('⚠️ Đã đăng xuất')),
        content: Text(L10nService().translate(reason)),
        actions: [
          TextButton(
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
      SecurityService().isProxyOrVpnActive().then(
        SecurityService().setProxyAtLogin,
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
    } catch (_) {}

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
    final allowed = await _authRateLimiter.checkRateLimit(
      action: _isLoginTab ? 'auth_login' : 'auth_register',
      maxCalls: 3,
      timeWindowMs: 5000,
    );
    if (allowed) return true;

    final cooldown = await _authRateLimiter.remainingCooldownSeconds;
    if (!mounted) return false;

    if (shouldShowRapidActionWarningSeconds(cooldown)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn thao tác hơi nhanh. Vui lòng chờ một lát rồi thử lại.',
          ),
          duration: Duration(seconds: 2),
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
      } catch (_) {}
    }
    return null;
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

  Future<void> _persistPendingHouseSetupDraft({required String? role}) async {
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

    await prefs.setBool(_pendingSignupAutoCreateHousePrefsKey, true);
  }

  Future<void> _clearPendingHouseSetupDraft() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    await prefs.remove(_pendingSignupRecoveryQuestionPrefsKey);
    await prefs.remove(_pendingSignupRecoveryAnswerPrefsKey);
    await prefs.remove(_pendingSignupAutoCreateHousePrefsKey);
  }

  void _setAuthTab(bool isLoginTab) {
    if (_isLoginTab == isLoginTab) return;
    setState(() {
      _isLoginTab = isLoginTab;
    });
  }

  Future<void> _handleAuthAction() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    var shouldClearPendingHouseSetupDraft = false;
    var handedOffToAppEntry = false;
    String? sessionRole;
    bool didAutoLogin = false;

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
      _showErrorDialog(
        L10nService().translate('auth_supported_domains_only'),
      );
      return;
    }

    if (!await _checkAuthRateLimit()) {
      return;
    }

    if (!_isLoginTab) {
      if (!_acceptTerms) {
        _showErrorDialog(L10nService().translate('auth_err_must_agree_terms'));
        return;
      }

      if (password.length < 6) {
        _showErrorDialog(
          L10nService().translate('Mật khẩu cần tối thiểu 6 ký tự!'),
        );
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

      setState(() => _isLoading = true);
      try {
        await _authService.signInWithEmailPassword(email, password);
        didAutoLogin = true;
        setState(() => _isLoginTab = true);
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (!errorString.contains('wrong_password') &&
            !errorString.contains('wrong-password') &&
            !errorString.contains('user-not-found') &&
            !errorString.contains('account_not_found') &&
            !errorString.contains('invalid-credential') &&
            !errorString.contains('mật khẩu không chính xác') &&
            !errorString.contains('sai mật khẩu') &&
            !errorString.contains('tài khoản không tồn tại')) {
          if (mounted) setState(() => _isLoading = false);
          rethrow;
        }
      }
      if (mounted) setState(() => _isLoading = false);

      if (!didAutoLogin) {
        final relationshipMode = await _ensureRelationshipModeSelected(email);
        if (relationshipMode == null) {
          return;
        }

        sessionRole = await _askGender(email);
        if (sessionRole == null) {
          return;
        }

        if (_failedAuthAttempts >= 2) {
          final passed = await _showMathCaptcha();
          if (!passed) return;
          if (!mounted) return;
        }
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

    if (sessionRole != null) {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      await prefs.setString('il_role', sessionRole);
      await SecureStorageService.instance.write(
        SecureStorageService.keyRole,
        sessionRole,
      );
    }

    if (!mounted) return;

    if (_isLoginTab) {
      if (_failedAuthAttempts >= 2) {
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
      if (_isLoginTab) {
        SLNotice.showInfo(
          context,
          L10nService().translate('Đang đăng nhập... 🔐'),
        );

        _rememberProxyStateAtLogin();

        if (!didAutoLogin) {
          await _authService.signInWithEmailPassword(email, password);
        }

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

        if (sessionRole == 'user1' || sessionRole == 'user2') {
          await prefs.setString('il_role', sessionRole!);
          await SecureStorageService.instance.write(
            SecureStorageService.keyRole,
            sessionRole,
          );
        }

        if (user != null) {
          try {
            final houseId = await HouseService()
                .getCurrentHouseId(preferFresh: true)
                .timeout(const Duration(seconds: 15));
            if (houseId != null && houseId.isNotEmpty) {
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

        await _persistPendingHouseSetupDraft(role: sessionRole);
        shouldClearPendingHouseSetupDraft = true;
        if (!mounted) {
          shouldClearPendingHouseSetupDraft = false;
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
      _failedAuthAttempts++;
      if (!_isLoginTab && shouldClearPendingHouseSetupDraft) {
        await _clearPendingHouseSetupDraft();
      }

      final l10n = L10nService();
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: _isLoginTab
            ? l10n.translate('auth_login_unavailable')
            : l10n.translate('auth_signup_unavailable'),
      );

      final isAccountNotFound =
          _isLoginTab &&
          (errorInfo.message.contains('Tài khoản không tồn tại') ||
              errorInfo.message.contains('Account does not exist'));

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
          _isLoginTab &&
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

  void _handleSocialLogin(String provider) async {
    var handedOffToAppEntry = false;

    if (!SocialAuthActionHelper.isSupportedProvider(provider)) {
      return;
    }

    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SocialAuthActionHelper.sensitiveActionFor(provider),
      onWarnStepUp: _showMathCaptcha,
    );
    if (!canContinue) {
      return;
    }

    // Hỏi giới tính trước khi đăng nhập mạng xã hội để tránh bị AppEntry tự động chuyển hướng làm ẩn dialog
    final selectedRole = await _askGender();
    if (selectedRole == null) {
      return;
    }

    // Lưu ngay vai trò vào SharedPreferences và SecureStorage trước khi gọi API đăng nhập
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    await prefs.setString('il_role', selectedRole);
    await SecureStorageService.instance.write(
      SecureStorageService.keyRole,
      selectedRole,
    );

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final result = switch (provider) {
        'Facebook' => await _authService.signInWithFacebook(),
        'Apple' => await _authService.signInWithApple(),
        _ => await _authService.signInWithGoogle(),
      };
      if (!mounted) return;

      if (result == null || result.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SocialAuthActionHelper.cancelledMessage(provider)),
          ),
        );
        return;
      }

      final email = (result.user?.email ?? '').trim().toLowerCase();
      var storedRole = selectedRole;
      if (email.isNotEmpty) {
        await prefs.setString('il_saved_gender_$email', storedRole);
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

      if (storedRole == 'user1' || storedRole == 'user2') {
        await prefs.setString('il_role', storedRole);
        await SecureStorageService.instance.write(
          SecureStorageService.keyRole,
          storedRole,
        );
      }

      if (user != null) {
        try {
          final houseId = await HouseService()
              .getCurrentHouseId(preferFresh: true)
              .timeout(const Duration(seconds: 15));
          if (houseId != null && houseId.isNotEmpty) {
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

      if (!mounted) return;
      _failedAuthAttempts = 0; // Reset on success
      debugPrint(
        '[Auth][LoginScreen] social login success -> navigate AppEntry',
      );
      handedOffToAppEntry = true;
      setState(() => _isLoading = false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AppEntry()));
      return;
    } catch (e) {
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
      if (mounted && !handedOffToAppEntry) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openTermsDocument() {
    final l10n = L10nService();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: l10n.locale.languageCode == 'vi'
              ? l10n.translate('Điều khoản sử dụng')
              : 'Terms of Use',
          assetPath: 'assets/docs/terms.html',
        ),
      ),
    );
  }

  void _openPrivacyDocument() {
    final l10n = L10nService();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: l10n.locale.languageCode == 'vi'
              ? l10n.translate('Chính sách bảo mật')
              : 'Privacy Policy',
          assetPath: 'assets/docs/privacy.html',
        ),
      ),
    );
  }

  void _openGuideDocument() {
    final l10n = L10nService();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: l10n.locale.languageCode == 'vi'
              ? l10n.translate('Hướng dẫn sử dụng')
              : 'User Guide',
          assetPath: 'assets/docs/huong_dan.html',
        ),
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
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      builder: (context, prefs, _) {
        if (prefs.uiVersion == 'v2') {
          return const AuroraLoginScreen();
        }
        return ListenableBuilder(
          listenable: L10nService(),
          builder: (context, _) {
            final l10n = L10nService();
            return SensitiveContentGuard(
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: SLColors.surfaceWarm,
                body: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: AuroraHeroBackground()),
                      const Positioned.fill(
                        child: IgnorePointer(child: AuroraDecorativeOrbs()),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 920;
                          final isTablet =
                              constraints.maxWidth >= 680 &&
                              constraints.maxWidth < 920;
                          final isCompact = constraints.maxWidth < 450;
                          final horizontalPadding =
                              SLResponsive.horizontalPaddingForWidth(
                                constraints.maxWidth,
                                compactPadding: 10,
                                handsetPadding: 18,
                                tabletPadding: 24,
                              );
                          final contentMaxWidth = isDesktop
                              ? 1080.0
                              : isTablet
                              ? 560.0
                              : 460.0;
                          final authPanelWidth = isDesktop
                              ? 408.0
                              : min(
                                  520.0,
                                  constraints.maxWidth - (isCompact ? 20 : 32),
                                );

                          return Center(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(
                                left: horizontalPadding,
                                right: horizontalPadding,
                                top: 10,
                                bottom:
                                    10 +
                                    MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SafeArea(
                                    bottom: false,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: isCompact ? 12 : 16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                _showSyncGuideDialog(context),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFFD6E0,
                                                  ),
                                                  width: 1.2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: SLColors.brandPink
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ShaderMask(
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFF9E00),
                                                            Color(0xFFFF6B00),
                                                          ],
                                                        ).createShader(bounds),
                                                    child: const Icon(
                                                      Icons.lightbulb_rounded,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    l10n.translate(
                                                      'auth_sync_guide',
                                                    ),
                                                    style: SLTheme.quicksand(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: SLColors.brandPink,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          AuthLanguageToggle(
                                            currentLocale: l10n.localeCode,
                                            onSelect: (code) {
                                              l10n.setLocale(code);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  AnimatedPadding(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                    padding: EdgeInsets.only(
                                      top: _isLoginTab ? 0 : 4,
                                    ),
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      opacity: _isSuccessTransition ? 0.0 : 1.0,
                                      child: AnimatedScale(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        scale: _isSuccessTransition ? 1.1 : 1.0,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: contentMaxWidth,
                                          ),
                                          child: Center(
                                            child: SizedBox(
                                              width: authPanelWidth,
                                              child: AuthPanelShell(
                                                compact:
                                                    !isDesktop &&
                                                    (isCompact || isTablet),
                                                isLoginTab: _isLoginTab,
                                                onSelectLogin: () =>
                                                    _setAuthTab(true),
                                                onSelectRegister: () =>
                                                    _setAuthTab(false),
                                                authSection: _isLoginTab
                                                    ? LoginShell(
                                                        emailController:
                                                            _emailController,
                                                        passwordController:
                                                            _passwordController,
                                                        obscurePassword:
                                                            _obscurePassword,
                                                        isLoading: _isLoading,
                                                        rememberMe: _rememberMe,
                                                        onToggleObscure: () => setState(
                                                          () => _obscurePassword =
                                                              !_obscurePassword,
                                                        ),
                                                        onRememberMeChanged:
                                                            (value) => setState(
                                                              () =>
                                                                  _rememberMe =
                                                                      value ??
                                                                      true,
                                                            ),
                                                        onLogin:
                                                            _handleAuthAction,
                                                        onForgotPassword:
                                                            _handleForgotPasswordAction,
                                                        onSocialLogin:
                                                            _handleSocialLogin,
                                                      )
                                                    : RegisterShell(
                                                        emailController:
                                                            _emailController,
                                                        passwordController:
                                                            _passwordController,
                                                        obscurePassword:
                                                            _obscurePassword,
                                                        isLoading: _isLoading,
                                                        acceptTerms:
                                                            _acceptTerms,
                                                        showSecurityQuestion:
                                                            _showSecurityQuestion,
                                                        selectedSecurityQuestion:
                                                            _selectedSecurityQuestion,
                                                        securityQuestions:
                                                            _cleanSecurityQuestions,
                                                        securityAnswerController:
                                                            _securityAnswerController,
                                                        onToggleObscure: () => setState(
                                                          () => _obscurePassword =
                                                              !_obscurePassword,
                                                        ),
                                                        onAcceptTermsChanged:
                                                            (value) => setState(
                                                              () =>
                                                                  _acceptTerms =
                                                                      value ??
                                                                      false,
                                                            ),
                                                        onToggleSecurityQuestion:
                                                            () => setState(
                                                              () => _showSecurityQuestion =
                                                                  !_showSecurityQuestion,
                                                            ),
                                                        onSecurityQuestionChanged:
                                                            (value) {
                                                              if (value == null)
                                                                return;
                                                              setState(
                                                                () =>
                                                                    _selectedSecurityQuestion =
                                                                        value,
                                                              );
                                                            },
                                                        onRegister:
                                                            _handleAuthAction,
                                                        onSocialLogin:
                                                            _handleSocialLogin,
                                                        onTermsTap:
                                                            _openTermsDocument,
                                                        onPrivacyTap:
                                                            _openPrivacyDocument,
                                                      ),
                                                onOpenGuide: _openGuideDocument,
                                                onOpenContact:
                                                    _showContactDialog,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Copyright watermark
                      SafeArea(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).padding.bottom > 0
                                  ? 8
                                  : 16,
                            ),
                            child: Text(
                              'SoulLocket © $_copyrightYear — Tame Trương Việt Hoàng',
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.50),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
                            _l10n.translate('Kết nối hai thiết bị'),
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
                  _l10n.translate('Hai tài khoản, một góc nhỏ chung'),
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
                  _l10n.translate(
                    'Mỗi người vẫn có tài khoản riêng. Sau khi ghép đôi, dữ liệu thuộc không gian chung mới được đồng bộ giữa hai máy.',
                  ),
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
                  title: _l10n.translate('Mỗi người đăng nhập tài khoản riêng'),
                  description: _l10n.translate(
                    'Đăng ký hoặc đăng nhập trên điện thoại của mình bằng Email, Google hoặc Apple.',
                  ),
                  icon: Icons.person_outline_rounded,
                  accent: const Color(0xFFE06686),
                ),
                _buildStep(
                  number: '2',
                  title: _l10n.translate('Ghép đôi bằng một mã kết nối'),
                  description: _l10n.translate(
                    'Vào Cài đặt → Ghép nối dữ liệu. Một người tạo mã, người còn lại nhập mã đó để xác nhận.',
                  ),
                  icon: Icons.qr_code_2_rounded,
                  accent: const Color(0xFF8771C7),
                ),
                _buildStep(
                  number: '3',
                  title: _l10n.translate('Cùng cập nhật không gian chung'),
                  description: _l10n.translate(
                    'Kỷ niệm, nhật ký, album và dữ liệu đôi sẽ được cập nhật sau khi hai tài khoản đã kết nối.',
                  ),
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
                          _l10n.translate(
                            'Khi đổi điện thoại, hãy đăng nhập lại đúng tài khoản để tải phần dữ liệu đã được lưu trên cloud.',
                          ),
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
    _drawPerson(canvas, right, const Color(0xFFE6DFFF), const Color(0xFF7E6CC1));

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
    final shadow = Paint()..color = const Color(0xFF7B5F68).withValues(alpha: 0.10);
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

    canvas.drawCircle(center.translate(0, -9), 10, Paint()..color = Colors.white);
    canvas.drawCircle(center.translate(-3.5, -10), 1.3, Paint()..color = accent);
    canvas.drawCircle(center.translate(3.5, -10), 1.3, Paint()..color = accent);
    final smile = Path()
      ..moveTo(center.dx - 3.5, center.dy - 5)
      ..quadraticBezierTo(center.dx, center.dy - 1, center.dx + 3.5, center.dy - 5);
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
  bool shouldRepaint(covariant _LegacySyncLoveThreadPainter oldDelegate) => false;
}
