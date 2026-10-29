import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/bootstrap/app_bootstrap.dart';
import '../incoming_call_payload.dart';
import '../notification_delivery_policy.dart';
import 'l10n_service.dart';
import 'incoming_call_suppression.dart';

const incomingCallChannelId = 'soullocket_calls_v1';
const priorityIncomingCallChannelId = 'soullocket_calls_priority_v1';
const incomingCallCategory = 'SOUL_CALL';
const answerCallActionId = 'soul_call_answer';
const declineCallActionId = 'soul_call_decline';

IncomingCallAction incomingCallAction(String? id) => switch (id) {
  answerCallActionId => IncomingCallAction.answer,
  declineCallActionId => IncomingCallAction.decline,
  _ => IncomingCallAction.open,
};

/// Callback isolate riêng: từ chối không cần mở Home hoặc lấy camera/micro.
@pragma('vm:entry-point')
Future<void> incomingCallNotificationBackgroundAction(NotificationResponse response) async {
  if (response.actionId != declineCallActionId || response.payload == null) return;
  try {
    final raw = jsonDecode(response.payload!);
    if (raw is! Map) return;
    final data = Map<String, dynamic>.from(raw);
    final roomId = data['roomId']?.toString().trim() ?? '';
    if (!validIncomingCallRoomId(roomId)) return;
    final account = data['accountUid'];
    final closed = IncomingCallSuppression.close(uid: account is String ? account : null,
      roomId: roomId);
    // Hủy ngay trên máy, không đợi kết nối Firebase mới ngắt chuông.
    await FlutterLocalNotificationsPlugin().cancel(id: incomingCallNotificationId(roomId));
    await closed;
    await initializeFirebaseBootstrap();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (data['accountUid'] == null || data['accountUid'] == currentUid) {
      await IncomingCallSuppression.close(uid: currentUid, roomId: roomId);
    }
    final incoming = await IncomingCallNotifications.readVerified(data);
    if (incoming == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseDatabase.instance.ref('calls/$roomId').runTransaction((raw) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return Transaction.abort();
      if (raw == null) return Transaction.success(null);
      if (raw is! Map || raw['status'] != 'ringing' ||
          raw['callerId'] != incoming['callerId'] ||
          raw['calleeId'] != incoming['recipientHouseId'] ||
           raw['timestamp'] != incoming['timestamp']) {
        return Transaction.abort();
      }
      return Transaction.success({...Map<String, dynamic>.from(raw),
        'status': 'ended', 'endReason': 'declined', 'endedAt': ServerValue.timestamp});
    }, applyLocally: false).timeout(const Duration(seconds: 8));
  } catch (error) {
    debugPrint('[IncomingCall] Chưa đồng bộ được thao tác từ chối: ${error.runtimeType}');
  }
}

/// Dùng cùng một cấu hình cho main isolate và FCM nền, không tạo hai chuông.
abstract final class IncomingCallNotifications {
  static AndroidNotificationChannel get channel => _channel(isPriority: false);
  static AndroidNotificationChannel get priorityChannel => _channel(isPriority: true);

  static AndroidNotificationChannel _channel({required bool isPriority}) => AndroidNotificationChannel(
    isPriority ? priorityIncomingCallChannelId : incomingCallChannelId,
    isPriority
      ? '${L10nService().translate('home_cucgin_eff0b9')} · ${L10nService().translate('priority_notifications_section_title')}'
      : L10nService().translate('home_cucgin_eff0b9'),
    bypassDnd: isPriority,
    importance: Importance.max, playSound: true,
    sound: const RawResourceAndroidNotificationSound('soul_call_ringtone'),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true, vibrationPattern: Int64List.fromList([0, 700, 350, 700, 1800]),
  );

