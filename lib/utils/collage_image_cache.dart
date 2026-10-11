import 'dart:math' as math;
import 'dart:ui' as ui;

/// Cache ảnh đã giải mã của trình ghép ảnh. Mỗi caller giữ một handle clone riêng,
/// nên xóa cache không hủy ảnh mà một lượt render đang sử dụng.
class CollageImageCache {
  CollageImageCache({this.maxBytes = 32 << 20, this.maxEntries = 30})
    : assert(maxBytes > 0),
      assert(maxEntries > 0);

  final int maxBytes;
  final int maxEntries;
  final _images = <String, ui.Image>{};
  int _bytes = 0;
  bool _disposed = false;

  int get estimatedBytes => _bytes;
  int get length => _images.length;

  ui.Image? get(String key) {
    final image = _images.remove(key);
    if (image == null) return null;
    _images[key] = image;
    return image.clone();
  }

  void put(String key, ui.Image image) {
    if (_disposed) return;
    final previous = _images.remove(key);
    if (previous != null) {
      _bytes -= _cost(previous);
      previous.dispose();
    }
    final cost = _cost(image);
    if (cost > maxBytes) return;
    while (_images.isNotEmpty &&
        (_bytes + cost > maxBytes || _images.length >= maxEntries)) {
      final oldest = _images.remove(_images.keys.first)!;
      _bytes -= _cost(oldest);
      oldest.dispose();
    }
    _images[key] = image.clone();
    _bytes += cost;
  }

  int _cost(ui.Image image) => image.width * image.height * 4;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _bytes = 0;
  }
}

/// Giới hạn tổng pixel giải mã theo số ảnh, không đổi kích thước ảnh xuất.
/// Đây là ngân sách RGBA ước tính; không phải trần RAM của toàn ứng dụng.
abstract final class CollageDecodePolicy {
  static const previewBytes = 32 << 20;
  static const fullBytes = 64 << 20;

  static int maxDimension(int photoCount, {required bool preview}) {
    final maxDimension = preview ? 720 : 1400;
    final budget = preview ? previewBytes : fullBytes;
    final count = math.max(1, photoCount);
    return math.min(maxDimension, math.sqrt(budget / (count * 4)).floor());
  }
}
