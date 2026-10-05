/// Date key là ngày dân sự Gregorian, không phải thời điểm trong UTC.
abstract final class CalendarCivilDate {
  static DateTime midnight(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  static int daysBetween(DateTime from, DateTime to) =>
      midnight(to).difference(midnight(from)).inDays;

  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null && key(parsed) == value ? parsed : null;
  }
}
