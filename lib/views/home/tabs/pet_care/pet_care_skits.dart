part of 'pet_care_scene.dart';

/// Tiểu cảnh hai bé tự chơi với nhau khi người chơi để yên một lúc. Chỉ là
/// hình ảnh trên máy, không đổi chỉ số; bé bị chọc/thua có thể dỗi, chạm vào
/// bé để dỗ (ôm) thì hết dỗi.
enum PetCareSkit {
  /// Lén chọc bé kia rồi bỏ chạy vòng quanh phòng; bị bắt được thì bị cốc
  /// đầu nổ sao, về chỗ ngồi dỗi.
  pokeChase(7.5, sulker: PetSkitRole.instigator),

  /// Lao vào nhau thành đám bụi hoạt hình bụp bụp, tung ra choáng váng; bé
  /// thua dỗi.
  brawl(6.5, sulker: PetSkitRole.target),

  /// Rượt bắt vòng quanh phòng, cả hai cười khanh khách.
  tag(6),

  /// Ghé tai thì thầm rồi cùng cười khúc khích, tim bay lên.
  whisper(4.5),

  /// Bếp: lén giành món trên đĩa bé kia rồi chạy về nhai; bé kia mếu rồi dỗi.
  steal(6.5, sulker: PetSkitRole.target),

  /// Nhà tắm: té nước vào nhau, rũ nước rồi cùng cười.
  splash(6),

  /// Phòng ngủ (còn thức): đánh gối, lông vũ bay tứ tung.
  pillow(6);

  const PetCareSkit(this.seconds, {this.sulker});

  /// Độ dài tiểu cảnh (giây).
  final double seconds;

  /// Bé dỗi sau tiểu cảnh (null: cả hai vui vẻ).
  final PetSkitRole? sulker;

  static List<PetCareSkit> forRoom(PetCareRoom room) => switch (room) {
    PetCareRoom.living => const [pokeChase, brawl, tag, whisper],
    PetCareRoom.kitchen => const [steal, pokeChase, whisper],
    PetCareRoom.bathroom => const [splash, pokeChase, tag],
    PetCareRoom.bedroom => const [pillow, whisper, brawl],
  };

  /// Nhịp phát âm (mốc tiến độ 0..1 → âm).
  List<(double, PetCareCue)> get beats => switch (this) {
    pokeChase => const [
      (.14, PetCareCue.squeak),
      (.32, PetCareCue.bounce),
      (.55, PetCareCue.bounce),
      (.79, PetCareCue.tap),
      (.82, PetCareCue.bounce),
    ],
    brawl => const [
      (.18, PetCareCue.bounce),
      (.28, PetCareCue.tap),
      (.36, PetCareCue.tap),
      (.44, PetCareCue.tap),
      (.52, PetCareCue.tap),
      (.62, PetCareCue.bounce),
    ],
    tag => const [
      (.1, PetCareCue.squeak),
      (.4, PetCareCue.bounce),
      (.7, PetCareCue.bounce),
    ],
    whisper => const [(.62, PetCareCue.hug)],
    steal => const [
      (.24, PetCareCue.pickup),
      (.36, PetCareCue.squeak),
      (.62, PetCareCue.bite),
      (.69, PetCareCue.bite),
    ],
    splash => const [
      (.18, PetCareCue.water),
      (.38, PetCareCue.water),
      (.6, PetCareCue.bounce),
    ],
    pillow => const [
      (.25, PetCareCue.bounce),
      (.4, PetCareCue.bounce),
      (.55, PetCareCue.bounce),
      (.7, PetCareCue.bounce),
    ],
  };
}

/// Vai trong tiểu cảnh: bé khơi mào hay bé bị chọc.
enum PetSkitRole { instigator, target }

enum _SkitMood { happy, angry, crying, dizzy }

/// Tư thế một bé trong một khung tiểu cảnh (toạ độ cảnh, tại chân bé).
class _SkitPose {
  const _SkitPose({
    required this.at,
    required this.facingRight,
    this.walking = false,
    this.stride = 0,
    this.lift = 0,
    this.tilt = 0,
    this.squash = 0,
    this.mood,
    this.hidden = false,
  });

  final Offset at;
  final bool facingRight;
  final bool walking;

  /// Số bước đã đi để chân bước đều.
  final double stride;

  /// Nhảy lên (đơn vị `hopLift` của bé).
  final double lift;

  /// Nghiêng người (radian, dương = nghiêng phải).
  final double tilt;

  /// Bẹp xuống khi bị cốc (0..1).
  final double squash;
  final _SkitMood? mood;

  /// Đang lẫn trong đám bụi ẩu đả.
  final bool hidden;
}

enum _SkitFxKind {
  exclaim,
  stars,
  pow,
  dust,
  sweat,
  vein,
  heart,
  note,
  dots,
  splash,
  drips,
  feathers,
  pillow,
  food,
}

class _SkitFx {
  const _SkitFx(this.kind, this.at, {this.t = 0, this.to, this.flip = false});

