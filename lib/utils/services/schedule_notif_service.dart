import 'package:firebase_database/firebase_database.dart';

import 'core/cloud_functions_helper.dart';
import 'schedule_notification_presenter.dart';

class ScheduleNotifService {
  static final ScheduleNotifService _instance =
      ScheduleNotifService._internal();

  factory ScheduleNotifService() => _instance;

  ScheduleNotifService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<String?> addCustomEvent({
    required String houseId,
    required String name,
    required DateTime date,
    bool repeat = false,
  }) async {
    final ref = _db.ref('houses/$houseId/settings/customEvents').push();
    await ref.set({
      'name': name.trim(),
      'date': '${date.year}-${_pad(date.month)}-${_pad(date.day)}',
      'repeat': repeat,
      'ts': ServerValue.timestamp,
    });
    return ref.key;
  }

  Future<void> deleteCustomEvent(String houseId, String eventId) async {
    await _db.ref('houses/$houseId/settings/customEvents/$eventId').remove();
  }

  Stream<List<UpcomingEvent>> streamUpcomingEvents(String houseId) {
    return _db
        .ref('houses/$houseId/settings/customEvents')
        .onValue
        .asyncMap((customEvent) async {
      final calSnap = await _db.ref('houses/$houseId/calendar').get();
      final events = <UpcomingEvent>[];
      final today = _todayMidnight();

      if (calSnap.exists && calSnap.value is Map) {
        final calData = Map<dynamic, dynamic>.from(calSnap.value as Map);
        for (final dateKey in calData.keys) {
          final dateMs = _parseDateKey(dateKey.toString());
          if (dateMs == null) continue;
          final dayObj = calData[dateKey];
          if (dayObj is! Map) continue;
          for (final eventId in dayObj.keys) {
            final eventRaw = dayObj[eventId];
            final title = eventRaw is Map
                ? eventRaw['title']?.toString() ?? 'Sự kiện'
                : 'Sự kiện';
            events.add(
              UpcomingEvent(
                eventKey: 'cal:$dateKey:$eventId',
                dateKey: dateKey.toString(),
                dateMs: dateMs,
                title: title,
                source: 'calendar',
                daysUntil: _daysUntil(dateMs, today),
              ),
            );
          }
        }
      }

      if (customEvent.snapshot.exists && customEvent.snapshot.value is Map) {
        final customData =
            Map<dynamic, dynamic>.from(customEvent.snapshot.value as Map);
        for (final key in customData.keys) {
          final value = customData[key];
          if (value is! Map) continue;
          final dateStr = value['date']?.toString() ?? '';
          final dateMs = _parseDateKey(dateStr);
          if (dateMs == null) continue;

          DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
          if (value['repeat'] == true) {
            final now = DateTime.now();
            eventDate = DateTime(now.year, eventDate.month, eventDate.day);
            final todayDate = DateTime(now.year, now.month, now.day);
            if (eventDate.isBefore(todayDate)) {
              eventDate =
                  DateTime(now.year + 1, eventDate.month, eventDate.day);
            }
          }

          final resolvedMs = eventDate.millisecondsSinceEpoch;
          events.add(
            UpcomingEvent(
              eventKey: 'cust:$key',
              dateKey:
                  '${eventDate.year}-${_pad(eventDate.month)}-${_pad(eventDate.day)}',
              dateMs: resolvedMs,
              title: value['name']?.toString() ?? 'Sự kiện',
              source: 'custom',
              daysUntil: _daysUntil(resolvedMs, today),
            ),
          );
        }
      }

      final identity = await _loadIdentityContext(houseId);
      events.addAll(_buildSystemEvents(identity, today));

      events.removeWhere((event) => event.daysUntil < 0);
      events.sort((left, right) => left.daysUntil.compareTo(right.daysUntil));
      return events;
    });
  }

