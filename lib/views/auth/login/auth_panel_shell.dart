import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';
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
    final isVietnamese = l10n.locale.languageCode == 'vi';
    final panelGradient = isLoginTab
        ? const [
            Color(0xFFFFFCFA),
            Color(0xFFFFF6F1),
            Color(0xFFFCF7F8),
          ]
        : const [
            Color(0xFFFFFBF8),
            Color(0xFFFDF4F2),
            Color(0xFFFAF7FB),
          ];
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 26,
        compact ? 20 : 26,
        compact ? 16 : 26,
        compact ? 16 : 22,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: panelGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 30 : 38),
        border: Border.all(
          color: SLTheme.authFieldBorder.withOpacity(0.98),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: SLColors.primary.withOpacity(isLoginTab ? 0.12 : 0.08),
            blurRadius: 34,
            spreadRadius: -6,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.82),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: compact ? -34 : -44,
            right: compact ? -30 : -22,
            child: IgnorePointer(
              child: Container(
                width: compact ? 112 : 132,
                height: compact ? 112 : 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isLoginTab
                          ? SLTheme.authHeroGlow.withOpacity(0.34)
                          : SLColors.accentPurple.withOpacity(0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthTabSwitcher(
                isLoginTab: isLoginTab,
                onSelectLogin: onSelectLogin,
                onSelectRegister: onSelectRegister,
              ),
              SLSpacing.h16,
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
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
              ),
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  14,
                  compact ? 12 : 14,
                  compact ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: SLTheme.authHelpBackground.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: SLTheme.authFieldBorder.withOpacity(0.96),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVietnamese
                          ? 'Trung tâm trợ giúp & Hướng dẫn'
                          : 'Help Center & Guide',
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        color: SLColors.textSecond,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SLSpacing.h12,
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackButtons = compact ||
                            textScale > 1.25 ||
                            constraints.maxWidth < 280;
                        final buttons = [
                          _AuthHelpButton(
                            icon: Icons.menu_book_rounded,
                            label: isVietnamese ? 'Hướng Dẫn' : 'Guide',
                            onTap: onOpenGuide,
                            isGuide: true,
                            expanded: !stackButtons,
                            compact: compact,
                          ),
                          _AuthHelpButton(
                            icon: Icons.headset_mic_rounded,
                            label: isVietnamese ? 'Liên Hệ' : 'Contact',
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
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.86),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isGuide ? const Color(0xFFA89BDD) : SLColors.secondary)
                .withOpacity(0.14),
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
