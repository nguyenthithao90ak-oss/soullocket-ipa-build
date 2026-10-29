part of 'companion_3d_renderer.dart';

// Depth buffer theo điểm ảnh giải quyết phần giao giữa da, mắt, tay và áo.
// Lưới màu cuối được gửi lên Canvas theo dải, không chờ giải mã ui.Image
// hoặc đổi pose sau frame. Model/rig vẫn được tính lại từ tọa độ 3D thật.
void _paintDepthBuffer(
  Canvas canvas,
  List<_Projected> projected,
  List<_Triangle> triangles, {
  Rect? sceneBounds,
}) {
  if (triangles.isEmpty) return;
  var left = double.infinity, top = double.infinity;
  var right = -double.infinity, bottom = -double.infinity;
  for (final t in triangles) {
    final p = projected[t.group];
    for (final v in [t.a, t.b, t.c]) {
      final x = p.xy[v * 2], y = p.xy[v * 2 + 1];
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }
  }
  if (sceneBounds != null) {
    left = math.max(left, sceneBounds.left - 1);
    top = math.max(top, sceneBounds.top - 1);
    right = math.min(right, sceneBounds.right + 1);
    bottom = math.min(bottom, sceneBounds.bottom + 1);
    if (right <= left || bottom <= top) return;
  }
  final transform = canvas.getTransform();
  final scale = math.max(
    math.sqrt(transform[0] * transform[0] + transform[1] * transform[1]),
    math.sqrt(transform[4] * transform[4] + transform[5] * transform[5]),
  );
  final targetHeight = ((bottom - top) * scale * 1.2).ceil().clamp(
    144,
    sceneBounds == null ? 288 : 700,
  );
  var step = math.max(
    (bottom - top) / targetHeight,
    (right - left) / (sceneBounds == null ? 230 : 460),
  );
  if (step <= 0 || !step.isFinite) return;
  var width = ((right - left) / step).ceil() + 5;
  var height = ((bottom - top) / step).ceil() + 5;
  // Giới hạn bộ nhớ raster; mỗi lượt gửi Canvas dùng indices Uint16 riêng.
  final maxPixels = sceneBounds == null ? 63000 : 300000;
  if (width * height > maxPixels) {
    step *= math.sqrt(width * height / (maxPixels - 1000)) * 1.02;
    width = ((right - left) / step).ceil() + 5;
    height = ((bottom - top) / step).ceil() + 5;
  }
  left -= step * 2;
  top -= step * 2;
  final depth = Float32List(width * height)
    ..fillRange(0, width * height, -double.infinity);
  final colors = Int32List(width * height);
  final inverseStep = 1 / step;
  for (final t in triangles) {
    final p = projected[t.group];
    final ax = (p.xy[t.a * 2] - left) * inverseStep;
    final ay = (p.xy[t.a * 2 + 1] - top) * inverseStep;
    final bx = (p.xy[t.b * 2] - left) * inverseStep;
    final by = (p.xy[t.b * 2 + 1] - top) * inverseStep;
    final cx = (p.xy[t.c * 2] - left) * inverseStep;
    final cy = (p.xy[t.c * 2 + 1] - top) * inverseStep;
    final denominator = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
    if (denominator.abs() < 1e-9) continue;
    final minX = math.min(ax, math.min(bx, cx)).floor().clamp(0, width - 1);
    final maxX = math.max(ax, math.max(bx, cx)).ceil().clamp(0, width - 1);
    final minY = math.min(ay, math.min(by, cy)).floor().clamp(0, height - 1);
    final maxY = math.max(ay, math.max(by, cy)).ceil().clamp(0, height - 1);
    final daX = (by - cy) / denominator, daY = (cx - bx) / denominator;
    final dbX = (cy - ay) / denominator, dbY = (ax - cx) / denominator;
    var rowA = daX * (minX - cx) + daY * (minY - cy);
    var rowB = dbX * (minX - cx) + dbY * (minY - cy);
    final za = p.z[t.a], zb = p.z[t.b], zc = p.z[t.c];
    final ca = p.colors[t.a], cb = p.colors[t.b], cc = p.colors[t.c];
    final ar = (ca >> 16) & 255, ag = (ca >> 8) & 255, ab = ca & 255;
    final br = (cb >> 16) & 255, bg = (cb >> 8) & 255, bb = cb & 255;
    final cr = (cc >> 16) & 255, cg = (cc >> 8) & 255, cblue = cc & 255;
    for (var y = minY; y <= maxY; y++) {
      var wa = rowA, wb = rowB, pixel = y * width + minX;
      for (var x = minX; x <= maxX; x++, pixel++) {
        final wc = 1 - wa - wb;
        if (wa >= -1e-7 && wb >= -1e-7 && wc >= -1e-7) {
          final z = wa * za + wb * zb + wc * zc;
          if (z > depth[pixel]) {
            depth[pixel] = z;
            final r = (wa * ar + wb * br + wc * cr).round().clamp(0, 255);
            final g = (wa * ag + wb * bg + wc * cg).round().clamp(0, 255);
            final b = (wa * ab + wb * bb + wc * cblue).round().clamp(0, 255);
            colors[pixel] = 0xff000000 | r << 16 | g << 8 | b;
          }
        }
        wa += daX;
        wb += dbX;
      }
      rowA += daY;
      rowB += dbY;
    }
  }

  // Chia theo dải hàng để indices Uint16 luôn nằm trong 65.535 đỉnh,
  // kể cả khi một cảnh 3D phủ toàn màn hình điện thoại.
  final rowsPerBatch = math.max(2, 62000 ~/ width);
  for (var row = 0; row < height - 1; row += rowsPerBatch - 1) {
    final rows = math.min(rowsPerBatch, height - row);
    final xy = Float32List(width * rows * 2);
    final batchColors = Int32List(width * rows);
    final indices = <int>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < width; x++) {
        final at = y * width + x, source = (row + y) * width + x;
        xy[at * 2] = left + x * step;
        xy[at * 2 + 1] = top + (row + y) * step;
        batchColors[at] = colors[source];
        if (x + 1 < width &&
            y + 1 < rows &&
            (colors[source] != 0 ||
                colors[source + 1] != 0 ||
                colors[source + width] != 0 ||
                colors[source + width + 1] != 0)) {
          indices.addAll([
            at,
            at + 1,
            at + width,
            at + 1,
            at + width + 1,
            at + width,
          ]);
        }
      }
    }
    final vertices = Vertices.raw(
      VertexMode.triangles,
      xy,
      colors: batchColors,
      indices: Uint16List.fromList(indices),
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }
}
