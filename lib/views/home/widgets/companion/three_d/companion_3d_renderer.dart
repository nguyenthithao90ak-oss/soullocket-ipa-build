import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'companion_3d_asset.dart';
import 'companion_3d_pose.dart';

part 'companion_3d_depth.dart';

/// Phép chiếu tùy chọn để đặt model có rig vào một thế giới 3D.
/// Giá trị depth lớn hơn ở gần camera hơn, null khi nằm sau mặt phẳng gần.
typedef Companion3DProjector =
    (Offset, double)? Function(double x, double y, double z);

/// Chiếu mesh 3D thật lên Canvas Flutter: rig phân cấp, quay theo quaternion,
/// loại mặt khuất, depth buffer và nội suy ánh sáng theo normal.
/// Dùng chung layer/clip/gesture của Flutter, không PlatformView hay WebView.
/// Đây là renderer riêng cho asset đồng hành; không phải engine glTF/PBR đầy đủ.
abstract final class Companion3DRenderer {
  static const units = 17.8;

  static int paint(
    Canvas canvas,
    Companion3DModel model,
    Companion3DPose pose, {
    required Map<String, String> variants,
    bool dark = false,
    Companion3DProjector? projector,
    Companion3DFrame? frame,
  }) {
    final count = model.nodes.length;
    final translations = [
      for (final n in model.nodes) List<double>.of(n.translation),
    ];
    final rotations = [
      for (final n in model.nodes) List<double>.of(n.rotation),
    ];
    final scales = [for (final n in model.nodes) List<double>.of(n.scale)];
    void clip(String name, double time, double weight) {
      if (weight <= .001) return;
      for (final c in model.clips[name] ?? const <Companion3DChannel>[]) {
        final t = time % c.times.last;
        var key = 0;
        while (key + 2 < c.times.length && c.times[key + 1] < t) {
          key++;
        }
        final width = c.property == 'rotation' ? 4 : 3;
        final span = c.times[key + 1] - c.times[key];
        final u = span > 0 ? ((t - c.times[key]) / span).clamp(0.0, 1.0) : 0.0;
        final a = c.values.sublist(key * width, (key + 1) * width);
        final b = c.values.sublist((key + 1) * width, (key + 2) * width);
        final value = c.property == 'rotation'
            ? _slerp(a, b, u)
            : [for (var k = 0; k < width; k++) a[k] + (b[k] - a[k]) * u];
        if (c.property == 'rotation') {
          rotations[c.node] = _slerp(rotations[c.node], value, weight);
        } else {
          final target = c.property == 'scale'
              ? scales[c.node]
              : translations[c.node];
          for (var k = 0; k < 3; k++) {
            target[k] += (value[k] - target[k]) * weight;
          }
        }
      }
    }

    clip('idle', pose.seconds, 1);
    clip('walk', pose.stride, pose.walk);
    clip('wave', (1 - pose.wave) * 1.49, pose.wave);
    clip('happy', pose.seconds, pose.happy * .28);
    clip(pose.yaw >= 0 ? 'holdR' : 'holdL', pose.seconds, pose.hold);
    clip('hug', .9, pose.hug);
    clip('eat', pose.seconds, pose.eat);
    clip('sleep', pose.seconds, pose.sleep);
    // Khi ngồi, hông hạ xuống và chân gập về phía trước; nội suy cùng ghế.
    final sit = pose.sit.clamp(0.0, 1.0);

    final matrices = List<_Transform?>.filled(count, null);
    final projected = <_Projected>[];
    final triangles = <_Triangle>[];
    final camera = _Transform.trs(
      [0, 0, 0],
      _quat(0, 1, 0, pose.yaw),
      [1, 1, 1],
    );
    final view = projector != null
        ? camera
        : _Transform.trs(
            [0, 0, 0],
            _quat(1, 0, 0, .055),
            [1, 1, 1],
          ).multiply(camera);
    for (var i = 0; i < count; i++) {
      final node = model.nodes[i];
      if (node.parent >= 0 && matrices[node.parent] == null) continue;
      if (node.slot != null) {
        if (variants[node.slot] != node.variant) continue;
        scales[i] = [1, 1, 1];
      }
      final name = node.name;
      if (name == 'torso') {
        translations[i][1] = pose.bodyBob / units - sit * .19;
        rotations[i] = _mul(rotations[i], _quat(1, 0, 0, sit * .08));
        translations[i][1] +=
            math.sin(pose.stride * math.pi * 4).abs() * .035 * pose.walk;
      } else if (name.startsWith('leg_')) {
        // Thân nhún nhưng chân trụ vẫn ở sàn; độ nhấc chân lấy từ clip walk.
        translations[i][1] -=
            translations[node.parent][1] / scales[node.parent][1];
        rotations[i] = _mul(rotations[i], _quat(1, 0, 0, sit * .78));
        translations[i][2] += sit * .12;
      } else if (name == 'head') {
        rotations[i] = _mul(
          rotations[i],
          _mul(
            _quat(0, 1, 0, pose.gaze.dx.clamp(-1.0, 1.0) * .20),
            _quat(1, 0, 0, -pose.gaze.dy.clamp(-1.0, 1.0) * .14),
          ),
        );
      } else if (name.startsWith('ear_') || name.startsWith('earTip_')) {
        final side = name.endsWith('L') ? -1 : 1;
        final tip = name.startsWith('earTip_');
        final swing =
            math.sin(pose.seconds * 1.6 + side * .7 - (tip ? .8 : 0)) * .025 +
            math.sin(pose.stride * math.pi * 2 - (tip ? .9 : .35)) *
                pose.walk *
                (tip ? .13 : .065);
        rotations[i] = _mul(rotations[i], _quat(0, 0, 1, swing));
      } else if (name.startsWith('eye_')) {
        final lid = variants['sleep'] == 'yes'
            ? 1.0
            : math.max(pose.blink, pose.happy * .16);
        scales[i][1] *= math.max(.025, 1 - lid);
      } else if (name.startsWith('pupil_')) {
        translations[i][0] += pose.gaze.dx.clamp(-1.0, 1.0) * .040;
        translations[i][1] += pose.gaze.dy.clamp(-1.0, 1.0) * .032;
      } else if (name == 'mouth') {
        final opening = math.max(pose.mouth, pose.happy * .32).clamp(0.0, 1.0);
        scales[i][1] = .65 + opening * 2.1;
        scales[i][0] = 1 + opening * .20;
      } else if (name.startsWith('muzzle_')) {
        scales[i][0] *= 1 + pose.eat * math.sin(pose.seconds * 13).abs() * .10;
      } else if (name.startsWith('brow_')) {
        final side = name.endsWith('L') ? -1 : 1;
        if (variants['angry'] == 'yes') {
          rotations[i] = _mul(rotations[i], _quat(0, 0, 1, side * .40));
        }
        if (variants['hungry'] == 'yes') {
          rotations[i] = _mul(rotations[i], _quat(0, 0, 1, side * -.28));
        }
      }
      final local = _Transform.trs(translations[i], rotations[i], scales[i]);
      final world = node.parent < 0
          ? view.multiply(local)
          : matrices[node.parent]!.multiply(local);
      matrices[i] = world;
    }
    // Tính đủ world transforms trước khi skin: xương khuỷu/tai có thể được
    // khai báo sau node chứa mesh trong GLB.
    for (var i = 0; i < count; i++) {
      final node = model.nodes[i];
      final world = matrices[i];
      if (world == null || node.mesh == null) continue;
      final mesh = model.meshes[node.mesh!];
      final material = model.materials[mesh.material];
      final skin = node.skin == null ? null : model.skins[node.skin!];
      final bones = skin == null
          ? null
          : [
              for (var j = 0; j < skin.joints.length; j++)
                matrices[skin.joints[j]]!.multiply(
                  _Transform.columnMajor(skin.inverseBind, j * 16),
                ),
            ];
      final p = _project(
        mesh,
        world,
        material,
        dark,
        bones: bones,
        projector: projector,
      );
      final group = projected.length;
      projected.add(p);
      for (var index = 0; index < mesh.indices.length; index += 3) {
        final a = mesh.indices[index],
            b = mesh.indices[index + 1],
            c = mesh.indices[index + 2];
        if (!p.z[a].isFinite || !p.z[b].isFinite || !p.z[c].isFinite) continue;
        final winding =
            (p.xy[b * 2] - p.xy[a * 2]) * (p.xy[c * 2 + 1] - p.xy[a * 2 + 1]) -
            (p.xy[b * 2 + 1] - p.xy[a * 2 + 1]) * (p.xy[c * 2] - p.xy[a * 2]);
        if (winding >= -.000001) continue;
        // Lớp vải ôm sát cần khoảng cách nhỏ để tránh z-fighting với lông
        // khi hai lưới dùng độ chia tam giác khác nhau.
        final bias = node.name.startsWith('pocket') ? .012 : 0.0;
        triangles.add(
          _Triangle(group, a, b, c, (p.z[a] + p.z[b] + p.z[c]) / 3 + bias),
        );
      }
    }
    if (frame == null) {
      _paintDepthBuffer(canvas, projected, triangles);
    } else {
      frame._append(projected, triangles);
    }
    return triangles.length;
  }

