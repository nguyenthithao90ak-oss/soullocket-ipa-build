import 'dart:math';
import 'package:flutter/material.dart';

class SlCountdownShapes {
  static ShapeBorder getShapeBorderForKey(String key, {BorderSide side = BorderSide.none}) {
    switch (key) {
      case 'squircle':
        return ContinuousRectangleBorder(
          side: side,
          borderRadius: BorderRadius.circular(100),
        );
      case 'heart':
        return _HeartBorder(side: side);
      case 'flower':
        return _FlowerBorder(side: side);
      case 'hexagon':
        return _PolygonBorder(sides: 6, side: side);
      case 'diamond':
        return _PolygonBorder(sides: 4, side: side);
      case 'circle':
      default:
        return CircleBorder(side: side);
    }
  }

  static List<String> get availableShapes => [
        'circle',
        'squircle',
        'heart',
        'flower',
        'hexagon',
        'diamond',
      ];
}

class _HeartBorder extends OutlinedBorder {
  const _HeartBorder({super.side = BorderSide.none});

  @override
  OutlinedBorder copyWith({BorderSide? side}) => _HeartBorder(side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    
    // Tạo khoảng lùi để hình trái tim không bị dính viền tuyệt đối
    final d = min(width, height) * 0.95; 
    final offsetX = (width - d) / 2 + rect.left;
    final offsetY = (height - d) / 2 + rect.top + d * 0.05; // Dịch xuống một chút để cân bằng trọng tâm

    final path = Path();
    path.moveTo(offsetX + d / 2, offsetY + d * 0.35); // Điểm giữa lõm
    
    // Nhánh trái
    path.cubicTo(
      offsetX + d * 0.15, offsetY - d * 0.1, 
      offsetX - d * 0.15, offsetY + d * 0.45, 
      offsetX + d / 2, offsetY + d * 0.95
    );
    
    // Nhánh phải
    path.moveTo(offsetX + d / 2, offsetY + d * 0.35);
    path.cubicTo(
      offsetX + d * 0.85, offsetY - d * 0.1, 
      offsetX + d * 1.15, offsetY + d * 0.45, 
      offsetX + d / 2, offsetY + d * 0.95
    );
    
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final path = getOuterPath(rect, textDirection: textDirection);
    final paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _HeartBorder(side: side.scale(t));
}

class _FlowerBorder extends OutlinedBorder {
  final int petals;
  const _FlowerBorder({this.petals = 12, super.side = BorderSide.none});

  @override
  OutlinedBorder copyWith({BorderSide? side, int? petals}) => 
      _FlowerBorder(petals: petals ?? this.petals, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final width = rect.width;
    final height = rect.height;
    final centerX = rect.left + width / 2;
    final centerY = rect.top + height / 2;
    final radius = min(width, height) / 2;
    final innerRadius = radius * 0.88;

    for (int i = 0; i < petals; i++) {
      final startAngle = (i * 2 * pi) / petals;
      final endAngle = ((i + 1) * 2 * pi) / petals;
      final midAngle = startAngle + (endAngle - startAngle) / 2;

      if (i == 0) {
        path.moveTo(
          centerX + innerRadius * cos(startAngle),
          centerY + innerRadius * sin(startAngle),
        );
      }
      path.quadraticBezierTo(
        centerX + radius * cos(midAngle),
        centerY + radius * sin(midAngle),
        centerX + innerRadius * cos(endAngle),
        centerY + innerRadius * sin(endAngle),
      );
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final path = getOuterPath(rect, textDirection: textDirection);
    final paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _FlowerBorder(petals: petals, side: side.scale(t));
}

class _PolygonBorder extends OutlinedBorder {
  final int sides;
  const _PolygonBorder({this.sides = 6, super.side = BorderSide.none});

  @override
  OutlinedBorder copyWith({BorderSide? side, int? sides}) => 
      _PolygonBorder(sides: sides ?? this.sides, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final width = rect.width;
    final height = rect.height;
    final centerX = rect.left + width / 2;
    final centerY = rect.top + height / 2;
    final radius = min(width, height) / 2;
    // Xoay đỉnh đầu tiên lên trên
    final offsetAngle = (sides == 4) ? 0.0 : -pi / 2; 

    for (int i = 0; i < sides; i++) {
      final angle = offsetAngle + (i * 2 * pi) / sides;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final path = getOuterPath(rect, textDirection: textDirection);
    final paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _PolygonBorder(sides: sides, side: side.scale(t));
}
