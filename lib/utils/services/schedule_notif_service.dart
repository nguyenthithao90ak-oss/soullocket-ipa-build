import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../calendar_widget_snapshot.dart';
import 'core/cloud_functions_helper.dart';
import 'schedule_notification_presenter.dart';

class ScheduleNotifService {
  static final ScheduleNotifService _instance =
      ScheduleNotifService._internal();

  factory ScheduleNotifService() => _instance;

  ScheduleNotifService._internal()
    : _root = FirebaseDatabase.instance.ref(),
      _now = DateTime.now,
      _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _uidChanges = (() =>
          FirebaseAuth.instance.authStateChanges().map((user) => user?.uid)),
      _sendPayload = _sendSecurePayload;

  @visibleForTesting
  ScheduleNotifService.forTesting(
    this._root, {
    required String? Function() readUid,
    DateTime Function()? now,
    Stream<String?> Function()? uidChanges,
    required Future<void> Function(Map<String, dynamic>) sendNotification,
  }) : _currentUid = readUid,
       _now = now ?? DateTime.now,
       _uidChanges = uidChanges ?? (() => const Stream<String?>.empty()),
       _sendPayload = sendNotification;

  final DatabaseReference _root;
  final DateTime Function() _now;
  final String? Function() _currentUid;
  final Stream<String?> Function() _uidChanges;
  final Future<void> Function(Map<String, dynamic>) _sendPayload;
  final _pendingChecks = <(String, String, String), Future<void>>{};
  static const _identityFields = [
    'houseName',
    'nameU1',
    'nameU2',
    'startDate',
    'dobU1',
    'dobU2',
  ];

  Future<String?> addCustomEvent({
    required String houseId,
    required String name,
    required DateTime date,
    bool repeat = false,
  }) async {
    final ref = _root.child('houses/$houseId/settings/customEvents').push();
    await ref.set({
      'name': name.trim(),
      'date': '${date.year}-${_pad(date.month)}-${_pad(date.day)}',
      'repeat': repeat,
      'ts': ServerValue.timestamp,
    });
    return ref.key;
  }

  Future<void> deleteCustomEvent(String houseId, String eventId) async {
    await _root
        .child('houses/$houseId/settings/customEvents/$eventId')
        .remove();
  }

  Stream<List<UpcomingEvent>> streamUpcomingEvents(String houseId) {
    final normalizedHouseId = houseId.trim();
    final uid = _currentUid();
    if (!_validHouseId(normalizedHouseId) || uid == null || uid.isEmpty) {
      return Stream.value(const []);
    }
    final snapshots = <String, DataSnapshot>{};
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];
    StreamSubscription<String?>? authSubscription;
    late StreamController<List<UpcomingEvent>> controller;
    var active = true;
    Future<void> cancelSources() async {
      active = false;
      await Future.wait([
        for (final subscription in subscriptions) subscription.cancel(),
        if (authSubscription != null) authSubscription!.cancel(),
      ]);
    }

    void stop() {
      if (!active) return;
      unawaited(cancelSources());
      controller.add(const []);
      unawaited(controller.close());
    }

    bool isCurrentScope() => active && _currentUid() == uid;
    void emit() {
      if (!isCurrentScope()) {
        stop();
        return;
      }
      if (snapshots.length != _identityFields.length + 2) return;
      controller.add(
        _upcomingEvents(
          calendar: snapshots['calendar']!,
          custom: snapshots['custom']!,
          identity: _identityFromValues(normalizedHouseId, {
            for (final field in _identityFields) field: snapshots[field]!.value,
          }),
        ),
      );
    }