  static _Projected _project(
    Companion3DMesh mesh,
    _Transform transform,
    Companion3DMaterial material,
    bool dark, {
    List<_Transform>? bones,
    Companion3DProjector? projector,
  }) {
    final count = mesh.positions.length ~/ 3;
    final xy = Float32List(count * 2), z = Float32List(count);
    final colors = Int32List(count);
    final m = transform.m, n = transform.normalMatrix();
    final boneNormals = bones == null
        ? null
        : [for (final b in bones) b.normalMatrix()];
    for (var i = 0; i < count; i++) {
      final x = mesh.positions[i * 3],
          y = mesh.positions[i * 3 + 1],
          zz = mesh.positions[i * 3 + 2];
      final a = mesh.normals[i * 3],
          b = mesh.normals[i * 3 + 1],
          c = mesh.normals[i * 3 + 2];
      var px = 0.0, py = 0.0, pz = 0.0, nx = 0.0, ny = 0.0, nz = 0.0;
      if (bones == null) {
        px = m[0] * x + m[1] * y + m[2] * zz + m[3];
        py = m[4] * x + m[5] * y + m[6] * zz + m[7];
        pz = m[8] * x + m[9] * y + m[10] * zz + m[11];
        nx = n[0] * a + n[1] * b + n[2] * c;
        ny = n[3] * a + n[4] * b + n[5] * c;
        nz = n[6] * a + n[7] * b + n[8] * c;
      } else {
        for (var k = 0; k < 4; k++) {
          final at = i * 4 + k, weight = mesh.weights![at];
          if (weight <= 0) continue;
          final joint = mesh.joints![at].toInt();
          final m = bones[joint].m, n = boneNormals![joint];
          px += (m[0] * x + m[1] * y + m[2] * zz + m[3]) * weight;
          py += (m[4] * x + m[5] * y + m[6] * zz + m[7]) * weight;
          pz += (m[8] * x + m[9] * y + m[10] * zz + m[11]) * weight;
          nx += (n[0] * a + n[1] * b + n[2] * c) * weight;
          ny += (n[3] * a + n[4] * b + n[5] * c) * weight;
          nz += (n[6] * a + n[7] * b + n[8] * c) * weight;
        }
      }
      if (projector == null) {
        xy[i * 2] = px * units;
        xy[i * 2 + 1] = -py * units;
        z[i] = pz;
      } else {
        final projected = projector(px, py, pz);
        xy[i * 2] = projected?.$1.dx ?? 0;
        xy[i * 2 + 1] = projected?.$1.dy ?? 0;
        z[i] = projected?.$2 ?? double.negativeInfinity;
      }
      final length = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (length > .00001) {
        nx /= length;
        ny /= length;
        nz /= length;
      }
      final key = math.max(0.0, -nx * .43 + ny * .64 + nz * .635);
      final fill = math.max(0.0, nx * .76 + ny * .15 + nz * .63);
      final rim = math.pow(1 - math.max(0.0, nz), 3).toDouble() * .055;
      final diffuse = (dark ? .57 : .67) + key * .26 + fill * .08 + rim;
      final gloss = 1 - material.roughness;
      final spec =
          math
              .pow(
                math.max(0.0, -nx * .24 + ny * .36 + nz * .901),
                12 + gloss * 80,
              )
              .toDouble() *
          (.018 + gloss * .18);
      int channel(int k) {
        final warm = k == 0
            ? 1.015
            : k == 2
            ? .990
            : 1.0;
        final base = material.color[k] * (mesh.colors?[i * 4 + k] ?? 1);
        return ((base * diffuse * warm + spec) * 255).round().clamp(0, 255);
      }

      colors[i] = 0xff000000 | channel(0) << 16 | channel(1) << 8 | channel(2);
    }
    return _Projected(xy, z, colors);
  }
}

