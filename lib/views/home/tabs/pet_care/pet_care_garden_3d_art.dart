part of 'pet_care_garden_3d.dart';

class _WorldFace {
  _WorldFace(this.points, this.color, [this.normals, this.closed = false]);
  final List<GardenVec3> points;
  final Color color;
  final List<GardenVec3>? normals;
  final bool closed;
  late final GardenVec3 normal = _normal();
  late final GardenVec3 outward = normals == null
      ? normal * -1
      : normals!.reduce((a, b) => a + b).unit;
  late final List<Color> shades = _shades();
  late final _ScreenFace screen = _ScreenFace(points.length + 1);
  late final double outwardDistance = outward.dot(points.first);

  GardenVec3 _normal() {
    for (var i = 1; i < points.length - 1; i++) {
      final n = (points[i] - points[0]).cross(points[i + 1] - points[0]);
      if (n.length > .00001) return n.unit;
    }
    return const GardenVec3(0, 0, 0);
  }

  // Ánh sáng thuộc hình học, chỉ tính khi cây hoặc đồ vật đổi hình.
  List<Color> _shades() {
    final direction = const GardenVec3(-.55, .9, .65).unit;
    final fallback = normal.y < 0 ? normal * -1 : normal;
    Color shade(GardenVec3 n) {
      final light = .72 + math.max(0.0, n.dot(direction)) * .34;
      return Color.fromRGBO(
        (color.r * 255 * light).round().clamp(0, 255),
        (color.g * 255 * light).round().clamp(0, 255),
        (color.b * 255 * light).round().clamp(0, 255),
        1,
      );
    }

    if (normals == null) {
      return List.filled(points.length, shade(closed ? outward : fallback));
    }
    return normals!.map(shade).toList(growable: false);
  }
}

class _ScreenFace {
  _ScreenFace(int capacity)
    : coordinates = Float64List(capacity * 3),
      colors = List.filled(capacity, Colors.transparent);
  final Float64List coordinates;
  final List<Color> colors;
  int length = 0;
  Rect bounds = Rect.zero;
  double depth = 0;
  Offset point(int index) =>
      Offset(coordinates[index * 3], coordinates[index * 3 + 1]);
  double inverse(int index) => coordinates[index * 3 + 2];
}

class _WorldMesh {
  final ground = <_WorldFace>[], faces = <_WorldFace>[];
  void polygon(
    List<GardenVec3> p,
    Color color, {
    bool floor = false,
    bool closed = false,
  }) {
    (floor ? ground : faces).add(_WorldFace(p, color, null, closed));
  }

  void box(GardenVec3 at, GardenVec3 size, Color color, {bool floor = false}) {
    final x = at.x, z = at.z, y = at.y, w = size.x, h = size.y, d = size.z;
    final a = GardenVec3(x, y, z),
        b = GardenVec3(x + w, y, z),
        c = GardenVec3(x + w, y, z + d),
        e = GardenVec3(x, y, z + d);
    final aa = a + GardenVec3(0, h, 0),
        bb = b + GardenVec3(0, h, 0),
        cc = c + GardenVec3(0, h, 0),
        ee = e + GardenVec3(0, h, 0);
    if (floor) {
      polygon([aa, bb, cc, ee], color, floor: true);
      return;
    }
    polygon(
      [a, b, bb, aa],
      Color.lerp(color, Colors.black, .06)!,
      floor: floor,
      closed: true,
    );
    polygon(
      [b, c, cc, bb],
      Color.lerp(color, Colors.black, .13)!,
      floor: floor,
      closed: true,
    );
    polygon([c, e, ee, cc], color, floor: floor, closed: true);
    polygon(
      [e, a, aa, ee],
      Color.lerp(color, Colors.white, .04)!,
      floor: floor,
      closed: true,
    );
    polygon(
      [aa, bb, cc, ee],
      Color.lerp(color, Colors.white, .13)!,
      floor: floor,
      closed: true,
    );
  }

  void roundBox(
    GardenVec3 at,
    GardenVec3 size,
    Color color, {
    double corner = .08,
  }) {
    final radius = math.min(corner, math.min(size.x, size.z) * .45);
    final bevel = math.min(size.y * .32, radius * .35);
    final perimeter = <GardenVec3>[];
    for (var k = 0; k < 4; k++) {
      final cx = k == 0 || k == 3 ? at.x + size.x - radius : at.x + radius;
      final cz = k < 2 ? at.z + size.z - radius : at.z + radius;
      for (var j = 0; j <= 3; j++) {
        final angle = k * math.pi / 2 + j * math.pi / 6;
        perimeter.add(
          GardenVec3(
            cx + math.cos(angle) * radius,
            at.y,
            cz + math.sin(angle) * radius,
          ),
        );
      }
    }
    final center = at + GardenVec3(size.x * .5, 0, size.z * .5);
    final shoulder = perimeter
        .map((p) => p + GardenVec3(0, size.y - bevel, 0))
        .toList();
    final top = perimeter.map((p) {
      final inset = (center - p).unit * bevel;
      return p + inset + GardenVec3(0, size.y, 0);
    }).toList();
    for (var i = 0; i < perimeter.length; i++) {
      final j = (i + 1) % perimeter.length;
      final n = (perimeter[i] - center).unit;
      faces.add(
        _WorldFace(
          [perimeter[i], perimeter[j], shoulder[j], shoulder[i]],
          color,
          List.filled(4, n),
          true,
        ),
      );
      faces.add(
        _WorldFace(
          [shoulder[i], shoulder[j], top[j], top[i]],
          Color.lerp(color, Colors.white, .12)!,
          [
            n,
            n,
            (n + const GardenVec3(0, 1, 0)).unit,
            (n + const GardenVec3(0, 1, 0)).unit,
          ],
          true,
        ),
      );
    }
    faces.add(
      _WorldFace(
        top,
        Color.lerp(color, Colors.white, .16)!,
        List.filled(top.length, const GardenVec3(0, 1, 0)),
        true,
      ),
    );
  }

