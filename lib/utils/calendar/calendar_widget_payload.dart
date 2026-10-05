import 'dart:async';

import '../calendar_widget_snapshot.dart';
import 'calendar_civil_date.dart';

/// Payload nguyên tử: native đọc một JSON, không ghép các field của hai phiên.
abstract final class CalendarWidgetPayload {
  static const version = 2;

  static CalendarWidgetSnapshot? merge(
    CalendarWidgetSnapshot? plan,
    CalendarWidgetSnapshot? holiday,
  ) {
    if (plan == null) return holiday;
    if (holiday == null) return plan;
    final order = CalendarCivilDate.key(
      plan.date,
    ).compareTo(CalendarCivilDate.key(holiday.date));
    if (order < 0) return plan;
    if (order > 0) return holiday;
    return CalendarWidgetSnapshot(
      date: plan.date,
      titles: List.unmodifiable([...plan.titles, ...holiday.titles]),
    );
  }

  static Map<String, Object?> empty({
    String locale = 'en',
    String titleLabel = '',
    String emptyLabel = '',
  }) => {
    'version': version,
    'enabled': false,
    'uid': '',
    'houseId': '',
    'dateKey': '',
    'nextDate': '',
    'events': '',
    'locale': locale,
    'titleLabel': titleLabel,
    'emptyLabel': emptyLabel,
  };

  static Map<String, Object?> create({
    required String uid,
    required String houseId,
    required CalendarWidgetSnapshot? event,
    required String locale,
    required String marketCode,
    required String? timeZone,
    required String dateLabel,
    required String countdown,
    required String todayLabel,
    required String tomorrowLabel,
    required String daysLeftTemplate,
    String titleLabel = '',
    String emptyLabel = '',
  }) => {
    'version': version,
    'enabled': event != null && uid.isNotEmpty && houseId.isNotEmpty,
    'uid': uid,
    'houseId': houseId,
    'dateKey': event == null ? '' : CalendarCivilDate.key(event.date),
    'nextDate': event == null ? '' : dateLabel,
    'countdown': event == null ? '' : countdown,
    'events': event?.titles.map((title) => '• $title').join('\n') ?? '',
    'locale': locale,
    'marketCode': marketCode,
    'timeZone': timeZone ?? '',
    'todayLabel': todayLabel,
    'tomorrowLabel': tomorrowLabel,
    'daysLeftTemplate': daysLeftTemplate,
    'titleLabel': titleLabel,
    'emptyLabel': emptyLabel,
  };
}

/// Serialize commit/clear để một thao tác native đang chờ không ghi đè sign out.
class CalendarWidgetWriteQueue {
  Future<void> _tail = Future.value();

  Future<void> enqueue(Future<void> Function() commit) {
    final task = _tail.then((_) => commit());
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }
}
