import 'package:timezone/timezone.dart' as tz;

/// Hai mốc nhắc 9 giờ theo ngày dân sự và múi giờ thiết bị/lựa chọn.
/// Ngày hôm trước có thể cách 23/25 giờ khi đổi DST.
class CalendarReminderTimes {
  const CalendarReminderTimes._({
    required this.onEventDay,
    required this.dayBefore,
  });

  final DateTime onEventDay;
  final DateTime dayBefore;

  factory CalendarReminderTimes.forDate(
    DateTime date, {
    tz.Location? timeZone,
  }) {
    DateTime atNine(int dayOffset) => timeZone == null
        ? DateTime(date.year, date.month, date.day + dayOffset, 9)
        : tz.TZDateTime(
            timeZone,
            date.year,
            date.month,
            date.day + dayOffset,
            9,
          );

    return CalendarReminderTimes._(
      onEventDay: atNine(0),
      dayBefore: atNine(-1),
    );
  }
}
