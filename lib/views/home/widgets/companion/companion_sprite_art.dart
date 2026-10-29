import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'home_companion_metrics.dart';

/// Ảnh Thỏ/Gấu 3D mềm (PNG/WebP nền trong suốt) vẽ thay hình GLB khi đã nạp.
///
/// Ảnh đặt trong hệ tọa độ của painter: chân ở (0, 0), miệng ngang
/// [HomeCompanionMetrics.modelMouthY], nên đồ ăn, thư và hiệu ứng của
/// Home/Trạm Mây vẫn rơi đúng chỗ như với mô hình 3D.
@immutable
class CompanionSpriteSpec {
  const CompanionSpriteSpec(
    this.asset, {
    required this.feet,
    required this.mouthY,
    this.side = false,
    this.fit = 1,
    this.eyes = const [],
    this.eyeRadius = Size.zero,
    this.lidColor = const Color(0x00000000),
    this.sourceSize = const Size(1254, 1254),
    this.rig,
  });

  /// Tâm hai mắt và bán kính vùng mắt (pixel ảnh gốc) để vẽ mí khi chớp.
  final List<Offset> eyes;
  final Size eyeRadius;

  /// Màu lông ngay trên mắt, dùng làm mí mắt.
  final Color lidColor;

  /// Thu nhỏ thêm khi bé bè ngang hơn mô hình cũ, để vẫn nằm trong lề ngang
  /// 32dp quanh chân của Home lúc nghiêng người.
  final double fit;

  final String asset;

  /// Ảnh nhìn ngang quay sang phải; lật gương khi bé quay sang trái.
  final bool side;

  /// Giữa hai bàn chân trong ảnh gốc, đơn vị pixel.
  final Offset feet;

  /// Tâm miệng trong ảnh gốc; dùng để cân cỡ ảnh khớp miệng mô hình 3D.
  final double mouthY;
  final Size sourceSize;

  /// Khung xương để uốn ảnh khi cử động; thiếu thì ảnh chỉ nhún cả thân.
  final CompanionSpriteRig? rig;

  double get unitsPerPixel =>
      -HomeCompanionMetrics.modelMouthY / (feet.dy - mouthY) * fit;
}

/// Một bộ phận xoay quanh khớp (tai, tay, đuôi), đo bằng pixel ảnh gốc.
@immutable
class SpriteLimb {
  const SpriteLimb(
    this.pivot,
    this.tip, {
    this.radius = 60,
    this.feather = 30,
    this.side = 1,
    this.outer,
  });

  final Offset pivot, tip;

  /// Nửa bề ngang bộ phận và dải chuyển mềm sang phần thân đứng yên.
  final double radius, feather;

  /// Nửa bề ngang phía ngoài thân (xa giữa người). Phía ngoài chỉ có nền
  /// trong suốt nên lấy rộng để cả bàn tay xoay liền khối, không răng cưa.
  final double? outer;

  /// Chiều xoay ứng với "vẫy ra ngoài": tai/tay trái và phải ngược nhau.
  final double side;
}

/// Khung xương của một ảnh: ảnh được chia lưới rồi uốn theo khớp, nên tai,
/// đầu, tay, chân và miệng cử động riêng mà không cần thêm ảnh.
@immutable
class CompanionSpriteRig {
  const CompanionSpriteRig({
    required this.content,
    required this.neck,
    required this.hipY,
    required this.legSplit,
    required this.mouth,
    required this.mouthSize,
    this.neckBand = 36,
    this.ears = const [],
    this.arms = const [],
    this.tail,
  });

  /// Vùng có hình trong ảnh gốc; chỉ chia lưới trong vùng này.
  final Rect content;

  /// Khớp cổ: đầu nghiêng quanh điểm này, dải [neckBand] nối mềm với thân.
  final Offset neck;
  final double neckBand;

  /// Tai và tay theo thứ tự trái, phải trong ảnh; ảnh nhìn ngang chỉ một tay.
  final List<SpriteLimb> ears, arms;
  final SpriteLimb? tail;

