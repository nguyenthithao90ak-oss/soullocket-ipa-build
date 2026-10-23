import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pet_care_progress.dart';

/// Bộ ba màu cho một món nội thất: thân, mặt sáng và bóng đổ.
@immutable
class PetCareTone {
  const PetCareTone(this.main, this.light, this.shade);

  factory PetCareTone.of(Color base) {
    final hsl = HSLColor.fromColor(base);
    return PetCareTone(
      base,
      hsl.withLightness((hsl.lightness + .09).clamp(0, .95)).toColor(),
      hsl
          .withLightness((hsl.lightness - .1).clamp(.05, 1))
          .withSaturation((hsl.saturation * .9).clamp(0, 1))
          .toColor(),
    );
  }

  final Color main;
  final Color light;
  final Color shade;
}

/// Hình vẽ tường, sàn, cửa sổ và màu nội thất của từng món trang trí.
/// Cảnh phòng và ô xem trước trong chế độ trang trí dùng chung các hàm này.
abstract final class PetCareRoomArt {
  static const _cream = Color(0xFFFFF8E8);
  static const _mint = Color(0xFFABD5C3);
  static const _rose = Color(0xFFECA6B9);
  static const _lilac = Color(0xFFB9A7D9);
  static const _gold = Color(0xFFE7BC78);
  static const _nightTint = Color(0xFF2E2838);

  /// Null nghĩa là giữ màu gốc của từng món trong phòng.
  static PetCareTone? tone(PetCareRoomItem furniture) => switch (furniture) {
    PetCareRoomItem.furniturePeach => PetCareTone.of(const Color(0xFFF4B596)),
    PetCareRoomItem.furnitureMint => PetCareTone.of(const Color(0xFF93D2B8)),
    PetCareRoomItem.furnitureLilac => PetCareTone.of(const Color(0xFFBCA6E3)),
    PetCareRoomItem.furnitureSky => PetCareTone.of(const Color(0xFF93C4EC)),
    PetCareRoomItem.furnitureHoney => PetCareTone.of(const Color(0xFFF0C46C)),
    PetCareRoomItem.furnitureCocoa => PetCareTone.of(const Color(0xFFB48669)),
    _ => null,
  };

  /// Màu nội thất gốc của phòng, dùng cho ô xem trước món "Cổ điển".
  static Color classicFurniture(PetCareRoom room) => switch (room) {
    PetCareRoom.living => const Color(0xFFE8AFBE),
    PetCareRoom.kitchen => const Color(0xFF9FBDA8),
    PetCareRoom.bathroom => const Color(0xFF94C1BD),
    PetCareRoom.bedroom => const Color(0xFFC6A4B0),
  };

  static Color _night(Color color, bool dark) =>
      dark ? Color.lerp(color, _nightTint, .66)! : color;

  /// Màu nền tường (trên, dưới) của món [wall] trong [room].
  static (Color, Color) wallColors(
    PetCareRoom room,
    PetCareRoomItem wall,
    bool dark,
  ) {
    final (Color top, Color bottom) = switch (wall) {
      PetCareRoomItem.wallPolka => (
        const Color(0xFFFDE6EE),
        const Color(0xFFFFF4F2),
      ),
      PetCareRoomItem.wallStripe => (
        const Color(0xFFFFF1DC),
        const Color(0xFFFFF8EA),
      ),
      PetCareRoomItem.wallHearts => (
        const Color(0xFFFBE2EB),
        const Color(0xFFFFF2F2),
      ),
      PetCareRoomItem.wallClouds => (
        const Color(0xFFCFE8FA),
        const Color(0xFFF0F8FF),
      ),
      PetCareRoomItem.wallLeaves => (
        const Color(0xFFE2F1DA),
        const Color(0xFFF5FAEE),
      ),
      PetCareRoomItem.wallCheck => (
        const Color(0xFFFFF0EC),
        const Color(0xFFFFF8F4),
      ),
      PetCareRoomItem.wallStars => (
        const Color(0xFF2F3A68),
        const Color(0xFF4B5A8C),
      ),
      _ => switch (room) {
        PetCareRoom.living => (const Color(0xFFF7E3E8), _cream),
        PetCareRoom.kitchen => (const Color(0xFFEAF0DA), _cream),
        PetCareRoom.bathroom => (const Color(0xFFE1F1EF), _cream),
        PetCareRoom.bedroom => (const Color(0xFFECE5F6), _cream),
      },
    };
    if (dark && wall == PetCareRoomItem.wallClassic) {
      final base = switch (room) {
        PetCareRoom.living => const Color(0xFF493746),
        PetCareRoom.kitchen => const Color(0xFF38473F),
        PetCareRoom.bathroom => const Color(0xFF35474D),
        PetCareRoom.bedroom => const Color(0xFF37354F),
      };
      return (base, base.withValues(alpha: .92));
    }
    return (_night(top, dark), _night(bottom, dark));
  }

