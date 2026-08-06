import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:soullocket_app/views/app_entry.dart';
import 'package:soullocket_app/views/chat/chat_detail_screen.dart';
import 'package:soullocket_app/views/chat/watch_together_screen.dart';
import 'package:soullocket_app/views/home/home_screen.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge_screen.dart';
import 'package:soullocket_app/views/utilities/creative_diary_screen.dart';
import 'package:soullocket_app/views/utilities/cinema_screen.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'house_service.dart';
import 'offline_cache_service.dart';
import 'role_utils.dart';
import 'widget_service.dart';
import 'l10n_service.dart';

/// NotificationService — Gra (Logic/Data) chịu trách nhiệm toàn bộ
/// Chức năng:
///   1. Lấy FCM Token và lưu vào Firebase (để Admin Panel gửi được)
///   2. Xử lý thông báo khi App đang mở (Foreground)
///   3. Xử lý thông báo khi App đang tắt (Background/Terminated)
///   4. Hiển thị Local Notification với âm thanh/icon đẹp
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  bool _isInitialized = false;
  Future<void>? _initializingTask;
  bool _didCheckInitialMessage = false;
  String? _lastForegroundMessageKey;
  DateTime? _lastForegroundShownAt;
  String? _lastOpenedMessageKey;
  DateTime? _lastOpenedHandledAt;
  bool _timeZoneReady = false;

  static const int _dailySleepReminderId = 21450045;

  // Kênh thông báo Android (phải khai báo trước khi dùng)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'soullocket_high_importance', // id
    'SoulLocket Thông Báo', // name
    description: 'Thông báo quan trọng từ người ấy 💕',
    importance: Importance.high,
    playSound: true,
  );

  Future<bool> hasPermission() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Gọi khi user chủ động bấm xin quyền
  Future<bool> requestPermissionAndInit() async {
    if (await hasPermission()) {
      await initialize();
      return true;
    }

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await initialize();
      return true;
    }
    return false;
  }

  /// Khởi tạo toàn bộ hệ thống thông báo — gọi 1 lần trong main.dart
  Future<void> initialize() async {
    if (_isInitialized) {
      await _saveFcmToken();
      await syncDailySleepReminder();
      return;
    }
    if (_initializingTask != null) {
      await _initializingTask;
      return;
    }

    // 1. Kiểm tra quyền thông báo hiện tại (KHÔNG TỰ Ý XIN QUYỀN)
    final permissionGranted = await hasPermission();

    if (!permissionGranted) {
      // User chưa cấp quyền hoặc đã từ chối, không làm gì thêm, đợi user bấm "Cấp quyền" trong Settings
      return;
    }

    final task = () async {
      try {
        await _localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);

        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const DarwinInitializationSettings iosSettings =
            DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const WindowsInitializationSettings windowsSettings =
            WindowsInitializationSettings(
          appName: 'SoulLocket',
          appUserModelId: 'SoulLocket.App',
          guid: '8d76c80d-3f20-4f42-9ad0-7f3f148bf17c',
        );

        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          windows: windowsSettings,
        );

        await _localNotif.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: _onNotificationTap,
        );

        await _saveFcmToken();

        // iOS: Bật hiển thị thông báo khi app đang mở (foreground)
        // Nếu không gọi dòng này, iOS sẽ âm thầm bỏ qua notification khi app ở foreground.
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        _tokenRefreshSubscription ??=
            _fcm.onTokenRefresh.listen(_onTokenRefresh);
        _foregroundSubscription ??=
            FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
            .listen(_handleMessageOpenedApp);

        if (!_didCheckInitialMessage) {
          final initialMessage = await _fcm.getInitialMessage();
          _didCheckInitialMessage = true;
          if (initialMessage != null) {
            _handleMessageOpenedApp(initialMessage);
          }
        }

        _isInitialized = true;
        await syncDailySleepReminder();
      } catch (error) {
        debugPrint(
            'NotificationService initialize error: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể khởi tạo thông báo lúc này.',
        ).message}');
      } finally {}
    }();

    _initializingTask = task;
    try {
      await task;
    } finally {
      if (identical(_initializingTask, task)) {
        _initializingTask = null;
      }
    }
  }

  /// Lưu FCM Token vào Firebase để Admin Panel và Cloud Function có thể dùng
  Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // iOS yêu cầu phải có APNS Token trước, nếu chưa có thì chờ tối đa 3 giây.
    // Nếu bỏ qua bước này, getToken() sẽ trả về null trên thiết bị thật iOS.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      String? apnsToken;
      for (var i = 0; i < 6; i++) {
        apnsToken = await _fcm.getAPNSToken();
        if (apnsToken != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apnsToken == null) {
        debugPrint(
            '[NotificationService] APNS token not available yet, skipping FCM token save.');
        return;
      }
    }

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseDatabase.instance
        .ref('users/${user.uid}/fcmToken')
        .set(token);

    // FCM token giờ chỉ lưu độc lập tại users/{uid}/fcmToken
    // Không lưu gộp vào houses/{houseId}/fcmTokens nữa để tách biệt hoàn toàn thiết bị theo UID
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseDatabase.instance
        .ref('users/${user.uid}/fcmToken')
        .set(newToken);

    // FCM token giờ chỉ lưu độc lập tại users/{uid}/fcmToken
    // Không lưu gộp vào houses/{houseId}/fcmTokens nữa để tách biệt hoàn toàn thiết bị theo UID
  }

  /// Dọn dẹp FCM token khi người dùng đăng xuất
  Future<void> clearTokenOnSignOut() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Xóa ở đường dẫn chính nơi token được lưu
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/fcmToken')
            .remove();
      }
    } catch (e) {
      debugPrint('[NotificationService] clearTokenOnSignOut error: $e');
    }

    // Xóa FCM token local trên thiết bị để ngắt hoàn toàn việc nhận notification
    try {
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[NotificationService] deleteToken error: $e');
    }
  }

  /// Xử lý thông báo khi App đang mở — hiển thị Local Notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString() ?? '';
    final screen = message.data['screen']?.toString() ?? '';

    // Đồng bộ iOS Widget cho Soul Merge
    if (type == 'soul_merge' || screen == 'soul_merge') {
      try {
        final text = message.notification?.body ??
            message.data['text'] ??
            'Có tin nhắn mới 💕';
        final senderName = message.data['senderName']?.toString() ?? 'Người ấy';
        await WidgetService.syncSoulMergeWidgetData(
            message: text.toString(), senderName: senderName);
      } catch (_) {}
    }

    final isInteractionOrMerge = type == 'soul_merge' ||
        screen == 'soul_merge' ||
        type == 'partner_care' ||
        type == 'interaction' ||
        type == 'photo_shot';

    // Yêu cầu: Không hiện thông báo in-app (Overlay/Heads-up) khi đang trong app đối với sự kiện gửi icon/bắn tim/tương tác (ôm, hôn...)
    // Chỉ hiện thông báo Push Notification của Hệ thống khi khóa màn hình hoặc thoát app.
    if (isInteractionOrMerge) return;

    final isOverlayTarget = type == 'chat' || screen == 'chat';

    // 1. Luôn hiển thị bong bóng (nếu được cấp quyền) ngay cả khi không có notification block (Data-only FCM)
    if (isOverlayTarget) {
      try {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        if (granted) {
          final active = await FlutterOverlayWindow.isActive();
          if (!active) {
            await FlutterOverlayWindow.showOverlay(
              enableDrag: true,
              height: 100,
              width: 100,
              alignment: OverlayAlignment.centerRight,
              overlayTitle: 'Bong bóng tâm hồn',
              overlayContent: 'Lời thì thầm đang kết nối...',
            );
          }
        }
      } catch (e) {
        debugPrint('Error showing overlay in foreground: $e');
      }
    }

    // 2. Xử lý hiển thị heads-up (Local Notification)
    final notification = message.notification;
    if (notification == null || _shouldSkipForegroundMessage(message)) return;

    await showLocalNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
      data: message.data,
      dedupeKey: _messageKey(message),
    );
  }

  /// Xử lý khi user tap vào thông báo mở App
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (_shouldSkipOpenedMessage(message)) return;
    _navigateFromData(message.data);
  }

  /// Xử lý khi user tap vào Local Notification
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    final decoded = jsonDecode(response.payload!);
    if (decoded is Map) {
      _navigateFromData(Map<String, dynamic>.from(decoded));
    }
  }

  Future<void> _navigateFromData(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    final screen = data['screen']?.toString() ?? 'home';
    final houseService = HouseService();
    final myHouseId = await houseService.getCurrentHouseId();

    Widget destination;
    switch (screen) {
      case 'chat':
        final targetHouseId = data['targetHouseId']?.toString() ??
            data['target_house_id']?.toString();
        final targetName = data['target_name']?.toString() ?? 'Người ấy';
        if (myHouseId == null ||
            targetHouseId == null ||
            targetHouseId.isEmpty) {
          destination = const HomeScreen(initialTab: 1);
        } else {
          destination = ChatDetailScreen(
            myHouseId: myHouseId,
            targetHouseId: targetHouseId,
            targetName: targetName,
          );
        }
        break;
      case 'watch_together':
        final targetHouseId = data['targetHouseId']?.toString() ??
            data['target_house_id']?.toString();
        final targetName = data['target_name']?.toString() ?? 'Người ấy';
        if (myHouseId == null ||
            targetHouseId == null ||
            targetHouseId.isEmpty) {
          destination = const HomeScreen(initialTab: 1);
        } else {
          destination = WatchTogetherScreen(
            myHouseId: myHouseId,
            targetHouseId: targetHouseId,
            targetName: targetName,
            initialUrl: data['url']?.toString(),
          );
        }
        break;
      case 'cinema':
        final targetHouseId = data['houseId']?.toString() ??
            data['targetHouseId']?.toString() ??
            data['target_house_id']?.toString() ??
            myHouseId;
        if (targetHouseId == null || targetHouseId.isEmpty) {
          destination = const HomeScreen(initialTab: 3);
        } else {
          final myName =
              await _resolveCurrentUserCinemaName(houseService, targetHouseId);
          final inviteId =
              data['inviteId']?.toString() ?? data['invite_id']?.toString();
          destination = CinemaScreen(
            houseId: targetHouseId,
            myName: myName,
            initialUrl: data['url']?.toString(),
            initialTitle: data['title']?.toString(),
            autoJoinInviteId:
                inviteId == null || inviteId.isEmpty ? null : inviteId,
          );
        }
        break;
      case 'diary':
        destination = const HomeScreen(initialTab: 2);
        break;
      case 'utilities':
        destination = const HomeScreen(initialTab: 3);
        break;
      case 'game':
        destination = const HomeScreen(initialTab: 4);
        break;
      case 'update':
        destination = const HomeScreen(initialTab: 5);
        break;
      case 'creative_diary':
        destination = const CreativeDiaryScreen();
        break;
      case 'soul_merge':
        destination = const SoulMergeScreen();
        break;
      case 'feed':
        destination = const HomeScreen(initialTab: 1);
        break;
      case 'home':
      default:
        destination = const AppEntry();
        break;
    }

    await navigator.push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  Future<String> _resolveCurrentUserCinemaName(
    HouseService houseService,
    String houseId,
  ) async {
    final fallback =
        FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty ==
                true
            ? FirebaseAuth.instance.currentUser!.displayName!.trim()
            : 'Bạn';

    try {
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      final role = RoleUtils.normalize(prefs.getString('il_role'));
      final settings = await houseService.getHouseSettings(houseId);
      if (settings == null) return fallback;
      final key = role == 'user2' ? 'nameU2' : 'nameU1';
      final resolved = settings[key]?.toString().trim() ?? '';
      return resolved.isEmpty ? fallback : resolved;
    } catch (_) {
      return fallback;
    }
  }

  String _messageKey(RemoteMessage message) {
    return message.messageId ??
        '${message.sentTime?.millisecondsSinceEpoch ?? 0}|'
            '${message.notification?.title ?? ''}|'
            '${message.notification?.body ?? ''}|'
            '${jsonEncode(message.data)}';
  }

  bool _shouldSkipForegroundMessage(RemoteMessage message) {
    final key = _messageKey(message);
    final now = DateTime.now();
    final shouldSkip = _lastForegroundMessageKey == key &&
        _lastForegroundShownAt != null &&
        now.difference(_lastForegroundShownAt!) < const Duration(seconds: 5);
    _lastForegroundMessageKey = key;
    _lastForegroundShownAt = now;
    return shouldSkip;
  }

  bool _shouldSkipOpenedMessage(RemoteMessage message) {
    final key = _messageKey(message);
    final now = DateTime.now();
    final shouldSkip = _lastOpenedMessageKey == key &&
        _lastOpenedHandledAt != null &&
        now.difference(_lastOpenedHandledAt!) < const Duration(seconds: 5);
    _lastOpenedMessageKey = key;
    _lastOpenedHandledAt = now;
    return shouldSkip;
  }

  int _notificationIdForPayload(
    Map<String, dynamic> payloadData,
    String fallbackKey,
  ) {
    final type = payloadData['type']?.toString() ?? '';
    if (type == 'partner_care') {
      final careType = payloadData['careType']?.toString() ?? '';
      if (careType == 'kiss') {
        return fallbackKey.hashCode;
      }
      return 'partner_care_latest'.hashCode;
    }
    return fallbackKey.hashCode;
  }

  NotificationDetails _notificationDetails({bool isCinemaInvite = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFFF6B9D),
        actions: isCinemaInvite
            ? <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'cinema_accept',
                  'Chấp nhận',
                  showsUserInterface: true,
                ),
              ]
            : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? dedupeKey,
  }) async {
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    await initialize();
    if (!await hasPermission()) return;

    final payloadData = <String, dynamic>{...?data};
    final key = dedupeKey ?? '$title|$body|${jsonEncode(payloadData)}';
    final now = DateTime.now();
    final shouldSkip = _lastForegroundMessageKey == key &&
        _lastForegroundShownAt != null &&
        now.difference(_lastForegroundShownAt!) < const Duration(seconds: 5);
    _lastForegroundMessageKey = key;
    _lastForegroundShownAt = now;
    if (shouldSkip) return;
    final isCinemaInvite = payloadData['type']?.toString() == 'cinema_invite';
    final notificationId = _notificationIdForPayload(payloadData, key);

    await _localNotif.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: _notificationDetails(isCinemaInvite: isCinemaInvite),
      payload: jsonEncode(payloadData),
    );
  }

  /// Gửi thông báo cho đối phương trong cùng house (qua Firebase trigger)
  /// Hàm này ghi trigger vào Firebase, Cloud Function sẽ tự gửi FCM
  Future<void> sendPartnerNotification({
    required String houseId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance.ref('notification_queue').push().set({
        'houseId': houseId,
        'house_id': houseId,
        'sender_uid': user.uid,
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint(
          'Failed to queue partner notification: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xếp hàng thông báo cho đối tác.',
      ).message}');
    }
  }

  /// Gửi thông báo cho toàn bộ các thiết bị trong nhà (bao gồm cả người gửi)
  Future<void> sendHouseNotification({
    required String houseId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance.ref('notification_queue').push().set({
        'houseId': houseId,
        'house_id': houseId,
        'sender_uid': user.uid,
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Failed to queue house notification: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xếp hàng thông báo cho house.',
      ).message}');
    }
  }

  /// Gửi thông báo "Tôi nhớ bạn" cho người yêu
  Future<void> sendMissYouNotification(String houseId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Người ấy';
    await sendPartnerNotification(
      houseId: houseId,
      title: '💕 $name nhớ bạn!',
      body: '$name vừa gửi một khoảnh khắc nhớ nhung đến bạn...',
      data: {'screen': 'home', 'type': 'miss_you'},
    );
  }

  /// Gửi thông báo khi đăng bài mới lên feed
  Future<void> sendNewPostNotification(String houseId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Người ấy';
    await sendPartnerNotification(
      houseId: houseId,
      title: '📸 $name vừa đăng ảnh mới!',
      body: 'Xem ngay khoảnh khắc mới nhất của người ấy 💖',
      data: {'screen': 'feed', 'post_id': postId, 'type': 'new_post'},
    );
  }

  /// Cài đặt thông báo cục bộ theo thời gian
  Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;
    if (kIsWeb) return;

    await initialize();
    if (!_isInitialized || !await hasPermission()) return;
    if (!await _ensureTimeZoneReady()) return;

    await _localNotif.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: _notificationDetails(),
      payload: jsonEncode(<String, dynamic>{
        'screen': 'home',
        'type': 'scheduled_local',
      }),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> syncDailySleepReminder() async {
    if (kIsWeb || !_isInitialized) return;

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('il_notifications_enabled') ?? true;
    final sleepReminderEnabled =
        prefs.getBool('il_smart_reminder_sleep') ?? true;
    if (!notificationsEnabled ||
        !sleepReminderEnabled ||
        !await hasPermission()) {
      await cancelDailySleepReminder();
      return;
    }
    if (!await _ensureTimeZoneReady()) return;

    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    final displayName = await _resolveSleepReminderDisplayName(prefs, role);

    await _localNotif.cancel(id: _dailySleepReminderId);
    await _localNotif.zonedSchedule(
      id: _dailySleepReminderId,
      title: buildSleepReminderTitle(displayName),
      body: buildSleepReminderMessage(displayName),
      scheduledDate: _nextDailySleepReminderTime(),
      notificationDetails: _notificationDetails(),
      payload: jsonEncode(<String, dynamic>{
        'screen': 'home',
        'type': 'daily_sleep_reminder',
        'role': role,
      }),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailySleepReminder() async {
    if (!_isInitialized) return;
    await _localNotif.cancel(id: _dailySleepReminderId);
  }

  String buildSleepReminderTitle(String displayName) {
    return '🌙 Đến giờ ngủ rồi, $displayName ơi ❤️';
  }

  String buildSleepReminderMessage(String displayName) {
    final safeName =
        displayName.trim().isNotEmpty ? displayName.trim() : 'người thương';
    return 'Ngủ ngoan nha, $safeName ơi. Khép lại một ngày dài, để trái tim đỏ này ôm bạn vào một giấc mơ thật dịu và thật ấm nhé ❤️';
  }

  Future<bool> _ensureTimeZoneReady() async {
    if (kIsWeb) return false;
    if (_timeZoneReady) return true;

    try {
      tzdata.initializeTimeZones();
      final rawTimeZone = (await FlutterTimezone.getLocalTimezone()).identifier;
      final normalizedTimeZone = _normalizeTimeZoneName(rawTimeZone);
      tz.setLocalLocation(tz.getLocation(normalizedTimeZone));
      _timeZoneReady = true;
      return true;
    } catch (e) {
      debugPrint('Notification timezone init failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể khởi tạo múi giờ thông báo.',
      ).message}');
      return false;
    }
  }

  String _normalizeTimeZoneName(String rawTimeZone) {
    const aliases = <String, String>{
      'SE Asia Standard Time': 'Asia/Bangkok',
      'Asia/Saigon': 'Asia/Ho_Chi_Minh',
    };
    return aliases[rawTimeZone] ?? rawTimeZone;
  }

  Future<String> _resolveSleepReminderDisplayName(
    SharedPreferences prefs,
    String role,
  ) async {
    final fallback = role == 'user2'
        ? L10nService().translate('female_role_default')
        : L10nService().translate('male_role_default');
    final cachedAuthUid = (prefs.getString('il_auth_uid') ?? '').trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final canUseSessionCache =
        currentUid.isNotEmpty && cachedAuthUid == currentUid;
    final cachedUserName = canUseSessionCache
        ? (prefs.getString('il_user_name') ?? '').trim()
        : '';
    final cachedHouseId =
        canUseSessionCache ? (prefs.getString('il_house_id') ?? '').trim() : '';
    final houseId = cachedHouseId.isNotEmpty
        ? cachedHouseId
        : (await HouseService().getCurrentHouseId())?.trim() ?? '';
    if (houseId.isEmpty) {
      return cachedUserName.isNotEmpty ? cachedUserName : fallback;
    }

    try {
      final settings = await HouseService().getHouseSettings(houseId);
      final key = role == 'user2' ? 'nameU2' : 'nameU1';
      final resolvedName = settings?[key]?.toString().trim() ?? '';
      if (resolvedName.isNotEmpty) {
        return resolvedName;
      }
    } catch (_) {}

    return cachedUserName.isNotEmpty ? cachedUserName : fallback;
  }

  String buildSleepReminderBody(String displayName) {
    return 'Ngủ ngoan nha, $displayName ơi. Khép lại một ngày dài, để trái tim đỏ này ôm bạn vào một giấc mơ thật dịu và thật ấm nhé ❤️';
  }

  Future<void> checkAutoSleepGreetings(String houseId) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('il_notifications_enabled') ?? true;
    if (!notificationsEnabled) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    final displayName = await _resolveSleepReminderDisplayName(prefs, role);

    final nightTimeStr = prefs.getString('il_good_night_time') ?? '22:15';
    final nightParts = nightTimeStr.split(':');
    final nightHour =
        nightParts.isNotEmpty ? (int.tryParse(nightParts[0]) ?? 22) : 22;
    final nightMinute =
        nightParts.length > 1 ? (int.tryParse(nightParts[1]) ?? 15) : 15;

    final morningTimeStr = prefs.getString('il_good_morning_time') ?? '05:55';
    final morningParts = morningTimeStr.split(':');
    final morningHour =
        morningParts.isNotEmpty ? (int.tryParse(morningParts[0]) ?? 5) : 5;
    final morningMinute =
        morningParts.length > 1 ? (int.tryParse(morningParts[1]) ?? 55) : 55;

    await _maybeSendAutoTimedGreeting(
      houseId: houseId,
      kind: 'good_night',
      targetHour: nightHour,
      targetMinute: nightMinute,
      windowEndHour: 23,
      windowEndMinute: 59,
      title: '🌙✨ $displayName ngủ ngon nha 💖',
      body:
          '🌙🧸✨ $displayName ơi, đêm nay nhớ ngủ thật ngoan nha. Mong chiếc ôm dịu dàng, ánh sao nhỏ và trái tim mềm này sẽ ru bạn vào một giấc mơ thật êm, thật sâu và thật ngọt ngào 💕💤',
    );

    await _maybeSendAutoTimedGreeting(
      houseId: houseId,
      kind: 'good_morning',
      targetHour: morningHour,
      targetMinute: morningMinute,
      windowEndHour: 9,
      windowEndMinute: 0,
      title: '☀️🌷 Chào buổi sáng, $displayName 💛',
      body:
          '☀️🐣🌷 Chào buổi sáng $displayName nha. Chúc bạn thức dậy với thật nhiều năng lượng, lòng nhẹ tênh và cả ngày được yêu thương, dịu dàng ôm lấy 💛✨',
    );
  }

  Future<void> _maybeSendAutoTimedGreeting({
    required String houseId,
    required String kind,
    required int targetHour,
    required int targetMinute,
    required int windowEndHour,
    required int windowEndMinute,
    required String title,
    required String body,
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_smart_reminder_love_note') ?? true)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      windowEndHour,
      windowEndMinute,
      59,
    );
    if (now.isBefore(start) || now.isAfter(end)) {
      return;
    }

    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final markerRef = FirebaseDatabase.instance.ref(
      'houses/$houseId/system_auto_greetings/$kind/$dateKey/${user.uid}',
    );

    final transaction = await markerRef.runTransaction((current) {
      if (current != null) {
        return Transaction.abort();
      }
      return Transaction.success({
        'createdAt': ServerValue.timestamp,
      });
    });

    if (!transaction.committed) {
      return;
    }

    await sendPartnerNotification(
      houseId: houseId,
      title: title,
      body: body,
      data: {
        'screen': 'home',
        'type': 'auto_$kind',
      },
    );
  }

  tz.TZDateTime _nextDailySleepReminderTime() {
    final now = tz.TZDateTime.now(tz.local);
    final prefs = OfflineCacheService.getPrefsSync();
    final timeStr = prefs?.getString('il_good_night_time') ?? '22:15';
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 22) : 22;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 15) : 15;

    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Gửi thông báo nhắc nhở thói quen
  Future<void> sendHabitReminderNotification(
      String houseId, String habitName) async {
    await sendPartnerNotification(
      houseId: houseId,
      title: '✅ Nhắc nhở thói quen',
      body:
          'Đến giờ thực hiện thói quen "$habitName" cùng nhau rồi, đừng quên check-in nhé! 💧',
      data: {'screen': 'utilities', 'type': 'habit'},
    );
  }

  /// Gửi thông báo chúc ngủ ngon / chào buổi sáng
  Future<void> sendSleepSyncNotification(String houseId, bool isWakeUp) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Người ấy';

    final title = isWakeUp ? '☀️ Chào buổi sáng!' : '🌙 Chúc ngủ ngon!';
    final body = isWakeUp
        ? '$name vừa thức dậy, hãy gửi một lời chào buổi sáng thật ngọt ngào nhé!'
        : '$name đã bắt đầu đi ngủ, chúc bạn cũng có một giấc mơ đẹp!';

    await sendPartnerNotification(
      houseId: houseId,
      title: title,
      body: body,
      data: {'screen': 'home', 'type': 'sleep_sync'},
    );
  }

  /// Gửi thông báo về nhà an toàn
  Future<void> sendSafeArrivalNotification(String houseId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Người ấy';

    await sendPartnerNotification(
      houseId: houseId,
      title: '🏠 Về nhà an toàn',
      body: '$name đã về đến nhà an toàn rồi nhé!',
      data: {'screen': 'map', 'type': 'safe_arrival'},
    );
  }

  /// Gửi thông báo "Ngày này năm xưa"
  Future<void> sendOnThisDayNotification(String houseId, int years) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_smart_reminder_diary') ?? true)) return;

    await sendPartnerNotification(
      houseId: houseId,
      title: '📸 Ngày này năm xưa',
      body:
          'Ngày này $years năm trước, hai bạn đã đăng một kỷ niệm rất tuyệt. Cùng ôn lại nào!',
      data: {'screen': 'diary', 'type': 'on_this_day'},
    );
  }

  /// Gửi thông báo cập nhật tâm trạng
  Future<void> sendMoodUpdateNotification(
      String houseId, String moodIcon) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Người ấy';

    await sendPartnerNotification(
      houseId: houseId,
      title: '💭 Cập nhật tâm trạng',
      body:
          'Hôm nay tâm trạng của $name đang là $moodIcon. Hãy vào xem và gửi lời động viên nhé!',
      data: {'screen': 'utilities', 'type': 'mood'},
    );
  }

  /// Kiểm tra và hiển thị thông báo hộp thư tương lai đến ngày
  Future<void> checkTimeCapsules(String houseId) async {
    try {
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (!(prefs.getBool('il_smart_reminder_capsule') ?? true)) return;

      final snap = await FirebaseDatabase.instance
          .ref('houses/$houseId/time_capsules')
          .get();
      if (!snap.exists || snap.value is! Map) return;

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final now = DateTime.now();

      for (final entry in data.entries) {
        if (entry.value is! Map) {
          continue;
        }
        final capsule = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        if (capsule['is_opened'] == true) continue;

        final unlockTimeMs = capsule['unlock_time_ms'] as int? ?? 0;
        final unlockDate = DateTime.fromMillisecondsSinceEpoch(unlockTimeMs);

        // Cùng ngày, tháng, năm
        if (now.year == unlockDate.year &&
            now.month == unlockDate.month &&
            now.day == unlockDate.day) {
          final key = 'capsule_notified_${capsule['id']}';

          if (!(prefs.getBool(key) ?? false)) {
            await showLocalNotification(
              title: '🚀 Hộp thư tương lai đã đến hẹn!',
              body:
                  'Bạn có một hộp thư tương lai đã sẵn sàng để mở trong ứng dụng.',
              data: {'screen': 'utilities', 'type': 'time_capsule'},
            );
            await prefs.setBool(key, true);
          }
        }
      }
    } catch (e) {
      debugPrint('Check time capsule error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra hộp thư tương lai lúc này.',
      ).message}');
    }
  }

  /// Gửi cảnh báo ngân sách
  Future<void> sendBudgetWarningNotification(
      String houseId, int percent) async {
    await sendPartnerNotification(
      houseId: houseId,
      title: '💸 Cảnh báo ngân sách',
      body:
          'Chú ý: Quỹ chung tháng này của hai bạn đã sử dụng vượt $percent% ngân sách dự kiến!',
      data: {'screen': 'utilities', 'type': 'finance'},
    );
  }

  /// Gửi thông báo đóng quỹ
  Future<void> sendFundContributionNotification(String houseId) async {
    await sendPartnerNotification(
      houseId: houseId,
      title: '💰 Nhắc nhở đóng quỹ',
      body:
          'Đã đến hạn đóng quỹ tình yêu tháng mới rồi, hãy nạp "năng lượng" cho quỹ nhé!',
      data: {'screen': 'utilities', 'type': 'finance'},
    );
  }

  Future<void> checkAnniversaryReminder(
      String houseId, DateTime coupleDate) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_notif_anniversary') ?? true)) return;

    final now = DateTime.now();
    var thisYearDate = DateTime(now.year, coupleDate.month, coupleDate.day);
    if (thisYearDate.isBefore(DateTime(now.year, now.month, now.day))) {
      thisYearDate = DateTime(now.year + 1, coupleDate.month, coupleDate.day);
    }

    final diff =
        thisYearDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diff == 3) {
      await sendPartnerNotification(
        houseId: houseId,
        title: '🎉 Sắp tới ngày kỷ niệm rồi!',
        body:
            'Chỉ còn 3 ngày nữa là đến ngày kỷ niệm của hai bạn nè! Chuẩn bị quà gì chưa đó? 🎁',
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    } else if (diff == 2) {
      await sendPartnerNotification(
        houseId: houseId,
        title: '⏳ Nhắc lịch: Còn 2 ngày!',
        body:
            'Chỉ còn 2 ngày nữa là đến ngày kỷ niệm thôi nha! Nhanh quá đi mất! 💖',
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    } else if (diff == 1) {
      await sendPartnerNotification(
        houseId: houseId,
        title: '⏰ Ngày mai là tới rồi!',
        body: 'Hồi hộp quá! Chỉ còn 1 ngày nữa là đến ngày kỷ niệm rùi đó! 🥰',
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    } else if (diff == 0) {
      await sendPartnerNotification(
        houseId: houseId,
        title: '🔔 Chúc mừng kỷ niệm!',
        body:
            'Tèn ten! Hôm nay là ngày kỷ niệm của hai bạn nè! Chúc hai bạn luôn hạnh phúc nhé! 🥳',
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    }
  }

  /// Dispose all subscriptions to prevent leaks.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
  }
}
