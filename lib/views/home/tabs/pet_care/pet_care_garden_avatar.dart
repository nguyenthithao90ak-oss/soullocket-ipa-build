part of 'pet_care_garden_3d.dart';

/// Các khối mềm được đặt trong thế giới 3D, chiếu từng trục và sắp độ sâu.
/// Tai, chân, tay, mắt quay cùng pose; không dùng ảnh dựng đứng theo camera.
class _GardenAvatar {
  _GardenAvatar({
    required this.camera,
    required this.size,
    required this.origin,
    required this.yaw,
    required this.scale,
  });
  final PetGardenCamera camera;
  final Size size;
  final GardenVec3 origin;
  final double yaw, scale;
  final shapes = <_GardenAvatarShape>[];

  GardenVec3 _rotate(GardenVec3 p) => GardenVec3(
    p.x * math.cos(yaw) + p.z * math.sin(yaw),
    p.y,
    -p.x * math.sin(yaw) + p.z * math.cos(yaw),
  );
  GardenVec3 point(GardenVec3 p) => origin + _rotate(p) * scale;

  void soft(
    GardenVec3 at,
    GardenVec3 radius,
    Color color, {
    double tilt = 0,
    double swing = 0,
    GardenVec3? normal,
    bool unlit = false,
  }) {
    GardenVec3 axis(GardenVec3 p) {
      final pitched = GardenVec3(
        p.x,
        p.y * math.cos(swing) - p.z * math.sin(swing),
        p.y * math.sin(swing) + p.z * math.cos(swing),
      );
      return _rotate(
            GardenVec3(
              pitched.x * math.cos(tilt) - pitched.y * math.sin(tilt),
              pitched.x * math.sin(tilt) + pitched.y * math.cos(tilt),
              pitched.z,
            ),
          ) *
          scale;
    }

    final center = point(at);
    if (normal != null && _rotate(normal).dot(camera.eye - center) <= .04) {
      return;
    }
    shapes.add(
      _GardenAvatarShape(
        center,
        [
          axis(GardenVec3(radius.x, 0, 0)),
          axis(GardenVec3(0, radius.y, 0)),
          axis(GardenVec3(0, 0, radius.z)),
        ],
        color,
        unlit,
      ),
    );
  }

