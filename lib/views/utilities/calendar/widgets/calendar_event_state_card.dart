import 'package:flutter/material.dart';
import '../../../../core/sl_theme.dart';

class CalendarEventStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const CalendarEventStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: color),
            ),
            SLSpacing.h12,
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: SLTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SLTheme.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
