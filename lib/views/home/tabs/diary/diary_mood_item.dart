import 'package:flutter/material.dart';
import '../../../../core/sl_theme.dart';

class DiaryMoodItem extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const DiaryMoodItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 50 : 44,
              height: selected ? 50 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? color.withOpacity(0.32)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: selected ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(fontSize: selected ? 28 : 24),
                ),
              ),
            ),
            SLSpacing.h8,
            Text(
              label,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: selected ? color : const Color(0xFFB6B1B2),
                fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
