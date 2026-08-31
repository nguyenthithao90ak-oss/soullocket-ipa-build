import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
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

    return SLTheme.paperCard(
      color: SLColors.paper.withValues(alpha: 0.97),
      accentColor: SLColors.thread,
      radius: compact ? 26 : 30,
      showTape: true,
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 28,
        compact ? 18 : 22,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SoulLocket',
                            style: SLTheme.textStyleForKey(
                              'dancingScript',
                              fontSize: compact ? 36 : 42,
                              fontWeight: FontWeight.w800,
                              color: SLColors.brandPink,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: compact ? 28 : 32,
                            height: compact ? 28 : 32,
                            decoration: BoxDecoration(
                              color: SLColors.primarySoft,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: SLColors.primary.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_rounded,
                                  size: compact ? 17 : 19,
                                  color: SLColors.primary,
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: compact ? 9 : 10,
                                    color: SLColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '❤️ ${l10n.translate('Nơi lưu giữ những khoảnh khắc yêu thương')} ❤️',
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 13 : 14.5,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecond,
                        ),
                      ),
                    ],
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
                      ...?currentChild == null ? null : [currentChild],
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
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: RepaintBoundary(child: authSection),
              ),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  8,
                  compact ? 12 : 14,
                  compact ? 8 : 10,
                ),
                decoration: const BoxDecoration(color: Colors.transparent),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stackButtons =
                        compact ||
                        textScale > 1.25 ||
                        constraints.maxWidth < 280;
                    final buttons = [
                      _AuthHelpButton(
                        icon: Icons.menu_book_rounded,
                        label: l10n.translate('Hướng dẫn'),
                        onTap: onOpenGuide,
                        isGuide: true,
                        expanded: !stackButtons,
                        compact: compact,
                      ),
                      _AuthHelpButton(
                        icon: Icons.headset_mic_rounded,
                        label: l10n.translate('Hỗ trợ'),
                        onTap: onOpenContact,
                        isGuide: false,
                        expanded: !stackButtons,
                        compact: compact,
                      ),
                    ];

                    if (stackButtons) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [buttons.first, SLSpacing.h8, buttons.last],
                      );
                    }

                    return Row(
                      children: [buttons.first, SLSpacing.w8, buttons.last],
                    );
                  },
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
    final foreground = isGuide ? Colors.white : SLColors.brandPink;
    final buttonChild = Container(
      decoration: BoxDecoration(
        gradient: isGuide
            ? const LinearGradient(
                colors: [SLColors.brandPink, Color(0xFFFF69B4)],
              )
            : null,
        color: isGuide ? null : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isGuide
              ? Colors.white.withValues(alpha: 0.3)
              : const Color(0xFFFFD6E0),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: SLColors.brandPink.withValues(alpha: isGuide ? 0.28 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
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
