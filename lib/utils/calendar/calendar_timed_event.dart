import 'package:timezone/timezone.dart' as tz;

import 'calendar_civil_date.dart';
import 'calendar_time_zone.dart';

/// Giữ thời điểm tuyệt đối và múi giờ lúc tạo; đổi vùng/ngôn ngữ không đổi giờ.
class CalendarTimedEvent {
  const CalendarTimedEvent({
    required this.startUtcMs,
    required this.endUtcMs,
    required this.timeZoneId,
  });

  final int startUtcMs;
  final int endUtcMs;
  final String timeZoneId;

  DateTime get start => CalendarTimeZone.fromMilliseconds(startUtcMs, timeZoneId);
  DateTime get end => CalendarTimeZone.fromMilliseconds(endUtcMs, timeZoneId);

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'startUtcMs': startUtcMs,
    'endUtcMs': endUtcMs,
    'timeZoneId': timeZoneId,
  };

  static CalendarTimedEvent? fromJson(Object? raw, {String? dateKey}) {
    if (raw is! Map || raw['schemaVersion'] != 1) return null;
    final start = raw['startUtcMs'];
    final end = raw['endUtcMs'];
    final zone = raw['timeZoneId'];
    if (start is! int || end is! int || zone is! String ||
        !CalendarTimeZone.isValidId(zone) || end <= start ||
        end - start > const Duration(days: 7).inMilliseconds) return null;
    final event = CalendarTimedEvent(startUtcMs: start, endUtcMs: end, timeZoneId: zone);
    try {
      if (dateKey != null && CalendarCivilDate.key(event.start) != dateKey) return null;
      return event;
    } catch (_) {
      return null;
    }
  }

  /// Không để TZDateTime tự đẩy giờ DST bị thiếu sang giờ khác. Liệt kê
  /// thời điểm thực sự khớp giờ tường: 0 = thiếu; 2 = lặp cần người dùng chọn.
  static List<tz.TZDateTime> candidates({
    required DateTime date,
    required int hour,
    required int minute,
    required String timeZoneId,
  }) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return const [];
    final location = CalendarTimeZone.locationFor(timeZoneId)!;
    final wall = DateTime.utc(date.year, date.month, date.day, hour, minute);
    final offsets = location.zones.map((zone) => zone.offset.inMilliseconds).toSet();
    final result = <tz.TZDateTime>[];
    for (final offset in offsets) {
      final value = tz.TZDateTime.fromMillisecondsSinceEpoch(
        location, wall.millisecondsSinceEpoch - offset,
      );
      if (value.year == date.year && value.month == date.month &&
          value.day == date.day && value.hour == hour && value.minute == minute) {
        result.add(value);
      }
    }
    return result..sort((a, b) => a.compareTo(b));
  }
}
