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
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
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
                      width: compact ? 42 : 46,
                      height: compact ? 42 : 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5287), Color(0xFFFF7397)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(compact ? 14 : 16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5287).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                              color: Colors.white.withValues(alpha: 0.78),
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
                  daysOfWeekHeight: compact ? 26 : 30,
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    titleTextStyle: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 16 : 17,
                    ),
                    formatButtonTextStyle: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    leftChevronIcon:
                        const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                    rightChevronIcon:
                        const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    weekendStyle: SLTheme.quicksand(
                      color: const Color(0xFFFFC0D3),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    weekendTextStyle: SLTheme.quicksand(
                      color: const Color(0xFFFFC0D3),
                      fontWeight: FontWeight.w700,
                    ),
                    selectedDecoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5287), Color(0xFFFF7397)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5287).withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF7397),
                        width: 1.8,
                      ),
                    ),
                    outsideTextStyle: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.25),
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
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5287),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5287).withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ],
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
