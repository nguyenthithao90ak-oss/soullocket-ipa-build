part of 'pet_care_garden_3d.dart';

class _ForestCluster {
  _ForestCluster(this.at, this.radius, this.mesh);
  final GardenVec3 at;
  final double radius;
  final _WorldMesh mesh;
}

/// Rừng xa không tham gia BSP của đồ vật trong sân. Mỗi view giữ buffer chiếu
/// riêng; chỉ dựng lại picture khi camera thay đổi, không theo nhịp bước chân.
class _GardenForest {
  final clusters = <_ForestCluster>[];
  _GardenForest() {
    for (var i = 0; i < 15; i++) {
      final angle = i * math.pi * 2 / 15;
      final at = GardenVec3(math.sin(angle) * 52, -1.2, math.cos(angle) * 52);
      final m = _WorldMesh();
      m.ellipsoid(
        at,
        GardenVec3(11 + i % 4.0, 5 + i % 3.0, 12),
        Color.lerp(
          const Color(0xFF94B8A1),
          const Color(0xFFB0C9AD),
          (i % 4) / 4,
        )!,
        sides: 12,
        rings: 4,
      );
      clusters.add(_ForestCluster(at, 16, m));
    }
    for (var layer = 0; layer < 3; layer++) {
      final count = [32, 44, 58][layer];
      for (var i = 0; i < count; i++) {
        final n = i + layer * 71;
        final angle =
            (i + .28 * math.sin(n * 3.7)) * math.pi * 2 / count + layer * .41;
        final distance = [14.0, 22.0, 35.0][layer] + 2.1 * math.sin(n * 2.3);
        final at = GardenVec3(
          math.sin(angle) * distance,
          -.02,
          math.cos(angle) * distance,
        );
        final scale =
            [1.6, 2.2, 3.0][layer] * (.85 + .30 * (1 + math.sin(n * 7.1)) / 2);
        final m = _WorldMesh();
        final leaf = Color.lerp(
          [
            const Color(0xFF4C845A),
            const Color(0xFF649473),
            const Color(0xFF83AC91),
          ][layer],
          [
            const Color(0xFF94B966),
            const Color(0xFF9DB980),
            const Color(0xFFA5C2A1),
          ][layer],
          (1 + math.sin(n * 2.71)) / 2,
        )!;
        // Bóng dưới tán cây nối thân cây với thảm đất.
        m.polygon(
          [
            for (var k = 0; k < 12; k++)
              at +
                  GardenVec3(
                    math.cos(k * math.pi / 6) * scale * .85,
                    .004,
                    math.sin(k * math.pi / 6) * scale * .7,
                  ),
          ],
          Color.lerp(
            const Color(0xFF8DA96D),
            const Color(0xFFA5BC83),
            layer / 3,
          )!,
          floor: true,
        );
        m.cylinder(
          at,
          .085 * scale,
          1.5 * scale,
          Color.lerp(const Color(0xFF8E7755), leaf, layer * .18)!,
          sides: 6,
          topRadius: .055 * scale,
        );
        if (layer == 0 || i % 3 == 0) {
          // Tán gần dùng khối tròn nhiều lớp, tránh cảm giác cây tam giác
          // phẳng khi camera đi ngang qua lối dạo.
          m.ellipsoid(
            at + GardenVec3(-.22 * scale, 1.55 * scale, .08 * scale),
            GardenVec3(.86 * scale, .70 * scale, .78 * scale),
            leaf,
            sides: 10,
            rings: 4,
          );
          m.ellipsoid(
            at + GardenVec3(.28 * scale, 1.86 * scale, -.08 * scale),
            GardenVec3(.74 * scale, .68 * scale, .72 * scale),
            Color.lerp(leaf, const Color(0xFFD1E39A), .18)!,
            sides: 10,
            rings: 4,
          );
          m.ellipsoid(
            at + GardenVec3(-.02 * scale, 2.20 * scale, .10 * scale),
            GardenVec3(.54 * scale, .54 * scale, .55 * scale),
            Color.lerp(leaf, Colors.white, .10)!,
            sides: 9,
            rings: 4,
          );
        } else if (i.isEven) {
          // Lớp giữa vẫn giữ silhouette đơn giản nhưng có vai tán bo mềm.
          m.ellipsoid(
            at + GardenVec3(0, 1.55 * scale, 0),
            GardenVec3(.98 * scale, .72 * scale, .90 * scale),
            leaf,
            sides: 9,
            rings: 3,
          );
          m.ellipsoid(
            at + GardenVec3(.10 * scale, 2.10 * scale, -.04 * scale),
            GardenVec3(.62 * scale, .58 * scale, .62 * scale),
            Color.lerp(leaf, const Color(0xFFC7D995), .14)!,
            sides: 9,
            rings: 3,
          );
        } else {
          for (var tier = 0; tier < 3; tier++) {
            m.cylinder(
              at + GardenVec3(0, (.65 + tier * .6) * scale, 0),
              (.83 - tier * .18) * scale,
              1.18 * scale,
              Color.lerp(leaf, const Color(0xFFC0D28A), tier * .09)!,
              sides: 8,
              topRadius: .025 * scale,
            );
          }
        }
        clusters.add(_ForestCluster(at, scale * 2.8, m));
      }
    }
  }
}