  void ellipsoid(
    GardenVec3 at,
    GardenVec3 radius,
    Color color, {
    int sides = 12,
    int rings = 6,
    bool floor = false,
  }) {
    GardenVec3 p(int row, int col) {
      final lat = -math.pi / 2 + math.pi * row / rings,
          a = math.pi * 2 * col / sides;
      return at +
          GardenVec3(
            math.cos(lat) * math.cos(a) * radius.x,
            math.sin(lat) * radius.y,
            math.cos(lat) * math.sin(a) * radius.z,
          );
    }

    for (var r = 0; r < rings; r++) {
      for (var s = 0; s < sides; s++) {
        final points = [p(r, s), p(r, s + 1), p(r + 1, s + 1), p(r + 1, s)];
        final normals = points.map((point) {
          final d = point - at;
          return GardenVec3(
            d.x / (radius.x * radius.x),
            d.y / (radius.y * radius.y),
            d.z / (radius.z * radius.z),
          ).unit;
        }).toList();
        (floor ? ground : faces).add(_WorldFace(points, color, normals, true));
      }
    }
  }

  void cylinder(
    GardenVec3 at,
    double r,
    double h,
    Color color, {
    int sides = 10,
    double? topRadius,
    bool floor = false,
  }) {
    final top = topRadius ?? r;
    final cap = <GardenVec3>[];
    for (var i = 0; i < sides; i++) {
      final a = i * math.pi * 2 / sides, b = (i + 1) * math.pi * 2 / sides;
      final p = at + GardenVec3(math.cos(a) * r, 0, math.sin(a) * r),
          q = at + GardenVec3(math.cos(b) * r, 0, math.sin(b) * r);
      final pp = at + GardenVec3(math.cos(a) * top, h, math.sin(a) * top),
          qq = at + GardenVec3(math.cos(b) * top, h, math.sin(b) * top);
      polygon([p, q, qq, pp], color, floor: floor, closed: true);
      cap.add(pp);
    }
    polygon(
      cap,
      Color.lerp(color, Colors.white, .1)!,
      floor: floor,
      closed: true,
    );
  }

  void leaf(GardenVec3 at, double angle, double s, Color color) {
    final dir = GardenVec3(math.cos(angle), .6, math.sin(angle));
    final side = GardenVec3(-math.sin(angle), 0, math.cos(angle));
    polygon([
      at,
      at + dir * (s * .55) + side * (s * .25),
      at + dir * s,
      at + dir * (s * .55) - side * (s * .25),
    ], color);
  }

  /// Một cụm hoa nhỏ dùng cho các điểm nhìn gần. Các cánh được dựng thành
  /// mặt phẳng mỏng thay vì ảnh bitmap để vẫn nhận được ánh sáng của cảnh.
  void flower(GardenVec3 at, Color color, {double scale = 1}) {
    cylinder(at, .012 * scale, .18 * scale, const Color(0xFF6B9252), sides: 5);
    final center = at + GardenVec3(0, .18 * scale, 0);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      final petal =
          center +
          GardenVec3(
            math.cos(a) * .075 * scale,
            math.sin(i * 2.2) * .012 * scale,
            math.sin(a) * .075 * scale,
          );
      ellipsoid(
        petal,
        GardenVec3(.055 * scale, .025 * scale, .042 * scale),
        color,
        sides: 6,
        rings: 3,
      );
    }
    ellipsoid(
      center + GardenVec3(0, .01 * scale, 0),
      GardenVec3(.032 * scale, .025 * scale, .032 * scale),
      const Color(0xFFF2C667),
      sides: 6,
      rings: 3,
    );
  }

  /// Đèn dây tạo điểm sáng ở hiên mà không cần texture hay shader riêng.
  void stringLight(GardenVec3 at, Color color, {double scale = 1}) {
    cylinder(at, .025 * scale, .08 * scale, const Color(0xFF6F5A4A), sides: 6);
    ellipsoid(
      at + GardenVec3(0, -.02 * scale, 0),
      GardenVec3(.065 * scale, .09 * scale, .065 * scale),
      color,
      sides: 7,
      rings: 3,
    );
  }

  void crop(GardenVec3 at, PetGardenCrop crop, double growth, bool ripe) {
    if (crop == PetGardenCrop.apple) {
      tree(at, .30 + growth * .7, fruit: ripe);
      return;
    }
    final s = .35 + growth * .65;
    final h =
        (crop == PetGardenCrop.sunflower
            ? .88
            : crop == PetGardenCrop.tomato
            ? .54
            : .24) *
        s;
    cylinder(at, .022, h, const Color(0xFF638B42), sides: 5);
    for (var i = 0; i < 4; i++) {
      leaf(
        at + GardenVec3(0, h * .3, 0),
        i * math.pi / 2,
        .32 * s,
        const Color(0xFF82A45B),
      );
    }
    if (crop == PetGardenCrop.carrot) {
      if (growth > .4) {
        cylinder(
          at + const GardenVec3(0, -.04, 0),
          .03,
          .25 * s,
          const Color(0xFFE5A25E),
          topRadius: .095 * s,
          sides: 7,
        );
      }
      for (var i = 0; i < 5; i++) {
        leaf(
          at + const GardenVec3(0, .1, 0),
          i * math.pi * 2 / 5,
          .35 * s,
          const Color(0xFF729E4E),
        );
      }
    } else if (crop == PetGardenCrop.sunflower && growth > .35) {
      final head = at + GardenVec3(0, h, 0);
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi * 2 / 9;
        ellipsoid(
          head + GardenVec3(math.cos(a) * .12 * s, math.sin(a) * .12 * s, 0),
          GardenVec3(.07 * s, .09 * s, .03),
          const Color(0xFFF5D773),
          sides: 5,
          rings: 3,
        );
      }
      ellipsoid(
        head + const GardenVec3(0, 0, .025),
        GardenVec3(.10 * s, .10 * s, .045),
        const Color(0xFF9B784D),
        sides: 8,
        rings: 3,
      );
    } else if (growth > .4) {
      for (var i = 0; i < 3; i++) {
        final p =
            at +
            GardenVec3(
              (i - 1) * .12 * s,
              .16 * s + i % 2 * .10,
              math.sin(i * 2) * .10,
            );
        ellipsoid(
          p,
          GardenVec3(
            .085 * s,
            crop == PetGardenCrop.strawberry ? .11 * s : .085 * s,
            .075 * s,
          ),
          ripe
              ? (crop == PetGardenCrop.strawberry
                    ? const Color(0xFFDF8D86)
                    : const Color(0xFFE5A07F))
              : const Color(0xFFA9BA76),
          sides: 7,
          rings: 4,
        );
        leaf(p + GardenVec3(0, .08 * s, 0), .2, .12, const Color(0xFF648B4D));
      }
    }
  }

  void tree(GardenVec3 at, double s, {bool fruit = false}) {
    cylinder(
      at,
      .09 * s,
      1.25 * s,
      const Color(0xFFA0825B),
      topRadius: .06 * s,
      sides: 8,
    );
    ellipsoid(
      at + GardenVec3(-.25 * s, 1.36 * s, 0),
      GardenVec3(.5 * s, .46 * s, .44 * s),
      const Color(0xFF71A65E),
    );
    ellipsoid(
      at + GardenVec3(.25 * s, 1.43 * s, 0),
      GardenVec3(.49 * s, .49 * s, .46 * s),
      const Color(0xFF82B76D),
    );
    ellipsoid(
      at + GardenVec3(0, 1.8 * s, 0),
      GardenVec3(.48 * s, .48 * s, .44 * s),
      const Color(0xFF9AC57C),
    );
    if (fruit) {
      for (var i = 0; i < 7; i++) {
        final a = i * math.pi * 2 / 7;
        ellipsoid(
          at +
              GardenVec3(
                math.cos(a) * .44 * s,
                (1.45 + math.sin(i * 3) * .24) * s,
                math.sin(a) * .42 * s,
              ),
          GardenVec3(.10 * s, .10 * s, .10 * s),
          const Color(0xFFDF937A),
          sides: 7,
          rings: 4,
        );
      }
    }
  }
}

