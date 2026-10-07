import 'dart:math' as math;

import 'calendar_civil_date.dart';
import 'calendar_time_zone.dart';

/// Bộ đếm từ ngày bắt đầu, dùng cùng ngày dân sự/múi giờ với Lịch chung.
/// Ngày bắt đầu là ngày 0; giờ/phút/giây là phần giờ đồng hồ, không phải
/// thời lượng thực đã trôi qua khi chuyển DST.
class RelationshipDuration {
  const RelationshipDuration({
    this.totalDays = 0,
    this.years = 0,
    this.months = 0,
    this.days = 0,
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
  });

  final int totalDays;
  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  static RelationshipDuration at(
    String? startDate, {
    DateTime? instant,
    String? timeZoneId,
  }) {
    final start = _parseCivilStart(startDate);
    if (start == null) return const RelationshipDuration();
    final now = CalendarTimeZone.fromMilliseconds(
      (instant ?? DateTime.now()).millisecondsSinceEpoch,
      timeZoneId,
    );
    final totalDays = CalendarCivilDate.daysBetween(start, now);
    if (totalDays < 0) return const RelationshipDuration();

    // Tìm số tháng lịch đã đủ. Mốc 31/1 + một tháng là 28/2 (hoặc 29/2),
    // không mượn một lần số ngày tháng trước rồi để phần ngày bị âm.
    var totalMonths = (now.year - start.year) * 12 + now.month - start.month;
    var anchor = _addMonthsClamped(start, totalMonths);
    if (CalendarCivilDate.daysBetween(anchor, now) < 0) {
      totalMonths--;
      anchor = _addMonthsClamped(start, totalMonths);
    }
    final wallClock = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ).difference(start);

    return RelationshipDuration(
      totalDays: totalDays,
      years: totalMonths ~/ 12,
      months: totalMonths % 12,
      days: CalendarCivilDate.daysBetween(anchor, now),
      hours: wallClock.isNegative ? 0 : wallClock.inHours % 24,
      minutes: wallClock.isNegative ? 0 : wallClock.inMinutes % 60,
      seconds: wallClock.isNegative ? 0 : wallClock.inSeconds % 60,
    );
  }

  static DateTime? _parseCivilStart(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.length < 10) return null;
    final date = CalendarCivilDate.parse(value.substring(0, 10));
    if (date == null) return null;
    if (value.length == 10) return date;
    if (DateTime.tryParse(value) == null) return null;

    // startDate là ngày đã chọn. Không chuyển tiền tố ngày sang UTC vì
    // dữ liệu ISO cũ có offset có thể bị đẩy sang hôm trước/hôm sau.
    final wallClock = value.replaceFirst(
      RegExp(r'([zZ]|[+-]\d{2}(?::?\d{2})?)$'),
      '',
    );
    final parsed = DateTime.tryParse('${wallClock}Z');
    if (parsed == null || !CalendarCivilDate.isSameDay(parsed, date)) {
      return null;
    }
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }

  static DateTime _addMonthsClamped(DateTime date, int months) {
    final targetMonth = DateTime.utc(date.year, date.month + months);
    final lastDay = DateTime.utc(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    return DateTime.utc(
      targetMonth.year,
      targetMonth.month,
      math.min(date.day, lastDay),
    );
  }
}
