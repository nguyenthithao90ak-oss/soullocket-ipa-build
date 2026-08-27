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

  String _selectedSecurityQuestion =
      L10nService().translate('Ngày sinh của bạn?');

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
    _loadRememberedEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKickReason();
      _checkFirstTimeSyncGuide();
    });
  }

  Future<void> _checkFirstTimeSyncGuide() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _isLoading) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('il_has_seen_sync_guide_v2') ?? false;
    if (!hasSeen) {
      await prefs.setBool('il_has_seen_sync_guide_v2', true);
      if (!mounted) return;
      _showSyncGuideDialog(context, enforceDelay: true);
    }
  }

  Future<void> _checkKickReason() async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
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

    final cachedMode = await _authService
        .getCachedRelationshipModeForEmail(normalizedAccountKey);
    if (cachedMode != null) {
      return cachedMode;
    }

    try {
      final existingHouseId =
          await _houseService.getCurrentHouseId(preferFresh: false);
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
          content:
              Text('Bạn thao tác hơi nhanh. Vui lòng chờ một lát rồi thử lại.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  Future<String?> _readSavedGender([String? accountKey]) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountKey != null && accountKey.trim().isNotEmpty) {
      final normalizedAccountKey = accountKey.trim().toLowerCase();
      final savedPerAccount =
          prefs.getString('il_saved_gender_$normalizedAccountKey')?.trim();
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
        final houseId =
            await _houseService.getCurrentHouseId(preferFresh: false);
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
                  'il_saved_gender_$normalizedAccountKey', roleInDb!);
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

    final prefs = await SharedPreferences.getInstance();
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
    required String? role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (role == 'user1' || role == 'user2') {
      await prefs.setString('il_role', role!);
      await SecureStorageService.instance
          .write(SecureStorageService.keyRole, role);
    }

    final shouldSaveRecovery = _showSecurityQuestion &&
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
    final prefs = await SharedPreferences.getInstance();
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
      _showErrorDialog(
        L10nService().translate('auth_err_empty_credentials'),
      );
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
    ];
    final isDomainAllowed =
        allowedDomains.any((domain) => emailLower.endsWith(domain));

    if (!isDomainAllowed) {
      _showErrorDialog(
        L10nService().format('auth_supported_domains_only', {
          'action': _isLoginTab
              ? L10nService().translate('đăng nhập')
              : L10nService().translate('đăng ký'),
          'domains': allowedDomains.join(', '),
        }),
      );
      return;
    }

    if (!await _checkAuthRateLimit()) {
      return;
    }

    if (!_isLoginTab) {
      if (!_acceptTerms) {
        _showErrorDialog(
          L10nService().translate('auth_err_must_agree_terms'),
        );
        return;
      }

      final strongRegex = RegExp(r'^(?=.*[0-9])(?=.{6,})');
      if (!strongRegex.hasMatch(password)) {
        _showErrorDialog(
          L10nService().translate('Mật khẩu yếu: Cần ít nhất 6 ký tự và 1 số!'),
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('il_role', sessionRole);
      await SecureStorageService.instance
          .write(SecureStorageService.keyRole, sessionRole);
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

        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('il_remembered_email', email);
        } else {
          await prefs.remove('il_remembered_email');
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final cachedAuthUid = (await SecureStorageService.instance
                      .read(SecureStorageService.keyAuthUid))
                  ?.trim() ??
              prefs.getString('il_auth_uid')?.trim() ??
              '';
          if (cachedAuthUid.isNotEmpty && cachedAuthUid != user.uid) {
            await SecureStorageService.instance
                .delete(SecureStorageService.keyHouseId);
            await SecureStorageService.instance
                .delete(SecureStorageService.keyRole);
            await prefs.remove('il_house_id');
            await prefs.remove('il_role');
          }
          await prefs.setString('il_auth_uid', user.uid);
          await SecureStorageService.instance
              .write(SecureStorageService.keyAuthUid, user.uid);
        }

        if (sessionRole == 'user1' || sessionRole == 'user2') {
          await prefs.setString('il_role', sessionRole!);
          await SecureStorageService.instance
              .write(SecureStorageService.keyRole, sessionRole);
        }

        if (user != null) {
          try {
            final houseId = await HouseService()
                .getCurrentHouseId(preferFresh: true)
                .timeout(const Duration(seconds: 15));
            if (houseId != null && houseId.isNotEmpty) {
              await prefs.setString('il_house_id', houseId);
              await SecureStorageService.instance
                  .write(SecureStorageService.keyHouseId, houseId);
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
            const Duration(milliseconds: 600)); // wait for transition
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppEntry()),
        );
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
            const Duration(milliseconds: 600)); // wait for transition
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppEntry()),
        );
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

      final isAccountNotFound = _isLoginTab &&
          (errorInfo.message.contains('Tài khoản không tồn tại') ||
              errorInfo.message.contains('Account does not exist'));

      var displayMessage = errorInfo.message;
      if (!mounted) return;
      if (isAccountNotFound) {
        final prefs = await SharedPreferences.getInstance();
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

      final showRecovery = !isAccountNotFound &&
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('il_role', selectedRole);
    await SecureStorageService.instance
        .write(SecureStorageService.keyRole, selectedRole);

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
            content: Text(
              SocialAuthActionHelper.cancelledMessage(provider),
            ),
          ),
        );
        return;
      }

      final email = (result.user?.email ?? '').trim().toLowerCase();
      var storedRole = selectedRole;
      final prefs = await SharedPreferences.getInstance();
      if (email.isNotEmpty) {
        await prefs.setString('il_saved_gender_$email', storedRole);
      }
      final user = result.user;
      if (user != null) {
        final cachedAuthUid = (await SecureStorageService.instance
                    .read(SecureStorageService.keyAuthUid))
                ?.trim() ??
            prefs.getString('il_auth_uid')?.trim() ??
            '';
        if (cachedAuthUid.isNotEmpty && cachedAuthUid != user.uid) {
          await SecureStorageService.instance
              .delete(SecureStorageService.keyHouseId);
          await SecureStorageService.instance
              .delete(SecureStorageService.keyRole);
          await prefs.remove('il_house_id');
          await prefs.remove('il_role');
        }
        await prefs.setString('il_auth_uid', user.uid);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, user.uid);
      }

      if (storedRole == 'user1' || storedRole == 'user2') {
        await prefs.setString('il_role', storedRole);
        await SecureStorageService.instance
            .write(SecureStorageService.keyRole, storedRole);
      }

      if (user != null) {
        try {
          final houseId = await HouseService()
              .getCurrentHouseId(preferFresh: true)
              .timeout(const Duration(seconds: 15));
          if (houseId != null && houseId.isNotEmpty) {
            await prefs.setString('il_house_id', houseId);
            await SecureStorageService.instance
                .write(SecureStorageService.keyHouseId, houseId);
          }
        } catch (e) {
          debugPrint('[Auth][LoginScreen] Error fetching houseId (Social): $e');
        }
      }

      if (!mounted) return;
      _failedAuthAttempts = 0; // Reset on success
      debugPrint(
          '[Auth][LoginScreen] social login success -> navigate AppEntry');
      handedOffToAppEntry = true;
      setState(() => _isLoading = false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppEntry()),
      );
      return;
    } catch (e) {
      _failedAuthAttempts++;
      final resolvedMessage = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('auth_login_unavailable'),
      ).message;
      debugPrint(
          '[Auth][LoginScreen] social login failed ($provider): $resolvedMessage');
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
            backgroundColor: Colors.white,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/default_auth_bg.jpg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  // Note: Removed BackdropFilter(sigma=2) — background is
                  // static so GPU blur is wasteful. Apply blur offline in
                  // the source asset if a blurred look is desired.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 920;
                      final isTablet = constraints.maxWidth >= 680 &&
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
                                10 + MediaQuery.of(context).viewInsets.bottom,
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xFFFFD6E0),
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: SLColors.brandPink
                                                    .withValues(alpha: 0.08),
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
                                                    Color(0xFFFF6B00)
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
                                                l10n.translate('auth_sync_guide'),
                                                style: SLTheme.quicksand(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w900,
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
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  opacity: _isSuccessTransition ? 0.0 : 1.0,
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    scale: _isSuccessTransition ? 1.1 : 1.0,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxWidth: contentMaxWidth),
                                      child: Center(
                                        child: SizedBox(
                                          width: authPanelWidth,
                                          child: AuthPanelShell(
                                            compact: !isDesktop &&
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
                                                    onToggleObscure: () =>
                                                        setState(
                                                      () => _obscurePassword =
                                                          !_obscurePassword,
                                                    ),
                                                    onRememberMeChanged:
                                                        (value) => setState(
                                                      () => _rememberMe =
                                                          value ?? true,
                                                    ),
                                                    onLogin: _handleAuthAction,
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
                                                    acceptTerms: _acceptTerms,
                                                    showSecurityQuestion:
                                                        _showSecurityQuestion,
                                                    selectedSecurityQuestion:
                                                        _selectedSecurityQuestion,
                                                    securityQuestions:
                                                        _cleanSecurityQuestions,
                                                    securityAnswerController:
                                                        _securityAnswerController,
                                                    onToggleObscure: () =>
                                                        setState(
                                                      () => _obscurePassword =
                                                          !_obscurePassword,
                                                    ),
                                                    onAcceptTermsChanged:
                                                        (value) => setState(
                                                      () => _acceptTerms =
                                                          value ?? false,
                                                    ),
                                                    onToggleSecurityQuestion:
                                                        () => setState(
                                                      () => _showSecurityQuestion =
                                                          !_showSecurityQuestion,
                                                    ),
                                                    onSecurityQuestionChanged:
                                                        (value) {
                                                      if (value == null) return;
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
                                            onOpenContact: _showContactDialog,
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
                                : 16),
                        child: Text(
                          'SoulLocket © ${DateTime.now().year} — Tame Trương Việt Hoàng',
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
    Timer? timer;
    showDialog(
      context: context,
      barrierDismissible:
          !enforceDelay, // Prevent dismissing by tapping outside if enforced
      builder: (dialogContext) {
        int countdownMs = enforceDelay ? (kDebugMode ? 500 : 3000) : 0;

        return StatefulBuilder(
          builder: (stateContext, setState) {
            if (enforceDelay && timer == null && countdownMs > 0) {
              timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
                if (!stateContext.mounted) {
                  t.cancel();
                  return;
                }
                if (countdownMs > 100) {
                  setState(() => countdownMs -= 100);
                } else {
                  t.cancel();
                  setState(() => countdownMs = 0);
                }
              });
            }

            final l10n = L10nService();
            return PopScope(
              canPop: !enforceDelay || countdownMs == 0,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFDFE),
                        Color(0xFFFFF2F8),
                        Color(0xFFFCF4FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: const Color(0xFFFF85A2).withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5277).withValues(alpha: 0.20),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7597), Color(0xFFFF5277)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5277)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.sync_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.translate('Hướng dẫn đồng bộ dữ liệu'),
                                  style: SLTheme.quicksand(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: SLColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  l10n.translate('Mô hình ghép đôi tài khoản riêng'),
                                  style: SLTheme.quicksand(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFF5277),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.translate(
                            'SoulLocket sử dụng hệ thống tài khoản riêng biệt để bảo vệ quyền riêng tư 100% cho từng người!'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecond,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSyncStepCard(
                        stepNumber: '1',
                        title: l10n.translate('Tạo 2 tài khoản riêng biệt'),
                        description: l10n.translate(
                            'Mỗi người tự đăng ký tài khoản riêng (Email, Google, Apple) và đăng nhập vào ứng dụng trên máy mình.'),
                        icon: Icons.person_add_alt_1_rounded,
                        accentColor: const Color(0xFFFF5277),
                      ),
                      const SizedBox(height: 10),
                      _buildSyncStepCard(
                        stepNumber: '2',
                        title: l10n.translate('Tạo hoặc nhập Mã ghép đôi'),
                        description: l10n.translate(
                            'Vào Cài đặt ⚙️ → Ghép nối dữ liệu. Một người bấm "Tạo mã ghép nối" và gửi cho người kia nhập vào.'),
                        icon: Icons.qr_code_rounded,
                        accentColor: const Color(0xFF7C4DFF),
                      ),
                      const SizedBox(height: 10),
                      _buildSyncStepCard(
                        stepNumber: '3',
                        title: l10n.translate('Đồng bộ dữ liệu thời gian thực'),
                        description: l10n.translate(
                            'Sau khi kết nối, mọi kỷ niệm, nhật ký, album ảnh và vị trí sẽ tự động đồng bộ tức thì giữa 2 máy!'),
                        icon: Icons.favorite_rounded,
                        accentColor: const Color(0xFF00BFA5),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFFFB74D).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              color: Color(0xFFF57C00),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.translate(
                                    'Mẹo: Dữ liệu được lưu an toàn trên đám mây. Đăng nhập lại trên máy mới dữ liệu tự động tải về đầy đủ.'),
                                style: SLTheme.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE65100),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: SLTheme.authPrimaryButton(
                          label: countdownMs > 0
                              ? '${l10n.translate('Đã hiểu')} (${(countdownMs / 1000).ceil()})'
                              : l10n.translate('Đã hiểu'),
                          onPressed: countdownMs > 0
                              ? null
                              : () {
                                  timer?.cancel();
                                  Navigator.pop(stateContext);
                                },
                          colors: const [
                            Color(0xFFFF5277),
                            Color(0xFFFF7597),
                          ],
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
    ).then((_) {
      timer?.cancel();
    });
  }

  Widget _buildSyncStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              stepNumber,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SLColors.textSecond,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
