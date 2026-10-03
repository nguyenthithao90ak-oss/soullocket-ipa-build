import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:soullocket_app/core/constants/market_calendar_profiles.dart';
import 'package:soullocket_app/utils/calendar/holiday_occurrence_resolver.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:table_calendar/table_calendar.dart';

import 'calendar_design.dart';

class CalendarHeaderSection extends StatelessWidget {
  final double horizontalInset;
  final bool compact;
  final CalendarFormat calendarFormat;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final String locale;
  final MarketCalendarProfile calendarProfile;
  final List<dynamic> Function(DateTime day) eventLoader;
  final List<HolidayOccurrence> Function(DateTime day)? holidayLoader;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime selectedDay, DateTime focusedDay)?
  onDayLongPressed;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;
  final VoidCallback? onTodayPressed;

  const CalendarHeaderSection({
    super.key,
    required this.horizontalInset,
    required this.compact,
    required this.calendarFormat,
    required this.focusedDay,
    required this.selectedDay,
    required this.locale,
    required this.calendarProfile,
    required this.eventLoader,
    this.holidayLoader,
    required this.onDaySelected,
    this.onDayLongPressed,
    required this.onFormatChanged,
    required this.onPageChanged,
    this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = CalendarDesign.primary(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cellHeight = 48.0 + (scale - 1).clamp(0.0, 2.0) * 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 12, horizontalInset, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('calendar_hero_title'),
                      style: CalendarDesign.text(
                        context,
                        size: 23,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('calendar_hero_desc'),
                      style: CalendarDesign.text(
                        context,
                        size: 13,
                        color: CalendarDesign.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: 30,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 6 : 12,
              8,
              compact ? 6 : 12,
              12,
            ),
            decoration: BoxDecoration(
              color: CalendarDesign.surface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: CalendarDesign.border(context)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final format in [
                            CalendarFormat.month,
                            CalendarFormat.twoWeeks,
                          ])
                            TextButton(
                              onPressed: () => onFormatChanged(format),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: calendarFormat == format
                                    ? primary
                                    : CalendarDesign.muted(context),
                                backgroundColor: calendarFormat == format
                                    ? primary.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                context.tr(
                                  format == CalendarFormat.month
                                      ? 'calendar_format_month'
                                      : 'calendar_format_two_weeks',
                                ),
                                style: CalendarDesign.text(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: calendarFormat == format
                                      ? primary
                                      : CalendarDesign.muted(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (onTodayPressed != null)
                        TextButton(
                          onPressed: onTodayPressed,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: primary,
                          ),
                          child: Text(
                            context.tr('p3_today'),
                            style: CalendarDesign.text(
                              context,
                              size: 13,
                              color: primary,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                TableCalendar<dynamic>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  locale: locale,
                  calendarFormat: calendarFormat,
                  startingDayOfWeek: calendarProfile.firstWeekday,
                  weekendDays: calendarProfile.weekendDays,
                  availableCalendarFormats: {
                    CalendarFormat.month: context.tr('calendar_format_month'),
                    CalendarFormat.twoWeeks: context.tr(
                      'calendar_format_two_weeks',
                    ),
                  },
                  eventLoader: (day) => [
                    ...eventLoader(day),
                    ...?holidayLoader?.call(day),
                  ],
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: onDaySelected,
                  onDayLongPressed: onDayLongPressed,
                  onFormatChanged: onFormatChanged,
                  onPageChanged: onPageChanged,
                  rowHeight: cellHeight,
                  daysOfWeekHeight: 30 + (scale - 1).clamp(0, 2) * 12,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: CalendarDesign.text(
                      context,
                      size: 17,
                      weight: FontWeight.w700,
                    ),
                    headerPadding: const EdgeInsets.symmetric(vertical: 6),
                    leftChevronMargin: EdgeInsets.zero,
                    rightChevronMargin: EdgeInsets.zero,
                    leftChevronPadding: const EdgeInsets.all(12),
                    rightChevronPadding: const EdgeInsets.all(12),
                    leftChevronIcon: Icon(
                      Icons.chevron_left_rounded,
                      color: CalendarDesign.ink(context),
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right_rounded,
                      color: CalendarDesign.ink(context),
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: CalendarDesign.text(
                      context,
                      size: 12,
                      color: CalendarDesign.muted(context),
                      weight: FontWeight.w600,
                    ),
                    weekendStyle: CalendarDesign.text(
                      context,
                      size: 12,
                      color: primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    cellMargin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    defaultTextStyle: CalendarDesign.text(
                      context,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                    weekendTextStyle: CalendarDesign.text(
                      context,
                      size: 14,
                      color: primary,
                      weight: FontWeight.w600,
                    ),
                    selectedTextStyle: CalendarDesign.text(
                      context,
                      size: 14,
                      color: CalendarDesign.onPrimary(context),
                      weight: FontWeight.w700,
                    ),
                    todayTextStyle: CalendarDesign.text(
                      context,
                      size: 14,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                    outsideTextStyle: CalendarDesign.text(
                      context,
                      size: 14,
                      color: CalendarDesign.muted(
                        context,
                      ).withValues(alpha: 0.65),
                    ),
                    selectedDecoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 1),
                    ),
                    markersMaxCount: 1,
                  ),
                  calendarBuilders: CalendarBuilders<dynamic>(
                    dowBuilder: (context, day) {
                      final fullLabel = DateFormat.EEEE(locale).format(day);
                      final shortLabel = DateFormat.E(locale).format(day);
                      final style = CalendarDesign.text(
                        context,
                        size: 12,
                        color: calendarProfile.weekendDays.contains(day.weekday)
                            ? primary
                            : CalendarDesign.muted(context),
                        weight: FontWeight.w600,
                      );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final painter = TextPainter(
                            text: TextSpan(text: shortLabel, style: style),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            maxLines: 1,
                          )..layout();
                          final fits =
                              painter.width <= constraints.maxWidth - 4;
                          painter.dispose();
                          // Cột hẹp/chữ lớn dùng tên thứ narrow của CLDR;
                          // trình đọc màn hình và tooltip vẫn có tên đầy đủ.
                          final label = fits
                              ? shortLabel
                              : DateFormat('EEEEE', locale).format(day);
                          return Semantics(
                            label: fullLabel,
                            child: ExcludeSemantics(
                              child: Tooltip(
                                message: fullLabel,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      label,
                                      key: ValueKey(
                                        'calendar-weekday-${day.weekday}',
                                      ),
                                      maxLines: 1,
                                      style: style,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      final holidayCount = events.whereType<HolidayOccurrence>().length;
                      final planCount = events.length - holidayCount;
                      final label = [
                        if (planCount > 0) L10nService().format('calendar_plan_count', {'count': planCount}),
                        if (holidayCount > 0) L10nService().format('calendar_holiday_count', {'count': holidayCount}),
                      ].join(', ');
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Semantics(
                          label: label,
                          child: ExcludeSemantics(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (planCount > 0)
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                                  ),
                                if (planCount > 0 && holidayCount > 0) const SizedBox(width: 4),
                                if (holidayCount > 0)
                                  Icon(
                                    Icons.star_rounded,
                                    key: ValueKey('calendar-holiday-marker-${day.year}-${day.month}-${day.day}'),
                                    size: 9,
                                    color: CalendarDesign.holidayAccent(context),
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
        ],
      ),
    );
  }
}
