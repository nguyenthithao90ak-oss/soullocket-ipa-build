import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import '../../../utils/sl_notice.dart';
import 'aurora_form_widgets.dart';
import 'auth_visual_style.dart';
import 'auth_form_details.dart';
import 'glass_text_field.dart';
import 'social_auth_buttons.dart';

final RegExp _loginEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool _isLoginInputValid(String email, String password) {
  return _loginEmailRegex.hasMatch(email.trim()) && password.trim().length >= 6;
}

/// Legacy login logic with the new Locket Garden presentation.
/// Validation/callback semantics intentionally remain the same as the old form.
class LoginForm extends StatelessWidget {
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
  final Color accentRose;
  final Color accentBlush;
  final Color accentLavender;

  const LoginForm({
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
    required this.accentRose,
    required this.accentBlush,
    required this.accentLavender,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final emailLabel = l10n.translate('email');
    final passwordLabel = l10n.translate('password');
    final loginLabel = l10n.translate('login');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthSectionLabel(label: emailLabel),
          const SizedBox(height: 7),
          GlassTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            hintText: l10n.translate('auth_email_placeholder'),
            accentColor: accentRose,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 13),
          AuthSectionLabel(label: passwordLabel),
          const SizedBox(height: 7),
          GlassTextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
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
            accentColor: accentRose,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: l10n.translate(
                obscurePassword
                    ? 'auth_refresh_show_password'
                    : 'auth_refresh_hide_password',
              ),
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
                                SLNotice.showError(
                                  context,
                                  l10n.translate('Vui lòng nhập Email.'),
                                );
                              } else if (!_loginEmailRegex.hasMatch(email)) {
                                SLNotice.showError(
                                  context,
                                  l10n.translate('Email không hợp lệ.'),
                                );
                              } else if (password.isEmpty) {
                                SLNotice.showError(
                                  context,
                                  l10n.translate('Vui lòng nhập Mật khẩu.'),
                                );
                              } else if (password.length < 6) {
                                SLNotice.showError(
                                  context,
                                  l10n.translate(
                                    'Mật khẩu phải từ 6 ký tự trở lên.',
                                  ),
                                );
                              } else {
                                SLNotice.showError(
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
          AuthSocialDivider(label: l10n.translate('Hoặc đăng nhập nhanh bằng')),
          const SizedBox(height: 13),
          SocialAuthButtons(onProviderTap: onSocialLogin),
          const SizedBox(height: 12),
          AuthPrivacyNote(text: l10n.translate('auth_refresh_login_notice')),
        ],
      ),
    );
  }
}
