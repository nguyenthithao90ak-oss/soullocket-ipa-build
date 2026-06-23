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
  final String authorUid;
  final Color color;
  final double width;
  final List<Offset> points;
  final bool normalized;

  _DrawStroke({
    required this.color,
    required this.width,
    required this.points,
    this.id = '',
    this.authorUid = '',
    this.normalized = false,
  });

  List<Offset> resolvedPoints(Size size) {
    if (!normalized) {
      return points;
    }
    return points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList(growable: false);
  }
}
