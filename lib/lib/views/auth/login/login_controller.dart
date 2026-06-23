import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../utils/services/anti_spam_service.dart';
import '../../../utils/services/auth_service.dart';
import '../../../utils/services/security_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/rapid_action_feedback_policy.dart';
import '../../../utils/sl_notice.dart';
import '../../app_entry.dart';
import '../qr_login_display_dialog.dart';
import 'social_auth_action_helper.dart';
import '../../../core/sl_theme.dart';

class LoginController extends ChangeNotifier {
  static const Duration _authActionTimeout = Duration(seconds: 12);
  static const Duration _prefsTimeout = Duration(seconds: 5);

  bool _isLoginTab = true;
  bool get isLoginTab => _isLoginTab;

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _rememberMe = true;
  bool get rememberMe => _rememberMe;

  bool _acceptTerms = false;
  bool get acceptTerms => _acceptTerms;

  bool _showSecurityQuestion = false;
  bool get showSecurityQuestion => _showSecurityQuestion;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController securityAnswerController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final AntiSpamRateLimitService _authRateLimiter = AntiSpamRateLimitService();

  String? _draftRelationshipMode;
  String? get draftRelationshipMode => _draftRelationshipMode;

  int _failedAuthAttempts = 0;

  String _selectedSecurityQuestion =
      L10nService().translate('auth_security_q_dob');
  String get selectedSecurityQuestion => _selectedSecurityQuestion;

  final List<String> securityQuestions = [
    L10nService().translate('auth_security_q_dob'),
    L10nService().translate('auth_security_q_first_pet'),
    L10nService().translate('auth_security_q_first_teacher'),
    L10nService().translate('auth_security_q_first_meet'),
    L10nService().translate('auth_security_q_favorite_food'),
  ];

  LoginController() {
    emailController.addListener(_handleEmailDraftChanged);
    _loadRememberedEmail();
    _hydrateDraftRelationshipMode();
  }

