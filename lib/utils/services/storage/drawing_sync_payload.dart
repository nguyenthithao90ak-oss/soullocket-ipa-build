/// Giới hạn payload mạng; nét vẽ gốc tại máy vẫn giữ nguyên độ chi tiết.
List<List<double>> boundedDrawingPoints(
  List<List<double>> points, {
  required int maxPoints,
}) {
  assert(maxPoints >= 2);
  if (points.isEmpty) return const [];
  final count = points.length.clamp(1, maxPoints);
  return List.generate(count, (index) {
    // Lấy đều cả đầu/cuối, tránh cắt mất phần đuôi của nét dài.
    final source = count == 1
        ? 0
        : (index * (points.length - 1) / (count - 1)).round();
    return points[source]
        .take(2)
        .map((coordinate) {
          final value = coordinate.isFinite ? coordinate.clamp(0.0, 1.0) : 0.0;
          return (value * 10000).round() / 10000;
        })
        .toList(growable: false);
  }, growable: false);
}
