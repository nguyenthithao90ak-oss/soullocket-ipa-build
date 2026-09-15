import 'dart:async';

/// Font và bảo trì cache không được giữ hàng chờ của các dịch vụ nền.
/// Nhóm khởi tạo cốt lõi vẫn phải hoàn tất trước dịch vụ nền/quảng cáo.
Future<void> runDeferredBootstrapTasks({
  required Future<void> Function() prepareCore,
  required Future<void> Function() warmFonts,
  required Future<void> Function() maintainCache,
  required Future<void> Function() startBackground,
  required Future<void> Function() initializeAds,
  required void Function(Object, StackTrace) onOptionalError,
  Future<void> Function(Duration)? wait,
}) async {
  final delay = wait ?? (duration) => Future<void>.delayed(duration);

  Future<void> runOptional(Future<void> Function() task) async {
    try {
      await task();
    } catch (error, stackTrace) {
      onOptionalError(error, stackTrace);
    }
  }

  unawaited(runOptional(warmFonts));
  unawaited(
    runOptional(() async {
      await delay(const Duration(seconds: 30));
      await maintainCache();
    }),
  );

  await prepareCore();
  unawaited(runOptional(startBackground));
  unawaited(
    runOptional(() async {
      await delay(const Duration(seconds: 3));
      await initializeAds();
    }),
  );
}

/// Giãn các lượt quét cache qua nhiều lần mở app, gộp lời gọi đồng thời.
/// Chỉ áp dụng cho bản tải tạm; không dùng cho dữ liệu người dùng/offline DB.
class CacheMaintenanceGate {
  CacheMaintenanceGate({
    this.minimumInterval = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration minimumInterval;
  final DateTime Function() _now;
  Future<bool>? _pending;

  Future<bool> runIfDue({
    required Future<int?> Function() readLastRunMs,
    required Future<void> Function(int) writeLastRunMs,
    required Future<void> Function() task,
  }) async {
    final pending = _pending;
    if (pending != null) return pending;
    final run = () async {
      final previous = await readLastRunMs();
      final now = _now();
      if (previous != null) {
        final elapsed = now.difference(
          DateTime.fromMillisecondsSinceEpoch(previous),
        );
        // Đồng hồ bị chỉnh lùi không được khóa bảo trì vô thời hạn.
        if (!elapsed.isNegative && elapsed < minimumInterval) return false;
      }
      await task();
      await writeLastRunMs(_now().millisecondsSinceEpoch);
      return true;
    }();
    _pending = run;
    try {
      return await run;
    } finally {
      if (identical(_pending, run)) _pending = null;
    }
  }
}
