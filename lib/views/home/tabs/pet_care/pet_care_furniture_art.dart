part of 'pet_care_room_theme.dart';

/// Bộ nội thất: ngoài màu, mỗi bộ có dáng và họa tiết riêng vẽ chồng lên
/// sofa, ghế, bàn ăn, bồn tắm và giường. Giữ tên món cũ trong dữ liệu để
/// món đã mua không mất.
enum PetCareFurnitureSet {
  classic,

  /// Bánh kem dâu: kem phủ chảy giọt, quả anh đào, cốm màu.
  cake,

  /// Rừng lá: lá non mọc lên, chân gỗ khúc, nấm đỏ.
  forest,

  /// Công chúa: vương miện, viền vàng, nệm chần nút, màn voan.
  princess,

  /// Mây bông: viền mây phồng, sao nhỏ, chân bông.
  cloud,

  /// Ong mật: mật chảy giọt, tổ ong lục giác, chú ong bay.
  honey,

  /// Mèo con: tai mèo, mặt mèo, dấu chân, chân móng mèo.
  kitty;

  static PetCareFurnitureSet of(PetCareRoomItem item) => switch (item) {
    PetCareRoomItem.furniturePeach => cake,
    PetCareRoomItem.furnitureMint => forest,
    PetCareRoomItem.furnitureLilac => princess,
    PetCareRoomItem.furnitureSky => cloud,
    PetCareRoomItem.furnitureHoney => honey,
    PetCareRoomItem.furnitureCocoa => kitty,
    _ => classic,
  };
}

/// Hình vẽ riêng của từng bộ nội thất, dùng chung cho cảnh phòng và ô xem
/// trước. Mọi hàm bỏ qua bộ "gốc" để phòng giữ nguyên như cũ.
abstract final class PetCareFurnitureArt {
  static const _icing = Color(0xFFFFFBF3);
  static const _icingShade = Color(0xFFEFD3C4);
  static const _cherryRed = Color(0xFFE5506A);
  static const _leaf = Color(0xFF79B97C);
  static const _leafLight = Color(0xFFA6D69A);
  static const _leafDark = Color(0xFF5A9862);
  static const _bark = Color(0xFF9C6B4E);
  static const _barkLight = Color(0xFFC99C76);
  static const _gold = Color(0xFFE9B949);
  static const _goldLight = Color(0xFFFFE08A);
  static const _goldDark = Color(0xFFBF8A2E);
  static const _jewel = Color(0xFFF07FA6);
  static const _cloud = Color(0xFFFFFFFF);
  static const _cloudShade = Color(0xFFCFE3F5);
  static const _starColor = Color(0xFFFFD970);
  static const _honey = Color(0xFFF2B23E);
  static const _honeyDark = Color(0xFFD38A1E);
  static const _beeYellow = Color(0xFFFFD45A);
  static const _beeStripe = Color(0xFF4F3E3E);
  static const _earPink = Color(0xFFF6B3C3);
  static const _nose = Color(0xFFE98AA4);
  static const _ink = Color(0xFF6F5550);
  static const _sprinkles = [
    Color(0xFFF58DAE),
    Color(0xFFF7CF5E),
    Color(0xFF7FD0B4),
    Color(0xFF86B3EE),
    Color(0xFFB998EC),
  ];

  static Color _dim(Color color, bool dark) =>
      dark ? Color.lerp(color, const Color(0xFF2E2838), .3)! : color;

  // ---- Các phần gắn lên đồ nội thất ----

  /// Đỉnh một tấm ván đứng (đầu/chân giường, lưng ghế): kem phủ + anh đào,
  /// lá non, vương miện, mũ mây, mật + ong, tai và mặt mèo. [size] mặc định
  /// bằng bề ngang tấm ván.
  static void boardTop(
    Canvas c,
    Rect board,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    double? size,
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    final s = size ?? board.width;
    final cx = board.center.dx;
    final top = board.top;
    switch (set) {
      case PetCareFurnitureSet.classic:
        return;
      case PetCareFurnitureSet.cake:
        _drips(
          c,
          Rect.fromLTWH(board.left - 1, top - 2, board.width + 2, s * .55),
          k(_icing),
          k(_icingShade),
          seed: 2,
        );
        _sprinkleDots(
          c,
          Rect.fromLTWH(board.left + 2, top, board.width - 4, s * .16),
          dark,
        );
        _cherry(c, Offset(cx, top - s * .16), s * .2, dark);
      case PetCareFurnitureSet.forest:
        _line(
          c,
          Offset(cx, top + 2),
          Offset(cx, top - s * .3),
          k(_bark),
          math.max(1.2, s * .07),
        );
        _leafShape(c, Offset(cx, top - s * .22), s * .62, -.95, k(_leaf));
        _leafShape(c, Offset(cx, top - s * .28), s * .56, .8, k(_leafLight));
        _leafShape(c, Offset(cx, top - s * .3), s * .42, -.05, k(_leafDark));
      case PetCareFurnitureSet.princess:
        _crown(c, Offset(cx, top + 1), s, dark);
      case PetCareFurnitureSet.cloud:
        _cloudPuff(
          c,
          Rect.fromLTWH(cx - s * .62, top - s * .34, s * 1.24, s * .52),
          k(_cloud),
          k(_cloudShade),
        );
        _star(c, Offset(cx + s * .52, top - s * .42), s * .14, k(_starColor));
      case PetCareFurnitureSet.honey:
        _drips(
          c,
          Rect.fromLTWH(board.left - 1, top - 2, board.width + 2, s * .5),
          k(_honey),
          k(_honeyDark),
          seed: 3,
        );
        _bee(c, Offset(cx + s * .48, top - s * .4), s * .22, dark);
      case PetCareFurnitureSet.kitty:
        final ear = math.min(s * .5, board.width * .5);
        _catEar(
          c,
          Offset(board.left + ear * .5, top + 2),
          ear,
          -.18,
          tone,
          dark,
        );
        _catEar(
          c,
          Offset(board.right - ear * .5, top + 2),
          ear,
          .18,
          tone,
          dark,
        );
        if (board.height > board.width * .9) {
          _catFace(
            c,
            Offset(cx, top + board.width * .5),
            board.width * .7,
            dark,
          );
        }
    }
  }