  /// Giấy dán tường phủ [rect] (đơn vị cảnh 360×300).
  static void paintWall(
    Canvas c,
    Rect rect,
    PetCareRoom room,
    PetCareRoomItem wall, {
    required bool dark,
  }) {
    final (top, bottom) = wallColors(room, wall, dark);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    c.save();
    c.clipRect(rect);
    final fade = dark ? .55 : 1.0;
    switch (wall) {
      case PetCareRoomItem.wallClassic:
        _classicWall(c, rect, room, dark);
      case PetCareRoomItem.wallPolka:
        _grid(c, rect, 26, 24, (p, odd) {
          _circle(c, p, 3.4, const Color(0xFFF2AFC3).withValues(alpha: fade));
        });
      case PetCareRoomItem.wallStripe:
        for (var x = rect.left - 8; x < rect.right + 24; x += 26) {
          c.drawRect(
            Rect.fromLTWH(x, rect.top, 11, rect.height),
            Paint()
              ..color = const Color(0xFFF8D3A1).withValues(alpha: .62 * fade),
          );
          _line(
            c,
            Offset(x + 18, rect.top),
            Offset(x + 18, rect.bottom),
            const Color(0xFFF2B9C5).withValues(alpha: .5 * fade),
            1.4,
          );
        }
      case PetCareRoomItem.wallHearts:
        _grid(c, rect, 34, 32, (p, odd) {
          _heart(
            c,
            p,
            odd ? 4.2 : 5.4,
            (odd ? const Color(0xFFF4BBCB) : const Color(0xFFEE9FB6))
                .withValues(alpha: .8 * fade),
          );
        });
      case PetCareRoomItem.wallClouds:
        _grid(c, rect, 74, 58, (p, odd) {
          _cloud(
            c,
            p + Offset(odd ? 14 : 0, 0),
            odd ? .26 : .34,
            Colors.white.withValues(alpha: .82 * fade),
          );
        });
      case PetCareRoomItem.wallLeaves:
        _grid(c, rect, 30, 30, (p, odd) {
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(odd ? -.7 : .55);
          _oval(
            c,
            const Rect.fromLTWH(-3.2, -7.5, 6.4, 15),
            (odd ? const Color(0xFF9CCB98) : const Color(0xFF7FB98A))
                .withValues(alpha: .62 * fade),
          );
          c.restore();
        });
      case PetCareRoomItem.wallCheck:
        final band = Paint()
          ..color = const Color(0xFFF2B4B4).withValues(alpha: .24 * fade);
        for (var x = rect.left; x < rect.right; x += 28) {
          c.drawRect(Rect.fromLTWH(x, rect.top, 14, rect.height), band);
        }
        for (var y = rect.top; y < rect.bottom; y += 28) {
          c.drawRect(Rect.fromLTWH(rect.left, y, rect.width, 14), band);
        }
      case PetCareRoomItem.wallStars:
        _grid(c, rect, 38, 36, (p, odd) {
          _star(
            c,
            p,
            odd ? 2.4 : 3.6,
            const Color(0xFFFFE3A0).withValues(alpha: odd ? .7 : .95),
          );
          _circle(
            c,
            p + const Offset(17, 11),
            1,
            Colors.white.withValues(alpha: .6),
          );
        });
      default:
        break;
    }
    c.restore();
  }

