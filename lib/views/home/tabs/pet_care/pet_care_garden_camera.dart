import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'pet_care_garden_map.dart';

@immutable
class GardenVec3 {
  const GardenVec3(this.x, this.y, this.z);
  final double x, y, z;
  GardenVec3 operator +(GardenVec3 p) => GardenVec3(x + p.x, y + p.y, z + p.z);
  GardenVec3 operator -(GardenVec3 p) => GardenVec3(x - p.x, y - p.y, z - p.z);
  GardenVec3 operator *(double k) => GardenVec3(x * k, y * k, z * k);
  double dot(GardenVec3 p) => x * p.x + y * p.y + z * p.z;
  GardenVec3 cross(GardenVec3 p) =>
      GardenVec3(y * p.z - z * p.y, z * p.x - x * p.z, x * p.y - y * p.x);
  double get length => math.sqrt(dot(this));
  GardenVec3 get unit =>
      length < .00001 ? const GardenVec3(0, 0, 0) : this * (1 / length);
  static GardenVec3 lerp(GardenVec3 a, GardenVec3 b, double t) => GardenVec3(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t,
  );
  static GardenVec3 fromMap(Offset p, [double height = 0]) =>
      GardenVec3(p.dx / 100 - 4.8, height, p.dy / 100 - 5.2);
  Offset get mapPoint => Offset((x + 4.8) * 100, (z + 5.2) * 100);
}

enum PetGardenViewMode { orbit, firstPerson, map }

/// Camera phối cảnh thật. Đổi góc nhìn chỉ đổi camera, không ghi tiến trình.
class PetGardenCamera extends ChangeNotifier {
  PetGardenViewMode _mode = PetGardenViewMode.orbit;
  _GardenCameraBlend? _blend;
  bool _widePresentation = false;
  bool following = false;

  PetGardenViewMode get mode => _mode;
  bool get isTransitioning => _blend != null;

  /// Bố cục ngang dùng pose third-person gần hơn; dọc giữ khoảng lùi để các
  /// luống và semantic target không bị cắt khỏi màn hình nhỏ.
  void setViewport(Size size) {
    _widePresentation = size.width > size.height * 1.18;
  }

  // Góc mặc định thấp và gần, ưu tiên thấy mặt Thỏ/Gấu cùng các vật tương tác.
  // Nút thu phóng vẫn cho phép lùi ra để xem toàn bộ rừng và các cổng.
  // Pose chéo thấp vừa đủ để thấy mặt bé, luống phía trước và cả rừng xa;
  // giữ khoảng lùi để mọi điểm tương tác vẫn nằm trong vùng chạm an toàn.
  double yaw = .24, elevation = .43, radius = 6.6;
  GardenVec3 target = const GardenVec3(-.9, .80, .15);
  GardenVec3 player = const GardenVec3(1, 1.55, 3.5);
  double lookYaw = -.12, lookPitch = -.18;
  GardenVec3 _orbitEye() {
    final pitch = _widePresentation ? elevation.clamp(.28, .46) : elevation;
    // Khi quay ra sau nhà, lùi dần để mái/tường không áp sát ống kính.
    // Hệ số liên tục theo góc quay, không đổi pose đột ngột ở một mốc góc.
    final nearHouse = math.exp(
      -math.pow((target.x + 1.1) / 6, 2) - math.pow((target.z + 1.5) / 7, 2),
    );
    final framing = 1 + .64 * nearHouse * math.max(0.0, -math.cos(yaw));
    final distance = radius * (_widePresentation ? .94 : 1.45) * framing;
    return target +
        GardenVec3(
              math.sin(yaw) * math.cos(pitch),
              math.sin(pitch),
              math.cos(yaw) * math.cos(pitch),
            ) *
            distance;
  }

