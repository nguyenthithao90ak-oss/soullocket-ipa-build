import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/utils/notification_reminder_plan.dart';
import 'package:soullocket_app/utils/notification_delivery_policy.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
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
import 'package:soullocket_app/views/utilities/capsule_screen.dart';
import 'package:soullocket_app/views/utilities/reward_store_screen.dart';
import 'package:soullocket_app/views/utilities/secret_vault_screen.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
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
import 'notification_installation_service.dart';
import '../incoming_call_payload.dart';
import 'incoming_call_notifications.dart';
import 'incoming_call_suppression.dart';
import 'system_call_bridge.dart';

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
      _localNotif = FlutterLocalNotificationsPlugin(),
      _readNotificationUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _readHouseSettingsForTesting = null;

  @visibleForTesting
  NotificationService.forTesting({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    String? Function()? readUid,
    Future<Map<String, dynamic>?> Function(String houseId)? readHouseSettings,
  }) : _fcm = messaging,
       _localNotif = localNotifications,
       _readNotificationUid = readUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _readHouseSettingsForTesting = readHouseSettings;

  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotif;
  final String? Function() _readNotificationUid;
  final Future<Map<String, dynamic>?> Function(String houseId)? _readHouseSettingsForTesting;
  ({String uid, String houseId, String role, String name, bool genderSwapped})? _houseReminderIdentity;
  int _houseIdentityRevision = 0;
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
  final PendingNotificationTapBuffer _pendingTap = PendingNotificationTapBuffer();
  String? _homeReadyUid;
  String? _registeredFcmToken;
  String? _registeredFcmUid;
  int _pushRegistrationRevision = 0;
  bool _pushRegistrationPaused = false;
  Future<void> _fcmTokenWrites = Future<void>.value();
  late final NotificationInstallationService _installations =
      GetIt.instance.isRegistered<NotificationInstallationService>()
          ? GetIt.instance<NotificationInstallationService>()
          : NotificationInstallationService();
  final NotificationDeliveryOnce _automaticDelivery = NotificationDeliveryOnce();
  final incomingCallRequest = ValueNotifier<IncomingCallRequest?>(null);
  StreamSubscription<IncomingCallRequest>? _systemCallSubscription;
  StreamSubscription<void>? _callRegistrationSubscription;
  Future<void> _callSettingsWrites = Future<void>.value();

  /// Áp dụng lựa chọn cuộc gọi cho native trước khi đồng bộ token lên server.
  Future<void> syncSystemCallSettings() {
    final uid = _readNotificationUid();
    final operation = _callSettingsWrites.then((_) async {
      if (_readNotificationUid() != uid) return;
      final prefs = await SharedPreferences.getInstance();
      final enabled = uid != null && !_pushRegistrationPaused &&
          (prefs.getBool('il_notifications_enabled') ?? true) &&
          (prefs.getBool('il_notif_chat') ?? true);
      if (_readNotificationUid() != uid) return;
      await SystemCallBridge.instance.configure(uid: uid, enabled: enabled);
    });
    _callSettingsWrites = operation.catchError((Object error) {
      debugPrint('[IncomingCall] Cấu hình native chưa sẵn sàng: ${error.runtimeType}');
    });
    return _callSettingsWrites;
  }

  /// Chỉ mở trang cấp quyền khi người dùng chủ động bấm trong Cài đặt.
  Future<void> openIncomingCallSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _ensureLocalPluginInitialized();
    try {
      await _androidPlugin?.requestFullScreenIntentPermission();
    } catch (error) {
      debugPrint('[IncomingCall] Chưa mở được quyền toàn màn hình: ${error.runtimeType}');
    }
  }

  IncomingCallRequest? takeIncomingCallRequest() {
    final request = incomingCallRequest.value;
    incomingCallRequest.value = null;
    return request;
  }

  @visibleForTesting
  void markHomeReadyForTesting() => _homeReadyUid = _readNotificationUid();

  /// Công tắc tổng không thay đổi lựa chọn từng loại. Hủy cả lịch và thẻ
  /// local đã hiện, cùng hàng đợi ghi để tác vụ cũ không sống lại sau khi tắt.
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('il_notifications_enabled', enabled);
    // Ghi preference trước rồi mới tăng revision để mọi tác vụ đang đợi thấy
    // trạng thái tắt, còn tác vụ đã đọc trạng thái cũ bị chặn bởi revision.
    _notificationPreferenceRevision++;
    _reminderGeneration++;
    await syncSystemCallSettings();
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
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return SystemCallBridge.instance.hasTimeSensitiveNotificationAccess();
    }
    if (defaultTargetPlatform != TargetPlatform.android) return false;
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
        await _androidPlugin?.createNotificationChannel(IncomingCallNotifications.priorityChannel);
      }
    } catch (error) {
      debugPrint(
        '[NotificationService] Không tạo được kênh thông báo ưu tiên: $error',
      );
    }
  }

  /// Mở quyền Notification Policy Access trên Android hoặc Time Sensitive trên iOS.
  /// Kết quả `false` nghĩa là người dùng chưa bật quyền; UI sẽ kiểm tra lại
  /// khi quay về ứng dụng.
  Future<bool> requestPriorityNotificationAccess() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (await hasPriorityNotificationAccess()) return true;
      await openPriorityNotificationSettings();
      return hasPriorityNotificationAccess();
    }
    if (defaultTargetPlatform != TargetPlatform.android) return false;
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
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    return _priorityNotificationTypes.contains(type) ||
        NotificationDeliveryPolicy.screen(data) == 'soul_merge_call';
  }

  Future<bool> _shouldUsePriorityChannel(Map<String, dynamic> data) async {
    if (!_isPriorityNotificationType(data)) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('il_priority_notifications_enabled') ?? false)) {
      return false;
    }
    if (NotificationDeliveryPolicy.screen(data) == 'soul_merge_call' &&
        defaultTargetPlatform == TargetPlatform.android) {
      return IncomingCallNotifications.preparePriorityChannel(plugin: _localNotif, prefs: prefs);
    }
    if (!await hasPriorityNotificationAccess()) return false;
    await prefs.reload();
    return prefs.getBool('il_priority_notifications_enabled') == true;
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
    _pushRegistrationPaused = false;
    SystemCallBridge.instance.initialize();
    _callRegistrationSubscription ??= SystemCallBridge.instance.registrationChanges.listen((_) {
      unawaited(_saveNotificationLocale());
    });
    _systemCallSubscription ??= SystemCallBridge.instance.events.listen((request) {
      // Mute/end của cuộc gọi đang kết nối do VideoCallScreen xử lý.
      if (request.action == IncomingCallAction.mute) return;
      unawaited(_navigateFromData({...request.data,
        'screen': 'soul_merge_call', 'callAction': request.action.name}));
    });
    await syncSystemCallSettings();
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

        // Chỉ onMessage sở hữu hiển thị foreground: tránh iOS hiện cả remote
        // lẫn local và bảo đảm công tắc từng loại được kiểm tra trước khi hiện.
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
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
    final revision = _pushRegistrationRevision;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _pushRegistrationPaused) return;

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
    if (token == null || _pushRegistrationPaused ||
        revision != _pushRegistrationRevision ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    await _storeFcmToken(user.uid, token, revision);

    // Field scalar giữ tương thích backend cũ; registry riêng từng máy được
    // đồng bộ cùng locale, không ghi token vào House dùng chung.
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    final revision = _pushRegistrationRevision;
    if (user == null || _pushRegistrationPaused) return;
    try {
      await _storeFcmToken(user.uid, newToken, revision);
    } catch (error) {
      debugPrint('[NotificationService] FCM token refresh deferred: $error');
    }

  }

  Future<void> _storeFcmToken(String uid, String token, int revision) async {
    bool active() => !_pushRegistrationPaused &&
        revision == _pushRegistrationRevision &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    final write = _fcmTokenWrites.then((_) async {
      if (!active() || token.isEmpty) return;
      // Ghi tuần tự để logout chờ lượt đang ghi, rồi mới xóa token của máy.
      _registeredFcmToken = token;
      _registeredFcmUid = uid;
      try {
        await FirebaseDatabase.instance.ref('users/$uid/fcmToken')
            .set(token).timeout(const Duration(seconds: 5));
      } catch (_) {
        debugPrint('[NotificationService] legacy token sync unavailable');
      }
    });
    _fcmTokenWrites = write.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    await write;
    if (active()) await _saveNotificationLocale();
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
            .set(locale).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Rules cũ có thể chưa hỗ trợ locale; vẫn giữ FCM token và thông báo trong app.
        debugPrint(
          '[NotificationService] notification locale sync unavailable',
        );
      }
      final token = _registeredFcmUid == uid ? _registeredFcmToken : null;
      if (token != null && !_pushRegistrationPaused && revision == _localeRevision &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        try {
          await _installations.register(uid: uid, token: token, locale: locale);
        } catch (_) {
          debugPrint('[NotificationService] installation registration deferred');
        }
      }
    }();
    _localeWrite = write;
    await write;
    if (identical(_localeWrite, write)) _localeWrite = null;
  }

  /// Làm mới múi giờ/giờ chúc của đúng bản cài sau resume hoặc đổi cài đặt.
  Future<void> refreshNotificationInstallation() async {
    final uid = _readNotificationUid();
    final token = _registeredFcmUid == uid ? _registeredFcmToken : null;
    if (uid == null || token == null || _pushRegistrationPaused) return;
    try {
      await _installations.register(
        uid: uid, token: token, locale: L10nService().localeCode,
      );
    } catch (_) {
      debugPrint('[NotificationService] Chưa làm mới được múi giờ bản cài');
    }
  }

  /// Dọn dẹp FCM token khi người dùng đăng xuất
  Future<void> clearTokenOnSignOut() async {
    final logoutUid = FirebaseAuth.instance.currentUser?.uid;
    final knownToken = _registeredFcmUid == logoutUid ? _registeredFcmToken : null;
    _pushRegistrationPaused = true;
    _pushRegistrationRevision++;
    _homeReadyUid = null;
    _pendingTap.clear();
    incomingCallRequest.value = null;
    await syncSystemCallSettings();
    _registeredFcmToken = null;
    _registeredFcmUid = null;
    // Vô hiệu hóa mọi lần đồng bộ đang chờ để lịch của UID cũ không được
    // đặt lại sau khi người dùng đã đăng xuất.
    _reminderGeneration++;
    _reminderSignedOutUid = _readNotificationUid();
    _houseReminderIdentity = null;
    _houseIdentityRevision++;
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
      await _fcmTokenWrites;
      if (logoutUid != null && FirebaseAuth.instance.currentUser?.uid == logoutUid) {
        final localToken = knownToken ?? await _fcm.getToken().timeout(
          const Duration(seconds: 2), onTimeout: () => null,
        );
        if (localToken != null) {
          try {
            await _installations.unregister(uid: logoutUid, token: localToken);
          } catch (_) {
            // App cũ/backend chưa rollout vẫn gỡ scalar và token native bên dưới.
            debugPrint('[NotificationService] installation unregister deferred');
          }
        }
        // Token trên server có thể đã thuộc máy khác. Transaction so sánh
        // nguyên tử, không xóa nhầm token mới giữa lúc đọc và đăng xuất.
        await FirebaseDatabase.instance
            .ref('users/$logoutUid/fcmToken')
            .runTransaction((remoteToken) {
              if (remoteToken == null) return Transaction.success(null);
              return NotificationDeliveryPolicy.ownsToken(remoteToken, localToken)
                  ? Transaction.success(null) : Transaction.abort();
            }, applyLocally: false)
            .timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('[NotificationService] clearTokenOnSignOut error: $e');
    }

    // Xóa FCM token local trên thiết bị để ngắt hoàn toàn việc nhận notification
    try {
      if (FirebaseAuth.instance.currentUser?.uid == logoutUid) {
        await _fcm.deleteToken();
      }
    } catch (e) {
      debugPrint('[NotificationService] deleteToken error: $e');
    }
  }

  /// Xử lý thông báo khi App đang mở — hiển thị Local Notification
  @visibleForTesting
  Future<void> handleForegroundMessageForTesting(RemoteMessage message) =>
      _handleForegroundMessage(message);

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final type = message.data['type']?.toString() ?? '';
    final screen = NotificationDeliveryPolicy.screen(message.data);
    final prefs = await SharedPreferences.getInstance();
    if (NotificationDeliveryPolicy.expired(message.data, DateTime.now()) ||
        !NotificationDeliveryPolicy.matchesScope(message.data,
          uid: _readNotificationUid(),
          houseId: prefs.getString('il_house_id'))) {
      return;
    }
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

    if (!NotificationDeliveryPolicy.allowsLocal(message.data, prefs.getBool)) return;

    final isInteractionOrMerge =
        !isSoulMergeCall &&
        (type == 'soul_merge' ||
            screen == 'soul_merge' ||
            type == 'partner_care' ||
            type == 'interaction' ||
            type == 'photo_shot');

    if (isSoulMergeCall) {
      if (message.data['callAction'] == 'cancel') {
        await dismissIncomingCallNotification(message.data['roomId']?.toString() ?? '');
        return;
      }
      // Home kiểm chứng phòng và sở hữu UI/chuông. Inbox RTDB cùng FCM chỉ
      // gợi ý cùng một room, không phát thêm local notification độc lập.
      await _navigateFromData({...message.data, 'screen': 'soul_merge_call'});
      return;
    }

    // Yêu cầu: Không hiện thông báo in-app (Overlay/Heads-up) khi đang trong app đối với sự kiện gửi icon/bắn tim/tương tác (ôm, hôn...)
    // Chỉ hiện thông báo Push Notification của Hệ thống khi khóa màn hình hoặc thoát app.
    if (isInteractionOrMerge) return;

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
    unawaited(_openLocalPayload(response.payload, actionId: response.actionId));
  }

  Future<void> _openLocalPayload(String? payload, {String? actionId}) async {
    if (payload == null) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (NotificationDeliveryPolicy.screen(data) == 'soul_merge_call') {
        data['callAction'] = incomingCallAction(actionId).name;
      }
      await _navigateFromData(data);
    } catch (error) {
      debugPrint(AppErrorMapper.resolve(error).message);
    }
  }

  /// Chỉ xử lý cold start sau khi màn hình chính đã qua luồng đăng nhập.
  Future<void> handleSoulEventLaunch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _homeReadyUid = uid;
    for (final request in await SystemCallBridge.instance.takePending()) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      unawaited(_navigateFromData({...request.data,
        'screen': 'soul_merge_call', 'callAction': request.action.name}));
    }
    final pending = _pendingTap.take(uid: uid, now: DateTime.now());
    if (pending != null) unawaited(_navigateFromData(pending));
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
        actionId: details?.notificationResponse?.actionId,
      );
    } catch (error) {
      debugPrint(AppErrorMapper.resolve(error).message);
    }
  }

  Future<void> _navigateFromData(Map<String, dynamic> data) {
    final isCall = NotificationDeliveryPolicy.screen(data) == 'soul_merge_call';
    final terminalAction = isCall && ['end', 'decline'].contains(data['callAction']);
    if (!terminalAction && NotificationDeliveryPolicy.expired(data, DateTime.now())) {
      return Future<void>.value();
    }
    final uid = _readNotificationUid();
    if (uid == null || _homeReadyUid != uid || (!isCall && navigatorKey.currentState == null)) {
      _pendingTap.store(data, uid: uid, now: DateTime.now());
      return Future<void>.value();
    }
    if (isCall) {
      final action = switch (data['callAction']) {
        'answer' => IncomingCallAction.answer,
        'decline' => IncomingCallAction.decline,
        'end' => IncomingCallAction.end,
        _ => IncomingCallAction.open,
      };
      // Không đẩy thêm Home lên trên màn nhận/cuộc gọi hiện có.
      incomingCallRequest.value = IncomingCallRequest(Map.of(data), action);
      return Future<void>.value();
    }
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
    final screen = NotificationDeliveryPolicy.screen(data);
    final houseService = HouseService();
    final myHouseId = await houseService.getCurrentHouseId();
    if (!NotificationDeliveryPolicy.matchesScope(data, uid: requestUid, houseId: myHouseId) ||
        FirebaseAuth.instance.currentUser?.uid != requestUid) {
      return;
    }

    Widget destination;
    switch (screen) {
      case 'internal_chat':
        final senderRole = data['senderRole']?.toString();
        if (myHouseId == null || !['user1', 'user2'].contains(senderRole)) return;
        destination = ChatDetailScreen(
          myHouseId: myHouseId,
          targetHouseId: myHouseId,
          targetName: UiCopy.text('copy_145933221191'),
          isInternal: true,
          currentRole: senderRole == 'user1' ? 'user2' : 'user1',
          targetRole: senderRole!,
        );
        break;
      case 'chat':
        final targetHouseId =
            data['targetHouseId']?.toString() ??
            data['target_house_id']?.toString();
        final targetName =
            data['target_name']?.toString() ?? UiCopy.text('copy_145933221191');
        if (myHouseId == null ||
            targetHouseId == null ||
            targetHouseId.isEmpty) {
          destination = const NotificationCenterScreen();
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
          destination = const NotificationCenterScreen();
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
        destination = HomeScreen(initialTab: NotificationDeliveryPolicy.homeTab(screen));
        break;
      case 'utilities':
        destination = HomeScreen(initialTab: NotificationDeliveryPolicy.homeTab(screen));
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
        destination = HomeScreen(initialTab: NotificationDeliveryPolicy.homeTab(screen));
        break;
      case 'update':
        destination = HomeScreen(initialTab: NotificationDeliveryPolicy.homeTab(screen));
        break;
      case 'creative_diary':
        destination = const CreativeDiaryScreen();
        break;
      case 'time_capsule':
        if (myHouseId == null) return;
        final name = await _resolveCurrentUserDisplayName(houseService, myHouseId);
        if (FirebaseAuth.instance.currentUser?.uid != requestUid ||
            await houseService.getCurrentHouseId() != myHouseId) {
          return;
        }
        destination = CapsuleScreen(houseId: myHouseId, myName: name);
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
        destination = const NotificationCenterScreen();
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
  ) async => await _currentHouseNotificationName(houseId) ??
      UiCopy.text('copy_40ffd8d0f1c7');

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
      if (roomId.isNotEmpty) return incomingCallNotificationId(roomId);
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
    Map<String, dynamic> data = const {},
    bool isPriority = false,
  }) {
    if (isIncomingCall) return IncomingCallNotifications.details(data: data, isPriority: isPriority);
    final channel = isPriority ? _priorityChannel : _channel;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        channelBypassDnd: isPriority,
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
        timeoutAfter: isIncomingCall ? 60000 : null,
        icon: 'ic_stat_soullocket',
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
    await _showLocalNotificationIfAllowed(
      title: title, body: body, data: data, dedupeKey: dedupeKey,
    );
  }

  Future<bool> _showLocalNotificationIfAllowed({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? dedupeKey,
    bool Function()? active,
  }) async {
    if (kIsWeb || (title.trim().isEmpty && body.trim().isEmpty)) return false;
    final revision = _notificationPreferenceRevision;
    final registrationRevision = _pushRegistrationRevision;
    final requestUid = _readNotificationUid();
    final prefs = await SharedPreferences.getInstance();
    final requestHouse = prefs.getString('il_house_id');
    final payloadData = <String, dynamic>{...?data};
    final incomingRoomId = NotificationDeliveryPolicy.screen(payloadData) == 'soul_merge_call'
        ? payloadData['roomId']?.toString() ?? '' : '';
    final hasScope = payloadData.containsKey('accountUid') ||
        payloadData.containsKey('houseId') || payloadData.containsKey('house_id');
    bool canShow() => (active?.call() ?? true) &&
        registrationRevision == _pushRegistrationRevision &&
        _readNotificationUid() == requestUid &&
        prefs.getString('il_house_id') == requestHouse &&
        _canWriteLocalNotification(prefs, revision) &&
        NotificationDeliveryPolicy.allowsLocal(payloadData, prefs.getBool) &&
        !NotificationDeliveryPolicy.expired(payloadData, DateTime.now()) &&
        !incomingCallLocallyExpired(payloadData, DateTime.now().millisecondsSinceEpoch) &&
        (incomingRoomId.isEmpty || !IncomingCallSuppression.isClosed(prefs,
          uid: requestUid, roomId: incomingRoomId)) &&
        (!hasScope || NotificationDeliveryPolicy.matchesScope(payloadData,
          uid: _readNotificationUid(),
          houseId: prefs.getString('il_house_id')));
    if (!canShow()) return false;
    // Hiển thị local không cần lưu lại token FCM hay đồng bộ toàn bộ lịch.
    await _ensureLocalPluginInitialized();

    final key = dedupeKey ?? '$title|$body|${jsonEncode(payloadData)}';
    return _withLocalNotificationWrite(() async {
      if (incomingRoomId.isNotEmpty) await prefs.reload();
      if (!canShow() || !await hasPermission()) {
        return false;
      }
      final isPriority = await _shouldUsePriorityChannel(payloadData);
      if (incomingRoomId.isNotEmpty) await prefs.reload();
      if (!canShow()) return false;
      final now = DateTime.now();
      final shouldSkip =
          _lastForegroundMessageKey == key &&
          _lastForegroundShownAt != null &&
          now.difference(_lastForegroundShownAt!) < const Duration(seconds: 5);
      if (shouldSkip) return true;
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
          data: payloadData,
          isPriority: isPriority && prefs.getBool('il_priority_notifications_enabled') == true,
        ),
        payload: jsonEncode(payloadData),
      );
      if (incomingRoomId.isNotEmpty) {
        await prefs.reload();
        if (!canShow()) {
          await _localNotif.cancel(id: notificationId);
          return false;
        }
      }
      _lastForegroundMessageKey = key;
      _lastForegroundShownAt = now;
      return true;
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
    String? accountUid,
    String? houseId,
    String? callerAvatar,
    int? localExpiresAt,
  }) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) return;
    final safeCallerName = callerName.trim().isEmpty
        ? L10nService().translate('home_ngigi_f1117f')
        : callerName.trim();
    await showLocalNotification(
      title: safeCallerName,
      body: L10nService().translate(isVideo ? 'call_incoming_video' : 'call_incoming_audio'),
      data: <String, dynamic>{
        'screen': 'soul_merge_call',
        'type': 'soul_merge_call',
        'roomId': normalizedRoomId,
        'callerName': safeCallerName,
        'isVideo': isVideo.toString(),
        'accountUid': ?accountUid,
        'houseId': ?houseId,
        'callerAvatar': ?callerAvatar,
        'localExpiresAt': ?localExpiresAt,
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
      await IncomingCallSuppression.close(uid: _readNotificationUid(), roomId: normalizedRoomId);
      await _ensureLocalPluginInitialized();
      if (!_localPluginReady) return;
      await _withLocalNotificationWrite(() async {
        await _localNotif.cancel(id: incomingCallNotificationId(normalizedRoomId));
        await _localNotif.cancel(id: normalizedRoomId.hashCode); // Thẻ của bản app cũ.
      });
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
    String? idempotencyKey,
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
      'idempotencyKey': ?idempotencyKey,
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
    final name = await _currentHouseNotificationName(houseId);
    if (name == null) return;
    await sendPartnerNotification(
      houseId: houseId,
      title: L10nService().format('notif_miss_you_title', {'value1': name}),
      body: L10nService().format('notif_miss_you_body', {'value1': name}),
      data: {'screen': 'home', 'type': 'miss_you'},
    );
  }

  /// Gửi thông báo khi đăng bài mới lên feed
  Future<void> sendNewPostNotification(String houseId, String postId) async {
    final name = await _currentHouseNotificationName(houseId);
    if (name == null) return;
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
      await _androidPlugin?.createNotificationChannel(IncomingCallNotifications.channel);

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('ic_stat_soullocket');

      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: [IncomingCallNotifications.category],
          );

      const WindowsInitializationSettings windowsSettings =
          WindowsInitializationSettings(
            appName: 'SoulLocket',
            appUserModelId: 'SoulLocket.App',
            guid: '8d76c80d-3f20-4f42-9ad0-7f3f148bf17c',
          );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        windows: windowsSettings,
      );

      await _localNotif.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: incomingCallNotificationBackgroundAction,
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

  /// Đồng bộ tên hiển thị theo snapshot settings Home đang nghe.
  /// Revision tăng trước await để lượt lịch cũ không ghi đè tên mới.
  Future<void> updateHouseReminderIdentity({
    required String accountUid,
    required String houseId,
    required String role,
    required String displayName,
    bool genderSwapped = false,
  }) {
    final uid = accountUid.trim();
    final house = houseId.trim();
    if (uid.isEmpty || house.isEmpty || _readNotificationUid() != uid) {
      return Future<void>.value();
    }
    final identity = (
      uid: uid,
      houseId: house,
      role: RoleUtils.normalize(role),
      name: displayName.trim(),
      genderSwapped: genderSwapped,
    );
    if (_houseReminderIdentity == identity) {
      return _reminderSyncTask ?? Future<void>.value();
    }
    _houseReminderIdentity = identity;
    _houseIdentityRevision++;
    _reminderGeneration++;
    return _enqueueReminderSync((generation) async {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _reminderGeneration ||
          _readNotificationUid() != uid ||
          prefs.getString('il_house_id')?.trim() != house ||
          RoleUtils.normalize(prefs.getString('il_role')) != identity.role) {
        return;
      }
      await _syncDailySleepReminderNow(generation, uid);
      if (!_appForeground) {
        await _syncInactivityReminderNow(generation, uid);
      }
    });
  }

  Future<void> syncDailySleepReminder() {
    final uid = _readNotificationUid();
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
        _readNotificationUid() == uid &&
        uid != _reminderSignedOutUid &&
        (prefs.getString('il_house_id') ?? '').trim() == houseId &&
        (prefs.getBool('il_notifications_enabled') ?? true) &&
        (prefs.getBool('il_smart_reminder_sleep') ?? true);
    if (!active()) return;
    await _ensureLocalPluginInitialized();
    if (!active() || !await _ensureTimeZoneReady()) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    final displayName = await _resolveSleepReminderDisplayName(prefs, role, houseId: houseId);
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
            'timeZoneId': tz.local.name,
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

  String? _snapshotHouseName(String uid, String houseId, String role) {
    final identity = _houseReminderIdentity;
    if (identity == null || identity.uid != uid || identity.houseId != houseId ||
        identity.role != role) return null;
    if (identity.name.isNotEmpty) return identity.name;
    return L10nService().translate(
      RoleUtils.defaultNameKey(role, genderSwapped: identity.genderSwapped),
    );
  }

  Future<String> _resolveSleepReminderDisplayName(
    SharedPreferences prefs,
    String role, {
    String? houseId,
  }) async {
    final fallback = L10nService().translate(RoleUtils.defaultNameKey(role));
    final uid = _readNotificationUid()?.trim() ?? '';
    final house = (houseId ?? prefs.getString('il_house_id') ?? '').trim();
    if (uid.isEmpty || house.isEmpty ||
        prefs.getString('il_auth_uid')?.trim() != uid ||
        prefs.getString('il_house_id')?.trim() != house) return fallback;
    final current = _snapshotHouseName(uid, house, role);
    if (current != null) return current;
    try {
      final settings = await (_readHouseSettingsForTesting?.call(house) ??
          HouseService().getHouseSettings(house))
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (_readNotificationUid() != uid ||
          prefs.getString('il_house_id')?.trim() != house ||
          RoleUtils.normalize(prefs.getString('il_role')) != role) return fallback;
      final latest = _snapshotHouseName(uid, house, role);
      if (latest != null) return latest;
      final name = settings?[role == 'user2' ? 'nameU2' : 'nameU1']
          ?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
      return L10nService().translate(RoleUtils.defaultNameKey(role,
          genderSwapped: RoleUtils.readGenderSwapped(settings)));
    } catch (error) {
      debugPrint('[NotificationService] Không lấy được tên House: ' + error.runtimeType.toString());
      return _snapshotHouseName(uid, house, role) ?? fallback;
    }
  }

  Future<String?> _currentHouseNotificationName(String houseId) async {
    final uid = _readNotificationUid();
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final role = RoleUtils.normalize(prefs.getString('il_role'));
    bool active() => _readNotificationUid() == uid &&
        prefs.getString('il_auth_uid')?.trim() == uid &&
        prefs.getString('il_house_id')?.trim() == houseId.trim() &&
        RoleUtils.normalize(prefs.getString('il_role')) == role;
    if (!active()) return null;
    final name = await _resolveSleepReminderDisplayName(prefs, role,
        houseId: houseId);
    return active() ? name : null;
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
      unawaited(refreshNotificationInstallation());
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
    final uid = _readNotificationUid();
    final identityRevision = _houseIdentityRevision;
    if (uid == null) return;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('il_notifications_enabled') ?? true;
    if (!notificationsEnabled) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    final displayName = await _resolveSleepReminderDisplayName(prefs, role, houseId: houseId);
    bool active() => _readNotificationUid() == uid &&
        _houseIdentityRevision == identityRevision &&
        prefs.getString('il_house_id')?.trim() == houseId &&
        RoleUtils.normalize(prefs.getString('il_role')) == role;
    if (!active()) return;

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
      identityActive: active,
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
      identityActive: active,
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
    required bool Function() identityActive,
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
    // Mốc local chỉ ghi khi server nhận queue; idempotencyKey chống lặp hai máy.
    final markerKey = 'auto_greeting_last_${user.uid}_${houseId}_$kind';
    final generation = _pushRegistrationRevision;
    bool active() => identityActive() && generation == _pushRegistrationRevision &&
        FirebaseAuth.instance.currentUser?.uid == user.uid &&
        prefs.getString('il_house_id') == houseId &&
        (prefs.getBool('il_notifications_enabled') ?? true) &&
        (prefs.getBool('il_smart_reminder_love_note') ?? true);
    await _automaticDelivery.run(
      key: '$markerKey:$dateKey',
      active: active,
      alreadyDelivered: () => prefs.getString(markerKey) == dateKey,
      deliver: () async {
        await sendPartnerNotification(
          houseId: houseId, title: title, body: body,
          data: {'screen': 'home', 'type': 'auto_$kind'},
          idempotencyKey: 'greeting:$kind:$dateKey',
        );
        return true;
      },
      markDelivered: () async { await prefs.setString(markerKey, dateKey); },
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
    final name = await _currentHouseNotificationName(houseId);
    if (name == null) return;

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
    final name = await _currentHouseNotificationName(houseId);
    if (name == null) return;

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
    final name = await _currentHouseNotificationName(houseId);
    if (name == null) return;

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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final generation = _pushRegistrationRevision;
      if (uid == null) return;
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      bool active() => generation == _pushRegistrationRevision &&
          FirebaseAuth.instance.currentUser?.uid == uid &&
          prefs.getString('il_house_id') == houseId &&
          (prefs.getBool('il_notifications_enabled') ?? true) &&
          (prefs.getBool('il_smart_reminder_capsule') ?? true);
      if (!active()) return;
      final now = DateTime.now();
      final checkedKey = 'capsule_check_after_${uid}_$houseId';
      var nextCheckMs = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
      // Giữ tối đa một lượt/ngày, nhưng cho kiểm tra lại khi thư đến giờ trong
      // cùng ngày. Lỗi API/native, tắt quyền hoặc đổi phiên không ghi mốc thành công.
      await _automaticDelivery.run(
        key: checkedKey,
        active: active,
        alreadyDelivered: () => (prefs.getInt(checkedKey) ?? 0) > now.millisecondsSinceEpoch,
        deliver: () async {
          final capsules = await TimeCapsuleService().getUnopenedCapsules(houseId);
          if (!active()) return false;
          for (final capsule in capsules) {
            final unlockMs = int.tryParse(capsule['unlock_time_ms']?.toString() ?? '') ?? 0;
            if (unlockMs > now.millisecondsSinceEpoch && unlockMs < nextCheckMs) {
              nextCheckMs = unlockMs;
            }
            if (!NotificationDeliveryPolicy.capsuleReady(capsule, now)) continue;
            final id = capsule['id']?.toString().trim() ?? '';
            if (id.isEmpty) continue;
            final key = 'capsule_notified_${uid}_${houseId}_$id';
            final delivered = await _automaticDelivery.run(
              key: key,
              active: active,
              alreadyDelivered: () => prefs.getBool(key) ?? false,
              deliver: () => _showLocalNotificationIfAllowed(
                title: L10nService().translate('notif_time_capsule_title'),
                body: L10nService().translate('notif_time_capsule_body'),
                data: {'screen': 'time_capsule', 'type': 'time_capsule',
                  'accountUid': uid, 'houseId': houseId, 'capsuleId': id},
                dedupeKey: key,
                active: active,
              ),
              markDelivered: () async { await prefs.setBool(key, true); },
            );
            if (!delivered) return false;
          }
          return true;
        },
        markDelivered: () async { await prefs.setInt(checkedKey, nextCheckMs); },
      );
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

  /// Dispose all subscriptions to prevent leaks.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _systemCallSubscription?.cancel();
    _systemCallSubscription = null;
    _callRegistrationSubscription?.cancel();
    _callRegistrationSubscription = null;
  }
}