final class _Projected {
  const _Projected(this.xy, this.z, this.colors);
  final Float32List xy, z;
  final Int32List colors;
}

final class _Triangle {
  const _Triangle(this.group, this.a, this.b, this.c, this.depth);
  final int group, a, b, c;
  final double depth;
}

List<double> _quat(double x, double y, double z, double angle) => [
  x * math.sin(angle / 2),
  y * math.sin(angle / 2),
  z * math.sin(angle / 2),
  math.cos(angle / 2),
];
List<double> _mul(List<double> a, List<double> b) => [
  a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
  a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
  a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
  a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
];
List<double> _slerp(List<double> a, List<double> b, double t) {
  var dot = 0.0;
  for (var i = 0; i < 4; i++) {
    dot += a[i] * b[i];
  }
  final sign = dot < 0 ? -1.0 : 1.0;
  dot = dot.abs().clamp(0.0, 1.0);
  if (dot > .9995) {
    final result = [
      for (var i = 0; i < 4; i++) a[i] + (b[i] * sign - a[i]) * t,
    ];
    final length = math.sqrt(result.fold(0.0, (sum, v) => sum + v * v));
    return result.map((v) => v / length).toList();
  }
  final angle = math.acos(dot), denom = math.sin(angle);
  final wa = math.sin((1 - t) * angle) / denom,
      wb = math.sin(t * angle) / denom * sign;
  return [for (var i = 0; i < 4; i++) a[i] * wa + b[i] * wb];
}

