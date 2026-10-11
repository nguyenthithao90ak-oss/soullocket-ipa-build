// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_error_mapper.dart';
import '../habit_local_reminders.dart';
import 'l10n_service.dart';
import 'notification_service.dart';

enum HabitReminderStatus {
  waiting,
  ready,
  disabled,
  permissionDenied,
  unsupported,
  limited,
  failed,
}

/// Owner nhắc Thói quen toàn app; RTDB cache cung cấp snapshot offline,
/// OS phát những lịch đã hẹn mà không cần chạy màn hình hoặc kết nối mạng.
class HabitReminderService extends ChangeNotifier with WidgetsBindingObserver {
  HabitReminderService._({
    DatabaseReference? root,
    String? Function()? readUid,
    Stream<String?> Function()? uidChanges,
    DateTime Function()? now,
    bool? supported,
    Future<bool> Function()? notificationsEnabled,
    Future<bool> Function()? hasPermission,
    Future<String?> Function()? refreshTimeZone,
    HabitReminderReconciler? reconciler,
    String Function()? title,
    String Function(HabitLocalReminder)? body,
    this.renewalInterval = const Duration(hours: 1),
  }) : _rootOverride = root,
       _supported = supported,
       _readUid = readUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _uidChanges =
           uidChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map(
             (user) => user?.uid,
           )),
       _now = now ?? DateTime.now,
       _notificationsEnabled =
           notificationsEnabled ??
           (() async =>
               (await SharedPreferences.getInstance()).getBool(
                 'il_notifications_enabled',
               ) ??
               true),
       _hasPermission =
           hasPermission ?? (() => NotificationService().hasPermission()),
       _refreshTimeZone =
           refreshTimeZone ??
           (() async {
             final notifications = NotificationService();
             if (!await notifications.refreshLocalTimeZone()) return null;
             return notifications.ensureLocalTimeZone();
           }),
       _reconcilerOverride = reconciler,
       _title =
           title ??
           (() => L10nService().translate('notif_habit_reminder_title')),
       _body =
           body ??
           ((item) => L10nService().format('notif_habit_reminder_body', {
             'value1': item.name,
           }));

  @visibleForTesting
  HabitReminderService.forTesting({
    required DatabaseReference root,
    required String? Function() readUid,
    required Stream<String?> Function() uidChanges,
    required DateTime Function() now,
    required Future<bool> Function() notificationsEnabled,
    required Future<bool> Function() hasPermission,
    required Future<String?> Function() refreshTimeZone,
    required HabitReminderReconciler reconciler,
  }) : this._(
         root: root,
         readUid: readUid,
         uidChanges: uidChanges,
         now: now,
         supported: true,
         notificationsEnabled: notificationsEnabled,
         hasPermission: hasPermission,
         refreshTimeZone: refreshTimeZone,
         reconciler: reconciler,
         title: () => 'Synthetic habit reminder',
         body: (item) => item.name,
         renewalInterval: null,
       );

  static final instance = HabitReminderService._();
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final DatabaseReference? _rootOverride;
  DatabaseReference get _root =>
      _rootOverride ?? FirebaseDatabase.instance.ref();
  final String? Function() _readUid;
  final Stream<String?> Function() _uidChanges;
  final DateTime Function() _now;
  final bool? _supported;
  final Future<bool> Function() _notificationsEnabled;
  final Future<bool> Function() _hasPermission;
  final Future<String?> Function() _refreshTimeZone;
  final HabitReminderReconciler? _reconcilerOverride;
  final String Function() _title;
  final String Function(HabitLocalReminder) _body;
  final Duration? renewalInterval;
  bool get _canRun => _supported ?? supported;

  StreamSubscription<String?>? _auth;
  StreamSubscription<DatabaseEvent>? _house;
  StreamSubscription<DatabaseEvent>? _habits;
  Timer? _renew;
  String? _uid;
  String? _houseId;
  Object? _data;
  Object? _error;
  bool _houseResolved = false;
  bool _hasSnapshot = false;
  bool _denied = false;
  bool _started = false;
  bool _disposed = false;
  int _revision = 0;
  int _authRevision = 0;
  int _houseRevision = 0;
  Future<void> _queue = Future.value();

  HabitReminderStatus status = HabitReminderStatus.waiting;
  int scheduledCount = 0;
  DateTime? scheduledThrough;

  void start() {
    if (_started || _disposed || !_canRun) return;
    try {
      _auth = _uidChanges().listen(_onAuthChanged);
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      L10nService().addListener(_onChanged);
      final interval = renewalInterval;
      if (interval != null) {
        _renew = Timer.periodic(interval, (_) => unawaited(refresh()));
      }
    } catch (error) {
      _reportError(error);
    }
  }

  void _onChanged() => unawaited(refresh());

  void _onAuthChanged(String? uid) {
    final generation = ++_authRevision;
    _uid = uid;
    _houseId = null;
    _houseResolved = false;
    _data = null;
    _hasSnapshot = false;
    _denied = false;
    _error = null;
    _houseRevision++;
    unawaited(_house?.cancel());
    unawaited(_habits?.cancel());
    _house = null;
    _habits = null;
    if (uid != null) {
      _listenHouse(uid, generation);
    }
    unawaited(refresh());
  }

  void _listenHouse(String uid, int generation) {
    if (!_currentUid(uid) || generation != _authRevision) return;
    _house = _root
        .child('users/$uid/houseId')
        .onValue
        .listen(
          (event) {
            if (!_currentUid(uid) || generation != _authRevision) return;
            _houseResolved = true;
            _error = null;
            final raw = event.snapshot.value;
            final id = raw is String && raw.trim().isNotEmpty
                ? raw.trim()
                : null;
            _bindHouse(id, uid);
          },
          onError: (Object error) {
            if (!_currentUid(uid) || generation != _authRevision) return;
            if (_permissionDenied(error)) {
              _houseResolved = true;
              _bindHouse(null, uid);
              _denied = true;
            }
            _error = error;
            unawaited(refresh());
          },
        );
  }

  bool _currentUid(String uid) =>
      !_disposed && _uid == uid && _readUid() == uid;
  bool _active(int revision, String? uid, String? houseId) =>
      !_disposed &&
      revision == _revision &&
      _uid == uid &&
      _readUid() == uid &&
      _houseId == houseId;
  static bool _permissionDenied(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  void _bindHouse(String? houseId, String uid, {bool rebind = false}) {
    if (!_currentUid(uid)) return;
    if (_houseId == houseId && _habits != null && !rebind) {
      unawaited(refresh());
      return;
    }
    final sameScope = _houseId == houseId;
    final generation = ++_houseRevision;
    _houseId = houseId;
    if (!sameScope) {
      _data = null;
      _hasSnapshot = false;
      _denied = false;
    }
    unawaited(_habits?.cancel());
    _habits = null;
    if (houseId != null) {
      _habits = _root
          .child('houses/$houseId/habits')
          .limitToLast(25)
          .onValue
          .listen(
            (event) {
              if (!_currentUid(uid) ||
                  generation != _houseRevision ||
                  _houseId != houseId) {
                return;
              }
              _data = event.snapshot.value;
              _hasSnapshot = true;
              _denied = false;
              _error = null;
              unawaited(refresh());
            },
            onError: (Object error) {
              if (!_currentUid(uid) ||
                  generation != _houseRevision ||
                  _houseId != houseId) {
                return;
              }
              _error = error;
              if (_permissionDenied(error)) {
                _denied = true;
                _data = null;
                _hasSnapshot = false;
              }
              unawaited(refresh());
            },
          );
    }
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (!_canRun) {
      status = HabitReminderStatus.unsupported;
      return Future.value();
    }
    final revision = ++_revision;
    final task = _queue.then((_) async {
      if (_disposed || revision != _revision) return;
      final uid = _uid, houseId = _houseId;
      bool active() => _active(revision, uid, houseId);
      try {
        final enabled = await _notificationsEnabled();
        if (!active()) return;
        final permission = uid != null && enabled && await _hasPermission();
        if (!active()) return;
        final clear = _denied || (_houseResolved && houseId == null);
        String zone = tz.local.name;
        List<HabitLocalReminder>? reminders;
        if (permission && !clear && _hasSnapshot) {
          final resolved = await _refreshTimeZone();
          if (!active()) return;
          if (resolved == null) {
            throw StateError('Cannot resolve habit reminder timezone');
          }
          zone = resolved;
          reminders = HabitLocalReminderPlanner.build(
            data: _data,
            now: tz.TZDateTime.from(_now(), tz.getLocation(zone)),
          );
        }
        final result = await (_reconcilerOverride ?? _nativeReconciler())
            .reconcile(
              uid: uid,
              houseId: houseId,
              reminders: reminders,
              enabled: enabled && permission,
              clearScope: clear,
              timeZoneId: zone,
              active: active,
              title: (_) => _title(),
              body: _body,
            );
        if (!active()) return;
        scheduledCount = result.count;
        scheduledThrough = result.through;
        status = _error != null || result.failed
            ? HabitReminderStatus.failed
            : !enabled
            ? HabitReminderStatus.disabled
            : uid != null && !permission
            ? HabitReminderStatus.permissionDenied
            : result.limited
            ? HabitReminderStatus.limited
            : uid != null && !clear && !_hasSnapshot
            ? HabitReminderStatus.waiting
            : HabitReminderStatus.ready;
        notifyListeners();
      } catch (error) {
        if (active()) _reportError(error);
      }
    });
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  /// Dựng lại listener sau lỗi stream hoặc khi app quay lại foreground.
  /// `refresh()` chỉ đồng bộ lịch đang có, nên không đủ để phục hồi một
  /// listener RTDB đã kết thúc sau lỗi mạng/quyền.
  Future<void> retry() async {
    if (_disposed || !_canRun) return;
    final uid = _uid;
    if (uid == null || _readUid() != uid) {
      await refresh();
      return;
    }

    _revision++;
    final generation = ++_authRevision;
    _houseRevision++;

    final oldHouse = _house;
    final oldHabits = _habits;
    _house = null;
    _habits = null;
    await oldHouse?.cancel();
    await oldHabits?.cancel();
    if (!_currentUid(uid) || generation != _authRevision) return;

    _listenHouse(uid, generation);
    // Giữ snapshot cùng scope khi nghe lại; mất quyền chỉ được gỡ trạng thái
    // đã từ chối sau khi listener mới trả dữ liệu hợp lệ.
    _bindHouse(_houseId, uid, rebind: true);
    await refresh();
  }

  static HabitReminderReconciler _nativeReconciler() {
    final notifications = NotificationService();
    return HabitReminderReconciler(
      pending: notifications.pendingLocalNotifications,
      cancel: notifications.cancelLocalNotifications,
      schedule: notifications.scheduleLocalNotification,
      // Android đủ 25 thói quen x 7 ngày. iOS chừa chỗ cho feature khác.
      maxReminders: defaultTargetPlatform == TargetPlatform.iOS ? 32 : 175,
      maxTotal: defaultTargetPlatform == TargetPlatform.iOS ? 60 : 256,
    );
  }

  void _reportError(Object error) {
    status = HabitReminderStatus.failed;
    debugPrint(
      '[HabitReminderService] ${AppErrorMapper.resolve(error).message}',
    );
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(retry());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _authRevision++;
    _houseRevision++;
    _renew?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      L10nService().removeListener(_onChanged);
    }
    unawaited(_auth?.cancel());
    unawaited(_house?.cancel());
    unawaited(_habits?.cancel());
    super.dispose();
  }
}
