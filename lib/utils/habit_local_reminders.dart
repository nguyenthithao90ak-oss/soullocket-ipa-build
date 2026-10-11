import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class HabitLocalReminder {
  const HabitLocalReminder({
    required this.habitId,
    required this.name,
    required this.dateKey,
    required this.time,
  });

  final String habitId;
  final String name;
  final String dateKey;
  final DateTime time;
  String get key => '$habitId:$dateKey';
}

abstract final class HabitLocalReminderPlanner {
  static const horizonDays = 7;

  static String dateKey(DateTime date) =>
      '${date.day}-${date.month}-${date.year}';

  static (int, int)? parseTime(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    return hour < 24 && minute < 60 ? (hour, minute) : null;
  }

  /// Dựng từng ngày dân sự, không cộng 24 giờ qua ranh đổi giờ mùa hè.
  /// Lịch một lần cho phép bỏ ngày đã hoàn thành mà không tắt các ngày sau.
  static List<HabitLocalReminder> build({
    required Object? data,
    required DateTime now,
  }) {
    if (data is! Map) return const [];
    final result = <HabitLocalReminder>[];
    for (final entry in data.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final habitId = entry.key as String;
      final raw = entry.value as Map;
      final name = raw['name'];
      final clock = parseTime(raw['time']);
      if (habitId.isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          clock == null) {
        continue;
      }
      final completed = raw['completed_dates'];
      for (var day = 0; day < horizonDays; day++) {
        final time = now is tz.TZDateTime
            ? tz.TZDateTime(
                now.location,
                now.year,
                now.month,
                now.day + day,
                clock.$1,
                clock.$2,
              )
            : now.isUtc
            ? DateTime.utc(
                now.year,
                now.month,
                now.day + day,
                clock.$1,
                clock.$2,
              )
            : DateTime(now.year, now.month, now.day + day, clock.$1, clock.$2);
        final key = dateKey(time);
        if (!time.isAfter(now) ||
            (completed is Map && completed[key] == true)) {
          continue;
        }
        result.add(
          HabitLocalReminder(
            habitId: habitId,
            name: name.trim(),
            dateKey: key,
            time: time,
          ),
        );
      }
    }
    return result..sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
  }
}

typedef HabitReminderScheduler =
    Future<bool> Function({
      required int id,
      required String title,
      required String body,
      required DateTime scheduledDate,
      required Map<String, dynamic> data,
    });

class HabitReminderResult {
  const HabitReminderResult({
    this.count = 0,
    this.through,
    this.limited = false,
    this.failed = false,
  });
  final int count;
  final DateTime? through;
  final bool limited;
  final bool failed;
}

/// Chỉ sở hữu payload thói quen. Không hủy nhắc Lịch, Sự kiện hay Giấc ngủ.
class HabitReminderReconciler {
  const HabitReminderReconciler({
    required this.pending,
    required this.cancel,
    required this.schedule,
    this.maxReminders = 32,
    this.maxTotal = 60,
  });
  static const payloadType = 'habit_reminder_v1';
  final Future<List<PendingNotificationRequest>> Function() pending;
  final Future<void> Function(Iterable<int>) cancel;
  final HabitReminderScheduler schedule;
  final int maxReminders;
  final int maxTotal;

  static Map<String, dynamic>? payload(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '');
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<HabitReminderResult> reconcile({
    required String? uid,
    required String? houseId,
    required List<HabitLocalReminder>? reminders,
    required bool enabled,
    required bool clearScope,
    required String timeZoneId,
    required bool Function() active,
    required String Function(HabitLocalReminder) title,
    required String Function(HabitLocalReminder) body,
  }) async {
    final existing = await pending();
    if (!active()) return const HabitReminderResult();
    final owned = {
      for (final item in existing)
        if (payload(item.payload)?['type'] == payloadType) item.id: item,
    };
    final others = {
      for (final item in existing)
        if (!owned.containsKey(item.id)) item.id,
    };
    if (uid == null || !enabled || clearScope) {
      await cancel(owned.keys);
      return const HabitReminderResult();
    }

    // Chờ snapshot đầu cùng tài khoản thì giữ lịch đã lưu trên OS.
    // Đổi UID/House hoặc mất quyền không được giữ lịch của scope cũ.
    if (houseId == null || reminders == null) {
      await cancel(
        owned.entries
            .where((entry) {
              final data = payload(entry.value.payload);
              return data?['accountUid'] != uid ||
                  (houseId != null && data?['houseId'] != houseId);
            })
            .map((entry) => entry.key),
      );
      if (!active()) return const HabitReminderResult();
      final retained = owned.values.where((item) {
        final data = payload(item.payload);
        return data?['accountUid'] == uid &&
            (houseId == null || data?['houseId'] == houseId);
      });
      final times =
          retained
              .map((item) => payload(item.payload)?['scheduledMs'])
              .whereType<int>()
              .toList()
            ..sort();
      return HabitReminderResult(
        count: retained.length,
        through: times.isEmpty
            ? null
            : DateTime.fromMillisecondsSinceEpoch(times.last),
      );
    }

    final budget = (maxTotal - others.length).clamp(0, maxReminders).toInt();
    final takenIds = <int>{...others};
    final planned =
        <
          int,
          ({
            HabitLocalReminder item,
            String title,
            String body,
            Map<String, dynamic> data,
          })
        >{};
    for (final item in reminders.take(budget)) {
      final identity = '$uid\u0000$houseId\u0000${item.key}';
      var hash = 0x811c9dc5;
      for (final unit in identity.codeUnits) {
        hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
      }
      var id = 0x30000000 | (hash & 0x0fffffff);
      while (!takenIds.add(id)) {
        id = 0x30000000 | ((id + 1) & 0x0fffffff);
      }
      planned[id] = (
        item: item,
        title: title(item),
        body: body(item),
        data: {
          'type': payloadType,
          'screen': 'habits',
          'accountUid': uid,
          'houseId': houseId,
          'habitId': item.habitId,
          'dateKey': item.dateKey,
          'scheduledMs': item.time.millisecondsSinceEpoch,
          'timeZoneId': timeZoneId,
        },
      );
    }
    await cancel(owned.keys.where((id) => !planned.containsKey(id)));
    if (!active()) return const HabitReminderResult();
    var count = 0;
    DateTime? through;
    for (final entry in planned.entries) {
      final plan = entry.value;
      final old = owned[entry.key];
      final data = payload(old?.payload);
      final unchanged =
          old?.title == plan.title &&
          old?.body == plan.body &&
          data?['accountUid'] == uid &&
          data?['houseId'] == houseId &&
          data?['habitId'] == plan.item.habitId &&
          data?['dateKey'] == plan.item.dateKey &&
          data?['scheduledMs'] == plan.data['scheduledMs'] &&
          data?['timeZoneId'] == timeZoneId;
      if (!unchanged) {
        final saved = await schedule(
          id: entry.key,
          title: plan.title,
          body: plan.body,
          scheduledDate: plan.item.time,
          data: plan.data,
        );
        if (!active()) {
          await cancel([entry.key]);
          return const HabitReminderResult();
        }
        if (!saved) {
          return HabitReminderResult(
            count: count,
            through: through,
            failed: true,
          );
        }
      }
      count++;
      through = plan.item.time;
    }
    return HabitReminderResult(
      count: count,
      through: through,
      limited: reminders.length > budget,
    );
  }
}
