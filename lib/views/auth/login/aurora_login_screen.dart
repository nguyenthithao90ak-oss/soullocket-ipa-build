import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/core/theme/design_tokens.dart';
import 'package:soullocket_app/utils/services/anti_spam_service.dart';
import 'package:soullocket_app/utils/services/auth_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/security_flow_guard.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/secure_storage_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
import 'package:soullocket_app/widgets/sensitive_content_guard.dart';

import '../dialogs/auth_feedback_dialogs.dart';
import '../dialogs/forgot_gmail_recovery_helper.dart';
import '../dialogs/math_captcha_dialog.dart';
import '../dialogs/support_dialog.dart';
import 'auth_language_toggle.dart';
import 'forgot_password_launcher.dart';
import 'social_auth_action_helper.dart';
import '../../home/screens/document_viewer_screen.dart';
import '../../app_entry.dart';

import 'aurora_hero_background.dart';
import 'aurora_decorative_orbs.dart';
import 'aurora_login_shell.dart';
import 'aurora_login_form.dart';
import 'aurora_register_form.dart';
import '../widgets/gender_selection_dialog.dart';
import '../widgets/relationship_mode_dialog.dart';

/// Aurora Login Screen — Phase 2.1 của SoulLocket UI Redesign.
/// Design: Aurora Soft style với animated gradient, glass panel, floating orbs.
/// NOTE: Migration plan (Phase 3 sẽ thực hiện):
///   - Thêm UiPrefs.uiVersion field = 'v2'
///   - Route '/login' check UiPrefs.uiVersion và route đến đây
///   - Default giữ nguyên 'v1' để không break existing behavior
class AuroraLoginScreen extends StatefulWidget {
  const AuroraLoginScreen({super.key});

  @override
  State<AuroraLoginScreen> createState() => _AuroraLoginScreenState();
}

