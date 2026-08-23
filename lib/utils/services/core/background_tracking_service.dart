import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// ─────────────────────────────────────────────
// SMART SLEEP LOGIC CONSTANTS
// ─────────────────────────────────────────────

/// Khung ngủ đêm: 21:00 → 06:00 (hôm sau)
const int kNightSleepStartHour = 21;
const int kNightSleepEndHour = 6;

/// Khung nghỉ trưa: 11:30 → 13:30
const int kNoonNapStartHour = 11;
const int kNoonNapStartMinute = 30;
const int kNoonNapEndHour = 13;
const int kNoonNapEndMinute = 30;

/// Thời gian màn hình tắt tối thiểu để tính là ngủ (ban đêm/buổi trưa)
const int kMinOfflineMinutesForNightSleep = 20;
const int kMinOfflineMinutesForNoonNap = 30;

/// Khoảng thời gian mở máy ngắn trong khung ngủ mà vẫn tính là đang ngủ
/// (ví dụ: mở máy 5 phút đi WC rồi tắt lại)
const int kBriefWakeToleranceMinutes = 15;

/// Sau bao lâu offline (ngoài khung ngủ) thì chuyển sang "Không hoạt động"
/// (không kết luận ngủ)
const int kInactiveThresholdMinutes = 120;

// ─────────────────────────────────────────────
// HELPER: Kiểm tra khung giờ ngủ
// ─────────────────────────────────────────────

/// Trả về tên khung ngủ nếu thời điểm [now] nằm trong khung ngủ, null nếu không.
/// "night" = ban đêm, "noon" = nghỉ trưa
String? _getSleepWindow(DateTime now) {
  final h = now.hour;
  final m = now.minute;

  // Khung ban đêm: 21:00 → 06:00 (vượt qua nửa đêm)
  if (h >= kNightSleepStartHour || h < kNightSleepEndHour) {
    return 'night';
  }

  // Khung nghỉ trưa: 11:30 → 13:30
  final afterNoonStart = (h > kNoonNapStartHour) ||
      (h == kNoonNapStartHour && m >= kNoonNapStartMinute);
  final beforeNoonEnd =
      (h < kNoonNapEndHour) || (h == kNoonNapEndHour && m <= kNoonNapEndMinute);
  if (afterNoonStart && beforeNoonEnd) {
    return 'noon';
  }

  return null;
}

/// Số phút offline tối thiểu để tính là ngủ, tuỳ khung giờ
int _minOfflineMinutes(String sleepWindow) {
  return sleepWindow == 'noon'
      ? kMinOfflineMinutesForNoonNap
      : kMinOfflineMinutesForNightSleep;
}

// ─────────────────────────────────────────────
// PRESENCE STATUS VALUES
// ─────────────────────────────────────────────
const String kStatusSleeping = 'sleeping';
const String kStatusNoonNap = 'noon_nap';
const String kStatusInactive = 'inactive'; // Offline ngoài khung ngủ
const String kStatusAwake = 'awake';

// ─────────────────────────────────────────────
// WorkManager (iOS background periodic task)
// ─────────────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();
      final prefs = await SharedPreferences.getInstance();

      final isTrackingEnabled =
          prefs.getBool('is_sleep_tracking_enabled') ?? false;
      if (!isTrackingEnabled) return Future.value(true);

      final houseId = prefs.getString('il_rel_house_id');
      final role = prefs.getString('il_rel_role');

      if (houseId == null || role == null || houseId.isEmpty || role.isEmpty) {
        return Future.value(true);
      }

      if (Platform.isIOS) {
        final health = Health();
        final types = [
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_ASLEEP,
        ];
        await health.requestAuthorization(types);
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final data = await health.getHealthDataFromTypes(
            startTime: yesterday, endTime: now, types: types);

        bool isCurrentlySleeping = false;
        for (final d in data) {
          if (d.dateTo.isAfter(now.subtract(const Duration(hours: 1)))) {
            isCurrentlySleeping = true;
            break;
          }
        }

        final ref =
            FirebaseDatabase.instance.ref('houses/$houseId/presence/$role');
        if (isCurrentlySleeping) {
          final window = _getSleepWindow(now);
          final statusStr = window == 'noon' ? kStatusNoonNap : kStatusSleeping;
          await ref.update({
            'sleep_mode': true,
            'sleep_status': statusStr,
            'sleep_start_time': ServerValue.timestamp,
          });
        } else {
          final snapshot = await ref.get();
          if (snapshot.exists) {
            final map = Map<String, dynamic>.from(snapshot.value as Map);
            if (map['sleep_mode'] == true) {
              await _saveAndClearSleepSession(ref, map, houseId, role);
            }
          }
          await ref.update({
            'sleep_mode': false,
            'sleep_status': kStatusAwake,
          });
        }
      }
    } catch (e) {
      debugPrint('[BackgroundTracking] Workmanager error: $e');
    }
    return Future.value(true);
  });
}

