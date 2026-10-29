import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Biểu cảm khuôn mặt của bé hoạt hình.
enum ToonFace {
  normal,
  happy,
  sleep,
  sad,
  angry,
  hungry,
  yawn,
  chew,
  wink,
  love,

  /// Mắt xoáy sau khi bị xoay nhiều vòng.
  dizzy,
}

/// Bốn bé hoạt hình: Thỏ, Gấu và hai bé riêng Mèo Mây, Chuột Phô Mai.
enum ToonSpecies { bunny, bear, cat, mouse }

/// Tay: [raise] giơ ra ngang/lên (0 buông, ~1,6 ngang vai, ~2,6 giơ cao),
/// [swing] đánh ra trước (+) hoặc ra sau (−), đơn vị radian.
@immutable
class ToonArm {
  const ToonArm({this.raise = .22, this.swing = 0});
  final double raise, swing;
}

/// Chân: nhấc lên [lift] và bước tới [stride] (đơn vị hình vẽ).
@immutable
class ToonFoot {
  const ToonFoot({this.lift = 0, this.stride = 0});
  final double lift, stride;
}

/// Tư thế một khung hình. [yaw] là góc quay quanh trục đứng: 0 nhìn thẳng,
/// +π/2 quay hẳn sang phải màn hình, ±π quay lưng; mọi góc đều vẽ được.
@immutable
class ToonPose {
  const ToonPose({
    this.yaw = .55,
    this.bodyLift = 0,
    this.headTilt = 0,
    this.earLeft = 0,
    this.earRight = 0,
    this.armLeft = const ToonArm(),
    this.armRight = const ToonArm(),
    this.footLeft = const ToonFoot(),
    this.footRight = const ToonFoot(),
    this.tail = 0,
    this.face = ToonFace.normal,
    this.blink = 0,
    this.mouth = 0,
    this.gaze = Offset.zero,
    this.blush = 0,
    this.sit = 0,
    this.tears = 0,
    this.dirty = false,
    this.hungry = false,
    this.angry = false,
    this.sparkle = 0,
    this.dizzy = 0,
    this.seconds = 0,
  });

  final double yaw, bodyLift, headTilt;

  /// Tai rũ/vẫy ra ngoài (radian); tay/chân "trái/phải" là phía màn hình khi
  /// bé nhìn thẳng.
  final double earLeft, earRight;
  final ToonArm armLeft, armRight;
  final ToonFoot footLeft, footRight;
  final double tail;
  final ToonFace face;
  final double blink;

  /// Há miệng 0 → 1 (chờ đồ ăn, ngáp, cười to).
  final double mouth;
  final Offset gaze;
  final double blush, sit, tears;
  final bool dirty, hungry, angry;
  final double sparkle;

  /// Sao bay vòng quanh đầu khi chóng mặt, 0 → 1.
  final double dizzy;
  final double seconds;
}

/// Màu và phụ kiện cố định của từng bé.
@immutable
class ToonLook {
  const ToonLook._({
    required this.species,
    required this.fur,
    required this.furLight,
    required this.furShade,
    required this.innerEar,
    required this.belly,
    required this.outline,
    required this.nose,
    required this.scarf,
    required this.scarfShade,
    required this.scarfDot,
    this.muzzle,
    this.overalls = false,
    this.flower = false,
    this.bell = false,
    this.star = false,
    this.cheese = false,
  });

  static const bunny = ToonLook._(
    species: ToonSpecies.bunny,
    fur: Color(0xFFFFF6EC),
    furLight: Color(0xFFFFFFFF),
    furShade: Color(0xFFEFD6C6),
    innerEar: Color(0xFFF7B6C4),
    belly: Color(0xFFFFFFFF),
    outline: Color(0xFF94696A),
    nose: Color(0xFFE77F9A),
    scarf: Color(0xFFE47B98),
    scarfShade: Color(0xFFB65576),
    scarfDot: Color(0xFFF8BCCB),
    flower: true,
  );

  static const bear = ToonLook._(
    species: ToonSpecies.bear,
    fur: Color(0xFFD69C6B),
    furLight: Color(0xFFEDC296),
    furShade: Color(0xFFAE7246),
    innerEar: Color(0xFFF1C3A0),
    belly: Color(0xFFF6DAB5),
    outline: Color(0xFF84594A),
    nose: Color(0xFF5B3C35),
    scarf: Color(0xFF71AAB7),
    scarfShade: Color(0xFF4A7B89),
    scarfDot: Color(0xFFC2E2E8),
    muzzle: Color(0xFFF7E0C3),
    overalls: true,
  );

  /// Mèo Mây: lông tím khói, sao vàng trên trán, vòng cổ vàng có chuông,
  /// tai nhọn và đuôi dài có khoanh sọc.
  static const cat = ToonLook._(
    species: ToonSpecies.cat,
    fur: Color(0xFFCDC6EE),
    furLight: Color(0xFFF4F1FF),
    furShade: Color(0xFFA197D0),
    innerEar: Color(0xFFF6B7C8),
    belly: Color(0xFFF8F5FF),
    outline: Color(0xFF6F6392),
    nose: Color(0xFFEF97AE),
    scarf: Color(0xFFEDB94A),
    scarfShade: Color(0xFFBE8E2A),
    scarfDot: Color(0xFFFFE6A2),
    muzzle: Color(0xFFF9F7FF),
    bell: true,
    star: true,
  );

  /// Chuột Phô Mai: lông sữa nâu, tai tròn to lòng hồng, răng cửa, đuôi hồng
  /// dài và kẹp phô mai trên đầu.
  static const mouse = ToonLook._(
    species: ToonSpecies.mouse,
    fur: Color(0xFFE9D4C1),
    furLight: Color(0xFFFFF6EC),
    furShade: Color(0xFFC6A891),
    innerEar: Color(0xFFF6BFCB),
    belly: Color(0xFFFFF8F0),
    outline: Color(0xFF86624F),
    nose: Color(0xFFEF8FA8),
    scarf: Color(0xFF74BE96),
    scarfShade: Color(0xFF4E9270),
    scarfDot: Color(0xFFC5EBD5),
    muzzle: Color(0xFFFFF4E8),
    cheese: true,
  );

  final ToonSpecies species;
  bool get isBear => species == ToonSpecies.bear;
  final Color fur, furLight, furShade, innerEar, belly, outline, nose;
  final Color scarf, scarfShade, scarfDot;
  final Color? muzzle;
  final bool overalls, flower;

