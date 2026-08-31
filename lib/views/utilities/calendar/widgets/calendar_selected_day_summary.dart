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
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFEFF),
              Color(0xFFF7FBFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6EAF9)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
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
                  width: compact ? 46 : 50,
                  height: compact ? 46 : 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(leadingIcon, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 15.5 : 16.5,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 11.5 : 12,
                          fontWeight: FontWeight.w700,
                          color: SLTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
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
