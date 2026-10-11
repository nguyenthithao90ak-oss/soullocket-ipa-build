part of '../../drawing_studio_screen.dart';

class _CanvasRatioPreset {
  final String id;
  final String label;
  final double ratio;

  const _CanvasRatioPreset({
    required this.id,
    required this.label,
    required this.ratio,
  });
}

class _DrawStroke {
  final String id;
  final Color color;
  final double width;
  final List<Offset> points;
  final bool isEraser;
  final int? stickerIndex;

  _DrawStroke({
    required this.color,
    required this.width,
    required this.points,
    this.id = '',
    this.isEraser = false,
    this.stickerIndex,
  });
}
