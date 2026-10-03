import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'calendar_civil_date.dart';
import 'calendar_reminder_times.dart';
import 'calendar_time_zone.dart';
import 'calendar_timed_event.dart';
import '../../models/soul_event.dart';
import 'holiday_occurrence_resolver.dart';

class CalendarLocalReminder {
  const CalendarLocalReminder({required this.key, required this.dateKey,
    required this.time, required this.title, required this.dayBefore, required this.source});
  final String key;
  final String dateKey;
  final DateTime time;
  final String title;
  final bool dayBefore;
  final String source;
}

abstract final class CalendarLocalReminderPlanner {
  static List<CalendarLocalReminder> build({required DateTime now,
    required Object? calendarData, required Iterable<HolidayOccurrence> holidays,
    required String Function(PresetHoliday) holidayName, String? timeZoneId}) {
    final result = <CalendarLocalReminder>[];
    void add(String key, DateTime date, String title, String source, DateTime? start) {
      final times = CalendarReminderTimes.forDate(date, timeZone: CalendarTimeZone.locationFor(timeZoneId));
      for (final previous in [false, true]) {
        final time = previous ? times.dayBefore : start ?? times.onEventDay;
        if (!time.isAfter(now)) continue;
        result.add(CalendarLocalReminder(key: '$source:$key:${previous ? 'before' : 'day'}',
          dateKey: CalendarCivilDate.key(date), time: time, title: title,
          dayBefore: previous, source: source));
      }
    }
    if (calendarData is Map) {
      for (final day in calendarData.entries) {
        final dateKey = day.key.toString();
        final date = CalendarCivilDate.parse(dateKey);
        if (date == null || day.value is! Map) continue;
        for (final event in (day.value as Map).entries) {
          final raw = event.value;
          if (raw is! Map) continue;
          final title = raw['title']?.toString().trim() ?? '';
          if (title.isEmpty) continue;
          final timed = CalendarTimedEvent.fromJson(raw['timing'], dateKey: dateKey);
          // Timing sai không tự biến thành sự kiện cả ngày.
          if (raw['timing'] != null && timed == null) continue;
          add('$dateKey:${event.key}', date, title, 'calendar', timed?.start);
        }
      }
    }
    for (final holiday in holidays) {
      add(holiday.occurrenceId, holiday.date, holidayName(holiday.holiday), 'holiday', null);
    }
    return result..sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
  }
}

typedef CalendarReminderScheduler = Future<bool> Function({required int id,
  required String title, required String body, required DateTime scheduledDate,
  required Map<String, dynamic> data});

/// Transport thay được trong test; chỉ hủy payload của lịch, giữ tính năng khác.
class CalendarReminderReconciler {
  const CalendarReminderReconciler({required this.pending, required this.cancel, required this.schedule});
  static const payloadType = 'calendar_reminder_v2';
  static const maxReminders = 24;
  final Future<List<PendingNotificationRequest>> Function() pending;
  final Future<void> Function(Iterable<int>) cancel;
  final CalendarReminderScheduler schedule;

  static Map<String, dynamic>? payload(String? raw) {
    try {
      final data = jsonDecode(raw ?? '');
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) { return null; }
  }

  Future<bool> reconcile({required String? uid, required String? houseId,
    required List<CalendarLocalReminder> reminders, required bool enabled,
    required bool Function() active, required String Function(CalendarLocalReminder) title,
    required String Function(CalendarLocalReminder) body}) async {
    final existing = await pending();
    if (!active()) return false;
    final owned = {for (final item in existing)
      if (payload(item.payload)?['type'] == payloadType) item.id: item};
    final others = {for (final item in existing) if (!owned.containsKey(item.id)) item.id};
    final budget = (60 - others.length).clamp(0, maxReminders);
    final planned = <int, ({CalendarLocalReminder item, String title, String body, Map<String, dynamic> data})>{};
    if (uid != null && enabled) {
      for (final item in reminders.take(budget)) {
        final identity = '$uid\u0000${houseId ?? ''}\u0000${item.key}';
        var hash = 0x811c9dc5;
        for (final unit in identity.codeUnits) { hash = ((hash ^ unit) * 0x01000193) & 0xffffffff; }
        var id = 0x10000000 | (hash & 0x0fffffff);
        while (!others.add(id)) { id = 0x10000000 | ((id + 1) & 0x0fffffff); }
        planned[id] = (item: item, title: title(item), body: body(item), data: {
          'type': payloadType, 'screen': 'calendar', 'accountUid': uid,
          'houseId': houseId, 'reminderKey': item.key, 'dateKey': item.dateKey,
          'scheduledMs': item.time.millisecondsSinceEpoch});
      }
    }
    await cancel(owned.keys.where((id) => !planned.containsKey(id)));
    if (!active()) return false;
    for (final entry in planned.entries) {
      final plan = entry.value;
      final old = owned[entry.key];
      final data = payload(old?.payload);
      if (old?.title == plan.title && old?.body == plan.body && data?['accountUid'] == uid &&
          data?['houseId'] == houseId && data?['reminderKey'] == plan.item.key &&
          data?['scheduledMs'] == plan.data['scheduledMs']) continue;
      final saved = await schedule(id: entry.key, title: plan.title, body: plan.body,
        scheduledDate: plan.item.time, data: plan.data);
      if (!active()) { await cancel([entry.key]); return false; }
      if (!saved) return false;
    }
    return true;
  }
}