final class _Transform {
  const _Transform(this.m);
  final List<double> m;
  factory _Transform.columnMajor(Float64List matrix, int at) => _Transform([
    matrix[at],
    matrix[at + 4],
    matrix[at + 8],
    matrix[at + 12],
    matrix[at + 1],
    matrix[at + 5],
    matrix[at + 9],
    matrix[at + 13],
    matrix[at + 2],
    matrix[at + 6],
    matrix[at + 10],
    matrix[at + 14],
  ]);
  factory _Transform.trs(List<double> t, List<double> q, List<double> s) {
    final x = q[0], y = q[1], z = q[2], w = q[3];
    return _Transform([
      (1 - 2 * y * y - 2 * z * z) * s[0],
      (2 * x * y - 2 * z * w) * s[1],
      (2 * x * z + 2 * y * w) * s[2],
      t[0],
      (2 * x * y + 2 * z * w) * s[0],
      (1 - 2 * x * x - 2 * z * z) * s[1],
      (2 * y * z - 2 * x * w) * s[2],
      t[1],
      (2 * x * z - 2 * y * w) * s[0],
      (2 * y * z + 2 * x * w) * s[1],
      (1 - 2 * x * x - 2 * y * y) * s[2],
      t[2],
    ]);
  }
  _Transform multiply(_Transform child) {
    final b = child.m, result = List.filled(12, 0.0);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        result[r * 4 + c] =
            m[r * 4] * b[c] + m[r * 4 + 1] * b[c + 4] + m[r * 4 + 2] * b[c + 8];
      }
      result[r * 4 + 3] =
          m[r * 4] * b[3] +
          m[r * 4 + 1] * b[7] +
          m[r * 4 + 2] * b[11] +
          m[r * 4 + 3];
    }
    return _Transform(result);
  }

  List<double> normalMatrix() {
    final a = m[0],
        b = m[1],
        c = m[2],
        d = m[4],
        e = m[5],
        f = m[6],
        g = m[8],
        h = m[9],
        i = m[10];
    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (det.abs() < 1e-12) return List.filled(9, 0);
    return [
      (e * i - f * h) / det,
      (f * g - d * i) / det,
      (d * h - e * g) / det,
      (c * h - b * i) / det,
      (a * i - c * g) / det,
      (b * g - a * h) / det,
      (b * f - c * e) / det,
      (c * d - a * f) / det,
      (a * e - b * d) / det,
    ];
  }
}

/// Gom cảnh và nhân vật vào cùng depth buffer để đồ vật che nhau đúng theo camera.
final class Companion3DFrame {
  final _projected = <_Projected>[];
  final _triangles = <_Triangle>[];

  void surface(List<(Offset, double)> points, Color color) {
    if (points.length < 3) return;
    final xy = Float32List(points.length * 2), z = Float32List(points.length);
    final colors = Int32List(points.length);
    for (var i = 0; i < points.length; i++) {
      xy[i * 2] = points[i].$1.dx;
      xy[i * 2 + 1] = points[i].$1.dy;
      z[i] = points[i].$2;
      colors[i] = color.toARGB32();
    }
    final group = _projected.length;
    _projected.add(_Projected(xy, z, colors));
    for (var i = 1; i + 1 < points.length; i++) {
      _triangles.add(
        _Triangle(group, 0, i, i + 1, (z[0] + z[i] + z[i + 1]) / 3),
      );
    }
  }

  void _append(List<_Projected> projected, List<_Triangle> triangles) {
    final offset = _projected.length;
    _projected.addAll(projected);
    for (final t in triangles) {
      _triangles.add(_Triangle(t.group + offset, t.a, t.b, t.c, t.depth));
    }
  }

  void paint(Canvas canvas, Rect bounds) =>
      _paintDepthBuffer(canvas, _projected, _triangles, sceneBounds: bounds);
}