  /// Từ [hipY] xuống chân nhấc theo bước; [legSplit] chia chân trái/phải.
  final double hipY, legSplit;

  /// Vùng miệng được kéo giãn/khép lại khi há miệng, nhai.
  final Offset mouth;
  final Size mouthSize;
}

/// Tư thế từng bộ phận trong một khung hình.
@immutable
class CompanionSpriteMotion {
  const CompanionSpriteMotion({
    this.head = 0,
    this.headDrop = 0,
    this.earLeft = 0,
    this.earRight = 0,
    this.armLeft = 0,
    this.armRight = 0,
    this.liftLeft = 0,
    this.liftRight = 0,
    this.strideLeft = 0,
    this.strideRight = 0,
    this.tail = 0,
    this.mouth = 1,
  });

  /// Nghiêng đầu (radian, dương theo chiều kim đồng hồ) và lún đầu xuống
  /// (pixel ảnh gốc).
  final double head, headDrop;

  /// Tai/tay vẫy ra ngoài, radian.
  final double earLeft, earRight, armLeft, armRight;

  /// Nhấc chân lên và bước tới (pixel ảnh gốc).
  final double liftLeft, liftRight, strideLeft, strideRight;
  final double tail;

  /// Độ há miệng: 1 như ảnh, nhỏ hơn là khép, lớn hơn là há to.
  final double mouth;
}

