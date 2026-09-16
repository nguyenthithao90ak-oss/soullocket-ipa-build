import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'home_companion_motion.dart';
import 'home_companion_outfit.dart';

@immutable
class CompanionPlayPose {
  const CompanionPlayPose({
    this.offset = Offset.zero,
    this.lift = 0,
    this.tilt = 0,
    this.kick = 0,
    this.dizzy = 0,
    this.impact = 0,
  });
  final Offset offset;
  final double lift;
  final double tilt;
  final double kick;
  final double dizzy;
  final double impact;
}

/// Màn đùa hoạt hình ngắn. Chỉ dịch hình vẽ, không làm mất đường đi/cuộn đã đo.
/// Không cộng dồn yêu cầu, không chạy bù lúc app ra nền.
class HomeCompanionPlay extends ChangeNotifier {
  double _time = 0;
  double _clock = 0;
  double _nextAllowedAt = 0;
  bool _active = false;
  int _impactSerial = 0;
  Offset _between = Offset.zero;
  HomeCompanionCharacter _initiator = HomeCompanionCharacter.bunny;

  bool get active => _active;
  int get impactSerial => _impactSerial;
  double get time => _time;
  bool facesRight(HomeCompanionCharacter character) =>
      character == HomeCompanionCharacter.bunny
      ? _between.dx >= 0
      : _between.dx < 0;

  bool start(
    HomeCompanionCharacter initiator,
    HomeCompanionMotion bunny,
    HomeCompanionMotion bear,
  ) {
    final between = bear.position - bunny.position;
    if (_active ||
        _clock < _nextAllowedAt ||
        !bunny.hasSurfaces ||
        !bear.hasSurfaces ||
        between.distance < 35 ||
        between.distance > 112 ||
        between.dy.abs() > 24 ||
        bunny.hopLift > 1 ||
        bear.hopLift > 1 ||
        bunny.phase == HomeCompanionPhase.sweeping ||
        bear.phase == HomeCompanionPhase.sweeping) {
      return false;
    }
    _initiator = initiator;
    _between = between;
    _time = 0;
    _active = true;
    _nextAllowedAt = _clock + 5;
    notifyListeners();
    return true;
  }

  void advance(Duration delta) {
    if (delta <= Duration.zero) return;
    final dt = math.min(delta.inMicroseconds / 1000000, 0.1);
    _clock += dt;
    if (!_active) return;
    final previous = _time;
    _time += dt;
    if (previous < 0.82 && _time >= 0.82) _impactSerial++;
    if (_time >= 2.8) {
      _active = false;
      _time = 0;
    }
    notifyListeners();
  }

  CompanionPlayPose pose(HomeCompanionCharacter character) {
    if (!_active) return const CompanionPlayPose();
    final attacking = character == _initiator;
    final direction = character == HomeCompanionCharacter.bunny
        ? _between
        : -_between;
    final sign = direction.dx >= 0 ? 1.0 : -1.0;
    final approach = _time < 0.22
        ? 0.0
        : _time < 0.82
        ? _ease((_time - 0.22) / 0.6)
        : _time < 1.3
        ? 1 - _ease((_time - 0.82) / 0.48)
        : 0.0;
    final travel = direction * (attacking ? 0.43 : 0.12) * approach;
    final flight = _time >= 0.22 && _time < 1.3
        ? math.sin(math.pi * ((_time - 0.22) / 1.08))
        : 0.0;
    final impact = _time >= 0.82 && _time < 1.22
        ? math.sin(math.pi * (_time - 0.82) / 0.4)
        : 0.0;
    final dizzy = !attacking && _time >= 1.05 && _time < 2.45
        ? math.sin(math.pi * (_time - 1.05) / 1.4)
        : 0.0;
    final kick = attacking && _time > 0.48 && _time < 1.08
        ? math.sin(math.pi * (_time - 0.48) / 0.6)
        : 0.0;
    return CompanionPlayPose(
      offset: travel,
      lift: flight * (attacking ? 18 : 5),
      tilt:
          sign * (attacking ? -flight * 0.16 : impact * 0.22) +
          math.sin(_time * 16) * dizzy * 0.055,
      kick: kick,
      dizzy: dizzy,
      impact: attacking ? impact : 0,
    );
  }

  static double _ease(double t) => t * t * (3 - 2 * t);

  void cancel() {
    if (!_active) return;
    _active = false;
    _time = 0;
    notifyListeners();
  }
}
