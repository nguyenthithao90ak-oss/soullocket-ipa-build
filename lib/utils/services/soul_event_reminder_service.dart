import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/soul_event.dart';
import '../app_error_mapper.dart';
import 'house_service.dart';
import 'l10n_service.dart';
import 'notification_service.dart';
import 'soul_event_service.dart';

enum SoulEventReminderStatus {
  ready,
  permissionDenied,
  disabled,
  unsupported,
  limited,
  failed,
}

class _Reminder {
  const _Reminder(this.event, this.time);
  final SoulEvent event;
  final DateTime time;
}

/// Lịch nhắc thuộc thiết bị và tài khoản hiện tại; chỉ hủy payload của tính năng này.
class SoulEventReminderService extends ChangeNotifier
    with WidgetsBindingObserver {
  SoulEventReminderService._();
  static final instance = SoulEventReminderService._();
  static const payloadType = 'soul_event_reminder_v1';
  static const maxReminders = 32;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  StreamSubscription<User?>? _auth;
  StreamSubscription<String>? _events;
  StreamSubscription<DatabaseEvent>? _house;
  String? _houseUid;
  String? _observedHouseId;
  bool _hasHouseSnapshot = false;
  Future<void> _queue = Future.value();
  int _revision = 0;
  bool _started = false;
  bool _disposed = false;
  SoulEventReminderStatus status = SoulEventReminderStatus.ready;

  void start() {
    if (_started || _disposed || !supported) return;
    try {
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        unawaited(_house?.cancel());
        _house = null;
        _houseUid = user?.uid;
        _observedHouseId = null;
        _hasHouseSnapshot = false;
        if (user != null) {
          _house = FirebaseDatabase.instance
              .ref('users/${user.uid}/houseId')
              .onValue
              .listen((event) {
                if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
                _hasHouseSnapshot = true;
                final value = event.snapshot.value;
                _observedHouseId = value is String && value.trim().isNotEmpty
                    ? value.trim()
                    : null;
                unawaited(refresh());
              }, onError: (Object error) => unawaited(refresh()));
        }
        unawaited(refresh());
      });
      _events = SoulEventService().changes.listen((_) => unawaited(refresh()));
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      L10nService().addListener(_onLanguageChanged);
      unawaited(refresh());
    } catch (error) {
      _reportError(error);
    }
  }

  void _onLanguageChanged() => unawaited(refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() {
    final revision = ++_revision;
    if (!supported) {
      status = SoulEventReminderStatus.unsupported;
      return Future.value();
    }
    final task = _queue.then((_) async {
      if (_disposed || revision != _revision) return;
      try {
        await _reconcile(revision);
      } catch (error) {
        if (revision == _revision) _reportError(error);
      }
    });
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  void _reportError(Object error) {
    status = SoulEventReminderStatus.failed;
    debugPrint(
      '[SoulEventReminderService] ${AppErrorMapper.resolve(error).message}',
    );
    if (!_disposed) notifyListeners();
  }

  Map<String, dynamic>? _payload(String? raw) {
    try {
      final value = jsonDecode(raw ?? '');
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  bool _active(int revision, String? uid) =>
      !_disposed &&
      revision == _revision &&
      FirebaseAuth.instance.currentUser?.uid == uid;

  Iterable<_Reminder> _occurrences(SoulEvent event, DateTime now) sync* {
    if (!event.reminderEnabled ||
        (event.isLunar && !event.hasConfirmedLunarDate)) {
      return;
    }
    var cursor = DateTime(now.year, now.month, now.day);
    // Giữ tối đa ba lần cho mỗi sự kiện; tổng ngân sách OS giới hạn bên dưới.
    var queued = 0;
    for (var count = 0; count < 4; count++) {
      final occurrence = event.calculateNextOccurrence(cursor);
      if (occurrence == null || occurrence.isBefore(cursor)) return;
      final minutes = event.reminderMinutes.clamp(0, 1439);
      final time = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (time.isAfter(now)) {
        yield _Reminder(event, time);
        if (++queued == 3) return;
      }
      if (!event.isAnniversary && !event.hasConfirmedLunarDate) return;
      cursor = DateTime(occurrence.year, occurrence.month, occurrence.day + 1);
    }
  }

  int _id(String uid, String houseId, _Reminder item) {
    final source =
        '$uid\u0000$houseId\u0000${item.event.id}\u0000${SoulEvent.dateKey(item.time)}';
    var hash = 0x811c9dc5;
    for (final unit in source.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return 0x20000000 | (hash & 0x0fffffff);
  }

  Future<void> _reconcile(int revision) async {
    final notifications = NotificationService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final pending = await notifications.pendingLocalNotifications();
    if (!_active(revision, uid)) return;
    final owned = {
      for (final item in pending)
        if (_payload(item.payload)?['type'] == payloadType) item.id: item,
    };
    // Hủy lịch của tài khoản cũ trước khi chờ đọc dữ liệu ngôi nhà.
    await notifications.cancelLocalNotifications(
      owned.entries
          .where((entry) => _payload(entry.value.payload)?['accountUid'] != uid)
          .map((entry) => entry.key),
    );
    if (!_active(revision, uid)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_active(revision, uid)) return;
    final enabled = prefs.getBool('il_notifications_enabled') ?? true;
    final permission =
        uid != null && enabled && await notifications.hasPermission();
    if (!_active(revision, uid)) return;
    if (uid == null || !enabled || !permission) {
      await notifications.cancelLocalNotifications(owned.keys);
      if (!_active(revision, uid)) return;
      status = !enabled
          ? SoulEventReminderStatus.disabled
          : uid == null
          ? SoulEventReminderStatus.ready
          : SoulEventReminderStatus.permissionDenied;
      notifyListeners();
      return;
    }
    final houseId = _hasHouseSnapshot && _houseUid == uid
        ? _observedHouseId
        : await HouseService().getCurrentHouseId().timeout(
            const Duration(seconds: 12),
          );
    if (!_active(revision, uid)) return;
    if (houseId == null || houseId.isEmpty) {
      await notifications.cancelLocalNotifications(owned.keys);
      if (!_active(revision, uid)) return;
      status = SoulEventReminderStatus.ready;
      notifyListeners();
      return;
    }
    final events = await SoulEventService().getEvents(houseId);
    if (!_active(revision, uid)) return;
    final now = DateTime.now();
    final candidates = [for (final event in events) ..._occurrences(event, now)]
      ..sort((a, b) {
        final byDate = a.time.compareTo(b.time);
        return byDate != 0 ? byDate : a.event.id.compareTo(b.event.id);
      });
    // iOS chỉ giữ 64 thông báo; dành chỗ cho tính năng khác của app.
    final otherCount = pending.length - owned.length;
    final budget = (60 - otherCount).clamp(0, maxReminders);
    final selected = candidates.take(budget);
    final takenIds = {
      for (final item in pending)
        if (!owned.containsKey(item.id)) item.id,
    };
    final planned =
        <
          int,
          ({
            _Reminder item,
            String title,
            String body,
            Map<String, dynamic> data,
          })
        >{};
    for (final item in selected) {
      var id = _id(uid, houseId, item);
      while (!takenIds.add(id)) {
        id = 0x20000000 | ((id + 1) & 0x0fffffff);
      }
      final title = L10nService().translate(
        'event_reminder_notification_title',
      );
      final body = L10nService().format('event_reminder_body', {
        'title': item.event.title,
        'date': SoulEvent.dateKey(item.time),
      });
      planned[id] = (
        item: item,
        title: title,
        body: body,
        data: {
          'screen': 'soul_events',
          'type': payloadType,
          'accountUid': uid,
          'houseId': houseId,
          'eventId': item.event.id,
          'scheduledMs': item.time.millisecondsSinceEpoch,
        },
      );
    }
    await notifications.cancelLocalNotifications(
      owned.keys.where((id) => !planned.containsKey(id)),
    );
    if (!_active(revision, uid)) return;
    if (planned.isNotEmpty && !await notifications.refreshLocalTimeZone()) {
      throw StateError('Cannot resolve local notification timezone');
    }
    if (!_active(revision, uid)) return;
    for (final entry in planned.entries) {
      final plan = entry.value;
      final old = owned[entry.key];
      final oldData = _payload(old?.payload);
      if (old?.title == plan.title &&
          old?.body == plan.body &&
          oldData?['scheduledMs'] == plan.data['scheduledMs'] &&
          oldData?['accountUid'] == uid &&
          oldData?['houseId'] == houseId &&
          oldData?['eventId'] == plan.item.event.id) {
        continue;
      }
      final scheduled = await notifications.scheduleLocalNotification(
        id: entry.key,
        title: plan.title,
        body: plan.body,
        scheduledDate: plan.item.time,
        data: plan.data,
      );
      if (!_active(revision, uid)) {
        await notifications.cancelLocalNotifications([entry.key]);
        return;
      }
      if (!scheduled) {
        status = SoulEventReminderStatus.failed;
        notifyListeners();
        return;
      }
    }
    status = candidates.length > budget
        ? SoulEventReminderStatus.limited
        : SoulEventReminderStatus.ready;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      L10nService().removeListener(_onLanguageChanged);
    }
    unawaited(_events?.cancel());
    unawaited(_auth?.cancel());
    unawaited(_house?.cancel());
    super.dispose();
  }
}