double _smooth(double from, double to, double x) {
  final t = ((x - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

Offset _rotate(Offset point, Offset center, double angle) {
  if (angle == 0) return point;
  final sin = math.sin(angle), cos = math.cos(angle);
  final d = point - center;
  return center + Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);
}

final class CompanionSprite {
  CompanionSprite._(this.spec, this.image, [List<Color>? lids])
    : lids = lids ?? [for (final _ in spec.eyes) spec.lidColor];

  final CompanionSpriteSpec spec;
  final ui.Image image;

  /// Màu mí từng mắt, lấy trung bình lông ngay phía trên mắt khi nạp ảnh.
  final List<Color> lids;

  static final _paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  /// Đổi tọa độ pixel ảnh gốc sang đơn vị painter (chân là gốc).
  Offset local(Offset pixel) => (pixel - spec.feet) * spec.unitsPerPixel;

  /// Điểm ảnh gốc sau khi uốn theo [motion], đổi sang tọa độ painter.
  Offset place(Offset pixel, CompanionSpriteMotion? motion) =>
      motion == null || spec.rig == null
      ? local(pixel)
      : local(deform(pixel, motion));

  void paint(
    Canvas canvas, {
    bool flip = false,
    CompanionSpriteMotion? motion,
  }) {
    canvas.save();
    if (flip) canvas.scale(-1, 1);
    if (spec.rig == null || motion == null) {
      final u = spec.unitsPerPixel;
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          -spec.feet.dx * u,
          -spec.feet.dy * u,
          spec.sourceSize.width * u,
          spec.sourceSize.height * u,
        ),
        _paint,
      );
    } else {
      _paintMesh(canvas, motion);
      _paintMouth(canvas, motion);
    }
    canvas.restore();
  }

  /// Uốn một điểm ảnh gốc: tai cong theo gốc tai, tay/đuôi xoay quanh khớp,
  /// chân nhấc theo bước, rồi cả đầu (kèm tai) nghiêng quanh cổ.
  Offset deform(Offset p, CompanionSpriteMotion m) {
    final rig = spec.rig!;
    var q = p;
    for (var i = 0; i < rig.ears.length; i++) {
      final amount = i == 0 ? m.earLeft : m.earRight;
      if (amount == 0) continue;
      final ear = rig.ears[i];
      final axis = ear.tip - ear.pivot;
      final rel = p - ear.pivot;
      final lengthSq = axis.distanceSquared;
      final s = (rel.dx * axis.dx + rel.dy * axis.dy) / lengthSq;
      if (s <= 0) continue;
      final lateral =
          (rel.dx * axis.dy - rel.dy * axis.dx).abs() / math.sqrt(lengthSq);
      final w = 1 - _smooth(ear.radius, ear.radius + ear.feather, lateral);
      if (w <= 0) continue;
      // Càng xa gốc càng cong, như tai mềm phất theo nhịp.
      final bend = _smooth(0, .5, s) * math.min(s, 1.25);
      q = _rotate(q, ear.pivot, ear.side * amount * w * bend);
    }
    for (var i = 0; i < rig.arms.length; i++) {
      final amount = i == 0 ? m.armLeft : m.armRight;
      if (amount != 0) q = _turnLimb(p, q, rig.arms[i], amount);
    }
    final tail = rig.tail;
    if (tail != null && m.tail != 0) q = _turnLimb(p, q, tail, m.tail);
    final legs = _smooth(
      rig.hipY,
      rig.hipY + (spec.feet.dy - rig.hipY) * .75,
      p.dy,
    );
    if (legs > 0) {
      final left = 1 - _smooth(rig.legSplit - 14, rig.legSplit + 14, p.dx);
      q += Offset(
        (m.strideLeft * left + m.strideRight * (1 - left)) * legs,
        -(m.liftLeft * left + m.liftRight * (1 - left)) * legs,
      );
    }
    final head =
        1 -
        _smooth(rig.neck.dy - rig.neckBand, rig.neck.dy + rig.neckBand, p.dy);
    if (head > 0) {
      q = _rotate(q, rig.neck, m.head * head) + Offset(0, m.headDrop * head);
    }
    return q;
  }

  Offset _turnLimb(Offset p, Offset q, SpriteLimb limb, double amount) {
    final axis = limb.tip - limb.pivot;
    final rel = p - limb.pivot;
    final s = (rel.dx * axis.dx + rel.dy * axis.dy) / axis.distanceSquared;
    final along = _smooth(-.4, .1, s);
    if (along <= 0) return q;
    final nearest = limb.pivot + axis * s.clamp(0.0, 1.0);
    final inner = (p.dx - nearest.dx) * (spec.feet.dx - nearest.dx) > 0;
    final radius = inner ? limb.radius : limb.outer ?? limb.radius;
    // Má/cằm cạnh vai thuộc về đầu, không bị tay kéo theo.
    final rig = spec.rig!;
    final body = _smooth(
      rig.neck.dy - rig.neckBand,
      rig.neck.dy + rig.neckBand,
      p.dy,
    );
    final w =
        along *
        body *
        (1 - _smooth(radius, radius + limb.feather, (p - nearest).distance));
    return w <= 0 ? q : _rotate(q, limb.pivot, limb.side * amount * w);
  }

  // Lưới chia vùng có hình, mỗi ô khoảng 23–27 pixel ảnh gốc.
  static const _cols = 30;
  late final Rect _content = spec.rig!.content;
  late final int _rows = math.max(
    8,
    (_content.height / _content.width * _cols).round(),
  );
  late final List<Offset> _grid = [
    for (var r = 0; r <= _rows; r++)
      for (var c = 0; c <= _cols; c++)
        Offset(
          _content.left + _content.width * c / _cols,
          _content.top + _content.height * r / _rows,
        ),
  ];
  late final Float32List _uv = () {
    final sx = image.width / spec.sourceSize.width;
    final sy = image.height / spec.sourceSize.height;
    final uv = Float32List(_grid.length * 2);
    for (var i = 0; i < _grid.length; i++) {
      uv[i * 2] = _grid[i].dx * sx;
      uv[i * 2 + 1] = _grid[i].dy * sy;
    }
    return uv;
  }();
  late final Uint16List _indices = () {
    final out = <int>[];
    const row = _cols + 1;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final at = r * row + c;
        out.addAll([at, at + 1, at + row, at + 1, at + row + 1, at + row]);
      }
    }
    return Uint16List.fromList(out);
  }();
  late final Paint _texture = Paint()
    ..isAntiAlias = true
    ..shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList(const [
        1, 0, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]),
      filterQuality: FilterQuality.medium,
    );

  void _paintMesh(Canvas canvas, CompanionSpriteMotion motion) {
    final u = spec.unitsPerPixel;
    final positions = Float32List(_grid.length * 2);
    for (var i = 0; i < _grid.length; i++) {
      final q = deform(_grid[i], motion);
      positions[i * 2] = (q.dx - spec.feet.dx) * u;
      positions[i * 2 + 1] = (q.dy - spec.feet.dy) * u;
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: _uv,
      indices: _indices,
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, _texture);
    vertices.dispose();
  }

  static final _mouthMask = Paint()
    ..blendMode = BlendMode.dstIn
    ..shader = ui.Gradient.radial(
      Offset.zero,
      1,
      const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
      const [0, .7, 1],
    );

  /// Há/khép miệng: vẽ lại vùng miệng kéo giãn theo chiều dọc, giữ mép trên
  /// như hàm dưới hạ xuống, viền hòa mềm vào lông xung quanh.
  void _paintMouth(Canvas canvas, CompanionSpriteMotion motion) {
    final rig = spec.rig!;
    final open = motion.mouth.clamp(.45, 1.45);
    if ((open - 1).abs() < .02) return;
    final u = spec.unitsPerPixel;
    final w = rig.mouthSize.width * u, h = rig.mouthSize.height * u;
    final sx = image.width / spec.sourceSize.width;
    final sy = image.height / spec.sourceSize.height;
    final center = place(rig.mouth, motion);
    final area = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(motion.head);
    canvas.clipRect(area);
    canvas.saveLayer(area, Paint());
    const anchor = .3;
    canvas.drawImageRect(
      image,
      Rect.fromCenter(
        center: Offset(rig.mouth.dx * sx, rig.mouth.dy * sy),
        width: rig.mouthSize.width * sx,
        height: rig.mouthSize.height * sy,
      ),
      Rect.fromLTWH(-w / 2, -h / 2 + h * anchor * (1 - open), w, h * open),
      _paint,
    );
    canvas.scale(w / 2, h / 2);
    canvas.drawRect(const Rect.fromLTRB(-1.1, -1.1, 1.1, 1.1), _mouthMask);
    canvas.restore();
    canvas.restore();
  }

  static final _lash = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.5;

  /// Mí mắt khép theo [amount] 0 → 1 trên ảnh mặt trước: chớp mắt, ngủ.
  /// Mí đặt theo mắt sau khi đầu nghiêng/lún theo [motion]; mép mí mờ dần
  /// vào lông xung quanh để không thành miếng tròn dán lên mặt.
  void paintBlink(
    Canvas canvas,
    double amount, [
    CompanionSpriteMotion? motion,
  ]) {
    if (amount <= .02 || spec.eyes.isEmpty) return;
    final u = spec.unitsPerPixel;
    final cover = math.min(amount, 1.0);
    _lash.color = const Color(
      0xFF3B2620,
    ).withValues(alpha: ((cover - .55) / .45).clamp(0.0, 1.0));
    const soft = 1.16; // mí rộng hơn mắt, phần thừa là viền mờ
    for (var i = 0; i < spec.eyes.length; i++) {
      final center = place(spec.eyes[i], motion);
      final rx = spec.eyeRadius.width * u, ry = spec.eyeRadius.height * u;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(motion?.head ?? 0);
      canvas.save();
      canvas.scale(rx * soft, ry * soft);
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 1)),
      );
      final lid = lids[i];
      canvas.drawRect(
        Rect.fromLTRB(-1, -1, 1, (-1 + 2 * cover) / soft + .02),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            [lid, lid, lid.withValues(alpha: 0)],
            const [0, .87, 1],
          ),
      );
      canvas.restore();
      if (cover > .55) {
        // Mắt nhắm là một nét cong xuống như đang cười híp.
        final y = -ry + ry * 2 * .58;
        canvas.drawPath(
          Path()
            ..moveTo(-rx * .72, y - ry * .08)
            ..quadraticBezierTo(0, y + ry * .32, rx * .72, y - ry * .08),
          _lash,
        );
      }
      canvas.restore();
    }
  }

  /// Trung bình màu lông trên vòng cung phía trên mắt, bỏ lông mày/mi tối
  /// và nền trong suốt. Không đọc được thì giữ [CompanionSpriteSpec.lidColor].
  static List<Color>? _sampleLids(
    CompanionSpriteSpec spec,
    ui.Image image,
    ByteData? pixels,
  ) {
    if (pixels == null || spec.eyes.isEmpty) return null;
    final sx = image.width / spec.sourceSize.width;
    final sy = image.height / spec.sourceSize.height;
    return [
      for (final eye in spec.eyes)
        () {
          var r = 0.0, g = 0.0, b = 0.0, n = 0;
          for (var a = math.pi - .2; a <= math.pi * 2 + .2; a += .08) {
            for (final f in const [1.14, 1.22, 1.3]) {
              final x =
                  ((eye.dx + math.cos(a) * spec.eyeRadius.width * f) * sx)
                      .round();
              final y =
                  ((eye.dy + math.sin(a) * spec.eyeRadius.height * f) * sy)
                      .round();
              if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
                continue;
              }
              final at = (y * image.width + x) * 4;
              final pr = pixels.getUint8(at), pg = pixels.getUint8(at + 1);
              final pb = pixels.getUint8(at + 2), pa = pixels.getUint8(at + 3);
              if (pa < 230 || pr * .3 + pg * .59 + pb * .11 < 110) continue;
              r += pr;
              g += pg;
              b += pb;
              n++;
            }
          }
          return n < 8
              ? spec.lidColor
              : Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
        }(),
    ];
  }
}

