/// Date key là ngày dân sự Gregorian, không phải thời điểm trong UTC.
abstract final class CalendarCivilDate {
  static DateTime midnight(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  /// Số ngày lịch giữa hai ngày, bỏ qua giờ. Không lệch khi đổi giờ mùa hè
  /// (DST) vì so sánh theo nửa đêm UTC thay vì nửa đêm giờ địa phương.
  static int daysBetween(DateTime from, DateTime to) =>
      midnight(to).difference(midnight(from)).inDays;

  /// Cộng/trừ theo ngày lịch, giữ nguyên giờ đồng hồ. `Duration(days: n)` là
  /// n×24 giờ nên có thể rơi sang 23:00 hôm trước ở các nước có DST.
  static DateTime addDays(DateTime date, int days) => date.isUtc
      ? DateTime.utc(
          date.year,
          date.month,
          date.day + days,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        )
      : DateTime(
          date.year,
          date.month,
          date.day + days,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );

  /// Nửa đêm giờ địa phương của cùng ngày lịch.
  static DateTime localMidnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
