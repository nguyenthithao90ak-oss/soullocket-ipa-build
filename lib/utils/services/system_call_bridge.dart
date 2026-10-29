import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../incoming_call_payload.dart';

/// Cầu nối hệ thống; không sở hữu SDP/ICE, mic, camera hoặc quyền House.
class SystemCallBridge {
  SystemCallBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('soullocket/system_calls');
  static final instance = SystemCallBridge();
  final MethodChannel _channel;
  final _events = StreamController<IncomingCallRequest>.broadcast(sync: true);
  Stream<IncomingCallRequest> get events => _events.stream;
  final _registrationChanges = StreamController<void>.broadcast();
  Stream<void> get registrationChanges => _registrationChanges.stream;
  bool _initialized = false;
  bool get _mobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS);

  void initialize() {
    if (_initialized || !_mobile) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRegistrationChanged') {
        _registrationChanges.add(null);
        return;
      }
      if (call.method != 'onCallEvent' || call.arguments is! Map) return;
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final action = switch (data['callAction']) {
        'answer' => IncomingCallAction.answer,
        'decline' => IncomingCallAction.decline,
        'end' => IncomingCallAction.end,
        'mute' => IncomingCallAction.mute,
        _ => IncomingCallAction.open,
      };
      if (validIncomingCallRoomId(data['roomId']?.toString() ?? '')) {
        _events.add(IncomingCallRequest(data, action));
      }
    });
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? data]) async {
    if (!_mobile) return null;
    initialize();
    try { return await _channel.invokeMethod<T>(method, data).timeout(const Duration(seconds: 3)); }
    on MissingPluginException { return null; }
    on PlatformException { return null; }
    on TimeoutException { return null; }
  }

  Future<List<IncomingCallRequest>> takePending() async {
    final pending = await _invoke<List<dynamic>>('takePending');
    return (pending ?? []).whereType<Map>().map((raw) {
      final data = Map<String, dynamic>.from(raw);
      return IncomingCallRequest(data, switch (data['callAction']) {
        'answer' => IncomingCallAction.answer,
        'decline' => IncomingCallAction.decline,
        'end' => IncomingCallAction.end,
        _ => IncomingCallAction.open,
      });
    }).where((item) => validIncomingCallRoomId(item.roomId)).toList();
  }

  Future<bool> reportIncoming(Map<String, dynamic> data) async =>
    await _invoke<bool>('reportIncoming', data) ?? false;
  Future<void> setIncomingVisible(bool visible) async {
    await _invoke<void>('setIncomingVisible', {'visible': visible});
  }
  Future<void> answer(String roomId) async {
    await _invoke<void>('answer', {'roomId': roomId});
  }
  Future<void> mediaReady(String roomId) async {
    await _invoke<void>('mediaReady', {'roomId': roomId});
  }
  Future<void> setMuted(String roomId, bool muted) async {
    await _invoke<void>('setMuted', {'roomId': roomId, 'muted': muted});
  }
  Future<void> end(String roomId) async {
    await _invoke<void>('end', {'roomId': roomId});
  }
  /// Time Sensitive có thể bị tắt riêng trong Cài đặt iOS, kể cả khi app có quyền thông báo.
  Future<bool> hasTimeSensitiveNotificationAccess() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    return await _invoke<bool>('hasTimeSensitiveNotificationAccess') ?? false;
  }
  Future<Map<String, dynamic>> registration() async {
    final raw = await _invoke<Map>('registration');
    return raw == null ? {} : Map<String, dynamic>.from(raw);
  }
  Future<void> configure({required String? uid, required bool enabled}) async {
    await _invoke<void>('configure', {'uid': uid, 'enabled': enabled});
  }
}