  void build({
    required bool bear,
    required HomeCompanionMotion motion,
    required PetCareVitals care,
    required PetCareOutfit outfit,
    required bool animate,
    required double sitting,
    required double tending,
  }) {
    final t = animate ? motion.elapsedSeconds : 0.0;
    final walking = motion.phase == HomeCompanionPhase.walking;
    final stride = motion.visualStride * math.pi * 2;
    final step = walking ? math.sin(stride) : 0.0;
    final bob = walking
        ? math.cos(stride * 2).abs() * .025
        : math.sin(t * 2) * .009;
    final fur = bear ? const Color(0xFFB97746) : const Color(0xFFFFF3DF);
    final lightFur = bear ? const Color(0xFFFFD99F) : const Color(0xFFFFFCF1);
    final blush = bear ? const Color(0xFFDB9679) : const Color(0xFFF4B2AC);
    final shirt = switch (outfit) {
      PetCareOutfit.bare =>
        bear ? const Color(0xFF3DADA1) : const Color(0xFFF1786C),
      PetCareOutfit.cloud => const Color(0xFFB6DCF4),
      PetCareOutfit.strawberry => const Color(0xFFF17995),
      PetCareOutfit.honey => const Color(0xFFF4B847),
      PetCareOutfit.sailor => const Color(0xFF496AAB),
      PetCareOutfit.raincoat => const Color(0xFFFFCC49),
      PetCareOutfit.pajamas => const Color(0xFF929BD5),
      PetCareOutfit.royal => const Color(0xFF9F74B9),
    };
    const face = GardenVec3(0, 0, 1);
    // Đuôi nằm phía sau, tự khuất khi bé quay mặt về người chơi.
    soft(
      GardenVec3(0, .40 + bob, -.28),
      GardenVec3(bear ? .13 : .18, bear ? .13 : .17, .16),
      lightFur,
    );
    final hip = .40 - sitting * .17;
    for (final side in [-1.0, 1.0]) {
      final legStep = step * side;
      soft(
        GardenVec3(
          side * .15,
          .17 + math.max(0, legStep) * .07,
          .05 + legStep * .12 + sitting * .15,
        ),
        const GardenVec3(.13, .17, .18),
        fur,
        swing: legStep * .35 - sitting * .9,
      );
      soft(
        GardenVec3(
          side * .15,
          .105 + math.max(0, legStep) * .07,
          .15 + legStep * .12 + sitting * .15,
        ),
        const GardenVec3(.115, .075, .12),
        lightFur,
      );
    }
    soft(
      GardenVec3(0, hip + .16 + bob, 0),
      GardenVec3(bear ? .33 : .285, .36 - sitting * .06, .265),
      fur,
    );
    // Le yếm có độ dày và hai quai ôm theo thân thay cho nét vẽ phẳng.
    if (bear || outfit != PetCareOutfit.bare) {
      soft(
        GardenVec3(0, hip + .055 + bob, .018),
        const GardenVec3(.302, .255, .263),
        shirt,
      );
      soft(
        GardenVec3(0, hip + .20 + bob, .225),
        const GardenVec3(.215, .19, .065),
        shirt,
      );
      for (final x in [-.205, .205]) {
        soft(
          GardenVec3(x, hip + .29 + bob, .18),
          const GardenVec3(.047, .22, .045),
          shirt,
          tilt: x * .3,
        );
        soft(
          GardenVec3(x, hip + .25 + bob, .229),
          const GardenVec3(.025, .025, .018),
          const Color(0xFFFFE5A4),
          normal: face,
        );
      }
      soft(
        GardenVec3(0, hip + .10 + bob, .292),
        const GardenVec3(.105, .075, .022),
        Color.lerp(shirt, Colors.white, .22)!,
        normal: face,
      );
    } else {
      soft(
        GardenVec3(0, hip + .17 + bob, .236),
        const GardenVec3(.19, .245, .047),
        lightFur,
        normal: face,
      );
    }
    for (final side in [-1.0, 1.0]) {
      final swing = -step * side * .52 - tending * .85;
      soft(
        GardenVec3(
          side * (bear ? .345 : .30),
          hip + .19 + bob,
          -step * side * .10 + tending * .12,
        ),
        const GardenVec3(.115, .225, .12),
        fur,
        tilt: side * (.16 + tending * .13),
        swing: swing,
      );
      soft(
        GardenVec3(
          side * .35,
          hip + .025 + bob + tending * .12,
          .045 - step * side * .16 + tending * .28,
        ),
        const GardenVec3(.115, .105, .12),
        lightFur,
      );
    }
    final headY = .99 + bob - sitting * .12 - tending * .10;
    final nod = math.sin(t * 1.6) * .015 + tending * .10;
    GardenVec3 head(double x, double y, double z) => GardenVec3(
      x,
      headY + y * math.cos(nod) - z * math.sin(nod),
      y * math.sin(nod) + z * math.cos(nod),
    );
    // Tai có trục riêng: rung nhẹ trễ nhịp chân và nghiêng khác nhau.
    for (final side in [-1.0, 1.0]) {
      final earTilt =
          -side * .15 + math.sin(t * 2.2 - side) * .025 + step * .035;
      if (bear) {
        soft(
          head(side * .32, .285, -.025),
          const GardenVec3(.175, .18, .125),
          fur,
          tilt: earTilt,
        );
        soft(
          head(side * .32, .295, .083),
          const GardenVec3(.105, .11, .035),
          const Color(0xFFEAA68A),
          normal: face,
        );
      } else {
        soft(
          head(side * .205, .575, -.02),
          const GardenVec3(.118, .365, .102),
          fur,
          tilt: earTilt,
          swing: step * .04,
        );
        soft(
          head(side * .205, .58, .064),
          const GardenVec3(.066, .285, .035),
          blush,
          tilt: earTilt,
          normal: face,
        );
      }
    }
    soft(
      head(0, 0, 0),
      GardenVec3(bear ? .43 : .405, bear ? .385 : .395, .36),
      fur,
    );
    // Má tròn và mõm nổi. Mặt ở phía +Z và thực sự quay theo hướng đi.
    for (final side in [-1.0, 1.0]) {
      soft(
        head(side * .238, -.092, .294),
        const GardenVec3(.095, .065, .025),
        blush,
        normal: GardenVec3(side * .5, -.08, 1),
      );
      soft(
        head(side * .078, -.13, .345),
        const GardenVec3(.12, .09, .075),
        lightFur,
        normal: GardenVec3(side * .15, -.1, 1),
      );
    }
    final sleepy = care.energy < 20;
    final blinkAt = (t + (bear ? 1.3 : 0)) % 4.7;
    final blink = animate && blinkAt > 4.48
        ? math.sin((blinkAt - 4.48) / .22 * math.pi).clamp(0.0, 1.0)
        : 0.0;
    final eyeHeight = (sleepy ? .058 : .085) * (1 - blink * .90);
    for (final side in [-1.0, 1.0]) {
      final normal = GardenVec3(side * .52, .13, 1);
      soft(
        head(side * .166, .022, .319),
        GardenVec3(.066, eyeHeight, .035),
        const Color(0xFF48352C),
        normal: normal,
      );
      soft(
        head(side * .166 - .009, .029, .349),
        GardenVec3(.043, eyeHeight * .80, .018),
        const Color(0xFF242930),
        normal: normal,
      );
      if (blink < .6) {
        soft(
          head(side * .166 - .015, .055, .363),
          const GardenVec3(.018, .021, .009),
          const Color(0xFFFFFCF1),
          normal: normal,
          unlit: true,
        );
        soft(
          head(side * .166 + .015, .002, .366),
          const GardenVec3(.008, .009, .005),
          const Color(0xFFA5D9DB),
          normal: normal,
          unlit: true,
        );
      }
    }
    soft(
      head(0, -.09, .419),
      GardenVec3(bear ? .052 : .041, .034, .033),
      bear ? const Color(0xFF55362C) : const Color(0xFFD98E8C),
      normal: face,
    );
    smile([
      head(-.065, -.158, .414),
      head(-.032, -.202, .417),
      head(0, -.160, .421),
      head(.032, -.202, .417),
      head(.065, -.158, .414),
    ], .012);
    // Khăn của Thỏ là điểm nhận diện và rung theo nhịp thở/bước chân.
    if (!bear && outfit == PetCareOutfit.bare) {
      soft(
        GardenVec3(0, hip + .48 + bob, .025),
        const GardenVec3(.245, .065, .23),
        shirt,
      );
      soft(
        GardenVec3(.15, hip + .32 + bob, .26),
        const GardenVec3(.08, .18, .045),
        shirt,
        tilt: -.20 + step * .1,
        normal: face,
      );
    }
    if (outfit == PetCareOutfit.royal) {
      soft(
        head(0, .405, .02),
        const GardenVec3(.24, .065, .22),
        const Color(0xFFFFCF58),
      );
      for (final x in [-.18, 0.0, .18]) {
        soft(
          head(x, .495, .07),
          const GardenVec3(.055, .115, .055),
          const Color(0xFFFFD76A),
        );
        soft(
          head(x, .48, .13),
          const GardenVec3(.027, .035, .018),
          const Color(0xFFE18AA7),
          normal: face,
        );
      }
    } else if (outfit == PetCareOutfit.raincoat ||
        outfit == PetCareOutfit.sailor) {
      final hat = outfit == PetCareOutfit.sailor
          ? const Color(0xFFFFF9EA)
          : shirt;
      soft(head(0, .375, .02), const GardenVec3(.44, .05, .37), hat);
      soft(head(0, .43, -.02), const GardenVec3(.29, .15, .27), hat);
    } else if (outfit == PetCareOutfit.strawberry) {
      for (final side in [-1.0, 1.0]) {
        soft(
          head(side * .075, .42, .11),
          const GardenVec3(.11, .04, .06),
          const Color(0xFF79B87B),
          tilt: side * .35,
        );
      }
    }
    if (care.clean < 25) {
      for (final at in [
        head(-.27, -.15, .25),
        GardenVec3(.14, hip + .08, .28),
      ]) {
        soft(
          at,
          const GardenVec3(.055, .035, .018),
          const Color(0xFFA48760),
          normal: face,
        );
      }
    }
  }

