import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
    final rawPassword = _passwordController.text.trim();
    // Tự động nhận diện chữ hoa thành chữ thường nếu người dùng gõ lộn chữ đầu hoa
    final password = rawPassword.toLowerCase();
    String? sessionRole;
    bool handedOffToAppEntry = false;

    if (email.isEmpty || rawPassword.isEmpty) {
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
      '@live.com',
      '@msn.com',
      '@proton.me',
      '@protonmail.com',
    ];
    final isDomainAllowed = allowedDomains
        .any((domain) => email.endsWith(domain));

    if (!isDomainAllowed) {
      _showErrorDialog(
        L10nService().translate('auth_supported_domains_only'),
      );
      return;
    }

    if (!await _checkAuthRateLimit()) return;

    if (!_isLoginTab) {
      if (!_acceptTerms) {
        _showErrorDialog(L10nService().translate('auth_err_must_agree_terms'));
        return;
      }
      if (password.length < 6) {
        _showErrorDialog('Mật khẩu cần tối thiểu 6 ký tự (chữ thường và số)!');
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
        try {
          await _authService.signInWithEmailPassword(email, rawPassword);
        } catch (e) {
          if (rawPassword != password) {
            try {
              await _authService.signInWithEmailPassword(email, password);
            } catch (_) {
              rethrow;
            }
          } else {
            rethrow;
          }
        }

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
    showDialog<void>(
      context: context,
      barrierDismissible: !enforceDelay,
      barrierColor: const Color(0xFF4A3540).withValues(alpha: 0.28),
      builder: (dialogContext) {
        int countdownMs = enforceDelay ? (kDebugMode ? 500 : 3000) : 0;

        return StatefulBuilder(
          builder: (stateContext, setDialogState) {
            if (enforceDelay && timer == null && countdownMs > 0) {
              timer = Timer.periodic(const Duration(milliseconds: 100), (tick) {
                if (!stateContext.mounted) {
                  tick.cancel();
                  return;
                }
                if (countdownMs > 100) {
                  setDialogState(() => countdownMs -= 100);
                } else {
                  tick.cancel();
                  setDialogState(() => countdownMs = 0);
                }
              });
            }

            final l10n = L10nService();
            return PopScope(
              canPop: !enforceDelay || countdownMs == 0,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    l10n.translate('Kết nối hai thiết bị'),
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
                            child: CustomPaint(
                              painter: _SyncLoveThreadPainter(),
                            ),
                          ),
                        ),
                        Text(
                          l10n.translate('Hai tài khoản, một góc nhỏ chung'),
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
                          l10n.translate(
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
                        _buildSyncStepCard(
                          stepNumber: '1',
                          title: l10n.translate('Mỗi người đăng nhập tài khoản riêng'),
                          description: l10n.translate(
                            'Đăng ký hoặc đăng nhập trên điện thoại của mình bằng Email, Google hoặc Apple.',
                          ),
                          icon: Icons.person_outline_rounded,
                          accentColor: const Color(0xFFE06686),
                        ),
                        _buildSyncStepCard(
                          stepNumber: '2',
                          title: l10n.translate('Ghép đôi bằng một mã kết nối'),
                          description: l10n.translate(
                            'Vào Cài đặt → Ghép nối dữ liệu. Một người tạo mã, người còn lại nhập mã đó để xác nhận.',
                          ),
                          icon: Icons.qr_code_2_rounded,
                          accentColor: const Color(0xFF8771C7),
                        ),
                        _buildSyncStepCard(
                          stepNumber: '3',
                          title: l10n.translate('Cùng cập nhật không gian chung'),
                          description: l10n.translate(
                            'Kỷ niệm, nhật ký, album và dữ liệu đôi sẽ được cập nhật sau khi hai tài khoản đã kết nối.',
                          ),
                          icon: Icons.favorite_outline_rounded,
                          accentColor: const Color(0xFF4F9B90),
                          isLast: true,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  l10n.translate(
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
                          child: _AuroraDialogButton(
                            label: countdownMs > 0
                                ? '${l10n.translate('Đã hiểu')} (${(countdownMs / 1000).ceil()})'
                                : l10n.translate('Đã hiểu'),
                            onPressed: countdownMs > 0
                                ? null
                                : () {
                                    timer?.cancel();
                                    Navigator.pop(stateContext);
                                  },
                          ),
                        ),
                      ],
                    ),
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
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Text(
                      stepNumber,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: accentColor.withValues(alpha: 0.24),
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
                  color: accentColor.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.16),
                  ),
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
                      child: Icon(icon, size: 17, color: accentColor),
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
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Compact Sync Guide Icon Button
                                  Tooltip(
                                    message: L10nService()
                                        .translate('auth_sync_guide'),
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showSyncGuideDialog(context),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.82),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFFD166),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFFB703)
                                                  .withValues(alpha: 0.18),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: ShaderMask(
                                            shaderCallback: (bounds) =>
                                                const LinearGradient(
                                              colors: [
                                                Color(0xFFFFB703),
                                                Color(0xFFFB8500),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ).createShader(bounds),
                                            child: const Icon(
                                              Icons.lightbulb_rounded,
                                              size: 19,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

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
                        color: const Color(0xFF7D6971).withValues(alpha: 0.52),
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

/// Soft paper panel used by the redesigned authentication screen.
class _AuroraGlassPanel extends StatelessWidget {
  final Widget child;

  const _AuroraGlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.96),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C6475).withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 17),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.78),
            blurRadius: 0,
            spreadRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: Stack(
          children: [
            const Positioned(
              top: -28,
              right: -26,
              child: _PanelPaperSeal(),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _PanelPaperSeal extends StatelessWidget {
  const _PanelPaperSeal();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.18,
      child: Container(
        width: 92,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5ED).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF2BFCE).withValues(alpha: 0.66),
          ),
        ),
      ),
    );
  }
}

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
    _pressAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    final disabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _pressCtrl.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _pressCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: disabled ? null : () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: AnimatedOpacity(
          opacity: disabled ? 0.56 : 1,
          duration: const Duration(milliseconds: 140),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE56284),
                  Color(0xFFF0839D),
                  Color(0xFF9276CC),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.46),
              ),
              boxShadow: disabled
                  ? const []
                  : [
                      BoxShadow(
                        color: const Color(0xFFD75A7B).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
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

class _SyncLoveThreadPainter extends CustomPainter {
  const _SyncLoveThreadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final leftCenter = Offset(size.width * 0.27, size.height * 0.53);
    final rightCenter = Offset(size.width * 0.73, size.height * 0.53);

    _drawPhone(canvas, leftCenter, const Color(0xFFFFE7ED), const Color(0xFFD85C7C));
    _drawPhone(canvas, rightCenter, const Color(0xFFEDE7FF), const Color(0xFF7F69BB));

    final thread = Path()
      ..moveTo(leftCenter.dx + 28, leftCenter.dy - 6)
      ..cubicTo(
        size.width * 0.43,
        size.height * 0.24,
        size.width * 0.57,
        size.height * 0.24,
        rightCenter.dx - 28,
        rightCenter.dy - 6,
      );
    final metric = thread.computeMetrics().first;
    final linePaint = Paint()
      ..color = const Color(0xFFE18BA4).withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;

    var distance = 0.0;
    const dash = 6.0;
    const gap = 5.0;
    while (distance < metric.length) {
      canvas.drawPath(
        metric.extractPath(
          distance,
          math.min(distance + dash, metric.length),
        ),
        linePaint,
      );
      distance += dash + gap;
    }

    final heartCenter = Offset(size.width * 0.50, size.height * 0.25);
    final heart = Path()
      ..moveTo(heartCenter.dx, heartCenter.dy + 12)
      ..cubicTo(
        heartCenter.dx - 24,
        heartCenter.dy - 3,
        heartCenter.dx - 13,
        heartCenter.dy - 23,
        heartCenter.dx,
        heartCenter.dy - 8,
      )
      ..cubicTo(
        heartCenter.dx + 13,
        heartCenter.dy - 23,
        heartCenter.dx + 24,
        heartCenter.dy - 3,
        heartCenter.dx,
        heartCenter.dy + 12,
      );
    canvas.drawPath(heart, Paint()..color = const Color(0xFFE76183));

    final sparkle = Paint()
      ..color = const Color(0xFFD7A348)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final p1 = Offset(size.width * 0.42, size.height * 0.16);
    final p2 = Offset(size.width * 0.61, size.height * 0.14);
    for (final point in [p1, p2]) {
      canvas.drawLine(point.translate(-5, 0), point.translate(5, 0), sparkle);
      canvas.drawLine(point.translate(0, -5), point.translate(0, 5), sparkle);
    }
  }

  void _drawPhone(
    Canvas canvas,
    Offset center,
    Color fill,
    Color accent,
  ) {
    final shadow = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 5),
          width: 58,
          height: 82,
        ),
        const Radius.circular(16),
      ),
      shadow,
    );

    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 58, height: 82),
      const Radius.circular(16),
    );
    canvas.drawRRect(phone, Paint()..color = fill);
    canvas.drawRRect(
      phone,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 1),
          width: 42,
          height: 56,
        ),
        const Radius.circular(11),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );

    final tinyHeart = Path()
      ..moveTo(center.dx, center.dy + 7)
      ..cubicTo(
        center.dx - 12,
        center.dy - 1,
        center.dx - 7,
        center.dy - 11,
        center.dx,
        center.dy - 4,
      )
      ..cubicTo(
        center.dx + 7,
        center.dy - 11,
        center.dx + 12,
        center.dy - 1,
        center.dx,
        center.dy + 7,
      );
    canvas.drawPath(tinyHeart, Paint()..color = accent);

    canvas.drawCircle(
      center.translate(0, 34),
      2.2,
      Paint()..color = accent.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
