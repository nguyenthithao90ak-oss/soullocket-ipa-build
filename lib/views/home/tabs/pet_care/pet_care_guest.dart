part of 'pet_care_scene.dart';

/// Bạn ghé chơi: Mèo Mây hoặc Chuột Phô Mai (đã mở khóa) thỉnh thoảng ghé
/// phòng khách, mỗi lần một bé nên trong phòng tối đa ba bé. Màn cha quyết
/// định lúc tới/về và quà Hạt; scene chỉ diễn: đi vào, vẫy chào, xin bánh,
/// ăn, vui, vẫy chào rồi về. Bé khách không có chỉ số đói/bẩn, không lưu gì.
enum _GuestBubble { none, hello, cookie, heart }

abstract final class _PetGuestTiming {
  /// Đi vào hoặc đi ra khỏi phòng.
  static const walk = 2.6;

  /// Vẫy chào sau khi tới.
  static const hello = 2.2;

  /// Bánh bay vào miệng rồi nhai.
  static const eat = 2.6;

  /// Nhảy mừng sau khi ăn.
  static const happy = 2.2;

  /// Vẫy chào trước khi quay đi.
  static const bye = .9;

  /// Được cưng: mắt tim, vẫy tay.
  static const pet = 1.6;
}

class _PetGuestVisit {
  _PetGuestVisit({
    required this.character,
    required this.startAt,
    required this.spot,
    required this.animated,
  }) : fromX = spot.dx < 180 ? -48 : 408;

  final HomeCompanionCharacter character;
  final double startAt;
  final Offset spot;

  /// Đi vào từ mép phòng gần chỗ đứng.
  final double fromX;
  final bool animated;
  double? treatAt;
  double? leaveAt;
  double petAt = -100;
  bool treatReported = false;
  bool leftReported = false;

  bool get treated => treatAt != null;

  bool arrivedAt(double now) =>
      leaveAt == null && (!animated || now - startAt >= _PetGuestTiming.walk);

  /// Xong phần ăn bánh (để báo màn cha tặng quà).
  bool doneEatingAt(double now) =>
      treatAt != null && (!animated || now - treatAt! >= _PetGuestTiming.eat);

  bool goneAt(double now) =>
      leaveAt != null &&
      (!animated ||
          now - leaveAt! >= _PetGuestTiming.bye + _PetGuestTiming.walk);