class _GardenWorldPainter extends CustomPainter {
  _GardenWorldPainter({
    required this.cache,
    required this.camera,
    required this.progress,
    required this.now,
    required this.frame,
    required this.pets,
    required this.heading,
    required this.lamp,
    required this.window,
    required this.sit,
    required this.seated,
    required this.animate,
    required this.wateringPlot,
    required this.actionPlot,
    required this.actionPhase,
  }) : super(repaint: Listenable.merge([camera, frame, lamp, window, sit]));
  final _GardenRenderCache cache;
  final PetGardenCamera camera;
  final PetCareProgress progress;
  final DateTime now;
  final ValueNotifier<double> frame;
  final List<HomeCompanionMotion> pets;
  final double Function(int) heading;
  final Animation<double> lamp, window;
  final Animation<double> sit;
  final bool seated, animate;
  final int? wateringPlot;
  final int? actionPlot;
  final PetGardenActionPhase? actionPhase;
  static _WorldMesh? _environment;
  static _WorldMesh _buildEnvironment() {
    final m = _WorldMesh();
    _gardenMeadow(m);
    const cream = Color(0xFFFFF0D4),
        wood = Color(0xFFBB885C),
        roof = Color(0xFFF18470);
    // Mặt đất liền mạch, bỏ lưới ô vuông kiểu prototype. Các mảng cỏ
    // không đều tạo vật liệu mềm và chiều sâu mà không cần texture CPU.
    m.box(
      const GardenVec3(-11, -.06, -13),
      const GardenVec3(22, .045, 26),
      const Color(0xFF83C870),
      floor: true,
    );
    for (var i = 0; i < 58; i++) {
      final a = i * 2.39996,
          d = 1.8 + (i * .917) % 8.8,
          p = GardenVec3(math.cos(a) * d, .004, math.sin(a) * d);
      if (p.x.abs() < 4.3 && p.z.abs() < 4.8) continue;
      final w = .22 + (i % 4) * .08, h = .12 + (i % 3) * .05;
      m.polygon(
        [
          p + GardenVec3(-w, 0, -h),
          p + GardenVec3(w * .8, 0, -h * .55),
          p + GardenVec3(w, 0, h),
          p + GardenVec3(-w * .65, 0, h * .72),
        ],
        i.isEven ? const Color(0xFF7FC366) : const Color(0xFF94D578),
        floor: true,
      );
    }
    // Bóng tiếp xúc lớn dưới nhà và cụm luống, giúp khối không còn bay trên
    // mặt cỏ khi camera hạ thấp xuống ngang tầm nhân vật.
    m.ellipsoid(
      const GardenVec3(-1.05, .002, -2.65),
      const GardenVec3(3.9, .012, 2.15),
      const Color(0xFF6CA95F),
      sides: 22,
      rings: 2,
      floor: true,
    );
    // Đường lát đá thấp và từng phiến đá nổi.
    m.box(
      const GardenVec3(.66, .002, -.95),
      const GardenVec3(.65, .015, 6.1),
      const Color(0xFFDEC7A3),
      floor: true,
    );
    for (final z in [1.15, 2.75, 4.35]) {
      m.box(
        GardenVec3(-3.6, .003, z - .22),
        const GardenVec3(5, .018, .45),
        const Color(0xFFDEC7A3),
        floor: true,
      );
      for (var x = -3.45; x < 1.5; x += .61) {
        m.cylinder(
          GardenVec3(x, .025, z),
          .24,
          .035,
          const Color(0xFFFFF0CF),
          sides: 8,
          floor: true,
        );
      }
    }
    for (var z = -.7; z < 5.1; z += .52) {
      m.cylinder(
        GardenVec3(.99, .022, z),
        .24,
        .04,
        const Color(0xFFFFF0CF),
        sides: 8,
        floor: true,
      );
    }
    m.box(
      const GardenVec3(-1.72, .003, -1.15),
      const GardenVec3(2.7, .02, .62),
      const Color(0xFFEEDABD),
      floor: true,
    );
    // Ao sau nhà với vành đá, lá súng.
    m.ellipsoid(
      const GardenVec3(2.9, .005, -2.05),
      const GardenVec3(1.22, .035, .92),
      const Color(0xFFA2B5A1),
      floor: true,
    );
    m.ellipsoid(
      const GardenVec3(2.9, .04, -2.05),
      const GardenVec3(1.07, .03, .79),
      const Color(0xFF57BFCA),
      floor: true,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi * 2 / 12;
      m.ellipsoid(
        GardenVec3(2.9 + math.cos(a) * 1.15, .08, -2.05 + math.sin(a) * .84),
        const GardenVec3(.16, .10, .12),
        const Color(0xFFCED9C4),
        sides: 7,
        rings: 3,
      );
    }
    m.cylinder(
      const GardenVec3(3.32, .09, -1.83),
      .20,
      .008,
      const Color(0xFF5EAE7D),
      sides: 9,
    );
    m.ellipsoid(
      const GardenVec3(3.33, .13, -1.83),
      const GardenVec3(.08, .045, .08),
      const Color(0xFFF4AFB2),
      sides: 7,
      rings: 3,
    );
    // Ngôi nhà có bốn mặt và mái hai dốc.
    m.box(
      const GardenVec3(-3.6, 0, -4.4),
      const GardenVec3(5, 2.6, 3.3),
      cream,
    );
    m.box(
      const GardenVec3(-3.64, 0, -4.44),
      const GardenVec3(5.08, .22, 3.38),
      const Color(0xFFB6C6A7),
    );
    for (var y = .4; y < 2.55; y += .31) {
      m.box(
        GardenVec3(-3.58, y, -1.088),
        const GardenVec3(4.96, .015, .02),
        const Color(0xFFE9D9B9),
      );
      m.box(
        GardenVec3(1.405, y, -4.38),
        const GardenVec3(.015, .015, 3.24),
        const Color(0xFFDEC5A2),
      );
    }
    m.polygon(const [
      GardenVec3(-3.8, 2.58, -.9),
      GardenVec3(-1.1, 3.95, -.9),
      GardenVec3(-1.1, 3.95, -4.6),
      GardenVec3(-3.8, 2.58, -4.6),
    ], roof);
    m.polygon(const [
      GardenVec3(-1.1, 3.95, -.9),
      GardenVec3(1.6, 2.58, -.9),
      GardenVec3(1.6, 2.58, -4.6),
      GardenVec3(-1.1, 3.95, -4.6),
    ], const Color(0xFFC6685D));
    m.polygon(const [
      GardenVec3(-3.6, 2.6, -1.09),
      GardenVec3(1.4, 2.6, -1.09),
      GardenVec3(-1.1, 3.87, -1.09),
    ], const Color(0xFFFFEBCD));
    m.polygon(const [
      GardenVec3(-3.6, 2.6, -4.41),
      GardenVec3(1.4, 2.6, -4.41),
      GardenVec3(-1.1, 3.87, -4.41),
    ], const Color(0xFFEEDBB8));
    // Viền mái, xà gỗ và hiên tạo độ dày cho ngôi nhà khi xoay camera.
    m.box(
      const GardenVec3(-3.82, 2.50, -1.24),
      const GardenVec3(5.24, .14, .16),
      const Color(0xFFA45E51),
    );
    m.box(
      const GardenVec3(-3.80, .10, -1.30),
      const GardenVec3(5.20, .12, .18),
      const Color(0xFFB9835F),
    );
    for (final x in [-3.45, -1.10, 1.18]) {
      m.box(
        GardenVec3(x, .22, -1.34),
        const GardenVec3(.12, 2.22, .13),
        const Color(0xFFD1A271),
      );
    }
    // Mái hiên nhỏ trước cửa, có đầu hồi bo mềm bằng các lớp ellipsoid.
    m.roundBox(
      const GardenVec3(-2.35, 2.18, -1.02),
      const GardenVec3(2.5, .12, .96),
      const Color(0xFFCF7664),
    );
    m.polygon(const [
      GardenVec3(-2.48, 2.30, .05),
      GardenVec3(-1.10, 2.72, .05),
      GardenVec3(-1.10, 2.72, -1.10),
      GardenVec3(-2.48, 2.30, -1.10),
    ], const Color(0xFFF49C80));
    m.polygon(const [
      GardenVec3(-1.10, 2.72, .05),
      GardenVec3(.28, 2.30, .05),
      GardenVec3(.28, 2.30, -1.10),
      GardenVec3(-1.10, 2.72, -1.10),
    ], const Color(0xFFD87465));
    m.polygon(const [
      GardenVec3(-2.35, 2.30, .048),
      GardenVec3(-1.10, 2.65, .048),
      GardenVec3(.15, 2.30, .048),
    ], const Color(0xFFFFE9C6));
    for (final x in [-2.12, -1.76, -1.40, -1.04, -.68, -.32]) {
      m.stringLight(
        GardenVec3(x, 2.23, -.05),
        const Color(0xFFFFD58D),
        scale: .62,
      );
    }
    for (var i = 0; i < 7; i++) {
      final t = i / 7, x = -3.8 + t * 2.7, h = 2.6 + t * 1.37;
      m.box(
        GardenVec3(x, h, -4.62),
        const GardenVec3(.026, .025, 3.76),
        const Color(0xFFFFA18A),
      );
      m.box(
        GardenVec3(1.6 - t * 2.7, h, -4.62),
        const GardenVec3(.025, .025, 3.76),
        const Color(0xFFE78A72),
      );
    }
    m.box(
      const GardenVec3(.35, 3.05, -3.9),
      const GardenVec3(.48, 1.13, .48),
      const Color(0xFFBBA087),
    );
    m.box(
      const GardenVec3(.27, 4.12, -3.98),
      const GardenVec3(.64, .14, .64),
      const Color(0xFFD7BA9A),
    );
    // Cửa, bậc và cửa sổ nhìn vào bên trong.
    m.box(
      const GardenVec3(-1.86, .12, -1.125),
      const GardenVec3(1.16, 2.03, .1),
      wood,
    );
    m.box(
      const GardenVec3(-1.75, .17, -1.01),
      const GardenVec3(.94, 1.85, .045),
      const Color(0xFF3B9B8E),
    );
    // Cửa có nẹp, tay nắm và ô kính tròn để nhìn rõ khi ở gần.
    m.box(
      const GardenVec3(-1.84, .20, -1.155),
      const GardenVec3(1.12, .07, .08),
      const Color(0xFFD8B27D),
    );
    m.box(
      const GardenVec3(-1.84, 2.03, -1.155),
      const GardenVec3(1.12, .07, .08),
      const Color(0xFFD8B27D),
    );
    m.box(
      const GardenVec3(-1.80, .20, -1.16),
      const GardenVec3(.06, 1.80, .07),
      const Color(0xFFD8B27D),
    );
    m.box(
      const GardenVec3(-.78, .20, -1.16),
      const GardenVec3(.06, 1.80, .07),
      const Color(0xFFD8B27D),
    );
    m.box(
      const GardenVec3(-1.64, 1.15, -.96),
      const GardenVec3(.72, .65, .025),
      const Color(0xFF90D5D7),
    );
    m.ellipsoid(
      const GardenVec3(-.95, 1.02, -.92),
      const GardenVec3(.055, .055, .055),
      const Color(0xFFF1D9A0),
      sides: 7,
      rings: 4,
    );
    m.ellipsoid(
      const GardenVec3(-1.33, 1.57, -.91),
      const GardenVec3(.20, .20, .03),
      const Color(0xFFF4D8A1),
      sides: 8,
      rings: 4,
    );
    for (var j = 0; j < 3; j++) {
      m.box(
        GardenVec3(-2.0 - j * .1, .02 + j * .07, -.77 - j * .18),
        GardenVec3(1.44 + j * .2, .08, .34),
        const Color(0xFFD6C6A7),
      );
    }
    for (final x in [-2.67, .63]) {
      m.box(
        GardenVec3(x - .5, 1.02, -1.13),
        const GardenVec3(1, 1.02, .13),
        wood,
      );
      m.box(
        GardenVec3(x - .43, 1.09, -.98),
        const GardenVec3(.86, .87, .025),
        const Color(0xFF64B8C1),
      );
      m.box(
        GardenVec3(x - .025, 1.08, -.935),
        const GardenVec3(.05, .9, .035),
        cream,
      );
      m.box(
        GardenVec3(x - .44, 1.49, -.93),
        const GardenVec3(.9, .05, .035),
        cream,
      );
      m.box(
        GardenVec3(x - .57, .86, -1.15),
        const GardenVec3(1.14, .20, .34),
        const Color(0xFFC19272),
      );
      // Bồn hoa gắn tường với chậu có vành sáng và hoa nhỏ nhiều màu.
      m.box(
        GardenVec3(x - .52, .80, -1.34),
        const GardenVec3(1.04, .18, .25),
        const Color(0xFFE3C58F),
      );
      for (var j = 0; j < 5; j++) {
        m.ellipsoid(
          GardenVec3(x - .42 + j * .21, 1.05, -.90),
          const GardenVec3(.14, .13, .11),
          const Color(0xFF62AB72),
          sides: 6,
          rings: 3,
        );
        m.ellipsoid(
          GardenVec3(x - .42 + j * .21, 1.17, -.89),
          const GardenVec3(.07, .05, .06),
          const Color(0xFFF49CAA),
          sides: 6,
          rings: 3,
        );
        m.flower(
          GardenVec3(x - .42 + j * .21, .98, -1.36),
          j.isEven ? const Color(0xFFF5C0A7) : const Color(0xFFBCA6D8),
          scale: .56,
        );
      }
    }
    m.box(const GardenVec3(1.42, 1, -3.6), const GardenVec3(.04, 1, 1), wood);
    m.box(
      const GardenVec3(1.47, 1.08, -3.52),
      const GardenVec3(.02, .84, .84),
      const Color(0xFF64B8C1),
    );
    // Ghế gỗ có chân và tựa; đèn đứng có thân chụp.
    for (final x in [-3.7, -2.7]) {
      for (final z in [-.72, -.36]) {
        m.box(
          GardenVec3(x, 0, z),
          const GardenVec3(.07, .44, .07),
          const Color(0xFF8D7455),
        );
      }
    }
    for (var j = 0; j < 3; j++) {
      m.box(
        GardenVec3(-3.85, .46, -.8 + j * .18),
        const GardenVec3(1.4, .07, .14),
        wood,
      );
    }
    for (var j = 0; j < 3; j++) {
      m.box(
        GardenVec3(-3.85, .65 + j * .14, -.79),
        const GardenVec3(1.4, .09, .07),
        wood,
      );
    }
    m.roundBox(
      const GardenVec3(-3.72, .56, -.78),
      const GardenVec3(1.15, .10, .38),
      const Color(0xFFF6AC99),
    );
    m.roundBox(
      const GardenVec3(-3.68, .69, -.77),
      const GardenVec3(.42, .10, .12),
      const Color(0xFFFFE7BD),
    );
    m.roundBox(
      const GardenVec3(-2.78, .69, -.77),
      const GardenVec3(.42, .10, .12),
      const Color(0xFFFFE7BD),
    );
    m.cylinder(
      const GardenVec3(-4.1, 0, -.45),
      .22,
      .055,
      const Color(0xFFB1A17A),
    );
    m.cylinder(
      const GardenVec3(-4.1, .05, -.45),
      .035,
      1.8,
      const Color(0xFF9B8867),
    );
    m.ellipsoid(
      const GardenVec3(-4.1, 1.86, -.45),
      const GardenVec3(.33, .07, .33),
      const Color(0xFFFFDB9A),
      sides: 9,
      rings: 3,
    );
    // Bảng chỉ dẫn nhỏ tạo điểm nhận diện khi camera lùi xa.
    m.box(
      const GardenVec3(2.02, 0, 1.80),
      const GardenVec3(.08, 1.05, .08),
      const Color(0xFF9D7956),
    );
    m.box(
      const GardenVec3(1.72, .74, 1.76),
      const GardenVec3(.70, .36, .08),
      const Color(0xFFE7C991),
    );
    m.box(
      const GardenVec3(1.80, .82, 1.68),
      const GardenVec3(.54, .05, .025),
      const Color(0xFFD69C7B),
    );
    m.box(
      const GardenVec3(1.96, .98, 1.68),
      const GardenVec3(.22, .05, .025),
      const Color(0xFFD69C7B),
    );
    // Hàng rào 3D quanh sân.
    for (var i = 0; i < 21; i++) {
      final x = -4.8 + i * .48;
      for (final z in [-5.1, 5.1]) {
        if (z > 0 && x > .28 && x < 1.72) continue;
        m.box(
          GardenVec3(x, 0, z),
          const GardenVec3(.09, .65, .09),
          const Color(0xFFFFF0D1),
        );
      }
    }
    for (var i = 0; i < 22; i++) {
      for (final x in [-4.8, 4.7]) {
        final z = -5.1 + i * .48;
        if (x > 0 && z > -.05 && z < 1.75) continue;
        m.box(
          GardenVec3(x, 0, -5.1 + i * .48),
          const GardenVec3(.09, .65, .09),
          const Color(0xFFFFF0D1),
        );
      }
    }
    for (final y in [.23, .46]) {
      for (final z in [-5.06, 5.12]) {
        for (final span
            in z < 0 ? [(-4.8, 9.6)] : [(-4.8, 5.15), (1.65, 3.15)]) {
          m.box(
            GardenVec3(span.$1, y, z),
            GardenVec3(span.$2, .06, .05),
            const Color(0xFFE7CBA1),
          );
        }
      }
      for (final x in [-4.76, 4.73]) {
        for (final span
            in x < 0 ? [(-5.1, 10.25)] : [(-5.1, 5.2), (1.7, 3.45)]) {
          m.box(
            GardenVec3(x, y, span.$1),
            GardenVec3(.05, .06, span.$2),
            const Color(0xFFE7CBA1),
          );
        }
      }
    }
    for (final p in [
      const GardenVec3(-4.3, 0, -3.4),
      const GardenVec3(3.9, 0, -4.5),
      const GardenVec3(-4.3, 0, 3.8),
    ]) {
      m.tree(p, 1.2);
    }
    for (var i = 0; i < 14; i++) {
      final a = i * 2.37;
      final p = GardenVec3(
        -3.25 + math.cos(a) * 1.8,
        .02,
        -.42 + math.sin(a) * .92,
      );
      m.flower(
        p,
        i.isEven ? const Color(0xFFF4B7A8) : const Color(0xFFBDA8D8),
        scale: .68 + (i % 3) * .12,
      );
    }
    return m;
  }