final class CompanionSpriteAssets extends ChangeNotifier {
  CompanionSpriteAssets._();
  static final instance = CompanionSpriteAssets._();

  /// Tắt để quay về hình 3D cũ khi cần đối chiếu.
  static bool enabled = true;

  /// Giải mã nhỏ hơn ảnh gốc 1254px: đủ nét cho Trạm Mây phóng 1,3× trên
  /// màn 3x, mỗi ảnh còn khoảng 2,4 MB bộ nhớ thay vì 6,3 MB.
  static const _decodeWidth = 768;

  // Đo trên ảnh gốc 1254×1254: chân là đáy vùng đặc, miệng là tâm vùng đỏ sẫm.
  // Thỏ bên phải dùng cùng cỡ Thỏ mặt trước (cùng máy quay). Khớp của khung
  // xương đo theo hàng pixel có hình của từng ảnh.
  static const _bunnyFront = CompanionSpriteSpec(
    'assets/companions_sprite/tho_truoc.webp',
    feet: Offset(621, 1206),
    mouthY: 722,
    eyes: [Offset(472, 640), Offset(767, 640)],
    eyeRadius: Size(76, 84),
    lidColor: Color(0xFFF8EEEC),
    rig: CompanionSpriteRig(
      content: Rect.fromLTRB(270, 35, 965, 1222),
      neck: Offset(618, 826),
      ears: [
        SpriteLimb(
          Offset(492, 400),
          Offset(410, 55),
          radius: 118,
          feather: 40,
          side: -1,
        ),
        SpriteLimb(
          Offset(775, 350),
          Offset(865, 75),
          radius: 112,
          feather: 40,
        ),
      ],
      arms: [
        SpriteLimb(
          Offset(478, 862),
          Offset(398, 955),
          radius: 52,
          feather: 26,
          outer: 95,
        ),
        SpriteLimb(
          Offset(762, 862),
          Offset(845, 955),
          radius: 52,
          feather: 26,
          side: -1,
          outer: 95,
        ),
      ],
      hipY: 1082,
      legSplit: 620,
      mouth: Offset(620, 724),
      mouthSize: Size(150, 118),
    ),
  );
  static const _bunnySide = CompanionSpriteSpec(
    'assets/companions_sprite/tho_ben_phai.webp',
    feet: Offset(649, 1191),
    mouthY: 1191 - 484,
    side: true,
    rig: CompanionSpriteRig(
      content: Rect.fromLTRB(340, 25, 915, 1206),
      neck: Offset(640, 792),
      neckBand: 34,
      ears: [
        SpriteLimb(
          Offset(525, 370),
          Offset(458, 45),
          radius: 100,
          feather: 34,
          side: -1,
        ),
        SpriteLimb(Offset(690, 335), Offset(712, 115), radius: 72, feather: 28),
      ],
      // Ảnh nhìn ngang chỉ thấy một tay: "vẫy ra ngoài" là đánh tay ra trước.
      arms: [
        SpriteLimb(
          Offset(588, 835),
          Offset(568, 950),
          radius: 58,
          feather: 26,
          side: -1,
        ),
      ],
      tail: SpriteLimb(
        Offset(505, 945),
        Offset(440, 950),
        radius: 62,
        feather: 22,
      ),
      hipY: 1062,
      // Chân gần (trái, chạm đất thấp hơn) và chân xa (phải).
      legSplit: 688,
      mouth: Offset(853, 686),
      mouthSize: Size(64, 74),
    ),
  );
  static const _bearFront = CompanionSpriteSpec(
    'assets/companions_sprite/gau_truoc.webp',
    feet: Offset(623, 1161),
    mouthY: 662,
    fit: .94,
    eyes: [Offset(472, 560), Offset(780, 556)],
    eyeRadius: Size(72, 76),
    lidColor: Color(0xFFD69661),
    rig: CompanionSpriteRig(
      content: Rect.fromLTRB(225, 160, 1025, 1176),
      neck: Offset(622, 768),
      neckBand: 34,
      ears: [
        SpriteLimb(
          Offset(425, 345),
          Offset(330, 215),
          radius: 105,
          feather: 30,
          side: -1,
        ),
        SpriteLimb(
          Offset(820, 345),
          Offset(915, 215),
          radius: 105,
          feather: 30,
        ),
      ],
      arms: [
        SpriteLimb(
          Offset(418, 808),
          Offset(362, 935),
          radius: 52,
          feather: 26,
          outer: 95,
        ),
        SpriteLimb(
          Offset(828, 808),
          Offset(884, 935),
          radius: 52,
          feather: 26,
          side: -1,
          outer: 95,
        ),
      ],
      hipY: 1040,
      legSplit: 636,
      mouth: Offset(622, 674),
      mouthSize: Size(124, 100),
    ),
  );
  static const _specs = {
    'bunny_front': _bunnyFront,
    'bunny_side': _bunnySide,
    'bear_front': _bearFront,
  };