  /// Main isolate và FCM nền cùng đọc công tắc trên máy và quyền hệ thống.
  /// Không dùng cờ priority của push để tự cấp quyền vượt Không làm phiền.
  static Future<bool> preparePriorityChannel({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await prefs.reload();
      if (prefs.getBool('il_priority_notifications_enabled') != true) return false;
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.hasNotificationPolicyAccess().timeout(const Duration(seconds: 3)) != true) return false;
      await prefs.reload();
      if (prefs.getBool('il_priority_notifications_enabled') != true) return false;
      await android?.createNotificationChannel(priorityChannel);
      await prefs.reload();
      return prefs.getBool('il_priority_notifications_enabled') == true;
    } catch (error) {
      debugPrint('[IncomingCall] Dùng kênh thường vì chưa có quyền ưu tiên: ${error.runtimeType}');
      return false;
    }
  }

  static DarwinNotificationCategory get category => DarwinNotificationCategory(
    incomingCallCategory, actions: [
      DarwinNotificationAction.plain(answerCallActionId,
        L10nService().translate('home_nghemy_e08606'),
        options: {DarwinNotificationActionOption.foreground}),
      DarwinNotificationAction.plain(declineCallActionId,
        L10nService().translate('home_tchi_2119d8'),
        options: {DarwinNotificationActionOption.destructive}),
    ],
  );

  static NotificationDetails details({required Map<String, dynamic> data, bool isPriority = false}) {
    final selectedChannel = isPriority ? priorityChannel : channel;
    final remaining = (incomingCallLocalDeadline(data) ??
      DateTime.now().millisecondsSinceEpoch + 45000) - DateTime.now().millisecondsSinceEpoch;
    return NotificationDetails(
      android: AndroidNotificationDetails(selectedChannel.id, selectedChannel.name,
        channelBypassDnd: isPriority,
        importance: Importance.max, priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true, ongoing: true, autoCancel: false,
        onlyAlertOnce: true, timeoutAfter: remaining.clamp(1, 45000),
        sound: const RawResourceAndroidNotificationSound('soul_call_ringtone'),
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: hệ thống lặp và tự dừng khi hủy.
        enableVibration: true, vibrationPattern: selectedChannel.vibrationPattern,
        visibility: NotificationVisibility.private,
        icon: 'ic_stat_soullocket',
        actions: [
          AndroidNotificationAction(declineCallActionId,
            L10nService().translate('home_tchi_2119d8'), titleColor: const Color(0xffdf536b)),
          AndroidNotificationAction(answerCallActionId,
            L10nService().translate('home_nghemy_e08606'),
            showsUserInterface: true, titleColor: const Color(0xff299f83)),
        ]),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true,
        presentBadge: false, sound: 'soul_call_ringtone.wav',
        interruptionLevel: isPriority ? InterruptionLevel.timeSensitive : null,
        categoryIdentifier: incomingCallCategory),
    );
  }

  /// Payload push chỉ gợi ý room. Quyền, người gọi và deadline lấy từ Firebase.
  static Future<Map<String, dynamic>?> readVerified(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final roomId = data['roomId']?.toString().trim() ?? '';
    if (uid == null || !validIncomingCallRoomId(roomId)) return null;
    final db = FirebaseDatabase.instance;
    final values = await Future.wait([
      db.ref('calls/$roomId').get(), db.ref('users/$uid/houseId').get(),
      db.ref('.info/serverTimeOffset').get(),
    ]).timeout(const Duration(seconds: 8));
    var houseId = values[1].value?.toString().trim() ?? '';
    if (houseId.isEmpty) {
      houseId = (await db.ref('users/$uid/house_id').get()
        .timeout(const Duration(seconds: 3))).value?.toString().trim() ?? '';
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid ||
        !NotificationDeliveryPolicy.matchesScope(data, uid: uid, houseId: houseId)) {
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return incomingCallFromRoom(roomId: roomId, raw: values[0].value,
      uid: uid, houseId: houseId, deviceNow: now,
      serverNow: now + ((values[2].value as num?)?.toInt() ?? 0));
  }

  /// Chỉ data-only v1 mới tạo thẻ local ở nền. Push legacy đã có thẻ của OS.
  static Future<void> handleBackgroundPush(Map<String, dynamic> data) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || data['callUiVersion'] != '1') return;
    final plugin = FlutterLocalNotificationsPlugin();
    final roomId = data['roomId']?.toString().trim() ?? '';
    if (!validIncomingCallRoomId(roomId)) return;
    if (data['callAction'] == 'cancel') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (FirebaseAuth.instance.currentUser?.uid != data['accountUid'] ||
          !NotificationDeliveryPolicy.matchesScope(data,
            uid: FirebaseAuth.instance.currentUser?.uid,
            houseId: prefs.getString('il_house_id'))) {
        return;
      }
      await IncomingCallSuppression.close(uid: FirebaseAuth.instance.currentUser?.uid,
        roomId: roomId);
      await plugin.cancel(id: incomingCallNotificationId(roomId));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (IncomingCallSuppression.isClosed(prefs,
        uid: FirebaseAuth.instance.currentUser?.uid, roomId: roomId)) {
      return;
    }
    if (!NotificationDeliveryPolicy.allowsLocal(data, prefs.getBool)) return;
    final incoming = await readVerified(data);
    if (incoming == null) return;
    await L10nService().init();
    await plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_soullocket')),
      onDidReceiveBackgroundNotificationResponse: incomingCallNotificationBackgroundAction);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
    final isPriority = await preparePriorityChannel(plugin: plugin, prefs: prefs);
    await prefs.reload();
    if (FirebaseAuth.instance.currentUser?.uid != incoming['accountUid'] ||
        IncomingCallSuppression.isClosed(prefs, uid: incoming['accountUid'] as String?, roomId: roomId) ||
        !NotificationDeliveryPolicy.allowsLocal(data, prefs.getBool) ||
        DateTime.now().millisecondsSinceEpoch >= (incoming['localExpiresAt'] as int)) {
      return;
    }
    final name = incoming['callerName']?.toString().trim() ?? '';
    await plugin.show(id: incomingCallNotificationId(roomId),
      title: name.isEmpty ? L10nService().translate('home_ngigi_f1117f') : name,
      body: L10nService().translate(incoming['isVideo'] == true ? 'call_incoming_video' : 'call_incoming_audio'),
      notificationDetails: details(data: incoming,
        isPriority: isPriority && prefs.getBool('il_priority_notifications_enabled') == true),
      payload: jsonEncode({...data,
        'localExpiresAt': incoming['localExpiresAt']}));
    await prefs.reload();
    if (FirebaseAuth.instance.currentUser?.uid != incoming['accountUid'] ||
        IncomingCallSuppression.isClosed(prefs, uid: incoming['accountUid'] as String?, roomId: roomId)) {
      await plugin.cancel(id: incomingCallNotificationId(roomId));
    }
  }
}
