import 'dart:math';
import 'package:flutter/material.dart';

class DoodleBackground extends StatelessWidget {
  const DoodleBackground({
    super.key,
    required this.child,
    this.opacity = 0.06,
    this.isDark = true,
  });

  final Widget child;
  final double opacity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CuteDoodlePainter(
                opacity: opacity,
                isDark: isDark,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CuteDoodlePainter extends CustomPainter {
  _CuteDoodlePainter({
    required this.opacity,
    required this.isDark,
  });

  final double opacity;
  final bool isDark;

  // Cố định seed để các vị trí không thay đổi mỗi lần build
  static final Random _random = Random(42);

  // Danh sách các ký tự/emoji trang trí dễ thương
  static const List<String> _doodles = [
    '✨',
    '💖',
    '🌸',
    '☁️',
    '🦋',
    '🧸',
    '💌',
    '🎀',
    '💫',
    '🌙',
    '🌷',
    '🫧',
    '🎨',
    '🎵',
    '💭',
    '✏️',
    '✩',
    '♡',
    '✧',
    '❀',
    '♪',
    '✿',
    '☾',
    '★',
  ];

  static List<_DoodleItem>? _cachedDoodles;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    if (_cachedDoodles == null || _cachedDoodles!.isEmpty) {
      _generateDoodles(size);
    }

    final color = isDark ? Colors.white : Colors.black;
    final defaultStyle = TextStyle(
      color: color.withValues(alpha: opacity),
      fontSize: 24,
      height: 1.0,
    );

    for (final item in _cachedDoodles!) {
      // Scaled position
      final dx = item.normalizedX * size.width;
      final dy = item.normalizedY * size.height;

      final textSpan = TextSpan(
        text: item.text,
        style: defaultStyle.copyWith(
          fontSize: item.size,
          color: color.withValues(
              alpha: item.isEmoji ? (opacity * 1.5).clamp(0.0, 1.0) : opacity),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(item.rotation);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  void _generateDoodles(Size size) {
    _cachedDoodles = [];
    // Tính toán số lượng dựa trên kích thước màn hình
    final count = ((size.width * size.height) / 12000).clamp(20, 80).toInt();

    for (int i = 0; i < count; i++) {
      final text = _doodles[_random.nextInt(_doodles.length)];
      final normalizedX = _random.nextDouble();
      final normalizedY = _random.nextDouble();
      final rotation = (_random.nextDouble() - 0.5) * 1.5; // Góc quay
      final size = 16.0 + _random.nextDouble() * 24.0;
      // Ký tự unicode đơn giản không có màu thì coi như text thường, emoji thì coi như emoji
      final isEmoji = text.runes.first > 10000;

      _cachedDoodles!.add(
        _DoodleItem(
          text: text,
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          rotation: rotation,
          size: size,
          isEmoji: isEmoji,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CuteDoodlePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.isDark != isDark;
  }
}

class _DoodleItem {
  _DoodleItem({
    required this.text,
    required this.normalizedX,
    required this.normalizedY,
    required this.rotation,
    required this.size,
    required this.isEmoji,
  });

  final String text;
  final double normalizedX;
  final double normalizedY;
  final double rotation;
  final double size;
  final bool isEmoji;
}