extension _GardenForestPainting on _GardenWorldPainter {
  void _surroundings(Canvas c, Size size) {
    final eye = camera.eye, forward = camera.forward, lens = camera.lens(size);
    // Mặt phẳng đất tiếp tục tới chân trời, không có mép tấm đất nổi.
    final horizon = size.height * .48 + lens * forward.y / camera.up.y;
    final top = horizon.clamp(0.0, size.height);
    if (top < size.height) {
      final rect = Rect.fromLTRB(0, top, size.width, size.height);
      c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB3C995), Color(0xFFA7C47D)],
          ).createShader(rect),
      );
    }
    // Mây và nắng có vị trí trong thế giới nên đổi hướng đúng theo camera.
    final sun = camera.project(const GardenVec3(-42, 28, -62), size);
    if (sun != null) {
      final r = lens * 4.8 / sun.$2;
      c.drawCircle(
        sun.$1,
        r * 2.5,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x66FFF3BF), Color(0x00FFF3BF)],
          ).createShader(Rect.fromCircle(center: sun.$1, radius: r * 2.5)),
      );
      c.drawCircle(sun.$1, r, Paint()..color = const Color(0xFFFFF1C2));
    }
    for (var i = 0; i < 11; i++) {
      final a = i * math.pi * 2 / 11;
      final p = camera.project(
        GardenVec3(math.sin(a) * 78, 20 + i % 3.0 * 3, math.cos(a) * 78),
        size,
      );
      if (p == null) continue;
      final scale = lens / p.$2;
      for (var j = 0; j < 3; j++) {
        c.drawOval(
          Rect.fromCenter(
            center: p.$1 + Offset((j - 1) * 3.2 * scale, -j % 2 * scale),
            width: 8 * scale,
            height: (2.4 + j % 2) * scale,
          ),
          Paint()..color = const Color(0xB3FAF9E8),
        );
      }
    }
    final flat = GardenVec3(forward.x, 0, forward.z).unit;
    final visible =
        cache.forest.clusters.where((cluster) {
          final delta = cluster.at - eye;
          if (delta.dot(forward) < -cluster.radius) return false;
          // Góc toàn cảnh mở bớt hàng cây phía trước camera để thấy được
          // ngôi nhà và hai bé giữa rừng.
          if (camera.mode != PetGardenViewMode.firstPerson &&
              cluster.at.dot(flat) < -2 - cluster.radius * .25) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) =>
              (b.at - eye).dot(forward).compareTo((a.at - eye).dot(forward)),
        );
    final faces = <_ScreenFace>[];
    for (final cluster in visible) {
      final projected = _project([
        ...cluster.mesh.ground,
        ...cluster.mesh.faces,
      ], size)..sort((a, b) => b.depth.compareTo(a.depth));
      faces.addAll(projected);
    }
    _gardenDrawMesh(c, faces);
  }
}

