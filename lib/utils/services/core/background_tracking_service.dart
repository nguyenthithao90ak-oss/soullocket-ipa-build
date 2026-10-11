import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../sleep_tracking_math.dart';
import '../../sleep_presence_state.dart';
import '../../sleep_service_startup.dart';
import '../../sleep_screen_journal.dart';
import '../sleep_tracking_service.dart';
import '../widget_service.dart';
import '../l10n_service.dart';

const sleepTaskIdentifier = 'com.soullocket.app.sleep.refresh';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      await Firebase.initializeApp();
      await SleepTrackingService.refreshHealth();
      return true;
    } catch (error) {
      debugPrint('[SleepTracker] Health refresh failed: $error');
      return false;
    }
  });
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    await _runSleepTracking(service);
  } catch (_) {
    debugPrint('[SleepTracker] Background initialization failed');
    final prefs = await SharedPreferences.getInstance();
    service.invoke('sleepReady', {
      'ready': false,
      'scope': prefs.getString('sleep_tracking_scope'),
    });
    await service.stopSelf();
  }
}

Future<void> _runSleepTracking(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final scope = await SleepTrackingService.readCachedScope(prefs);
  if (scope == null ||
      prefs.getBool('is_sleep_tracking_enabled') != true ||
      prefs.getString('sleep_tracking_scope') != scope.token) {
    await service.stopSelf();
    return;
  }
  final uid = scope.uid, house = scope.house, role = scope.role;
  final ref = FirebaseDatabase.instance.ref('houses/$house/presence/$role');
  Timer? timer;
  StreamSubscription<ScreenStateEvent>? screenSub;
  StreamSubscription<Map<String, dynamic>?>? stopSub;
  StreamSubscription<Map<String, dynamic>?>? statusSub;
  Future<void> pending = Future.value();
  Future<void> localPending = Future.value();
  final journal = SleepScreenJournal.read(
    scope.token,
    prefs.getString('sleep_screen_journal'),
  );
  bool syncing = false;
  bool stopped = false;
  Future<void> shutdown() async {
    if (stopped) return;
    stopped = true;
    timer?.cancel();
    await screenSub?.cancel();
    await statusSub?.cancel();
    await stopSub?.cancel();
    await service.stopSelf();
  }

  Future<bool> current() async {
    await prefs.reload();
    if (stopped ||
        FirebaseAuth.instance.currentUser?.uid != uid ||
        prefs.getBool('is_sleep_tracking_enabled') != true ||
        prefs.getString('sleep_tracking_scope') != scope.token) {
      return false;
    }
    // Token chứa UID/House/role; đổi tài khoản, nhà hoặc vai đều làm lệch token.
    return (await SleepTrackingService.readCachedScope(prefs))?.token ==
        scope.token;
  }

  void enqueue(Future<void> Function() job) {
    pending = pending
        .then((_) async {
          if (await current()) {
            await job();
          } else {
            await shutdown();
          }
        })
        .catchError((Object e) {
          debugPrint('[SleepTracker] Screen estimate update failed');
        });
  }

  Future<void> persistLocal() async {
    if (!await current()) return;
    await prefs.setString('sleep_screen_journal', journal.encode());
    service.invoke('sleepLocal', {'scope': scope.token});
  }

  // Ghi máy và ghi mạng có hàng đợi riêng: offline không làm mất sự kiện màn hình.
  Future<void> flush() async {
    if (syncing || !await current()) return;
    syncing = true;
    try {
      // Transaction cần snapshot ban đầu; không abort vì cache native chưa nạp.
      await ref.get().timeout(const Duration(seconds: 10));
      for (final event in [...journal.events]) {
        if (!await current()) return;
        SleepRecord? ended;
        final result = await ref
            .runTransaction((raw) {
              if (stopped || FirebaseAuth.instance.currentUser?.uid != uid)
                return Transaction.abort();
              final p = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};
              if (p['sleep_tracking_enabled'] != true)
                return Transaction.abort();
              final next = screenSleepPresence(
                p,
                screenOn: event.screenOn,
                at: event.at,
                timestamp: ServerValue.timestamp,
              );
              ended = event.screenOn
                  ? completedScreenSleep(next, event.at)
                  : null;
              return Transaction.success(next);
            }, applyLocally: false)
            .timeout(const Duration(seconds: 10));
        if (!result.committed) return;
        final record = ended;
        if (record != null && await current()) {
          await FirebaseDatabase.instance
              .ref('houses/$house/sleep_history/$role/estimate_${record.start}')
              .set(record.toMap('screen_estimate'))
              .timeout(const Duration(seconds: 10));
        }
        final saved = localPending.then((_) async {
          journal.acknowledge(event);
          await persistLocal();
        });
        localPending = saved.catchError((Object _) {});
        await saved;
      }
      if (!await current()) return;
      await ref
          .runTransaction((raw) {
            if (stopped ||
                FirebaseAuth.instance.currentUser?.uid != uid ||
                raw is! Map)
              return Transaction.abort();
            final p = Map<String, dynamic>.from(raw);
            final next = automatedSleepPresence(
              p,
              tickScreenSleepPresence(p, DateTime.now()),
            );
            return next == null
                ? Transaction.abort()
                : Transaction.success({
                    ...next,
                    'sleep_updated_at': ServerValue.timestamp,
                  });
          }, applyLocally: false)
          .timeout(const Duration(seconds: 10));
      await prefs.setInt(
        'sleep_screen_synced_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      service.invoke('sleepLocal', {'scope': scope.token});
      try {
        if (await current())
          await WidgetService.syncSleepWidgetData(
            houseId: house,
          ).timeout(const Duration(seconds: 8));
      } catch (_) {
        debugPrint('[SleepTracker] Widget sync deferred');
      }
    } finally {
      syncing = false;
    }
  }

  void observe(bool screenOn, int at) {
    localPending = localPending
        .then((_) async {
          if (!await current()) return;
          journal.observe(SleepScreenEvent(at, screenOn));
          await persistLocal();
          enqueue(flush);
        })
        .catchError((Object _) {
          debugPrint('[SleepTracker] Local screen event failed');
        });
  }

  stopSub = service.on('stopService').listen((_) => unawaited(shutdown()));
  timer = Timer.periodic(const Duration(minutes: 1), (_) {
    localPending = localPending
        .then((_) async {
          if (!await current()) return;
          journal.presence = tickScreenSleepPresence(
            journal.presence,
            DateTime.now(),
          );
          await persistLocal();
          enqueue(flush);
        })
        .catchError((Object _) {
          debugPrint('[SleepTracker] Local estimate deferred');
        });
  });
  screenSub = Screen().screenStateStream.listen(
    (event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (event == ScreenStateEvent.screenOff) {
        observe(false, now);
      } else if (event == ScreenStateEvent.screenOn ||
          event == ScreenStateEvent.screenUnlocked) {
        observe(true, now);
      }
    },
    onError: (Object error) async {
      debugPrint('[SleepTracker] Screen events unavailable');
      await prefs.reload();
      if (FirebaseAuth.instance.currentUser?.uid == uid &&
          prefs.getString('sleep_tracking_scope') == scope.token) {
        await prefs.setBool('is_sleep_tracking_enabled', false);
        service.invoke('sleepReady', {'ready': false, 'scope': scope.token});
        unawaited(
          SleepTrackingService.setEnabled(
            false,
            expectedHouseId: house,
            expectedUid: uid,
          ).catchError((Object _) {
            debugPrint('[SleepTracker] Remote disable deferred');
          }),
        );
      }
      await shutdown();
    },
  );
  statusSub = service.on('sleepStatus').listen((message) async {
    if (message?['scope'] == scope.token && await current()) {
      // Yêu cầu này chỉ được gửi lúc app ở foreground; không đoán màn hình khi reboot.
      if (message?['foreground'] == true)
        observe(true, DateTime.now().millisecondsSinceEpoch);
      service.invoke('sleepReady', {'ready': true, 'scope': scope.token});
    }
  });
  if (await current())
    service.invoke('sleepReady', {'ready': true, 'scope': scope.token});
  enqueue(flush);
}