  Future<void> sendScheduleNotification({
    required String toHouseId,
    required String notifId,
    required String title,
    required String message,
    required String sourceLabel,
    required String eventKey,
    required String eventDate,
    required String eventTitle,
  }) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      'createScheduleNotificationSecure',
      payload: <String, dynamic>{
        'houseId': toHouseId,
        'notificationId': notifId,
        'title': title,
        'message': message,
        'sourceLabel': sourceLabel,
        'eventKey': eventKey,
        'eventDate': eventDate,
        'eventTitle': eventTitle,
      },
    );
  }

  Future<void> checkAndNotify(String houseId) async {
    final today = _todayMidnight();
    final calSnap = await _db.ref('houses/$houseId/calendar').get();
    final customSnap =
        await _db.ref('houses/$houseId/settings/customEvents').get();
    final identity = await _loadIdentityContext(houseId);

    final events = <UpcomingEvent>[];

    if (calSnap.exists && calSnap.value is Map) {
      final data = Map<dynamic, dynamic>.from(calSnap.value as Map);
      for (final dateKey in data.keys) {
        final dateMs = _parseDateKey(dateKey.toString());
        if (dateMs == null) continue;
        final dayObj = data[dateKey];
        if (dayObj is! Map) continue;
        for (final eventId in dayObj.keys) {
          final eventRaw = dayObj[eventId];
          final title =
              eventRaw is Map ? eventRaw['title']?.toString() ?? '' : '';
          events.add(
            UpcomingEvent(
              eventKey: 'cal:$dateKey:$eventId',
              dateKey: dateKey.toString(),
              dateMs: dateMs,
              title: title,
              source: 'calendar',
              daysUntil: _daysUntil(dateMs, today),
            ),
          );
        }
      }
    }

    if (customSnap.exists && customSnap.value is Map) {
      final data = Map<dynamic, dynamic>.from(customSnap.value as Map);
      for (final key in data.keys) {
        final value = data[key];
        if (value is! Map) continue;
        final dateStr = value['date']?.toString() ?? '';
        final dateMs = _parseDateKey(dateStr);
        if (dateMs == null) continue;
        events.add(
          UpcomingEvent(
            eventKey: 'cust:$key',
            dateKey: dateStr,
            dateMs: dateMs,
            title: value['name']?.toString() ?? '',
            source: 'custom',
            daysUntil: _daysUntil(dateMs, today),
          ),
        );
      }
    }

    events.addAll(_buildSystemEvents(identity, today));

    for (final event in events) {
      if (event.daysUntil < 0 || event.daysUntil > 3) continue;

      final notifId =
          'sched_d${event.daysUntil}_${event.eventKey.hashCode.toUnsigned(32).toRadixString(16)}';
      final presentation = describeScheduleNotification(
        notificationId: notifId,
        fallbackTitle: _fallbackScheduleTitle(event.daysUntil),
        fallbackMessage: _fallbackScheduleMessage(event.daysUntil, event.title),
        eventTitle: event.title,
        eventDate: event.dateKey,
        identity: identity,
      );

      await sendScheduleNotification(
        toHouseId: houseId,
        notifId: notifId,
        title: presentation.title,
        message: presentation.message,
        sourceLabel: presentation.sourceLabel,
        eventKey: event.eventKey,
        eventDate: event.dateKey,
        eventTitle: event.title,
      );
    }
  }

  Future<ScheduleIdentityContext> _loadIdentityContext(String houseId) async {
    try {
      final settingsSnap = await _db.ref('houses/$houseId/settings').get();
      final settings = settingsSnap.value is Map
          ? Map<String, dynamic>.from(settingsSnap.value as Map)
          : const <String, dynamic>{};
      return ScheduleIdentityContext(
        houseId: houseId,
        houseName: (settings['houseName'] ?? '').toString(),
        nameU1: (settings['nameU1'] ?? '').toString(),
        nameU2: (settings['nameU2'] ?? '').toString(),
        startDate: (settings['startDate'] ?? '').toString(),
        dobU1: (settings['dobU1'] ?? '').toString(),
        dobU2: (settings['dobU2'] ?? '').toString(),
      );
    } catch (_) {
      return ScheduleIdentityContext(houseId: houseId);
    }
  }

  String _fallbackScheduleTitle(int daysUntil) {
    switch (daysUntil) {
      case 3:
        return '🎉 Sắp tới rồi!';
      case 2:
        return '⏳ Còn 2 ngày nữa!';
      case 1:
        return '⏰ Ngày mai là tới rồi!';
      case 0:
        return '🔔 Hôm nay là ngày đặc biệt!';
      default:
        return 'Thông báo mới';
    }
  }

  String _fallbackScheduleMessage(int daysUntil, String eventTitle) {
    final label = eventTitle.trim().isEmpty ? 'sự kiện này' : eventTitle.trim();
    switch (daysUntil) {
      case 3:
        return 'Chỉ còn 3 ngày nữa là đến $label nè! Chuẩn bị điều gì đó thật vui nhé! 🎁';
      case 2:
        return 'Chỉ còn 2 ngày nữa là đến $label thôi nha! 💖';
      case 1:
        return 'Hồi hộp quá! Chỉ còn 1 ngày nữa là đến $label rồi đó! 🥰';
      case 0:
        return 'Tèn ten! Hôm nay là $label nè! Chúc một ngày thật vui vẻ nhé! 🥳';
      default:
        return 'Đừng quên $label nhé!';
    }
  }

  List<UpcomingEvent> _buildSystemEvents(
    ScheduleIdentityContext identity,
    int todayMs,
  ) {
    final events = <UpcomingEvent>[];
    final now = DateTime.now();

    _addRecurringMonthDayEvent(
      events: events,
      eventKey: 'sys:anniversary:yearly',
      rawDate: identity.startDate,
      title: 'Ngày yêu của ${identity.fallbackSource}',
      source: 'system',
      now: now,
      todayMs: todayMs,
    );
    _addRecurringMonthDayEvent(
      events: events,
      eventKey: 'sys:birthday:user1',
      rawDate: identity.dobU1,
      title: identity.nameU1.trim().isEmpty
          ? 'Sinh nhật người thương'
          : 'Sinh nhật ${identity.nameU1.trim()}',
      source: 'system',
      now: now,
      todayMs: todayMs,
    );
    _addAdvanceNoticeBirthdayEvent(
      events: events,
      eventKey: 'sys:birthday:user1:pre7',
      rawDate: identity.dobU1,
      name: identity.nameU1.trim().isEmpty
          ? 'người thương'
          : identity.nameU1.trim(),
      advanceDays: 7,
      now: now,
      todayMs: todayMs,
    );
    _addRecurringMonthDayEvent(
      events: events,
      eventKey: 'sys:birthday:user2',
      rawDate: identity.dobU2,
      title: identity.nameU2.trim().isEmpty
          ? 'Sinh nhật người thương'
          : 'Sinh nhật ${identity.nameU2.trim()}',
      source: 'system',
      now: now,
      todayMs: todayMs,
    );
    _addAdvanceNoticeBirthdayEvent(
      events: events,
      eventKey: 'sys:birthday:user2:pre7',
      rawDate: identity.dobU2,
      name: identity.nameU2.trim().isEmpty
          ? 'người thương'
          : identity.nameU2.trim(),
      advanceDays: 7,
      now: now,
      todayMs: todayMs,
    );

    final anchor = _parseFlexibleDate(identity.startDate);
    if (anchor != null) {
      for (final milestone in const [30, 100, 365]) {
        final milestoneDate =
            _startOfDay(anchor).add(Duration(days: milestone));
        final dateKey = _formatDateKey(milestoneDate);
        final dateMs = milestoneDate.millisecondsSinceEpoch;
        events.add(
          UpcomingEvent(
            eventKey: 'sys:milestone:$milestone:$dateKey',
            dateKey: dateKey,
            dateMs: dateMs,
            title: 'Kỷ niệm $milestone ngày yêu',
            source: 'system',
            daysUntil: _daysUntil(dateMs, todayMs),
          ),
        );
      }
    }

    return events;
  }

  void _addRecurringMonthDayEvent({
    required List<UpcomingEvent> events,
    required String eventKey,
    required String rawDate,
    required String title,
    required String source,
    required DateTime now,
    required int todayMs,
  }) {
    final parsed = _parseFlexibleDate(rawDate);
    if (parsed == null) return;

    var eventDate = DateTime(now.year, parsed.month, parsed.day);
    final todayDate = DateTime(now.year, now.month, now.day);
    if (eventDate.isBefore(todayDate)) {
      eventDate = DateTime(now.year + 1, parsed.month, parsed.day);
    }

    final dateKey = _formatDateKey(eventDate);
    final dateMs = eventDate.millisecondsSinceEpoch;
    events.add(
      UpcomingEvent(
        eventKey: '$eventKey:$dateKey',
        dateKey: dateKey,
        dateMs: dateMs,
        title: title,
        source: source,
        daysUntil: _daysUntil(dateMs, todayMs),
      ),
    );
  }

  static const List<String> _giftSuggestions = [
    '🎁 Handmade viết tay lời yêu thương',
    '💐 Một bó hoa tươi kèm thiệp nhỏ xinh',
    '🎂 Bất ngờ với bánh kem và nến lung linh',
    '🍫 Hộp socola tình yêu và một cái ôm thật chặt',
    '💍 Trang sức nhỏ xinh đính tên 2 đứa',
    '🧸 Thú bông ôm tay dễ thương to đùng',
    '🎫 Vé xem phim đôi hoặc concert cả 2 thích',
    '📸 Album ảnh kỷ niệm tự thiết kế',
    '🌹 Một bữa tối lãng mạn với đèn nến và hoa',
    '✈️ Chuyến đi chơi 2 ngày 1 đêm bất ngờ',
    '🛍️ Set quà chăm sóc da hoặc nước hoa',
    '🎧 Tai nghe bluetooth cùng playlist tặng riêng',
    '🖼️ Khung ảnh điện tử quay vòng kỷ niệm',
    '🌸 Cây cảnh nhỏ xinh để cùng chăm sóc',
    '☕ Bộ ly sứ đôi khắc tên 2 đứa',
    '🎮 Game hoặc boardgame có thể chơi cùng nhau',
    '🧦 Đồ đôi: áo, mũ hoặc vớ dễ thương',
    '📖 Cuốn sổ nhỏ ghi lại lời yêu mỗi ngày',
    '🎵 Đàn hộp nhỏ (ukulele) và bài hát tặng riêng',
    '🌟 Bộ đèn sao trần phòng ngủ lãng mạn',
  ];

  void _addAdvanceNoticeBirthdayEvent(
      {required List<UpcomingEvent> events,
      required String eventKey,
      required String rawDate,
      required String name,
      required int advanceDays,
      required DateTime now,
      required int todayMs}) {
    final parsed = _parseFlexibleDate(rawDate);
    if (parsed == null) return;
    var bd = DateTime(now.year, parsed.month, parsed.day);
    final td = DateTime(now.year, now.month, now.day);
    if (bd.isBefore(td)) bd = DateTime(now.year + 1, parsed.month, parsed.day);
    final rd = bd.subtract(Duration(days: advanceDays));
    final rk = _formatDateKey(rd);
    final rms = rd.millisecondsSinceEpoch;
    if (rms < todayMs) return;
    final g = _giftSuggestions[
        (parsed.day + parsed.month + advanceDays) % _giftSuggestions.length];
    events.add(UpcomingEvent(
        eventKey: '$eventKey:$rk',
        dateKey: rk,
        dateMs: rms,
        title: '🎂 Sinh nhật $name sắp tới! Gợi ý quà: $g',
        source: 'system',
        daysUntil: _daysUntil(rms, todayMs)));
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _parseFlexibleDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;

    final ddmmyyyy = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})');
    final ddmmyyyyMatch = ddmmyyyy.firstMatch(value);
    if (ddmmyyyyMatch != null) {
      return DateTime(
        int.parse(ddmmyyyyMatch.group(3)!),
        int.parse(ddmmyyyyMatch.group(2)!),
        int.parse(ddmmyyyyMatch.group(1)!),
      );
    }

    final yyyymmdd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
    final yyyymmddMatch = yyyymmdd.firstMatch(value);
    if (yyyymmddMatch != null) {
      return DateTime(
        int.parse(yyyymmddMatch.group(1)!),
        int.parse(yyyymmddMatch.group(2)!),
        int.parse(yyyymmddMatch.group(3)!),
      );
    }

    return null;
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  static int _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  static int? _parseDateKey(String key) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) return null;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return date.millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  static int _daysUntil(int dateMs, int todayMs) {
    return ((dateMs - todayMs) / 86400000).round();
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

class UpcomingEvent {
  final String eventKey;
  final String dateKey;
  final int dateMs;
  final String title;
  final String source;
  final int daysUntil;

  UpcomingEvent({
    required this.eventKey,
    required this.dateKey,
    required this.dateMs,
    required this.title,
    required this.source,
    required this.daysUntil,
  });

  bool get isToday => daysUntil == 0;
  bool get isTomorrow => daysUntil == 1;
  bool get isUrgent => daysUntil <= 2;

  String get dayLabel {
    if (daysUntil == 0) return 'Hôm nay';
    if (daysUntil == 1) return 'Ngày mai';
    return 'Còn $daysUntil ngày';
  }
}
