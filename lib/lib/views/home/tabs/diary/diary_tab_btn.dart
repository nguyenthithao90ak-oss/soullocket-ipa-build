import 'package:flutter/material.dart';
import '../../../../core/sl_theme.dart';

class DiaryTabBtn extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool active;
  final List<Color> palette;
  final Color accent;
  final VoidCallback onTap;

  const DiaryTabBtn({
    super.key,
    required this.id,
    required this.label,
    required this.icon,
    required this.active,
    required this.palette,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.92) : Colors.transparent,
          borderRadius: SLRadius.lgAll,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: SLRadius.pillAll,
                gradient: active
                    ? LinearGradient(
                        colors: palette,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.92),
                          Colors.white.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.65)
                      : palette.first.withValues(alpha: 0.16),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: palette.first.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                size: 14,
                color: active ? Colors.white : palette.first.withValues(alpha: 0.82),
              ),
            ),
            SLSpacing.w8,
            Text(
              label,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: active ? accent : SLColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