  _WorldMesh _plants() {
    final m = _WorldMesh();
    for (var i = 0; i < 9; i++) {
      final at = GardenVec3.fromMap(PetGardenMap.plots[i]);
      final plant = progress.garden.plots[i], bed = i < 6;
      if (bed) {
        m.roundBox(
          at + const GardenVec3(-.83, 0, -.54),
          const GardenVec3(1.66, .15, 1.08),
          const Color(0xFFCF9A63),
        );
        m.roundBox(
          at + const GardenVec3(-.74, .14, -.45),
          const GardenVec3(1.48, .035, .90),
          plant?.wateredAt != null
              ? const Color(0xFF77513C)
              : const Color(0xFFAA7950),
        );
        for (var j = 0; j < 3; j++) {
          m.box(
            at + GardenVec3(-.65, .18, -.29 + j * .28),
            const GardenVec3(1.3, .006, .015),
            const Color(0xFF8C613F),
          );
        }
      } else {
        m.cylinder(at, .45, .04, const Color(0xFF7EAD63), sides: 12);
      }
      if (plant != null) {
        if (bed) {
          for (var j = -1; j <= 1; j++) {
            m.crop(
              at + GardenVec3(j * .45, .19, j.isEven ? .1 : -.07),
              plant.crop,
              plant.growth(now),
              plant.ready(now),
            );
          }
        } else {
          m.crop(at, plant.crop, plant.growth(now), plant.ready(now));
        }
      } else {
        m.box(
          at + GardenVec3(bed ? .55 : .25, .12, -.35),
          const GardenVec3(.035, .38, .035),
          const Color(0xFFB98450),
        );
        m.box(
          at + GardenVec3(bed ? .43 : .13, .37, -.36),
          const GardenVec3(.28, .18, .04),
          const Color(0xFFEADDB7),
        );
      }
    }
    return m;
  }

