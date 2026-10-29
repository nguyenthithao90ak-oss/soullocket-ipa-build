import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/cloud_functions_helper.dart';
import 'device_installation_identity.dart';
import 'system_call_bridge.dart';

/// Đồng bộ riêng từng bản cài, giữ thứ tự khi token đổi hoặc người dùng đăng xuất.
class NotificationInstallationService {
  NotificationInstallationService({
    String? Function()? readUid,
    Future<DeviceInstallationIdentity> Function(String)? identity,
    Future<void> Function(String, Map<String, dynamic>)? invoke,
    DateTime Function()? now,
    Future<Map<String, dynamic>> Function()? callRegistration,
    Future<Map<String, dynamic>> Function()? greetingSettings,
  }) : _readUid = readUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _identity = identity ?? DeviceInstallationIdentity.forUid,
       _invoke = invoke ?? _call,
       _now = now ?? DateTime.now,
       _callRegistration = callRegistration ?? SystemCallBridge.instance.registration,
       _greetingSettings = greetingSettings ?? _localGreetingSettings;

  final String? Function() _readUid;
  final Future<DeviceInstallationIdentity> Function(String) _identity;
  final Future<void> Function(String, Map<String, dynamic>) _invoke;
  final DateTime Function() _now;
  final Future<Map<String, dynamic>> Function() _callRegistration;
  final Future<Map<String, dynamic>> Function() _greetingSettings;
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  String? _lastRegistration;
  DateTime? _lastRegisteredAt;
  ({String uid, String token, String id})? _activeBinding;

  static Future<void> _call(String name, Map<String, dynamic> data) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      name,
      payload: data,
      requireAppCheck: true,
      throwOriginalException: true,
      timeout: const Duration(seconds: 8),
    );
  }

  static Future<Map<String, dynamic>> _localGreetingSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawZone = (await FlutterTimezone.getLocalTimezone()
          .timeout(const Duration(seconds: 2))).identifier;
      final zone = switch (rawZone) {
        'Asia/Saigon' => 'Asia/Ho_Chi_Minh',
        'SE Asia Standard Time' => 'Asia/Bangkok',
        _ => rawZone,
      };
      String clock(String key, String fallback) {
        final value = prefs.getString(key) ?? '';
        return RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)
            ? value : fallback;
      }
      return {
        'timeZoneId': zone,
        'dailyGreetings': {
          'enabled': prefs.getBool('il_smart_reminder_love_note') ?? true,
          'morningTime': clock('il_good_morning_time', '05:55'),
          'nightTime': clock('il_good_night_time', '22:15'),
        },
      };
    } catch (_) {
      // Không đoán múi giờ theo ngôn ngữ/House; chat và cuộc gọi vẫn đăng ký.
      return {};
    }
  }

  Future<void> register({
    required String uid,
    required String token,
    required String locale,
  }) {
    final revision = _revision;
    final operation = _writes.then((_) async {
      if (_readUid() != uid || revision != _revision || token.isEmpty) return;
      final capabilities = await _callRegistration();
      if (_readUid() != uid || revision != _revision) return;
      final timing = await _greetingSettings();
      final greetingData = <String, dynamic>{
        if (timing['timeZoneId'] is String) 'timeZoneId': timing['timeZoneId'],
        if (timing['dailyGreetings'] is Map) 'dailyGreetings': timing['dailyGreetings'],
      };
      final callData = <String, dynamic>{
        if (capabilities['callUiVersion'] == 1) 'callUiVersion': 1,
        if (capabilities['voipToken'] is String &&
            capabilities['apnsEnvironment'] is String) ...{
          'voipToken': capabilities['voipToken'],
          'apnsEnvironment': capabilities['apnsEnvironment'],
        },
      };
      final key = '$uid\u0000$token\u0000$locale\u0000${jsonEncode(callData)}\u0000${jsonEncode(greetingData)}';
      if (_readUid() != uid ||
          revision != _revision ||
          token.isEmpty ||
          (_lastRegistration == key &&
              _lastRegisteredAt != null &&
              _now().difference(_lastRegisteredAt!) <
                  const Duration(hours: 24))) {
        return;
      }
      final installation = await _identity(uid);
      if (_readUid() != uid || revision != _revision) return;
      final random = Random.secure();
      final binding = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _activeBinding = (uid: uid, token: token, id: binding);
      await _invoke('registerNotificationInstallation', {
        ...installation.payload,
        'expectedUid': uid,
        'token': token,
        'registrationId': binding,
        'locale': locale,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        ...callData,
        ...greetingData,
      });
      if (_readUid() == uid && revision == _revision) {
        _lastRegistration = key;
        _lastRegisteredAt = _now();
      }
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> unregister({required String uid, required String token}) {
    // Vô hiệu hóa cả các lượt đang chờ lấy credential. Lượt đã gửi lên server
    // phải kết thúc trước khi gỡ đúng token, để không tạo lại sau logout.
    _revision++;
    _lastRegistration = null;
    final binding = _activeBinding;
    _activeBinding = null;
    final operation = _writes.then((_) async {
      if (_readUid() != uid || token.isEmpty) return;
      final installation = await _identity(uid);
      if (_readUid() != uid) return;
      await _invoke('unregisterNotificationInstallation', {
        ...installation.payload,
        'expectedUid': uid,
        'token': token,
        if (binding?.uid == uid && binding?.token == token)
          'registrationId': binding!.id,
      });
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
