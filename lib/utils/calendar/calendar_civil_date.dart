/// Date key là ngày dân sự Gregorian, không phải thời điểm trong UTC.
abstract final class CalendarCivilDate {
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