class BackgroundTrackingService {
  static Future<void> initialize({bool? autoStart}) async {
    final enabled = await SleepTrackingService.isEnabled();
    if (Platform.isIOS) {
      if (enabled) {
        await _schedule();
        await SleepTrackingService.refreshHealth();
      }
      return;
    }
    if (!Platform.isAndroid) return;
    final l10n = L10nService();
    final channel = AndroidNotificationChannel(
      'background_tracking_channel',
      l10n.translate('sleep_notification_title'),
      description: l10n.translate('sleep_notification_channel_description'),
      importance: Importance.low,
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final configured = await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: autoStart ?? enabled,
        autoStartOnBoot: enabled,
        foregroundServiceTypes: const [AndroidForegroundType.specialUse],
        isForegroundMode: true,
        notificationChannelId: 'background_tracking_channel',
        initialNotificationTitle: l10n.translate('sleep_notification_title'),
        initialNotificationContent: l10n.translate(
          'sleep_notification_body_android',
        ),
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    if (!configured) throw StateError('sleep_start_failed');
    if (!enabled) FlutterBackgroundService().invoke('stopService');
  }

  static Future<void> _schedule() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      sleepTaskIdentifier,
      sleepTaskIdentifier,
      frequency: const Duration(minutes: 30),
    );
  }

  static Future<void> start({required String houseId, String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    uid ??= FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('sleep_scope_missing');
    if (!Platform.isAndroid && !Platform.isIOS)
      throw StateError('sleep_platform_unsupported');
    await SleepTrackingService.prepareScope(houseId: houseId, expectedUid: uid);
    // UI hỏi quyền trước; không lưu trạng thái bật nếu khởi tạo thất bại.
    if (Platform.isIOS && !await SleepTrackingService.requestHealthAccess())
      throw StateError('sleep_authorization_failed');
    try {
      await SleepTrackingService.setEnabled(
        true,
        expectedHouseId: houseId,
        expectedUid: uid,
      );
      if (Platform.isIOS) {
        await _schedule();
        // Lỗi đọc Health tạm thời không phải lỗi consent/khởi tạo.
        try {
          await SleepTrackingService.refreshHealth();
        } catch (_) {
          debugPrint('[SleepTracker] Initial Health refresh deferred');
        }
      } else {
        await initialize(autoStart: false);
        await _startAndroid(prefs.getString('sleep_tracking_scope')!);
      }
    } catch (e) {
      await prefs.reload();
      // Không hoàn tác vào tài khoản/House mới nếu người dùng đổi phiên.
      final active = await SleepTrackingService.readCachedScope(prefs);
      if (FirebaseAuth.instance.currentUser?.uid == uid &&
          active?.house == houseId) {
        await prefs.setBool('is_sleep_tracking_enabled', false);
        await prefs.remove('sleep_tracking_scope');
        if (Platform.isAndroid)
          FlutterBackgroundService().invoke('stopService');
        try {
          await SleepTrackingService.setEnabled(
            false,
            expectedHouseId: houseId,
            expectedUid: uid,
          );
        } catch (_) {
          /* Giữ lỗi khởi tạo gốc. */
        }
      }
      rethrow;
    }
  }

  static Future<void> _startAndroid(String scope) async {
    final service = FlutterBackgroundService();
    await startSleepService(
      scope: scope,
      readiness: service.on('sleepReady'),
      isRunning: service.isRunning,
      start: service.startService,
      requestStatus: () =>
          service.invoke('sleepStatus', {'scope': scope, 'foreground': true}),
    );
  }

  /// Giữ consent đã có, kiểm tra phản hồi thật và khởi động lại service bị dừng.
  static Future<bool> ensureRunning({
    required String houseId,
    required String uid,
  }) async {
    await SleepTrackingService.prepareScope(houseId: houseId, expectedUid: uid);
    if (!await SleepTrackingService.isEnabled()) return false;
    if (Platform.isIOS) {
      await _schedule();
      return true;
    }
    if (!Platform.isAndroid) return false;
    await initialize(autoStart: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await _startAndroid(prefs.getString('sleep_tracking_scope')!);
    return true;
  }

  static Future<Map<String, dynamic>> readLocalPresence(String scope) async {
    if (!Platform.isAndroid) return {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final journal = SleepScreenJournal.read(
      scope,
      prefs.getString('sleep_screen_journal'),
    );
    if (journal.presence['last_screen_on'] == null &&
        journal.presence['last_screen_off'] == null)
      return {};
    return {
      ...journal.presence,
      'pending': journal.events.isNotEmpty,
      'synced_at': prefs.getInt('sleep_screen_synced_at') ?? 0,
    };
  }

  static Future<void> stop({String? houseId, String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    // Chỉ chặn khi biết chắc đang ở nhà khác; thiếu bản sao prefs vẫn phải tắt được.
    final active = await SleepTrackingService.readCachedScope(prefs);
    if ((uid != null && FirebaseAuth.instance.currentUser?.uid != uid) ||
        (houseId != null && active != null && active.house != houseId))
      throw StateError('sleep_scope_changed');
    await prefs.setBool('is_sleep_tracking_enabled', false);
    await prefs.remove('sleep_tracking_scope');
    try {
      if (Platform.isAndroid)
        FlutterBackgroundService().invoke('stopService');
      else if (Platform.isIOS)
        await Workmanager().cancelByUniqueName(sleepTaskIdentifier);
    } finally {
      await SleepTrackingService.setEnabled(
        false,
        expectedHouseId: houseId,
        expectedUid: uid,
      );
    }
  }
}
