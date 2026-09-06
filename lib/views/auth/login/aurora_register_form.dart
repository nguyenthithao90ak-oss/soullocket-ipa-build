import 'package:flutter/material.dart';
import 'auth_visual_style.dart';
import 'auth_form_details.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
import 'aurora_form_widgets.dart';
import 'aurora_social_buttons.dart';

final RegExp _registerEmailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Aurora-styled register form section.
/// Giữ nguyên logic validation từ register_form_section.dart cũ.
class AuroraRegisterForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final bool acceptTerms;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onAcceptTermsChanged;
  final VoidCallback onRegister;
  final Function(String) onSocialLogin;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const AuroraRegisterForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.acceptTerms,
    required this.onToggleObscure,
    required this.onAcceptTermsChanged,
    required this.onRegister,
    required this.onSocialLogin,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  bool _isRegisterInputValid(String email, String password, bool acceptTerms) {
    return _registerEmailRegex.hasMatch(email.trim().toLowerCase()) &&
        password.trim().length >= 6 &&
        acceptTerms;
  }

  void _handleDisabledTap(BuildContext context) {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      SLNotice.showError(
        context,
        L10nService().translate('Vui lòng nhập địa chỉ Email!'),
      );
      return;
    }
    if (!email.contains('@') || !_registerEmailRegex.hasMatch(email)) {
      SLNotice.showError(
        context,
        L10nService().translate(
          'Email chưa đúng định dạng. Vui lòng kiểm tra lại!',
        ),
      );
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
    final isDomainAllowed = allowedDomains.any((d) => email.endsWith(d));
    if (!isDomainAllowed) {
      SLNotice.showError(
        context,
        L10nService().translate('auth_supported_domains_only'),
      );
      return;
    }
    if (password.isEmpty) {
      SLNotice.showError(
        context,
        L10nService().translate('Vui lòng nhập mật khẩu!'),
      );
      return;
    }
    if (password.length < 6) {
      SLNotice.showError(
        context,
        L10nService().translate(
          'Mật khẩu cần tối thiểu 6 ký tự (chữ thường và số)!',
        ),
      );
      return;
    }
    if (!acceptTerms) {
      SLNotice.showError(
        context,
        L10nService().translate(
          'Vui lòng tích chọn xác nhận bạn từ 13 tuổi trở lên và chấp nhận Điều khoản sử dụng!',
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final passwordLabel = l10n.translate('Mật khẩu');
    final passwordHint = l10n.translate('Tối thiểu 6 ký tự');
    final signupLabel = l10n.translate('auth_refresh_create_account');

    return AutofillGroup(
      child: Column(
        key: const ValueKey('aurora_register'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email input
          AuthSectionLabel(label: l10n.translate('auth_refresh_email_label')),
          const SizedBox(height: 8),
          AuroraTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.newUsername,
              AutofillHints.email,
            ],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            hintText: l10n.translate('auth_email_placeholder'),
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
          ),

          const SizedBox(height: 14),

          // Password input
          AuthSectionLabel(label: passwordLabel),
          const SizedBox(height: 8),
          AuroraTextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            isPassword: true,
            onSubmitted: (_) {
              if (!isLoading && acceptTerms) {
                onRegister();
              } else {
                _handleDisabledTap(context);
              }
            },
            hintText: passwordHint,
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

          // Terms checkbox
          AuthTermsConsent(
            accepted: acceptTerms,
            onChanged: onAcceptTermsChanged,
            onTerms: onTermsTap,
            onPrivacy: onPrivacyTap,
          ),
          const SizedBox(height: 20),

          // Register button
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
                    onPressed: onRegister,
                    onDisabledTap: () => _handleDisabledTap(context),
                    isLoading: isLoading,
                    enabled: isInputValid,
                  );
                },
              );
            },
          ),

          // Social auth divider
          const SizedBox(height: 18),
          AuthSocialDivider(label: l10n.translate('Hoặc đăng ký nhanh với')),
          const SizedBox(height: 16),

          // Social auth buttons
          AuroraSocialButtons(onProviderTap: onSocialLogin),

          const SizedBox(height: 12),

          // Social notice
          AuthPrivacyNote(text: l10n.translate('auth_social_register_notice')),
        ],
      ),
    );
  }
}