  GardenVec3 _firstPersonForward() => GardenVec3(
    math.sin(lookYaw) * math.cos(lookPitch),
    math.sin(lookPitch),
    -math.cos(lookYaw) * math.cos(lookPitch),
  ).unit;
  GardenVec3 _eyeFor(PetGardenViewMode value) =>
      value == PetGardenViewMode.firstPerson ? player : _orbitEye();
  GardenVec3 _forwardFor(PetGardenViewMode value) =>
      value == PetGardenViewMode.firstPerson
      ? _firstPersonForward()
      : (target - _orbitEye()).unit;
  GardenVec3 get eye {
    final blend = _blend;
    if (blend == null) return _eyeFor(_mode);
    final t = _ease(blend.progress);
    return GardenVec3.lerp(blend.fromEye, blend.toEye, t);
  }

  GardenVec3 get forward {
    final blend = _blend;
    if (blend == null) return _forwardFor(_mode);
    final t = _ease(blend.progress);
    return GardenVec3.lerp(blend.fromForward, blend.toForward, t).unit;
  }

  GardenVec3 get right => forward.cross(const GardenVec3(0, 1, 0)).unit;
  GardenVec3 get up => right.cross(forward).unit;
  double lens(Size size) => size.height * .78;
  (Offset, double)? project(GardenVec3 point, Size size) {
    final delta = point - eye, depth = delta.dot(forward);
    if (depth < .09) return null;
    final f = lens(size);
    return (
      Offset(
        size.width / 2 + delta.dot(right) * f / depth,
        size.height * .48 - delta.dot(up) * f / depth,
      ),
      depth,
    );
  }

  GardenVec3 ray(Offset screen, Size size) =>
      (forward +
              right * ((screen.dx - size.width / 2) / lens(size)) +
              up * ((size.height * .48 - screen.dy) / lens(size)))
          .unit;
  GardenVec3? ground(Offset screen, Size size) {
    final d = ray(screen, size);
    if (d.y >= -.0001) return null;
    final t = -eye.y / d.y;
    return t > 0 && t < 80 ? eye + d * t : null;
  }

  void setMode(PetGardenViewMode value) {
    _blend = null;
    _mode = value;
    notifyListeners();
  }

  /// Chuyển giữa hai camera 3D bằng một pose trung gian. Map vẫn đổi ngay
  /// vì InteractiveViewer không dùng cùng hệ tọa độ với scene phối cảnh.
  void transitionTo(
    PetGardenViewMode value, {
    Duration duration = const Duration(milliseconds: 440),
  }) {
    if (value == _mode && _blend == null) return;
    if (value == PetGardenViewMode.map || _mode == PetGardenViewMode.map) {
      setMode(value);
      return;
    }
    final fromEye = eye;
    final fromForward = forward;
    final toEye = _eyeFor(value);
    final toForward = _forwardFor(value);
    if (duration <= Duration.zero) {
      setMode(value);
      return;
    }
    _blend = _GardenCameraBlend(
      target: value,
      fromEye: fromEye,
      toEye: toEye,
      fromForward: fromForward,
      toForward: toForward,
      durationSeconds: duration.inMicroseconds / Duration.microsecondsPerSecond,
    );
    notifyListeners();
  }

  /// Tiến một khung camera; caller quyết định ticker/lifecycle của cảnh.
  void advanceTransition(double seconds) {
    final blend = _blend;
    if (blend == null) return;
    blend.progress =
        (blend.progress + seconds.clamp(0.0, .08) / blend.durationSeconds)
            .clamp(0.0, 1.0);
    if (blend.progress >= 1) {
      _mode = blend.target;
      _blend = null;
    }
    notifyListeners();
  }

  void finishTransition() {
    final blend = _blend;
    if (blend == null) return;
    _mode = blend.target;
    _blend = null;
    notifyListeners();
  }

  void drag(Offset delta) {
    if (mode == PetGardenViewMode.firstPerson) {
      lookYaw += delta.dx * .006;
      lookPitch = (lookPitch - delta.dy * .005).clamp(-1.1, .6);
    } else {
      yaw -= delta.dx * .007;
      elevation = (elevation + delta.dy * .005).clamp(.18, 1.32);
    }
    notifyListeners();
  }

