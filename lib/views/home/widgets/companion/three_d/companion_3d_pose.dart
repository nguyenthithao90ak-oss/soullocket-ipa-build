import 'dart:math' as math;
import 'dart:ui';

/// Tư thế hiển thị độc lập với chỉ số, đồng bộ House và hành động gameplay.
final class Companion3DPose {
  const Companion3DPose({
    this.seconds = 0,
    this.stride = 0,
    this.yaw = .28,
    this.walk = 0,
    this.wave = 0,
    this.happy = 0,
    this.hug = 0,
    this.sleep = 0,
    this.eat = 0,
    this.hold = 0,
    this.blink = 0,
    this.mouth = 0,
    this.gaze = Offset.zero,
    this.bodyBob = 0,
    this.sit = 0,
  });
  final double seconds, stride, yaw, walk, wave, happy, hug, sleep, eat, hold;
  final double blink, mouth, bodyBob, sit;
  final Offset gaze;
}

/// Nội suy theo đồng hồ foreground của scene. Vẽ lại cùng timestamp không
/// thay tư thế; không dùng timer, DateTime hoặc chạy bù khi app trở lại.
final class Companion3DAnimator {
  final Map<bool, _Blend> _characters = {};

  Companion3DPose sample({
    required bool bear,
    required double seconds,
    required bool facingRight,
    required bool moving,
    required double stride,
    bool animate = true,
    bool sleeping = false,
    bool happy = false,
    double affection = 0,
    double hug = 0,
    double mouth = 0,
    double eat = 0,
    double hold = 0,
    Offset? gaze,
    double? yaw,
    double bodyBob = 0,
    double sit = 0,
  }) {
    if (!animate) {
      return Companion3DPose(
        yaw: facingRight ? .28 : -.28,
        sleep: sleeping ? 1 : 0,
        blink: sleeping ? 1 : 0,
        mouth: mouth,
        gaze: gaze ?? Offset.zero,
        sit: sit,
      );
    }
    final state = _characters.putIfAbsent(bear, _Blend.new);
    final targetYaw = yaw ?? (facingRight ? 1 : -1) * (moving ? 1.10 : .28);
    final rawDt = state.last == null ? 0.0 : seconds - state.last!;
    final reset = state.last == null || rawDt < 0;
    final dt = rawDt.clamp(0.0, .10);
    final blend = reset ? 1.0 : 1 - math.exp(-dt * 8);
    if (reset) state.yaw = targetYaw;
    final deltaYaw = math.atan2(
      math.sin(targetYaw - state.yaw),
      math.cos(targetYaw - state.yaw),
    );
    state.yaw += deltaYaw * blend;
    state.walk += ((moving ? 1 : 0) - state.walk) * blend;
    state.sleep += ((sleeping ? 1 : 0) - state.sleep) * blend;
    state.happy += ((happy ? 1 : 0) - state.happy) * blend;
    state.hug += (hug - state.hug) * blend;
    state.eat += (eat - state.eat) * blend;
    state.hold += (hold - state.hold) * blend;
    state.mouth += (mouth - state.mouth) * (reset ? 1 : 1 - math.exp(-dt * 18));
    final idleGaze = Offset(
      math.sin(seconds * .63 + (bear ? 1.3 : 0)) * .30,
      math.sin(seconds * .47) * .13,
    );
    // Pointer vẫn cập nhật đầu/mắt khi scene đang nhường ticker cho thao tác cuộn.
    state.gaze = gaze ?? Offset.lerp(state.gaze, idleGaze, blend)!;
    state.last = seconds;
    return Companion3DPose(
      seconds: seconds,
      stride: stride,
      yaw: state.yaw,
      walk: state.walk,
      wave: affection,
      happy: state.happy,
      hug: state.hug,
      sleep: state.sleep,
      eat: state.eat,
      hold: state.hold,
      mouth: state.mouth,
      gaze: state.gaze,
      bodyBob: bodyBob,
      sit: sit,
      blink: math.max(state.sleep, blinkAt(seconds, bear: bear)),
    );
  }

  /// Đóng nhanh, mở chậm; nháy kép thưa và lệch nhịp giữa hai bé.
  static double blinkAt(double seconds, {bool bear = false}) {
    final t = (seconds + (bear ? 1.79 : .42)) % 6.7;
    double pulse(double at) {
      final p = t - at;
      if (p < 0 || p > .24) return 0;
      if (p < .075) return p / .075;
      final open = ((p - .075) / .165).clamp(0.0, 1.0);
      return 1 - open * open * (3 - 2 * open);
    }

    return math.max(pulse(5.5), pulse(5.86) * .82);
  }
}

final class _Blend {
  double? last;
  double yaw = .28, walk = 0, sleep = 0, happy = 0, hug = 0, mouth = 0, eat = 0;
  double hold = 0;
  Offset gaze = Offset.zero;
}