  final _SkitFxKind kind;
  final Offset at;

  /// Tiến độ riêng của hiệu ứng (0..1).
  final double t;

  /// Điểm đích (tia nước, món ăn bay).
  final Offset? to;
  final bool flip;
}

class _SkitFrame {
  const _SkitFrame(this.instigator, this.target, [this.effects = const []]);

  final _SkitPose instigator;
  final _SkitPose target;
  final List<_SkitFx> effects;
}

double _seg(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);
double _ease(double x) => Curves.easeInOutSine.transform(x);

/// Một khung của tiểu cảnh [skit] ở tiến độ [t] (0..1). [a]/[b] là chỗ đứng
/// thường ngày của bé khơi mào/bé bị chọc; [growth] là cỡ bé theo cấp.
_SkitFrame _petSkitFrame(
  PetCareSkit skit,
  double t, {
  required Offset a,
  required Offset b,
  required PetCarePet instigatorPet,
  required double growth,
  required double seconds,
}) {
  final g = growth;
  final dir = b.dx >= a.dx ? 1.0 : -1.0;
  final floor = (a.dy + b.dy) / 2;
  Offset head(Offset at) => at + Offset(0, -112 * g);
  Offset clampX(Offset p) => Offset(p.dx.clamp(46.0, 314.0), p.dy);

  _SkitPose stand(
    Offset at, {
    required bool faceRight,
    _SkitMood? mood,
    double lift = 0,
    double tilt = 0,
    double squash = 0,
  }) => _SkitPose(
    at: at,
    facingRight: faceRight,
    mood: mood,
    lift: lift,
    tilt: tilt,
    squash: squash,
  );

  _SkitPose walk(
    Offset from,
    Offset to,
    double x, {
    _SkitMood? mood,
    bool? faceRight,
  }) {
    final e = _ease(x);
    final distance = (to - from).distance;
    final moving = x > 0 && x < 1 && distance > 2;
    return _SkitPose(
      at: Offset.lerp(from, to, e)!,
      facingRight: moving || faceRight == null ? to.dx >= from.dx : faceRight,
      walking: moving,
      stride: distance * e / 20,
      mood: mood,
    );
  }

  // Đường chạy vòng quanh phòng: elip dẹt trên sàn.
  Offset loop(double angle) =>
      clampX(Offset(180 + math.cos(angle) * 112, floor + math.sin(angle) * 9));
  _SkitPose run(double angle, double travelled, {_SkitMood? mood}) => _SkitPose(
    at: loop(angle),
    facingRight: -math.sin(angle) >= 0,
    walking: true,
    stride: travelled * 112 / 16,
    mood: mood,
    lift: (math.sin(travelled * 9).abs()) * .35,
  );

  switch (skit) {
    case PetCareSkit.pokeChase:
      final beside = clampX(b + Offset(-dir * 56 * g, 0));
      if (t < .14) {
        return _SkitFrame(
          walk(a, beside, _seg(t, 0, .14), mood: _SkitMood.happy),
          stand(b, faceRight: dir > 0),
        );
      }
      if (t < .22) {
        final x = _seg(t, .14, .22);
        final jab = math.sin(x * math.pi);
        return _SkitFrame(
          stand(
            beside + Offset(dir * 7 * jab, 0),
            faceRight: dir > 0,
            tilt: dir * .12 * jab,
            mood: _SkitMood.happy,
          ),
          stand(
            b,
            faceRight: x > .55 ? dir < 0 : dir > 0,
            lift: jab * 1.6,
            mood: x > .55 ? _SkitMood.angry : null,
          ),
          [_SkitFx(_SkitFxKind.exclaim, head(b), t: x)],
        );
      }
      final start = beside.dx < 180 ? math.pi : 0.0;
      double runAngle(double u) => start + u * math.pi * 2 * 1.3;
      if (t < .74) {
        final u = _seg(t, .22, .74);
        final blend = _ease(_seg(u, 0, .14));
        final runner = run(runAngle(u), u * 8.2, mood: _SkitMood.happy);
        final chaser = run(runAngle(u) - .8, u * 8.2, mood: _SkitMood.angry);
        final r = _SkitPose(
          at: Offset.lerp(beside, runner.at, blend)!,
          facingRight: runner.facingRight,
          walking: true,
          stride: runner.stride,
          lift: runner.lift,
          mood: _SkitMood.happy,
        );
        final c = _SkitPose(
          at: Offset.lerp(b, chaser.at, blend)!,
          facingRight: chaser.facingRight,
          walking: true,
          stride: chaser.stride,
          lift: chaser.lift,
          mood: _SkitMood.angry,
        );
        return _SkitFrame(r, c, [
          _SkitFx(_SkitFxKind.sweat, head(r.at), t: u, flip: r.facingRight),
          _SkitFx(_SkitFxKind.vein, head(c.at), t: u),
        ]);
      }
      final caught = loop(runAngle(1));
      final from = loop(runAngle(1) - .8);
      final landing = clampX(
        caught + Offset(from.dx < caught.dx ? -42 * g : 42 * g, 0),
      );
      if (t < .82) {
        final x = _seg(t, .74, .82);
        final hit = _seg(x, .6, 1);
        return _SkitFrame(
          stand(
            caught,
            faceRight: from.dx < caught.dx,
            squash: hit,
            mood: hit > 0 ? _SkitMood.dizzy : _SkitMood.happy,
          ),
          _SkitPose(
            at: Offset.lerp(from, landing, _ease(x))!,
            facingRight: caught.dx >= from.dx,
            lift: math.sin(x * math.pi) * 2.4,
            mood: _SkitMood.angry,
          ),
          [
            if (hit > 0) _SkitFx(_SkitFxKind.pow, head(caught), t: hit),
            if (hit > 0) _SkitFx(_SkitFxKind.stars, head(caught), t: hit),
          ],
        );
      }
      final x = _seg(t, .82, 1);
      return _SkitFrame(
        walk(caught, a, x, mood: x < .45 ? _SkitMood.dizzy : _SkitMood.angry),
        walk(landing, b, x, mood: _SkitMood.happy),
        [
          if (x < .55)
            _SkitFx(_SkitFxKind.stars, head(walk(caught, a, x).at), t: 1),
        ],
      );

    case PetCareSkit.brawl:
      final mid = Offset((a.dx + b.dx) / 2, floor);
      final left = clampX(mid + Offset(-dir * 24 * g, 0));
      final right = clampX(mid + Offset(dir * 24 * g, 0));
      if (t < .18) {
        final x = _seg(t, 0, .18);
        final i = walk(a, left, x, mood: _SkitMood.angry);
        final j = walk(b, right, x, mood: _SkitMood.angry);
        return _SkitFrame(i, j, [
          _SkitFx(_SkitFxKind.vein, head(i.at), t: x),
          _SkitFx(_SkitFxKind.vein, head(j.at), t: x),
        ]);
      }
      if (t < .62) {
        final x = _seg(t, .18, .62);
        const hidden = _SkitPose(
          at: Offset.zero,
          facingRight: true,
          hidden: true,
        );
        return _SkitFrame(hidden, hidden, [
          _SkitFx(_SkitFxKind.dust, mid + Offset(0, -46 * g), t: x),
        ]);
      }
      final outI = clampX(mid + Offset(-dir * 52 * g, 0));
      final outJ = clampX(mid + Offset(dir * 52 * g, 0));
      if (t < .7) {
        final x = _seg(t, .62, .7);
        final pop = math.sin(x * math.pi);
        return _SkitFrame(
          stand(
            outI,
            faceRight: dir > 0,
            lift: pop * 1.4,
            mood: _SkitMood.dizzy,
          ),
          stand(
            outJ,
            faceRight: dir < 0,
            lift: pop * 1.4,
            mood: _SkitMood.dizzy,
          ),
          [
            _SkitFx(_SkitFxKind.stars, head(outI), t: 1),
            _SkitFx(_SkitFxKind.stars, head(outJ), t: 1),
          ],
        );
      }
      final x = _seg(t, .7, 1);
      final j = walk(outJ, b, x, mood: _SkitMood.angry);
      return _SkitFrame(walk(outI, a, x, mood: _SkitMood.happy), j, [
        if (x < .35) _SkitFx(_SkitFxKind.stars, head(j.at), t: 1),
      ]);

    case PetCareSkit.tag:
      final near = clampX(b + Offset(-dir * 56 * g, 0));
      if (t < .12) {
        return _SkitFrame(
          walk(a, near, _seg(t, 0, .12), mood: _SkitMood.happy),
          stand(b, faceRight: dir < 0, mood: _SkitMood.happy),
        );
      }
      final start = b.dx < 180 ? math.pi : 0.0;
      double angle(double u) => start + u * math.pi * 2 * 1.2;
      if (t < .8) {
        final u = _seg(t, .12, .8);
        final blend = _ease(_seg(u, 0, .14));
        final runner = run(angle(u), u * 7.5, mood: _SkitMood.happy);
        final chaser = run(angle(u) - .8, u * 7.5, mood: _SkitMood.happy);
        final r = _SkitPose(
          at: Offset.lerp(b, runner.at, blend)!,
          facingRight: runner.facingRight,
          walking: true,
          stride: runner.stride,
          lift: runner.lift,
          mood: _SkitMood.happy,
        );
        final c = _SkitPose(
          at: Offset.lerp(near, chaser.at, blend)!,
          facingRight: chaser.facingRight,
          walking: true,
          stride: chaser.stride,
          lift: chaser.lift,
          mood: _SkitMood.happy,
        );
        return _SkitFrame(c, r, [
          _SkitFx(_SkitFxKind.note, head(r.at), t: (u * 3) % 1),
          _SkitFx(
            _SkitFxKind.note,
            head(c.at),
            t: (u * 3 + .5) % 1,
            flip: true,
          ),
        ]);
      }
      final x = _seg(t, .8, 1);
      final endR = loop(angle(1));
      final endC = loop(angle(1) - .8);
      final i = walk(endC, a, x, mood: _SkitMood.happy);
      final j = walk(endR, b, x, mood: _SkitMood.happy);
      return _SkitFrame(i, j, [
        _SkitFx(_SkitFxKind.heart, head(i.at), t: x),
        _SkitFx(_SkitFxKind.heart, head(j.at), t: x, flip: true),
      ]);

    case PetCareSkit.whisper:
      final near = clampX(b + Offset(-dir * 68 * g, 0));
      if (t < .25) {
        return _SkitFrame(
          walk(a, near, _seg(t, 0, .25), mood: _SkitMood.happy),
          stand(b, faceRight: dir < 0),
        );
      }
      if (t < .6) {
        final x = _seg(t, .25, .6);
        return _SkitFrame(
          stand(
            near,
            faceRight: dir > 0,
            tilt: dir * .14,
            mood: _SkitMood.happy,
          ),
          stand(b, faceRight: dir < 0, tilt: -dir * .06),
          [
            _SkitFx(
              _SkitFxKind.dots,
              near + Offset(dir * 26 * g, -96 * g),
              t: x,
            ),
          ],
        );
      }
      if (t < .85) {
        final x = _seg(t, .6, .85);
        final mid = Offset.lerp(near, b, .5)! + Offset(0, -120 * g);
        return _SkitFrame(
          stand(
            near,
            faceRight: dir > 0,
            lift: math.sin(x * math.pi * 4).abs() * .7,
            mood: _SkitMood.happy,
          ),
          stand(
            b,
            faceRight: dir < 0,
            lift: math.sin(x * math.pi * 4 + 1.2).abs() * .7,
            mood: _SkitMood.happy,
          ),
          [
            _SkitFx(_SkitFxKind.heart, mid, t: x),
            _SkitFx(_SkitFxKind.note, mid + Offset(18 * g, 6), t: (x * 2) % 1),
          ],
        );
      }
      return _SkitFrame(
        walk(near, a, _seg(t, .85, 1), mood: _SkitMood.happy),
        stand(b, faceRight: dir < 0, mood: _SkitMood.happy),
      );

    case PetCareSkit.steal:
      final targetPet = instigatorPet == PetCarePet.rabbit
          ? PetCarePet.bear
          : PetCarePet.rabbit;
      final plate =
          _PetCareSceneState.plateFor(targetPet) + const Offset(0, -12);
      final beside = clampX(b + Offset(-dir * 52 * g, 0));
      Offset mouth(Offset at, bool right) =>
          at + Offset((right ? 1 : -1) * 6 * g, -62 * g);
      if (t < .22) {
        return _SkitFrame(
          walk(a, beside, _seg(t, 0, .22), mood: _SkitMood.happy),
          stand(b, faceRight: dir > 0),
          [_SkitFx(_SkitFxKind.food, plate, t: 0)],
        );
      }
      if (t < .32) {
        final x = _seg(t, .22, .32);
        return _SkitFrame(
          stand(
            beside,
            faceRight: dir > 0,
            tilt: dir * .1,
            mood: _SkitMood.happy,
          ),
          stand(b, faceRight: dir > 0),
          [
            _SkitFx(
              _SkitFxKind.food,
              Offset.lerp(plate, mouth(beside, dir > 0), _ease(x))!,
              t: 0,
            ),
          ],
        );
      }
      if (t < .6) {
        final x = _seg(t, .32, .6);
        final i = walk(beside, a, x, mood: _SkitMood.happy);
        return _SkitFrame(
          i,
          stand(
            b,
            faceRight: dir < 0,
            lift: x < .2 ? math.sin(x / .2 * math.pi) * 1.2 : 0,
            mood: _SkitMood.crying,
          ),
          [
            _SkitFx(_SkitFxKind.food, mouth(i.at, i.facingRight), t: 0),
            if (x < .35) _SkitFx(_SkitFxKind.exclaim, head(b), t: x / .35),
          ],
        );
      }
      final x = _seg(t, .6, 1);
      return _SkitFrame(
        stand(a, faceRight: dir > 0, mood: _SkitMood.happy),
        stand(
          b,
          faceRight: dir < 0,
          mood: x < .3 ? _SkitMood.crying : _SkitMood.angry,
        ),
        [
          if (x < .35) _SkitFx(_SkitFxKind.food, mouth(a, dir > 0), t: x / .35),
          if (x >= .3) _SkitFx(_SkitFxKind.vein, head(b), t: x),
        ],
      );

    case PetCareSkit.splash:
      final near = clampX(b + Offset(-dir * 92 * g, 0));
      if (t < .15) {
        return _SkitFrame(
          walk(a, near, _seg(t, 0, .15), mood: _SkitMood.happy),
          stand(b, faceRight: dir < 0),
        );
      }
      if (t < .55) {
        final first = t < .35;
        final x = first ? _seg(t, .15, .35) : _seg(t, .35, .55);
        final shake = x > .55 ? math.sin(x * math.pi * 10) * .08 : 0.0;
        return _SkitFrame(
          stand(
            near,
            faceRight: dir > 0,
            tilt: first ? dir * .1 * math.sin(x * math.pi) : shake,
            mood: first ? _SkitMood.happy : _SkitMood.dizzy,
          ),
          stand(
            b,
            faceRight: dir < 0,
            tilt: first ? shake : -dir * .1 * math.sin(x * math.pi),
            mood: first ? _SkitMood.dizzy : _SkitMood.happy,
          ),
          [
            _SkitFx(
              _SkitFxKind.splash,
              first ? head(near) : head(b),
              to: first ? head(b) : head(near),
              t: x,
            ),
            if (x > .55)
              _SkitFx(_SkitFxKind.drips, first ? head(b) : head(near), t: x),
          ],
        );
      }
      if (t < .8) {
        final x = _seg(t, .55, .8);
        return _SkitFrame(
          stand(
            near,
            faceRight: dir > 0,
            lift: math.sin(x * math.pi * 4).abs() * .8,
            mood: _SkitMood.happy,
          ),
          stand(
            b,
            faceRight: dir < 0,
            lift: math.sin(x * math.pi * 4 + 1).abs() * .8,
            mood: _SkitMood.happy,
          ),
          [
            _SkitFx(
              _SkitFxKind.heart,
              Offset.lerp(head(near), head(b), .5)!,
              t: x,
            ),
          ],
        );
      }
      return _SkitFrame(
        walk(near, a, _seg(t, .8, 1), mood: _SkitMood.happy),
        stand(b, faceRight: dir < 0, mood: _SkitMood.happy),
      );

    case PetCareSkit.pillow:
      final mid = Offset((a.dx + b.dx) / 2, floor);
      final left = clampX(mid + Offset(-dir * 46 * g, 0));
      final right = clampX(mid + Offset(dir * 46 * g, 0));
      if (t < .15) {
        final x = _seg(t, 0, .15);
        return _SkitFrame(
          walk(a, left, x, mood: _SkitMood.happy),
          walk(b, right, x, mood: _SkitMood.happy),
        );
      }
      if (t < .75) {
        final x = _seg(t, .15, .75);
        // Bốn cú đánh luân phiên; mỗi cú: vung lên rồi đập xuống.
        final beat = (x * 4).floor().clamp(0, 3);
        final local = x * 4 - beat;
        final swing = math.sin(local * math.pi);
        final iSwings = beat.isEven;
        final hit = local > .55 ? _seg(local, .55, 1) : 0.0;
        return _SkitFrame(
          stand(
            left,
            faceRight: dir > 0,
            tilt: iSwings ? dir * .16 * swing : -dir * .06 * hit,
            squash: iSwings ? 0 : hit * .3,
            mood: _SkitMood.happy,
          ),
          stand(
            right,
            faceRight: dir < 0,
            tilt: iSwings ? dir * .06 * hit : -dir * .16 * swing,
            squash: iSwings ? hit * .3 : 0,
            mood: _SkitMood.happy,
          ),
          [
            _SkitFx(
              _SkitFxKind.pillow,
              head(left) + Offset(dir * 14 * g, -6),
              t: iSwings ? swing : .1,
              flip: dir < 0,
            ),
            _SkitFx(
              _SkitFxKind.pillow,
              head(right) + Offset(-dir * 14 * g, -6),
              t: iSwings ? .1 : swing,
              flip: dir > 0,
            ),
            if (hit > 0)
              _SkitFx(
                _SkitFxKind.feathers,
                head(iSwings ? right : left),
                t: hit,
              ),
          ],
        );
      }
      final x = _seg(t, .75, 1);
      return _SkitFrame(
        walk(left, a, x, mood: _SkitMood.happy),
        walk(right, b, x, mood: _SkitMood.happy),
        [
          _SkitFx(
            _SkitFxKind.feathers,
            Offset.lerp(head(left), head(right), .5)!,
            t: .5 + x / 2,
          ),
        ],
      );
  }
}

