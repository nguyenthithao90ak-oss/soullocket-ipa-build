import 'dart:async';

/// Dùng thời điểm tọa độ, không dùng thời điểm listener nhận lại cache.
abstract final class GpsFreshness {
  static const maxAge = Duration(minutes: 3);

  static bool isFresh(int? timestamp, {DateTime? now}) {
    if (timestamp == null || timestamp <= 0) return false;
    final age = (now ?? DateTime.now()).millisecondsSinceEpoch - timestamp;
    return age >= 0 && age <= maxAge.inMilliseconds;
  }

  /// Điểm gần đúng vẫn xem được nhưng không dùng để suy luận đang ở gần nhau.
  static bool canUseProximity(
    int? timestamp,
    double? accuracy, {
    DateTime? now,
  }) =>
      isFresh(timestamp, now: now) &&
      accuracy != null &&
      accuracy.isFinite &&
      accuracy >= 0 &&
      accuracy <= 100;
}

/// Hẹn đúng lúc điểm đang xem hết hạn. Không polling/heartbeat hay đọc Firebase.
/// Màn hình phải cancel khi ẩn, và schedule lại từ snapshot khi resume.
class GpsFreshnessDeadline {
  GpsFreshnessDeadline({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Timer? _timer;
  int _generation = 0;

  void schedule(Iterable<int?> timestamps, void Function() onExpired) {
    cancel();
    final values = timestamps.whereType<int>().toList(growable: false);
    final generation = _generation;
    void arm() {
      if (generation != _generation) return;
      final now = _now();
      final deadlines = values
          .where((value) => GpsFreshness.isFresh(value, now: now))
          .map((value) => value + GpsFreshness.maxAge.inMilliseconds + 1);
      if (deadlines.isEmpty) return;
      final next = deadlines.reduce((a, b) => a < b ? a : b);
      _timer = Timer(
        Duration(milliseconds: next - now.millisecondsSinceEpoch),
        () {
          if (generation != _generation) return;
          _timer = null;
          onExpired();
          arm();
        },
      );
    }

    arm();
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }
}
