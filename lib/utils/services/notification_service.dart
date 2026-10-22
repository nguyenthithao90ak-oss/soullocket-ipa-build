import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/utils/notification_reminder_plan.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/routing/single_open_gate.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:soullocket_app/views/map/map_screen.dart';
import 'package:soullocket_app/views/notifications/notification_center_screen.dart';
import 'package:soullocket_app/views/utilities/creative_diary_screen.dart';
import 'package:soullocket_app/views/utilities/reward_store_screen.dart';
import 'package:soullocket_app/views/utilities/secret_vault_screen.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'house_service.dart';
import '../../views/utilities/soul_events/soul_events_screen.dart';
import '../../views/utilities/soul_events/soul_event_detail_screen.dart';
import '../../views/utilities/calendar_screen.dart';
import '../../views/utilities/habit_screen.dart';
import 'soul_event_service.dart';
import 'offline_cache_service.dart';
import 'time_capsule_service.dart';
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
  NotificationService._internal()
    : _fcm = FirebaseMessaging.instance,
      _localNotif = FlutterLocalNotificationsPlugin();

  @visibleForTesting
  NotificationService.forTesting({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
  }) : _fcm = messaging,
       _localNotif = localNotifications;

  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotif;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  bool _isInitialized = false;
  bool _localeListenerAttached = false;
  int _localeRevision = 0;
  Future<void>? _localeWrite;
  Future<void>? _initializingTask;
  bool _didCheckInitialMessage = false;
  String? _lastForegroundMessageKey;
  DateTime? _lastForegroundShownAt;
  String? _lastOpenedMessageKey;
  DateTime? _lastOpenedHandledAt;
  bool _timeZoneReady = false;
  bool _localPluginReady = false;
  bool _didCheckSoulEventLaunch = false;
  Future<void>? _localPluginTask;
  final SingleOpenGate _navigationGate = SingleOpenGate();
  Future<void>? _reminderSyncTask;
  int _reminderGeneration = 0;
  bool _appForeground = true;
  String? _reminderSignedOutUid;
  Future<void> _localNotificationWrites = Future<void>.value();
  int _notificationPreferenceRevision = 0;

  /// Công tắc tổng không thay đổi lựa chọn từng loại. Hủy cả lịch và thẻ
  /// local đã hiện, cùng hàng đợi ghi để tác vụ cũ không sống lại sau khi tắt.
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('il_notifications_enabled', enabled);
    // Ghi preference trước rồi mới tăng revision để mọi tác vụ đang đợi thấy
    // trạng thái tắt, còn tác vụ đã đọc trạng thái cũ bị chặn bởi revision.
    _notificationPreferenceRevision++;
    _reminderGeneration++;
    if (enabled || kIsWeb) return;
    await _ensureLocalPluginInitialized();
    await _withLocalNotificationWrite(() => _localNotif.cancelAll());
  }

  bool _canWriteLocalNotification(SharedPreferences prefs, int revision) =>
      revision == _notificationPreferenceRevision &&
      (prefs.getBool('il_notifications_enabled') ?? true);

  static const int _dailySleepReminderId =
      NotificationReminderPlan.firstSleepId;
  static const int _sleepReminderVariantCount =
      NotificationReminderPlan.variantCount;
  static const int _sleepReminderScheduleDays = _sleepReminderVariantCount;
  static const int _inactiveAppReminderId =
      NotificationReminderPlan.inactivityId;
  static const int _maxNativeScheduledNotifications = 60;

  /// Chỉ các sự kiện cần phản hồi nhanh mới được dùng kênh này. Android chỉ
  /// cho phép kênh vượt Không làm phiền sau khi người dùng cấp Notification
  /// Policy Access trong phần Cài đặt hệ thống.
  static const String priorityNotificationChannelId = 'soullocket_priority';
  static const String normalNotificationChannelId =
      'soullocket_high_importance';

  static const Set<String> _priorityNotificationTypes = <String>{
    'chat',
    'partner_message',
    'soul_merge',
    'soul_merge_call',
  };

  static String _sleepReminderIdKey(int offset) =>
      NotificationReminderPlan.messageKey(offset);

  static int _sleepReminderNotificationId(int offset) =>
      _dailySleepReminderId + offset;

  static bool _isSleepReminderNotificationId(int id) =>
      id >= _dailySleepReminderId &&
      id < _dailySleepReminderId + _sleepReminderScheduleDays;

  // Kênh thông báo Android (phải khai báo trước khi dùng)
  static AndroidNotificationChannel get _channel => AndroidNotificationChannel(
    normalNotificationChannelId, // id
    L10nService().translate('notifications_title'),
    description: L10nService().translate(
      'notification_partner_channel_description',
    ),
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList(const <int>[
      0,
      650,
      300,
      650,
      300,
      1000,
    ]),
  );

  static AndroidNotificationChannel get _priorityChannel =>
      AndroidNotificationChannel(
        priorityNotificationChannelId,
        L10nService().translate('priority_notifications_channel_name'),
        description: L10nService().translate(
          'priority_notifications_channel_description',
        ),
        importance: Importance.high,
        bypassDnd: true,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const <int>[0, 700, 300, 900]),
      );

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _localNotif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> hasPriorityNotificationAccess() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // iOS dùng Time Sensitive; Windows/Web không có quyền DND tương đương.
      return true;
    }
    await _ensureLocalPluginInitialized();
    try {
      return await _androidPlugin?.hasNotificationPolicyAccess() ?? false;
    } catch (error) {
      debugPrint(
        '[NotificationService] Không kiểm tra được quyền vượt Không làm phiền: $error',
      );
      return false;
    }
  }

  Future<void> _createPriorityChannelIfAllowed() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (await _androidPlugin?.hasNotificationPolicyAccess() == true) {
        await _androidPlugin?.createNotificationChannel(_priorityChannel);
      }
    } catch (error) {
      debugPrint(
        '[NotificationService] Không tạo được kênh thông báo ưu tiên: $error',
      );
    }
  }

  /// Mở màn hình cấp Notification Policy Access trên Android.
  /// Kết quả `false` nghĩa là người dùng chưa bật quyền; UI sẽ kiểm tra lại
  /// khi quay về ứng dụng.
  Future<bool> requestPriorityNotificationAccess() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    await _ensureLocalPluginInitialized();
    final plugin = _androidPlugin;
    if (plugin == null) return false;
    try {
      if (await plugin.hasNotificationPolicyAccess() == true) {
        await _createPriorityChannelIfAllowed();
        return true;
      }
      await plugin.requestNotificationPolicyAccess();
      final granted = await plugin.hasNotificationPolicyAccess() ?? false;
      if (granted) await _createPriorityChannelIfAllowed();
      return granted;
    } catch (error) {
      debugPrint(
        '[NotificationService] Không mở được cài đặt thông báo ưu tiên: $error',
      );
      return false;
    }
  }

  Future<void> openPriorityNotificationSettings() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await requestPriorityNotificationAccess();
      return;
    }
    await _localNotif.openAppNotificationSettings();
  }

  Future<void> setPriorityNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('il_priority_notifications_enabled', enabled);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseDatabase.instance
          .ref('users/$uid/notificationPreferences')
          .update({
            'priorityNotificationsEnabled': enabled,
            'updatedAt': ServerValue.timestamp,
          });
    } catch (error) {
      debugPrint(
        '[NotificationService] Không đồng bộ cài đặt thông báo ưu tiên: $error',
      );
    }
  }

  bool _isPriorityNotificationType(Map<String, dynamic> data) {
    final explicit = data['priority'];
    if (explicit == true || explicit?.toString().toLowerCase() == 'true') {
      return true;
    }
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    return _priorityNotificationTypes.contains(type);
  }

  Future<bool> _shouldUsePriorityChannel(Map<String, dynamic> data) async {
    if (!_isPriorityNotificationType(data)) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_priority_notifications_enabled') ?? false)) {
      return false;
    }
    return hasPriorityNotificationAccess();
  }

  Future<bool> hasPermission() async {
    try {
      final settings = await _fcm.getNotificationSettings().timeout(
        const Duration(seconds: 4),
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint(
        '[NotificationService] Notification permission unavailable: $error',
      );
      return false;
    }
  }

  /// Gọi khi user chủ động bấm xin quyền
  Future<bool> requestPermissionAndInit() async {
    if (await hasPermission()) {
      await initialize();
      return true;
    }

    final settings = await _fcm
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        )
        .timeout(const Duration(seconds: 8));

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
      if (!_localeListenerAttached) {
        L10nService().addListener(_onNotificationLocaleChanged);
        _localeListenerAttached = true;
      }
      await syncDailySleepReminder();
      await syncInactivityReminder();
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
        await _ensureLocalPluginInitialized();

        await _saveFcmToken();

        // iOS: Bật hiển thị thông báo khi app đang mở (foreground)
        // Nếu không gọi dòng này, iOS sẽ âm thầm bỏ qua notification khi app ở foreground.
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        _tokenRefreshSubscription ??= _fcm.onTokenRefresh.listen(
          _onTokenRefresh,
        );
        _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
        );
        _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
            .listen(_handleMessageOpenedApp);

        if (!_didCheckInitialMessage) {
          final initialMessage = await _fcm.getInitialMessage();
          _didCheckInitialMessage = true;
          if (initialMessage != null) {
            _handleMessageOpenedApp(initialMessage);
          }
        }

        if (!_localeListenerAttached) {
          L10nService().addListener(_onNotificationLocaleChanged);
          _localeListenerAttached = true;
        }
        _isInitialized = true;
        await syncDailySleepReminder();
        await syncInactivityReminder();
      } catch (error) {
        debugPrint(
          'NotificationService initialize error: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể khởi tạo thông báo lúc này.').message}',
        );
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
        apnsToken = await _fcm.getAPNSToken().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
        if (apnsToken != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apnsToken == null) {
        debugPrint(
          '[NotificationService] APNS token not available yet, skipping FCM token save.',
        );
        return;
      }
    }

    String? token;
    try {
      // Một số thiết bị không có Google Play Services (hoặc mạng Google bị
      // chặn) sẽ không bao giờ trả token. Không để việc này giữ app ở trạng
      // thái connecting; các tính năng dữ liệu vẫn hoạt động bình thường.
      token = await _fcm.getToken().timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
    } catch (error) {
      debugPrint(
        '[NotificationService] FCM token unavailable; push disabled on this device: $error',
      );
      return;
    }
    if (token == null || FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    await FirebaseDatabase.instance
        .ref('users/${user.uid}/fcmToken')
        .set(token)
        .timeout(const Duration(seconds: 5));
    await _saveNotificationLocale();

    // FCM token giờ chỉ lưu độc lập tại users/{uid}/fcmToken
    // Không lưu gộp vào houses/{houseId}/fcmTokens nữa để tách biệt hoàn toàn thiết bị theo UID
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/fcmToken')
          .set(newToken)
          .timeout(const Duration(seconds: 5));
      await _saveNotificationLocale();
    } catch (error) {
      debugPrint('[NotificationService] FCM token refresh deferred: $error');
    }

    // FCM token giờ chỉ lưu độc lập tại users/{uid}/fcmToken
    // Không lưu gộp vào houses/{houseId}/fcmTokens nữa để tách biệt hoàn toàn thiết bị theo UID
  }

  void _onNotificationLocaleChanged() {
    unawaited(_saveNotificationLocale());
    unawaited(_refreshLocalizedChannel());
    unawaited(_refreshPersonalReminderLocale());
  }

  Future<void> _refreshPersonalReminderLocale() async {
    try {
      await syncDailySleepReminder();
      await syncInactivityReminder();
    } catch (error) {
      debugPrint(
        '[NotificationService] personal reminder locale refresh error: $error',
      );
    }
  }

  Future<void> _refreshLocalizedChannel() async {
    if (kIsWeb || !_localPluginReady) return;
    try {
      // Giữ ID cũ để Android bảo toàn lựa chọn âm thanh/quyền của người dùng.
      await _androidPlugin?.createNotificationChannel(_channel);
      await _createPriorityChannelIfAllowed();
    } catch (_) {
      debugPrint('[NotificationService] localized channel refresh unavailable');
    }
  }

  Future<void> _saveNotificationLocale() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final locale = L10nService().localeCode;
    final revision = ++_localeRevision;
    final previous = _localeWrite;
    final write = () async {
      try {
        if (previous != null) await previous;
        if (revision != _localeRevision ||
            FirebaseAuth.instance.currentUser?.uid != uid) {
          return;
        }
        await FirebaseDatabase.instance
            .ref('users/$uid/notificationLocale')
            .set(locale);
      } catch (_) {
        // Rules cũ có thể chưa hỗ trợ locale; vẫn giữ FCM token và thông báo trong app.
        debugPrint(
          '[NotificationService] notification locale sync unavailable',
        );
      }
    }();
    _localeWrite = write;
    await write;
    if (identical(_localeWrite, write)) _localeWrite = null;
  }

  /// Dọn dẹp FCM token khi người dùng đăng xuất
  Future<void> clearTokenOnSignOut() async {
    // Vô hiệu hóa mọi lần đồng bộ đang chờ để lịch của UID cũ không được
    // đặt lại sau khi người dùng đã đăng xuất.
    _reminderGeneration++;
    _reminderSignedOutUid = FirebaseAuth.instance.currentUser?.uid;
    _localeRevision++;
    if (_localeListenerAttached) {
      L10nService().removeListener(_onNotificationLocaleChanged);
      _localeListenerAttached = false;
    }
    try {
      await cancelDailySleepReminder();
      await cancelInactivityReminder();
    } catch (error) {
      debugPrint('[NotificationService] clear local reminders error: $error');
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Xóa ở đường dẫn chính nơi token được lưu
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/fcmToken')
            .remove()
            .timeout(const Duration(seconds: 2));
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
    final isSoulMergeCall =
        type == 'soul_merge_call' || screen == 'soul_merge_call';

    // Đồng bộ iOS Widget cho Soul Merge
    if (type == 'soul_merge' || screen == 'soul_merge') {
      try {
        final text =
            message.notification?.body ??
            message.data['text'] ??
            UiCopy.text('copy_ed5fd66064f8');
        final senderName =
            message.data['senderName']?.toString() ??
            UiCopy.text('copy_145933221191');
        await WidgetService.syncSoulMergeWidgetData(
          message: text.toString(),
          senderName: senderName,
        );
      } catch (error) {
        debugPrint(
          '[NotificationService] Không đồng bộ được Soul Merge widget: $error',
        );
      }
    }

    final isInteractionOrMerge =
        !isSoulMergeCall &&
        (type == 'soul_merge' ||
            screen == 'soul_merge' ||
            type == 'partner_care' ||
            type == 'interaction' ||
            type == 'photo_shot');

    if (isSoulMergeCall) {
      final callerName = message.data['callerName']?.toString().trim() ?? '';
      await showLocalNotification(
        title:
            message.notification?.title ??
            L10nService().translate('home_cucgin_eff0b9'),
        body:
            message.notification?.body ??
            L10nService().format('home_incoming_call_from', {
              'name': callerName.isEmpty
                  ? L10nService().translate('home_ngigi_f1117f')
                  : callerName,
            }),
        data: message.data,
        dedupeKey: _messageKey(message),
      );
      return;
    }

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
              overlayTitle: UiCopy.text('copy_2ae0a531a5df'),
              overlayContent: UiCopy.text('copy_2beace08a4bf'),
            );
          }
        }
      } catch (e) {
        debugPrint('Error showing overlay in foreground: $e');
      }
    }

    // 2. Xử lý hiển thị heads-up (Local Notification)
    final notification = message.notification;
    if (notification == null) return;

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
    unawaited(_navigateFromData(message.data));
  }

  /// Xử lý khi user tap vào Local Notification
  void _onNotificationTap(NotificationResponse response) {
    unawaited(_openLocalPayload(response.payload));
  }

  Future<void> _openLocalPayload(
    String? payload, {
    bool eventsOnly = false,
  }) async {
    if (payload == null) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (eventsOnly &&
          data['type'] != 'soul_event_reminder_v1' &&
          data['type'] != 'calendar_reminder_v2' &&
          data['type'] != 'habit_reminder_v1') {
        return;
      }
      await _navigateFromData(data);
    } catch (error) {
      debugPrint(AppErrorMapper.resolve(error).message);
    }
  }

  /// Chỉ xử lý cold start sau khi màn hình chính đã qua luồng đăng nhập.
  Future<void> handleSoulEventLaunch() async {
    if (kIsWeb ||
        _didCheckSoulEventLaunch ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _ensureLocalPluginInitialized();
      if (_didCheckSoulEventLaunch) return;
      _didCheckSoulEventLaunch = true;
      final details = await _localNotif.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      await _openLocalPayload(
        details?.notificationResponse?.payload,
        eventsOnly: true,
      );
    } catch (error) {
      debugPrint(AppErrorMapper.resolve(error).message);
    }
  }

  Future<void> _navigateFromData(Map<String, dynamic> data) {
    // Giữ khóa từ lúc đọc dữ liệu tới khi route đóng; callback trễ không
    // xếp thêm màn hình sau lưng người dùng khi mạng hoặc thiết bị chậm.
    return _navigationGate.run(() async {
      try {
        await _navigateFromDataInternal(data);
      } catch (error) {
        debugPrint(AppErrorMapper.resolve(error).message);
      }
    });
  }

  Future<void> _navigateFromDataInternal(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    final requestUid = FirebaseAuth.instance.currentUser?.uid;
    final screen = data['screen']?.toString() ?? 'home';
    final houseService = HouseService();
    final myHouseId = await houseService.getCurrentHouseId();

    Widget destination;
    switch (screen) {
      case 'chat':
        final targetHouseId =
            data['targetHouseId']?.toString() ??
            data['target_house_id']?.toString();
        final targetName =
            data['target_name']?.toString() ?? UiCopy.text('copy_145933221191');
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
        final targetHouseId =
            data['targetHouseId']?.toString() ??
            data['target_house_id']?.toString();
        final targetName =
            data['target_name']?.toString() ?? UiCopy.text('copy_145933221191');
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
      case 'soul_events':
        if (requestUid == null ||
            myHouseId == null ||
            data['accountUid'] != requestUid ||
            data['houseId'] != myHouseId ||
            FirebaseAuth.instance.currentUser?.uid != requestUid) {
          return;
        }
        final events = await SoulEventService().getEvents(myHouseId);
        if (FirebaseAuth.instance.currentUser?.uid != requestUid) return;
        final event = events.where((e) => e.id == data['eventId']).firstOrNull;
        destination = event == null
            ? const SoulEventsScreen()
            : SoulEventDetailScreen(houseId: myHouseId, event: event);
        break;
      case 'calendar':
        // Thông báo cũ không được mở lịch sau khi UID/House đã thay đổi.
        if (requestUid == null ||
            myHouseId == null ||
            data['accountUid']?.toString() != requestUid ||
            data['houseId']?.toString() != myHouseId ||
            FirebaseAuth.instance.currentUser?.uid != requestUid) {
          return;
        }
        final currentHouse = await houseService.getCurrentHouseId(
          preferFresh: true,
        );
        if (FirebaseAuth.instance.currentUser?.uid != requestUid ||
            currentHouse != myHouseId) {
          return;
        }
        final calendarName = await _resolveCurrentUserDisplayName(
          houseService,
          myHouseId,
        );
        if (FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId() != myHouseId) {
          return;
        }
        destination = CalendarScreen(
          houseId: myHouseId,
          myName: calendarName,
          initialDateKey: data['dateKey']?.toString(),
        );
        break;
      case 'diary':
        destination = const HomeScreen(initialTab: 2);
        break;
      case 'utilities':
        destination = const HomeScreen(initialTab: 3);
        break;
      case 'habits':
        // Payload cũ không được mở thói quen của tài khoản/House trước đó.
        if (requestUid == null ||
            myHouseId == null ||
            data['accountUid'] != requestUid ||
            data['houseId'] != myHouseId ||
            FirebaseAuth.instance.currentUser?.uid != requestUid) {
          return;
        }
        final habitName = await _resolveCurrentUserDisplayName(
          houseService,
          myHouseId,
        );
        if (FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId() != myHouseId) {
          return;
        }
        destination = HabitScreen(houseId: myHouseId, myName: habitName);
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
      case 'soul_merge_call':
        // Home giữ listener cuộc gọi đến và có dialog nhận/từ chối. Khi app
        // được mở từ notification lúc terminated, không đẩy thẳng Soul Merge
        // vì màn đó không sở hữu listener inbox của Home.
        destination = const HomeScreen(initialTab: 0);
        break;
      case 'feed':
        destination = const HomeScreen(initialTab: 1);
        break;
      case 'notifications':
        // Payload thông báo cũ có thể còn nằm trong khay hệ thống sau khi
        // người dùng đổi tài khoản hoặc đổi House. Chỉ mở trung tâm khi
        // scope hiện tại vẫn khớp payload (nếu payload có ghi scope).
        final payloadUid = data['accountUid']?.toString();
        final notificationPayloadHouseId =
            data['houseId']?.toString() ?? data['house_id']?.toString();
        if (requestUid == null ||
            myHouseId == null ||
            (payloadUid != null &&
                payloadUid.isNotEmpty &&
                payloadUid != requestUid) ||
            (notificationPayloadHouseId != null &&
                notificationPayloadHouseId.isNotEmpty &&
                notificationPayloadHouseId != myHouseId) ||
            FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId(preferFresh: true) !=
                myHouseId) {
          return;
        }
        destination = const NotificationCenterScreen();
        break;
      case 'reward_store':
        if (requestUid == null ||
            FirebaseAuth.instance.currentUser?.uid != requestUid) {
          return;
        }
        destination = const RewardStoreScreen();
        break;
      case 'vault':
        final vaultPayloadHouseId =
            data['houseId']?.toString() ?? data['house_id']?.toString();
        if (requestUid == null ||
            myHouseId == null ||
            (vaultPayloadHouseId != null &&
                vaultPayloadHouseId.isNotEmpty &&
                vaultPayloadHouseId != myHouseId) ||
            FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId(preferFresh: true) !=
                myHouseId) {
          return;
        }
        destination = SecretVaultScreen(houseId: myHouseId);
        break;
      case 'map':
        final mapPayloadHouseId =
            data['houseId']?.toString() ?? data['house_id']?.toString();
        if (requestUid == null ||
            myHouseId == null ||
            (mapPayloadHouseId != null &&
                mapPayloadHouseId.isNotEmpty &&
                mapPayloadHouseId != myHouseId) ||
            FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId(preferFresh: true) !=
                myHouseId) {
          return;
        }
        final prefs =
            OfflineCacheService.getPrefsSync() ??
            await SharedPreferences.getInstance();
        final myRole = RoleUtils.normalize(prefs.getString('il_role'));
        final partnerRole = myRole == 'user1' ? 'user2' : 'user1';
        final settings = await houseService.getHouseSettings(myHouseId);
        if (FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId() != myHouseId) {
          return;
        }
        String nameForRole(String role) {
          final key = role == 'user2' ? 'nameU2' : 'nameU1';
          final name = settings?[key]?.toString().trim() ?? '';
          return name.isEmpty ? UiCopy.text('copy_40ffd8d0f1c7') : name;
        }

        String avatarForRole(String role) {
          final primary = role == 'user1' ? 'avtUser1' : 'avtUser2';
          final alias = role == 'user1' ? 'avatarU1' : 'avatarU2';
          return (settings?[primary] ?? settings?[alias])?.toString().trim() ??
              '';
        }

        destination = MapScreen(
          houseId: myHouseId,
          myRole: myRole,
          partnerRole: partnerRole,
          relationshipMode:
              settings?['relationshipMode']?.toString().trim() ?? 'single',
          myName: nameForRole(myRole),
          partnerName: nameForRole(partnerRole),
          myAvatarUrl: avatarForRole(myRole),
          partnerAvatarUrl: avatarForRole(partnerRole),
        );
        break;
      case 'home':
      default:
        destination = const AppEntry();
        break;
    }

    if (!navigator.mounted ||
        !context.mounted ||
        FirebaseAuth.instance.currentUser?.uid != requestUid) {
      return;
    }
    await slPush<void>(
      context,
      destination,
      fullscreenDialog: destination is SoulMergeScreen,
    );
  }

  Future<String> _resolveCurrentUserDisplayName(
    HouseService houseService,
    String houseId,
  ) async {
    final fallback =
        FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty ==
            true
        ? FirebaseAuth.instance.currentUser!.displayName!.trim()
        : UiCopy.text('copy_40ffd8d0f1c7');

    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
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
    final type = message.data['type']?.toString() ?? '';
    final screen = message.data['screen']?.toString() ?? '';
    final roomId = message.data['roomId']?.toString().trim() ?? '';
    if ((type == 'soul_merge_call' || screen == 'soul_merge_call') &&
        roomId.isNotEmpty) {
      // FCM và listener RTDB có thể báo cùng một cuộc gọi gần như đồng thời.
      // Dùng roomId làm khóa chung để chỉ tạo một heads-up ban đầu.
      return _incomingCallDedupeKey(roomId, 0);
    }
    return message.messageId ??
        '${message.sentTime?.millisecondsSinceEpoch ?? 0}|'
            '${message.notification?.title ?? ''}|'
            '${message.notification?.body ?? ''}|'
            '${jsonEncode(message.data)}';
  }

  String _incomingCallDedupeKey(String roomId, int sequence) =>
      'soul_merge_call:${roomId.trim()}:$sequence';

  bool _shouldSkipOpenedMessage(RemoteMessage message) {
    final key = _messageKey(message);
    final now = DateTime.now();
    final shouldSkip =
        _lastOpenedMessageKey == key &&
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
    final screen = payloadData['screen']?.toString() ?? '';
    // Backend cũ có thể phải dùng `partner_message` để qua whitelist, nhưng
    // vẫn giữ `screen=soul_merge_call`. Dùng cùng roomId cho cả hai dạng để
    // lần rung lại cập nhật đúng một thẻ và khi kết thúc có thể dismiss được.
    if (type == 'soul_merge_call' || screen == 'soul_merge_call') {
      final roomId = payloadData['roomId']?.toString().trim() ?? '';
      if (roomId.isNotEmpty) return roomId.hashCode;
    }
    if (type == 'partner_care') {
      final careType = payloadData['careType']?.toString() ?? '';
      if (careType == 'kiss') {
        return fallbackKey.hashCode;
      }
      return 'partner_care_latest'.hashCode;
    }
    return fallbackKey.hashCode;
  }

  NotificationDetails _notificationDetails({
    bool isIncomingCall = false,
    bool isPriority = false,
  }) {
    final channel = isPriority ? _priorityChannel : _channel;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: isIncomingCall
            ? Int64List.fromList(const <int>[0, 650, 300, 650, 300, 1000])
            : null,
        onlyAlertOnce: false,
        ongoing: isIncomingCall,
        autoCancel: !isIncomingCall,
        category: isIncomingCall ? AndroidNotificationCategory.call : null,
        fullScreenIntent: isIncomingCall,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFFF5E7E),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isPriority ? InterruptionLevel.timeSensitive : null,
      ),
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? dedupeKey,
  }) async {
    if (kIsWeb || (title.trim().isEmpty && body.trim().isEmpty)) return;
    final revision = _notificationPreferenceRevision;
    final prefs = await SharedPreferences.getInstance();
    if (!_canWriteLocalNotification(prefs, revision)) return;
    // Hiển thị local không cần lưu lại token FCM hay đồng bộ toàn bộ lịch.
    await _ensureLocalPluginInitialized();

    final payloadData = <String, dynamic>{...?data};
    final key = dedupeKey ?? '$title|$body|${jsonEncode(payloadData)}';
    await _withLocalNotificationWrite(() async {
      if (!_canWriteLocalNotification(prefs, revision) ||
          !await hasPermission()) {
        return;
      }
      final isPriority = await _shouldUsePriorityChannel(payloadData);
      if (!_canWriteLocalNotification(prefs, revision)) return;
      final now = DateTime.now();
      final shouldSkip =
          _lastForegroundMessageKey == key &&
          _lastForegroundShownAt != null &&
          now.difference(_lastForegroundShownAt!) < const Duration(seconds: 5);
      if (shouldSkip) return;
      _lastForegroundMessageKey = key;
      _lastForegroundShownAt = now;
      final isIncomingCall =
          payloadData['type']?.toString() == 'soul_merge_call' ||
          payloadData['screen']?.toString() == 'soul_merge_call';
      final notificationId = _notificationIdForPayload(payloadData, key);

      await _localNotif.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(
          isIncomingCall: isIncomingCall,
          isPriority: isPriority,
        ),
        payload: jsonEncode(payloadData),
      );
    });
  }

  /// Hiển thị/rung lại cảnh báo cuộc gọi bằng notification native.
  /// `sequence` thay đổi theo mỗi nhịp chuông, còn notification ID giữ theo
  /// room để Android cập nhật cùng một thẻ thay vì tạo một loạt thông báo.
  Future<void> showIncomingCallNotification({
    required String roomId,
    required String callerName,
    required bool isVideo,
    int sequence = 0,
  }) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) return;
    final safeCallerName = callerName.trim().isEmpty
        ? L10nService().translate('home_ngigi_f1117f')
        : callerName.trim();
    await showLocalNotification(
      title: L10nService().translate('home_cucgin_eff0b9'),
      body: L10nService().format('home_incoming_call_from', {
        'name': safeCallerName,
      }),
      data: <String, dynamic>{
        'screen': 'soul_merge_call',
        'type': 'soul_merge_call',
        'roomId': normalizedRoomId,
        'callerName': safeCallerName,
        'isVideo': isVideo.toString(),
      },
      dedupeKey: _incomingCallDedupeKey(normalizedRoomId, sequence),
    );
  }

  /// Xóa heads-up/notification cuộc gọi khi người dùng đã bắt máy, từ chối
  /// hoặc cuộc gọi kết thúc. Dùng cùng ID với các nhịp chuông để không để lại
  /// thông báo cũ trong khay hệ thống.
  Future<void> dismissIncomingCallNotification(String roomId) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) return;
    try {
      await initialize();
      if (!_localPluginReady) return;
      await _localNotif.cancel(id: normalizedRoomId.hashCode);
    } catch (error) {
      debugPrint(
        '[NotificationService] dismiss incoming call failed: '
        '${AppErrorMapper.resolve(error).message}',
      );
    }
  }

  /// Gửi thông báo cho đối phương trong cùng house (qua Firebase trigger)
  /// Hàm này ghi trigger vào Firebase, Cloud Function sẽ tự gửi FCM
  Future<void> sendPartnerNotification({
    required String houseId,
    required String title,
    required String body,
    Map<String, String>? data,
    bool throwOriginalException = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final requestData = <String, dynamic>{
      'houseId': houseId,
      'title': title,
      'body': body,
      'data': data ?? const <String, String>{},
      'audience': 'partner',
    };

    try {
      await CloudFunctionsHelper.callSecure<dynamic>(
        'queuePartnerNotificationSecure',
        payload: requestData,
        // Callable đang enforce App Check ở production. Ép helper chuẩn bị và
        // refresh token một lần để thao tác gọi không bị rơi FCM chỉ vì app
        // vừa khởi động hoặc token debug chưa sẵn sàng.
        requireAppCheck: true,
        throwOriginalException: throwOriginalException,
      );
    } on FirebaseFunctionsException catch (error) {
      // Một số bản Function cũ chưa có whitelist `soul_merge_call`. Khi đó
      // giữ screen/room của cuộc gọi nhưng dùng type legacy đã được chấp nhận;
      // server mới vẫn đi qua nhánh chính và không gửi trùng.
      final requestedType = data?['type']?.trim().toLowerCase();
      if (throwOriginalException &&
          requestedType == 'soul_merge_call' &&
          error.code.trim().toLowerCase() == 'invalid-argument') {
        final compatibilityData = <String, String>{
          ...?data,
          'type': 'partner_message',
        };
        await CloudFunctionsHelper.callSecure<dynamic>(
          'queuePartnerNotificationSecure',
          payload: <String, dynamic>{
            ...requestData,
            'data': compatibilityData,
          },
          requireAppCheck: true,
          throwOriginalException: true,
        );
        return;
      }
      debugPrint(
        'Failed to queue partner notification: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể xếp hàng thông báo cho đối tác.').message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        'Failed to queue partner notification: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể xếp hàng thông báo cho đối tác.').message}',
      );
      // Để màn hình kiểm tra và các luồng gọi có thể báo đúng trạng thái;
      // nếu nuốt lỗi, nút test sẽ luôn hiện "đã gửi" dù callable bị từ chối.
      rethrow;
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
      await CloudFunctionsHelper.callSecure<dynamic>(
        'queuePartnerNotificationSecure',
        payload: <String, dynamic>{
          'houseId': houseId,
          'title': title,
          'body': body,
          'data': data ?? const <String, String>{},
          'audience': 'house',
        },
        requireAppCheck: true,
      );
    } catch (e) {
      debugPrint(
        'Failed to queue house notification: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể xếp hàng thông báo cho house.').message}',
      );
      rethrow;
    }
  }

  /// Gửi thông báo "Tôi nhớ bạn" cho người yêu
  Future<void> sendMissYouNotification(String houseId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? UiCopy.text('copy_145933221191');
    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().format('notif_miss_you_title', {'value1': name}),
      body: L10nService().format('notif_miss_you_body', {'value1': name}),
      data: {'screen': 'home', 'type': 'miss_you'},
    );
  }

  /// Gửi thông báo khi đăng bài mới lên feed
  Future<void> sendNewPostNotification(String houseId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? UiCopy.text('copy_145933221191');
    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().format('notif_new_post_title', {'value1': name}),
      body: L10nService().translate('notif_new_post_body'),
      data: {'screen': 'feed', 'post_id': postId, 'type': 'new_post'},
    );
  }

  Future<void> _ensureLocalPluginInitialized() async {
    if (kIsWeb || _localPluginReady) return;
    if (_localPluginTask != null) return _localPluginTask;
    final task = () async {
      await _androidPlugin?.createNotificationChannel(_channel);

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
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

      _localPluginReady = true;
      await _createPriorityChannelIfAllowed();
    }();
    _localPluginTask = task;
    try {
      await task;
    } finally {
      if (identical(_localPluginTask, task)) _localPluginTask = null;
    }
  }

  Future<List<PendingNotificationRequest>> pendingLocalNotifications() async {
    if (kIsWeb) return const [];
    await _ensureLocalPluginInitialized();
    return _localNotif.pendingNotificationRequests();
  }

  Future<bool> refreshLocalTimeZone() {
    _timeZoneReady = false;
    return _ensureTimeZoneReady();
  }

  /// Trả về múi giờ IANA mà lịch cục bộ đang dùng sau khi đã khởi tạo.
  Future<String?> ensureLocalTimeZone() async {
    if (!await _ensureTimeZoneReady()) return null;
    return tz.local.name;
  }

  /// Cài đặt thông báo cục bộ theo thời gian
  Future<bool> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? data,
  }) => _scheduleGuardedLocalNotification(
    id: id,
    title: title,
    body: body,
    scheduledDate: scheduledDate,
    data: {'screen': 'home', 'type': 'scheduled_local', ...?data},
    active: () => true,
  );

  int get _nativeScheduleLimit => defaultTargetPlatform == TargetPlatform.iOS
      ? _maxNativeScheduledNotifications
      : 480;

  Future<T> _withLocalNotificationWrite<T>(Future<T> Function() action) {
    final next = _localNotificationWrites.then((_) => action());
    // Giữ hàng đợi hoạt động kể cả khi một lần ghi native thất bại.
    _localNotificationWrites = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<bool> _scheduleGuardedLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required Map<String, dynamic> data,
    required bool Function() active,
  }) async {
    if (kIsWeb || !active()) return false;
    final revision = _notificationPreferenceRevision;
    final prefs = await SharedPreferences.getInstance();
    bool canWrite() =>
        active() && _canWriteLocalNotification(prefs, revision);
    if (!canWrite()) return false;
    await _ensureLocalPluginInitialized();
    if (!canWrite() || !await _ensureTimeZoneReady()) return false;
    return _withLocalNotificationWrite(() async {
      if (!canWrite() || !await hasPermission()) {
        return false;
      }
      final pending = await _localNotif.pendingNotificationRequests();
      final replacesExisting = pending.any((item) => item.id == id);
      if (!replacesExisting && pending.length >= _nativeScheduleLimit) {
        return false;
      }
      if (!canWrite() || !scheduledDate.isAfter(DateTime.now())) return false;
      await _localNotif.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: _notificationDetails(),
        payload: jsonEncode(data),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      if (!canWrite()) {
        await _localNotif.cancel(id: id);
        return false;
      }
      return true;
    });
  }

  /// Hủy nhiều thông báo cục bộ theo ID đã lưu cho cùng một nghiệp vụ.
  Future<void> cancelLocalNotifications(Iterable<int> ids) async {
    if (kIsWeb) return;
    final ownedIds = ids.toSet();
    if (ownedIds.isEmpty) return;
    await _ensureLocalPluginInitialized();
    await _withLocalNotificationWrite(() async {
      for (final id in ownedIds) {
        await _localNotif.cancel(id: id);
      }
    });
  }

  Future<void> syncDailySleepReminder() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _enqueueReminderSync(
      (generation) => _syncDailySleepReminderNow(generation, uid),
    );
  }

  Future<void> _syncDailySleepReminderNow(int generation, String? uid) async {
    if (kIsWeb || generation != _reminderGeneration) return;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (generation != _reminderGeneration) return;
    final enabled = prefs.getBool('il_notifications_enabled') ?? true;
    final sleepEnabled = prefs.getBool('il_smart_reminder_sleep') ?? true;
    if (!enabled || !await hasPermission()) {
      await _cancelDailySleepReminderNow();
      await _cancelInactivityReminderNow();
      return;
    }
    if (!sleepEnabled || uid == null || uid == _reminderSignedOutUid) {
      await _cancelDailySleepReminderNow();
      return;
    }
    final houseId = (prefs.getString('il_house_id') ?? '').trim();
    bool active() =>
        generation == _reminderGeneration &&
        FirebaseAuth.instance.currentUser?.uid == uid &&
        uid != _reminderSignedOutUid &&
        (prefs.getString('il_house_id') ?? '').trim() == houseId &&
        (prefs.getBool('il_notifications_enabled') ?? true) &&
        (prefs.getBool('il_smart_reminder_sleep') ?? true);
    if (!active()) return;
    await _ensureLocalPluginInitialized();
    if (!active() || !await _ensureTimeZoneReady()) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    final displayName = await _resolveSleepReminderDisplayName(prefs, role);
    if (!active()) return;
    final pending = await pendingLocalNotifications();
    if (!active()) return;
    final others = pending
        .where((item) => !_isSleepReminderNotificationId(item.id))
        .toList();
    final count = NotificationReminderPlan.sleepBudget(
      otherCount: others.length,
      totalLimit: _nativeScheduleLimit,
      reserveInactivity: !others.any(
        (item) => item.id == _inactiveAppReminderId,
      ),
    );
    final dates = NotificationReminderPlan.sleepNights(
      now: tz.TZDateTime.now(tz.local),
      clock: prefs.getString('il_good_night_time') ?? '22:15',
      count: count,
    );
    final reminders = <PlannedPersonalReminder>[
      for (var offset = 0; offset < dates.length; offset++)
        PlannedPersonalReminder(
          id: _sleepReminderNotificationId(offset),
          time: dates[offset],
          title: buildSleepReminderTitle(displayName),
          body: buildSleepReminderMessage(
            displayName,
            variantIndex: _sleepVariantIndex(dates[offset]),
          ),
          data: {
            'screen': 'home',
            'type': 'daily_sleep_reminder',
            'accountUid': uid,
            'houseId': houseId,
            'role': role,
            'variant': _sleepVariantIndex(dates[offset]),
            'scheduledMs': dates[offset].millisecondsSinceEpoch,
          },
        ),
    ];
    await PersonalReminderReconciler(
      pending: pendingLocalNotifications,
      cancel: cancelLocalNotifications,
      schedule:
          ({
            required id,
            required title,
            required body,
            required scheduledDate,
            required data,
          }) => _scheduleGuardedLocalNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            data: data,
            active: active,
          ),
    ).reconcile(
      owns: _isSleepReminderNotificationId,
      reminders: reminders,
      active: active,
    );
  }

  Future<void> cancelDailySleepReminder() async {
    return _enqueueReminderSync((_) => _cancelDailySleepReminderNow());
  }

  Future<void> _cancelDailySleepReminderNow() async {
    await cancelLocalNotifications(
      List<int>.generate(
        _sleepReminderScheduleDays,
        _sleepReminderNotificationId,
      ),
    );
  }

  String buildSleepReminderTitle(String displayName) {
    return L10nService().format('notif_sleep_reminder_title', {
      'value1': _safeSleepName(displayName),
    });
  }

  String buildSleepReminderMessage(String displayName, {int? variantIndex}) =>
      formatSleepReminderMessage(displayName, variantIndex: variantIndex);

  static String formatSleepReminderMessage(
    String displayName, {
    int? variantIndex,
  }) {
    final index =
        (variantIndex ?? _sleepVariantIndex(DateTime.now())) %
        _sleepReminderVariantCount;
    return L10nService().format(_sleepReminderIdKey(index), {
      'value1': _safeSleepName(displayName),
    });
  }

  static String _safeSleepName(String displayName) => displayName.trim().isEmpty
      ? UiCopy.text('copy_296890314132')
      : displayName.trim();

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
      debugPrint(
        'Notification timezone init failed: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể khởi tạo múi giờ thông báo.').message}',
      );
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
    final cachedHouseId = canUseSessionCache
        ? (prefs.getString('il_house_id') ?? '').trim()
        : '';
    final houseId = cachedHouseId.isNotEmpty
        ? cachedHouseId
        : (await HouseService().getCurrentHouseId().timeout(
                const Duration(seconds: 2),
                onTimeout: () => null,
              ))?.trim() ??
              '';
    if (houseId.isEmpty) {
      return cachedUserName.isNotEmpty ? cachedUserName : fallback;
    }

    try {
      final settings = await HouseService()
          .getHouseSettings(houseId)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      final key = role == 'user2' ? 'nameU2' : 'nameU1';
      final resolvedName = settings?[key]?.toString().trim() ?? '';
      if (resolvedName.isNotEmpty) {
        return resolvedName;
      }
    } catch (error) {
      debugPrint(
        '[NotificationService] Không lấy được tên hiển thị từ house: $error',
      );
    }

    return cachedUserName.isNotEmpty ? cachedUserName : fallback;
  }

  String buildSleepReminderBody(String displayName) {
    return buildSleepReminderMessage(displayName);
  }

  /// Ghi lifecycle ngay khi nhận sự kiện; tác vụ chậm cũ không được đặt
  /// lại lịch sau một lần resume hoặc đăng xuất mới hơn.
  Future<void> updateAppReminderActivity({required bool foreground}) async {
    if (kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    _appForeground = foreground;
    _reminderGeneration++;
    if (foreground && uid != null) _reminderSignedOutUid = null;
    await _enqueueReminderSync((generation) async {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (generation != _reminderGeneration ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      if (uid != null) {
        await prefs.setInt(
          'il_last_app_activity_$uid',
          now.millisecondsSinceEpoch,
        );
      }
      if (foreground) {
        await _cancelInactivityReminderNow();
      } else {
        await _syncInactivityReminderNow(generation, uid);
      }
    });
    if (foreground) {
      _timeZoneReady = false;
      await syncDailySleepReminder();
    }
  }

  /// Một lần sau 3 ngày vắng app; mỗi lần dùng lại sẽ hủy và đặt lại mốc.
  Future<void> syncInactivityReminder() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _enqueueReminderSync(
      (generation) => _syncInactivityReminderNow(generation, uid),
    );
  }

  Future<void> _syncInactivityReminderNow(int generation, String? uid) async {
    if (kIsWeb || generation != _reminderGeneration) return;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (generation != _reminderGeneration) return;
    final enabled = prefs.getBool('il_notifications_enabled') ?? true;
    if (_appForeground ||
        !enabled ||
        uid == null ||
        uid == _reminderSignedOutUid ||
        !await hasPermission()) {
      await _cancelInactivityReminderNow();
      return;
    }
    final houseId = (prefs.getString('il_house_id') ?? '').trim();
    bool active() =>
        generation == _reminderGeneration &&
        !_appForeground &&
        FirebaseAuth.instance.currentUser?.uid == uid &&
        uid != _reminderSignedOutUid &&
        (prefs.getString('il_house_id') ?? '').trim() == houseId &&
        (prefs.getBool('il_notifications_enabled') ?? true);
    if (!active()) return;
    await _ensureLocalPluginInitialized();
    if (!active() || !await _ensureTimeZoneReady()) return;
    final lastMs = prefs.getInt('il_last_app_activity_$uid');
    if (lastMs == null || !active()) return;
    final lastActivity = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      lastMs,
    );
    final scheduledDate = NotificationReminderPlan.inactivityTime(lastActivity);
    if (!scheduledDate.isAfter(DateTime.now())) {
      await _cancelInactivityReminderNow();
      return;
    }
    final pending = await pendingLocalNotifications();
    if (!active()) return;
    // Nếu số lịch đã đầy, nhường một đêm xa nhất của chính nhắc ngủ.
    if (!pending.any((item) => item.id == _inactiveAppReminderId) &&
        pending.length >= _nativeScheduleLimit) {
      final sleepIds =
          pending
              .where((item) => _isSleepReminderNotificationId(item.id))
              .map((item) => item.id)
              .toList()
            ..sort();
      if (sleepIds.isNotEmpty) await cancelLocalNotifications([sleepIds.last]);
    }
    if (!active()) return;
    await PersonalReminderReconciler(
      pending: pendingLocalNotifications,
      cancel: cancelLocalNotifications,
      schedule:
          ({
            required id,
            required title,
            required body,
            required scheduledDate,
            required data,
          }) => _scheduleGuardedLocalNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            data: data,
            active: active,
          ),
    ).reconcile(
      owns: (id) => id == _inactiveAppReminderId,
      active: active,
      reminders: [
        PlannedPersonalReminder(
          id: _inactiveAppReminderId,
          time: scheduledDate,
          title: L10nService().translate('notif_inactive_app_title'),
          body: L10nService().translate('notif_inactive_app_body'),
          data: {
            'screen': 'home',
            'type': 'inactive_app_reminder',
            'accountUid': uid,
            'houseId': houseId,
            'scheduledMs': scheduledDate.millisecondsSinceEpoch,
          },
        ),
      ],
    );
  }

  Future<void> cancelInactivityReminder() =>
      _enqueueReminderSync((_) => _cancelInactivityReminderNow());

  Future<void> _cancelInactivityReminderNow() =>
      cancelLocalNotifications([_inactiveAppReminderId]);

  Future<void> _enqueueReminderSync(
    Future<void> Function(int generation) action,
  ) {
    final generation = _reminderGeneration;
    final previous = _reminderSyncTask ?? Future<void>.value();
    final next = previous.then((_) => action(generation));
    _reminderSyncTask = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  static int _sleepVariantIndex(DateTime date) =>
      NotificationReminderPlan.variantForDate(date);

  Future<void> checkAutoSleepGreetings(String houseId) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('il_notifications_enabled') ?? true;
    if (!notificationsEnabled) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    final displayName = await _resolveSleepReminderDisplayName(prefs, role);

    final nightTimeStr = prefs.getString('il_good_night_time') ?? '22:15';
    final nightParts = nightTimeStr.split(':');
    final nightHour = nightParts.isNotEmpty
        ? (int.tryParse(nightParts[0]) ?? 22)
        : 22;
    final nightMinute = nightParts.length > 1
        ? (int.tryParse(nightParts[1]) ?? 15)
        : 15;

    final morningTimeStr = prefs.getString('il_good_morning_time') ?? '05:55';
    final morningParts = morningTimeStr.split(':');
    final morningHour = morningParts.isNotEmpty
        ? (int.tryParse(morningParts[0]) ?? 5)
        : 5;
    final morningMinute = morningParts.length > 1
        ? (int.tryParse(morningParts[1]) ?? 55)
        : 55;

    await _maybeSendAutoTimedGreeting(
      houseId: houseId,
      kind: 'good_night',
      targetHour: nightHour,
      targetMinute: nightMinute,
      windowEndHour: 23,
      windowEndMinute: 59,
      title: buildSleepReminderTitle(displayName),
      body: buildSleepReminderMessage(
        displayName,
        variantIndex: _sleepVariantIndex(DateTime.now()),
      ),
    );

    await _maybeSendAutoTimedGreeting(
      houseId: houseId,
      kind: 'good_morning',
      targetHour: morningHour,
      targetMinute: morningMinute,
      windowEndHour: 9,
      windowEndMinute: 0,
      title: L10nService().format('notif_auto_good_morning_title', {
        'value1': displayName,
      }),
      body: L10nService().format('notif_auto_good_morning_body', {
        'value1': displayName,
      }),
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
    final prefs =
        OfflineCacheService.getPrefsSync() ??
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
    // Mốc "hôm nay đã gửi" theo UID/nhà/loại lời chúc. Luật RTDB không có node
    // `system_auto_greetings` nên lệnh ghi cũ luôn bị từ chối và lời chúc chưa
    // từng được gửi; lưu mốc trên máy để mỗi máy gửi tối đa một lần mỗi ngày.
    final markerKey = 'auto_greeting_last_${user.uid}_${houseId}_$kind';
    if (prefs.getString(markerKey) == dateKey) {
      return;
    }
    await prefs.setString(markerKey, dateKey);
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    await sendPartnerNotification(
      houseId: houseId,
      title: title,
      body: body,
      data: {'screen': 'home', 'type': 'auto_$kind'},
    );
  }

  /// Gửi thông báo nhắc nhở thói quen
  Future<void> sendHabitReminderNotification(
    String houseId,
    String habitName,
  ) async {
    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().translate('notif_habit_reminder_title'),
      body: L10nService().format('notif_habit_reminder_body', {
        'value1': habitName,
      }),
      data: {'screen': 'utilities', 'type': 'habit'},
    );
  }

  /// Gửi thông báo chúc ngủ ngon / chào buổi sáng
  Future<void> sendSleepSyncNotification(String houseId, bool isWakeUp) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? UiCopy.text('copy_145933221191');

    final title = L10nService().translate(
      isWakeUp ? 'notif_sleep_wake_title' : 'notif_sleep_bed_title',
    );
    final body = isWakeUp
        ? L10nService().format('notif_sleep_wake_body', {'value1': name})
        : L10nService().format('notif_sleep_bed_body', {'value1': name});

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
    final name = user?.displayName ?? UiCopy.text('copy_145933221191');

    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().translate('notif_safe_arrival_title'),
      body: L10nService().format('notif_safe_arrival_body', {'value1': name}),
      data: {'screen': 'map', 'type': 'safe_arrival'},
    );
  }

  /// Gửi thông báo "Ngày này năm xưa"
  Future<void> sendOnThisDayNotification(String houseId, int years) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_smart_reminder_diary') ?? true)) return;

    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().translate('notif_on_this_day_title'),
      body: L10nService().format('notif_on_this_day_body', {'value1': years}),
      data: {'screen': 'diary', 'type': 'on_this_day'},
    );
  }

  /// Gửi thông báo cập nhật tâm trạng
  Future<void> sendMoodUpdateNotification(
    String houseId,
    String moodIcon,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? UiCopy.text('copy_145933221191');

    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().translate('notif_mood_title'),
      body: L10nService().format('notif_mood_body', {
        'value1': name,
        'value2': moodIcon,
      }),
      data: {'screen': 'utilities', 'type': 'mood'},
    );
  }

  /// Kiểm tra và hiển thị thông báo hộp thư tương lai đến ngày
  Future<void> checkTimeCapsules(String houseId) async {
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (!(prefs.getBool('il_smart_reminder_capsule') ?? true)) return;

      // Luật RTDB khóa `houses/{id}/time_capsules` với app, chỉ máy chủ đọc được:
      // hỏi qua listTimeCapsules. Hàm này còn ký link ảnh nên mỗi nhà chỉ hỏi
      // một lần mỗi ngày; lỗi thì không đánh dấu để lần mở sau thử lại.
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final checkedKey = 'capsule_checked_day_$houseId';
      if (prefs.getString(checkedKey) == todayKey) return;

      final capsules = await TimeCapsuleService().getUnopenedCapsules(houseId);
      await prefs.setString(checkedKey, todayKey);

      for (final capsule in capsules) {
        final unlockTimeMs = (capsule['unlock_time_ms'] as num?)?.toInt() ?? 0;
        final unlockDate = DateTime.fromMillisecondsSinceEpoch(unlockTimeMs);

        // Cùng ngày, tháng, năm
        if (now.year == unlockDate.year &&
            now.month == unlockDate.month &&
            now.day == unlockDate.day) {
          final key = 'capsule_notified_${capsule['id']}';

          if (!(prefs.getBool(key) ?? false)) {
            await showLocalNotification(
              title: L10nService().translate('notif_time_capsule_title'),
              body: L10nService().translate('notif_time_capsule_body'),
              data: {'screen': 'utilities', 'type': 'time_capsule'},
            );
            await prefs.setBool(key, true);
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Check time capsule error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể kiểm tra hộp thư tương lai lúc này.').message}',
      );
    }
  }

  /// Gửi cảnh báo ngân sách
  Future<void> sendBudgetWarningNotification(
    String houseId,
    int percent,
  ) async {
    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().translate('notif_budget_title'),
      body: L10nService().format('notif_budget_body', {'value1': percent}),
      data: {'screen': 'utilities', 'type': 'finance'},
    );
  }

  /// Gửi thông báo đóng quỹ
  Future<void> sendFundContributionNotification(String houseId) async {
    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().translate('notif_fund_title'),
      body: L10nService().translate('notif_fund_body'),
      data: {'screen': 'utilities', 'type': 'finance'},
    );
  }

  Future<void> checkAnniversaryReminder(
    String houseId,
    DateTime coupleDate,
  ) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_notif_anniversary') ?? true)) return;

    final now = DateTime.now();
    var thisYearDate = DateTime(now.year, coupleDate.month, coupleDate.day);
    if (thisYearDate.isBefore(DateTime(now.year, now.month, now.day))) {
      thisYearDate = DateTime(now.year + 1, coupleDate.month, coupleDate.day);
    }

    final diff = thisYearDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (diff == 3) {
      await sendPartnerNotification(
        houseId: houseId,
        title: L10nService().translate('notif_anniversary_3_title'),
        body: L10nService().translate('notif_anniversary_3_body'),
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    } else if (diff == 2) {
      await sendPartnerNotification(
        houseId: houseId,
        title: L10nService().translate('notif_anniversary_2_title'),
        body: L10nService().translate('notif_anniversary_2_body'),
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    } else if (diff == 1) {
      await sendPartnerNotification(
        houseId: houseId,
        title: L10nService().translate('notif_anniversary_1_title'),
        body: L10nService().translate('notif_anniversary_1_body'),
        data: {'screen': 'home', 'type': 'anniversary'},
      );
    } else if (diff == 0) {
      await sendPartnerNotification(
        houseId: houseId,
        title: L10nService().translate('notif_anniversary_0_title'),
        body: L10nService().translate('notif_anniversary_0_body'),
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