/// Kiểm thử: vị trí chân hai bé (khơi mào, bị chọc) và có đang lẫn trong
/// đám bụi không, ở tiến độ [t] của tiểu cảnh.
@visibleForTesting
({Offset instigator, Offset target, bool hidden}) petSkitPositions(
  PetCareSkit skit,
  double t, {
  required Offset a,
  required Offset b,
  PetCarePet instigatorPet = PetCarePet.rabbit,
  double growth = 1,
}) {
  final frame = _petSkitFrame(
    skit,
    t,
    a: a,
    b: b,
    instigatorPet: instigatorPet,
    growth: growth,
    seconds: t * skit.seconds,
  );
  return (
    instigator: frame.instigator.at,
    target: frame.target.at,
    hidden: frame.instigator.hidden || frame.target.hidden,
  );
}

extension _PetCareSkits on _PetHousePainter {
  /// Bé mình đang giành món trên đĩa: đĩa của mình tạm trống.
  bool get _plateStolen =>
      skit == PetCareSkit.steal && !skitMineFirst && skitProgress > .22;

  /// Vai của bé mình trong tiểu cảnh đang chạy.
  bool get _mineInstigates => skitMineFirst;

  _SkitFrame? get _skitFrame {
    final current = skit;
    if (current == null || small) return null;
    final mine = position;
    final partner = _partnerPosition;
    return _petSkitFrame(
      current,
      skitProgress,
      a: _mineInstigates ? mine : partner,
      b: _mineInstigates ? partner : mine,
      instigatorPet: _mineInstigates ? selectedPet : _partner,
      growth: growth,
      seconds: seconds,
    );
  }

