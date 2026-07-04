import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:soullocket_app/utils/helpers/sensor_helper.dart';

/// Lắng nghe cảm biến gia tốc để phát hiện cú va chạm (bump) khi 2 điện thoại cụng vào nhau.
class BumpDetector {
  final double threshold;
  final Duration cooldown;
  final VoidCallback onBump;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime? _lastBumpTime;

  BumpDetector({
    this.threshold = 4.0, // Gia tốc tuyến tính > 4.0 m/s^2 được tính là bump
    this.cooldown = const Duration(
        milliseconds: 1000), // Thời gian chờ giữa 2 lần bump liên tiếp
    required this.onBump,
  });

  void start() {
    if (kIsWeb) return; // Không hỗ trợ web

    _subscription?.cancel();
    _subscription = SensorHelper.userAccelerometerEvents.listen(
      (UserAccelerometerEvent event) {
        // userAccelerometer loại bỏ trọng lực, chỉ còn gia tốc do chuyển động tay.
        // Tính độ lớn vector gia tốc tuyến tính (bo qua Z nếu chi quan tam mặt phẳng màn hình,
        // nhung thuc te bump co the dien ra doc theo X hoac Y)
        final acceleration = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );

        if (acceleration > threshold) {
          final now = DateTime.now();
          if (_lastBumpTime == null ||
              now.difference(_lastBumpTime!) > cooldown) {
            _lastBumpTime = now;
            debugPrint(
                '[BumpDetector] Bump detected! Acceleration: $acceleration');
            onBump();
          }
        }
      },
      onError: (e) {
        debugPrint('[BumpDetector] Error: $e');
      },
      cancelOnError: false,
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
