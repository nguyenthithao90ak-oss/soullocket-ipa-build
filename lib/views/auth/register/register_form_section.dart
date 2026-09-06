import 'package:flutter/material.dart';
import '../login/auth_visual_style.dart';
import '../login/auth_form_details.dart';
import '../login/aurora_form_widgets.dart';

import '../../../utils/services/l10n_service.dart';
import '../login/glass_text_field.dart';
import '../login/social_auth_buttons.dart';

final RegExp _registerEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool _isRegisterInputValid(String email, String password, bool acceptTerms) {
  return _registerEmailRegex.hasMatch(email.trim()) &&
      password.trim().length >= 6 &&
      acceptTerms;
}

class RegisterForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final bool acceptTerms;
  final bool showSecurityQuestion;
  final String selectedSecurityQuestion;
  final List<String> securityQuestions;
  final TextEditingController securityAnswerController;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onAcceptTermsChanged;
  final VoidCallback onToggleSecurityQuestion;
  final ValueChanged<String?> onSecurityQuestionChanged;
  final VoidCallback onRegister;
  final Function(String) onSocialLogin;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final Color accentRose;
  final Color accentBlush;
  final Color accentLavender;

  const RegisterForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.acceptTerms,
    required this.showSecurityQuestion,
    required this.selectedSecurityQuestion,
    required this.securityQuestions,
    required this.securityAnswerController,
    required this.onToggleObscure,
    required this.onAcceptTermsChanged,
    required this.onToggleSecurityQuestion,
    required this.onSecurityQuestionChanged,
    required this.onRegister,
    required this.onSocialLogin,
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.accentRose,
    required this.accentBlush,
    required this.accentLavender,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final passwordLabel = l10n.translate('Mật khẩu');
    final passwordHint = l10n.translate('Tối thiểu 6 ký tự');
    final signupLabel = l10n.translate('auth_refresh_create_account');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthSectionLabel(label: l10n.translate('auth_refresh_email_label')),
          const SizedBox(height: 8),
          GlassTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.newUsername,
              AutofillHints.email,
            ],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            hintText: l10n.translate('auth_email_placeholder'),
            accentColor: accentRose,
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
          ),
          const SizedBox(height: 10),
          AuthSectionLabel(label: passwordLabel),
          const SizedBox(height: 8),
          GlassTextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (_) {
              if (!isLoading) onRegister();
            },
            hintText: passwordHint,
            accentColor: accentRose,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              tooltip: l10n.translate(
                obscurePassword
                    ? 'auth_refresh_show_password'
                    : 'auth_refresh_hide_password',
              ),
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: AuthVisualStyle.of(context).muted,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          const SizedBox(height: 12),
          AuthTermsConsent(
            accepted: acceptTerms,
            onChanged: onAcceptTermsChanged,
            onTerms: onTermsTap,
            onPrivacy: onPrivacyTap,
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: emailController,
            builder: (context, emailValue, _) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: passwordController,
                builder: (context, passwordValue, _) {
                  final isInputValid = _isRegisterInputValid(
                    emailValue.text,
                    passwordValue.text,
                    acceptTerms,
                  );

                  return AuroraPrimaryButton(
                    label: signupLabel,
                    onPressed: isLoading || !isInputValid ? null : onRegister,
                    isLoading: isLoading,
                    enabled: isInputValid,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          AuthSocialDivider(label: l10n.translate('Hoặc đăng ký nhanh với')),
          const SizedBox(height: 14),
          SocialAuthButtons(onProviderTap: onSocialLogin),
          const SizedBox(height: 12),
          AuthPrivacyNote(text: l10n.translate('auth_social_register_notice')),
        ],
      ),
    );
  }
}
