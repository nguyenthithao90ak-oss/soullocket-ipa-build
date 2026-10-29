import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hiệu ứng chạy trên khung hình gửi đi, không phải lớp phủ trên preview.
class CallCameraEffects {
  static const channel = MethodChannel('soullocket/call_camera_effects');
  Future<void>? _operation;

  Future<void> _enqueue(Future<void> Function() action) {
    final previous = _operation;
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // Bridge lỗi không làm kẹt thao tác tiếp theo hoặc cleanup.
        }
      }
      await action();
    }();
    _operation = operation;
    unawaited(
      operation.then(
        (_) {
          if (identical(_operation, operation)) _operation = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_operation, operation)) _operation = null;
        },
      ),
    );
    // UI có deadline riêng; queue vẫn giữ Future native thật để lệnh tới muộn
    // không vượt qua clear hoặc thao tác mới.
    return operation.timeout(const Duration(seconds: 5));
  }

  Future<void> waitUntilIdle() async {
    try {
      await _operation;
    } catch (_) {
      // Kết quả đã được trả cho caller; ở đây chỉ đợi native nhả thao tác.
    }
  }

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> setSkinBrightening(String trackId, double amount) async {
    if (!isSupported) throw UnsupportedError('call_beauty_unavailable');
    await _enqueue(() async {
      final applied = await channel.invokeMethod<bool>('setSkinBrightening', {
        'trackId': trackId,
        'amount': amount.clamp(0.0, 1.0),
      });
      if (applied != true) throw StateError('call_beauty_unavailable');
    });
  }

  Future<void> clear() async {
    if (!isSupported) return;
    await _enqueue(() => channel.invokeMethod<void>('clear'));
  }
}
