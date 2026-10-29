part of 'pet_care_garden_3d.dart';

/// Phân vùng mesh một lần theo hình học. Khi camera đổi, chỉ duyệt xa → gần;
/// không so từng cặp mặt hay tô một depth buffer bằng Dart trong mỗi frame.
class _GardenBsp {
  _GardenBsp(this.normal, this.distance, this.coplanar, this.front, this.back);
  final GardenVec3 normal;
  final double distance;
  final List<_WorldFace> coplanar;
  final _GardenBsp? front, back;

  static _GardenBsp? build(List<_WorldFace> faces, [int depth = 0]) {
    if (faces.isEmpty) return null;
    if (depth >= 48) {
      return _GardenBsp(const GardenVec3(0, 1, 0), 0, faces, null, null);
    }
    GardenVec3? plane;
    var distance = 0.0;
    final candidates = <(GardenVec3, double, double)>[];
    for (final face in faces) {
      for (var i = 1; i < face.points.length - 1; i++) {
        final n = (face.points[i] - face.points[0]).cross(
          face.points[i + 1] - face.points[0],
        );
        if (n.length > .00001) {
          candidates.add((n.unit, n.unit.dot(face.points[0]), n.length));
          break;
        }
      }
    }
    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    var best = double.infinity;
    for (final candidate in candidates.take(faces.length > 40 ? 16 : 8)) {
      var f = 0, b = 0, split = 0, on = 0;
      final step = (faces.length ~/ 128).clamp(1, faces.length);
      for (var i = 0; i < faces.length; i += step) {
        var front = false, back = false;
        for (final p in faces[i].points) {
          final d = candidate.$1.dot(p) - candidate.$2;
          front = front || d > .00002;
          back = back || d < -.00002;
        }
        if (front) f++;
        if (back) b++;
        if (front && back) split++;
        if (!front && !back) on++;
      }
      final score = split * 7 + (f - b).abs() - on * .5;
      if (score < best) {
        best = score;
        plane = candidate.$1;
        distance = candidate.$2;
      }
    }
    if (plane == null) return null;
    var splitting = plane;
    final front = <_WorldFace>[],
        back = <_WorldFace>[],
        coplanar = <_WorldFace>[];
    for (final face in faces) {
      _split(face, splitting, distance, front, back, coplanar);
    }
    // Mặt phẳng phân vùng trùng một đầu khoảng: chuyển sang mặt thật để tiến.
    if (coplanar.isEmpty &&
        (front.length == faces.length || back.length == faces.length)) {
      final face = faces.first;
      for (var i = 1; i < face.points.length - 1; i++) {
        final n = (face.points[i] - face.points[0])
            .cross(face.points[i + 1] - face.points[0])
            .unit;
        if (n.length > .001) {
          splitting = n;
          distance = n.dot(face.points[0]);
          break;
        }
      }
      front.clear();
      back.clear();
      coplanar.clear();
      for (final face in faces) {
        _split(face, splitting, distance, front, back, coplanar);
      }
      if (coplanar.isEmpty) {
        return _GardenBsp(splitting, distance, faces, null, null);
      }
    }
    return _GardenBsp(
      splitting,
      distance,
      coplanar,
      build(front, depth + 1),
      build(back, depth + 1),
    );
  }

  static void _split(
    _WorldFace face,
    GardenVec3 n,
    double distance,
    List<_WorldFace> front,
    List<_WorldFace> back,
    List<_WorldFace> coplanar,
  ) {
    final distances = face.points.map((p) => n.dot(p) - distance).toList();
    const epsilon = .00002;
    final hasFront = distances.any((d) => d > epsilon);
    final hasBack = distances.any((d) => d < -epsilon);
    if (!hasFront && !hasBack) {
      coplanar.add(face);
      return;
    }
    if (!hasFront) {
      back.add(face);
      return;
    }
    if (!hasBack) {
      front.add(face);
      return;
    }
    final fp = <GardenVec3>[], bp = <GardenVec3>[];
    final fn = <GardenVec3>[], bn = <GardenVec3>[];
    for (var i = 0; i < face.points.length; i++) {
      final j = (i + 1) % face.points.length;
      final a = face.points[i],
          b = face.points[j],
          da = distances[i],
          db = distances[j];
      final normalA = face.normals?[i];
      if (da >= -epsilon) {
        fp.add(a);
        if (normalA != null) fn.add(normalA);
      }
      if (da <= epsilon) {
        bp.add(a);
        if (normalA != null) bn.add(normalA);
      }
      if ((da > epsilon && db < -epsilon) || (da < -epsilon && db > epsilon)) {
        final t = da / (da - db), point = a + (b - a) * t;
        fp.add(point);
        bp.add(point);
        if (normalA != null) {
          final normal = (normalA * (1 - t) + face.normals![j] * t).unit;
          fn.add(normal);
          bn.add(normal);
        }
      }
    }
    if (fp.length >= 3) {
      front.add(
        _WorldFace(fp, face.color, fn.isEmpty ? null : fn, face.closed),
      );
    }
    if (bp.length >= 3) {
      back.add(_WorldFace(bp, face.color, bn.isEmpty ? null : bn, face.closed));
    }
  }

  // Chỉ sao chép nhánh có cửa/đèn đi qua; cây tĩnh được dùng lại nguyên vẹn.
  _GardenBsp withMoving(List<_WorldFace> moving) {
    if (moving.isEmpty) return this;
    final ahead = <_WorldFace>[], behind = <_WorldFace>[], on = <_WorldFace>[];
    for (final face in moving) {
      _split(face, normal, distance, ahead, behind, on);
    }
    return _GardenBsp(
      normal,
      distance,
      on.isEmpty ? coplanar : [...coplanar, ...on],
      front?.withMoving(ahead) ?? build(ahead),
      back?.withMoving(behind) ?? build(behind),
    );
  }

  void order(GardenVec3 eye, List<_WorldFace> into) {
    final near = normal.dot(eye) >= distance;
    (near ? back : front)?.order(eye, into);
    into.addAll(coplanar);
    (near ? front : back)?.order(eye, into);
  }
}
