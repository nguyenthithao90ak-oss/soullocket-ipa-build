import 'dart:collection';
import 'dart:ui';

abstract final class PetGardenMap {
  static const size = Size(960, 1040);
  // Giữ tọa độ luống cũ, mở thêm lối đi quanh hàng rào.
  static const bounds = Rect.fromLTRB(-420, -360, 1380, 1400);
  static const plots = [
    Offset(220, 555),
    Offset(420, 555),
    Offset(220, 715),
    Offset(420, 715),
    Offset(220, 875),
    Offset(420, 875),
    Offset(730, 525),
    Offset(770, 705),
    Offset(700, 890),
  ];
  static final _obstacles = [
    // Hai cổng thật: cuối lối đá và cạnh vườn táo.
    const Rect.fromLTWH(-12, 0, 24, 1040),
    const Rect.fromLTWH(0, 0, 960, 24),
    const Rect.fromLTWH(0, 1020, 520, 24),
    const Rect.fromLTWH(660, 1020, 300, 24),
    const Rect.fromLTWH(938, 10, 24, 520),
    const Rect.fromLTWH(938, 690, 24, 340),
    const Rect.fromLTWH(120, 90, 500, 335),
    const Rect.fromLTWH(650, 210, 250, 220),
    for (var i = 0; i < plots.length; i++)
      Rect.fromCenter(
        center: plots[i],
        width: i < 6 ? 158 : 94,
        height: i < 6 ? 100 : 68,
      ),
  ];
  static bool walkable(Offset p) {
    if (!bounds.deflate(20).contains(p)) {
      return false;
    }
    return !_obstacles.any((r) => r.contains(p));
  }

  /// Đường đi ô lưới tránh nhà, ao và luống, không bước xuyên đồ vật.
  static List<Offset> route(Offset start, Offset destination) {
    final nodes = <int, Offset>{};
    final columns = (bounds.width / 40).ceil();
    final rows = (bounds.height / 40).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final p = bounds.topLeft + Offset(x * 40.0 + 20, y * 40.0 + 20);
        if (walkable(p)) nodes[y * columns + x] = p;
      }
    }
    int nearest(Offset p) => nodes.keys.reduce(
      (a, b) =>
          (nodes[a]! - p).distanceSquared < (nodes[b]! - p).distanceSquared
          ? a
          : b,
    );
    final from = nearest(start), to = nearest(destination);
    final queue = Queue<int>()..add(from);
    final previous = <int, int?>{from: null};
    while (queue.isNotEmpty && !previous.containsKey(to)) {
      final id = queue.removeFirst();
      for (final next in [id - 1, id + 1, id - columns, id + columns]) {
        if (!nodes.containsKey(next) ||
            previous.containsKey(next) ||
            (nodes[next]! - nodes[id]!).distance > 41) {
          continue;
        }
        previous[next] = id;
        queue.add(next);
      }
    }
    if (!previous.containsKey(to)) return const [];
    final result = <Offset>[];
    int? cursor = to;
    while (cursor != null) {
      result.add(nodes[cursor]!);
      cursor = previous[cursor];
    }
    return result.reversed.toList();
  }

  /// Nối các đoạn nhìn thẳng được với nhau để không ngoặt ở mỗi ô 40px.
  /// Mọi đoạn mới vẫn được kiểm tra toàn đường, kể cả sát góc luống/nhà.
  static List<Offset> smoothRoute(Offset start, Offset destination) {
    final grid = route(start, destination);
    if (grid.isEmpty) return grid;
    bool clear(Offset a, Offset b) {
      if (!walkable(a) || !walkable(b)) return false;
      final delta = b - a;
      for (final box in _obstacles) {
        final rect = box.inflate(.1);
        var low = 0.0, high = 1.0;
        for (final axis in [
          (a.dx, delta.dx, rect.left, rect.right),
          (a.dy, delta.dy, rect.top, rect.bottom),
        ]) {
          if (axis.$2.abs() < .00001) {
            if (axis.$1 < axis.$3 || axis.$1 > axis.$4) {
              low = 2;
              break;
            }
          } else {
            final t0 = (axis.$3 - axis.$1) / axis.$2;
            final t1 = (axis.$4 - axis.$1) / axis.$2;
            final near = t0 < t1 ? t0 : t1, far = t0 > t1 ? t0 : t1;
            if (near > low) low = near;
            if (far < high) high = far;
          }
        }
        if (low <= high) return false;
      }
      return true;
    }

    final result = <Offset>[];
    var from = start, index = 0;
    while (index < grid.length) {
      var last = index;
      for (var i = index; i < grid.length; i++) {
        if (clear(from, grid[i])) last = i;
      }
      result.add(grid[last]);
      from = grid[last];
      index = last + 1;
    }
    if (walkable(destination) && clear(from, destination)) {
      result.add(destination);
    }
    return result;
  }
}
