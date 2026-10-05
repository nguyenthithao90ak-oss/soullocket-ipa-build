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
import 'widget_service.dart';

enum CalendarReminderStatus {
  ready,
  disabled,
  permissionDenied,
  unsupported,
  limited,
  failed,
}

/// Nhắc kế hoạch/lễ cục bộ theo UID; lựa chọn một người không gửi tới cả House.
class CalendarReminderService extends ChangeNotifier
    with WidgetsBindingObserver {
  CalendarReminderService._({
    DatabaseReference? root,
    String? Function()? readUid,
    Stream<String?> Function()? uidChanges,
    DateTime Function()? now,
    this._isSupported,
    Future<bool> Function()? notificationsEnabled,
    Future<bool> Function()? hasPermission,
    Future<bool> Function()? refreshTimeZone,
    CalendarReminderReconciler? reconciler,
    Future<void> Function(String, Object?)? syncWidget,
    Future<void> Function()? clearWidget,
    this.renewalInterval = const Duration(hours: 1),
  }) : _rootOverride = root,
       _readUid = readUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _uidChanges =
           uidChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map(
             (user) => user?.uid,
           )),
       _now = now ?? DateTime.now,
       _notificationsEnabled =
           notificationsEnabled ??
           (() async {
             final prefs = await SharedPreferences.getInstance();
             return prefs.getBool('il_notifications_enabled') ?? true;
           }),
       _hasPermission = hasPermission ?? NotificationService().hasPermission,
       _refreshTimeZone =
           refreshTimeZone ?? NotificationService().refreshLocalTimeZone,
       _reconcilerOverride = reconciler,
       _syncWidget =
           syncWidget ??
           ((houseId, data) => WidgetService.syncCalendarWidgetData(
             houseId: houseId,
             calendarData: data,
           )),
       _clearWidget = clearWidget ?? WidgetService.clearCalendarWidgetData;

  @visibleForTesting
  CalendarReminderService.forTesting({
    required DatabaseReference root,
    required String? Function() readUid,
    required Stream<String?> Function() uidChanges,
    required DateTime Function() now,
    required Future<bool> Function() notificationsEnabled,
    required Future<bool> Function() hasPermission,
    required CalendarReminderReconciler reconciler,
    required Future<void> Function(String, Object?) syncWidget,
    required Future<void> Function() clearWidget,
  }) : this._(
         root: root,
         readUid: readUid,
         uidChanges: uidChanges,
         now: now,
         isSupported: true,
         notificationsEnabled: notificationsEnabled,
         hasPermission: hasPermission,
         refreshTimeZone: () async => true,
         reconciler: reconciler,
         syncWidget: syncWidget,
         clearWidget: clearWidget,
         renewalInterval: null,
       );

  final DatabaseReference? _rootOverride;
  DatabaseReference get _root =>
      _rootOverride ?? FirebaseDatabase.instance.ref();
  final String? Function() _readUid;
  final Stream<String?> Function() _uidChanges;
  final DateTime Function() _now;
  final bool? _isSupported;
  final Future<bool> Function() _notificationsEnabled;
  final Future<bool> Function() _hasPermission;
  final Future<bool> Function() _refreshTimeZone;
  final CalendarReminderReconciler? _reconcilerOverride;
  final Future<void> Function(String, Object?) _syncWidget;
  final Future<void> Function() _clearWidget;
  final Duration? renewalInterval;
  bool get _canRun => _isSupported ?? supported;
  static final instance = CalendarReminderService._();
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  CalendarReminderStatus status = CalendarReminderStatus.ready;
  StreamSubscription<String?>? _auth;
  StreamSubscription<DatabaseEvent>? _house;
  StreamSubscription<DatabaseEvent>? _calendar;
  Timer? _renew;
  String? _uid;
  String? _houseId;
  String? _calendarScopeUid;
  String? _calendarScopeHouseId;
  Object? _calendarData;
  bool _hasCalendarSnapshot = false;
  int _authRevision = 0;
  Object? _houseError;
  Object? _calendarError;
  bool _started = false;
  bool _disposed = false;
  int _revision = 0;
  int _houseRevision = 0;
  String? _queryTimeZone;
  Future<void> _queue = Future.value();

  void start() {
    if (_started || _disposed || !_canRun) return;
    try {
      _auth = _uidChanges().listen((uid) {
        final authRevision = ++_authRevision;
        _uid = uid;
        _houseError = null;
        _houseRevision++;
        unawaited(_house?.cancel());
        _house = null;
        _bindCalendar(null);
        if (uid != null) {
          _house = _root
              .child('users/$uid/houseId')
              .onValue
              .listen(
                (event) {
                  if (authRevision != _authRevision ||
                      _uid != uid ||
                      _readUid() != uid) {
                    return;
                  }
                  final raw = event.snapshot.value;
                  _houseError = null;
                  final id = raw is String && raw.trim().isNotEmpty
                      ? raw.trim()
                      : null;
                  if (_houseId != id) {
                    _bindCalendar(id);
                  } else {
                    unawaited(refresh());
                  }
                },
                onError: (Object error) {
                  if (authRevision == _authRevision &&
                      _uid == uid &&
                      _readUid() == uid) {
                    _houseError = error;
                    if (error is FirebaseException &&
                        error.code == 'permission-denied') {
                      _bindCalendar(null);
                    } else {
                      unawaited(refresh());
                    }
                  }
                },
              );
        }
        unawaited(refresh());
      });
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      MarketService.instance.addListener(_onChanged);
      L10nService().addListener(_onChanged);
      final interval = renewalInterval;
      if (interval != null) {
        _renew = Timer.periodic(interval, (_) => _bindCalendar(_houseId));
      }
    } catch (error) {
      _fail(error);
    }
  }

  void _bindCalendar(String? id) {
    final generation = ++_houseRevision;
    final uid = _uid;
    final sameScope = _calendarScopeUid == uid && _calendarScopeHouseId == id;
    _houseId = id;
    _calendarScopeUid = uid;
    _calendarScopeHouseId = id;
    // Giữ snapshot tốt khi rebind cùng UID/House để không hủy nhắc hợp lệ
    // trong lúc listener thay thế còn đang chờ dữ liệu.
    if (!sameScope) {
      _calendarData = null;
      _hasCalendarSnapshot = false;
      _calendarError = null;
      unawaited(_clearWidget());
    }
    unawaited(_calendar?.cancel());
    _calendar = null;
    if (id != null && uid != null) {
      _queryTimeZone = MarketService.instance.preferences.timeZoneId;
      final now = CalendarTimeZone.fromMilliseconds(
        _now().millisecondsSinceEpoch,
        MarketService.instance.preferences.timeZoneId,
      );
      _calendar = _root
          .child('houses/$id/calendar')
          .orderByKey()
          .startAt(CalendarCivilDate.key(now))
          .endAt(
            CalendarCivilDate.key(
              DateTime.utc(now.year, now.month, now.day + 90),
            ),
          )
          .limitToFirst(64)
          .onValue
          .listen(
            (event) {
              if (generation != _houseRevision ||
                  _uid != uid ||
                  _readUid() != uid ||
                  _houseId != id) {
                return;
              }
              _calendarData = event.snapshot.value;
              _hasCalendarSnapshot = true;
              _calendarError = null;
              unawaited(refresh());
            },
            onError: (Object error) {
              if (generation != _houseRevision || _readUid() != uid) return;
              _calendarError = error;
              // Lỗi mạng giữ snapshot cùng scope; mất quyền phải xóa dữ liệu.
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                _calendarData = null;
                _hasCalendarSnapshot = false;
                unawaited(_clearWidget());
              }
              unawaited(refresh());
            },
          );
    }
    unawaited(refresh());
  }

  void _onChanged() {
    if (_queryTimeZone != MarketService.instance.preferences.timeZoneId &&
        _houseId != null) {
      _bindCalendar(_houseId);
    } else {
      unawaited(refresh());
    }
  }

  Future<void> refresh() {
    if (!_canRun) {
      status = CalendarReminderStatus.unsupported;
      return Future.value();
    }
    final revision = ++_revision;
    final task = _queue.then((_) async {
      if (_disposed || revision != _revision) return;
      final uid = _uid;
      final houseId = _houseId;
      bool active() =>
          !_disposed &&
          revision == _revision &&
          uid == _uid &&
          _readUid() == uid &&
          houseId == _houseId;
      try {
        // Widget cập nhật từ listener ngay cả khi Home đóng hoặc quyền nhắc bị tắt.
        if (uid != null && houseId != null && _hasCalendarSnapshot) {
          try {
            await _syncWidget(houseId, _calendarData);
          } catch (error) {
            // Lỗi cầu nối widget không được làm mất nhắc lịch local.
            debugPrint(
              '[CalendarReminderService] Widget sync skipped: '
              '${AppErrorMapper.resolve(error).message}',
            );
          }
          if (!active()) return;
        }
        final enabled = await _notificationsEnabled();
        if (!active()) return;
        final allowed = uid != null && enabled && await _hasPermission();
        if (!active()) return;
        final selection = MarketService.instance.preferences;
        final now = CalendarTimeZone.fromMilliseconds(
          _now().millisecondsSinceEpoch,
          selection.timeZoneId,
        );
        final holidays = selection.holidayRemindersEnabled
            ? HolidayOccurrenceResolver.occurrencesBetween(
                HolidayService.getApplicableHolidays(),
                start: now,
                end: DateTime.utc(now.year, now.month, now.day + 90),
              )
            : <HolidayOccurrence>[];
        final candidates = CalendarLocalReminderPlanner.build(
          now: now,
          calendarData: _calendarData,
          holidays: holidays,
          holidayName: HolidayService.getLocalizedName,
          timeZoneId: selection.timeZoneId,
        );
        if (allowed && candidates.isNotEmpty && !await _refreshTimeZone()) {
          throw StateError('Cannot resolve reminder timezone');
        }
        if (!active()) return;
        final reconciler = _reconcilerOverride ?? _nativeReconciler();
        final saved = await reconciler.reconcile(
          uid: uid,
          houseId: houseId,
          reminders: candidates,
          enabled: allowed,
          active: active,
          title: (item) => L10nService().translate(
            item.dayBefore
                ? 'calendar_notification_tomorrow_title'
                : 'calendar_notification_today_title',
          ),
          body: (item) => L10nService().format('event_reminder_body', {
            'title': item.title,
            'date': item.dateKey,
          }),
        );
        if (!active()) return;
        status = _houseError != null || _calendarError != null
            ? CalendarReminderStatus.failed
            : !enabled
            ? CalendarReminderStatus.disabled
            : uid != null && !allowed
            ? CalendarReminderStatus.permissionDenied
            : !saved
            ? CalendarReminderStatus.failed
            : candidates.length > CalendarReminderReconciler.maxReminders
            ? CalendarReminderStatus.limited
            : CalendarReminderStatus.ready;
        notifyListeners();
      } catch (error) {
        if (active()) _fail(error);
      }
    });
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  void _fail(Object error) {
    status = CalendarReminderStatus.failed;
    debugPrint(
      '[CalendarReminderService] ${AppErrorMapper.resolve(error).message}',
    );
    if (!_disposed) notifyListeners();
  }

  static CalendarReminderReconciler _nativeReconciler() {
    final notifications = NotificationService();
    return CalendarReminderReconciler(
      pending: notifications.pendingLocalNotifications,
      cancel: notifications.cancelLocalNotifications,
      schedule: notifications.scheduleLocalNotification,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _bindCalendar(_houseId);
  }

  @override
  void dispose() {
    _disposed = true;
    _authRevision++;
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