// ─────────────────────────────────────────────
// Android foreground service entry point
// ─────────────────────────────────────────────

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final houseId = prefs.getString('il_rel_house_id');
  final role = prefs.getString('il_rel_role');

  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((_) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((_) => service.setAsBackgroundService());
  }
  service.on('stopService').listen((_) => service.stopSelf());

  if (houseId == null || role == null || houseId.isEmpty || role.isEmpty) {
    return;
  }

  final ref = FirebaseDatabase.instance.ref('houses/$houseId/presence/$role');

  // Timer định kỳ kiểm tra trạng thái offline timeout (mỗi 5 phút)
  Timer.periodic(const Duration(minutes: 5), (_) async {
    try {
      final trackingEnabled = (await SharedPreferences.getInstance())
              .getBool('is_sleep_tracking_enabled') ??
          false;
      if (!trackingEnabled) return;

      final snapshot = await ref.get();
      if (!snapshot.exists) return;
      final map = Map<String, dynamic>.from(snapshot.value as Map);

      final bool currentSleepMode = map['sleep_mode'] == true;
      final int lastScreenOff = map['last_screen_off'] ?? 0;
      final int lastScreenOn = map['last_screen_on'] ?? 0;
      final int lastActive = map['last_active'] ?? lastScreenOn;

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      if (currentSleepMode) {
        // Đang trong trạng thái ngủ: kiểm tra xem có bị kẹt không
        // (tắt máy / mất mạng → không bao giờ có screenOn)
        final sleepStartTime = map['sleep_start_time'] ?? 0;
        if (sleepStartTime > 0) {
          final sleepDurationHours =
              (nowMs - (sleepStartTime as int)) / (1000 * 3600);
          // Nếu ngủ quá 14 tiếng mà không thức → có thể bị kẹt, reset
          if (sleepDurationHours > 14) {
            debugPrint(
                '[SleepTracker] Sleep session >14h detected, auto-resetting.');
            await _saveAndClearSleepSession(ref, map, houseId, role);
            await ref.update({
              'sleep_mode': false,
              'sleep_status': kStatusAwake,
            });
          }
        }
        return; // Không thay đổi trạng thái ngủ ở đây (screenOn sẽ xử lý)
      }

      // Không trong chế độ ngủ: kiểm tra xem có nên chuyển sang ngủ không
      if (lastScreenOff <= 0) return;

      // Thời gian màn hình đã tắt (phút)
      final minutesOff = (nowMs - lastScreenOff) / 60000;

      // Kiểm tra "brief wake" tolerance: nếu có mở máy tạm trong khoảng này
      // nhưng vẫn trong cửa sổ ngủ, không reset
      final sleepWindow = _getSleepWindow(now);

      if (sleepWindow == null) {
        // Ngoài khung ngủ hoàn toàn
        final minutesInactive =
            lastActive > 0 ? (nowMs - lastActive) / 60000 : minutesOff;
        if (minutesInactive >= kInactiveThresholdMinutes &&
            map['sleep_status'] != kStatusInactive) {
          // Đã offline lâu ngoài giờ ngủ → "Không hoạt động"
          await ref.update({'sleep_status': kStatusInactive});
        }
        return;
      }

      // Trong khung ngủ: kiểm tra ngưỡng thời gian tối thiểu
      final minMinutes = _minOfflineMinutes(sleepWindow);
      if (minutesOff < minMinutes) return; // Chưa đủ thời gian, chờ thêm

      // Đủ điều kiện: chuyển sang ngủ
      final statusStr =
          sleepWindow == 'noon' ? kStatusNoonNap : kStatusSleeping;
      debugPrint(
          '[SleepTracker] Entering sleep mode: $statusStr (${minutesOff.toStringAsFixed(1)} min off)');
      await ref.update({
        'sleep_mode': true,
        'sleep_status': statusStr,
        'sleep_start_time': lastScreenOff, // Tính từ lúc tắt màn hình
      });
    } catch (e) {
      debugPrint('[BackgroundTracking] Periodic check error: $e');
    }
  });

  // Lắng nghe sự kiện màn hình
  Screen screen = Screen();
  screen.screenStateStream.listen((ScreenStateEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isTrackingEnabled =
          prefs.getBool('is_sleep_tracking_enabled') ?? false;
      if (!isTrackingEnabled) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (event == ScreenStateEvent.screenOff) {
        // Ghi thời điểm tắt màn hình, KHÔNG set ngủ ngay
        await ref.update({
          'last_screen_off': ServerValue.timestamp,
          // Reset inactive status khi màn hình vừa tắt
          'sleep_status': kStatusAwake,
        });
      } else if (event == ScreenStateEvent.screenOn) {
        final snapshot = await ref.get();
        if (!snapshot.exists) return;
        final map = Map<String, dynamic>.from(snapshot.value as Map);

        final bool wasSleeping = map['sleep_mode'] == true;
        final int lastScreenOff = map['last_screen_off'] ?? 0;
        final now = DateTime.now();
        final sleepWindow = _getSleepWindow(now);

        if (wasSleeping) {
          // Đang ngủ → bật màn hình lên

          if (sleepWindow != null && lastScreenOff > 0) {
            // Còn trong khung giờ ngủ → có thể chỉ là "brief wake" (đi WC...)
            // Ghi nhận last_active nhưng CHƯA kết thúc phiên ngủ
            await ref.update({
              'last_screen_on': ServerValue.timestamp,
              'last_active': nowMs,
              // Giữ nguyên sleep_mode = true để periodic timer tự xử lý
            });
            debugPrint(
                '[SleepTracker] Screen on during sleep window – monitoring brief wake.');
            return;
          }

          // Ngoài khung ngủ hoặc brief wake đã qua → kết thúc phiên ngủ
          await _saveAndClearSleepSession(ref, map, houseId, role);
          await ref.update({
            'last_screen_on': ServerValue.timestamp,
            'last_active': nowMs,
            'sleep_mode': false,
            'sleep_status': kStatusAwake,
          });
        } else {
          // Không đang ngủ, cập nhật last_active
          await ref.update({
            'last_screen_on': ServerValue.timestamp,
            'last_active': nowMs,
            'sleep_status': kStatusAwake,
            'sleep_mode': false,
          });
        }
      }
    } catch (e) {
      debugPrint('[BackgroundTracking] Screen event error: $e');
    }
  });
}

