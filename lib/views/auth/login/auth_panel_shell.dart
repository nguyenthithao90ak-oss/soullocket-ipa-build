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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.96),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C6475).withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 17),
          ),
          BoxShadow(
            color: const Color(0xFF8A75C3).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AuroraLoginShell(
            compact: compact,
            isLoginTab: isLoginTab,
            onSelectLogin: onSelectLogin,
            onSelectRegister: onSelectRegister,
            authSection: authSection,
            onOpenGuide: onOpenGuide,
            onOpenContact: onOpenContact,
          ),
          const Positioned(
            right: 18,
            top: -6,
            child: _PaperSeal(),
          ),
        ],
      ),
    );
  }
}

class _PaperSeal extends StatelessWidget {
  const _PaperSeal();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.08,
      child: Container(
        width: 38,
        height: 17,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE3A8).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFDDBA73).withValues(alpha: 0.48),
          ),
        ),
      ),
    );
  }
}
