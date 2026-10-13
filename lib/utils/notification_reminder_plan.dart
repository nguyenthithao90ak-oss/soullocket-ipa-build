import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

abstract final class NotificationReminderPlan {
  static const variantCount = 20;
  static const firstSleepId = 21450045;
  static const inactivityId = 21450066;

  static bool ownsSleepId(int id) =>
      id >= firstSleepId && id < firstSleepId + variantCount;

  static String messageKey(int variant) =>
      'notif_sleep_good_night_${(variant % variantCount + 1).toString().padLeft(2, '0')}';

  /// Ngày dân sự liên tục: không reset năm mới hoặc lệch vào ngày đổi giờ.
  static int variantForDate(DateTime date) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).difference(DateTime.utc(2020)).inDays %
      variantCount;

  static List<tz.TZDateTime> sleepNights({
    required tz.TZDateTime now,
    required String clock,
    int count = variantCount,
  }) {
    final parts = clock.split(':');
    final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final valid =
        hour != null &&
        hour >= 0 &&
        hour < 24 &&
        minute != null &&
        minute >= 0 &&
        minute < 60;
    final h = valid ? hour : 22;
    final m = valid ? minute : 15;
    final today = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      h,
      m,
    );
    final firstOffset = today.isAfter(now) ? 0 : 1;
    return [
      for (var offset = 0; offset < count.clamp(0, variantCount); offset++)
        tz.TZDateTime(
          now.location,
          now.year,
          now.month,
          now.day + firstOffset + offset,
          h,
          m,
        ),
    ];
  }

  /// 19:30 đầu tiên sau ít nhất 72 giờ kể từ lần dùng app cuối.
  static tz.TZDateTime inactivityTime(tz.TZDateTime lastActivity) {
    final due = lastActivity.add(const Duration(days: 3));
    var time = tz.TZDateTime(
      lastActivity.location,
      due.year,
      due.month,
      due.day,
      19,
      30,
    );
    if (time.isBefore(due)) {
      time = tz.TZDateTime(
        lastActivity.location,
        due.year,
        due.month,
        due.day + 1,
        19,
        30,
      );
    }
    return time;
  }

  static int sleepBudget({
    required int otherCount,
    required int totalLimit,
    required bool reserveInactivity,
  }) => (totalLimit - otherCount - (reserveInactivity ? 1 : 0))
      .clamp(0, variantCount)
      .toInt();
}

class PlannedPersonalReminder {
  const PlannedPersonalReminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    required this.data,
  });
  final int id;
  final DateTime time;
  final String title;
  final String body;
  final Map<String, dynamic> data;
}

typedef PersonalReminderScheduler =
    Future<bool> Function({
      required int id,
      required String title,
      required String body,
      required DateTime scheduledDate,
      required Map<String, dynamic> data,
    });

/// Guard trước/sau mỗi await ngăn UID cũ đặt lại lịch sau khi đổi phiên.
/// Chỉ hủy ID sở hữu, giữ nguyên lịch của các tính năng khác.
class PersonalReminderReconciler {
  const PersonalReminderReconciler({
    required this.pending,
    required this.cancel,
    required this.schedule,
  });
  final Future<List<PendingNotificationRequest>> Function() pending;
  final Future<void> Function(Iterable<int>) cancel;
  final PersonalReminderScheduler schedule;

  Future<bool> reconcile({
    required bool Function(int id) owns,
    required List<PlannedPersonalReminder> reminders,
    required bool Function() active,
  }) async {
    final existing = await pending();
    if (!active()) return false;
    final owned = {
      for (final item in existing)
        if (owns(item.id)) item.id: item,
    };
    final wantedIds = reminders.map((item) => item.id).toSet();
    await cancel(owned.keys.where((id) => !wantedIds.contains(id)));
    if (!active()) return false;
    for (final item in reminders) {
      if (!active()) return false;
      final old = owned[item.id];
      if (old?.title == item.title &&
          old?.body == item.body &&
          old?.payload == jsonEncode(item.data)) {
        continue;
      }
      final saved = await schedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: item.time,
        data: item.data,
      );
      if (!active()) {
        await cancel([item.id]);
        return false;
      }
      if (!saved) return false;
    }
    return true;
  }
}