  void smile(List<GardenVec3> local, double width) {
    final at = point(local[2]);
    if (_rotate(const GardenVec3(0, 0, 1)).dot(camera.eye - at) <= .04) return;
    shapes.add(
      _GardenAvatarStroke(at, local.map(point).toList(), width * scale),
    );
  }

  void paint(Canvas c) {
    final forward = camera.forward;
    shapes.sort(
      (a, b) => b.center.dot(forward).compareTo(a.center.dot(forward)),
    );
    for (final shape in shapes) {
      shape.paint(c, camera, size);
    }
  }
}

class _GardenAvatarShape {
  _GardenAvatarShape(this.center, this.axes, this.color, this.unlit);
  final GardenVec3 center;
  final List<GardenVec3> axes;
  final Color color;
  final bool unlit;

  void paint(Canvas c, PetGardenCamera camera, Size size) {
    final projected = camera.project(center, size);
    if (projected == null || projected.$2 < .2) return;
    // Jacobian phối cảnh cho silhouette của ellipsoid: cả chiều sâu của
    // khối góp vào ellipse, nên góc nghiêng khác với việc xoay một sprite.
    final relative = center - camera.eye;
    final f = camera.forward, r = camera.right, u = camera.up;
    final depth = projected.$2, lens = camera.lens(size);
    final rx = relative.dot(r), uy = relative.dot(u);
    var xx = 0.0, xy = 0.0, yy = 0.0;
    for (final axis in axes) {
      final z = axis.dot(f);
      final x = lens * (axis.dot(r) * depth - rx * z) / (depth * depth);
      final y = -lens * (axis.dot(u) * depth - uy * z) / (depth * depth);
      xx += x * x;
      xy += x * y;
      yy += y * y;
    }
    final split = math.sqrt((xx - yy) * (xx - yy) + 4 * xy * xy);
    final major = math.sqrt(math.max(.01, (xx + yy + split) * .5));
    final minor = math.sqrt(math.max(.01, (xx + yy - split) * .5));
    final angle = .5 * math.atan2(2 * xy, xx - yy);
    if (major < .12) return;
    final bounds = Rect.fromCenter(
      center: projected.$1,
      width: major * 2,
      height: major * 2,
    );
    if (!bounds.overlaps(Offset.zero & size)) return;
    final sun = const GardenVec3(-.55, .9, .65).unit;
    final dx = sun.dot(r), dy = -sun.dot(u);
    final highlightX = (dx * math.cos(angle) + dy * math.sin(angle)) * .46;
    final highlightY = (-dx * math.sin(angle) + dy * math.cos(angle)) * .46;
    c.save();
    c.translate(projected.$1.dx, projected.$1.dy);
    c.rotate(angle);
    final rect = Rect.fromLTRB(-major, -minor, major, minor);
    final paint = Paint();
    if (unlit) {
      paint.color = color;
    } else {
      paint.shader = RadialGradient(
        center: Alignment(highlightX, highlightY),
        radius: .96,
        colors: [
          Color.lerp(color, const Color(0xFFFFFBE9), .28)!,
          color,
          Color.lerp(color, const Color(0xFF5B5B73), .34)!,
        ],
        stops: const [0, .48, 1],
      ).createShader(rect);
    }
    c.drawOval(rect, paint);
    c.restore();
  }
}

class _GardenAvatarStroke extends _GardenAvatarShape {
  _GardenAvatarStroke(GardenVec3 center, this.points, this.width)
    : super(center, const [], const Color(0xFF79513F), true);
  final List<GardenVec3> points;
  final double width;
  @override
  void paint(Canvas c, PetGardenCamera camera, Size size) {
    final projected = points.map((p) => camera.project(p, size)).toList();
    if (projected.any((p) => p == null)) return;
    final path = Path()..moveTo(projected.first!.$1.dx, projected.first!.$1.dy);
    for (var i = 1; i + 1 < projected.length; i += 2) {
      path.quadraticBezierTo(
        projected[i]!.$1.dx,
        projected[i]!.$1.dy,
        projected[i + 1]!.$1.dx,
        projected[i + 1]!.$1.dy,
      );
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (width * camera.lens(size) / projected[2]!.$2).clamp(
          .6,
          4.0,
        ),
    );
  }
}
