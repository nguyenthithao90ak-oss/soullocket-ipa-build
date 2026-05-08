import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';
import 'social_auth_buttons.dart';

final RegExp _loginEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

const List<Color> _loginButtonDisabledColors = <Color>[
  Color(0xFFE8AFC4),
  Color(0xFFF1C3D3),
  Color(0xFFE8CFE0),
];

bool _isLoginInputValid(String email, String password) {
  return _loginEmailRegex.hasMatch(email.trim()) && password.trim().length >= 6;
}

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
    final isVietnamese = l10n.locale.languageCode == 'vi';
    final emailLabel = isVietnamese ? 'Email:' : l10n.translate('email');
    final passwordLabel =
        isVietnamese ? 'Mật khẩu mở cửa:' : l10n.translate('password');
    final rememberMeLabel =
        isVietnamese ? 'Ghi nhớ đăng nhập' : l10n.translate('remember_me');
    final loginLabel =
        isVietnamese ? 'VÀO NHÀ' : l10n.translate('login').toUpperCase();
    final forgotPasswordLabel =
        isVietnamese ? 'Quên mật khẩu?' : l10n.translate('forgot_password');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SLTheme.sectionHeader(title: emailLabel),
          const SizedBox(height: 8),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: SLTheme.authInputDecoration(hintText: emailLabel),
          ),
          const SizedBox(height: 10),
          SLTheme.sectionHeader(title: passwordLabel),
          const SizedBox(height: 8),
          TextField(
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
            style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: SLTheme.authInputDecoration(
              hintText: passwordLabel,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: SLTheme.authMutedTextColor,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onRememberMeChanged(!rememberMe),
            child: SLTheme.authToggleCard(
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
                        activeColor: SLColors.primary,
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
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          color: SLColors.textSecond.withValues(alpha: 0.92),
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

                  return SLTheme.authPrimaryButton(
                    label: loginLabel,
                    onPressed: isLoading || !isInputValid ? null : onLogin,
                    isLoading: isLoading,
                    colors: isInputValid
                        ? [accentRose, accentBlush, accentLavender]
                        : _loginButtonDisabledColors,
                  );
                },
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: SLColors.danger,
                padding: const EdgeInsets.only(top: 2, bottom: 4, right: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                forgotPasswordLabel,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SLColors.danger,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                isVietnamese ? 'HOẶC' : 'OR',
                style: SLTheme.quicksand(
                  color: const Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SocialAuthButtons(
            onProviderTap: onSocialLogin,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              isVietnamese
                  ? 'Đăng nhập / Đăng ký qua Google hoặc Apple đồng nghĩa\n'
                      'bạn xác nhận đủ 13 tuổi và đồng ý với Điều khoản.'
                  : 'By continuing with Google or Apple, you confirm\nyou are 13+ and agree to our Terms.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: const Color(0xFF999999),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