  @override
  void dispose() {
    emailController.removeListener(_handleEmailDraftChanged);
    emailController.dispose();
    passwordController.dispose();
    securityAnswerController.dispose();
    super.dispose();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void setAcceptTerms(bool value) {
    _acceptTerms = value;
    notifyListeners();
  }

  void toggleSecurityQuestion() {
    _showSecurityQuestion = !_showSecurityQuestion;
    notifyListeners();
  }

  void setSelectedSecurityQuestion(String value) {
    _selectedSecurityQuestion = value;
    notifyListeners();
  }

  void setAuthTab(bool isLogin) {
    if (_isLoginTab == isLogin) return;
    _isLoginTab = isLogin;
    if (isLogin) {
      _draftRelationshipMode = null;
    }
    notifyListeners();
    if (!isLogin) {
      _hydrateDraftRelationshipMode();
    }
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await OfflineCacheService.getPrefs();
    final savedEmail = prefs.getString('il_remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
      _rememberMe = true;
      notifyListeners();
    }
  }

  void _handleEmailDraftChanged() {
    if (!_isLoginTab) {
      _hydrateDraftRelationshipMode();
    }
  }

  Future<void> _hydrateDraftRelationshipMode() async {
    final draftEmail = emailController.text.trim();
    final mode =
        await _authService.getCachedRelationshipModeForEmail(draftEmail);
    if (_isLoginTab) return;
    if (draftEmail != emailController.text.trim()) return;
    if (mode != _draftRelationshipMode) {
      _draftRelationshipMode = mode;
      notifyListeners();
    }
  }

  Future<bool> checkAuthRateLimit(BuildContext context) async {
    final allowed = await _authRateLimiter.checkRateLimit(
      action: _isLoginTab ? 'auth_login' : 'auth_register',
      maxCalls: 3,
      timeWindowMs: 5000,
    );
    if (allowed) return true;

    final cooldown = await _authRateLimiter.remainingCooldownSeconds;
    if (!context.mounted) return false;
    if (context.mounted && shouldShowRapidActionWarningSeconds(cooldown)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10nService().translate('auth_rate_limit_wait')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  Future<void> handleAuthAction(
    BuildContext context,
    Future<String?> Function(String) ensureRelationshipModeSelected,
    Future<bool> Function() showMathCaptcha,
    Function(String) showLoginErrorWithRecovery,
  ) async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    String? registerRelMode;

    if (email.isEmpty || password.isEmpty) {
      SLNotice.showError(
          context, L10nService().translate('auth_enter_email_password'));
      return;
    }

    if (!email.contains('@')) {
      SLNotice.showError(context,
          L10nService().translate('auth_invalid_email_format'));
      return;
    }

    final eLower = email.toLowerCase();
    final allowedDomains = [
      '@gmail.com',
      '@hotmail.com',
      '@outlook.com',
      '@icloud.com',
      '@yahoo.com'
    ];

    final isDomainAllowed =
        allowedDomains.any((domain) => eLower.endsWith(domain));

    if (!isDomainAllowed) {
      SLNotice.showError(
        context,
        L10nService().format('auth_supported_domains_only', {
          'action': _isLoginTab
              ? L10nService().translate('auth_action_login')
              : L10nService().translate('auth_action_register'),
          'domains': allowedDomains.join(', '),
        }),
      );
      return;
    }

    if (!await checkAuthRateLimit(context)) {
      return;
    }
    if (!context.mounted) return;

    if (!_isLoginTab) {
      if (!_acceptTerms) {
        SLNotice.showError(
            context,
            L10nService().translate('auth_accept_terms_required'));
        return;
      }
      final strongRegex = RegExp(r'^(?=.*[0-9])(?=.{6,})');
      if (!strongRegex.hasMatch(password)) {
        SLNotice.showError(
            context,
            L10nService().translate('auth_password_rule'));
        return;
      }

      registerRelMode = await ensureRelationshipModeSelected(email);
      if (registerRelMode == null) return;
    }

    final isProxy = await SecurityService().isProxyOrVpnActive();
    
    if (_failedAuthAttempts >= 2) {
      final passed = await showMathCaptcha();
      if (!passed) return;
    }

    if (!context.mounted) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (_isLoginTab) {
        SLNotice.showInfo(context,
            L10nService().translate('auth_logging_in'));
        SecurityService().setProxyAtLogin(isProxy);

        await _authService.signInWithEmailPassword(email, password).timeout(
              _authActionTimeout,
              onTimeout: () =>
                  throw Exception(L10nService().translate('auth_login_timeout')),
            );

        final prefs = await SharedPreferences.getInstance().timeout(
          _prefsTimeout,
          onTimeout: () => throw Exception(L10nService().translate('auth_save_login_state_timeout')),
        );
        if (_rememberMe) {
          await prefs.setString('il_remembered_email', email);
        } else {
          await prefs.remove('il_remembered_email');
        }

        if (!context.mounted) return;
        _showSuccessDialog(
          context,
          L10nService().translate('auth_login_success'),
          next: const AppEntry(),
        );
      } else {
        SLNotice.showInfo(
            context,
            L10nService().translate('auth_creating_account'));
        SecurityService().setProxyAtLogin(isProxy);

        debugPrint('[Auth][Register] start createUserWithEmailAndPassword');
        await _authService.registerWithEmailPassword(email, password).timeout(
              _authActionTimeout,
              onTimeout: () =>
                  throw Exception(L10nService().translate('auth_register_timeout')),
            );
        debugPrint('[Auth][Register] account created successfully');

        if (registerRelMode != null) {
          debugPrint('[Auth][Register] queue save pending relationship mode');
          unawaited(
            _authService
                .savePendingRelationshipModeForCurrentUser(registerRelMode)
                .timeout(
                  _prefsTimeout,
                  onTimeout: () {},
                )
                .then((_) {
              debugPrint(
                '[Auth][Register] pending relationship mode saved',
              );
            }).catchError((error) {
              debugPrint(
                'savePendingRelationshipModeForCurrentUser failed: ${AppErrorMapper.resolve(
                  error,
                  fallbackMessage: L10nService().translate('auth_save_pending_relationship_mode_failed'),
                ).message}',
              );
            }),
          );
        }

        if (!context.mounted) return;
        debugPrint(
            '[Auth][Register] show success dialog and continue to AppEntry');
        _showSuccessDialog(
          context,
          L10nService().translate('auth_register_success_setup_house'),
          next: const AppEntry(),
        );
      }
    } catch (e) {
      _failedAuthAttempts++;
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: _isLoginTab
            ? L10nService().translate('auth_login_unavailable')
            : L10nService().translate('auth_signup_unavailable'),
      );
      final showRecovery =
          _isLoginTab && AppErrorMapper.shouldOfferPasswordRecovery(e);