class _AuroraLoginScreenState extends State<AuroraLoginScreen>
    with TickerProviderStateMixin {
  // ─── Auth state ────────────────────────────────────────────────────
  bool _isLoginTab = false;
  bool _obscurePassword = false;
  bool _isLoading = false;
  bool _isSuccessTransition = false;
  bool _rememberMe = true;
  bool _acceptTerms = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _failedAuthAttempts = 0;

  final AuthService _authService = AuthService();
  final HouseService _houseService = HouseService();
  final AntiSpamRateLimitService _authRateLimiter = AntiSpamRateLimitService();
  final SecurityFlowGuard _securityFlowGuard = SecurityFlowGuard.instance;

  // ─── Animation controllers ───────────────────────────────────────────
  late final AnimationController _successScaleCtrl;
  late final Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();
    _successScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _successScaleCtrl,
        curve: Curves.easeOutBack,
      ),
    );

    _loadRememberedEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKickReason();
      _checkFirstTimeSyncGuide();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _successScaleCtrl.dispose();
    super.dispose();
  }

  // ─── Lifecycle helpers ───────────────────────────────────────────────
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

  void _setAuthTab(bool isLoginTab) {
    if (_isLoginTab == isLoginTab) return;
    setState(() {
      _isLoginTab = isLoginTab;
    });
  }

  // ─── Gender & relationship helpers (từ login_screen.dart) ───────────
  Future<String?> _ensureRelationshipModeSelected(String accountKey) async {
    final normalizedAccountKey = accountKey.trim().toLowerCase();
    if (normalizedAccountKey.isEmpty) return null;

    final cachedMode = await _authService
        .getCachedRelationshipModeForEmail(normalizedAccountKey);
    if (cachedMode != null) return cachedMode;

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

    if (cooldown > 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn thao tác hơi nhanh. Vui lòng chờ một lát rồi thử lại.'),
          duration: Duration(seconds: math.min(cooldown, 5)),
          behavior: SnackBarBehavior.floating,
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
    if (savedGender != null) return savedGender;
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

  Future<bool> _showMathCaptcha() {
    return MathCaptchaDialog.show(context);
  }

  Future<bool> _guardForgotPasswordReset() {
    return _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.forgotPasswordReset,
      onWarnStepUp: _showMathCaptcha,
    );
  }

  // ─── Main auth action ────────────────────────────────────────────────
  Future<void> _handleAuthAction() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    String? sessionRole;
    bool handedOffToAppEntry = false;

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog(L10nService().translate('auth_err_empty_credentials'));
      return;
    }

    if (!email.contains('@')) {
      _showErrorDialog('Vui lòng sử dụng Email hợp lệ!');
      return;
    }

    const allowedDomains = [
      '@gmail.com',
      '@hotmail.com',
      '@outlook.com',
      '@icloud.com',
      '@yahoo.com',
    ];
    final isDomainAllowed = allowedDomains
        .any((domain) => email.toLowerCase().endsWith(domain));

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

    if (!await _checkAuthRateLimit()) return;

    if (!_isLoginTab) {
      if (!_acceptTerms) {
        _showErrorDialog(L10nService().translate('auth_err_must_agree_terms'));
        return;
      }
      final strongRegex = RegExp(r'^(?=.*[0-9])(?=.{6,})');
      if (!strongRegex.hasMatch(password)) {
        _showErrorDialog('Mật khẩu yếu: Cần ít nhất 6 ký tự và 1 số!');
        return;
      }
    }

    // Ask gender
    sessionRole = await _readSavedGender(email);
    if (sessionRole == null && mounted) {
      sessionRole = await _askGender(email);
      if (sessionRole == null) return;
    }

    if (sessionRole != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('il_role', sessionRole);
      await SecureStorageService.instance
          .write(SecureStorageService.keyRole, sessionRole);
    }

    // Captcha check for returning users
    if (_isLoginTab && _failedAuthAttempts >= 2) {
      final passed = await _showMathCaptcha();
      if (!passed) return;
      if (!mounted) return;
    }

    // Security flow guard
    if (_isLoginTab) {
      final canContinue = await _securityFlowGuard.guard(
        context,
        action: SensitiveActionType.loginWithPassword,
        onWarnStepUp: _showMathCaptcha,
      );
      if (!canContinue) return;
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
        await _authService.signInWithEmailPassword(email, password);

        // Remember email
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('il_remembered_email', email);
        } else {
          await prefs.remove('il_remembered_email');
        }

        // Store auth UID
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await prefs.setString('il_auth_uid', user.uid);
          await SecureStorageService.instance
              .write(SecureStorageService.keyAuthUid, user.uid);

          // Fetch house ID
          try {
            final houseId = await _houseService
                .getCurrentHouseId(preferFresh: true)
                .timeout(const Duration(seconds: 15));
            if (houseId != null && houseId.isNotEmpty) {
              await prefs.setString('il_house_id', houseId);
              await SecureStorageService.instance
                  .write(SecureStorageService.keyHouseId, houseId);
            }
          } catch (e) {
            debugPrint('[AuroraLogin] Error fetching houseId: $e');
          }
        }

        _failedAuthAttempts = 0;
        handedOffToAppEntry = true;
        setState(() {
          _isLoading = false;
          _isSuccessTransition = true;
        });
        _successScaleCtrl.forward();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppEntry()),
        );
        return;
      } else {
        // Register mode: ensure relationship mode first
        final relationshipMode = await _ensureRelationshipModeSelected(email);
        if (relationshipMode == null) return;
        if (!mounted) return;

        _rememberProxyStateAtLogin();
        await _authService.registerWithEmailPassword(email, password);
        // Auto-login after register
        _failedAuthAttempts = 0;
        handedOffToAppEntry = true;
        setState(() {
          _isLoading = false;
          _isSuccessTransition = true;
        });
        _successScaleCtrl.forward();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppEntry()),
        );
        return;
      }
    } catch (e) {
      _failedAuthAttempts++;
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

      if (!mounted) return;

      if (isAccountNotFound) {
        await AuthFeedbackDialogs.showAccountNotFoundDialog(
          context,
          message: errorInfo.message,
          onCreateNew: () => _setAuthTab(false),
        );
      } else {
        final showRecovery = !isAccountNotFound &&
            _isLoginTab &&
            (AppErrorMapper.shouldOfferPasswordRecovery(e) ||
                AppErrorMapper.shouldOfferPasswordRecovery(errorInfo.message));
        if (showRecovery) {
          await AuthFeedbackDialogs.showLoginErrorWithRecovery(
            context,
            message: errorInfo.message,
            onRegister: () => _setAuthTab(false),
            onForgotPassword: _handleForgotPasswordAction,
            onForgotGmail: _handleForgotGmailFlow,
          );
        } else {
          _showErrorDialog(errorInfo.message);
        }
      }
    } finally {
      if (mounted && !handedOffToAppEntry) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    AuthFeedbackDialogs.showError(context, message);
  }

  void _handleForgotPasswordAction() {
    unawaited(ForgotPasswordLauncher.launch(context));
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

  // ─── Social login ───────────────────────────────────────────────────
  void _handleSocialLogin(String provider) async {
    if (!SocialAuthActionHelper.isSupportedProvider(provider)) return;

    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SocialAuthActionHelper.sensitiveActionFor(provider),
      onWarnStepUp: _showMathCaptcha,
    );
    if (!canContinue) return;

    final selectedRole = await _askGender();
    if (selectedRole == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('il_role', selectedRole);
    await SecureStorageService.instance
        .write(SecureStorageService.keyRole, selectedRole);

    if (mounted) setState(() => _isLoading = true);

    try {
      final result = switch (provider) {
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

      final user = result.user!;
      final email = (user.email ?? '').trim().toLowerCase();
      await prefs.setString('il_auth_uid', user.uid);
      await SecureStorageService.instance
          .write(SecureStorageService.keyAuthUid, user.uid);

      if (email.isNotEmpty) {
        await prefs.setString('il_saved_gender_$email', selectedRole);
      }

      try {
        final houseId = await _houseService
            .getCurrentHouseId(preferFresh: true)
            .timeout(const Duration(seconds: 15));
        if (houseId != null && houseId.isNotEmpty) {
          await prefs.setString('il_house_id', houseId);
          await SecureStorageService.instance
              .write(SecureStorageService.keyHouseId, houseId);
        }
      } catch (e) {
        debugPrint('[AuroraLogin][Social] Error fetching houseId: $e');
      }

      _failedAuthAttempts = 0;
      setState(() => _isLoading = false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppEntry()),
      );
    } catch (e) {
      _failedAuthAttempts++;
      final resolvedMessage = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('auth_login_unavailable'),
      ).message;
      debugPrint(
          '[AuroraLogin][Social] social login failed ($provider): $resolvedMessage');
      if (!mounted) return;
      _showErrorDialog(
        resolvedMessage.isEmpty
            ? L10nService().translate('auth_login_unavailable')
            : resolvedMessage,
      );
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Document handlers ───────────────────────────────────────────────
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

  void _showContactDialog() {
    unawaited(AuthSupportDialog.show(context));
  }

  // ─── Sync guide dialog ──────────────────────────────────────────────
  void _showSyncGuideDialog(BuildContext context, {bool enforceDelay = false}) {
    Timer? timer;
    showDialog(
      context: context,
      barrierDismissible: !enforceDelay,
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
                                colors: [
                                  Color(0xFFFF7597),
                                  Color(0xFFFF5277)
                                ],
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
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF2F3441),
                                  ),
                                ),
                                Text(
                                  l10n.translate('Mô hình ghép đôi tài khoản riêng'),
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
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
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF667085),
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
                            color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
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
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
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
                        child: _AuroraDialogButton(
                          label: countdownMs > 0
                              ? '${l10n.translate('Đã hiểu')} (${(countdownMs / 1000).ceil()})'
                              : l10n.translate('Đã hiểu'),
                          onPressed: countdownMs > 0 ? null : () {
                            timer?.cancel();
                            Navigator.pop(stateContext);
                          },
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
              style: const TextStyle(
                fontFamily: 'Quicksand',
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
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2F3441),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
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

  // ─── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SensitiveContentGuard(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFFFF5F7),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              // ── Animated aurora background ──────────────────────
              const Positioned.fill(child: AuroraHeroBackground()),

              // ── Decorative floating orbs ──────────────────────
              const Positioned.fill(child: AuroraDecorativeOrbs()),

              // ── Main content ───────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 920;
                  final isTablet = constraints.maxWidth >= 680 &&
                      constraints.maxWidth < 920;
                  final isCompact = constraints.maxWidth < 450;

                  // Responsive padding
                  double horizontalPadding;
                  if (constraints.maxWidth >= 920) {
                    horizontalPadding = 32;
                  } else if (constraints.maxWidth >= 680) {
                    horizontalPadding = 24;
                  } else if (constraints.maxWidth >= 450) {
                    horizontalPadding = 18;
                  } else {
                    horizontalPadding = 10;
                  }

                  final authPanelWidth = isDesktop
                      ? 408.0
                      : math.min(
                          520.0,
                          constraints.maxWidth -
                              (isCompact ? 20 : 32),
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
                          // ── Top bar: sync guide hint + language toggle ──
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
                                  // Sync guide chip
                                  GestureDetector(
                                    onTap: () =>
                                        _showSyncGuideDialog(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFFFD6E0),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: SLAuroraPalette.roseDeep
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
                                            L10nService()
                                                .translate('auth_sync_guide'),
                                            style: TextStyle(
                                              fontFamily: 'Quicksand',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: SLAuroraPalette.roseDeep,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Language toggle
                                  ListenableBuilder(
                                    listenable: L10nService(),
                                    builder: (context, _) {
                                      return AuthLanguageToggle(
                                        currentLocale:
                                            L10nService().localeCode,
                                        onSelect: (code) {
                                          L10nService().setLocale(code);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── Auth panel ───────────────────────────
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            opacity: _isSuccessTransition ? 0.0 : 1.0,
                            child: ScaleTransition(
                              scale: _successScaleAnim,
                              child: SizedBox(
                                width: authPanelWidth,
                                child: _AuroraGlassPanel(
                                  child: AuroraLoginShell(
                                    compact: !isDesktop &&
                                        (isCompact || isTablet),
                                    isLoginTab: _isLoginTab,
                                    onSelectLogin: () => _setAuthTab(true),
                                    onSelectRegister: () => _setAuthTab(false),
                                    authSection: _isLoginTab
                                        ? AuroraLoginForm(
                                            emailController: _emailController,
                                            passwordController:
                                                _passwordController,
                                            obscurePassword: _obscurePassword,
                                            isLoading: _isLoading,
                                            rememberMe: _rememberMe,
                                            onToggleObscure: () => setState(
                                              () =>
                                                  _obscurePassword =
                                                      !_obscurePassword,
                                            ),
                                            onRememberMeChanged: (value) =>
                                                setState(
                                              () => _rememberMe = value ?? true,
                                            ),
                                            onLogin: _handleAuthAction,
                                            onForgotPassword:
                                                _handleForgotPasswordAction,
                                            onSocialLogin: _handleSocialLogin,
                                          )
                                        : AuroraRegisterForm(
                                            emailController: _emailController,
                                            passwordController:
                                                _passwordController,
                                            obscurePassword: _obscurePassword,
                                            isLoading: _isLoading,
                                            acceptTerms: _acceptTerms,
                                            onToggleObscure: () => setState(
                                              () =>
                                                  _obscurePassword =
                                                      !_obscurePassword,
                                            ),
                                            onAcceptTermsChanged: (value) =>
                                                setState(
                                              () => _acceptTerms =
                                                  value ?? false,
                                            ),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Copyright watermark ───────────────────────────
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
                      style: TextStyle(
                        fontFamily: 'Quicksand',
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
  }
}

/// Glass panel wrapper cho aurora login shell.
class _AuroraGlassPanel extends StatelessWidget {
  final Widget child;

  const _AuroraGlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B9D).withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Aurora-styled dialog button cho sync guide.
class _AuroraDialogButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _AuroraDialogButton({
    required this.label,
    this.onPressed,
  });

  @override
  State<_AuroraDialogButton> createState() => _AuroraDialogButtonState();
}

class _AuroraDialogButtonState extends State<_AuroraDialogButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _pressCtrl.forward(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _pressCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: Opacity(
          opacity: isDisabled ? 0.65 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: isDisabled
                  ? const LinearGradient(
                      colors: [Color(0xFFFFB6C1), Color(0xFFFFC0CB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFF5277), Color(0xFFFF7597)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFFF5277).withValues(alpha: 0.38),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