  final Map<String, CompanionSprite> _sprites = {};
  Future<void>? _loading;

  static String _key(bool bear, bool side) =>
      '${bear ? 'bear' : 'bunny'}_${side ? 'side' : 'front'}';

  /// Ảnh nhìn ngang chưa có thì dùng ảnh mặt trước.
  CompanionSprite? sprite({required bool bear, bool side = false}) {
    if (!enabled) return null;
    return (side ? _sprites[_key(bear, true)] : null) ??
        _sprites[_key(bear, false)];
  }

  bool hasSide(bool bear) => _sprites.containsKey(_key(bear, true));

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final loaded = <String, CompanionSprite>{};
    for (final entry in _specs.entries) {
      try {
        final data = await rootBundle.load(entry.value.asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: _decodeWidth,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        final lids = entry.value.eyes.isEmpty
            ? null
            : CompanionSprite._sampleLids(
                entry.value,
                frame.image,
                await frame.image.toByteData(),
              );
        loaded[entry.key] = CompanionSprite._(entry.value, frame.image, lids);
      } catch (error) {
        debugPrint('Không nạp được ảnh đồng hành ${entry.value.asset}: $error');
      }
    }
    // Chỉ công bố khi đủ mặt trước của cả hai bé, tránh Thỏ ảnh mới đứng
    // cạnh Gấu hình cũ.
    if (loaded.containsKey(_key(false, false)) &&
        loaded.containsKey(_key(true, false))) {
      _sprites.addAll(loaded);
      notifyListeners();
    } else {
      for (final sprite in loaded.values) {
        sprite.image.dispose();
      }
    }
  }
}
