/// Biểu diễn phụ cho ngày đã chọn. Ngày lưu chính vẫn luôn là Gregorian dân sự.
abstract final class CalendarSecondaryDate {
  // Epoch dân sự của ICU: JDN 1948440 (19/7/622 Gregorian).
  static const _civilEpoch = 1948440;
  static String? format(DateTime date, String? calendar) {
    switch (calendar) {
      case 'buddhist':
        return '${date.day}/${date.month}/${date.year + 543}';
      case 'islamic-civil':
        final value = _toIslamicCivil(date.year, date.month, date.day);
        return '${value.$3}/${value.$2}/${value.$1}';
      default:
        return null;
    }
  }

  /// Lịch Hồi giáo dân sự dạng tabular, dùng cho nhãn tham khảo ổn định
  /// offline; không đại diện cho ngày quan sát trăng hay ngày nghỉ lễ.
  static (int, int, int) _toIslamicCivil(int year, int month, int day) {
    final jd = _gregorianToJulianDay(year, month, day);
    final islamicYear = ((30 * (jd - _civilEpoch) + 10646) / 10631).floor();
    final first = _islamicToJulianDay(islamicYear, 1, 1);
    final islamicMonth = (((jd - 29 - first) / 29.5).ceil() + 1).clamp(1, 12);
    final islamicDay =
        jd - _islamicToJulianDay(islamicYear, islamicMonth, 1) + 1;
    return (islamicYear, islamicMonth, islamicDay);
  }

  static int _gregorianToJulianDay(int year, int month, int day) {
    final a = ((14 - month) / 12).floor();
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;
  }

  static int _islamicToJulianDay(int year, int month, int day) {
    return day +
        ((29.5 * (month - 1)).ceil()) +
        (year - 1) * 354 +
        ((3 + 11 * year) / 30).floor() +
        _civilEpoch -
        1;
  }
}