// ─────────────────────────────────────────────
// Helper: lưu lịch sử và xóa session ngủ
// ─────────────────────────────────────────────
Future<void> _saveAndClearSleepSession(
  DatabaseReference ref,
  Map<String, dynamic> map,
  String houseId,
  String role,
) async {
  final startTime = map['sleep_start_time'];
  if (startTime == null || startTime == 0) return;

  final endTime = DateTime.now().millisecondsSinceEpoch;
  final durationMs = endTime - (startTime as int);

  // Chỉ lưu nếu phiên ngủ >= 10 phút (loại bỏ nhiễu)
  if (durationMs < 10 * 60 * 1000) return;

  final historyRef = FirebaseDatabase.instance
      .ref('houses/$houseId/sleep_history/$role')
      .push();
  await historyRef.set({
    'start_time': startTime,
    'end_time': endTime,
    'duration_ms': durationMs,
    'sleep_status': map['sleep_status'] ?? kStatusSleeping,
  });

  debugPrint(
      '[SleepTracker] Session saved: ${(durationMs / 3600000).toStringAsFixed(2)}h');
}

// ─────────────────────────────────────────────
// Khởi tạo service
// ─────────────────────────────────────────────
class BackgroundTrackingService {
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isTrackingEnabled =
        prefs.getBool('is_sleep_tracking_enabled') ?? false;

    if (Platform.isIOS) {
      if (isTrackingEnabled) {
        await Workmanager().initialize(callbackDispatcher);
        await Workmanager().registerPeriodicTask(
          'sleep_tracker',
          'sleep_tracker_task',
          frequency: const Duration(minutes: 30),
        );

        final health = Health();
        final types = [
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_ASLEEP,
        ];
        await health.requestAuthorization(types);
      }
    } else if (Platform.isAndroid) {
      final service = FlutterBackgroundService();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'background_tracking_channel',
        'Tracking Service',
        description: 'This channel is used for tracking screen state.',
        importance: Importance.low,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: isTrackingEnabled,
          isForegroundMode: true,
          foregroundServiceTypes: [AndroidForegroundType.specialUse],
          notificationChannelId: 'background_tracking_channel',
          initialNotificationTitle: 'SoulLocket',
          initialNotificationContent: 'Chạy ngầm theo dõi giấc ngủ',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: (ServiceInstance service) {
            return true;
          },
        ),
      );

      // Nếu người dùng chưa bật tính năng, đảm bảo service không chạy ngầm
      if (!isTrackingEnabled) {
        try {
          final isRunning = await service.isRunning();
          if (isRunning) {
            service.invoke('stopService');
          }
        } catch (_) {}
      }
    }
  }

  /// Bật chạy ngầm khi người dùng chủ động bật trong app
  static Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sleep_tracking_enabled', true);

    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
    } else if (Platform.isIOS) {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        'sleep_tracker',
        'sleep_tracker_task',
        frequency: const Duration(minutes: 30),
      );
      try {
        final health = Health();
        final types = [
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_ASLEEP,
        ];
        await health.requestAuthorization(types);
      } catch (_) {}
    }
  }

  /// Tắt chạy ngầm khi người dùng tắt tính năng trong app
  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sleep_tracking_enabled', false);

    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      try {
        service.invoke('stopService');
      } catch (_) {}
    } else if (Platform.isIOS) {
      try {
        await Workmanager().cancelByUniqueName('sleep_tracker');
      } catch (_) {}
    }
  }
}
