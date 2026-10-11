import 'dart:async';

/// Gom các lượt đọc cùng một nhánh RTDB xảy ra gần như cùng lúc.
///
/// Mỗi lần mở app, nhiều service cùng `get()` nhánh `houses/{id}/presence` (đo 07/10/2026:
/// 2–7 lượt ~1,3 KB mỗi lần mở, nhiều lượt trùng trong cùng một giây). `get()` luôn tải từ
/// server, nên các lượt trùng được gộp: dùng chung request đang chạy và kết quả vừa có trong
/// [reuse]. Khóa gồm UID để không dùng kết quả của tài khoản khác sau khi đổi tài khoản.
class RtdbReadCoalescer {
  RtdbReadCoalescer({
    this.reuse = const Duration(seconds: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Dùng chung trong app cho các nhánh đọc lặp khi mở app (presence).
  static final RtdbReadCoalescer shared = RtdbReadCoalescer();

  final Duration reuse;
  final DateTime Function() _now;
  final Map<String, _CoalescedRead> _reads = {};

  /// [key] nên gồm UID và đường dẫn; [load] chỉ chạy khi không có lượt đọc dùng lại được.
  Future<Object?> read(String key, Future<Object?> Function() load) {
    final existing = _reads[key];
    if (existing != null &&
        (existing.completedAt == null ||
            _now().difference(existing.completedAt!) < reuse)) {
      return existing.future;
    }
    final entry = _CoalescedRead(load());
    _reads[key] = entry;
    entry.future.then(
      (_) {
        if (identical(_reads[key], entry)) entry.completedAt = _now();
      },
      onError: (Object _) {
        // Lỗi không được giữ lại: lượt sau đọc lại server.
        if (identical(_reads[key], entry)) _reads.remove(key);
      },
    );
    return entry.future;
  }

  void clear() => _reads.clear();
}

class _CoalescedRead {
  _CoalescedRead(this.future);

  final Future<Object?> future;
  DateTime? completedAt;
}