// Lối đi vòng quanh sân, hoa dại và góc nghỉ có hình học thật ở cùng mặt đất.
void _gardenMeadow(_WorldMesh m) {
  const path = Color(0xFFD4C69D);
  void ribbon(List<GardenVec3> points, double width) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1], delta = b - a;
      final side = GardenVec3(-delta.z, 0, delta.x).unit * (width / 2);
      m.polygon([a - side, b - side, b + side, a + side], path, floor: true);
    }
  }

  final loop = [
    for (var i = 0; i <= 96; i++)
      GardenVec3(
        math.cos(i * math.pi / 48) * (7.3 + .16 * math.sin(i * .4)),
        .008,
        math.sin(i * math.pi / 48) * (7.15 + .18 * math.cos(i * .5)),
      ),
  ];
  ribbon(loop, .9);
  ribbon(const [
    GardenVec3(.99, .01, 5),
    GardenVec3(.99, .01, 6.1),
    GardenVec3(1.4, .01, 7.04),
  ], 1.1);
  ribbon(const [
    GardenVec3(4.55, .01, .85),
    GardenVec3(5.8, .01, .85),
    GardenVec3(7.3, .01, .9),
  ], 1.1);
  for (var i = 0; i < 22; i++) {
    final a = i * math.pi / 11 + .12;
    final p = GardenVec3(math.cos(a) * 8.5, .03, math.sin(a) * 8.4);
    m.ellipsoid(
      p,
      GardenVec3(.18 + i % 3 * .07, .12, .21),
      i.isEven ? const Color(0xFFB0B59A) : const Color(0xFFC2C4A7),
      sides: 7,
      rings: 3,
    );
  }
  for (var i = 0; i < 100; i++) {
    final a = i * 2.39996;
    final d = 5.7 + (i * .719) % 3.4;
    final p = GardenVec3(math.cos(a) * d, .012, math.sin(a) * d);
    if (p.x.abs() < 5 && p.z.abs() < 5.5) continue;
    for (var j = 0; j < 3; j++) {
      final offset = GardenVec3(j * .055, 0, 0);
      m.polygon([
        p + offset - const GardenVec3(.035, 0, 0),
        p + offset + GardenVec3(.02, .12 + (i % 3) * .025, -.03),
        p + offset + const GardenVec3(.03, 0, .025),
      ], i.isEven ? const Color(0xFF8BAA66) : const Color(0xFF9AB971));
    }
    if (i % 3 != 0) continue;
    final h = .16 + (i % 4) * .025;
    final bloom = [
      const Color(0xFFF4DF91),
      const Color(0xFFE4B1B2),
      const Color(0xFFF7F3DA),
      const Color(0xFFBBA6CC),
    ][i % 4];
    for (var j = 0; j < 5; j++) {
      final angle = j * math.pi * 2 / 5;
      final at =
          p + GardenVec3(math.cos(angle) * .06, h, math.sin(angle) * .06);
      m.polygon([
        at + const GardenVec3(-.05, 0, 0),
        at + const GardenVec3(0, .02, -.05),
        at + const GardenVec3(.05, 0, 0),
        at + const GardenVec3(0, -.01, .05),
      ], bloom);
    }
  }
  // Tấm thảm dã ngoại và giỏ mây bên lối đi, giữ cảnh có điểm khám phá.
  m.box(
    const GardenVec3(5.6, .015, -4.4),
    const GardenVec3(1.25, .018, 1.4),
    const Color(0xFFEBDAB7),
    floor: true,
  );
  for (var i = 0; i < 6; i++) {
    m.box(
      GardenVec3(5.6 + i * .22, .037, -4.4),
      const GardenVec3(.07, .002, 1.4),
      const Color(0xFFCCAAA1),
      floor: true,
    );
    m.box(
      GardenVec3(5.6, .039, -4.4 + i * .24),
      const GardenVec3(1.25, .002, .07),
      const Color(0xFFCCAAA1),
      floor: true,
    );
  }
  m.cylinder(
    const GardenVec3(6.48, .04, -4.18),
    .19,
    .22,
    const Color(0xFFBE9B6D),
    sides: 9,
    topRadius: .23,
  );
  m.ellipsoid(
    const GardenVec3(5.9, .06, -3.5),
    const GardenVec3(.22, .07, .17),
    const Color(0xFF9AB29A),
    sides: 8,
    rings: 3,
  );
  for (final x in [.35, 1.65]) {
    m.box(
      GardenVec3(x - .06, 0, 5.04),
      const GardenVec3(.12, 1.65, .14),
      const Color(0xFFB89A70),
    );
    m.ellipsoid(
      GardenVec3(x, .12, 5.28),
      const GardenVec3(.31, .23, .28),
      const Color(0xFF7E9F67),
      sides: 9,
      rings: 4,
    );
    for (var j = 0; j < 3; j++) {
      m.ellipsoid(
        GardenVec3(x + (j - 1) * .13, .32, 5.3),
        const GardenVec3(.075, .06, .07),
        const Color(0xFFE5C29C),
        sides: 6,
        rings: 3,
      );
    }
  }
  m.box(
    const GardenVec3(.24, 1.64, 4.98),
    const GardenVec3(1.53, .16, .26),
    const Color(0xFFC9AE80),
  );
}