  _PetGuestFrame frameAt(
    double now, {
    required _PetSceneMotion motion,
    required CompanionSpinFrame spin,
    required double growth,
  }) {
    final t = now - startAt;
    final walkIn = animated ? (t / _PetGuestTiming.walk).clamp(0.0, 1.0) : 1.0;
    final leave = leaveAt == null ? null : now - leaveAt!;
    final walkOut = leave == null || !animated
        ? 0.0
        : ((leave - _PetGuestTiming.bye) / _PetGuestTiming.walk).clamp(
            0.0,
            1.0,
          );
    final inEase = Curves.easeOutSine.transform(walkIn);
    final outEase = Curves.easeInSine.transform(walkOut);
    final x = leave == null || walkOut <= 0
        ? fromX + (spot.dx - fromX) * inEase
        : spot.dx + (fromX - spot.dx) * outEase;
    final walkingIn = walkIn < 1;
    final walkingOut = walkOut > 0 && walkOut < 1;
    final distance = (spot.dx - fromX).abs();
    final arrived = t - (animated ? _PetGuestTiming.walk : 0);

    final eatT = treatAt == null ? null : now - treatAt!;
    final eaten = eatT != null && (!animated || eatT >= _PetGuestTiming.eat);
    final happyT = eaten && animated ? eatT - _PetGuestTiming.eat : null;
    final cheer = happyT != null && happyT < _PetGuestTiming.happy
        ? math.sin(happyT / _PetGuestTiming.happy * math.pi).clamp(0.0, 1.0)
        : 0.0;
    final hello = animated && arrived >= 0 && arrived < _PetGuestTiming.hello
        ? 1 - arrived / _PetGuestTiming.hello
        : 0.0;
    final bye = leave != null && animated && leave < _PetGuestTiming.bye
        ? 1 - leave / _PetGuestTiming.bye
        : 0.0;
    final petT = now - petAt;
    final pet = petT >= 0 && petT < _PetGuestTiming.pet
        ? 1 - petT / _PetGuestTiming.pet
        : 0.0;

    final bubble = leave != null
        ? (leave < _PetGuestTiming.bye + .5
              ? _GuestBubble.hello
              : _GuestBubble.none)
        : walkingIn && walkIn < .7
        ? _GuestBubble.none
        : eatT != null && !eaten
        ? _GuestBubble.none
        : pet > 0 || cheer > 0 || (eaten && !animated)
        ? _GuestBubble.heart
        : hello > .35
        ? _GuestBubble.hello
        : treated
        ? _GuestBubble.none
        : _GuestBubble.cookie;
    final bubbleAlpha = leave != null
        ? (1 - (leave - _PetGuestTiming.bye) / .5).clamp(0.0, 1.0)
        : walkingIn
        ? ((walkIn - .7) / .3).clamp(0.0, 1.0)
        : 1.0;
    final opacity = walkingIn
        ? (walkIn / .12).clamp(0.0, 1.0)
        : walkOut > .8
        ? (1 - (walkOut - .8) / .2).clamp(0.0, 1.0)
        : 1.0;
    final facingRight = walkingIn
        ? spot.dx > fromX
        : walkingOut
        ? fromX > spot.dx
        // Đứng thì hướng vào giữa phòng, về phía hai bé chủ nhà.
        : spot.dx < 180;
    return _PetGuestFrame(
      motion: motion,
      character: character,
      at: Offset(x, spot.dy),
      facingRight: facingRight,
      walking: walkingIn || walkingOut,
      stride: walkingIn
          ? distance * inEase / 48
          : walkingOut
          ? distance * outEase / 48
          : 0,
      opacity: opacity,
      eating: eatT != null && animated && eatT >= .35 && !eaten ? 1 : 0,
      cookie: eatT == null || !animated
          ? 0
          : (eatT / _PetGuestTiming.eat).clamp(0.0, 1.0),
      cheer: cheer,
      cuddle: math.max(math.max(hello, bye), pet),
      lift: cheer * math.sin((happyT ?? 0) * 9).abs() * 3,
      growth: growth,
      bubble: bubble,
      bubbleAlpha: bubbleAlpha,
      spin: spin,
      seconds: now * .78 + 3.7,
    );
  }
}

/// Một khung hình của bé khách cho lớp vẽ.
@immutable
class _PetGuestFrame {
  const _PetGuestFrame({
    required this.motion,
    required this.character,
    required this.at,
    required this.facingRight,
    required this.walking,
    required this.stride,
    required this.opacity,
    required this.eating,
    required this.cookie,
    required this.cheer,
    required this.cuddle,
    required this.lift,
    required this.growth,
    required this.bubble,
    required this.bubbleAlpha,
    required this.spin,
    required this.seconds,
  });

  final _PetSceneMotion motion;
  final HomeCompanionCharacter character;
  final Offset at;
  final bool facingRight, walking;
  final double stride, opacity, eating;

  /// 0 → 1 trong lúc ăn: bánh bay vào miệng rồi bị cắn dần.
  final double cookie;
  final double cheer, cuddle, lift, growth;
  final _GuestBubble bubble;
  final double bubbleAlpha;
  final CompanionSpinFrame spin;
  final double seconds;

  /// Chiều cao bé khách tính tới đỉnh tai (đơn vị sân khấu).
  double get height => 124 * growth;
}

extension _PetGuestArt on _PetHousePainter {
  static const _guestRoomScale = 2.3;

  void _guestPet(Canvas c) {
    final g = roomPlay.guest;
    if (g == null || g.opacity <= .01) return;
    final faded = g.opacity < .99;
    if (faded) {
      c.saveLayer(
        const Rect.fromLTWH(-90, -80, 540, 440),
        Paint()..color = Color.fromRGBO(0, 0, 0, g.opacity),
      );
    }
    c.save();
    c.translate(g.at.dx, g.at.dy - g.lift);
    final scale = _guestRoomScale * g.growth;
    c.scale(scale, scale);
    c.translate(-180, -260);
    g.motion
      ..walking = g.walking
      ..hopping = false
      ..walkWeight = g.walking ? 1 : 0
      ..strideCycles = g.stride
      ..cuddle = g.cuddle
      ..lift = 0
      ..cheering = g.cheer > 0
      ..cheer = g.cheer
      ..gameFacingRight = g.facingRight
      ..seconds = g.seconds
      ..spin = g.spin;
    HomeCompanionPainter(
      motion: g.motion,
      darkMode: dark,
      character: g.character,
      showEffects: true,
      eating: g.eating,
      mouthOpen: g.cookie > 0 && g.cookie < .14 ? .6 : 0,
    ).paint(c, const Size(360, 300));
    c.restore();
    _guestCookie(c, g);
    _guestBubble(c, g);
    if (faded) c.restore();
  }

