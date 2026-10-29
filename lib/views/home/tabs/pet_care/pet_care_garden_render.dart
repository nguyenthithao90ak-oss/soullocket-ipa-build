part of 'pet_care_garden_3d.dart';

/// Giữ display list của cảnh tĩnh trong vòng đời một vườn. Ticker của bé
/// không dựng lưới, chiếu lại cảnh hay tô từng pixel trên CPU.
class _GardenRenderCache {
  final forest = _GardenForest();
  ui.Picture? picture;
  Object? key;
  List<_ScreenFace> faces = const [];
  final _petMasks = <int, (Object, Path)>{};
  int buildCount = 0;
  int lastBuildMicros = 0;
  int lastProjectionMicros = 0;
  int lastDrawMicros = 0;
  int lastGeometryMicros = 0;
  Object? geometryKey;
  _GardenBsp? world, composed;
  Object? fixtureKey;
  List<_WorldFace> orderWorld(
    Object key,
    List<_WorldFace> Function() build,
    GardenVec3 eye,
    Object nextFixture,
    List<_WorldFace> Function() moving,
  ) {
    if (geometryKey != key || world == null) {
      final watch = Stopwatch()..start();
      world = _GardenBsp.build(build());
      geometryKey = key;
      composed = null;
      lastGeometryMicros = watch.elapsedMicroseconds;
    }
    if (fixtureKey != nextFixture || composed == null) {
      composed = world?.withMoving(moving());
      fixtureKey = nextFixture;
    }
    final ordered = <_WorldFace>[];
    composed?.order(eye, ordered);
    return ordered;
  }

  void prepare(
    Object next,
    List<_ScreenFace> Function() project,
    Size size, {
    void Function(Canvas)? background,
  }) {
    if (key == next && picture != null) return;
    final watch = Stopwatch()..start();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    canvas.clipRect(Offset.zero & size);
    background?.call(canvas);
    faces = project();
    lastProjectionMicros = watch.elapsedMicroseconds;
    _gardenDrawMesh(canvas, faces);
    lastDrawMicros = watch.elapsedMicroseconds - lastProjectionMicros;
    final previous = picture;
    picture = recorder.endRecording();
    previous?.dispose();
    key = next;
    buildCount++;
    lastBuildMicros = watch.elapsedMicroseconds;
  }

  Path petMask(
    int index,
    Rect bounds,
    GardenVec3 base,
    PetGardenCamera camera,
    Size size,
  ) {
    final maskKey = (key, bounds, base.x, base.y, base.z);
    final saved = _petMasks[index];
    if (saved != null && saved.$1 == maskKey) return saved.$2;
    final path = _gardenOcclusion(faces, bounds, base, camera, size);
    _petMasks[index] = (maskKey, path);
    return path;
  }

  void dispose() {
    picture?.dispose();
    picture = null;
    key = null;
    faces = const [];
    world = null;
    composed = null;
    fixtureKey = null;
    _petMasks.clear();
    geometryKey = null;
  }
}

void _gardenDrawMesh(Canvas c, List<_ScreenFace> faces) {
  var count = 0;
  for (final face in faces) {
    count += (face.length - 2) * 3;
  }
  if (count == 0) return;
  final positions = Float32List(count * 2), colors = Int32List(count);
  var cursor = 0;
  void add(_ScreenFace face, int index) {
    positions[cursor * 2] = face.coordinates[index * 3];
    positions[cursor * 2 + 1] = face.coordinates[index * 3 + 1];
    colors[cursor] = face.colors[index].toARGB32();
    cursor++;
  }

  for (final face in faces) {
    for (var i = 1; i < face.length - 1; i++) {
      add(face, 0);
      add(face, i);
      add(face, i + 1);
    }
  }
  // Không có index nên không bị giới hạn Uint16; gửi thẳng buffer cho engine.
  final vertices = ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    colors: colors,
  );
  c.drawVertices(vertices, BlendMode.dst, Paint());
  vertices.dispose();
}

/// Mặt phẳng đứng của bé: nghịch đảo độ sâu là hàm tuyến tính trên màn hình.
/// Cắt đúng phần đa giác ở phía trước thay vì cho cả vật thể che bé theo tâm.
Path _gardenOcclusion(
  List<_ScreenFace> faces,
  Rect bounds,
  GardenVec3 base,
  PetGardenCamera camera,
  Size size,
) {
  final normal = GardenVec3(camera.forward.x, 0, camera.forward.z).unit;
  final plane = (base - camera.eye).dot(normal);
  final result = Path();
  if (plane.abs() < .001) return result;
  final lens = camera.lens(size);
  final x = camera.right.dot(normal) / (lens * plane);
  final y = -camera.up.dot(normal) / (lens * plane);
  final constant =
      camera.forward.dot(normal) / plane -
      x * size.width / 2 -
      y * size.height * .48;
  double inverseAt(Offset p) => x * p.dx + y * p.dy + constant;
  for (final face in faces) {
    if (!face.bounds.overlaps(bounds)) continue;
    final polygon = <Offset>[];
    for (var i = 0; i < face.length; i++) {
      final j = (i + 1) % face.length;
      final a = face.point(i), b = face.point(j);
      final da = face.inverse(i) - inverseAt(a) - .00015;
      final db = face.inverse(j) - inverseAt(b) - .00015;
      if (da > 0) polygon.add(a);
      if ((da > 0) != (db > 0)) {
        polygon.add(Offset.lerp(a, b, da / (da - db))!);
      }
    }
    if (polygon.length < 3) continue;
    var winding = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      winding += a.dx * b.dy - a.dy * b.dx;
    }
    // Các mặt chồng nhau phải cùng chiều để không tạo lỗ trong vùng che.
    result.addPolygon(winding < 0 ? polygon.reversed.toList() : polygon, true);
  }
  return result;
}