  /// Chuông trước cổ thay cho nút khăn (Mèo Mây).
  final bool bell;

  /// Sao vàng trên trán (Mèo Mây).
  final bool star;

  /// Kẹp phô mai trên đầu (Chuột Phô Mai).
  final bool cheese;
}

/// Bé hoạt hình vẽ vector "xoay bàn": từng bộ phận đặt trong không gian 3 chiều
/// quanh trục đứng rồi chiếu xuống màn hình, nên bé quay được mọi góc, bộ
/// phận phía xa tự lùi ra sau thân. Chân ở (0, 0); kích thước giữ như bản vẽ
/// tay cũ để Home/Trạm Mây không phải đổi khoảng an toàn.
abstract final class CompanionToon {
  static const _neckY = -31.0;
  static const _headY = -48.5;
  static const _headRx = 27.5, _headRy = 20.8;
  static const _faceR = 25.0;
  static const _eye = Color(0xFF4A3333);
  static const _blush = Color(0xFFF6A2B6);
  static const _denim = Color(0xFF80B0BD);
  static const _denimShade = Color(0xFF5E8D9B);

  static void paint(Canvas canvas, ToonLook look, ToonPose pose) {
    final p = _Frame(canvas, look, pose);
    p.paint();
  }
}

final class _Frame {
  _Frame(this.c, this.look, this.pose)
    : cosY = math.cos(pose.yaw),
      sinY = math.sin(pose.yaw);

  final Canvas c;
  final ToonLook look;
  final ToonPose pose;
  final double cosY, sinY;

  Color get outline => look.outline;

  /// Chiếu điểm (X sang phải, Z hướng ra người xem) theo góc quay.
  ({double x, double z}) _proj(double x, double z) =>
      (x: x * cosY + z * sinY, z: -x * sinY + z * cosY);

  double get _sit => pose.sit.clamp(0.0, 1.0);
  double get _lift => pose.bodyLift + _sit * 5;

  bool get _longTail =>
      look.species == ToonSpecies.cat || look.species == ToonSpecies.mouse;

  void paint() {
    final tail = _proj(0, -15);
    final knot = look.bell ? _proj(0, 14.5) : _proj(8, 12);
    final flower = _proj(12.5, 3);
    final cheese = _proj(-13, 3);

    // Lớp sau thân: đuôi, tay/chân phía xa, đuôi khăn khi nút khăn ở sau.
    c.save();
    c.translate(0, _lift);
    if (tail.z < 0) _longTail ? _paintLongTail() : _paintTail(tail.x);
    if (knot.z < 0 && !look.bell) _paintScarfTails(knot.x, behind: true);
    c.restore();
    _paintFeet(back: true);
    _paintArms(back: true);

    c.save();
    c.translate(0, _lift);
    _paintBody();
    if (tail.z >= 0) _longTail ? _paintLongTail() : _paintTail(tail.x);
    c.restore();

    _paintFeet(back: false);

    c.save();
    c.translate(0, _lift);
    // Đầu nghiêng quanh cổ, tai và mặt đi theo.
    c.translate(0, CompanionToon._neckY);
    c.rotate(pose.headTilt);
    c.translate(0, -CompanionToon._neckY);
    if (look.flower && flower.z < 0) _paintFlower(flower.x);
    if (look.cheese && cheese.z < 0) _paintCheese(cheese.x);
    _paintEars();
    _paintHead();
    _paintFace();
    if (look.flower && flower.z >= 0) _paintFlower(flower.x);
    if (look.cheese && cheese.z >= 0) _paintCheese(cheese.x);
    c.restore();

    c.save();
    c.translate(0, _lift);
    _paintCollar(knot);
    c.restore();
    _paintArms(back: false);
    _paintCareFx();
  }

  // ---------------------------------------------------------------- thân

  Path get _bodyPath => Path()
    ..moveTo(-12.5, -33)
    ..cubicTo(-17.5, -27, -19.5, -12, -15.5, -6)
    ..cubicTo(-11, -0.5, 11, -0.5, 15.5, -6)
    ..cubicTo(19.5, -12, 17.5, -27, 12.5, -33)
    ..cubicTo(6, -36, -6, -36, -12.5, -33)
    ..close();