  Offset _guestBubbleAt(_PetGuestFrame g) => Offset(
    (g.at.dx + (g.facingRight ? 30 : -30) * g.growth).clamp(24.0, 336.0),
    g.at.dy - g.lift - g.height - 6,
  );

  Offset _guestMouth(_PetGuestFrame g) => Offset(
    g.at.dx + (g.facingRight ? 9 : -9) * g.growth,
    g.at.dy - g.lift - 66 * g.growth,
  );

  /// Bánh quy bay từ bong bóng vào miệng rồi nhỏ dần theo từng miếng cắn.
  void _guestCookie(Canvas c, _PetGuestFrame g) {
    if (g.cookie <= 0 || g.cookie >= 1) return;
    final fly = Curves.easeInOutSine.transform(
      (g.cookie / .14).clamp(0.0, 1.0),
    );
    final at = Offset.lerp(_guestBubbleAt(g), _guestMouth(g), fly)!;
    final bite = ((g.cookie - .14) / .86).clamp(0.0, 1.0);
    final size = (20 - bite * 9) * g.growth.clamp(.7, 1.1);
    PetCareFoodPaint.paint(c, '🍪', at, size, bite: bite);
    if (bite > 0) {
      // Vụn bánh rơi lả tả.
      for (var i = 0; i < 3; i++) {
        final phase = (g.seconds * 2.1 + i / 3) % 1;
        _circle(
          c,
          at + Offset((i - 1) * 4.0, 4 + phase * 14),
          1.4 * (1 - phase),
          const Color(0xFFC98F4E).withValues(alpha: .8 * (1 - phase)),
        );
      }
    }
  }

  /// Bong bóng nhỏ trên đầu khách: vẫy chào, xin bánh hoặc trái tim.
  void _guestBubble(Canvas c, _PetGuestFrame g) {
    if (g.bubble == _GuestBubble.none || g.bubbleAlpha <= .01) return;
    final bob = math.sin(g.seconds * 3.2) * 1.6;
    final center = _guestBubbleAt(g) + Offset(0, bob);
    final pulse = g.bubble == _GuestBubble.cookie
        ? 1 + math.sin(g.seconds * 4.4).abs() * .06
        : 1.0;
    final r = 15.5 * pulse;
    final alpha = g.bubbleAlpha;
    final tailDir = g.facingRight ? -1.0 : 1.0;
    final bubble = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r))
      ..moveTo(center.dx + tailDir * 4, center.dy + r - 2)
      ..lineTo(center.dx + tailDir * 10, center.dy + r + 7)
      ..lineTo(center.dx + tailDir * 11, center.dy + r - 5)
      ..close();
    c.drawPath(
      bubble.shift(const Offset(0, 1.6)),
      Paint()..color = const Color(0xFF8E6F86).withValues(alpha: .16 * alpha),
    );
    c.drawPath(
      bubble,
      Paint()..color = Colors.white.withValues(alpha: .96 * alpha),
    );
    c.drawPath(
      bubble,
      Paint()
        ..color = const Color(0xFFE6C7D6).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final emoji = switch (g.bubble) {
      _GuestBubble.hello => '👋',
      _GuestBubble.cookie => '🍪',
      _GuestBubble.heart => '💗',
      _GuestBubble.none => '',
    };
    if (alpha < .99) {
      c.saveLayer(
        Rect.fromCircle(center: center, radius: r + 2),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
    }
    final wave = g.bubble == _GuestBubble.hello
        ? math.sin(g.seconds * 11) * .28
        : 0.0;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(wave);
    PetCareFoodPaint.paint(c, emoji, Offset.zero, 18);
    c.restore();
    if (alpha < .99) c.restore();
  }
}
