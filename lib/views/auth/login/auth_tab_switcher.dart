import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';

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
    final isVietnamese = l10n.locale.languageCode == 'vi';

    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final width = rootConstraints.maxWidth;
        final compact = width < 360;
        final dense = width < 320;

        return Container(
          height: compact ? 56 : 60,
          padding: SLSpacing.all4,
          decoration: BoxDecoration(
            color: SLTheme.authSurfaceTint.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: SLTheme.authFieldBorder.withValues(alpha: 0.98),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD9C9BD).withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
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
                        gradient: const LinearGradient(
                          colors: [
                            SLColors.primary,
                            Color(0xFFF191B3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(compact ? 16 : 18),
                        boxShadow: [
                          BoxShadow(
                            color: SLColors.primary.withValues(alpha: 0.24),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _AuthTabButton(
                        label: isVietnamese
                            ? 'VÀO NHÀ'
                            : l10n.translate('login').toUpperCase(),
                        active: isLoginTab,
                        onTap: onSelectLogin,
                        compact: compact,
                        dense: dense,
                      ),
                      _AuthTabButton(
                        label: isVietnamese
                            ? 'TẠO NHÀ MỚI'
                            : l10n.translate('signup').toUpperCase(),
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
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
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