  void _paintBody() {
    final body = _bodyPath;
    _fur(body, const Rect.fromLTRB(-19, -36, 19, -1));
    c.save();
    c.clipPath(body);
    // Bụng sáng hơn ở mặt trước, co lại khi quay ngang và mất khi quay lưng.
    final belly = _proj(0, 14);
    final face = belly.z / 14;
    if (face > 0.05) {
      final w = 17 * (.25 + .75 * face);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(belly.x * .85, -16),
          width: w,
          height: 17,
        ),
        Paint()
          ..color = look.belly.withValues(alpha: (face * 2).clamp(0.0, 1.0)),
      );
    }
    if (look.overalls) _paintOveralls();
    if (pose.hungry && face > .2) {
      _stroke(
        Path()
          ..moveTo(belly.x * .85 - 3.5, -15)
          ..quadraticBezierTo(belly.x * .85 - 1.7, -13, belly.x * .85, -15)
          ..quadraticBezierTo(belly.x * .85 + 1.7, -17, belly.x * .85 + 3.5, -15),
        color: const Color(0xFFB27C74).withValues(alpha: .75),
        width: 1,
      );
    }
    c.restore();
    _stroke(body);
  }

  void _paintOveralls() {
    // Quần yếm: nửa dưới thân màu denim nhìn từ mọi phía.
    c.drawRect(
      const Rect.fromLTRB(-22, -15.5, 22, 2),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CompanionToon._denim, CompanionToon._denimShade],
        ).createShader(const Rect.fromLTRB(-22, -16, 22, 2)),
    );
    _stroke(
      Path()
        ..moveTo(-22, -15.5)
        ..lineTo(22, -15.5),
      color: CompanionToon._denimShade,
      width: 1.1,
    );
    final bib = _proj(0, 15);
    final face = bib.z / 15;
    if (face > .08) {
      final w = 15 * (.3 + .7 * face);
      final x = bib.x * .8;
      final rect = Rect.fromLTRB(x - w / 2, -25, x + w / 2, -14);
      c.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2.2)),
        Paint()..color = CompanionToon._denim,
      );
      _stroke(
        Path()..addRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2.2)),
        ),
        color: CompanionToon._denimShade,
        width: 1,
      );
      // Túi trước và hai cúc mật ong.
      _stroke(
        Path()
          ..moveTo(x - w * .22, -21.5)
          ..lineTo(x - w * .22, -18)
          ..quadraticBezierTo(x, -16.4, x + w * .22, -18)
          ..lineTo(x + w * .22, -21.5),
        color: const Color(0xFFD3E7EB),
        width: .8,
      );
      for (final sx in [-1.0, 1.0]) {
        c.drawCircle(
          Offset(x + sx * w * .36, -23.2),
          1.35,
          Paint()..color = const Color(0xFFFFDB8E),
        );
      }
      // Dây đeo vắt qua vai.
      for (final sx in [-1.0, 1.0]) {
        final shoulder = _proj(sx * 11, 4);
        _stroke(
          Path()
            ..moveTo(x + sx * w * .4, -25)
            ..lineTo(shoulder.x, -33),
          color: CompanionToon._denimShade,
          width: 2.6,
        );
        _stroke(
          Path()
            ..moveTo(x + sx * w * .4, -25)
            ..lineTo(shoulder.x, -33),
          color: CompanionToon._denim,
          width: 1.6,
        );
      }
    } else if (face < -.2) {
      // Quay lưng: hai dây chéo chữ X.
      for (final sx in [-1.0, 1.0]) {
        final from = _proj(sx * 10, -8);
        final to = _proj(-sx * 6, -10);
        _stroke(
          Path()
            ..moveTo(from.x, -33)
            ..lineTo(to.x, -16),
          color: CompanionToon._denimShade,
          width: 2.4,
        );
      }
    }
  }

  void _paintTail(double x) {
    final r = look.isBear ? 4.6 : 6.6;
    final wag = math.sin(pose.tail) * 1.6;
    final center = Offset(x * (look.isBear ? .95 : 1.05) + wag, -13);
    _fur(
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
      Rect.fromCircle(center: center, radius: r),
      width: 1.4,
    );
  }

  /// Đuôi dài của Mèo Mây/Chuột Phô Mai. Vẽ theo dáng nghiêng gốc (lưng ở
  /// bên trái) rồi lật/thu theo góc quay: nghiêng sang phải thì đuôi vắt bên
  /// trái, nhìn thẳng thì khuất sau lưng, quay lưng thì dựng giữa lưng.
  void _paintLongTail() {
    final cat = look.species == ToonSpecies.cat;
    final side = (sinY * 1.8).clamp(-1.0, 1.0);
    final lean = side + (1 - side.abs()) * (cosY < 0 ? .4 : 0);
    final sway = math.sin(pose.tail) * (cat ? 1.6 : 2.2);
    Offset at(double x, double y) =>
        Offset(x * lean + sway * (x.abs() / 30), y);
    final path = Path();
    void move(double x, double y) {
      final p = at(x, y);
      path.moveTo(p.dx, p.dy);
    }

    void cubic(double x1, double y1, double x2, double y2, double x, double y) {
      final a = at(x1, y1), b = at(x2, y2), e = at(x, y);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
    }

    void quad(double x1, double y1, double x, double y) {
      final a = at(x1, y1), e = at(x, y);
      path.quadraticBezierTo(a.dx, a.dy, e.dx, e.dy);
    }

    if (cat) {
      move(-11, -9);
      cubic(-25, -8, -32, -18, -26, -30);
      quad(-23, -36, -27, -40);
      _stroke(path, width: 6.8);
      _stroke(path, color: look.fur, width: 4.6);
      // Ba khoanh sọc tím đậm.
      for (final metric in path.computeMetrics()) {
        for (final t in const [.42, .62, .82]) {
          final tangent = metric.getTangentForOffset(metric.length * t);
          if (tangent == null) continue;
          final n = Offset(-tangent.vector.dy, tangent.vector.dx) * 2.2;
          _stroke(
            Path()
              ..moveTo(tangent.position.dx - n.dx, tangent.position.dy - n.dy)
              ..lineTo(tangent.position.dx + n.dx, tangent.position.dy + n.dy),
            color: look.furShade,
            width: 1.6,
          );
        }
      }
    } else {
      move(-11, -7);
      cubic(-24, -4, -33, -10, -31, -21);
      cubic(-30, -28, -22, -28, -23, -22);
      quad(-24, -18, -27, -20);
      _stroke(path, width: 3.5);
      _stroke(path, color: const Color(0xFFF4B3C0), width: 2);
    }
  }

  // ---------------------------------------------------------------- chân

  void _paintFeet({required bool back}) {
    final feet = [
      (side: -1.0, step: pose.footLeft),
      (side: 1.0, step: pose.footRight),
    ];
    // Vẽ chân xa trước để chân gần đè lên.
    final placed = [
      for (final f in feet)
        (
          f: f,
          at: _proj(f.side * 6.6 * (1 + _sit * .25), 2 + f.step.stride + _sit * 5),
        ),
    ]..sort((a, b) => a.at.z.compareTo(b.at.z));
    for (final item in placed) {
      final isBack = item.at.z < -1.5;
      if (isBack != back) continue;
      final lift = item.f.step.lift;
      final rect = Rect.fromCenter(
        center: Offset(item.at.x, -3.2 - lift + _sit * .6),
        width: 12 + _sit * 1.5,
        height: 6.8 + _sit * 1.8,
      );
      _fur(
        Path()..addOval(rect),
        rect,
        width: 1.45,
        dim: isBack ? .9 : 1,
      );
      // Đệm chân hồng khi ngồi (lòng bàn chân hướng ra trước).
      if (_sit > .3 && item.at.z > 0) {
        c.drawOval(
          Rect.fromCenter(
            center: rect.center + const Offset(0, .6),
            width: rect.width * .42,
            height: rect.height * .42,
          ),
          Paint()..color = CompanionToon._blush.withValues(alpha: .8 * _sit),
        );
      }
    }
  }

  // ----------------------------------------------------------------- tay

  void _paintArms({required bool back}) {
    final arms = [
      (side: -1.0, arm: pose.armLeft),
      (side: 1.0, arm: pose.armRight),
    ];
    for (final item in arms) {
      final shoulder = _proj(item.side * 14.2, 0);
      final isBack = shoulder.z < -2;
      if (isBack != back) continue;
      final r = item.arm.raise, f = item.arm.swing;
      // Hướng tay trong không gian: buông xuống, giơ ra ngang, đánh tới trước.
      final dx = item.side * math.sin(r);
      final dy = math.cos(r) * math.cos(f);
      final dz = math.cos(r).abs() * math.sin(f);
      final sx = dx * cosY + dz * sinY;
      // Tay ngắn lại khi chỉ thẳng về phía người xem.
      final v = Offset(sx, dy);
      final length = 11.5 * math.max(.45, v.distance);
      c.save();
      c.translate(shoulder.x, -30 + _lift);
      c.rotate(math.atan2(v.dy, v.dx) - math.pi / 2);
      // Tay mũm mĩm: vai nhỏ, bàn tay tròn to hơn.
      final arm = Path()
        ..moveTo(-3.2, -1.5)
        ..cubicTo(-3.6, length * .45, -4.6, length * .8, -4.1, length + .6)
        ..cubicTo(-3.6, length + 4.8, 3.6, length + 4.8, 4.1, length + .6)
        ..cubicTo(4.6, length * .8, 3.6, length * .45, 3.2, -1.5)
        ..cubicTo(2.6, -4.6, -2.6, -4.6, -3.2, -1.5)
        ..close();
      _fur(
        arm,
        Rect.fromLTRB(-4.6, -2, 4.6, length + 5),
        width: 1.4,
        dim: isBack ? .9 : 1,
      );
      c.restore();
    }
  }

  // ----------------------------------------------------------------- đầu

  Path get _headPath {
    const y = CompanionToon._headY;
    const rx = CompanionToon._headRx, ry = CompanionToon._headRy;
    // Đầu mochi: đỉnh tròn, hai má phúng phính, cằm hơi phẳng.
    return Path()
      ..moveTo(0, y - ry)
      ..cubicTo(rx * .62, y - ry, rx, y - ry * .55, rx, y + ry * .05)
      ..cubicTo(rx, y + ry * .72, rx * .55, y + ry, 0, y + ry)
      ..cubicTo(-rx * .55, y + ry, -rx, y + ry * .72, -rx, y + ry * .05)
      ..cubicTo(-rx, y - ry * .55, -rx * .62, y - ry, 0, y - ry)
      ..close();
  }

  void _paintHead() {
    // Bóng đổ mềm của đầu lên vai.
    c.drawOval(
      const Rect.fromLTRB(-15, -34.5, 15, -27.5),
      Paint()..color = look.furShade.withValues(alpha: .55),
    );
    final head = _headPath;
    _fur(
      head,
      const Rect.fromLTRB(
        -CompanionToon._headRx,
        CompanionToon._headY - CompanionToon._headRy,
        CompanionToon._headRx,
        CompanionToon._headY + CompanionToon._headRy,
      ),
    );
    if (look.isBear) {
      // Lọn lông trên đỉnh đầu, chỉ thấy ở mặt trước/nghiêng.
      final tuft = _proj(0, 20);
      if (tuft.z > 4) {
        final x = tuft.x * .9;
        _stroke(
          Path()
            ..moveTo(x - 5, -64.5)
            ..quadraticBezierTo(x - 1.5, -69, x, -64)
            ..quadraticBezierTo(x + 2.5, -68.5, x + 5, -64.5),
          color: look.furShade,
          width: 1.5,
        );
      }
    }
  }

  void _paintEars() {
    final ears = [
      (side: -1.0, flop: pose.earLeft),
      (side: 1.0, flop: pose.earRight),
    ];
    final (spread, depth) = switch (look.species) {
      ToonSpecies.bunny => (10.5, -3.0),
      ToonSpecies.bear => (17.5, -4.0),
      ToonSpecies.cat => (15.5, -2.0),
      ToonSpecies.mouse => (19.5, -4.0),
    };
    final placed = [
      for (final e in ears) (e: e, at: _proj(e.side * spread, depth)),
    ]..sort((a, b) => a.at.z.compareTo(b.at.z));
    for (final item in placed) {
      final x = item.at.x, z = item.at.z;
      final side = item.e.side, flop = item.e.flop;
      switch (look.species) {
        case ToonSpecies.bunny:
          _paintBunnyEar(x, z, side, flop);
        case ToonSpecies.bear:
          _paintBearEar(x, z, side, flop);
        case ToonSpecies.cat:
          _paintCatEar(x, z, side, flop);
        case ToonSpecies.mouse:
          _paintMouseEar(x, z, side, flop);
      }
    }
  }

  /// Tai mèo tam giác bo tròn, chếch ra hai bên, mỏng lại khi quay ngang.
  void _paintCatEar(double x, double z, double side, double flop) {
    final angle = (side * .34 + side * flop * .8) * cosY - .14 * sinY;
    final w = .55 + .45 * cosY.abs();
    c.save();
    c.translate(x, -60.5 + flop.abs() * 1.5);
    c.rotate(angle);
    final ear = Path()
      ..moveTo(-8 * w, 3)
      ..quadraticBezierTo(-7.4 * w, -8.5, -1.4 * w, -14.6)
      ..quadraticBezierTo(.3 * w, -16, 1.8 * w, -14.4)
      ..quadraticBezierTo(7.2 * w, -7, 8 * w, 3)
      ..close();
    _fur(ear, Rect.fromLTRB(-8 * w, -16, 8 * w, 3), width: 1.5);
    final inner = (z / 15.5 * .5 + cosY).clamp(0.0, 1.0);
    if (inner > .05) {
      c.drawPath(
        Path()
          ..moveTo(-4.4 * w, 1.2)
          ..quadraticBezierTo(-4 * w, -5.6, -.7 * w, -9.6)
          ..quadraticBezierTo(3.6 * w, -4.4, 4.4 * w, 1.2)
          ..close(),
        Paint()..color = look.innerEar.withValues(alpha: inner),
      );
    }
    c.restore();
  }

  /// Tai chuột tròn to, lòng hồng gần kín tai; nhìn ngang thành hình bầu dục.
  void _paintMouseEar(double x, double z, double side, double flop) {
    final w = .48 + .52 * cosY.abs();
    final center = Offset(x + side * flop * 5 * cosY, -60 + flop.abs() * 2);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate((side * .12 + side * flop * .6) * cosY - .1 * sinY);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: 25 * w,
      height: 24.5,
    );
    _fur(Path()..addOval(rect), rect, width: 1.45);
    final inner = (z / 19.5 * .5 + cosY).clamp(0.0, 1.0);
    if (inner > .05) {
      final pink = Rect.fromCenter(
        center: Offset(-side * .6 * cosY, .8),
        width: 16.4 * w * (.6 + .4 * inner),
        height: 16.4,
      );
      c.drawOval(
        pink,
        Paint()
          ..shader = RadialGradient(
            colors: [
              look.innerEar.withValues(alpha: inner),
              Color.lerp(
                look.innerEar,
                const Color(0xFFE48FA4),
                .35,
              )!.withValues(alpha: inner),
            ],
          ).createShader(pink),
      );
    }
    c.restore();
  }

  void _paintBunnyEar(double x, double z, double side, double flop) {
    // Tai nghiêng ra ngoài khi nhìn thẳng, ngả ra sau khi quay ngang.
    final angle =
        (side * .14 + side * flop) * cosY - (.2 + flop.abs() * .4) * sinY;
    final width = 11.5 * (.5 + .5 * cosY.abs());
    const height = 30.0;
    c.save();
    c.translate(x, -63.5);
    c.rotate(angle);
    final ear = Path()
      ..moveTo(-width * .5, 1.5)
      ..cubicTo(
        -width * .85,
        -height * .35,
        -width * .62,
        -height,
        0,
        -height,
      )
      ..cubicTo(width * .62, -height, width * .85, -height * .35, width * .5, 1.5)
      ..close();
    _fur(ear, Rect.fromLTRB(-width, -height, width, 2), width: 1.5);
    // Lòng tai hồng chỉ thấy từ phía trước.
    final inner = (z / 10.5 * .4 + cosY).clamp(0.0, 1.0);
    if (inner > .05) {
      final w = width * .48;
      c.drawPath(
        Path()
          ..moveTo(-w * .5, -2.5)
          ..cubicTo(-w * .8, -height * .4, -w * .5, -height + 5, 0, -height + 5)
          ..cubicTo(w * .5, -height + 5, w * .8, -height * .4, w * .5, -2.5)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              look.innerEar.withValues(alpha: .95 * inner),
              look.innerEar.withValues(alpha: .55 * inner),
            ],
          ).createShader(Rect.fromLTRB(-w, -height, w, 0)),
      );
    }
    c.restore();
  }

  void _paintBearEar(double x, double z, double side, double flop) {
    final center = Offset(x + side * flop * 6 * cosY, -63.5 + flop.abs() * 2);
    final rect = Rect.fromCircle(center: center, radius: 9.8);
    _fur(Path()..addOval(rect), rect, width: 1.5);
    final inner = (z / 17.5 * .5 + cosY).clamp(0.0, 1.0);
    if (inner > .05) {
      c.drawCircle(
        center + Offset(-side * .8 * cosY, .6),
        5.4 * (.6 + .4 * inner),
        Paint()..color = look.innerEar.withValues(alpha: inner),
      );
    }
  }

  // ------------------------------------------------------------------ mặt

  void _paintFace() {
    final face = pose.face;
    const y = CompanionToon._headY;
    final blushAlpha = (.78 + pose.blush * .22).clamp(0.0, 1.0);
    // Má hồng mờ dần ra mép.
    for (final sx in [-1.0, 1.0]) {
      final cheek = _proj(sx * 16.5, 18.8);
      final f = cheek.z / CompanionToon._faceR;
      if (f < .05) continue;
      final w = (11.5 + pose.blush * 3) * (.35 + .65 * f);
      final rect = Rect.fromCenter(
        center: Offset(cheek.x, y + 8),
        width: w,
        height: 7.2 + pose.blush * 1.5,
      );
      c.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              CompanionToon._blush.withValues(alpha: blushAlpha * f.clamp(0, 1)),
              CompanionToon._blush.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    if (look.muzzle != null) {
      final (mw, mh, my, push) = switch (look.species) {
        ToonSpecies.cat => (16.5, 10.5, 8.4, 1.04),
        ToonSpecies.mouse => (18.0, 12.5, 7.8, 1.16),
        _ => (21.0, 14.0, 7.5, 1.08),
      };
      final m = _proj(0, 21);
      final f = m.z / 21;
      if (f > -.1) {
        final w = mw * (.45 + .55 * f.clamp(0, 1));
        final rect = Rect.fromCenter(
          center: Offset(m.x * push, y + my),
          width: w,
          height: mh,
        );
        c.drawOval(rect, Paint()..color = look.muzzle!);
        // Mõm chồi ra ngoài mép đầu (nhìn nghiêng) thì cần viền.
        if (f < .45 || rect.left < -23.5 || rect.right > 23.5) {
          _stroke(Path()..addOval(rect), width: 1.1);
        }
      }
    }
    if (look.star) _paintForeheadStar();
    if (_longTail) _paintWhiskers();

    // Mắt.
    for (final sx in [-1.0, 1.0]) {
      final eye = _proj(sx * 8.8, 23.4);
      final f = eye.z / CompanionToon._faceR;
      if (f < .08) continue;
      final squeeze = .3 + .7 * f.clamp(0.0, 1.0);
      final center = Offset(
        eye.x + pose.gaze.dx * squeeze,
        y - .5 + pose.gaze.dy,
      );
      final wink = face == ToonFace.wink && sx > 0;
      if (face == ToonFace.happy || wink) {
        _stroke(
          Path()
            ..moveTo(center.dx - 3 * squeeze, center.dy + 1)
            ..quadraticBezierTo(
              center.dx,
              center.dy - 3.2,
              center.dx + 3 * squeeze,
              center.dy + 1,
            ),
          color: CompanionToon._eye,
          width: 1.7,
        );
      } else if (face == ToonFace.sleep || face == ToonFace.yawn) {
        _stroke(
          Path()
            ..moveTo(center.dx - 3 * squeeze, center.dy)
            ..quadraticBezierTo(
              center.dx,
              center.dy + 2.8,
              center.dx + 3 * squeeze,
              center.dy,
            ),
          color: CompanionToon._eye,
          width: 1.6,
        );
      } else if (face == ToonFace.love) {
        _heart(center, 3.4 * squeeze, 3.4, const Color(0xFFE7577A));
      } else if (face == ToonFace.dizzy) {
        final spiral = Path();
        for (var i = 0; i <= 26; i++) {
          final t = i / 26;
          final a = t * math.pi * 4 + pose.seconds * 7 * sx;
          final r = .4 + t * 3.1;
          final p = center + Offset(math.cos(a) * r * squeeze, math.sin(a) * r);
          i == 0 ? spiral.moveTo(p.dx, p.dy) : spiral.lineTo(p.dx, p.dy);
        }
        _stroke(spiral, color: CompanionToon._eye, width: 1.1);
      } else {
        _paintEye(center, squeeze);
      }
      final openEye =
          face != ToonFace.happy &&
          face != ToonFace.sleep &&
          face != ToonFace.yawn &&
          face != ToonFace.love &&
          face != ToonFace.dizzy &&
          !wink;
      if (look.species == ToonSpecies.cat && openEye && pose.blink < .5) {
        // Đuôi mắt mèo hất nhẹ lên.
        _stroke(
          Path()
            ..moveTo(center.dx + sx * 2.5 * squeeze, center.dy - 2.4)
            ..quadraticBezierTo(
              center.dx + sx * 3.6 * squeeze,
              center.dy - 3,
              center.dx + sx * 4.3 * squeeze,
              center.dy - 4.2,
            ),
          color: CompanionToon._eye,
          width: 1,
        );
      }
      if (look.species == ToonSpecies.bunny &&
          face != ToonFace.love &&
          face != ToonFace.dizzy) {
        // Hai sợi mi ở đuôi mắt Thỏ.
        final corner = Offset(center.dx + sx * 2.7 * squeeze, center.dy - 2);
        _stroke(
          Path()
            ..moveTo(corner.dx, corner.dy)
            ..lineTo(corner.dx + sx * 1.6, corner.dy - 1.2)
            ..moveTo(corner.dx - sx * .4, corner.dy - 1)
            ..lineTo(corner.dx + sx * .8, corner.dy - 2.6),
          color: CompanionToon._eye,
          width: .85,
        );
      }
      // Chân mày theo cảm xúc.
      if (face == ToonFace.sad || face == ToonFace.angry) {
        final inner = face == ToonFace.sad ? -1.6 : 1.6;
        _stroke(
          Path()
            ..moveTo(center.dx - sx * 3 * squeeze, center.dy - 5.8)
            ..lineTo(center.dx + sx * 2.6 * squeeze, center.dy - 5.8 + inner),
          color: CompanionToon._eye,
          width: 1.3,
        );
      }
    }

    // Mũi và miệng ở chính giữa mặt.
    final nose = _proj(0, 26);
    if (nose.z > -2) {
      final nx = nose.x;
      const ny = y + 5.2;
      final base = switch (look.species) {
        ToonSpecies.cat => 3.6,
        ToonSpecies.mouse => 5.2,
        _ => 4.4,
      };
      final w = base * (.55 + .45 * (nose.z / 26).clamp(0.0, 1.0));
      final path = Path()
        ..moveTo(nx - w / 2, ny - 1)
        ..quadraticBezierTo(nx, ny - 2.4, nx + w / 2, ny - 1)
        ..quadraticBezierTo(nx + w * .3, ny + 1.6, nx, ny + 1.6)
        ..quadraticBezierTo(nx - w * .3, ny + 1.6, nx - w / 2, ny - 1)
        ..close();
      c.drawPath(path, Paint()..color = look.nose);
      c.drawCircle(
        Offset(nx - w * .15, ny - .9),
        .55,
        Paint()..color = Colors.white.withValues(alpha: .7),
      );
      _paintMouth(Offset(nx, ny + 1.6), (nose.z / 26).clamp(0.2, 1.0));
      if (look.species == ToonSpecies.mouse && nose.z > 6) {
        _paintTeeth(Offset(nx, ny + 2.1), (nose.z / 26).clamp(0.3, 1.0));
      }
    }
  }

  /// Hai răng cửa trắng nhỏ, dấu hiệu nhận ra Chuột Phô Mai.
  void _paintTeeth(Offset top, double face) {
    final w = 4.4 * face;
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(top.dx - w / 2, top.dy, w, 3.1),
      bottomLeft: const Radius.circular(1),
      bottomRight: const Radius.circular(1),
    );
    c.drawRRect(rect, Paint()..color = Colors.white);
    _stroke(Path()..addRRect(rect), color: CompanionToon._eye, width: .7);
    _stroke(
      Path()
        ..moveTo(top.dx, top.dy + .2)
        ..lineTo(top.dx, top.dy + 2.9),
      color: CompanionToon._eye,
      width: .55,
    );
  }

  /// Ria mỗi bên má, mảnh và nhạt; chỉ thấy phía má đang hướng ra.
  void _paintWhiskers() {
    const y = CompanionToon._headY;
    final rows = look.species == ToonSpecies.cat
        ? const [-1.7, .5, 2.7]
        : const [-1.0, 1.7];
    for (final sx in [-1.0, 1.0]) {
      final root = _proj(sx * 10.5, 22);
      if (root.z / CompanionToon._faceR < .1) continue;
      for (final dy in rows) {
        final tip = _proj(sx * 23, 15);
        final from = Offset(root.x, y + 6.6 + dy * .45);
        final to = Offset(tip.x, y + 5.4 + dy * 1.25);
        _stroke(
          Path()
            ..moveTo(from.dx, from.dy)
            ..quadraticBezierTo(
              (from.dx + to.dx) / 2,
              (from.dy + to.dy) / 2 - 1.1,
              to.dx,
              to.dy,
            ),
          color: outline.withValues(alpha: .7),
          width: .8,
        );
      }
    }
  }

  /// Sao vàng trên trán Mèo Mây, co lại khi bé quay ngang.
  void _paintForeheadStar() {
    final at = _proj(0, 21.5);
    final f = at.z / 21.5;
    if (f < .12) return;
    final center = Offset(at.x * 1.02, CompanionToon._headY - 11.8);
    const r = 3.9;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * .45;
      final p = center + Offset(math.cos(a) * rr * f, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = const Color(0xFFFFD66B));
    _stroke(path, color: const Color(0xFFD9A23B), width: .9);
  }

  void _paintEye(Offset center, double squeeze) {
    final open = (1 - pose.blink).clamp(0.0, 1.0);
    final h = math.max(1.2, 7.2 * open);
    final rect = Rect.fromCenter(center: center, width: 5.6 * squeeze, height: h);
    c.drawOval(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2F2121), CompanionToon._eye, Color(0xFF8C6150)],
          stops: [0, .55, 1],
        ).createShader(rect),
    );
    if (h > 3) {
      c.drawCircle(
        center + Offset(-.9 * squeeze, -1.7 * open),
        1.4 * (.7 + .3 * squeeze),
        Paint()..color = Colors.white,
      );
      c.drawCircle(
        center + Offset(1 * squeeze, 1.5 * open),
        .7,
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
    }
  }

  void _paintMouth(Offset top, double face) {
    final w = 4.2 * face;
    switch (pose.face) {
      case ToonFace.happy || ToonFace.love || ToonFace.wink:
        _openMouth(top, w * 1.15, 3.6 + pose.mouth * 2);
      case ToonFace.yawn:
        final rect = Rect.fromCenter(
          center: top + const Offset(0, 3.6),
          width: w * .9,
          height: 4.8 + pose.mouth * 2,
        );
        c.drawOval(rect, Paint()..color = const Color(0xFFA6445A));
        _stroke(Path()..addOval(rect), color: CompanionToon._eye, width: .9);
      case ToonFace.sad || ToonFace.angry:
        _stroke(
          Path()
            ..moveTo(top.dx - w * .7, top.dy + 3.2)
            ..quadraticBezierTo(top.dx, top.dy + 1, top.dx + w * .7, top.dy + 3.2),
          color: CompanionToon._eye,
          width: 1.1,
        );
      case ToonFace.hungry || ToonFace.dizzy:
        _stroke(
          Path()
            ..moveTo(top.dx - w * .8, top.dy + 2.2)
            ..quadraticBezierTo(top.dx - w * .4, top.dy + 1, top.dx, top.dy + 2.2)
            ..quadraticBezierTo(top.dx + w * .4, top.dy + 3.4, top.dx + w * .8, top.dy + 2.2),
          color: CompanionToon._eye,
          width: 1.05,
        );
      case ToonFace.chew:
        final open = pose.mouth;
        if (open > .35) {
          _openMouth(top, w * .8, 1.6 + open * 2.2);
        } else {
          _paintSmile(top, w);
        }
      case ToonFace.normal || ToonFace.sleep || ToonFace.dizzy:
        if (pose.mouth > .1) {
          _openMouth(top, w * (1 + pose.mouth * .2), 2.5 + pose.mouth * 3.2);
        } else {
          _paintSmile(top, w);
        }
    }
  }

  void _paintSmile(Offset top, double w) {
    _stroke(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(top.dx, top.dy + .9)
        ..moveTo(top.dx - w * .85, top.dy + .5)
        ..quadraticBezierTo(top.dx - w * .4, top.dy + 2.6, top.dx, top.dy + .9)
        ..quadraticBezierTo(top.dx + w * .4, top.dy + 2.6, top.dx + w * .85, top.dy + .5),
      color: CompanionToon._eye,
      width: 1.05,
    );
  }

  void _openMouth(Offset top, double w, double h) {
    final mouth = Path()
      ..moveTo(top.dx - w * .85, top.dy + .4)
      ..quadraticBezierTo(top.dx, top.dy + 1.2, top.dx + w * .85, top.dy + .4)
      ..quadraticBezierTo(top.dx + w * .8, top.dy + h, top.dx, top.dy + h)
      ..quadraticBezierTo(top.dx - w * .8, top.dy + h, top.dx - w * .85, top.dy + .4)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFFA6445A));
    c.save();
    c.clipPath(mouth);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(top.dx, top.dy + h - .4),
        width: w * 1.1,
        height: h * .8,
      ),
      Paint()..color = const Color(0xFFF39BAD),
    );
    c.restore();
    _stroke(mouth, color: CompanionToon._eye, width: .9);
  }

  void _paintFlower(double x) {
    final center = Offset(x * .92, -61.5);
    const petal = Color(0xFFF7A9BD);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5;
      final at = center + Offset(math.cos(a) * (.6 + .4 * cosY.abs()), math.sin(a)) * 2.7;
      final rect = Rect.fromCircle(center: at, radius: 2.3);
      c.drawOval(rect, Paint()..color = petal);
      _stroke(Path()..addOval(rect), color: const Color(0xFFD9738F), width: .75);
    }
    c.drawCircle(center, 1.6, Paint()..color = const Color(0xFFFFC56B));
    c.drawCircle(
      center + const Offset(-.5, -.5),
      .55,
      Paint()..color = const Color(0xFFFFF1C9),
    );
  }

  /// Kẹp phô mai vàng có lỗ trên đầu Chuột Phô Mai.
  void _paintCheese(double x) {
    final center = Offset(x * .92, -62.5);
    final w = .6 + .4 * cosY.abs();
    final wedge = Path()
      ..moveTo(center.dx - 4.6 * w, center.dy + 2.8)
      ..lineTo(center.dx + 4.8 * w, center.dy + 2.8)
      ..quadraticBezierTo(
        center.dx + 5 * w,
        center.dy - 1.5,
        center.dx + 2.6 * w,
        center.dy - 3.6,
      )
      ..close();
    c.drawPath(
      wedge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE08A), Color(0xFFF2B947)],
        ).createShader(Rect.fromCircle(center: center, radius: 5)),
    );
    for (final (dx, dy, r) in const [(.8, .9, 1.0), (2.9, -.6, .7), (-1.9, 1.6, .6)]) {
      c.drawCircle(
        center + Offset(dx * w, dy),
        r,
        Paint()..color = const Color(0xFFD99A2E).withValues(alpha: .75),
      );
    }
    _stroke(wedge, color: const Color(0xFFC1862A), width: .9);
  }

  // ------------------------------------------------------------------ khăn

  void _paintCollar(({double x, double z}) knot) {
    final collar = Path()
      ..moveTo(-14.5, -33.8)
      ..quadraticBezierTo(0, -28.6, 14.5, -33.8)
      ..lineTo(13.6, -29.2)
      ..quadraticBezierTo(0, -24.2, -13.6, -29.2)
      ..close();
    c.drawPath(
      collar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [look.scarf, look.scarfShade],
        ).createShader(const Rect.fromLTRB(-15, -34, 15, -24)),
    );
    _stroke(collar, color: look.scarfShade, width: 1.2);
    _stroke(
      Path()
        ..moveTo(-9.5, -31.6)
        ..quadraticBezierTo(-1, -28.6, 6, -30.8),
      color: Colors.white.withValues(alpha: .45),
      width: 1,
    );
    if (knot.z >= 0 && look.bell) {
      _paintBell(knot);
    } else if (knot.z >= 0) {
      _paintScarfTails(knot.x, behind: false);
      final rect = Rect.fromCenter(
        center: Offset(knot.x, -28.4),
        width: 6.4 * (.55 + .45 * (knot.z / 14.4).clamp(0, 1)),
        height: 5.6,
      );
      c.drawOval(rect, Paint()..color = look.scarfDot);
      _stroke(Path()..addOval(rect), color: look.scarfShade, width: 1);
    }
  }

  /// Chuông vàng trước cổ Mèo Mây.
  void _paintBell(({double x, double z}) at) {
    final f = (at.z / 14.5).clamp(0.0, 1.0);
    final center = Offset(at.x, -26.4);
    final rect = Rect.fromCenter(
      center: center,
      width: 7 * (.55 + .45 * f),
      height: 6.8,
    );
    c.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Color(0xFFFFF2B8), Color(0xFFF5C445), Color(0xFFD69A27)],
          stops: [0, .55, 1],
        ).createShader(rect),
    );
    _stroke(Path()..addOval(rect), color: const Color(0xFFB27E22), width: .9);
    _stroke(
      Path()
        ..moveTo(center.dx - rect.width * .32, center.dy + .6)
        ..lineTo(center.dx + rect.width * .32, center.dy + .6),
      color: const Color(0xFFB27E22),
      width: .8,
    );
    c.drawCircle(
      center + const Offset(0, 2),
      .8,
      Paint()..color = const Color(0xFF8E6418),
    );
  }

  void _paintScarfTails(double x, {required bool behind}) {
    final flutter = math.sin(pose.seconds * 3.1) * 1.2 + pose.bodyLift * .3;
    // Đuôi khăn bay về phía sau lưng bé.
    final back = -sinY;
    for (final k in [0.0, 1.0]) {
      final tip = Offset(
        x + back * (6 + k * 3) + (1 - back.abs()) * (k * 3 - 1.5),
        -22 + k * 2.5 + flutter * (k + .5),
      );
      final path = Path()
        ..moveTo(x - 1.6, -28)
        ..quadraticBezierTo((x + tip.dx) / 2, -26, tip.dx, tip.dy)
        ..lineTo(tip.dx + 2.2, tip.dy - 2)
        ..quadraticBezierTo((x + tip.dx) / 2 + 2, -27.5, x + 1.6, -28.5)
        ..close();
      c.drawPath(path, Paint()..color = behind ? look.scarfShade : look.scarf);
      _stroke(path, color: look.scarfShade, width: 1);
    }
  }

  // ------------------------------------------------------- hiệu ứng chăm bé

  void _paintCareFx() {
    c.save();
    c.translate(0, _lift);
    if (pose.dirty) {
      // Vài vệt bùn nhỏ, mềm mép; chỉ hiện phía đang nhìn thấy.
      for (final spot in const [
        (x: -7.0, z: 12.0, y: -20.0, r: 2.6),
        (x: 8.0, z: 11.0, y: -11.0, r: 2.1),
        (x: -14.0, z: 20.0, y: -56.0, r: 2.2),
        (x: 11.0, z: 4.0, y: -24.0, r: 1.6),
      ]) {
        final at = _proj(spot.x, spot.z);
        if (at.z < 2) continue;
        final rect = Rect.fromCircle(center: Offset(at.x, spot.y), radius: spot.r);
        c.drawOval(
          rect,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFA67C5E).withValues(alpha: .62),
                const Color(0xFFA67C5E).withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      }
    }
    if (pose.tears > .05) {
      final drop = (pose.seconds * .9) % 1;
      for (final sx in [-1.0, 1.0]) {
        final eye = _proj(sx * 8.8, 23.4);
        if (eye.z < 4) continue;
        final at = Offset(eye.x, -45 + drop * 9);
        final paint = Paint()
          ..color = const Color(0xFF7CC4EE).withValues(alpha: .9 * pose.tears);
        c.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - 2.4)
            ..quadraticBezierTo(at.dx + 1.6, at.dy + .2, at.dx, at.dy + 1.4)
            ..quadraticBezierTo(at.dx - 1.6, at.dy + .2, at.dx, at.dy - 2.4),
          paint,
        );
      }
    }
    if (pose.angry) {
      final at = Offset(_proj(14, 14).x + 6, -66);
      final paint = Paint()
        ..color = const Color(0xFFE3646D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      for (final a in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
        final dir = Offset(math.cos(a + .785), math.sin(a + .785));
        c.drawLine(at + dir * .9, at + dir * 2.8, paint);
      }
    }
    if (pose.dizzy > .05) {
      // Ba ngôi sao nhỏ bay vòng quanh đầu.
      for (var i = 0; i < 3; i++) {
        final a = pose.seconds * 4.5 + i * math.pi * 2 / 3;
        final depth = (math.sin(a) + 1) / 2;
        _star(
          Offset(math.cos(a) * 17, -77 + math.sin(a) * 3.5),
          (1.6 + depth * 1.2) * pose.dizzy,
          const Color(
            0xFFFFCF4D,
          ).withValues(alpha: (.45 + .55 * depth) * pose.dizzy),
        );
      }
    }
    if (pose.sparkle > .05) {
      for (final (i, at) in const [Offset(-23, -70), Offset(24, -60)].indexed) {
        final s = (math.sin(pose.seconds * 4 + i * 2) * .5 + .5) * pose.sparkle;
        _star(at, 1.8 + s * 1.4, const Color(0xFFFFD66E).withValues(alpha: .4 + s * .6));
      }
    }
    c.restore();
  }

  void _star(Offset center, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final rr = i.isEven ? r : r * .38;
      final p = center + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _heart(Offset center, double w, double h, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + h * .55)
      ..cubicTo(
        center.dx - w * .9,
        center.dy,
        center.dx - w * .55,
        center.dy - h * .7,
        center.dx,
        center.dy - h * .2,
      )
      ..cubicTo(
        center.dx + w * .55,
        center.dy - h * .7,
        center.dx + w * .9,
        center.dy,
        center.dx,
        center.dy + h * .55,
      )
      ..close();
    c.drawPath(path, Paint()..color = color);
    c.drawCircle(
      center + Offset(-w * .25, -h * .2),
      .55,
      Paint()..color = Colors.white.withValues(alpha: .85),
    );
  }

  // --------------------------------------------------------------- tô vẽ

  /// Lông tô chuyển sáng ở góc trên trái, tối dần ở dưới phải, viền ấm.
  void _fur(Path path, Rect bounds, {double width = 1.6, double dim = 1}) {
    final base = dim < 1
        ? Color.lerp(look.fur, look.furShade, .35)!
        : look.fur;
    c.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.38, -.48),
          radius: 1.05,
          colors: [look.furLight, base, look.furShade],
          stops: const [0, .52, 1],
        ).createShader(bounds),
    );
    _stroke(path, width: width);
  }

  void _stroke(Path path, {Color? color, double width = 1.6}) {
    c.drawPath(
      path,
      Paint()
        ..color = color ?? outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}
