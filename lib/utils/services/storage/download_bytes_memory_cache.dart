import 'dart:typed_data';

/// Cache byte tải xuống; không thay thế cache ảnh đã giải mã của Flutter.
class DownloadBytesMemoryCache {
  DownloadBytesMemoryCache({
    this.maxBytes = 16 * 1024 * 1024,
    this.maxEntries = 40,
    DateTime Function()? now,
  }) : assert(maxBytes >= 0),
       assert(maxEntries >= 0),
       _now = now ?? DateTime.now;

  final int maxBytes;
  final int maxEntries;
  final DateTime Function() _now;
  final Map<String, _CachedDownloadBytes> _entries = {};
  int _retainedBytes = 0;

  int get length => _entries.length;
  int get retainedBytes => _retainedBytes;

  Uint8List? get(String key, {required Duration ttl}) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (_now().difference(entry.modifiedAt) > ttl) {
      remove(key);
      return null;
    }

    // Đưa mục vừa đọc về cuối để chỉ loại mục ít được dùng nhất.
    _entries.remove(key);
    _entries[key] = entry;
    return entry.bytes;
  }

  void put(
    String key,
    Uint8List bytes, {
    required DateTime modifiedAt,
    required Duration ttl,
  }) {
    remove(key);
    // Một view nhỏ vẫn giữ sống toàn bộ buffer gốc, phải tính đủ bộ nhớ đó.
    final retainedSize = bytes.buffer.lengthInBytes;
    if (bytes.isEmpty ||
        maxEntries == 0 ||
        retainedSize > maxBytes ||
        _now().difference(modifiedAt) > ttl) {
      return;
    }

    while (_entries.isNotEmpty &&
        (_entries.length >= maxEntries ||
            _retainedBytes + retainedSize > maxBytes)) {
      remove(_entries.keys.first);
    }
    _entries[key] = _CachedDownloadBytes(bytes, modifiedAt, retainedSize);
    _retainedBytes += retainedSize;
  }

  void remove(String key) {
    final removed = _entries.remove(key);
    if (removed != null) _retainedBytes -= removed.retainedSize;
  }
}

class _CachedDownloadBytes {
  const _CachedDownloadBytes(this.bytes, this.modifiedAt, this.retainedSize);

  final Uint8List bytes;
  final DateTime modifiedAt;
  final int retainedSize;
}
