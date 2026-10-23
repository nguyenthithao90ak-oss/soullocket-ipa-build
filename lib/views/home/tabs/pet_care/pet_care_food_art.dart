import 'package:flutter/material.dart';

import 'pet_care_item_art.dart';
import 'pet_care_progress.dart';

/// Hình món ăn trên kệ/tủ lạnh. Bốn món đầu dùng atlas vẽ tay, các món sau
/// dùng emoji hệ thống nên không phải đóng gói thêm ảnh.
class PetCareFoodArt extends StatelessWidget {
  const PetCareFoodArt({required this.food, this.size = 56, super.key});

  final PetCareFood food;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = food.emoji;
    if (emoji == null) return PetCareItemArt(index: food.index, size: size);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            emoji,
            textAlign: TextAlign.center,
            // Cỡ hình cố định như ảnh, không phóng theo cỡ chữ hệ thống.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: size * .74,
              height: 1.1,
              fontFamilyFallback: emojiFonts,
            ),
          ),
        ),
      ),
    );
  }
}

/// Font emoji màu của từng hệ điều hành; máy không có thì tự dùng font hệ thống.
const emojiFonts = ['Apple Color Emoji', 'Noto Color Emoji', 'Segoe UI Emoji'];

/// Vẽ emoji món ăn lên canvas của cảnh; mỗi emoji chỉ dựng chữ một lần.
abstract final class PetCareFoodPaint {
  static const _base = 40.0;
  static final Map<String, TextPainter> _cache = {};

  static TextPainter _painter(String emoji) => _cache.putIfAbsent(
    emoji,
    () => TextPainter(
      text: TextSpan(
        text: emoji,
        style: const TextStyle(
          fontSize: _base,
          height: 1,
          fontFamilyFallback: emojiFonts,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  /// Vẽ món [emoji] cao khoảng [size] đơn vị, tâm tại [center].
  /// [bite] > 0 khoét vết cắn tròn ở mép phải.
  static void paint(
    Canvas canvas,
    String emoji,
    Offset center,
    double size, {
    double bite = 0,
  }) {
    final painter = _painter(emoji);
    final scale = size / _base;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final offset = Offset(-painter.width / 2, -painter.height / 2);
    if (bite <= 0) {
      painter.paint(canvas, offset);
    } else {
      final bounds = (offset & painter.size).inflate(2);
      canvas.saveLayer(bounds, Paint());
      painter.paint(canvas, offset);
      final clear = Paint()..blendMode = BlendMode.clear;
      final r = _base * (.16 + bite * .1);
      canvas.drawCircle(const Offset(_base * .42, -_base * .14), r, clear);
      if (bite > .5) {
        canvas.drawCircle(
          const Offset(_base * .34, _base * .14),
          r * .8,
          clear,
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }
}
