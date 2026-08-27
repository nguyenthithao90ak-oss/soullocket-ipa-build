import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

import 'calendar_info_pill.dart';

class CalendarSelectedDaySummary extends StatelessWidget {
  final double horizontalInset;
  final bool compact;
  final Color accent;
  final IconData leadingIcon;
  final String displayDate;
  final String description;
  final String badgeLabel;
  final String shortDateLabel;
  final int eventCount;

  const CalendarSelectedDaySummary({
    super.key,
    required this.horizontalInset,
    required this.compact,
    required this.accent,
    required this.leadingIcon,
    required this.displayDate,
    required this.description,
    required this.badgeLabel,
    required this.shortDateLabel,
    required this.eventCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.all(compact ? 16 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.94),
              Colors.white.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 44 : 48,
                  height: compact ? 44 : 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(compact ? 14 : 16),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: accent,
                    size: compact ? 22 : 24,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 15.5 : 17,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        description,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 11.5 : 12,
                          fontWeight: FontWeight.w700,
                          color: SLTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 12,
                    vertical: compact ? 7 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: SLTheme.quicksand(
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 14),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [
                CalendarInfoPill(
                  icon: Icons.calendar_today_rounded,
                  label: shortDateLabel,
                  accent: accent,
                  compact: compact,
                ),
                CalendarInfoPill(
                  icon: Icons.event_note_rounded,
                  label: '$eventCount kế hoạch',
                  accent: accent,
                  compact: compact,
                ),
                CalendarInfoPill(
                  icon: Icons.notifications_active_rounded,
                  label: 'Nhắc lúc 09:00',
                  accent: accent,
                  compact: compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
