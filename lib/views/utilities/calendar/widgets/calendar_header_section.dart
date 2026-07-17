import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../../../core/fast_backdrop_filter.dart';
import '../../../../core/sl_theme.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarHeaderSection extends StatelessWidget {
  final double horizontalInset;
  final bool compact;
  final CalendarFormat calendarFormat;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final List<dynamic> Function(DateTime day) eventLoader;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime selectedDay, DateTime focusedDay)?
      onDayLongPressed;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;

  const CalendarHeaderSection({
    super.key,
    required this.horizontalInset,
    required this.compact,
    required this.calendarFormat,
    required this.focusedDay,
    required this.selectedDay,
    required this.eventLoader,
    required this.onDaySelected,
    this.onDayLongPressed,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(horizontalInset, 10, horizontalInset, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
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
                      width: compact ? 42 : 46,
                      height: compact ? 42 : 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(compact ? 14 : 16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: compact ? 22 : 24,
                      ),
                    ),
                    SLSpacing.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('util_lchichi_3eb020'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: compact ? 17 : 18,
                            ),
                          ),
                          SLSpacing.h4,
                          Text(
                            context.tr('util_chmvongybt_98a4c5'),
                            style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                              fontSize: compact ? 11.5 : 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 16),
                TableCalendar(
                  locale: L10nService().localeCode,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  calendarFormat: calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableCalendarFormats: {
                    CalendarFormat.month: context.tr('util_thng_570330'),
                    CalendarFormat.twoWeeks: context.tr('util_2tun_9917c0'),
                  },
                  eventLoader: eventLoader,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: onDaySelected,
                  onDayLongPressed: onDayLongPressed,
                  onFormatChanged: onFormatChanged,
                  onPageChanged: onPageChanged,
                  rowHeight: compact ? 44 : 50,
                  daysOfWeekHeight: compact ? 24 : 28,
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    titleTextStyle: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 15 : 16,
                    ),
                    formatButtonTextStyle: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24)),
                    ),
                    leftChevronIcon:
                        const Icon(Icons.chevron_left, color: Colors.white),
                    rightChevronIcon:
                        const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontWeight: FontWeight.w800,
                    ),
                    weekendStyle: SLTheme.quicksand(
                      color: const Color(0xFFFFF0C7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    weekendTextStyle: SLTheme.quicksand(
                      color: const Color(0xFFFFF0C7),
                      fontWeight: FontWeight.w700,
                    ),
                    selectedDecoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF7396), Color(0xFFE63A71)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 1.4,
                      ),
                    ),
                    outsideTextStyle: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                    markersMaxCount: 1,
                    markerDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${events.length}',
                            style: SLTheme.quicksand(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2157F2),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
