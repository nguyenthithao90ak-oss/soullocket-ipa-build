import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

class AuthTabSwitcher extends StatelessWidget {
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;

  const AuthTabSwitcher({
    super.key,
    required this.isLoginTab,
    required this.onSelectLogin,
    required this.onSelectRegister,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final width = rootConstraints.maxWidth;
        final compact = width < 360;
        final dense = width < 320;

        return Container(
          height: compact ? 50 : 54,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SLColors.paperPeach.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: SLColors.border, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: SLColors.ink.withValues(alpha: 0.05),
                blurRadius: 12,
                spreadRadius: -5,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final indicatorWidth = (constraints.maxWidth - 8) / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    bottom: 0,
                    left: isLoginTab ? 0 : indicatorWidth,
                    child: Container(
                      width: indicatorWidth,
                      decoration: BoxDecoration(
                        color: SLColors.paper,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: SLColors.thread.withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SLColors.thread.withValues(alpha: 0.10),
                            blurRadius: 9,
                            spreadRadius: -3,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _AuthTabButton(
                        label: l10n.translate('login'),
                        active: isLoginTab,
                        onTap: onSelectLogin,
                        compact: compact,
                        dense: dense,
                      ),
                      _AuthTabButton(
                        label: l10n.translate('signup'),
                        active: !isLoginTab,
                        onTap: onSelectRegister,
                        compact: compact,
                        dense: dense,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool compact;
  final bool dense;

  const _AuthTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = dense
        ? (active ? 11.6 : 11.2)
        : compact
        ? (active ? 12.4 : 12.0)
        : (active ? 13.8 : 13.2);
    final letterSpacing = dense
        ? (active ? 0.24 : 0.18)
        : compact
        ? (active ? 0.42 : 0.3)
        : (active ? 0.7 : 0.45);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: SLTheme.quicksand(
                    color: active
                        ? SLColors
                              .brandPink // Romantic pink cho chữ đang chọn
                        : const Color(
                            0xFF757575,
                          ), // Xám nhạt cho chữ không chọn
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    fontSize: fontSize,
                    letterSpacing: letterSpacing * 0.55,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
