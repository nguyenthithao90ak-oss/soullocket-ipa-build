import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
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
      SLNotice.showError(context, 'Vui lòng nhập địa chỉ Email!');
      return;
    }
    if (!email.contains('@') || !_registerEmailRegex.hasMatch(email)) {
      SLNotice.showError(
        context,
        'Email chưa đúng định dạng. Vui lòng kiểm tra lại!',
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
      SLNotice.showError(context, 'Vui lòng nhập mật khẩu!');
      return;
    }
    if (password.length < 6) {
      SLNotice.showError(
        context,
        'Mật khẩu cần tối thiểu 6 ký tự (chữ thường và số)!',
      );
      return;
    }
    if (!acceptTerms) {
      SLNotice.showError(
        context,
        'Vui lòng tích chọn xác nhận bạn từ 13 tuổi trở lên và chấp nhận Điều khoản sử dụng!',
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final passwordLabel = l10n.translate('Mật khẩu');
    final passwordHint = l10n.translate('Tối thiểu 6 ký tự');
    final signupLabel = l10n.translate('Đăng ký').toUpperCase();

    return AutofillGroup(
      child: Column(
        key: const ValueKey('aurora_register'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email input
          _AuroraSectionLabel(label: l10n.translate('auth_email_label')),
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

          // Terms checkbox
          _AuroraTermsCard(
            acceptTerms: acceptTerms,
            onAcceptTermsChanged: onAcceptTermsChanged,
            onTermsTap: onTermsTap,
            onPrivacyTap: onPrivacyTap,
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
          _AuroraRegisterDivider(
            label: l10n.translate('Hoặc đăng ký nhanh với'),
          ),
          const SizedBox(height: 16),

          // Social auth buttons
          AuroraSocialButtons(onProviderTap: onSocialLogin),

          const SizedBox(height: 12),

          // Social notice
          Center(
            child: Text(
              l10n.translate('auth_social_register_notice'),
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

class _AuroraTermsCard extends StatelessWidget {
  final bool acceptTerms;
  final ValueChanged<bool?> onAcceptTermsChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const _AuroraTermsCard({
    required this.acceptTerms,
    required this.onAcceptTermsChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();

    return GestureDetector(
      onTap: () => onAcceptTermsChanged(!acceptTerms),
      child: Container(
        decoration: BoxDecoration(
          color: acceptTerms
              ? const Color(0xFFFFF2F5).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: acceptTerms
                ? const Color(0xFFFF5E7E).withValues(alpha: 0.5)
                : const Color(0xFFF0E5DF),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: acceptTerms,
                  activeColor: const Color(0xFFFF5E7E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: onAcceptTermsChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12,
                      color: Color(0xFF58455B),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '${l10n.translate('auth_terms_confirm_prefix')} ',
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => onAcceptTermsChanged(!acceptTerms),
                      ),
                      TextSpan(
                        text: l10n.translate('terms_of_use'),
                        style: const TextStyle(
                          color: Color(0xFFFF5E7E),
                          fontWeight: FontWeight.w900,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onTermsTap,
                      ),
                      const TextSpan(text: ' & '),
                      TextSpan(
                        text: l10n.translate('privacy_policy'),
                        style: const TextStyle(
                          color: Color(0xFFFF5E7E),
                          fontWeight: FontWeight.w900,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onPrivacyTap,
                      ),
                    ],
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

class _AuroraRegisterDivider extends StatelessWidget {
  final String label;

  const _AuroraRegisterDivider({required this.label});

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
