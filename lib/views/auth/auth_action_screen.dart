import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/sl_notice.dart';
import '../login_screen.dart';

class AuthActionScreen extends StatefulWidget {
  final Uri initialUri;

  const AuthActionScreen({
    super.key,
    required this.initialUri,
  });

  @override
  State<AuthActionScreen> createState() => _AuthActionScreenState();
}

class _AuthActionScreenState extends State<AuthActionScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _isBusy = true;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  bool _canSubmitPassword = false;
  bool _hidePassword = false;
  bool _hideConfirm = false;
  String _title = 'Đang kiểm tra liên kết';
  String _message = 'Vui lòng chờ trong giây lát.';
  String? _oobCode;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final mode = _resolveMode(widget.initialUri);
    final oobCode = widget.initialUri.queryParameters['oobCode']?.trim();
    _oobCode = oobCode;

    if (mode == 'resetPassword') {
      await _handleResetPassword(oobCode);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _isSuccess = false;
      _title = 'Liên kết không hợp lệ';
      _message = 'App không nhận ra thao tác từ liên kết này.';
    });
  }

  String _resolveMode(Uri uri) {
    final rawMode = uri.queryParameters['mode']?.trim();
    if (rawMode != null && rawMode.isNotEmpty) {
      return rawMode;
    }
    if (uri.path == '/reset-password-complete') {
      return 'resetPassword';
    }
    return '';
  }

  Future<void> _handleResetPassword(String? oobCode) async {
    if (oobCode == null || oobCode.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isSuccess = false;
        _title = 'Link không hợp lệ';
        _message = 'Liên kết đặt lại mật khẩu đang thiếu mã xác thực.';
      });
      return;
    }

    try {
      final email = await _authService.verifyPasswordResetCode(oobCode);
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isSuccess = false;
        _canSubmitPassword = true;
        _title = 'Đặt lại mật khẩu';
        _message =
            'Liên kết hợp lệ cho ${email.trim()}. Hãy nhập mật khẩu mới để hoàn tất.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isSuccess = false;
        _title = 'Không thể đặt lại mật khẩu';
        _message = _mapResetPasswordError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isSuccess = false;
        _title = 'Không thể đặt lại mật khẩu';
        _message =
            'Liên kết đặt lại mật khẩu chưa thể dùng lúc này. Vui lòng thử lại sau.';
      });
    }
  }

  String _mapResetPasswordError(FirebaseAuthException error) {
    switch (error.code) {
      case 'expired-action-code':
        return 'Liên kết đặt lại mật khẩu đã hết hạn. Bạn hãy yêu cầu liên kết mới nhé.';
      case 'invalid-action-code':
        return 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã được dùng rồi.';
      case 'user-disabled':
        return 'Tài khoản này đang bị vô hiệu hóa nên chưa thể đổi mật khẩu.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản cho liên kết đặt lại mật khẩu này.';
      case 'weak-password':
        return 'Mật khẩu mới chưa đủ mạnh. Bạn thử mật khẩu dài hơn nhé.';
      default:
        return error.message ??
            'Chưa thể đặt lại mật khẩu lúc này. Vui lòng thử lại sau.';
    }
  }

  Future<void> _submitPasswordReset() async {
    final code = _oobCode;
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (code == null || code.isEmpty) {
      _showSnack('Liên kết đặt lại mật khẩu không còn hợp lệ.');
      return;
    }
    if (password.length < 6) {
      _showSnack('Mật khẩu mới phải có ít nhất 6 ký tự.');
      return;
    }
    if (password != confirm) {
      _showSnack('Mật khẩu nhập lại chưa khớp.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.confirmPasswordReset(
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      setState(() {
        _canSubmitPassword = false;
        _isSuccess = true;
        _title = 'Đặt lại thành công';
        _message =
            'Mật khẩu mới đã được cập nhật. Bây giờ bạn có thể quay lại màn hình đăng nhập.';
      });
    } on FirebaseAuthException catch (error) {
      _showSnack(_mapResetPasswordError(error));
    } catch (_) {
      _showSnack(
          'Chưa thể cập nhật mật khẩu mới lúc này. Vui lòng thử lại sau.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    SLNotice.showError(context, message);
  }

  void _openLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: (_isSuccess
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFBCFE8))
                        .withOpacity(0.9),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _isBusy
                            ? Icons.hourglass_top_rounded
                            : _isSuccess
                                ? Icons.verified_rounded
                                : Icons.lock_reset_rounded,
                        size: 56,
                        color: _isSuccess
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD81B60),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                      if (_isBusy) ...[
                        const SizedBox(height: 24),
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD81B60),
                          ),
                        ),
                      ],
                      if (_canSubmitPassword) ...[
                        const SizedBox(height: 24),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _hidePassword,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu mới',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _hidePassword = !_hidePassword);
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: _hideConfirm,
                          enabled: !_isSubmitting,
                          onSubmitted: (_) => _submitPasswordReset(),
                          decoration: InputDecoration(
                            labelText: 'Nhập lại mật khẩu mới',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _hideConfirm = !_hideConfirm);
                              },
                              icon: Icon(
                                _hideConfirm
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed:
                              _isSubmitting ? null : _submitPasswordReset,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD81B60),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Cập nhật mật khẩu'),
                        ),
                      ],
                      if (!_isBusy && !_canSubmitPassword) ...[
                        const SizedBox(height: 22),
                        OutlinedButton(
                          onPressed: _openLogin,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                              _isSuccess ? 'Mở đăng nhập' : 'Về đăng nhập'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
