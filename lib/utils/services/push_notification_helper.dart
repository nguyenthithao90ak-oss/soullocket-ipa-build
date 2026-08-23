import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import 'package:soullocket_app/core/constants/app_config.dart';
import 'app_check_http_headers.dart';

class PushNotificationHelper {
  PushNotificationHelper._();

  static final _db = FirebaseDatabase.instance;

  static Future<void> push({
    required String toHouseId,
    required String type,
    required String from,
    required String msg,
    String? title,
    String? postId,
    String? fromId,
    String? fromLabel,
    Map<String, dynamic>? extra,
  }) async {
    if (toHouseId.isEmpty) return;
    try {
      final payload = <String, dynamic>{
        'type': type,
        'from': from,
        'msg': msg,
        'ts': ServerValue.timestamp,
        'title': ?title,
        'postId': ?postId,
        'fromId': ?fromId,
        'fromLabel': ?fromLabel,
        ...?extra,
      };
      await _db.ref('notifications/$toHouseId').push().set(payload);
    } catch (_) {}
  }

  static Future<void> _pushSystemViaServer({
    required String toHouseId,
    required String type,
    required String title,
    required String content,
    Map<String, dynamic>? extra,
  }) async {
    if (toHouseId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idToken = await user.getIdToken(true) ?? '';
      if (idToken.isEmpty) return;

      await http
          .post(
            Uri.parse(AppConfig.systemNotificationUrl),
            headers: await AppCheckHttpHeaders.withRequiredToken({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            }, forceRefresh: true),
            body: jsonEncode({
              'houseId': toHouseId,
              'type': type,
              'title': title,
              'content': content,
              'extra': ?extra,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  static Future<void> friendRequest({
    required String toHouseId,
    required String fromHouseId,
    required String fromName,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'friend_request',
        from: fromHouseId, // Must be houseId to pass Firebase security rules
        fromId: fromHouseId,
        msg: '$fromName muốn kết bạn với bạn!',
        title: 'Lời mời kết bạn',
      );

  static Future<void> friendAccepted({
    required String toHouseId,
    required String fromHouseId,
    required String fromName,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'friend_accept',
        from: fromHouseId, // Must be houseId to pass Firebase security rules
        fromId: fromHouseId,
        msg: '$fromName đã chấp nhận lời mời kết bạn của bạn!',
        title: 'Kết bạn thành công',
      );

  static Future<void> friendWave({
    required String toHouseId,
    required String fromName,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'friend_wave',
        from: fromName,
        msg: 'vừa gửi lời chào mới!',
      );

  static Future<void> heartDrop({
    required String toHouseId,
    required String fromName,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'fire',
        from: fromName,
        msg: 'đã thả tim cho nhà bạn!',
      );

  static Future<void> chatMessage({
    required String toHouseId,
    required String fromName,
    required String preview,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'message',
        from: fromName,
        msg: preview.length > 30 ? '${preview.substring(0, 30)}...' : preview,
      );

  static Future<void> socialLike({
    required String toHouseId,
    required String fromHouseId,
    required String fromName,
    required String postId,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'like',
        from: fromHouseId,
        fromId: fromHouseId,
        fromLabel: fromName,
        msg: 'đã thích bài đăng của bạn!',
        postId: postId,
        title: 'Lượt thích mới',
      );

  static Future<void> socialComment({
    required String toHouseId,
    required String fromHouseId,
    required String fromName,
    required String commentText,
    required String postId,
  }) =>
      push(
        toHouseId: toHouseId,
        type: 'comment',
        from: fromHouseId,
        fromId: fromHouseId,
        fromLabel: fromName,
        msg: commentText,
        postId: postId,
        title: 'Bình luận mới',
      );

  static Future<void> systemWarning({
    required String toHouseId,
    required String title,
    required String content,
  }) =>
      _pushSystemViaServer(
        toHouseId: toHouseId,
        type: 'warning',
        title: title,
        content: content,
      );

  static Future<void> systemEvent({
    required String toHouseId,
    required String type,
    required String title,
    required String content,
    String from = 'Hệ thống',
    Map<String, dynamic>? extra,
  }) =>
      _pushSystemViaServer(
        toHouseId: toHouseId,
        type: type,
        title: title,
        content: content,
        extra: {
          'fromLabel': from,
          ...?extra,
        },
      );

  static Future<void> globalBroadcast({
    required String message,
    required String adminName,
    List<String> targetHouseIds = const [],
  }) async {
    if (targetHouseIds.isEmpty) return;
    final batch = <Future>[];
    for (final hid in targetHouseIds) {
      batch.add(push(
        toHouseId: hid,
        type: 'system',
        from: adminName,
        msg: message,
        title: 'Thông báo hệ thống',
        extra: {
          'immutable': true,
          'systemLocked': true,
        },
      ));
    }
    await Future.wait(batch);
  }
}