  static void _classicWall(Canvas c, Rect rect, PetCareRoom room, bool dark) {
    if (room == PetCareRoom.bathroom) {
      for (var row = (rect.top / 42).floor(); row < 5; row++) {
        for (var col = 0; col < 9; col++) {
          final r = Rect.fromLTWH(
            col * 44 - (row.isOdd ? 22 : 0),
            row * 42 - 9,
            42,
            40,
          );
          _round(
            c,
            r,
            5,
            (row + col).isEven
                ? Colors.white.withValues(alpha: dark ? .035 : .42)
                : _mint.withValues(alpha: .11),
          );
          if ((row + col) % 5 == 0) {
            _diamond(c, r.center, 3, _mint.withValues(alpha: .35));
          }
        }
      }
      return;
    }
    for (var row = (rect.top / 39).floor(); row < 5; row++) {
      for (var col = 0; col < 10; col++) {
        final p = Offset(col * 39 + (row.isOdd ? 17 : 0), row * 39 + 14);
        if (room == PetCareRoom.bedroom) {
          _star(c, p, 2.7, _lilac.withValues(alpha: dark ? .14 : .24));
        } else if (room == PetCareRoom.kitchen) {
          _path(
            c,
            Path()
              ..moveTo(p.dx - 3, p.dy)
              ..lineTo(p.dx, p.dy + 3)
              ..lineTo(p.dx + 3, p.dy),
            _mint.withValues(alpha: .3),
            width: 1.2,
          );
        } else {
          _flower(c, p, 2.2, _rose.withValues(alpha: dark ? .16 : .22));
        }
      }
    }
  }

  /// Màu sàn (gần tường, gần người xem).
  static (Color, Color) floorColors(
    PetCareRoom room,
    PetCareRoomItem floor,
    bool dark,
  ) {
    final (Color back, Color front) = switch (floor) {
      PetCareRoomItem.floorOak => (
        const Color(0xFFEFD3AE),
        const Color(0xFFF8E6C8),
      ),
      PetCareRoomItem.floorChecker => (
        const Color(0xFFF7D8DC),
        const Color(0xFFFFF1EA),
      ),
      PetCareRoomItem.floorCarpet => (
        const Color(0xFFF0BCCB),
        const Color(0xFFF9D9E2),
      ),
      PetCareRoomItem.floorMarble => (
        const Color(0xFFE6E3EA),
        const Color(0xFFF8F6F9),
      ),
      PetCareRoomItem.floorGrass => (
        const Color(0xFF9CCF8B),
        const Color(0xFFBFE2A7),
      ),
      PetCareRoomItem.floorNight => (
        const Color(0xFF39436F),
        const Color(0xFF55618F),
      ),
      _ => (
        room == PetCareRoom.bathroom
            ? const Color(0xFFB5D5D0)
            : const Color(0xFFE7C7AA),
        const Color(0xFFF4DEBF),
      ),
    };
    if (dark && floor == PetCareRoomItem.floorClassic) {
      return (const Color(0xFF5D535A), const Color(0xFF433D4C));
    }
    return (_night(back, dark), _night(front, dark));
  }

