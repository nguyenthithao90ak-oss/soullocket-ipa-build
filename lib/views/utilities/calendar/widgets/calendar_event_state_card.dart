import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.16)),
                ),
                child: Icon(icon, size: 32, color: color),
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
                  height: 1.38,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: onAction,
                  icon: Icon(Icons.refresh_rounded, color: color, size: 18),
                  label: Text(
                    actionLabel!,
                    style: SLTheme.quicksand(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    backgroundColor: color.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
