import 'package:flutter/material.dart';
import '../../../../core/sl_theme.dart';

class DiaryHintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const DiaryHintChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
