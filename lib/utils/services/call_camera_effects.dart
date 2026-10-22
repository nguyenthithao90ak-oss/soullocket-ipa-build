import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hiệu ứng chạy trên khung hình gửi đi, không phải lớp phủ trên preview.
class CallCameraEffects {
  static const channel = MethodChannel('soullocket/call_camera_effects');

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> setSkinBrightening(String trackId, double amount) async {
    if (!isSupported) throw UnsupportedError('call_beauty_unavailable');
    final applied = await channel.invokeMethod<bool>('setSkinBrightening', {
      'trackId': trackId,
      'amount': amount.clamp(0.0, 1.0),
    });
    if (applied != true) throw StateError('call_beauty_unavailable');
  }

  Future<void> clear() async {
    if (!isSupported) return;
    await channel.invokeMethod<void>('clear');
  }
}
