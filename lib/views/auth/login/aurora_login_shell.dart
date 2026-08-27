import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/theme/design_tokens.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'aurora_tab_switcher.dart';

/// Aurora login shell — layout wrapper chứa glass panel + brand header.
/// Tách riêng để tái sử dụng và giữ main screen gọn gàng.
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
    final l10n = L10nService();

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 28,
        0,
        compact ? 18 : 28,
        compact ? 18 : 24,
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Brand Header ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App icon + title
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Fraunces serif cho tên app — elegant, romantic
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                SLAuroraPalette.roseDeep,
                                SLAuroraPalette.lavender,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'SoulLocket',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: compact ? 34 : 38,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Icon
                          Container(
                            width: compact ? 28 : 34,
                            height: compact ? 28 : 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  SLAuroraPalette.roseDeep,
                                  SLAuroraPalette.lavender,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: SLAuroraPalette.roseDeep
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tagline
                      Text(
                        '❤️ ${l10n.translate('Nơi lưu giữ những khoảnh khắc yêu thương')} ❤️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: compact ? 13 : 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7A6A73),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Tab Switcher ─────────────────────────────────
              AuroraTabSwitcher(
                isLoginTab: isLoginTab,
                onSelectLogin: onSelectLogin,
                onSelectRegister: onSelectRegister,
              ),

              const SizedBox(height: 20),

              // ─── Auth Section (Login/Register form) ────────────
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
                    child: SlideTransition(
                      position: slide,
                      child: child,
                    ),
                  );
                },
                child: RepaintBoundary(
                  key: ValueKey(isLoginTab ? 'login' : 'register'),
                  child: authSection,
                ),
              ),

              const SizedBox(height: 16),

              // ─── Footer Help Buttons ────────────────────────────
              _AuroraHelpSection(
                onOpenGuide: onOpenGuide,
                onOpenContact: onOpenContact,
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuroraHelpSection extends StatelessWidget {
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenContact;
  final bool compact;

  const _AuroraHelpSection({
    required this.onOpenGuide,
    required this.onOpenContact,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sync guide hint
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent_rounded,
              size: 13,
              color: SLAuroraPalette.roseDeep.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onOpenGuide,
              child: Text(
                l10n.translate('auth_sync_guide'),
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 12,
                  color: SLAuroraPalette.roseDeep.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: SLAuroraPalette.roseDeep.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Guide & Contact buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AuroraHelpButton(
              icon: Icons.menu_book_rounded,
              label: l10n.translate('Hướng dẫn'),
              onTap: onOpenGuide,
              isPrimary: true,
              compact: compact,
            ),
            if (!compact) const SizedBox(width: 12),
            _AuroraHelpButton(
              icon: Icons.headset_mic_rounded,
              label: l10n.translate('Hỗ trợ'),
              onTap: onOpenContact,
              isPrimary: false,
              compact: compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _AuroraHelpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool compact;

  const _AuroraHelpButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? Colors.white : SLAuroraPalette.roseDeep;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [
                      SLAuroraPalette.roseDeep,
                      SLAuroraPalette.lavender,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary ? null : Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withValues(alpha: 0.3)
                  : const Color(0xFFFFD6E0),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: SLAuroraPalette.roseDeep
                    .withValues(alpha: isPrimary ? 0.28 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 15 : 16, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
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
  }
}
