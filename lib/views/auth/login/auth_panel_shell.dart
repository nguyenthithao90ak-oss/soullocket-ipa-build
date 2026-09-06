import 'package:flutter/material.dart';

import 'aurora_login_shell.dart';

/// Presentation wrapper for the legacy auth flow.
///
/// The authentication state and callbacks stay in [LoginScreen]; only the
/// visual shell is shared with the new Locket Garden design.
class AuthPanelShell extends StatelessWidget {
  final bool compact;
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;
  final Widget authSection;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenContact;

  const AuthPanelShell({
    super.key,
    required this.compact,
    required this.isLoginTab,
    required this.onSelectLogin,
    required this.onSelectRegister,
    required this.authSection,
    required this.onOpenGuide,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraLoginShell(
      compact: compact,
      isLoginTab: isLoginTab,
      onSelectLogin: onSelectLogin,
      onSelectRegister: onSelectRegister,
      authSection: authSection,
      onOpenGuide: onOpenGuide,
      onOpenContact: onOpenContact,
    );
  }
}