  _WorldMesh _fixtures() {
    final m = _WorldMesh();
    // Hai cánh quay quanh bản lề, giữ kính và khung cửa ở phía sau.
    final angle = window.value * 2.05;
    for (final side in [-1.0, 1.0]) {
      final hinge = GardenVec3(side < 0 ? -3.17 : -2.17, 1.08, -.92);
      final end =
          hinge +
          GardenVec3(-side * .49 * math.cos(angle), 0, .49 * math.sin(angle));
      m.polygon([
        hinge,
        end,
        end + const GardenVec3(0, .92, 0),
        hinge + const GardenVec3(0, .92, 0),
      ], const Color(0xFF91AB91));
      for (var j = 1; j < 6; j++) {
        final a = hinge + GardenVec3(0, j * .145, .006),
            b = end + GardenVec3(0, j * .145, .006);
        m.polygon([
          a,
          b,
          b + const GardenVec3(0, .025, 0),
          a + const GardenVec3(0, .025, 0),
        ], const Color(0xFF7E987D));
      }
    }
    m.cylinder(
      const GardenVec3(-4.1, 1.68, -.45),
      .29,
      .35,
      Color.lerp(const Color(0xFFE8D8AE), const Color(0xFFFFD58E), lamp.value)!,
      topRadius: .18,
    );
    if (lamp.value > .001) {
      m.ellipsoid(
        const GardenVec3(-4.1, .012, -.45),
        const GardenVec3(.7, .008, .68),
        Color.lerp(
          const Color(0xFFAEC58A),
          const Color(0xFFEADDAB),
          lamp.value,
        )!,
        sides: 18,
        rings: 3,
      );
      m.ellipsoid(
        const GardenVec3(-4.1, 1.75, -.45),
        const GardenVec3(.22, .13, .22),
        const Color(0xFFFFD99D),
        sides: 9,
        rings: 4,
      );
    }
    return m;
  }

