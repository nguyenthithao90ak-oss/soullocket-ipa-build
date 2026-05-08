import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sl_theme.dart';
import '../../services/auth_service.dart';
import 'widgets/admin_shared_widgets.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationMinutes = 15;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập email và mật khẩu admin.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt('admin_failed_login_attempts') ?? 0;
    final lockoutUntil = prefs.getInt('admin_lockout_until') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < lockoutUntil) {
      final remainingMinutes = ((lockoutUntil - now) / 1000 / 60).ceil();
      setState(() => _errorText =
          'Tài khoản bị khóa tạm thời. Vui lòng thử lại sau $remainingMinutes phút.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Future.delayed(
          const Duration(milliseconds: 500)); // Tránh brute force quá nhanh
      await _authService.signInWithEmailPassword(email, password);
      final hasAccess =
          await _authService.isCurrentUserAdmin(forceRefresh: true);
      if (!hasAccess) {
        await _authService.signOut();
        throw 'Tài khoản này chưa có quyền admin.';
      }

      // Đăng nhập thành công -> reset bộ đếm
      await prefs.setInt('admin_failed_login_attempts', 0);
      await prefs.setInt('admin_lockout_until', 0);
    } catch (error) {
      if (!mounted) return;

      final newFailedAttempts = failedAttempts + 1;
      await prefs.setInt('admin_failed_login_attempts', newFailedAttempts);

      if (newFailedAttempts >= maxFailedAttempts) {
        final lockoutTime = now + (lockoutDurationMinutes * 60 * 1000);
        await prefs.setInt('admin_lockout_until', lockoutTime);
        setState(() {
          _errorText =
              'Bạn đã nhập sai quá $maxFailedAttempts lần. Tài khoản bị khóa tạm thời trong $lockoutDurationMinutes phút.';
        });
      } else {
        debugPrint('Admin login failed: $error');
        setState(() {
          _errorText =
              '${_adminLoginErrorText(error)}\n(Sai $newFailedAttempts/$maxFailedAttempts lần)';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _adminLoginErrorText(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Email admin chưa đúng định dạng.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email hoặc mật khẩu admin chưa đúng.';
        case 'user-disabled':
          return 'Tài khoản admin này đã bị vô hiệu hóa.';
        case 'too-many-requests':
          return 'Bạn thử đăng nhập quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.';
        case 'network-request-failed':
          return 'Kết nối mạng chưa ổn định. Vui lòng thử lại.';
      }
    }
    final message = error.toString();
    if (message.contains('chưa có quyền admin')) {
      return 'Tài khoản này chưa có quyền admin.';
    }
    return 'Chưa thể đăng nhập admin lúc này. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: SLSpacing.all24,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 920;
                return Flex(
                  direction: isCompact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: isCompact ? 0 : 6,
                      child: AdminGlassCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            sectionTag('SoulLocket Admin'),
                            SLSpacing.h16,
                            Text(
                              'Web admin dark cho đăng nhập và dashboard tổng quan',
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            SLSpacing.h16,
                            Text(
                              'Giai đoạn 1 tập trung vào xác thực admin bằng Firebase Auth và màn hình tổng quan dữ liệu hệ thống.',
                              style: SLTheme.quicksand(
                                color: const Color(0xFFB7C1D6),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.6,
                              ),
                            ),
                            SLSpacing.h24,
                            const Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                HighlightChip(
                                  icon: Icons.security_rounded,
                                  label: 'Kiểm tra custom claim admin',
                                ),
                                HighlightChip(
                                  icon: Icons.dashboard_rounded,
                                  label: 'Dashboard overview realtime',
                                ),
                                HighlightChip(
                                  icon: Icons.dark_mode_rounded,
                                  label: 'Dark UI Flutter Web',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                        width: isCompact ? 0 : 24, height: isCompact ? 24 : 0),
                    Expanded(
                      flex: isCompact ? 0 : 5,
                      child: AdminGlassCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đăng nhập admin',
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SLSpacing.h8,
                            Text(
                              'Dùng tài khoản đã được gán custom claim admin.',
                              style: SLTheme.quicksand(
                                color: const Color(0xFF9AA8C4),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SLSpacing.h24,
                            AdminTextField(
                              controller: _emailController,
                              label: 'Email admin',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.mail_outline_rounded,
                            ),
                            SLSpacing.h16,
                            AdminTextField(
                              controller: _passwordController,
                              label: 'Mật khẩu',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.lock_outline_rounded,
                              onSubmitted: (_) =>
                                  _isLoading ? null : _handleLogin(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF9AA8C4),
                                ),
                              ),
                            ),
                            if (_errorText != null) ...[
                              SLSpacing.h16,
                              Container(
                                width: double.infinity,
                                padding: SLSpacing.all12,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFF4D6D).withValues(alpha: 0.14),
                                  borderRadius: SLRadius.lgAll,
                                  border: Border.all(
                                    color: const Color(0xFFFF4D6D)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  _errorText!,
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFFFFB6C5),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            SLSpacing.h24,
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4B91),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: SLRadius.lgAll,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Vào dashboard',
                                        style: SLTheme.quicksand(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
