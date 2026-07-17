import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../core/fast_backdrop_filter.dart';
import '../../../utils/services/l10n_service.dart';
import 'auth_tab_switcher.dart';

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
    final l10n = L10nService();
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        fallbackColor: Colors.white.withValues(alpha: 0.85),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF1C3D3).withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 16),
              )
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 28,
            compact ? 22 : 28,
            compact ? 18 : 28,
            compact ? 18 : 24,
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // --- brand micro-header ---
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isLoginTab
                          ? const [Color(0xFFE0609A), Color(0xFFA044C0)]
                          : const [Color(0xFF9030C0), Color(0xFFE060B0)],
                    ).createShader(bounds),
                    child: Text(
                      'SoulLocket',
                      style: SLTheme.quicksand(
                        fontSize: compact ? 22 : 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              AuthTabSwitcher(
                isLoginTab: isLoginTab,
                onSelectLogin: onSelectLogin,
                onSelectRegister: onSelectRegister,
              ),
              SLSpacing.h16,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  final fade = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  final slide = Tween<Offset>(
                    begin: const Offset(0.0, 0.04),
                    end: Offset.zero,
                  ).animate(fade);
                  return FadeTransition(
                    opacity: fade,
                    child: SlideTransition(
                      position: slide,
                      child: child,
                    ),
                  );
                },
                child: RepaintBoundary(child: authSection),
              ),
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  12,
                  compact ? 12 : 14,
                  compact ? 10 : 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 13,
                          color: SLColors.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.translate('auth_help_center_guide'),
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            color: SLColors.primary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackButtons = compact ||
                            textScale > 1.25 ||
                            constraints.maxWidth < 280;
                        final buttons = [
                          _AuthHelpButton(
                            icon: Icons.menu_book_rounded,
                            label: l10n.translate('auth_guide_short'),
                            onTap: onOpenGuide,
                            isGuide: true,
                            expanded: !stackButtons,
                            compact: compact,
                          ),
                          _AuthHelpButton(
                            icon: Icons.headset_mic_rounded,
                            label: l10n.translate('auth_contact_short'),
                            onTap: onOpenContact,
                            isGuide: false,
                            expanded: !stackButtons,
                            compact: compact,
                          ),
                        ];

                        if (stackButtons) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buttons.first,
                              SLSpacing.h8,
                              buttons.last,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            buttons.first,
                            SLSpacing.w8,
                            buttons.last,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _AuthHelpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isGuide;
  final bool expanded;
  final bool compact;

  const _AuthHelpButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isGuide,
    required this.expanded,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isGuide ? SLColors.primary : Colors.white;
    final foreground = isGuide ? Colors.white : SLColors.textPrimary;
    final buttonChild = Container(
      decoration: BoxDecoration(
        gradient: isGuide
            ? const LinearGradient(
                colors: [
                  SLColors.primary,
                  Color(0xFFE37A9C),
                ],
              )
            : null,
        color: isGuide ? null : bgColor,
        borderRadius: SLRadius.xlAll,
        border: Border.all(
          color: isGuide
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.86),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isGuide ? const Color(0xFFA89BDD) : SLColors.secondary)
                .withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: SLRadius.xlAll,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 15 : 16, color: foreground),
                SLSpacing.w8,
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: compact ? 13.0 : 13.5,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expanded) {
      return Expanded(child: buttonChild);
    }
    return buttonChild;
  }
}