  /// Mép trên một món nằm ngang (lưng sofa): đồ trang trí nhô lên khỏi mép.
  static void edgeTrim(
    Canvas c,
    Rect edge,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    final top = edge.top;
    final l = edge.left;
    final r = edge.right;
    final w = edge.width;
    final cx = edge.center.dx;
    switch (set) {
      case PetCareFurnitureSet.classic:
        return;
      case PetCareFurnitureSet.cake:
        _drips(
          c,
          Rect.fromLTWH(l, top - 3, w, 19),
          k(_icing),
          k(_icingShade),
          seed: 1,
        );
        _sprinkleDots(c, Rect.fromLTWH(l + 6, top - 1, w - 12, 5), dark);
        for (final x in [l + w * .18, cx, l + w * .82]) {
          _cherry(c, Offset(x, top - 6), 5, dark);
        }
      case PetCareFurnitureSet.forest:
        var i = 0;
        for (var x = l + 8; x < r - 6; x += 13, i++) {
          _leafShape(
            c,
            Offset(x, top + 4),
            15 + (i % 3) * 3.0,
            i.isEven ? -.42 : .38,
            k(i % 3 == 0 ? _leafDark : (i.isEven ? _leaf : _leafLight)),
          );
        }
        _mushroom(c, Offset(r - 2, top + 6), 13, dark);
        _mushroom(c, Offset(l + 4, top + 6), 9, dark);
      case PetCareFurnitureSet.princess:
        _line(
          c,
          Offset(l + 4, top + 2.5),
          Offset(r - 4, top + 2.5),
          k(_gold),
          2.4,
        );
        for (var x = l + 8; x < r - 4; x += 9) {
          _circle(c, Offset(x, top + 2.5), 1.5, k(_goldLight));
        }
        _crown(c, Offset(cx, top + 1), 34, dark);
      case PetCareFurnitureSet.cloud:
        for (var x = l + 9; x <= r - 9; x += 17) {
          _cloudBump(c, Offset(x, top + 4), 10, k(_cloud), k(_cloudShade));
        }
        _star(c, Offset(l + w * .2, top - 14), 4.5, k(_starColor));
        _star(c, Offset(l + w * .78, top - 17), 3.5, k(_starColor));
      case PetCareFurnitureSet.honey:
        _drips(
          c,
          Rect.fromLTWH(l, top - 3, w, 20),
          k(_honey),
          k(_honeyDark),
          seed: 4,
        );
        _bee(c, Offset(l + w * .74, top - 15), 7, dark);
        _hexagon(c, Offset(l + w * .24, top - 9), 6, k(_honey));
        _hexagon(c, Offset(l + w * .24, top - 9), 3.4, k(_goldLight));
      case PetCareFurnitureSet.kitty:
        _catEar(c, Offset(l + 16, top + 3), 24, -.22, tone, dark);
        _catEar(c, Offset(r - 16, top + 3), 24, .22, tone, dark);
        _catFace(c, Offset(cx, top + 4), 20, dark);
    }
  }

  /// Họa tiết trên thanh ngang mỏng (thành bồn, thành giường, mặt quầy,
  /// mặt bàn): treo xuống dưới, không che bé đứng phía sau.
  static void rimTrim(
    Canvas c,
    Rect rim,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    final cy = rim.center.dy;
    switch (set) {
      case PetCareFurnitureSet.classic:
        return;
      case PetCareFurnitureSet.cake:
        _drips(
          c,
          Rect.fromLTWH(rim.left + 3, rim.top, rim.width - 6, rim.height + 11),
          k(_icing),
          k(_icingShade),
          seed: 5,
        );
        _sprinkleDots(
          c,
          Rect.fromLTWH(rim.left + 8, rim.top + 1, rim.width - 16, 4),
          dark,
        );
      case PetCareFurnitureSet.forest:
        final vine = Path()..moveTo(rim.left + 4, cy);
        for (var x = rim.left + 4; x < rim.right - 4; x += 16) {
          vine.quadraticBezierTo(x + 4, cy - 3, x + 8, cy);
          vine.quadraticBezierTo(x + 12, cy + 3, x + 16, cy);
        }
        _path(c, vine, k(_leafDark), width: 1.4);
        var i = 0;
        for (var x = rim.left + 10; x < rim.right - 8; x += 12, i++) {
          _leafShape(
            c,
            Offset(x, cy),
            8,
            i.isEven ? -.9 : 2.3,
            k(i.isEven ? _leaf : _leafLight),
          );
        }
      case PetCareFurnitureSet.princess:
        _line(
          c,
          Offset(rim.left + 4, cy),
          Offset(rim.right - 4, cy),
          k(_gold),
          2,
        );
        for (var x = rim.left + 8; x < rim.right - 4; x += 8) {
          _circle(c, Offset(x, cy), 1.4, k(_goldLight));
        }
      case PetCareFurnitureSet.cloud:
        for (var x = rim.left + 7; x < rim.right - 4; x += 11) {
          _circle(c, Offset(x, rim.bottom), 5.2, k(_cloudShade));
          _circle(c, Offset(x, rim.bottom - .8), 4.8, k(_cloud));
        }
      case PetCareFurnitureSet.honey:
        _drips(
          c,
          Rect.fromLTWH(rim.left + 3, rim.top, rim.width - 6, rim.height + 12),
          k(_honey),
          k(_honeyDark),
          seed: 6,
        );
      case PetCareFurnitureSet.kitty:
        var i = 0;
        for (var x = rim.left + 12; x < rim.right - 8; x += 20, i++) {
          _paw(
            c,
            Offset(x, cy + (i.isEven ? 0 : .6)),
            math.min(3.4, rim.height * .34),
            k(tone.shade).withValues(alpha: .8),
          );
        }
    }
  }