  void zoom(double factor) {
    if (mode == PetGardenViewMode.firstPerson) return;
    radius = (radius / factor).clamp(4.2, 19);
    notifyListeners();
  }

  void reset() {
    _blend = null;
    yaw = .24;
    elevation = .43;
    radius = 6.6;
    following = false;
    target = const GardenVec3(-.9, .80, .15);
    player = const GardenVec3(1, 1.55, 3.5);
    lookYaw = -.12;
    lookPitch = -.18;
    notifyListeners();
  }

  /// Bám theo chân bé, giữ độ cao ngắm và chuyển tâm mềm khi bắt đầu đi.
  void follow(Offset feet, double seconds) {
    if (!following || mode != PetGardenViewMode.orbit || isTransitioning) {
      return;
    }
    final desired = GardenVec3.fromMap(feet, .86);
    final amount = 1 - math.exp(-5.5 * seconds.clamp(0.0, .05));
    final next = GardenVec3.lerp(target, desired, amount);
    if ((next - target).length < .001) return;
    target = next;
    notifyListeners();
  }

  /// Hướng cần điều khiển luôn theo mặt phẳng đất của camera hiện tại.
  Offset groundAxis(Offset stick) {
    final flat = GardenVec3(forward.x, 0, forward.z).unit;
    final side = GardenVec3(right.x, 0, right.z).unit;
    final direction = side * stick.dx + flat * (-stick.dy);
    return Offset(direction.x, direction.z);
  }

  bool canStand(GardenVec3 at) {
    final p = at.mapPoint;
    if (!PetGardenMap.walkable(p) ||
        !PetGardenMap.walkable(p + const Offset(13, 0)) ||
        !PetGardenMap.walkable(p - const Offset(13, 0)) ||
        !PetGardenMap.walkable(p + const Offset(0, 13)) ||
        !PetGardenMap.walkable(p - const Offset(0, 13))) {
      return false;
    }
    if (const Rect.fromLTWH(107, 77, 526, 351).contains(p)) return false;
    if (const Rect.fromLTWH(645, 204, 261, 232).contains(p)) return false;
    for (var i = 0; i < PetGardenMap.plots.length; i++) {
      if (Rect.fromCenter(
        center: PetGardenMap.plots[i],
        width: i < 6 ? 185 : 110,
        height: i < 6 ? 125 : 100,
      ).contains(p)) {
        return false;
      }
    }
    return true;
  }

  void move(Offset stick, double seconds) {
    if (mode != PetGardenViewMode.firstPerson || stick.distance < .06) return;
    final dt = seconds.clamp(0.0, .05);
    final axis = stick.distance > 1 ? stick / stick.distance : stick;
    final ahead = GardenVec3(math.sin(lookYaw), 0, -math.cos(lookYaw));
    final side = GardenVec3(math.cos(lookYaw), 0, math.sin(lookYaw));
    final delta = (side * axis.dx + ahead * (-axis.dy)) * (1.7 * dt);
    final next = player + delta;
    if (canStand(next)) {
      player = next;
    } else {
      final x = GardenVec3(next.x, player.y, player.z);
      if (canStand(x)) player = x;
      final z = GardenVec3(player.x, player.y, next.z);
      if (canStand(z)) player = z;
    }
    notifyListeners();
  }
}

double _ease(double t) => t * t * (3 - 2 * t);

class _GardenCameraBlend {
  _GardenCameraBlend({
    required this.target,
    required this.fromEye,
    required this.toEye,
    required this.fromForward,
    required this.toForward,
    required this.durationSeconds,
  });
  final PetGardenViewMode target;
  final GardenVec3 fromEye, toEye, fromForward, toForward;
  final double durationSeconds;
  double progress = 0;
}
