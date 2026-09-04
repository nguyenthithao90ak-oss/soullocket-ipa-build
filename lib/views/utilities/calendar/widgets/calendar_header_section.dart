import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
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
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5668C8), Color(0xFF7C70D4), Color(0xFFE47D96)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C70D4).withValues(alpha: 0.22),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(compact ? 14 : 16),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('calendar_hero_title'),
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 17 : 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('calendar_hero_desc'),
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.86),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              calendarFormat: calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: {
                CalendarFormat.month: context.tr('calendar_format_month'),
                CalendarFormat.twoWeeks: context.tr(
                  'calendar_format_two_weeks',
                ),
              },
              eventLoader: eventLoader,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: onDaySelected,
              onDayLongPressed: onDayLongPressed,
              onFormatChanged: onFormatChanged,
              onPageChanged: onPageChanged,
              rowHeight: compact ? 44 : 48,
              daysOfWeekHeight: compact ? 24 : 28,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonTextStyle: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                titleTextStyle: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 15 : 16,
                ),
                formatButtonDecoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w800,
                ),
                weekendStyle: SLTheme.quicksand(
                  color: const Color(0xFFFFF4BD),
                  fontWeight: FontWeight.w800,
                ),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                weekendTextStyle: SLTheme.quicksand(
                  color: const Color(0xFFFFF4BD),
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF7DA3), Color(0xFFE9538A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
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
          ),
        ],
      ),
    );
  }
}
