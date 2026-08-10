import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../../../core/fast_backdrop_filter.dart';
import '../../../../core/sl_theme.dart';

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.all(compact ? 16 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
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
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(compact ? 14 : 16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
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
                              color: Colors.white,
                            ),
                          ),
                          SLSpacing.h4,
                          Text(
                            description,
                            style: SLTheme.quicksand(
                              fontSize: compact ? 11.5 : 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8),
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
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: SLTheme.quicksand(
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                      label: context.tr('util_nhclc0900_bc079d'),
                      accent: accent,
                      compact: compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