  /// Sàn phủ [rect]; dòng chân tường do cảnh vẽ riêng.
  static void paintFloor(
    Canvas c,
    Rect rect,
    PetCareRoom room,
    PetCareRoomItem floor, {
    required bool dark,
  }) {
    final (back, front) = floorColors(room, floor, dark);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [back, front],
        ).createShader(rect),
    );
    c.save();
    c.clipRect(rect);
    final fade = dark ? .5 : 1.0;
    switch (floor) {
      case PetCareRoomItem.floorClassic:
        if (room == PetCareRoom.bathroom) {
          _bathTiles(c, rect);
        } else {
          _planks(c, rect, const Color(0xFFB58E7F), const Color(0xFFC29A84));
        }
      case PetCareRoomItem.floorOak:
        _planks(c, rect, const Color(0xFFC49A6C), const Color(0xFFD3AE80));
      case PetCareRoomItem.floorChecker:
        const size = 26.0;
        final tile = Paint()
          ..color = const Color(0xFFFFFBF4).withValues(alpha: .85 * fade);
        for (var row = 0; row * size < rect.height; row++) {
          for (var col = 0; col * size < rect.width + size; col++) {
            if ((row + col).isEven) {
              c.drawRect(
                Rect.fromLTWH(
                  rect.left + col * size,
                  rect.top + row * size,
                  size,
                  size,
                ),
                tile,
              );
            }
          }
        }
      case PetCareRoomItem.floorCarpet:
        _grid(c, rect, 18, 14, (p, odd) {
          _circle(
            c,
            p,
            odd ? 1.6 : 2.2,
            Colors.white.withValues(alpha: .32 * fade),
          );
        });
        _line(
          c,
          Offset(rect.left, rect.top + 10),
          Offset(rect.right, rect.top + 10),
          Colors.white.withValues(alpha: .45 * fade),
          2,
        );
      case PetCareRoomItem.floorMarble:
        for (var i = 0; i < 7; i++) {
          final x = rect.left + i * 62.0 - 20;
          _path(
            c,
            Path()
              ..moveTo(x, rect.top)
              ..quadraticBezierTo(x + 26, rect.top + 30, x + 12, rect.top + 60)
              ..quadraticBezierTo(x - 6, rect.top + 92, x + 30, rect.bottom),
            const Color(0xFFB9B2C4).withValues(alpha: .38 * fade),
            width: 1.1,
          );
        }
        for (var y = rect.top + 34; y < rect.bottom; y += 34) {
          _line(
            c,
            Offset(rect.left, y),
            Offset(rect.right, y),
            Colors.white.withValues(alpha: .7 * fade),
            1,
          );
        }
      case PetCareRoomItem.floorGrass:
        _grid(c, rect, 22, 16, (p, odd) {
          for (var i = -1; i < 2; i++) {
            _line(
              c,
              p,
              p + Offset(i * 2.5, -5.0 - (i == 0 ? 2 : 0)),
              const Color(0xFF6FAE63).withValues(alpha: .55 * fade),
              1.1,
            );
          }
          if (odd && (p.dx ~/ 22) % 3 == 0) {
            _flower(c, p + const Offset(7, -4), 1.8, _cream);
          }
        });
      case PetCareRoomItem.floorNight:
        _grid(c, rect, 30, 22, (p, odd) {
          _star(
            c,
            p,
            odd ? 1.8 : 2.6,
            const Color(0xFFFFE3A0).withValues(alpha: odd ? .55 : .8),
          );
        });
      default:
        break;
    }
    c.restore();
  }

  static void _planks(Canvas c, Rect rect, Color seam, Color grain) {
    for (var row = 0; row * 26.0 < rect.height; row++) {
      final y = rect.top + 14 + row * 26.0;
      _line(
        c,
        Offset(rect.left, y),
        Offset(rect.right, y),
        seam.withValues(alpha: .23),
        1,
      );
      for (var col = 0; col < 5; col++) {
        final x = rect.left + col * 84 + (row.isOdd ? 36.0 : 0.0);
        _line(
          c,
          Offset(x, y),
          Offset(x, y + 26),
          seam.withValues(alpha: .17),
          1,
        );
        _path(
          c,
          Path()
            ..moveTo(x + 12, y + 12)
            ..quadraticBezierTo(x + 27, y + 7, x + 42, y + 11),
          grain.withValues(alpha: .2),
          width: .7,
        );
      }
    }
  }

  static void _bathTiles(Canvas c, Rect rect) {
    for (var i = -3; i < 10; i++) {
      _line(
        c,
        Offset(i * 53, rect.top + 5),
        Offset(i * 53 + 60 + (rect.height - 106) * .6, rect.bottom),
        Colors.white.withValues(alpha: .25),
        1,
      );
    }
    for (var y = rect.top + 30; y < rect.bottom; y += 34) {
      _line(
        c,
        Offset(rect.left, y),
        Offset(rect.right, y),
        Colors.white.withValues(alpha: .28),
        1,
      );
    }
  }

  /// Viền ngoài cửa sổ theo kiểu đã chọn, tâm tại gốc tọa độ.
  static Path windowPath(PetCareRoomItem window, Size size) {
    final w = size.width;
    final h = size.height;
    switch (window) {
      case PetCareRoomItem.windowRound:
        final d = math.min(w, h);
        return Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: d / 2));
      case PetCareRoomItem.windowBay:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: w * 1.08,
              height: h * .9,
            ),
            const Radius.circular(9),
          ),
        );
      case PetCareRoomItem.windowHeart:
        final s = math.min(w, h) / 20;
        return Path()
          ..moveTo(0, 10 * s)
          ..cubicTo(-14 * s, 1 * s, -12 * s, -11 * s, -5.5 * s, -10.5 * s)
          ..cubicTo(-2.5 * s, -10.3 * s, -.6 * s, -8.2 * s, 0, -6.4 * s)
          ..cubicTo(.6 * s, -8.2 * s, 2.5 * s, -10.3 * s, 5.5 * s, -10.5 * s)
          ..cubicTo(12 * s, -11 * s, 14 * s, 1 * s, 0, 10 * s)
          ..close();
      case PetCareRoomItem.windowStar:
        final r = math.min(w, h) * .58;
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final a = i * math.pi / 5 - math.pi / 2;
          final size = i.isEven ? r : r * .56;
          final p = Offset(math.cos(a), math.sin(a)) * size;
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path..close();
      default:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            Radius.circular(math.min(w, h) * .38),
          ),
        );
    }
  }

  /// Cửa sổ có khung, kính trời ngày/đêm và bậu; tâm tại gốc tọa độ.
  static void paintWindow(
    Canvas c,
    PetCareRoomItem window,
    Size size, {
    required bool night,
    double wave = 0,
  }) {
    final outer = windowPath(window, size);
    final bounds = outer.getBounds();
    c.save();
    c.translate(2, 4);
    c.drawPath(outer, Paint()..color = const Color(0x1A856C7A));
    c.restore();
    c.drawPath(outer, Paint()..color = _cream);
    final inset = (1 - 14 / math.max(bounds.width, bounds.height)).clamp(
      .6,
      .95,
    );
    final pane = outer.transform(
      Matrix4.diagonal3Values(inset, inset, 1).storage,
    );
    final paneBounds = pane.getBounds();
    c.save();
    c.clipPath(pane);
    c.drawRect(
      paneBounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const [Color(0xFF6E79A3), Color(0xFFB4ABC9)]
              : const [Color(0xFFA9D4E0), Color(0xFFE4F1E1)],
        ).createShader(paneBounds),
    );
    final unit = paneBounds.width / 63;
    if (night) {
      _circle(
        c,
        Offset(12 * unit, paneBounds.top * .5),
        12 * unit,
        const Color(0xFFFFE5A3),
      );
      _circle(
        c,
        Offset(17 * unit, paneBounds.top * .5 - 4 * unit),
        10 * unit,
        const Color(0xFF8790B4),
      );
      for (final p in [
        Offset(-20 * unit, paneBounds.top * .55),
        Offset(20 * unit, paneBounds.bottom * .3),
        Offset(-12 * unit, paneBounds.bottom * .1),
      ]) {
        _star(c, p, 2.5, _cream);
      }
    } else {
      _circle(
        c,
        Offset(16 * unit, paneBounds.top * .55),
        12 * unit,
        const Color(0xFFFFE6AA),
      );
      _cloud(
        c,
        Offset(-12 * unit + wave * 3, paneBounds.bottom * .05),
        .5 * unit,
        Colors.white.withValues(alpha: .85),
      );
      _cloud(
        c,
        Offset(22 * unit - wave * 2, paneBounds.bottom * .55),
        .62 * unit,
        Colors.white.withValues(alpha: .7),
      );
    }
    c.restore();
    final bar = Paint()
      ..color = _cream
      ..strokeWidth = window == PetCareRoomItem.windowBay ? 4 : 5
      ..strokeCap = StrokeCap.round;
    c.save();
    c.clipPath(pane);
    c.drawLine(Offset(0, paneBounds.top), Offset(0, paneBounds.bottom), bar);
    c.drawLine(Offset(paneBounds.left, 0), Offset(paneBounds.right, 0), bar);
    if (window == PetCareRoomItem.windowBay) {
      for (final x in [-paneBounds.width / 4, paneBounds.width / 4]) {
        c.drawLine(
          Offset(x, paneBounds.top),
          Offset(x, paneBounds.bottom),
          bar..strokeWidth = 2.5,
        );
      }
    }
    c.restore();
    // Bậu cửa; kiểu ô vuông có thêm chậu hoa nhỏ.
    final sill = Rect.fromLTWH(
      bounds.left - 7,
      bounds.bottom - 3,
      bounds.width + 14,
      10,
    );
    _round(c, sill, 5, const Color(0xFFE1BCA4));
    if (window == PetCareRoomItem.windowBay) {
      _round(
        c,
        Rect.fromLTWH(sill.left + 6, sill.top - 9, sill.width - 12, 10),
        4,
        const Color(0xFFD9A58A),
      );
      for (var i = 0; i < 4; i++) {
        _flower(
          c,
          Offset(sill.left + 14 + i * (sill.width - 28) / 3, sill.top - 11),
          3.2,
          [_rose, _gold, _lilac, _rose][i],
        );
      }
    }
  }

  // ---- Hình vẽ nhỏ dùng chung ----

  static void _grid(
    Canvas c,
    Rect rect,
    double dx,
    double dy,
    void Function(Offset point, bool odd) draw,
  ) {
    final startRow = (rect.top / dy).floor();
    for (var row = startRow; row * dy < rect.bottom + dy; row++) {
      final odd = row.isOdd;
      for (var x = -dx; x < rect.right + dx; x += dx) {
        draw(Offset(x + (odd ? dx / 2 : 0), row * dy + dy / 2), odd);
      }
    }
  }

  static void _round(Canvas c, Rect rect, double radius, Color color) =>
      c.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = color,
      );
  static void _oval(Canvas c, Rect rect, Color color) =>
      c.drawOval(rect, Paint()..color = color);
  static void _circle(Canvas c, Offset center, double radius, Color color) =>
      c.drawCircle(center, radius, Paint()..color = color);
  static void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  static void _path(Canvas c, Path path, Color color, {double? width}) =>
      c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = width ?? 1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  static void _diamond(Canvas c, Offset p, double r, Color color) => _path(
    c,
    Path()
      ..moveTo(p.dx, p.dy - r)
      ..lineTo(p.dx + r, p.dy)
      ..lineTo(p.dx, p.dy + r)
      ..lineTo(p.dx - r, p.dy)
      ..close(),
    color,
  );
  static void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2;
      final size = i.isEven ? r : r * .47;
      final point = p + Offset(math.cos(a), math.sin(a)) * size;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    _path(c, path..close(), color);
  }

  static void _heart(Canvas c, Offset p, double r, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(r / 10);
    _path(
      c,
      Path()
        ..moveTo(0, 10)
        ..cubicTo(-23, -4, -8, -16, 0, -6)
        ..cubicTo(8, -16, 23, -4, 0, 10),
      color,
    );
    c.restore();
  }

  static void _flower(Canvas c, Offset p, double radius, Color color) {
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      _circle(
        c,
        p + Offset(math.cos(angle), math.sin(angle)) * radius,
        radius * .7,
        color,
      );
    }
    _circle(c, p, radius * .55, _gold.withValues(alpha: color.a));
  }

  static void _cloud(Canvas c, Offset p, double scale, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-37, -6, 76, 30), color);
    _circle(c, const Offset(-20, -2), 19, color);
    _circle(c, const Offset(3, -12), 24, color);
    _circle(c, const Offset(26, -1), 18, color);
    c.restore();
  }
}

