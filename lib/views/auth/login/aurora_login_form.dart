import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'aurora_form_widgets.dart';
import 'auth_visual_style.dart';
import 'auth_form_details.dart';
import 'aurora_social_buttons.dart';

final RegExp _loginEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

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
    return _loginEmailRegex.hasMatch(email.trim()) &&
        password.trim().length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final emailLabel = l10n.translate('email');
    final passwordLabel = l10n.translate('password');
    final loginLabel = l10n.translate('login');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('aurora_login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthSectionLabel(label: emailLabel),
          const SizedBox(height: 7),
          AuroraTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            hintText: l10n.translate('auth_email_placeholder'),
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 13),
          AuthSectionLabel(label: passwordLabel),
          const SizedBox(height: 7),
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
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: obscurePassword
                  ? l10n.translate('Hiện mật khẩu')
                  : l10n.translate('Ẩn mật khẩu'),
              onPressed: onToggleObscure,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 20,
                color: AuthVisualStyle.of(context).muted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AuthRememberRow(
            selected: rememberMe,
            onChanged: onRememberMeChanged,
            onForgotPassword: isLoading ? null : onForgotPassword,
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: emailController,
            builder: (context, emailValue, _) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: passwordController,
                builder: (context, passwordValue, _) {
                  final valid = _isLoginInputValid(
                    emailValue.text,
                    passwordValue.text,
                  );
                  return AuroraPrimaryButton(
                    label: loginLabel,
                    onPressed: isLoading
                        ? null
                        : () {
                            if (!valid) {
                              final email = emailValue.text.trim();
                              final password = passwordValue.text;
                              if (email.isEmpty) {
                                _showError(
                                  context,
                                  l10n.translate('Vui lòng nhập Email.'),
                                );
                              } else if (!_loginEmailRegex.hasMatch(email)) {
                                _showError(
                                  context,
                                  l10n.translate('Email không hợp lệ.'),
                                );
                              } else if (password.isEmpty) {
                                _showError(
                                  context,
                                  l10n.translate('Vui lòng nhập Mật khẩu.'),
                                );
                              } else if (password.length < 6) {
                                _showError(
                                  context,
                                  l10n.translate(
                                    'Mật khẩu phải từ 6 ký tự trở lên.',
                                  ),
                                );
                              } else {
                                _showError(
                                  context,
                                  l10n.translate(
                                    'Thông tin đăng nhập chưa hợp lệ.',
                                  ),
                                );
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
          const SizedBox(height: 15),
          AuthSocialDivider(label: l10n.translate('Hoặc tiếp tục với')),
          const SizedBox(height: 13),
          AuroraSocialButtons(onProviderTap: onSocialLogin),
          const SizedBox(height: 12),
          AuthPrivacyNote(text: l10n.translate('auth_encrypted_note')),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFC74F6C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
