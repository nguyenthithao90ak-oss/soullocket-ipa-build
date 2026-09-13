import 'dart:math' as math;
import 'dart:ui';

/// Lấy viền thật thay vì hình hộp bao ngoài (trái tim, hoa, góc bo...).
/// Chỉ ghép các nét có chung đầu mút; không tạo đường tắt qua nội dung.
List<Offset>? sampleHomeCompanionOutline(Path path) {
  final runs = <List<Offset>>[];
  for (final metric in path.computeMetrics()) {
    if (!metric.length.isFinite || metric.length < 1) continue;
    final count = (metric.length / 5).ceil().clamp(8, 256);
    runs.add([
      for (var i = 0; i <= count; i++)
        if (metric.getTangentForOffset(metric.length * i / count)
            case final tangent?)
          tangent.position,
    ]);
  }
  if (runs.isEmpty || runs.any((run) => run.length < 2)) return null;
  final result = [...runs.removeAt(0)];
  while (runs.isNotEmpty) {
    final index = runs.indexWhere(
      (run) =>
          (run.first - result.last).distance < 0.1 ||
          (run.last - result.last).distance < 0.1,
    );
    if (index < 0) return null;
    final run = runs.removeAt(index);
    final forward = (run.first - result.last).distance < 0.1;
    result.addAll((forward ? run : run.reversed).skip(1));
  }
  if ((result.last - result.first).distance > 0.1) return null;
  result[result.length - 1] = result.first;
  // Bỏ điểm thẳng hàng trên cạnh dài để kiểm tra va chạm nhẹ hơn.
  final simplified = <Offset>[result.first];
  for (var i = 1; i < result.length - 1; i++) {
    final before = result[i] - simplified.last;
    final after = result[i + 1] - result[i];
    final cross = (before.dx * after.dy - before.dy * after.dx).abs();
    if (cross > 0.001 * math.max(1, before.distance + after.distance) ||
        before.dx * after.dx + before.dy * after.dy < 0) {
      simplified.add(result[i]);
    }
  }
  simplified.add(result.last);
  return simplified.length < 4 ? null : List.unmodifiable(simplified);
}
