import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import '../../../utils/sl_notice.dart';
import 'aurora_form_widgets.dart';
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
    final rememberMeLabel = l10n.translate('remember_me');
    final loginLabel = l10n.translate('login').toUpperCase();
    final forgotPasswordLabel = l10n.translate('forgot_password');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomePaper(
            title: l10n.translate('Chào bạn quay lại'),
            subtitle: l10n.translate(
              'Mở chiếc locket nhỏ và tiếp tục câu chuyện của hai bạn.',
            ),
          ),
          const SizedBox(height: 17),
          _SectionLabel(icon: Icons.alternate_email_rounded, label: emailLabel),
          const SizedBox(height: 7),
          GlassTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            hintText: emailLabel,
            accentColor: accentRose,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 13),
          _SectionLabel(icon: Icons.key_rounded, label: passwordLabel),
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
              onPressed: onToggleObscure,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 20,
                color: const Color(0xFF947B85),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RememberChip(
                  selected: rememberMe,
                  label: rememberMeLabel,
                  onTap: () => onRememberMeChanged(!rememberMe),
                  onChanged: onRememberMeChanged,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: isLoading ? null : onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD6587B),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  forgotPasswordLabel,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
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
                                SLNotice.showError(context, 'Vui lòng nhập Email.');
                              } else if (!_loginEmailRegex.hasMatch(email)) {
                                SLNotice.showError(context, 'Email không hợp lệ.');
                              } else if (password.isEmpty) {
                                SLNotice.showError(context, 'Vui lòng nhập Mật khẩu.');
                              } else if (password.length < 6) {
                                SLNotice.showError(
                                  context,
                                  'Mật khẩu phải từ 6 ký tự trở lên.',
                                );
                              } else {
                                SLNotice.showError(
                                  context,
                                  'Thông tin đăng nhập chưa hợp lệ.',
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
          _SoftDivider(label: l10n.translate('Hoặc đăng nhập nhanh bằng')),
          const SizedBox(height: 13),
          SocialAuthButtons(onProviderTap: onSocialLogin),
          const SizedBox(height: 12),
          const _PrivacyNote(
            text: 'Bằng việc tiếp tục, bạn đồng ý với Điều khoản & Chính sách bảo mật.',
          ),
        ],
      ),
    );
  }
}

class _WelcomePaper extends StatelessWidget {
  final String title;
  final String subtitle;

  const _WelcomePaper({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2DED3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.waving_hand_rounded,
            size: 20,
            color: Color(0xFFE3A44C),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6F5760),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF947F86),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFFD25A7B)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 12.5,
            color: Color(0xFF604C54),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RememberChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final ValueChanged<bool?> onChanged;

  const _RememberChip({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEEF3) : const Color(0xFFFFFAF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFF1B0C0) : const Color(0xFFEEDFE3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: selected,
                onChanged: onChanged,
                activeColor: const Color(0xFFE56184),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7B656D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  final String label;

  const _SoftDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xFFEBDDE1)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA5929A),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEBDDE1), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  final String text;

  const _PrivacyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 12,
            color: Color(0xFFA68B94),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              color: Color(0xFF9A858D),
              fontSize: 9.8,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
