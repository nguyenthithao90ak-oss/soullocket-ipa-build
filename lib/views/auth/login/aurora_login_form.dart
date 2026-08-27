import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'aurora_form_widgets.dart';
import 'aurora_social_buttons.dart';

final RegExp _loginEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Aurora-styled login form section.
/// Giữ nguyên logic validation từ login_form_section.dart cũ.
class AuroraLoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final bool rememberMe;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final Function(String) onSocialLogin;

  const AuroraLoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onSocialLogin,
  });

  bool _isLoginInputValid(String email, String password) {
    return _loginEmailRegex.hasMatch(email.trim()) && password.trim().length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final emailLabel = l10n.translate('email');
    final passwordLabel = l10n.translate('password');
    final rememberMeLabel = l10n.translate('remember_me');
    final loginLabel = l10n.translate('login').toUpperCase();
    final forgotPasswordLabel = l10n.translate('forgot_password');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('aurora_login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email input
          _AuroraSectionLabel(label: emailLabel),
          const SizedBox(height: 8),
          AuroraTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            hintText: emailLabel,
            prefixIcon: const Icon(
              Icons.mail_outline_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
          ),

          const SizedBox(height: 14),

          // Password input
          _AuroraSectionLabel(label: passwordLabel),
          const SizedBox(height: 8),
          AuroraTextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
            isPassword: true,
            onSubmitted: (_) {
              if (!isLoading &&
                  _isLoginInputValid(
                    emailController.text,
                    passwordController.text,
                  )) {
                onLogin();
              }
            },
            hintText: passwordLabel,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: SLTheme.authMutedTextColor,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ),

          const SizedBox(height: 12),

          // Remember me toggle
          GestureDetector(
            onTap: () => onRememberMeChanged(!rememberMe),
            child: _AuroraToggleCard(
              selected: rememberMe,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: rememberMe,
                        activeColor: const Color(0xFFFF5E7E),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        onChanged: onRememberMeChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rememberMeLabel,
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 12,
                          color: const Color(0xFF667085)
                              .withValues(alpha: 0.92),
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Login button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: emailController,
            builder: (context, emailValue, _) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: passwordController,
                builder: (context, passwordValue, _) {
                  final isInputValid = _isLoginInputValid(
                    emailValue.text,
                    passwordValue.text,
                  );

                  return AuroraPrimaryButton(
                    label: loginLabel,
                    onPressed: isLoading
                        ? null
                        : () {
                            if (!isInputValid) {
                              final email = emailValue.text.trim();
                              final password = passwordValue.text;
                              if (email.isEmpty) {
                                _showAuroraError(context, 'Vui lòng nhập Email.');
                              } else if (!_loginEmailRegex.hasMatch(email)) {
                                _showAuroraError(
                                    context, 'Email không hợp lệ.');
                              } else if (password.isEmpty) {
                                _showAuroraError(
                                    context, 'Vui lòng nhập Mật khẩu.');
                              } else if (password.length < 6) {
                                _showAuroraError(context,
                                    'Mật khẩu phải từ 6 ký tự trở lên.');
                              } else {
                                _showAuroraError(context,
                                    'Thông tin đăng nhập chưa hợp lệ.');
                              }
                              return;
                            }
                            onLogin();
                          },
                    isLoading: isLoading,
                    enabled: true,
                  );
                },
              );
            },
          ),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF5E7E),
                padding:
                    const EdgeInsets.only(top: 2, bottom: 4, right: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                forgotPasswordLabel,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5E7E),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          // Social auth divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                '✨ ${l10n.translate('HOẶC ĐĂNG KÝ NHANH')} ✨',
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Social auth buttons
          AuroraSocialButtons(onProviderTap: onSocialLogin),

          const SizedBox(height: 12),

          // Encryption note
          Center(
            child: Text(
              l10n.translate('auth_encrypted_note'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFBBBBBB),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Center(
            child: Text(
              l10n.translate(
                'Đăng nhập/Đăng ký qua Google hoặc Apple nữa\nBạn xác nhận rằng bạn 13 tuổi và chấp nhận các điều kiện.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                color: Color(0xFF999999),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuroraError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _AuroraSectionLabel extends StatelessWidget {
  final String label;

  const _AuroraSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Quicksand',
        fontSize: 13.5,
        color: Color(0xFF2F3441),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _AuroraToggleCard extends StatelessWidget {
  final Widget child;
  final bool selected;

  const _AuroraToggleCard({
    required this.child,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFFF1F2).withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? const Color(0xFFFF5E7E).withValues(alpha: 0.5)
              : const Color(0xFFF0E5DF),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}
