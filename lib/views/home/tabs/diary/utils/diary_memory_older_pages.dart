/// Vị trí của một bản ghi theo thứ tự RTDB khi `orderByChild('ts')`: giá trị `ts` thô và key.
class MemoryOrderCursor {
  const MemoryOrderCursor(this.value, this.key);

  final Object? value;
  final String key;
}

int _typeRank(Object? value) {
  if (value == null) return 0;
  if (value is bool) return 1;
  if (value is num) return 2;
  if (value is String) return 3;
  return 4;
}

int _compareKeys(String a, String b) {
  // RTDB xếp key dạng số nguyên 32-bit trước, theo giá trị số; còn lại theo chuỗi.
  final aInt = int.tryParse(a);
  final bInt = int.tryParse(b);
  if (aInt != null && bInt != null) return aInt.compareTo(bInt);
  if (aInt != null) return -1;
  if (bInt != null) return 1;
  return a.compareTo(b);
}

/// So sánh hai bản ghi đúng như RTDB sắp xếp khi `orderByChild`:
/// null < bool < số < chuỗi < object; cùng giá trị thì so key.
int compareRtdbChildOrder(
  Object? aValue,
  String aKey,
  Object? bValue,
  String bKey,
) {
  final rankA = _typeRank(aValue);
  final rankB = _typeRank(bValue);
  if (rankA != rankB) return rankA.compareTo(rankB);
  var result = 0;
  if (aValue is bool && bValue is bool) {
    result = aValue == bValue ? 0 : (aValue ? 1 : -1);
  } else if (aValue is num && bValue is num) {
    result = aValue.compareTo(bValue);
  } else if (aValue is String && bValue is String) {
    result = aValue.compareTo(bValue);
  }
  return result != 0 ? result : _compareKeys(aKey, bKey);
}

Object? _tsOf(Object? value) => value is Map ? value['ts'] : null;

/// Các trang kỷ niệm cũ hơn cửa sổ live (N bản mới nhất, cập nhật realtime).
///
/// Trước đây mỗi lần "tải thêm" tăng `limitToLast` của listener nên server gửi lại cả
/// danh sách. Nay listener live giữ cố định; mỗi trang chỉ đọc các bản cũ hơn bản cũ
/// nhất đã có. Lớp này giữ các trang đó và nối liền với cửa sổ live:
/// - bản bị ảnh mới đẩy ra khỏi cửa sổ live được chuyển xuống trang cũ để không biến mất;
/// - bản đã có trong cửa sổ live thì bỏ khỏi trang cũ (live luôn là bản mới nhất);
/// - xóa/sửa trên máy này được áp vào trang cũ qua [forget]/[patch].
/// Xóa từ máy khác ở các trang cũ chỉ thấy khi tải lại danh sách (đổi nhà/mở lại tab).
class DiaryMemoryOlderPages {
  final Map<String, Map<String, dynamic>> _items = <String, Map<String, dynamic>>{};
  Map<String, Object?>? _lastLiveWindow;
  MemoryOrderCursor? _oldestLoaded;
  MemoryOrderCursor? _liveOldest;
  int _liveCount = 0;
  bool _exhausted = false;
  int _version = 0;

  /// Tăng mỗi khi tập bản ghi hiển thị thêm thay đổi; dùng làm khóa ghi nhớ feed.
  int get version => _version;
  bool get exhausted => _exhausted;
  int get liveCount => _liveCount;
  Map<String, Map<String, dynamic>> get items => Map.unmodifiable(_items);

  /// Mốc để đọc trang tiếp theo: bản cũ nhất đã tải, chưa có trang thì là bản cũ nhất của live.
  MemoryOrderCursor? get nextCursor => _oldestLoaded ?? _liveOldest;

  /// Chỉ tải thêm khi cửa sổ live đã đầy (có thể còn bản cũ hơn) và chưa hết dữ liệu.
  bool canLoadMore(int windowLimit) =>
      !_exhausted && _liveCount >= windowLimit && nextCursor != null;

  /// Ghi nhận một sự kiện của listener live; [orderedChildren] theo đúng thứ tự query (cũ → mới).
  void applyLiveWindow(
    List<MapEntry<String, Object?>> orderedChildren, {
    required int windowLimit,
  }) {
    final current = <String, Object?>{
      for (final child in orderedChildren) child.key: child.value,
    };
    _liveCount = orderedChildren.length;
    final first = orderedChildren.isEmpty ? null : orderedChildren.first;
    _liveOldest = first == null
        ? null
        : MemoryOrderCursor(_tsOf(first.value), first.key);
    final previous = _lastLiveWindow;
    _lastLiveWindow = current;

    var changed = false;
    for (final key in current.keys) {
      if (_items.remove(key) != null) changed = true;
    }
    // Chưa tải trang cũ thì trang đầu sẽ đọc từ bản cũ nhất hiện tại, không cần giữ gì.
    final liveOldest = _liveOldest;
    if (previous != null &&
        _oldestLoaded != null &&
        liveOldest != null &&
        orderedChildren.length >= windowLimit) {
      previous.forEach((key, value) {
        if (current.containsKey(key) || value is! Map) return;
        final pushedOut =
            compareRtdbChildOrder(
              _tsOf(value),
              key,
              liveOldest.value,
              liveOldest.key,
            ) <
            0;
        // Bản cũ hơn mốc live là bị ảnh mới đẩy ra; bản trong khoảng live mà mất là đã bị xóa.
        if (pushedOut) {
          _items[key] = Map<String, dynamic>.from(value);
          changed = true;
        }
      });
    }
    if (changed) _version++;
  }

  /// Thêm một trang đọc từ query `endBefore(nextCursor).limitToLast(pageSize)` (cũ → mới).
  void addPage(
    List<MapEntry<String, Object?>> orderedChildren, {
    required int pageSize,
  }) {
    final live = _lastLiveWindow;
    for (final child in orderedChildren) {
      final value = child.value;
      if (value is! Map) continue;
      if (live != null && live.containsKey(child.key)) continue;
      _items[child.key] = Map<String, dynamic>.from(value);
    }
    if (orderedChildren.isNotEmpty) {
      final first = orderedChildren.first;
      _oldestLoaded = MemoryOrderCursor(_tsOf(first.value), first.key);
    }
    if (orderedChildren.length < pageSize) _exhausted = true;
    _version++;
  }

  /// Bỏ các bản đã xóa trên máy này khỏi trang cũ.
  void forget(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      if (_items.remove(id) != null) changed = true;
    }
    if (changed) _version++;
  }

  /// Cập nhật trường của một bản trong trang cũ (ví dụ đổi ngày album trên máy này).
  void patch(String id, Map<String, Object?> fields) {
    final item = _items[id];
    if (item == null) return;
    item.addAll(fields);
    _version++;
  }

  /// Về trạng thái ban đầu khi đổi nhà/tài khoản hoặc dựng lại danh sách.
  void reset() {
    _items.clear();
    _lastLiveWindow = null;
    _oldestLoaded = null;
    _liveOldest = null;
    _liveCount = 0;
    _exhausted = false;
    _version++;
  }
}