  /// Bé dỗi quay lưng với bé kia; bé kia nhìn sang, toát mồ hôi.
  _SkitPose? _sulkPose(bool mine) {
    if (skit != null || sulk == 0 || small) return null;
    final sulking = sulk == (mine ? 1 : 2);
    final self = mine ? position : _partnerPosition;
    final other = mine ? _partnerPosition : position;
    final away = other.dx < self.dx;
    return _SkitPose(
      at: self,
      facingRight: sulking ? away : !away,
      tilt: sulking ? (away ? .05 : -.05) : 0,
      mood: sulking ? _SkitMood.angry : null,
    );
  }

  _SkitPose? get _minePose {
    if (roomPlay.mine != null) return roomPlay.mine;
    final frame = _skitFrame;
    if (frame != null) {
      return _mineInstigates ? frame.instigator : frame.target;
    }
    return _sulkPose(true);
  }

  _SkitPose? get _partnerPose {
    if (roomPlay.partner != null) return roomPlay.partner;
    final frame = _skitFrame;
    if (frame != null) {
      return _mineInstigates ? frame.target : frame.instigator;
    }
    return _sulkPose(false);
  }

  /// Nét mặt theo tâm trạng tiểu cảnh, đổi qua dữ liệu (không sửa nét vẽ bé).
  PetCareVitals _skitFace(PetCareVitals care, _SkitMood? mood) {
    final steady = care.copyWith(
      food: math.max(60, care.food),
      clean: math.max(60, care.clean),
      energy: math.max(60, care.energy),
      sleeping: false,
    );
    return switch (mood) {
      null => care,
      _SkitMood.happy => steady.copyWith(joy: 100),
      _SkitMood.angry => steady.copyWith(joy: 35),
      _SkitMood.crying => steady.copyWith(joy: 10),
      _SkitMood.dizzy => steady.copyWith(joy: 62),
    };
  }

