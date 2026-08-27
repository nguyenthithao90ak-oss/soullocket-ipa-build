import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import 'login_form_section.dart';

class LoginShell extends StatelessWidget {
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

  const LoginShell({
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

  @override
  Widget build(BuildContext context) {
    return LoginForm(
      emailController: emailController,
      passwordController: passwordController,
      obscurePassword: obscurePassword,
      isLoading: isLoading,
      rememberMe: rememberMe,
      onToggleObscure: onToggleObscure,
      onRememberMeChanged: onRememberMeChanged,
      onLogin: onLogin,
      onForgotPassword: onForgotPassword,
      onSocialLogin: onSocialLogin,
      accentRose: SLColors.brandPink,
      accentBlush: const Color(0xFFFF69B4),
      accentLavender: const Color(0xFFFF85A2),
    );
  }
}
