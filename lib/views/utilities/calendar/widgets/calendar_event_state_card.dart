import 'package:flutter/material.dart';
import 'calendar_design.dart';

class CalendarEventStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CalendarEventStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: CalendarDesign.primary(context)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: CalendarDesign.text(
            context,
            size: 15,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: CalendarDesign.text(
            context,
            size: 13,
            color: CalendarDesign.muted(context),
          ),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: CalendarDesign.primary(context),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}
