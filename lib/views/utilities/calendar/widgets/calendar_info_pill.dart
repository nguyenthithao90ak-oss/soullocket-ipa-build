import 'package:flutter/material.dart';
import '../../../../core/sl_theme.dart';

class CalendarInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool compact;

  const CalendarInfoPill({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 15, color: accent),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
