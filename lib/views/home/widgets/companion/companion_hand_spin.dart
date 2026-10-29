import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Ảnh chụp trạng thái xoay bằng tay trong một khung hình.
@immutable
class CompanionSpinFrame {
  const CompanionSpinFrame({
    this.yaw = 0,
    this.speed = 0,
    this.dizzy = 0,
    this.held = false,
  });

  static const none = CompanionSpinFrame();

  /// Góc cộng thêm vào hướng tự nhiên của bé (radian).
  final double yaw;

  /// Tốc độ quay hiện tại (radian/giây, luôn dương).
  final double speed;

  /// Chóng mặt sau khi bị quay nhiều vòng, 0 → 1.
  final double dizzy;

  /// Ngón tay đang giữ bé.
  final bool held;

  bool get active => held || yaw != 0 || speed > 0 || dizzy > 0;
}

/// Xoay bé bằng tay: kéo ngang thì bé quay theo ngón tay; thả ra thì quay
/// tiếp theo đà, chậm dần, đứng ở góc mới một lúc rồi từ từ quay về hướng tự
/// nhiên. Quay từ hai vòng rưỡi trở lên thì bé chóng mặt một chút. Chỉ là
/// hình ảnh trên máy, không lưu hay gửi đi đâu.
class CompanionHandSpin {
  /// Kéo ngang chừng này điểm ảnh logic thì bé quay đủ một vòng.
  static const pixelsPerTurn = 260.0;
  static const _friction = 2.4; // đà giảm theo e^(−k·t)
  static const _stopSpeed = .45; // radian/giây: coi như đã dừng
  static const _hold = .9; // đứng ở góc mới trước khi quay về
  static const _returnRate = 2.6;
  static const _maxSpeed = 26.0;
  static const _dizzyTurns = 2.5;
  static const _dizzyLength = 2.4;

  double _angle = 0;
  double _velocity = 0;
  double _releasedAt = double.negativeInfinity;
  double _travelled = 0;
  bool _held = false;

  bool get held => _held;

  /// Thời gian quay theo đà sau khi thả.
  double get _coastTime => _velocity.abs() <= _stopSpeed
      ? 0
      : math.log(_velocity.abs() / _stopSpeed) / _friction;

  /// Góc đi thêm theo đà tới lúc dừng.
  double get _coast => _velocity.abs() <= _stopSpeed
      ? 0
      : (_velocity - _velocity.sign * _stopSpeed) / _friction;

  void grab(double now) {
    final frame = frameAt(now);
    // Đang chóng mặt hoặc còn quay dở thì cộng dồn số vòng.
    if (frame.dizzy <= 0 && frame.speed <= 0) _travelled = 0;
    _angle = _wrap(frame.yaw);
    _velocity = 0;
    _held = true;
  }

  void dragBy(double dx) {
    if (!_held || !dx.isFinite) return;
    final delta = dx / pixelsPerTurn * math.pi * 2;
    _angle += delta;
    _travelled += delta.abs();
  }

  void release(double now, double velocityPx) {
    if (!_held) return;
    _held = false;
    final v = velocityPx.isFinite
        ? velocityPx / pixelsPerTurn * math.pi * 2
        : 0.0;
    _velocity = v.clamp(-_maxSpeed, _maxSpeed).toDouble();
    _releasedAt = now;
    _travelled += _coast.abs();
  }

  /// Bỏ trạng thái xoay ngay (đổi màn, ẩn bé).
  void reset() {
    _held = false;
    _angle = 0;
    _velocity = 0;
    _travelled = 0;
    _releasedAt = double.negativeInfinity;
  }

  /// Bé nên đứng yên tại chỗ (đang kéo, quay theo đà hoặc vừa dừng).
  bool busyAt(double now) => _held || now - _releasedAt < _coastTime + _hold;

  CompanionSpinFrame frameAt(double now) {
    if (_held) return CompanionSpinFrame(yaw: _angle, held: true);
    final t = math.max(0.0, now - _releasedAt);
    if (!t.isFinite) return CompanionSpinFrame.none;
    final coastTime = _coastTime;
    if (t < coastTime) {
      final fade = math.exp(-_friction * t);
      return CompanionSpinFrame(
        yaw: _angle + _velocity / _friction * (1 - fade),
        speed: _velocity.abs() * fade,
      );
    }
    final rest = _wrap(_angle + _coast);
    final dizzy = _dizzyAt(t - coastTime);
    // Chóng mặt thì quay mặt ra ngay để thấy mắt xoáy, không đứng ngắm.
    final dizzyMode = _travelled >= _dizzyTurns * math.pi * 2;
    final back = t - coastTime - (dizzyMode ? 0 : _hold);
    final yaw = back <= 0
        ? rest
        : rest *
              math.exp(-(dizzyMode ? _returnRate * 1.6 : _returnRate) * back);
    if (yaw.abs() < 1e-3 && dizzy <= 0) return CompanionSpinFrame.none;
    return CompanionSpinFrame(yaw: yaw.abs() < 1e-3 ? 0 : yaw, dizzy: dizzy);
  }

  /// Chóng mặt [since] giây sau khi dừng; đang kéo thì chưa chóng mặt.
  double _dizzyAt(double since) {
    if (_travelled < _dizzyTurns * math.pi * 2 || !since.isFinite) return 0;
    if (since < 0 || since > _dizzyLength) return 0;
    return ((_dizzyLength - since) / .6).clamp(0.0, 1.0).toDouble();
  }

  static double _wrap(double a) {
    final w = (a + math.pi) % (math.pi * 2);
    return (w < 0 ? w + math.pi * 2 : w) - math.pi;
  }
}
