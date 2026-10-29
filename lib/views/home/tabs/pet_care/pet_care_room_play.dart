part of 'pet_care_scene.dart';

/// Bóng trên sàn: mô phỏng cục bộ, tối đa sáu giây một lượt; không giữ timer,
/// không thưởng Hạt và không ghi dữ liệu. Bước nhỏ cố định tránh xuyên tường.
class PetCareBallMotion {
  static const home = Offset(320, 279);
  Offset position = home;
  Offset velocity = Offset.zero;
  double rotation = -.2;
  double elapsed = 0;
  bool active = false;
  bool held = false;
  int bounces = 0;

  static Offset _safe(Offset p, Offset fallback) =>
      p.dx.isFinite && p.dy.isFinite ? p : fallback;
  static Offset _clamp(Offset p) =>
      Offset(p.dx.clamp(24.0, 336.0), p.dy.clamp(176.0, 279.0));

  void hold(Offset point) {
    position = _clamp(_safe(point, position));
    velocity = Offset.zero;
    elapsed = 0;
    held = true;
    active = false;
    bounces = 0;
  }

  void move(Offset point) {
    if (held) position = _clamp(_safe(point, position));
  }

  void launch(Offset speed) {
    final safe = _safe(speed, Offset.zero);
    velocity = Offset(
      safe.dx.clamp(-480.0, 480.0),
      safe.dy.clamp(-260.0, 160.0),
    );
    elapsed = 0;
    held = false;
    active = true;
    bounces = 0;
  }

  /// Chuyền/đá không kéo dài hạn kết thúc của lượt đang diễn.
  void kick(Offset speed) {
    if (!active) return;
    final safe = _safe(speed, Offset.zero);
    velocity = Offset(
      safe.dx.clamp(-360.0, 360.0),
      safe.dy.clamp(-180.0, 80.0),
    );
  }

  void step(double seconds) {
    if (!active || !seconds.isFinite || seconds <= 0) return;
    var remaining = math.min(seconds, 6 - elapsed).clamp(0.0, 6.0);
    while (remaining > .000001 && active) {
      final dt = math.min(remaining, 1 / 120);
      remaining -= dt;
      elapsed += dt;
      var vx = velocity.dx * math.exp(-.75 * dt);
      var vy = velocity.dy + 720 * dt;
      var x = position.dx + vx * dt;
      var y = position.dy + vy * dt;
      if (x < 24 || x > 336) {
        x = x.clamp(24.0, 336.0);
        vx = -vx * .68;
        bounces++;
      }
      if (y < 176) {
        y = 176;
        vy = vy.abs() * .45;
      }
      if (y >= 279) {
        y = 279;
        if (vy > 28) {
          vy = -vy * .48;
          if (vy.abs() > 24) bounces++;
        } else {
          vy = 0;
        }
        vx *= math.exp(-1.5 * dt);
      }
      position = Offset(x, y);
      velocity = Offset(vx, vy);
      rotation += vx * dt / 18;
      if (elapsed >= 6 - .000001) {
        elapsed = 6;
        active = false;
        velocity = Offset.zero;
        position = Offset(position.dx, 279);
      }
    }
  }

  void reset() {
    position = home;
    velocity = Offset.zero;
    rotation = -.2;
    elapsed = 0;
    active = false;
    held = false;
    bounces = 0;
  }
}

/// Một snapshot immutable cho painter; không đọc state đang đổi giữa hai lớp.
class _PetRoomPlayFrame {
  const _PetRoomPlayFrame({
    this.ball = PetCareBallMotion.home,
    this.rotation = -.2,
    this.active = false,
    this.held = false,
    this.inviting = false,
    this.mine,
    this.partner,
    this.missAt,
    this.touchPet,
    this.touchPoint,
    this.touchHead = false,
    this.touchStrength = 0,
    this.cuddle = 0,
    this.spinMine = CompanionSpinFrame.none,
    this.spinPartner = CompanionSpinFrame.none,
    this.guest,
  });
  final Offset ball;
  final double rotation;
  final bool active;
  final bool held;
  final bool inviting;
  final _SkitPose? mine;
  final _SkitPose? partner;
  final Offset? missAt;
  final PetCarePet? touchPet;
  final Offset? touchPoint;
  final bool touchHead;
  final double touchStrength;
  final double cuddle;

  /// Vuốt ngang xoay bé mình/bé kia bằng tay.
  final CompanionSpinFrame spinMine, spinPartner;

  /// Bạn đang ghé chơi phòng khách, null khi không có khách.
  final _PetGuestFrame? guest;
}

extension _PetRoomPlayArt on _PetHousePainter {
  double _touchAmount(PetCarePet pet) =>
      roomPlay.touchPet == pet ? roomPlay.touchStrength : 0;

  /// Xoa đầu thì lim dim và dụi theo ngón tay; chỉ đổi snapshot nét mặt.
  PetCareVitals _touchFace(PetCareVitals care, PetCarePet pet) {
    if (_touchAmount(pet) <= .02) return care;
    return care.copyWith(
      joy: 100,
      energy: roomPlay.touchHead ? 20 : math.max(60, care.energy),
      food: math.max(60, care.food),
      clean: math.max(60, care.clean),
      sleeping: false,
    );
  }

  void _paintRoomPlayFx(Canvas c) {
    final play = roomPlay;
    final miss = play.missAt;
    if (miss != null) {
      _paintFx(
        c,
        _SkitFx(_SkitFxKind.sweat, miss + Offset(14, -105 * growth), t: .5),
      );
    }
    if (play.inviting) {
      // Bé đưa bóng ra, ngước nhìn chờ: hai nhịp mời quanh quả bóng thật.
      for (var i = 0; i < 2; i++) {
        final t = (seconds * .8 + i / 2) % 1;
        _oval(
          c,
          Rect.fromCenter(
            center: Offset(play.ball.dx, 277),
            width: 38 + t * 26,
            height: 8 + t * 7,
          ),
          _PetHousePainter._gold.withValues(alpha: (1 - t) * .5),
          stroke: 1.5,
        );
      }
    }
    if (play.cuddle > .4 && play.partner != null) {
      final center = Offset(
        (position.dx + play.partner!.at.dx) / 2,
        position.dy - 105 * growth,
      );
      _heart(
        c,
        center,
        9 * play.cuddle,
        _PetHousePainter._rose.withValues(alpha: play.cuddle),
      );
    }
    final point = play.touchPoint;
    final power = play.touchStrength;
    if (point == null || power <= .01) return;
    for (var i = 0; i < 3; i++) {
      final t = (seconds * 1.2 + i / 3) % 1;
      final at = point + Offset((i - 1) * 15.0, -8 - t * 29);
      if (play.touchHead) {
        _heart(
          c,
          at,
          (3 + math.sin(t * math.pi) * 2) * power,
          _PetHousePainter._rose.withValues(alpha: (1 - t) * power),
        );
      } else {
        _star(
          c,
          at,
          (3 + math.sin(t * math.pi) * 2) * power,
          _PetHousePainter._gold.withValues(alpha: (1 - t) * power),
        );
      }
    }
  }
}