  _WorldMesh _water() {
    final m = _WorldMesh();
    // Bình nước nằm trong tay khi tưới, giọt rơi xuống đúng luống.
    if (wateringPlot case final id?) {
      final at = GardenVec3.fromMap(PetGardenMap.plots[id]);
      m.cylinder(
        at + const GardenVec3(.55, .6, .42),
        .13,
        .23,
        const Color(0xFF82ADB1),
        sides: 9,
      );
      m.box(
        at + const GardenVec3(.19, .67, .35),
        const GardenVec3(.32, .055, .075),
        const Color(0xFF96BCBE),
      );
      for (var j = 0; j < 8; j++) {
        final t = (frame.value * 1.4 + j / 8) % 1;
        m.ellipsoid(
          at + GardenVec3(.19 - t * .18, .69 - t * .49, .37 + j % 3 * .045),
          const GardenVec3(.018, .038, .018),
          const Color(0xFFBDDDE0),
          sides: 5,
          rings: 3,
        );
      }
    }
    return m;
  }

  List<_ScreenFace> _project(List<_WorldFace> faces, Size size) {
    final result = <_ScreenFace>[];
    final eye = camera.eye, forward = camera.forward;
    final right = camera.right, up = camera.up, lens = camera.lens(size);
    final originX = size.width / 2, originY = size.height * .48;
    final eyeDepth = eye.dot(forward),
        eyeRight = eye.dot(right),
        eyeUp = eye.dot(up);
    for (final face in faces) {
      if (face.normal.length < .001) continue;
      if (face.closed && face.outward.dot(eye) <= face.outwardDistance) {
        continue;
      }
      final screen = face.screen, coordinates = screen.coordinates;
      screen.length = 0;
      var minX = double.infinity, minY = double.infinity;
      var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      var sumDepth = 0.0;
      void add(double x, double y, double depth, Color color) {
        final index = screen.length++, at = index * 3;
        coordinates[at] = x;
        coordinates[at + 1] = y;
        coordinates[at + 2] = 1 / depth;
        screen.colors[index] = color;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        sumDepth += depth;
      }

      // Ghi vào buffer thuộc mặt, dùng lại khi camera đổi để giảm cấp phát/GC.
      for (var i = 0; i < face.points.length; i++) {
        final j = (i + 1) % face.points.length;
        final p = face.points[i], q = face.points[j];
        final da = p.dot(forward) - eyeDepth;
        final db = q.dot(forward) - eyeDepth;
        if (da >= .10) {
          final inverse = 1 / da;
          add(
            originX + (p.dot(right) - eyeRight) * lens * inverse,
            originY - (p.dot(up) - eyeUp) * lens * inverse,
            da,
            face.shades[i],
          );
        }
        if ((da >= .10) != (db >= .10)) {
          final t = (da - .10) / (da - db), cut = p + (q - p) * t;
          add(
            originX + (cut.dot(right) - eyeRight) * lens * 10,
            originY - (cut.dot(up) - eyeUp) * lens * 10,
            .10,
            Color.lerp(face.shades[i], face.shades[j], t)!,
          );
        }
      }
      if (screen.length < 3 ||
          maxX < 0 ||
          minX > size.width ||
          maxY < 0 ||
          minY > size.height) {
        continue;
      }
      screen.bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      screen.depth = sumDepth / screen.length;
      result.add(screen);
    }
    return result;
  }