      if (showRecovery) {
        showLoginErrorWithRecovery(errorInfo.message);
      } else {
        SLNotice.showError(context, errorInfo.message);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleSocialLogin(BuildContext context, String provider) async {
    if (!SocialAuthActionHelper.isSupportedProvider(provider)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await (switch (provider) {
        'Facebook' => _authService.signInWithFacebook(),
        'Apple' => _authService.signInWithApple(),
        _ => _authService.signInWithGoogle(),
      })
          .timeout(
        _authActionTimeout,
        onTimeout: () => throw Exception(
          switch (provider) {
            'Facebook' => L10nService().translate('auth_facebook_login_timeout'),
            'Apple' => L10nService().translate('auth_apple_login_timeout'),
            _ => L10nService().translate('auth_google_login_timeout'),
          },
        ),
      );
      if (!context.mounted) return;

      if (result == null || result.user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(provider == 'Facebook'
                    ? L10nService().translate('auth_facebook_login_cancelled')
                    : L10nService().translate('auth_google_login_cancelled'))),
          );
        }
        return;
      }

      _failedAuthAttempts = 0; // Reset on success

      if (context.mounted) {
        _showSuccessDialog(
          context,
          provider == 'Facebook'
              ? L10nService().translate('auth_facebook_login_success')
              : L10nService().translate('auth_google_login_success'),
          next: const AppEntry(),
        );
      }
    } catch (e) {
      _failedAuthAttempts++;
      if (context.mounted) {
        final message = AppErrorMapper.resolve(
          e,
          fallbackMessage: L10nService().translate('auth_login_unavailable'),
        ).message;
        SLNotice.showError(context, message);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleQRLogin(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const QRLoginDisplayDialog(),
    );
    if (!context.mounted) return;

    final houseId = result?['houseId']?.trim() ?? '';
    if (houseId.isNotEmpty) {
      _isLoading = true;
      notifyListeners();
      try {
        final email = await _authService.findEmailByHouseId(houseId).timeout(
              _authActionTimeout,
              onTimeout: () =>
                  throw Exception(L10nService().translate('auth_qr_verify_timeout')),
            );
        if (!context.mounted) return;
        if (email != null && email.isNotEmpty) {
          emailController.text = email;
          if (context.mounted) {
            _showSuccessDialog(
                context,
                L10nService().translate('auth_qr_identity_confirmed_enter_password'));
          }
        } else {
          if (context.mounted) {
            _showSuccessDialog(
                context,
                L10nService().translate('auth_qr_identity_confirmed_enter_email_password'));
          }
        }
      } catch (e) {
        _failedAuthAttempts++;
        if (context.mounted) {
          SLNotice.showError(
            context,
            L10nService().translate('auth_qr_login_error'),
          );
        }
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String message,
      {Widget? next}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(L10nService().translate('core_success'),
            style: SLTheme.quicksand(color: Colors.green)),
        content: Text(
          L10nService().translate(message),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _failedAuthAttempts = 0; // Reset on success
              Navigator.of(ctx).pop();
              if (next != null && context.mounted) {
                Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => next));
              }
            },
            child: Text('OK', style: SLTheme.quicksand()),
          )
        ],
      ),
    );
  }
}
