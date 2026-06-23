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
            color: isLoginTab
                ? const Color(0xFFFFF0F5).withValues(alpha: 0.6)
                : const Color(0xFFFCF0FF).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isLoginTab
                  ? const Color(0xFFFFB6D3).withValues(alpha: 0.5)
                  : const Color(0xFFD4AAFF).withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isLoginTab
                    ? const Color(0xFFFF85B3).withValues(alpha: 0.08)
                    : const Color(0xFFB080FF).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                        gradient: LinearGradient(
                          colors: isLoginTab
                              ? const [Color(0xFFFF5293), Color(0xFFFF8FB8)]
                              : const [Color(0xFF8A3BFF), Color(0xFFC49CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: (isLoginTab
                                    ? const Color(0xFFFF5293)
                                    : const Color(0xFF8A3BFF))
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _AuthTabButton(
                        label: l10n.translate('login').toUpperCase(),
                        active: isLoginTab,
                        onTap: onSelectLogin,
                        compact: compact,
                        dense: dense,
                      ),
                      _AuthTabButton(
                        label: l10n.translate('signup').toUpperCase(),
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
          borderRadius: BorderRadius.circular(22),
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
                        ? Colors.white
                        : SLTheme.authChipText.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    letterSpacing: letterSpacing,
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