    controller = StreamController<List<UpcomingEvent>>(
      onListen: () {
        if (!isCurrentScope()) {
          stop();
          return;
        }
        authSubscription = _uidChanges().listen((value) {
          if (value != uid) stop();
        });
        final queries = <String, Query>{
          'calendar': _calendarQuery(normalizedHouseId, _now()),
          'custom': _root.child(
            'houses/$normalizedHouseId/settings/customEvents',
          ),
          for (final field in _identityFields)
            field: _root.child('houses/$normalizedHouseId/settings/$field'),
        };
        for (final entry in queries.entries) {
          subscriptions.add(
            entry.value.onValue.listen(
              (event) {
                if (!isCurrentScope()) {
                  stop();
                  return;
                }
                snapshots[entry.key] = event.snapshot;
                emit();
              },
              onError: (Object error, StackTrace stack) {
                if (!isCurrentScope()) {
                  stop();
                  return;
                }
                controller.addError(error, stack);
                unawaited(cancelSources());
                unawaited(controller.close());
              },
            ),
          );
        }
      },
      onCancel: cancelSources,
      onPause: () {
        for (final subscription in subscriptions) {
          subscription.pause();
        }
      },
      onResume: () {
        if (!isCurrentScope()) {
          stop();
          return;
        }
        for (final subscription in subscriptions) {
          subscription.resume();
        }
      },
    );
    return controller.stream;
  }

  List<UpcomingEvent> _upcomingEvents({
    required DataSnapshot calendar,
    required DataSnapshot custom,
    required ScheduleIdentityContext identity,
  }) {
    final events = <UpcomingEvent>[];
    final today = _todayMidnight();

    for (final daySnapshot in calendar.children) {
      final dateKey = daySnapshot.key ?? '';
      final dateMs = _parseDateKey(dateKey);
      if (dateMs == null) continue;
      for (final eventSnapshot in daySnapshot.children) {
        final eventId = eventSnapshot.key;
        if (eventId == null) continue;
        final eventRaw = eventSnapshot.value;
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
    for (final customSnapshot in custom.children) {
      final key = customSnapshot.key;
      if (key == null) continue;
      final value = customSnapshot.value;
      if (value is! Map) continue;
      final dateStr = value['date']?.toString() ?? '';
      final dateMs = _parseDateKey(dateStr);
      if (dateMs == null) continue;

      DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
      if (value['repeat'] == true) {
        final now = _now();
        eventDate = DateTime(now.year, eventDate.month, eventDate.day);
        final todayDate = DateTime(now.year, now.month, now.day);
        if (eventDate.isBefore(todayDate)) {
          eventDate = DateTime(now.year + 1, eventDate.month, eventDate.day);
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
    events.addAll(_buildSystemEvents(identity, today));

    events.removeWhere((event) => event.daysUntil < 0);
    events.sort((left, right) => left.daysUntil.compareTo(right.daysUntil));
    return events;
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
    await _sendPayload(<String, dynamic>{
      'houseId': toHouseId,
      'notificationId': notifId,
      'title': title,
      'message': message,
      'sourceLabel': sourceLabel,
      'eventKey': eventKey,
      'eventDate': eventDate,
      'eventTitle': eventTitle,
    });
  }

  Future<void> checkAndNotify(String houseId) async {
    final normalizedHouseId = houseId.trim();
    final uid = _currentUid();
    if (!_validHouseId(normalizedHouseId) || uid == null || uid.isEmpty) return;
    final now = _now();
    final key = (uid, normalizedHouseId, _formatDateKey(now));
    final pending = _pendingChecks[key];
    if (pending != null) return pending;
    final operation = _checkAndNotify(normalizedHouseId, uid, now);
    _pendingChecks[key] = operation;
    try {
      await operation;
    } finally {
      if (identical(_pendingChecks[key], operation)) _pendingChecks.remove(key);
    }
  }

  Future<void> _checkAndNotify(String houseId, String uid, DateTime now) async {
    var invalidated = false;
    final authSubscription = _uidChanges().listen((value) {
      if (value != uid) invalidated = true;
    });
    bool isCurrentScope() => !invalidated && _currentUid() == uid;
    try {
      if (!isCurrentScope()) return;
      final today = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final calSnap = await _calendarQuery(
        houseId,
        now,
        reminderOnly: true,
      ).get();
      if (!isCurrentScope()) return;
      final customSnap = await _root
          .child('houses/$houseId/settings/customEvents')
          .get();
      if (!isCurrentScope()) return;
      final identity = await _loadIdentityContext(houseId);
      if (!isCurrentScope()) return;

      final events = <UpcomingEvent>[];

      for (final daySnapshot in calSnap.children) {
        final dateKey = daySnapshot.key ?? '';
        final dateMs = _parseDateKey(dateKey);
        if (dateMs == null) continue;
        for (final eventSnapshot in daySnapshot.children) {
          final eventId = eventSnapshot.key;
          if (eventId == null) continue;
          final eventRaw = eventSnapshot.value;
          final title = eventRaw is Map
              ? eventRaw['title']?.toString() ?? ''
              : '';
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
      for (final customSnapshot in customSnap.children) {
        final key = customSnapshot.key;
        if (key == null) continue;
        final value = customSnapshot.value;
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
      events.addAll(_buildSystemEvents(identity, today));

      for (final event in events) {
        if (!isCurrentScope()) return;
        if (event.daysUntil < 0 || event.daysUntil > 3) continue;

        final notifId = _notificationIdFor(event);
        final presentation = describeScheduleNotification(
          notificationId: notifId,
          fallbackTitle: _fallbackScheduleTitle(event.daysUntil),
          fallbackMessage: _fallbackScheduleMessage(
            event.daysUntil,
            event.title,
          ),
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
    } finally {
      await authSubscription.cancel();
    }
  }

  String _notificationIdFor(UpcomingEvent event) {
    return 'sched_d${event.daysUntil}_${event.eventKey.hashCode.toUnsigned(32).toRadixString(16)}';
  }

  Query _calendarQuery(
    String houseId,
    DateTime now, {
    bool reminderOnly = false,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final query = _root
        .child('houses/$houseId/calendar')
        .orderByKey()
        .startAt(CalendarWidgetSnapshot.dateKeyFor(today));
    return reminderOnly
        ? query.endAt(
            CalendarWidgetSnapshot.dateKeyFor(
              DateTime(today.year, today.month, today.day + 3),
            ),
          )
        : query;
  }

  static bool _validHouseId(String houseId) =>
      RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(houseId);

  static Future<void> _sendSecurePayload(Map<String, dynamic> payload) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      'createScheduleNotificationSecure',
      payload: payload,
    );
  }

  ScheduleIdentityContext _identityFromValues(
    String houseId,
    Map<String, Object?> values,
  ) {
    return ScheduleIdentityContext(
      houseId: houseId,
      houseName: (values['houseName'] ?? '').toString(),
      nameU1: (values['nameU1'] ?? '').toString(),
      nameU2: (values['nameU2'] ?? '').toString(),
      startDate: (values['startDate'] ?? '').toString(),
      dobU1: (values['dobU1'] ?? '').toString(),
      dobU2: (values['dobU2'] ?? '').toString(),
    );
  }

  Future<ScheduleIdentityContext> _loadIdentityContext(String houseId) async {
    try {
      final snapshots = await Future.wait([
        for (final field in _identityFields)
          _root.child('houses/$houseId/settings/$field').get(),
      ]);
      return _identityFromValues(houseId, {
        for (var index = 0; index < _identityFields.length; index++)
          _identityFields[index]: snapshots[index].value,
      });
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
    final now = DateTime.fromMillisecondsSinceEpoch(todayMs);

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
        final milestoneDate = _startOfDay(
          anchor,
        ).add(Duration(days: milestone));
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

  void _addAdvanceNoticeBirthdayEvent({
    required List<UpcomingEvent> events,
    required String eventKey,
    required String rawDate,
    required String name,
    required int advanceDays,
    required DateTime now,
    required int todayMs,
  }) {
    final parsed = _parseFlexibleDate(rawDate);
    if (parsed == null) return;
    var bd = DateTime(now.year, parsed.month, parsed.day);
    final td = DateTime(now.year, now.month, now.day);
    if (bd.isBefore(td)) bd = DateTime(now.year + 1, parsed.month, parsed.day);
    final rd = bd.subtract(Duration(days: advanceDays));
    final rk = _formatDateKey(rd);
    final rms = rd.millisecondsSinceEpoch;
    if (rms < todayMs) return;
    final g =
        _giftSuggestions[(parsed.day + parsed.month + advanceDays) %
            _giftSuggestions.length];
    events.add(
      UpcomingEvent(
        eventKey: '$eventKey:$rk',
        dateKey: rk,
        dateMs: rms,
        title: '🎂 Sinh nhật $name sắp tới! Gợi ý quà: $g',
        source: 'system',
        daysUntil: _daysUntil(rms, todayMs),
      ),
    );
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

  int _todayMidnight() {
    final now = _now();
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
