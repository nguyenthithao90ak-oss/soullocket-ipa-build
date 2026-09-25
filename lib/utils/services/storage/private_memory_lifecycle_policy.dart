import 'dart:math';

/// Nhận diện bản ghi mới ngay cả khi build sau tắt cờ upload private.
abstract final class PrivateMemoryLifecyclePolicy {
  static bool isPrivateId(String id) =>
      RegExp(r'^pm_[a-f0-9]{64}$').hasMatch(id.trim());

  static bool allowsLegacyFallback({
    required bool privateUploadEnabled,
    required Iterable<Map<String, dynamic>> records,
  }) =>
      !privateUploadEnabled &&
      records.every(
        (record) =>
            record['privateUploadVersion'] != 1 &&
            !isPrivateId(record['id']?.toString() ?? ''),
      );

  static String newOperationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
