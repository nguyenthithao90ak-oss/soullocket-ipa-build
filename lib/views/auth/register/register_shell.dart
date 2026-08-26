import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import 'register_form_section.dart';

class RegisterShell extends StatelessWidget {
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

  const RegisterShell({
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
  });

  @override
  Widget build(BuildContext context) {
    return RegisterForm(
      emailController: emailController,
      passwordController: passwordController,
      obscurePassword: obscurePassword,
      isLoading: isLoading,
      acceptTerms: acceptTerms,
      showSecurityQuestion: showSecurityQuestion,
      selectedSecurityQuestion: selectedSecurityQuestion,
      securityQuestions: securityQuestions,
      securityAnswerController: securityAnswerController,
      onToggleObscure: onToggleObscure,
      onAcceptTermsChanged: onAcceptTermsChanged,
      onToggleSecurityQuestion: onToggleSecurityQuestion,
      onSecurityQuestionChanged: onSecurityQuestionChanged,
      onRegister: onRegister,
      onSocialLogin: onSocialLogin,
      onTermsTap: onTermsTap,
      onPrivacyTap: onPrivacyTap,
      accentRose: const SLColors.brandPink,
      accentBlush: const Color(0xFFFF69B4),
      accentLavender: const Color(0xFFFF85A2),
    );
  }
}
