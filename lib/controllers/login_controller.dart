import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/anti_spam_service.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/l10n_service.dart';
import '../utils/app_error_mapper.dart';
import '../utils/rapid_action_feedback_policy.dart';
import '../utils/sl_notice.dart';
import '../views/app_entry.dart';
import '../views/auth/qr_login_display_dialog.dart';
import '../views/auth/login/social_auth_action_helper.dart';
import '../core/sl_theme.dart';

class LoginController extends ChangeNotifier {
  static const Duration _authActionTimeout = Duration(seconds: 20);
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

  String _selectedSecurityQuestion =
      L10nService().translate('Ngày sinh của bạn?');
  String get selectedSecurityQuestion => _selectedSecurityQuestion;

  final List<String> securityQuestions = [
    L10nService().translate('Ngày sinh của bạn?'),
    L10nService().translate('Con vật đầu tiên bạn nuôi?'),
    L10nService().translate('Tên giáo viên chủ nhiệm lớp 1?'),
    L10nService().translate('Nơi lần đầu tiên hai bạn gặp nhau?'),
    L10nService().translate('Món ăn yêu thích nhất của bạn?'),
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
    final prefs = await SharedPreferences.getInstance();
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
        const SnackBar(
          content: Text('Thao tác quá nhanh, thử lại sau nhé.'),
          duration: Duration(seconds: 2),
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
          context, L10nService().translate('Vui lòng nhập email và mật khẩu.'));
      return;
    }

    if (!email.contains('@')) {
      SLNotice.showError(context,
          L10nService().translate('Vui lòng nhập đúng định dạng email.'));
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
              ? L10nService().translate('đăng nhập')
              : L10nService().translate('đăng ký'),
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
            L10nService().translate(
                'Vui lòng đồng ý với Điều khoản và Chính sách bảo mật để tiếp tục.'));
        return;
      }
      final strongRegex = RegExp(r"^(?=.*[0-9])(?=.{6,})");
      if (!strongRegex.hasMatch(password)) {
        SLNotice.showError(
            context,
            L10nService()
                .translate('Mật khẩu cần có ít nhất 6 ký tự và 1 số.'));
        return;
      }

      registerRelMode = await ensureRelationshipModeSelected(email);
      if (registerRelMode == null) return;

      final passed = await showMathCaptcha();
      if (!passed) return;
    }

    if (!context.mounted) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (_isLoginTab) {
        SLNotice.showInfo(context,
            L10nService().translate('Đang đăng nhập, bạn chờ một chút nhé.'));
        final isProxy = await SecurityService().isProxyOrVpnActive();
        SecurityService().setProxyAtLogin(isProxy);

        await _authService.signInWithEmailPassword(email, password).timeout(
              _authActionTimeout,
              onTimeout: () =>
                  throw Exception('Đăng nhập quá lâu. Vui lòng thử lại.'),
            );

        final prefs = await SharedPreferences.getInstance().timeout(
          _prefsTimeout,
          onTimeout: () => throw Exception('Lưu trạng thái đăng nhập quá lâu.'),
        );
        if (_rememberMe) {
          await prefs.setString('il_remembered_email', email);
        } else {
          await prefs.remove('il_remembered_email');
        }

        if (!context.mounted) return;
        _showSuccessDialog(
          context,
          L10nService()
              .translate('Đăng nhập thành công. Chào mừng bạn quay lại.'),
          next: const AppEntry(),
        );
      } else {
        SLNotice.showInfo(
            context,
            L10nService()
                .translate('Đang tạo tài khoản, bạn chờ một chút nhé.'));
        final isProxy = await SecurityService().isProxyOrVpnActive();
        SecurityService().setProxyAtLogin(isProxy);

        debugPrint('[Auth][Register] start createUserWithEmailAndPassword');
        await _authService.registerWithEmailPassword(email, password).timeout(
              _authActionTimeout,
              onTimeout: () =>
                  throw Exception('Tạo tài khoản quá lâu. Vui lòng thử lại.'),
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
            }).catchError((error, stackTrace) {
              debugPrint(
                'savePendingRelationshipModeForCurrentUser failed: '
                '$error\n$stackTrace',
              );
            }),
          );
        }

        if (!context.mounted) return;
        debugPrint(
            '[Auth][Register] show success dialog and continue to AppEntry');
        _showSuccessDialog(
          context,
          L10nService().translate(
              'Tạo tài khoản thành công. Tiếp theo, hãy thiết lập ngôi nhà của bạn.'),
          next: const AppEntry(),
        );
      }
    } catch (e) {
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
            'Facebook' => 'Đăng nhập Facebook quá lâu. Vui lòng thử lại.',
            'Apple' => 'Đăng nhập Apple quá lâu. Vui lòng thử lại.',
            _ => 'Đăng nhập Google quá lâu. Vui lòng thử lại.',
          },
        ),
      );
      if (!context.mounted) return;

      if (result == null || result.user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(provider == 'Facebook'
                    ? 'Bạn đã hủy đăng nhập Facebook.'
                    : L10nService().translate(
                        'Bạn đã hủy đăng nhập Google.',
                      ))),
          );
        }
        return;
      }

      if (context.mounted) {
        _showSuccessDialog(
          context,
          provider == 'Facebook'
              ? 'Đăng nhập Facebook thành công.'
              : L10nService().translate('Đăng nhập Google thành công.'),
          next: const AppEntry(),
        );
      }
    } catch (e) {
      if (context.mounted) {
        SLNotice.showError(
          context,
          L10nService()
              .translate('Chưa thể đăng nhập lúc này. Vui lòng thử lại sau.'),
        );
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
                  throw Exception('Xác minh QR quá lâu. Vui lòng thử lại.'),
            );
        if (!context.mounted) return;
        if (email != null && email.isNotEmpty) {
          emailController.text = email;
          if (context.mounted) {
            _showSuccessDialog(
                context,
                L10nService().translate(
                    'Thiết bị khác đã xác nhận danh tính của bạn. Vui lòng nhập mật khẩu để tiếp tục.'));
          }
        } else {
          if (context.mounted) {
            _showSuccessDialog(
                context,
                L10nService().translate(
                    'Thiết bị khác đã xác nhận danh tính của bạn. Vui lòng nhập email đã liên kết với ngôi nhà và mật khẩu để tiếp tục.'));
          }
        }
      } catch (e) {
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
        title: Text(L10nService().translate('Thành công'),
            style: SLTheme.quicksand(color: Colors.green)),
        content: Text(
          L10nService().translate(message),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () {
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