/// Ô xem trước món trang trí: mẫu tường/sàn, hình cửa sổ hoặc ghế màu.
class PetCareRoomSwatch extends StatelessWidget {
  const PetCareRoomSwatch({
    required this.item,
    required this.room,
    this.size = 56,
    super.key,
  });

  final PetCareRoomItem item;
  final PetCareRoom room;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SwatchPainter(
          item,
          room,
          Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    ),
  );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.item, this.room, this.dark);
  final PetCareRoomItem item;
  final PetCareRoom room;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 60;
    canvas.save();
    canvas.scale(scale);
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, 58, 58),
      const Radius.circular(16),
    );
    canvas.clipRRect(frame);
    switch (item.slot) {
      case PetCareRoomSlot.wall:
        // Phóng to mẫu giấy để thấy rõ hoa văn trong ô nhỏ.
        canvas.save();
        canvas.scale(.62);
        PetCareRoomArt.paintWall(
          canvas,
          const Rect.fromLTWH(0, 0, 100, 100),
          room,
          item,
          dark: dark,
        );
        canvas.restore();
      case PetCareRoomSlot.floor:
        canvas.save();
        canvas.scale(.62);
        PetCareRoomArt.paintFloor(
          canvas,
          const Rect.fromLTWH(0, 0, 100, 100),
          room,
          item,
          dark: dark,
        );
        canvas.restore();
      case PetCareRoomSlot.window:
        final (top, bottom) = PetCareRoomArt.wallColors(
          room,
          PetCareRoomItem.wallClassic,
          dark,
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 60, 60),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ).createShader(const Rect.fromLTWH(0, 0, 60, 60)),
        );
        canvas.translate(30, 28);
        PetCareRoomArt.paintWindow(
          canvas,
          item,
          const Size(38, 42),
          night: room == PetCareRoom.bedroom,
        );
      case PetCareRoomSlot.furniture:
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 60, 60),
          Paint()
            ..color = dark ? const Color(0xFF4A4157) : const Color(0xFFFFF6EA),
        );
        final tone =
            PetCareRoomArt.tone(item) ??
            PetCareTone.of(PetCareRoomArt.classicFurniture(room));
        // Ghế nệm nhỏ đại diện cho bộ màu nội thất.
        PetCareRoomArt._round(
          canvas,
          const Rect.fromLTWH(10, 16, 40, 24),
          9,
          tone.main,
        );
        PetCareRoomArt._round(
          canvas,
          const Rect.fromLTWH(13, 20, 16, 14),
          6,
          tone.light,
        );
        PetCareRoomArt._round(
          canvas,
          const Rect.fromLTWH(31, 20, 16, 14),
          6,
          tone.light,
        );
        PetCareRoomArt._round(
          canvas,
          const Rect.fromLTWH(7, 32, 46, 11),
          5,
          tone.shade,
        );
        PetCareRoomArt._round(
          canvas,
          const Rect.fromLTWH(12, 42, 4, 7),
          2,
          const Color(0xFF856C7A),
        );
        PetCareRoomArt._round(
          canvas,
          const Rect.fromLTWH(44, 42, 4, 7),
          2,
          const Color(0xFF856C7A),
        );
    }
    canvas.restore();
    canvas.drawRRect(
      frame.scaleRRect(scale),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x33856C7A),
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) =>
      oldDelegate.item != item ||
      oldDelegate.room != room ||
      oldDelegate.dark != dark;
}

extension on RRect {
  RRect scaleRRect(double scale) => RRect.fromRectAndRadius(
    Rect.fromLTRB(left * scale, top * scale, right * scale, bottom * scale),
    Radius.circular(tlRadiusX * scale),
  );
}