  /// Hoa văn trong tấm nệm/cánh tủ/thân bồn (cắt theo khung).
  static void panel(
    Canvas c,
    RRect frame,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    bool dark = false,
  }) {
    if (set == PetCareFurnitureSet.classic) return;
    Color k(Color color) => _dim(color, dark);
    final b = frame.outerRect;
    c.save();
    c.clipRRect(frame);
    switch (set) {
      case PetCareFurnitureSet.classic:
        break;
      case PetCareFurnitureSet.cake:
        var i = 0;
        for (var y = b.top + 4; y < b.bottom; y += 7) {
          for (var x = b.left + 3 + (i % 3) * 2; x < b.right; x += 9, i++) {
            c.save();
            c.translate(x, y + (i % 2) * 2);
            c.rotate(i * 1.3);
            _round(
              c,
              const Rect.fromLTWH(-2.2, -.8, 4.4, 1.6),
              .8,
              k(_sprinkles[i % _sprinkles.length]),
            );
            c.restore();
          }
        }
      case PetCareFurnitureSet.forest:
        var i = 0;
        for (var y = b.top + 10; y < b.bottom + 6; y += 12) {
          for (var x = b.left + 6 + (i % 2) * 6; x < b.right; x += 13, i++) {
            _leafShape(
              c,
              Offset(x, y),
              8,
              i.isEven ? -.6 : .6,
              k(_leafDark).withValues(alpha: .38),
            );
          }
        }
      case PetCareFurnitureSet.princess:
        final line = k(tone.shade).withValues(alpha: .5);
        const gap = 12.0;
        for (var d = -b.height; d < b.width + b.height; d += gap) {
          _line(
            c,
            Offset(b.left + d, b.top),
            Offset(b.left + d + b.height, b.bottom),
            line,
            .9,
          );
          _line(
            c,
            Offset(b.left + d, b.bottom),
            Offset(b.left + d + b.height, b.top),
            line,
            .9,
          );
        }
        for (var y = b.top; y <= b.bottom + gap; y += gap) {
          final row = ((y - b.top) / gap).round();
          for (
            var x = b.left + (row.isOdd ? gap / 2 : 0);
            x <= b.right + gap;
            x += gap
          ) {
            _circle(c, Offset(x, y), 1.5, k(_gold));
          }
        }
      case PetCareFurnitureSet.cloud:
        var i = 0;
        for (var y = b.top + 8; y < b.bottom + 6; y += 15) {
          for (var x = b.left + 8 + (i % 2) * 9; x < b.right; x += 20, i++) {
            if (i % 3 == 2) {
              _star(c, Offset(x, y), 2.4, k(_starColor));
            } else {
              _cloudPuff(
                c,
                Rect.fromCenter(center: Offset(x, y), width: 12, height: 6),
                k(_cloud).withValues(alpha: .85),
                null,
              );
            }
          }
        }
      case PetCareFurnitureSet.honey:
        const r = 5.0;
        final dx = r * math.sqrt(3);
        var row = 0;
        for (var y = b.top; y < b.bottom + r * 2; y += r * 1.5, row++) {
          var col = 0;
          for (
            var x = b.left + (row.isOdd ? dx / 2 : 0);
            x < b.right + dx;
            x += dx, col++
          ) {
            if ((row + col * 2) % 5 == 0) {
              _hexagon(
                c,
                Offset(x, y),
                r - .6,
                k(_honey).withValues(alpha: .55),
              );
            }
            _hexagon(
              c,
              Offset(x, y),
              r - .4,
              k(_honeyDark).withValues(alpha: .4),
              stroke: .8,
            );
          }
        }
      case PetCareFurnitureSet.kitty:
        var i = 0;
        for (var y = b.top + 8; y < b.bottom + 6; y += 14) {
          for (var x = b.left + 7 + (i % 2) * 8; x < b.right; x += 16, i++) {
            _paw(c, Offset(x, y), 3, k(tone.shade).withValues(alpha: .42));
          }
        }
    }
    c.restore();
  }

  /// Chân đồ trong khung [foot]: cốc giấy cupcake, khúc gỗ, chân vàng có
  /// bi, cụm mây, chân lục giác mật ong, chân móng mèo.
  static void foot(
    Canvas c,
    Rect foot,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    final cx = foot.center.dx;
    final w = foot.width;
    switch (set) {
      case PetCareFurnitureSet.classic:
        return;
      case PetCareFurnitureSet.cake:
        final cup = Path()
          ..moveTo(foot.left - 1.5, foot.top + 2)
          ..lineTo(foot.right + 1.5, foot.top + 2)
          ..lineTo(foot.right - w * .12, foot.bottom)
          ..lineTo(foot.left + w * .12, foot.bottom)
          ..close();
        _path(c, cup, k(const Color(0xFFF58DAE)));
        for (var i = 1; i < 4; i++) {
          final x = foot.left + w * i / 4;
          _line(
            c,
            Offset(x, foot.top + 3),
            Offset(cx + (x - cx) * .8, foot.bottom - 1),
            Colors.white.withValues(alpha: .55),
            .8,
          );
        }
        _round(
          c,
          Rect.fromLTWH(foot.left - 2, foot.top, w + 4, 4),
          2,
          k(_icing),
        );
      case PetCareFurnitureSet.forest:
        _round(c, foot, 2.5, k(_bark));
        for (var i = 1; i < 3; i++) {
          _line(
            c,
            Offset(foot.left + w * i / 3, foot.top + 3),
            Offset(foot.left + w * i / 3, foot.bottom - 2),
            k(const Color(0xFF7E533B)),
            .8,
          );
        }
        _oval(c, Rect.fromLTWH(foot.left, foot.top - 1.5, w, 4), k(_barkLight));
        _circle(c, Offset(cx, foot.top + .5), w * .14, k(_bark));
      case PetCareFurnitureSet.princess:
        final leg = Path()
          ..moveTo(foot.left + w * .1, foot.top)
          ..lineTo(foot.right - w * .1, foot.top)
          ..lineTo(cx + w * .2, foot.bottom - w * .45)
          ..lineTo(cx - w * .2, foot.bottom - w * .45)
          ..close();
        _path(c, leg, k(_gold));
        _circle(c, Offset(cx, foot.bottom - w * .32), w * .42, k(_goldDark));
        _circle(c, Offset(cx, foot.bottom - w * .36), w * .36, k(_gold));
        _circle(
          c,
          Offset(cx - w * .12, foot.bottom - w * .48),
          w * .1,
          k(_goldLight),
        );
      case PetCareFurnitureSet.cloud:
        _round(
          c,
          Rect.fromLTWH(cx - w * .25, foot.top, w * .5, foot.height * .6),
          2,
          k(tone.shade),
        );
        final r = w * .42;
        for (final dx in [-r * .55, r * .55]) {
          _circle(c, Offset(cx + dx, foot.bottom - r * .8), r, k(_cloudShade));
          _circle(c, Offset(cx + dx, foot.bottom - r * .95), r * .9, k(_cloud));
        }
        _circle(c, Offset(cx, foot.bottom - r * 1.3), r * .85, k(_cloud));
      case PetCareFurnitureSet.honey:
        _round(
          c,
          Rect.fromLTWH(cx - w * .22, foot.top, w * .44, foot.height * .7),
          2,
          k(_honeyDark),
        );
        _hexagon(c, Offset(cx, foot.bottom - w * .45), w * .55, k(_honey));
        _hexagon(c, Offset(cx, foot.bottom - w * .45), w * .3, k(_goldLight));
      case PetCareFurnitureSet.kitty:
        _round(
          c,
          Rect.fromLTWH(cx - w * .3, foot.top, w * .6, foot.height * .75),
          2,
          k(tone.main),
        );
        final paw = Rect.fromCenter(
          center: Offset(cx, foot.bottom - w * .32),
          width: w * 1.3,
          height: w * .7,
        );
        _oval(c, paw.inflate(.8), k(tone.shade));
        _oval(c, paw, k(tone.light));
        for (final dx in [-w * .22, 0.0, w * .22]) {
          _line(
            c,
            Offset(cx + dx, paw.top + paw.height * .45),
            Offset(cx + dx, paw.bottom - .5),
            k(tone.shade),
            .8,
          );
        }
    }
  }

  /// Biểu tượng nhỏ của bộ (giữa thân bồn tắm, ô xem trước).
  static void emblem(
    Canvas c,
    Offset p,
    double size,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    switch (set) {
      case PetCareFurnitureSet.classic:
        return;
      case PetCareFurnitureSet.cake:
        _path(
          c,
          Path()
            ..moveTo(p.dx - size * .35, p.dy + size * .1)
            ..quadraticBezierTo(
              p.dx - size * .2,
              p.dy - size * .55,
              p.dx + size * .05,
              p.dy - size * .62,
            )
            ..moveTo(p.dx + size * .35, p.dy + size * .1)
            ..quadraticBezierTo(
              p.dx + size * .2,
              p.dy - size * .4,
              p.dx + size * .05,
              p.dy - size * .62,
            ),
          k(_leafDark),
          width: 1,
        );
        _leafShape(
          c,
          Offset(p.dx + size * .05, p.dy - size * .6),
          size * .45,
          1.2,
          k(_leaf),
        );
        _cherry(
          c,
          Offset(p.dx - size * .35, p.dy + size * .28),
          size * .3,
          dark,
        );
        _cherry(
          c,
          Offset(p.dx + size * .35, p.dy + size * .28),
          size * .3,
          dark,
        );
      case PetCareFurnitureSet.forest:
        _leafShape(c, p + Offset(0, size * .5), size * 1.1, -.6, k(_leaf));
        _leafShape(c, p + Offset(0, size * .5), size * .95, .6, k(_leafLight));
      case PetCareFurnitureSet.princess:
        _crown(c, p + Offset(0, size * .38), size * 1.4, dark);
      case PetCareFurnitureSet.cloud:
        _cloudPuff(
          c,
          Rect.fromCenter(center: p, width: size * 1.6, height: size * .8),
          k(_cloud),
          k(_cloudShade),
        );
        _star(
          c,
          p + Offset(size * .55, -size * .45),
          size * .25,
          k(_starColor),
        );
      case PetCareFurnitureSet.honey:
        _bee(c, p, size * .7, dark);
      case PetCareFurnitureSet.kitty:
        final head = Rect.fromCenter(
          center: p,
          width: size * 1.5,
          height: size * 1.2,
        );
        _catEar(
          c,
          Offset(p.dx - size * .42, p.dy - size * .3),
          size * .6,
          -.25,
          tone,
          dark,
        );
        _catEar(
          c,
          Offset(p.dx + size * .42, p.dy - size * .3),
          size * .6,
          .25,
          tone,
          dark,
        );
        _oval(c, head.inflate(.8), k(tone.shade));
        _oval(c, head, k(tone.light));
        _catFace(c, p + Offset(0, size * .05), size * 1.1, dark);
    }
  }

  /// Màn voan buông hai bên đầu giường có mái vòm và vương miện (bộ công
  /// chúa). [top] là đỉnh vòm, rộng [width], buông xuống [drop].
  static void canopy(
    Canvas c,
    Offset top,
    double width,
    double drop,
    PetCareTone tone, {
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    final cx = top.dx;
    final y = top.dy;
    final half = width / 2;
    final veil = k(Color.lerp(tone.light, Colors.white, .45)!);
    final fold = k(tone.light);
    // Hai tấm voan buông, thắt nơ vàng ở hai phần ba.
    for (final side in [-1.0, 1.0]) {
      final outer = cx + side * half;
      final inner = cx + side * (half - 18);
      final tie = y + drop * .62;
      final path = Path()
        ..moveTo(inner, y + 10)
        ..quadraticBezierTo(inner + side * 2, tie - 20, outer - side * 2, tie)
        ..quadraticBezierTo(inner, tie + 22, inner - side * 2, y + drop)
        ..lineTo(outer + side * 6, y + drop)
        ..quadraticBezierTo(outer + side * 1, tie + 12, outer - side * 2, tie)
        ..quadraticBezierTo(
          outer + side * 6,
          tie - 26,
          outer + side * 2,
          y + 10,
        )
        ..close();
      _path(c, path, veil.withValues(alpha: .93));
      _path(
        c,
        Path()
          ..moveTo(cx + side * (half - 9), y + 12)
          ..quadraticBezierTo(
            cx + side * (half - 6),
            tie - 18,
            outer - side * 1,
            tie,
          ),
        fold.withValues(alpha: .9),
        width: 1.4,
      );
      _circle(c, Offset(outer - side * 2, tie), 3.4, k(_gold));
      _path(
        c,
        Path()
          ..moveTo(outer - side * 2, tie)
          ..lineTo(outer - side * 7, tie + 9)
          ..moveTo(outer - side * 2, tie)
          ..lineTo(outer + side * 3, tie + 10),
        k(_goldDark),
        width: 1.3,
      );
    }
    // Mái vòm có viền lượn sóng.
    final hood = Path()
      ..moveTo(cx - half - 2, y + 16)
      ..quadraticBezierTo(cx - half + 4, y - 2, cx, y - 6)
      ..quadraticBezierTo(cx + half - 4, y - 2, cx + half + 2, y + 16);
    const scallops = 6;
    for (var i = scallops; i > 0; i--) {
      final x0 = cx - half - 2 + (width + 4) * i / scallops;
      final x1 = cx - half - 2 + (width + 4) * (i - 1) / scallops;
      hood.quadraticBezierTo((x0 + x1) / 2, y + 27, x1, y + 16);
    }
    hood.close();
    _path(c, hood, k(tone.main));
    _path(c, hood, k(_gold), width: 1.6);
    // Núm vàng trên đỉnh vòm (vương miện đã có ở đầu giường).
    _circle(c, Offset(cx, y - 8), 4.2, k(_goldDark));
    _circle(c, Offset(cx, y - 8.5), 3.5, k(_gold));
    _circle(c, Offset(cx, y - 8.5), 1.5, k(_jewel));
  }

  /// Món chính của [room] thu nhỏ trong khung 100×100 cho ô xem trước.
  static void miniature(
    Canvas c,
    PetCareRoom room,
    PetCareFurnitureSet set,
    PetCareTone tone, {
    bool dark = false,
  }) {
    Color k(Color color) => _dim(color, dark);
    final classic = set == PetCareFurnitureSet.classic;
    const ink = Color(0xFF856C7A);
    void legs(List<Rect> feet, Color plain) {
      for (final rect in feet) {
        if (classic) {
          _round(c, rect, 2.5, k(plain));
        } else {
          foot(c, rect, set, tone, dark: dark);
        }
      }
    }

    switch (room) {
      case PetCareRoom.living:
        _round(c, const Rect.fromLTWH(14, 38, 72, 40), 14, k(tone.main));
        for (final x in const [19.0, 51.0]) {
          final cushion = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 45, 30, 22),
            const Radius.circular(9),
          );
          c.drawRRect(cushion, Paint()..color = k(tone.light));
          panel(c, cushion, set, tone, dark: dark);
        }
        _round(c, const Rect.fromLTWH(10, 64, 80, 15), 7, k(tone.shade));
        for (final x in const [5.0, 81.0]) {
          _round(c, Rect.fromLTWH(x, 54, 14, 27), 7, k(tone.main));
        }
        legs(const [
          Rect.fromLTWH(18, 77, 10, 13),
          Rect.fromLTWH(72, 77, 10, 13),
        ], ink);
        edgeTrim(c, const Rect.fromLTWH(18, 38, 64, 40), set, tone, dark: dark);
      case PetCareRoom.kitchen:
        final back = RRect.fromRectAndRadius(
          const Rect.fromLTWH(28, 22, 44, 46),
          const Radius.circular(14),
        );
        c.drawRRect(back, Paint()..color = k(tone.main));
        final inner = back.deflate(6).shift(const Offset(0, 1));
        c.drawRRect(inner, Paint()..color = k(tone.light));
        panel(c, inner, set, tone, dark: dark);
        legs(const [
          Rect.fromLTWH(29, 72, 10, 20),
          Rect.fromLTWH(61, 72, 10, 20),
        ], const Color(0xFFB18B7B));
        _round(c, const Rect.fromLTWH(22, 64, 56, 12), 6, k(tone.shade));
        rimTrim(c, const Rect.fromLTWH(24, 65, 52, 8), set, tone, dark: dark);
        boardTop(
          c,
          const Rect.fromLTWH(28, 22, 44, 46),
          set,
          tone,
          size: 36,
          dark: dark,
        );
      case PetCareRoom.bathroom:
        for (var i = 0; i < 4; i++) {
          _circle(
            c,
            Offset(30 + i * 13.0, 38 - (i.isOdd ? 6 : 0)),
            5 + (i % 2) * 2.0,
            Colors.white.withValues(alpha: dark ? .5 : .95),
          );
        }
        legs(const [
          Rect.fromLTWH(19, 76, 13, 15),
          Rect.fromLTWH(68, 76, 13, 15),
        ], tone.shade);
        _round(c, const Rect.fromLTWH(10, 48, 80, 32), 15, k(tone.main));
        final inner = RRect.fromRectAndRadius(
          const Rect.fromLTWH(16, 54, 68, 20),
          const Radius.circular(10),
        );
        c.drawRRect(inner, Paint()..color = k(tone.light));
        panel(c, inner, set, tone, dark: dark);
        _round(
          c,
          const Rect.fromLTWH(6, 43, 88, 9),
          4.5,
          k(PetCareRoomArt._cream),
        );
        rimTrim(c, const Rect.fromLTWH(6, 43, 88, 9), set, tone, dark: dark);
        emblem(c, const Offset(50, 66), 9, set, tone, dark: dark);
      case PetCareRoom.bedroom:
        if (set == PetCareFurnitureSet.princess) {
          canopy(c, const Offset(80, 14), 34, 52, tone, dark: dark);
        }
        _round(
          c,
          const Rect.fromLTWH(16, 52, 62, 12),
          6,
          k(const Color(0xFFFFF6EA)),
        );
        _round(
          c,
          const Rect.fromLTWH(56, 48, 22, 10),
          5,
          k(const Color(0xFFFFE6C8)),
        );
        _round(
          c,
          const Rect.fromLTWH(14, 57, 50, 13),
          6,
          k(Color.lerp(tone.light, tone.main, .5)!),
        );
        legs(const [
          Rect.fromLTWH(14, 76, 10, 13),
          Rect.fromLTWH(78, 76, 10, 13),
        ], tone.shade);
        _round(c, const Rect.fromLTWH(8, 67, 84, 10), 5, k(tone.shade));
        rimTrim(c, const Rect.fromLTWH(14, 68, 72, 8), set, tone, dark: dark);
        final head = RRect.fromRectAndRadius(
          const Rect.fromLTWH(74, 30, 18, 52),
          const Radius.circular(8),
        );
        c.drawRRect(head, Paint()..color = k(tone.main));
        final headInner = head.deflate(4);
        c.drawRRect(headInner, Paint()..color = k(tone.light));
        panel(c, headInner, set, tone, dark: dark);
        boardTop(
          c,
          const Rect.fromLTWH(74, 30, 18, 52),
          set,
          tone,
          size: 24,
          dark: dark,
        );
        final footboard = RRect.fromRectAndRadius(
          const Rect.fromLTWH(6, 44, 14, 38),
          const Radius.circular(7),
        );
        c.drawRRect(footboard, Paint()..color = k(tone.main));
        boardTop(
          c,
          const Rect.fromLTWH(6, 44, 14, 38),
          set,
          tone,
          size: 18,
          dark: dark,
        );
    }
  }

  // ---- Nét vẽ nhỏ ----

  /// Lớp kem/mật phủ mép trên dải [band], các giọt chảy xuống không đều.
  static void _drips(
    Canvas c,
    Rect band,
    Color fill,
    Color shade, {
    int seed = 0,
  }) {
    const pattern = [1.0, .42, .78, .3, .95, .55, .7, .36];
    final count = math.max(2, (band.width / 11).round());
    final step = band.width / count;
    final base = band.top + band.height * .36;
    final reach = band.height - (base - band.top);
    final path = Path()
      ..moveTo(band.left, base)
      ..lineTo(band.left, band.top + 2.5)
      ..quadraticBezierTo(band.left, band.top, band.left + 2.5, band.top)
      ..lineTo(band.right - 2.5, band.top)
      ..quadraticBezierTo(band.right, band.top, band.right, band.top + 2.5)
      ..lineTo(band.right, base);
    for (var i = count - 1; i >= 0; i--) {
      final mid = band.left + (i + .5) * step;
      final half = step * .27;
      final len = pattern[(i + seed) % pattern.length] * (reach - half);
      path
        ..lineTo(mid + half, base)
        ..lineTo(mid + half, base + len)
        ..cubicTo(
          mid + half,
          base + len + half * 1.35,
          mid - half,
          base + len + half * 1.35,
          mid - half,
          base + len,
        )
        ..lineTo(mid - half, base)
        ..lineTo(band.left + i * step, base);
    }
    path.close();
    c.save();
    c.translate(0, 1.3);
    _path(c, path, shade);
    c.restore();
    _path(c, path, fill);
    _line(
      c,
      Offset(band.left + 3, band.top + 1.6),
      Offset(band.right - 3, band.top + 1.6),
      Colors.white.withValues(alpha: .55),
      1,
    );
  }

  static void _sprinkleDots(Canvas c, Rect area, bool dark) {
    var i = 0;
    for (var x = area.left; x < area.right; x += 5.5, i++) {
      c.save();
      c.translate(x, area.top + (i % 3) * area.height / 3);
      c.rotate(i * 1.1);
      _round(
        c,
        const Rect.fromLTWH(-1.6, -.6, 3.2, 1.2),
        .6,
        _dim(_sprinkles[i % _sprinkles.length], dark),
      );
      c.restore();
    }
  }

  static void _cherry(Canvas c, Offset center, double r, bool dark) {
    _path(
      c,
      Path()
        ..moveTo(center.dx, center.dy - r * .6)
        ..quadraticBezierTo(
          center.dx + r * .3,
          center.dy - r * 1.6,
          center.dx + r * 1.1,
          center.dy - r * 1.9,
        ),
      _dim(_leafDark, dark),
      width: math.max(.8, r * .22),
    );
    _circle(c, center, r, _dim(_cherryRed, dark));
    _circle(
      c,
      center + Offset(-r * .35, -r * .35),
      r * .3,
      Colors.white.withValues(alpha: .7),
    );
  }

  /// Lá hình giọt, gốc tại [base], [angle] 0 là mọc thẳng lên.
  static void _leafShape(
    Canvas c,
    Offset base,
    double length,
    double angle,
    Color color,
  ) {
    final w = length * .36;
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    _path(
      c,
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(w, -length * .45, 0, -length)
        ..quadraticBezierTo(-w, -length * .45, 0, 0)
        ..close(),
      color,
    );
    _line(
      c,
      Offset(0, -length * .1),
      Offset(0, -length * .78),
      Colors.white.withValues(alpha: .35 * color.a),
      math.max(.6, length * .05),
    );
    c.restore();
  }

  static void _mushroom(Canvas c, Offset base, double size, bool dark) {
    _round(
      c,
      Rect.fromLTWH(
        base.dx - size * .16,
        base.dy - size * .55,
        size * .32,
        size * .55,
      ),
      size * .12,
      _dim(_icing, dark),
    );
    final cap = Rect.fromLTWH(
      base.dx - size * .5,
      base.dy - size * 1.05,
      size,
      size * .7,
    );
    c.drawArc(
      cap,
      math.pi,
      math.pi,
      true,
      Paint()..color = _dim(const Color(0xFFE5606A), dark),
    );
    for (final (dx, dy, r) in [
      (-.22, -.82, .1),
      (.12, -.92, .08),
      (.3, -.74, .07),
    ]) {
      _circle(
        c,
        Offset(base.dx + dx * size, base.dy + dy * size),
        r * size,
        _dim(_icing, dark),
      );
    }
  }

  /// Vương miện: [base] là giữa mép dưới, rộng [width].
  static void _crown(Canvas c, Offset base, double width, bool dark) {
    final h = width * .58;
    final w = width / 2;
    final b = base.dy;
    final x = base.dx;
    final crown = Path()
      ..moveTo(x - w, b)
      ..lineTo(x - w, b - h * .78)
      ..lineTo(x - w * .5, b - h * .42)
      ..lineTo(x, b - h)
      ..lineTo(x + w * .5, b - h * .42)
      ..lineTo(x + w, b - h * .78)
      ..lineTo(x + w, b)
      ..close();
    _path(c, crown, _dim(_gold, dark));
    _path(c, crown, _dim(_goldDark, dark), width: math.max(.7, width * .03));
    _round(
      c,
      Rect.fromLTWH(x - w, b - h * .26, w * 2, h * .26),
      h * .08,
      _dim(_goldDark, dark),
    );
    for (final p in [
      Offset(x - w, b - h * .8),
      Offset(x, b - h * 1.02),
      Offset(x + w, b - h * .8),
    ]) {
      _circle(c, p, width * .07, _dim(_jewel, dark));
    }
    _circle(c, Offset(x, b - h * .13), width * .08, _dim(_jewel, dark));
    _circle(
      c,
      Offset(x - w * .4, b - h * .55),
      width * .05,
      Colors.white.withValues(alpha: .7),
    );
  }

  static void _cloudBump(
    Canvas c,
    Offset p,
    double r,
    Color fill,
    Color shade,
  ) {
    _circle(c, p + const Offset(0, 1.2), r, shade);
    _circle(c, p, r, fill);
    c.drawArc(
      Rect.fromCircle(center: p, radius: r * .62),
      math.pi * 1.1,
      math.pi * .55,
      false,
      Paint()
        ..color = shade.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Đám mây phồng ba cụm vừa khung [box].
  static void _cloudPuff(Canvas c, Rect box, Color fill, Color? shade) {
    void puff(Offset offset, Color color) {
      final h = box.height;
      final w = box.width;
      _oval(
        c,
        Rect.fromLTWH(box.left, box.top + h * .45, w, h * .55).shift(offset),
        color,
      );
      _circle(
        c,
        Offset(box.left + w * .27, box.top + h * .55) + offset,
        h * .42,
        color,
      );
      _circle(
        c,
        Offset(box.left + w * .52, box.top + h * .4) + offset,
        h * .5,
        color,
      );
      _circle(
        c,
        Offset(box.left + w * .76, box.top + h * .58) + offset,
        h * .38,
        color,
      );
    }

    if (shade != null) puff(const Offset(0, 1.2), shade);
    puff(Offset.zero, fill);
  }

  static void _bee(Canvas c, Offset p, double size, bool dark) {
    final body = Rect.fromCenter(
      center: p,
      width: size * 1.7,
      height: size * 1.15,
    );
    for (final dx in [-size * .28, size * .18]) {
      _oval(
        c,
        Rect.fromCenter(
          center: p + Offset(dx, -size * .72),
          width: size * .8,
          height: size * .62,
        ),
        Colors.white.withValues(alpha: dark ? .55 : .85),
      );
    }
    _oval(c, body, _dim(_beeYellow, dark));
    c.save();
    c.clipPath(Path()..addOval(body));
    for (final dx in [-size * .1, size * .32]) {
      c.drawRect(
        Rect.fromLTWH(p.dx + dx, body.top, size * .2, body.height),
        Paint()..color = _dim(_beeStripe, dark),
      );
    }
    c.restore();
    _circle(
      c,
      Offset(body.left + size * .3, p.dy - size * .1),
      size * .1,
      _dim(_beeStripe, dark),
    );
  }

  static void _catEar(
    Canvas c,
    Offset base,
    double w,
    double tilt,
    PetCareTone tone,
    bool dark,
  ) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(tilt);
    final ear = Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(-w * .3, -w * .7, -w * .05, -w * .92)
      ..quadraticBezierTo(w * .08, -w * .98, w * .16, -w * .86)
      ..quadraticBezierTo(w * .38, -w * .5, w / 2, 0)
      ..close();
    _path(c, ear, _dim(tone.shade, dark));
    c.save();
    c.translate(0, -1);
    c.scale(.92);
    _path(c, ear, _dim(tone.main, dark));
    c.restore();
    final inner = Path()
      ..moveTo(-w * .26, -w * .08)
      ..quadraticBezierTo(-w * .14, -w * .55, 0, -w * .7)
      ..quadraticBezierTo(w * .2, -w * .4, w * .26, -w * .08)
      ..close();
    _path(c, inner, _dim(_earPink, dark));
    c.restore();
  }

  /// Mặt mèo cười híp mắt, rộng [w].
  static void _catFace(Canvas c, Offset p, double w, bool dark) {
    final ink = _dim(_ink, dark);
    for (final side in [-1.0, 1.0]) {
      c.drawArc(
        Rect.fromCenter(
          center: p + Offset(side * w * .22, -w * .05),
          width: w * .2,
          height: w * .16,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.8, w * .05)
          ..strokeCap = StrokeCap.round,
      );
      _oval(
        c,
        Rect.fromCenter(
          center: p + Offset(side * w * .34, w * .12),
          width: w * .18,
          height: w * .1,
        ),
        _dim(_earPink, dark).withValues(alpha: .8),
      );
      for (final dy in [.06, .17]) {
        _line(
          c,
          p + Offset(side * w * .4, w * dy),
          p + Offset(side * w * .64, w * (dy - .04 + (dy > .1 ? .06 : 0))),
          ink.withValues(alpha: .7),
          math.max(.5, w * .025),
        );
      }
    }
    _path(
      c,
      Path()
        ..moveTo(p.dx - w * .06, p.dy + w * .06)
        ..lineTo(p.dx + w * .06, p.dy + w * .06)
        ..lineTo(p.dx, p.dy + w * .13)
        ..close(),
      _dim(_nose, dark),
    );
    _path(
      c,
      Path()
        ..moveTo(p.dx - w * .12, p.dy + w * .16)
        ..quadraticBezierTo(
          p.dx - w * .06,
          p.dy + w * .23,
          p.dx,
          p.dy + w * .14,
        )
        ..quadraticBezierTo(
          p.dx + w * .06,
          p.dy + w * .23,
          p.dx + w * .12,
          p.dy + w * .16,
        ),
      ink,
      width: math.max(.6, w * .035),
    );
  }

  static void _paw(Canvas c, Offset p, double r, Color color) {
    _oval(
      c,
      Rect.fromCenter(
        center: p + Offset(0, r * .45),
        width: r * 1.5,
        height: r * 1.2,
      ),
      color,
    );
    for (final (dx, dy) in [
      (-.72, -.25),
      (-.26, -.72),
      (.26, -.72),
      (.72, -.25),
    ]) {
      _circle(c, p + Offset(dx * r, dy * r), r * .34, color);
    }
  }

  static void _hexagon(
    Canvas c,
    Offset p,
    double r,
    Color color, {
    double? stroke,
  }) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final q = p + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    _path(c, path..close(), color, width: stroke);
  }

  static void _round(Canvas c, Rect rect, double radius, Color color) =>
      PetCareRoomArt._round(c, rect, radius, color);
  static void _oval(Canvas c, Rect rect, Color color) =>
      PetCareRoomArt._oval(c, rect, color);
  static void _circle(Canvas c, Offset p, double r, Color color) =>
      PetCareRoomArt._circle(c, p, r, color);
  static void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      PetCareRoomArt._line(c, a, b, color, width);
  static void _path(Canvas c, Path path, Color color, {double? width}) =>
      PetCareRoomArt._path(c, path, color, width: width);
  static void _star(Canvas c, Offset p, double r, Color color) =>
      PetCareRoomArt._star(c, p, r, color);
}
