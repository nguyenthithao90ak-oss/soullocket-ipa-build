import 'lunar_astronomy.dart';

class LunarDate {
  const LunarDate(this.year, this.month, this.day, {this.isLeapMonth = false});
  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;
}

class _LunarMonth {
  const _LunarMonth(this.start, this.end, this.year, this.month, this.leap);
  final int start;
  final int end;
  final int year;
  final int month;
  final bool leap;
}

/// Lịch âm hiện đại theo ngày dân sự; không dùng lịch Trung Quốc cho UTC+7.
abstract final class LunarCalendar {
  static const minYear = 2000;
  static const maxYear = 2050;
  static final _cache = <(int, int), List<_LunarMonth>>{};

  static int _monthEleven(int year, int offset) {
    var low = LunarAstronomy.julianDay(DateTime(year, 12, 19));
    var high = low + 5;
    for (var i = 0; i < 35; i++) {
      final mid = (low + high) / 2;
      if (LunarAstronomy.solarLongitude(mid) < 270) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final solsticeDay = LunarAstronomy.civilDay((low + high) / 2, offset);
    var k = ((low - 2451550.09766) / 29.530588861).floor();
    while (_moonDay(k + 1, offset) <= solsticeDay) {
      k++;
    }
    while (_moonDay(k, offset) > solsticeDay) {
      k--;
    }
    return k;
  }

  static int _moonDay(int k, int offset) =>
      LunarAstronomy.civilDay(LunarAstronomy.newMoon(k), offset);

  static List<_LunarMonth> _span(int year, int offset) {
    return _cache.putIfAbsent((year, offset), () {
      final first = _monthEleven(year, offset);
      final last = _monthEleven(year + 1, offset);
      final starts = [for (var k = first; k <= last; k++) _moonDay(k, offset)];
      var leapIndex = -1;
      if (last - first == 13) {
        for (var i = 1; i < starts.length - 1; i++) {
          final left = LunarAstronomy.solarLongitude(
            starts[i] - 0.5 - offset / 24,
          );
          final right = LunarAstronomy.solarLongitude(
            starts[i + 1] - 0.5 - offset / 24,
          );
          if ((left / 30).floor() == (right / 30).floor()) {
            leapIndex = i;
            break;
          }
        }
      }
      if (last - first != 12 && leapIndex < 0) {
        throw StateError('Cannot resolve lunar leap month');
      }
      var month = 11;
      var lunarYear = year;
      final months = <_LunarMonth>[];
      for (var i = 0; i < starts.length - 1; i++) {
        final leap = i == leapIndex;
        if (i > 0 && !leap) {
          month = month % 12 + 1;
          if (month == 1) lunarYear++;
        }
        months.add(
          _LunarMonth(starts[i], starts[i + 1], lunarYear, month, leap),
        );
      }
      return List.unmodifiable(months);
    });
  }

  static bool supports(DateTime date) =>
      date.year >= minYear && date.year <= maxYear;

  static LunarDate? fromSolar(DateTime date, {int offsetHours = 7}) {
    if (!supports(date) || (offsetHours != 7 && offsetHours != 8)) return null;
    final day = LunarAstronomy.julianDay(date).floor() + 1;
    for (final year in [date.year - 1, date.year]) {
      for (final month in _span(year, offsetHours)) {
        if (day >= month.start && day < month.end) {
          return LunarDate(
            month.year,
            month.month,
            day - month.start + 1,
            isLeapMonth: month.leap,
          );
        }
      }
    }
    return null;
  }

  static DateTime? toSolar(LunarDate date, {int offsetHours = 7}) {
    if (date.year < minYear - 1 ||
        date.year > maxYear ||
        date.month < 1 ||
        date.month > 12 ||
        date.day < 1 ||
        date.day > 30 ||
        (offsetHours != 7 && offsetHours != 8)) {
      return null;
    }
    for (final year in [date.year - 1, date.year]) {
      for (final month in _span(year, offsetHours)) {
        if (month.year == date.year &&
            month.month == date.month &&
            month.leap == date.isLeapMonth &&
            date.day <= month.end - month.start) {
          final result = LunarAstronomy.dateFromDay(month.start + date.day - 1);
          return supports(result) ? result : null;
        }
      }
    }
    return null;
  }

  /// Tháng nhuận: chỉ lặp ở năm có đúng tháng nhuận đã chọn.
  static DateTime? nextOccurrence({
    required int month,
    required int day,
    required DateTime from,
    bool leapMonth = false,
    int offsetHours = 7,
  }) {
    final today = DateTime(from.year, from.month, from.day);
    final startYear = today.year - 1 < minYear - 1
        ? minYear - 1
        : today.year - 1;
    for (var year = startYear; year <= maxYear; year++) {
      final date = toSolar(
        LunarDate(year, month, day, isLeapMonth: leapMonth),
        offsetHours: offsetHours,
      );
      if (date != null && !date.isBefore(today)) return date;
    }
    return null;
  }
}