  void _paintSkitFx(Canvas c) {
    final frame = _skitFrame;
    if (frame != null) {
      for (final fx in frame.effects) {
        _paintFx(c, fx);
      }
      return;
    }
    if (sulk == 0 || small) return;
    final sulker = sulk == 1 ? position : _partnerPosition;
    final other = sulk == 1 ? _partnerPosition : position;
    final pulse = (seconds * .9) % 1;
    _paintFx(
      c,
      _SkitFx(_SkitFxKind.vein, sulker + Offset(0, -112 * growth), t: pulse),
    );
    _paintFx(
      c,
      _SkitFx(
        _SkitFxKind.sweat,
        other + Offset(0, -112 * growth),
        t: (seconds * .5) % 1,
        flip: other.dx > sulker.dx,
      ),
    );
  }

  void _paintFx(Canvas c, _SkitFx fx) {
    final g = growth;
    switch (fx.kind) {
      case _SkitFxKind.exclaim:
        final pop = Curves.easeOutBack.transform(_seg(fx.t, 0, .35));
        final p = fx.at + Offset(0, -18 * g - pop * 6);
        c.save();
        c.translate(p.dx, p.dy);
        c.scale(pop * g * 1.2);
        _round(c, const Rect.fromLTWH(-5, -26, 10, 18), 5, Colors.white);
        _round(
          c,
          const Rect.fromLTWH(-3.2, -24, 6.4, 14.5),
          3.2,
          const Color(0xFFE5574F),
        );
        _circle(c, const Offset(0, -3), 4.6, Colors.white);
        _circle(c, const Offset(0, -3), 3, const Color(0xFFE5574F));
        c.restore();
      case _SkitFxKind.stars:
        for (var i = 0; i < 3; i++) {
          final angle = seconds * 5 + i * math.pi * 2 / 3;
          final p =
              fx.at +
              Offset(math.cos(angle) * 22 * g, math.sin(angle) * 6 * g - 6 * g);
          _star(c, p, 5.5 * g, const Color(0xFFF4C34E).withValues(alpha: .95));
        }
      case _SkitFxKind.pow:
        final r = (10 + fx.t * 14) * g;
        final burst = Path();
        for (var i = 0; i < 16; i++) {
          final angle = i * math.pi / 8;
          final radius = i.isEven ? r : r * .55;
          final p =
              fx.at +
              Offset(
                math.cos(angle) * radius,
                math.sin(angle) * radius - 8 * g,
              );
          i == 0 ? burst.moveTo(p.dx, p.dy) : burst.lineTo(p.dx, p.dy);
        }
        burst.close();
        final alpha = (1 - _seg(fx.t, .7, 1)).clamp(0.0, 1.0);
        c.drawPath(
          burst,
          Paint()..color = const Color(0xFFFFE07A).withValues(alpha: alpha),
        );
        c.drawPath(
          burst,
          Paint()
            ..color = const Color(0xFFF08A3C).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case _SkitFxKind.dust:
        // Đám bụi hoạt hình: mây cuộn có viền rung lắc, sao, chân tay ló ra
        // và vạch tốc độ quanh mép.
        final grow = Curves.easeOutBack.transform(_seg(fx.t, 0, .2));
        final shrink = 1 - _seg(fx.t, .85, 1);
        final s = grow * shrink * g * 1.55;
        if (s <= .01) return;
        final puffs = <(Offset, double)>[
          for (var i = 0; i < 10; i++)
            (
              fx.at +
                  Offset(
                    math.cos(i * math.pi / 5 + seconds * 2.4) *
                        (36 + math.sin(seconds * 13 + i * 2.1) * 4) *
                        s,
                    math.sin(i * math.pi / 5 + seconds * 2.4) *
                        (24 + math.sin(seconds * 11 + i) * 3) *
                        s,
                  ),
              (17 + (i % 3) * 5) * s,
            ),
        ];
        for (final (p, r) in puffs) {
          _circle(c, p, r + 2.4 * g, const Color(0xFFC9B394));
        }
        _circle(c, fx.at, 40 * s + 2.4 * g, const Color(0xFFC9B394));
        for (final (p, r) in puffs) {
          _circle(c, p, r, const Color(0xFFF3E8D6));
        }
        _circle(c, fx.at, 40 * s, const Color(0xFFFBF4E8));
        // Chân tay hai bé thò ra thụt vào.
        for (var i = 0; i < 4; i++) {
          final out = math.sin(seconds * 9 + i * 1.9).clamp(0.0, 1.0);
          final angle = i * math.pi / 2 + .5 + math.sin(seconds * 3 + i) * .3;
          final p =
              fx.at +
              Offset(
                math.cos(angle) * (40 + out * 12) * s,
                math.sin(angle) * (28 + out * 9) * s,
              );
          final fur = i.isEven
              ? const Color(0xFFFFF9F1)
              : const Color(0xFFB98559);
          _circle(c, p, 8.5 * s, const Color(0xFF8C6F63));
          _circle(c, p, 7 * s, fur);
        }
        for (var i = 0; i < 3; i++) {
          final angle = i * 2.1 + seconds * 3.2;
          _star(
            c,
            fx.at +
                Offset(
                  math.cos(angle) * 30 * s,
                  math.sin(angle) * 18 * s - 6 * s,
                ),
            6.5 * s,
            const Color(0xFFF4C34E),
          );
        }
        // Vạch tốc độ ngắn quanh mép đám bụi.
        final streak = Paint()
          ..color = const Color(0xFF9C8670)
          ..strokeWidth = 2 * g
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + seconds * .8;
          final inner =
              fx.at +
              Offset(math.cos(angle) * 58 * s, math.sin(angle) * 40 * s);
          final outer =
              fx.at +
              Offset(math.cos(angle) * 68 * s, math.sin(angle) * 47 * s);
          c.drawLine(inner, outer, streak);
        }
        final popAt = (seconds * 3).floor() % 4;
        final popAngle = popAt * 1.6 + .4;
        _paintFx(
          c,
          _SkitFx(
            _SkitFxKind.pow,
            fx.at +
                Offset(
                  math.cos(popAngle) * 48 * s,
                  math.sin(popAngle) * 30 * s + 8 * g,
                ),
            t: (seconds * 3) % 1,
          ),
        );
      case _SkitFxKind.sweat:
        final side = fx.flip ? -1.0 : 1.0;
        final fall = fx.t;
        final p =
            fx.at + Offset(side * (22 + fall * 6) * g, (-4 + fall * 10) * g);
        final drop = Path()
          ..moveTo(p.dx, p.dy - 7 * g)
          ..quadraticBezierTo(p.dx + 5 * g, p.dy, p.dx, p.dy + 4 * g)
          ..quadraticBezierTo(p.dx - 5 * g, p.dy, p.dx, p.dy - 7 * g);
        c.drawPath(
          drop,
          Paint()
            ..color = const Color(0xFF8CCBEB).withValues(alpha: 1 - fall * .5),
        );
      case _SkitFxKind.vein:
        // Dấu "giận" kiểu truyện tranh: bốn nét cong quanh một tâm.
        final beat = 1 + math.sin(fx.t * math.pi * 2) * .18;
        final p = fx.at + Offset(20 * g, -6 * g);
        final paint = Paint()
          ..color = const Color(0xFFE5574F)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.6 * g;
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2 + math.pi / 4;
          final center =
              p +
              Offset(
                math.cos(angle) * 6 * g * beat,
                math.sin(angle) * 6 * g * beat,
              );
          c.drawArc(
            Rect.fromCircle(center: center, radius: 4.5 * g * beat),
            angle + math.pi * .55,
            math.pi * .9,
            false,
            paint,
          );
        }
      case _SkitFxKind.heart:
        final rise = fx.t;
        _heart(
          c,
          fx.at + Offset((fx.flip ? -10 : 10) * g, -rise * 26 * g),
          (5 + rise * 2) * g,
          _PetHousePainter._rose.withValues(
            alpha: math.sin(rise * math.pi).clamp(0.0, 1.0),
          ),
        );
      case _SkitFxKind.note:
        final rise = fx.t;
        final p =
            fx.at +
            Offset(
              (fx.flip ? -16 : 16) * g + math.sin(rise * 6) * 3,
              -rise * 24 * g,
            );
        final color = const Color(
          0xFF8C7BC4,
        ).withValues(alpha: math.sin(rise * math.pi).clamp(0.0, 1.0));
        _oval(
          c,
          Rect.fromCenter(center: p, width: 7 * g, height: 5.5 * g),
          color,
        );
        c.drawLine(
          p + Offset(3 * g, 0),
          p + Offset(3 * g, -12 * g),
          Paint()
            ..color = color
            ..strokeWidth = 1.8 * g,
        );
        c.drawLine(
          p + Offset(3 * g, -12 * g),
          p + Offset(8 * g, -9 * g),
          Paint()
            ..color = color
            ..strokeWidth = 1.8 * g,
        );
      case _SkitFxKind.dots:
        _round(
          c,
          Rect.fromCenter(center: fx.at, width: 34 * g, height: 18 * g),
          9 * g,
          Colors.white.withValues(alpha: .92),
        );
        for (var i = 0; i < 3; i++) {
          final on = fx.t * 4 > i + .5;
          _circle(
            c,
            fx.at + Offset((i - 1) * 8.5 * g, 0),
            2.6 * g,
            const Color(0xFF8C7BC4).withValues(alpha: on ? 1 : .25),
          );
        }
      case _SkitFxKind.splash:
        final to = fx.to ?? fx.at;
        for (var i = 0; i < 6; i++) {
          final u = (fx.t * 1.3 - i * .06).clamp(0.0, 1.0);
          if (u <= 0 || u >= 1) continue;
          final p =
              Offset.lerp(fx.at, to, u)! +
              Offset(
                math.sin(i * 1.7) * 6,
                -math.sin(u * math.pi) * 26 * g + (i % 3) * 3,
              );
          _circle(
            c,
            p,
            (3 + (i % 2)) * g,
            const Color(0xFF8CCBEB).withValues(alpha: .9),
          );
        }
      case _SkitFxKind.drips:
        for (var i = 0; i < 3; i++) {
          final fall = (fx.t * 2 + i / 3) % 1;
          final p = fx.at + Offset((i - 1) * 14 * g, (10 + fall * 40) * g);
          _circle(
            c,
            p,
            2.4 * g,
            const Color(0xFF8CCBEB).withValues(alpha: 1 - fall),
          );
        }
      case _SkitFxKind.feathers:
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + .4;
          final spread = Curves.easeOut.transform(fx.t);
          final p =
              fx.at +
              Offset(
                math.cos(angle) * 30 * g * spread,
                math.sin(angle) * 14 * g * spread + fx.t * 20 * g,
              );
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(angle + seconds * 2);
          _oval(
            c,
            Rect.fromCenter(center: Offset.zero, width: 10 * g, height: 4 * g),
            Colors.white.withValues(alpha: (1 - fx.t * .7).clamp(0.0, 1.0)),
          );
          c.restore();
        }
      case _SkitFxKind.pillow:
        c.save();
        c.translate(fx.at.dx, fx.at.dy);
        c.rotate((fx.flip ? 1 : -1) * (-.9 + fx.t * 1.6));
        c.translate(0, -16 * g);
        _round(
          c,
          Rect.fromCenter(center: Offset.zero, width: 30 * g, height: 20 * g),
          9 * g,
          const Color(0xFFF5F0FA),
        );
        _round(
          c,
          Rect.fromCenter(
            center: Offset.zero,
            width: 30 * g,
            height: 20 * g,
          ).deflate(3 * g),
          7 * g,
          const Color(0xFFDCCFF0),
        );
        c.restore();
      case _SkitFxKind.food:
        final scale = .76 * g * (1 - fx.t * .65);
        if (scale <= .1) return;
        _food(c, food, fx.at, scale, bitten: fx.t > .15);
    }
  }
}
