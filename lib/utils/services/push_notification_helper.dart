import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:soullocket_app/core/constants/app_config.dart';
import 'app_check_http_headers.dart';

class PushNotificationHelper {
  PushNotificationHelper._();

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

      final response = await http
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[PushNotification] Máy chủ từ chối yêu cầu: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('[PushNotification] Gửi thông báo thất bại: $error');
    }
  }

  static Future<void> systemWarning({
    required String toHouseId,
    required String title,
    required String content,
  }) => _pushSystemViaServer(
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
  }) => _pushSystemViaServer(
    toHouseId: toHouseId,
    type: type,
    title: title,
    content: content,
    extra: {'fromLabel': from, ...?extra},
  );
}
