import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_error_mapper.dart';
import '../calendar/calendar_civil_date.dart';
import '../calendar/calendar_local_reminders.dart';
import '../calendar/calendar_time_zone.dart';
import '../calendar/holiday_occurrence_resolver.dart';
import 'holiday_service.dart';
import 'l10n_service.dart';
import 'market_service.dart';
import 'notification_service.dart';

enum CalendarReminderStatus { ready, disabled, permissionDenied, unsupported, limited, failed }

/// Nhắc kế hoạch/lễ cục bộ theo UID; lựa chọn một người không gửi tới cả House.
class CalendarReminderService extends ChangeNotifier with WidgetsBindingObserver {
  CalendarReminderService._();
  static final instance = CalendarReminderService._();
  static bool get supported => !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  CalendarReminderStatus status = CalendarReminderStatus.ready;
  StreamSubscription<User?>? _auth;
  StreamSubscription<DatabaseEvent>? _house;
  StreamSubscription<DatabaseEvent>? _calendar;
  Timer? _renew;
  String? _uid;
  String? _houseId;
  Object? _calendarData;
  bool _started = false;
  bool _disposed = false;
  int _revision = 0;
  int _houseRevision = 0;
  Future<void> _queue = Future.value();

  void start() {
    if (_started || _disposed || !supported) return;
    try {
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        _uid = user?.uid;
        _houseRevision++;
        unawaited(_house?.cancel());
        _house = null;
        _bindCalendar(null);
        if (user != null) {
          _house = FirebaseDatabase.instance.ref('users/${user.uid}/houseId').onValue.listen((event) {
            if (_uid != user.uid || FirebaseAuth.instance.currentUser?.uid != user.uid) return;
            final raw = event.snapshot.value;
            final id = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
            if (_houseId != id) _bindCalendar(id);
          }, onError: (Object error) { _bindCalendar(null); });
        }
        unawaited(refresh());
      });
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      MarketService.instance.addListener(_onChanged);
      L10nService().addListener(_onChanged);
      _renew = Timer.periodic(const Duration(hours: 1), (_) => _bindCalendar(_houseId));
    } catch (error) { _fail(error); }
  }

  void _bindCalendar(String? id) {
    final generation = ++_houseRevision;
    final uid = _uid;
    _houseId = id;
    _calendarData = null;
    unawaited(_calendar?.cancel());
    _calendar = null;
    if (id != null && uid != null) {
      final now = CalendarTimeZone.fromMilliseconds(DateTime.now().millisecondsSinceEpoch,
        MarketService.instance.preferences.timeZoneId);
      _calendar = FirebaseDatabase.instance.ref('houses/$id/calendar').orderByKey()
        .startAt(CalendarCivilDate.key(now))
        .endAt(CalendarCivilDate.key(DateTime(now.year, now.month, now.day + 90)))
        .limitToFirst(64).onValue.listen((event) {
          if (generation != _houseRevision || _uid != uid || _houseId != id) return;
          _calendarData = event.snapshot.value;
          unawaited(refresh());
        }, onError: (Object error) {
          if (generation != _houseRevision) return;
          _calendarData = null;
          unawaited(refresh());
          _fail(error);
        });
    }
    unawaited(refresh());
  }

  void _onChanged() => unawaited(refresh());

  Future<void> refresh() {
    if (!supported) { status = CalendarReminderStatus.unsupported; return Future.value(); }
    final revision = ++_revision;
    final task = _queue.then((_) async {
      if (_disposed || revision != _revision) return;
      final uid = _uid;
      final houseId = _houseId;
      bool active() => !_disposed && revision == _revision && uid == _uid &&
        FirebaseAuth.instance.currentUser?.uid == uid && houseId == _houseId;
      try {
        final notifications = NotificationService();
        final prefs = await SharedPreferences.getInstance();
        if (!active()) return;
        final enabled = prefs.getBool('il_notifications_enabled') ?? true;
        final allowed = uid != null && enabled && await notifications.hasPermission();
        if (!active()) return;
        final selection = MarketService.instance.preferences;
        final now = CalendarTimeZone.fromMilliseconds(DateTime.now().millisecondsSinceEpoch, selection.timeZoneId);
        final holidays = selection.holidayRemindersEnabled
          ? HolidayOccurrenceResolver.occurrencesBetween(HolidayService.getApplicableHolidays(),
              start: now, end: DateTime(now.year, now.month, now.day + 90))
          : <HolidayOccurrence>[];
        final candidates = CalendarLocalReminderPlanner.build(now: now,
          calendarData: _calendarData, holidays: holidays,
          holidayName: HolidayService.getLocalizedName, timeZoneId: selection.timeZoneId);
        if (allowed && candidates.isNotEmpty && !await notifications.refreshLocalTimeZone()) {
          throw StateError('Cannot resolve reminder timezone');
        }
        if (!active()) return;
        final saved = await CalendarReminderReconciler(
          pending: notifications.pendingLocalNotifications, cancel: notifications.cancelLocalNotifications,
          schedule: ({required id, required title, required body, required scheduledDate, required data}) =>
            notifications.scheduleLocalNotification(id: id, title: title, body: body,
              scheduledDate: scheduledDate, data: data),
        ).reconcile(uid: uid, houseId: houseId, reminders: candidates, enabled: allowed, active: active,
          title: (item) => L10nService().translate(item.dayBefore
            ? 'calendar_notification_tomorrow_title' : 'calendar_notification_today_title'),
          body: (item) => L10nService().format('event_reminder_body', {'title': item.title, 'date': item.dateKey}));
        if (!active()) return;
        status = !enabled ? CalendarReminderStatus.disabled : uid != null && !allowed
          ? CalendarReminderStatus.permissionDenied : !saved ? CalendarReminderStatus.failed
          : candidates.length > CalendarReminderReconciler.maxReminders ? CalendarReminderStatus.limited
          : CalendarReminderStatus.ready;
        notifyListeners();
      } catch (error) { if (active()) _fail(error); }
    });
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  void _fail(Object error) {
    status = CalendarReminderStatus.failed;
    debugPrint('[CalendarReminderService] ${AppErrorMapper.resolve(error).message}');
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _bindCalendar(_houseId);
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _houseRevision++;
    _renew?.cancel();
    unawaited(_auth?.cancel());
    unawaited(_house?.cancel());
    unawaited(_calendar?.cancel());
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      MarketService.instance.removeListener(_onChanged);
      L10nService().removeListener(_onChanged);
    }
    super.dispose();
  }
}
