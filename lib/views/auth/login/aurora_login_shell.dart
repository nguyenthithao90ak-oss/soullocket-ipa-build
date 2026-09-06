import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'auth_visual_style.dart';
import 'auth_keepsake_details.dart';
import 'aurora_tab_switcher.dart';

/// Khung xác thực dùng chung, tự đổi bố cục theo chiều rộng khả dụng.
class AuroraLoginShell extends StatelessWidget {
  final bool compact;
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;
  final Widget authSection;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenContact;

  const AuroraLoginShell({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final header = _AuthBrandHeader(isLoginTab: isLoginTab, wide: wide);
        final form = AuthKeepsakeCard(
          padding: EdgeInsets.all(compact ? 20 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuroraTabSwitcher(
                isLoginTab: isLoginTab,
                onSelectLogin: onSelectLogin,
                onSelectRegister: onSelectRegister,
              ),
              const SizedBox(height: 22),
              AnimatedSize(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: authSection,
              ),
            ],
          ),
        );
        final help = Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            children: [
              _HelpLink(
                icon: Icons.help_outline_rounded,
                label: context.tr('auth_refresh_guide'),
                onTap: onOpenGuide,
              ),
              _HelpLink(
                icon: Icons.chat_bubble_outline_rounded,
                label: context.tr('auth_refresh_support'),
                onTap: onOpenContact,
              ),
            ],
          ),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 64),
                  child: header,
                ),
              ),
              SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [form, help],
                ),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: header,
            ),
            form,
            help,
          ],
        );
      },
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  final bool isLoginTab;
  final bool wide;
  const _AuthBrandHeader({required this.isLoginTab, required this.wide});

  @override
  Widget build(BuildContext context) => AuthKeepsakeHeader(
    wide: wide,
    title: context.tr(
      isLoginTab ? 'auth_refresh_login_title' : 'auth_refresh_register_title',
    ),
    subtitle: context.tr(
      isLoginTab
          ? 'auth_refresh_login_subtitle'
          : 'auth_refresh_register_subtitle',
    ),
  );
}

class AuthLocketMark extends StatelessWidget {
  final double size;
  const AuthLocketMark({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: style.accentFill,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(
          Icons.favorite_border_rounded,
          size: size * 0.57,
          color: style.accent,
        ),
      ),
    );
  }
}

class _HelpLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HelpLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: style.muted,
        minimumSize: const Size(48, 48),
        textStyle: style.text(size: 12, weight: FontWeight.w500),
      ),
    );
  }
}