  void _pet(Canvas c, Size size, int i) {
    final pet = PetCarePet.values[i], vitals = progress.vitalsFor(pet);
    if (vitals.sleeping) return;
    final motion = pets[i];
    final canSit =
        seated &&
        i == 0 &&
        motion.phase != HomeCompanionPhase.walking &&
        (motion.position - const Offset(165, 465)).distance < 35;
    final sitting = canSit ? sit.value : 0.0;
    final base = GardenVec3.fromMap(motion.position, sitting * .48);
    final projected = camera.project(base, size);
    if (projected == null || projected.$2 < .4) return;
    final growth = petCareGrowth(progress.bondPoints).clamp(.7, 1.15) * 1.16;
    final pixels = camera.lens(size) / projected.$2 * growth;
    final feet = projected.$1;
    final bounds = Rect.fromLTRB(
      feet.dx - .72 * pixels,
      feet.dy - 2.05 * pixels,
      feet.dx + .72 * pixels,
      feet.dy + .25 * pixels,
    );
    if (!bounds.overlaps(Offset.zero & size)) return;
    final avatar = _GardenAvatar(
      camera: camera,
      size: size,
      origin: base,
      yaw: sitting > .5 ? 0 : heading(i),
      scale: growth,
    );
    avatar.build(
      bear: i == 1,
      motion: motion,
      care: vitals,
      outfit: progress.outfitFor(pet),
      animate: animate,
      sitting: sitting,
      tending: actionPlot != null && i == 0
          ? (actionPhase == PetGardenActionPhase.contact ? 1.0 : .35)
          : 0,
    );
    c.saveLayer(bounds, Paint());
    c.clipRect(bounds);
    c.drawOval(
      Rect.fromCenter(
        center: feet + Offset(0, pixels * .015),
        width: .62 * pixels,
        height: .17 * pixels,
      ),
      Paint()
        ..color = const Color(0x38466D48)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pixels * .04),
    );
    avatar.paint(c);
    c.drawPath(
      cache.petMask(i, bounds, base, camera, size),
      Paint()..blendMode = BlendMode.clear,
    );
    c.restore();
  }

  void _premiumAtmosphere(Canvas c, Size size) {
    final lens = camera.lens(size);
    // Vùng sáng của đèn có lan ra mặt sân và vật thể xung quanh.
    if (lamp.value > .001) {
      final light = camera.project(const GardenVec3(-4.1, 1.75, -.45), size);
      if (light != null) {
        final radius = (lens * .62 / light.$2).clamp(18.0, 180.0).toDouble();
        c.drawCircle(
          light.$1,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.fromRGBO(255, 220, 147, .22 * lamp.value),
                const Color(0x00FFDA9A),
              ],
            ).createShader(Rect.fromCircle(center: light.$1, radius: radius)),
        );
      }
    }
    // Hạt sáng nhỏ chuyển động theo thời gian tạo nhịp sống ở lớp xa.
    if (animate) {
      final tick = frame.value;
      for (var i = 0; i < 14; i++) {
        final a = i * 2.17 + tick * (.16 + i % 3 * .025);
        final world = GardenVec3(
          math.cos(a) * (4.2 + i % 4 * .65),
          .55 + (i % 5) * .18 + math.sin(a * 1.7) * .08,
          math.sin(a) * (3.6 + i % 3 * .7),
        );
        final projected = camera.project(world, size);
        if (projected == null || projected.$2 < .5) continue;
        final alpha = (.24 + .16 * math.sin(tick * 2.4 + i))
            .clamp(.06, .42)
            .toDouble();
        final radius = (lens / projected.$2 * .012).clamp(.8, 2.8).toDouble();
        c.drawCircle(
          projected.$1,
          radius,
          Paint()..color = Color.fromRGBO(255, 232, 155, alpha),
        );
      }
    }
    // Vignette rất nhẹ để điểm nhìn nằm ở nhà và hai bé, không che chi tiết.
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.05),
          radius: 1.05,
          colors: [Color(0x000A2B2A), Color(0x240A2B2A)],
          stops: [0.58, 1],
        ).createShader(Offset.zero & size),
    );
  }

  void _actionIndicator(Canvas c, Size size) {
    final plot = actionPlot;
    final phase = actionPhase;
    if (plot == null ||
        phase == null ||
        plot < 0 ||
        plot >= PetGardenMap.plots.length) {
      return;
    }
    final projected = camera.project(
      GardenVec3.fromMap(PetGardenMap.plots[plot], .035),
      size,
    );
    if (projected == null) return;
    final tick = frame.value;
    final phaseIndex = phase.index;
    final pulse = .5 + .5 * math.sin(tick * 7.0);
    final radius = (camera.lens(size) / projected.$2 * (.22 + pulse * .025))
        .clamp(7.0, 44.0)
        .toDouble();
    final color = switch (phase) {
      PetGardenActionPhase.preparing => const Color(0xFFE9C47A),
      PetGardenActionPhase.contact => const Color(0xFF8CC7A0),
      PetGardenActionPhase.finishing => const Color(0xFFDCA48E),
    };
    c.drawCircle(
      projected.$1,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * .09).clamp(1.2, 4.0).toDouble()
        ..color = color.withValues(alpha: .28 + pulse * .16),
    );
    final sweep = math.pi * (.7 + phaseIndex * .5) + pulse * .32;
    c.drawArc(
      Rect.fromCircle(center: projected.$1, radius: radius * 1.28),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (radius * .11).clamp(1.4, 4.5).toDouble()
        ..color = color.withValues(alpha: .72),
    );
  }

  void _livingWorldAccents(Canvas c, Size size) {
    if (!animate) return;
    final tick = frame.value;
    final lens = camera.lens(size);

    // Mặt ao có gợn nước thật theo nhịp, giúp nền không đứng im như ảnh.
    final pond = camera.project(const GardenVec3(2.9, .09, -2.05), size);
    if (pond != null) {
      for (var i = 0; i < 3; i++) {
        final t = (tick * (.24 + i * .06) + i / 3) % 1;
        final radius = (lens / pond.$2 * (.20 + t * .42))
            .clamp(4.0, 40.0)
            .toDouble();
        c.drawOval(
          Rect.fromCenter(
            center: pond.$1 + Offset(0, t * 1.8),
            width: radius * 2.3,
            height: radius * .72,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1.3 - t * .7).clamp(.45, 1.3).toDouble()
            ..color = const Color(0xFFEDF5D3).withValues(alpha: (1 - t) * .32),
        );
      }
    }

    // Hạt bụi sáng bay theo vòng nhỏ ở tiền cảnh; chuyển động lệch pha tạo
    // cảm giác gió và chiều sâu, thay cho các vật thể tĩnh xếp hàng.
    for (var i = 0; i < 9; i++) {
      final a = tick * (.25 + i % 3 * .08) + i * 1.91;
      final world = GardenVec3(
        -4.6 + (i % 5) * 2.1 + math.sin(a * 1.3) * .35,
        .35 + (i % 4) * .24 + math.sin(a) * .08,
        1.4 + (i % 3) * 1.55 + math.cos(a * .9) * .22,
      );
      final p = camera.project(world, size);
      if (p == null || p.$2 < .5) continue;
      final r = (lens / p.$2 * .018).clamp(.7, 3.2).toDouble();
      c.drawCircle(
        p.$1,
        r,
        Paint()..color = const Color(0xFFFFE6A2).withValues(alpha: .24),
      );
    }
  }

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF69C6E5), Color(0xFFB3E5DD), Color(0xFFEAF1CE)],
          stops: [0, .56, 1],
        ).createShader(Offset.zero & size),
    );
    final eye = camera.eye, forward = camera.forward;
    final growthKey = Object.hashAll(
      progress.garden.plots.entries.map(
        (entry) => (
          entry.key,
          entry.value.crop,
          (entry.value.growth(now) * 60).floor(),
          entry.value.ready(now),
          entry.value.wateredAt != null,
        ),
      ),
    );
    final key = (
      size,
      eye.x,
      eye.y,
      eye.z,
      forward.x,
      forward.y,
      forward.z,
      growthKey,
      lamp.value,
      window.value,
    );
    cache.prepare(
      key,
      () {
        final ordered = cache.orderWorld(
          growthKey,
          () {
            final environment = _environment ??= _buildEnvironment();
            final plants = _plants();
            // Buffer chiếu thuộc riêng view; mesh môi trường gốc chỉ giữ hình học.
            return [
              for (final face in [...environment.ground, ...environment.faces])
                _WorldFace(face.points, face.color, face.normals, face.closed),
              ...plants.faces,
            ];
          },
          eye,
          (lamp.value, window.value),
          () => _fixtures().faces,
        );
        return _project(ordered, size);
      },
      size,
      background: (canvas) => _surroundings(canvas, size),
    );
    c.drawPicture(cache.picture!);
    _premiumAtmosphere(c, size);
    _livingWorldAccents(c, size);
    _actionIndicator(c, size);
    final order = List.generate(pets.length, (i) => i)
      ..sort((a, b) {
        final da = (GardenVec3.fromMap(pets[a].position) - eye).dot(forward);
        final db = (GardenVec3.fromMap(pets[b].position) - eye).dot(forward);
        return db.compareTo(da);
      });
    for (final i in order) {
      _pet(c, size, i);
    }
    if (wateringPlot != null) {
      final water = _project(_water().faces, size);
      final base = GardenVec3.fromMap(PetGardenMap.plots[wateringPlot!]);
      final bounds = water.fold<Rect>(
        Rect.zero,
        (bounds, face) => bounds.expandToInclude(face.bounds),
      );
      c.saveLayer(bounds, Paint());
      _gardenDrawMesh(c, water..sort((a, b) => b.depth.compareTo(a.depth)));
      c.drawPath(
        _gardenOcclusion(cache.faces, bounds, base, camera, size),
        Paint()..blendMode = BlendMode.clear,
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_GardenWorldPainter old) => true;
}
