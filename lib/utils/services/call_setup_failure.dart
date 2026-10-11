import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

/// Chỉ lưu bước và mã lỗi; không đưa SDP, token hay nội dung riêng tư vào log.
class CallSetupFailure implements Exception {
  const CallSetupFailure(this.stage, this.code);
  final String stage;
  final String code;

  factory CallSetupFailure.from(Object error, String stage) {
    if (error is CallSetupFailure) return error;
    if (error is FirebaseException) return CallSetupFailure(stage, error.code);
    if (error is TimeoutException) return CallSetupFailure(stage, 'timeout');
    if (error is PlatformException) return CallSetupFailure(stage, error.code);
    return CallSetupFailure(stage, error.runtimeType.toString());
  }

  String get messageKey {
    final normalized = code.toLowerCase().replaceAll('_', '-');
    if (normalized.contains('permission-denied')) {
      return 'p4_call_service_blocked';
    }
    if (normalized.contains('unauthenticated')) return 'p4_call_sign_in_again';
    if (stage == 'media' || stage == 'renderer') {
      return 'p4_call_media_unavailable';
    }
    if (normalized == 'timeout') return 'p4_call_setup_timeout';
    return 'p4_call_connection_failed';
  }

  @override
  String toString() => 'CallSetupFailure(stage=$stage, code=$code)';
}

Future<T> runCallSetupStep<T>(String stage, Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw CallSetupFailure.from(error, stage);
  }
}

/// Firebase có thể trả danh sách hoặc map chỉ số; urls hỗ trợ một hoặc nhiều URL.
class RtcIceServers {
  static List<Map<String, dynamic>> parse(Object? raw) {
    final items = raw is List
        ? raw
        : raw is Map
        ? raw.values
        : const [];
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) continue;
      final rawUrls = item['urls'];
      final urls =
          (rawUrls is String
                  ? [rawUrls]
                  : rawUrls is List
                  ? rawUrls
                  : const [])
              .whereType<String>()
              .map((url) => url.trim())
              .where(
                (url) =>
                    RegExp(r'^(stun|stuns|turn|turns):[^\s]+$').hasMatch(url),
              )
              .toList();
      if (urls.isEmpty) continue;
      result.add({
        'urls': urls.length == 1 ? urls.single : urls,
        if (item['username'] is String) 'username': item['username'],
        if (item['credential'] is String) 'credential': item['credential'],
      });
    }
    return result;
  }
}
