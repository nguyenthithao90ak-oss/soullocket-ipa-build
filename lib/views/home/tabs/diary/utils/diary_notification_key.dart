import 'dart:convert';

import 'package:crypto/crypto.dart';

String _diaryNotificationDigest(String kind, String value) =>
    '$kind:${sha256.convert(utf8.encode(value)).toString().substring(0, 40)}';

/// Khóa không chứa nội dung bài, nhưng ổn định khi cùng một bài được retry.
String diaryPostNotificationIdempotencyKey(String postId) =>
    _diaryNotificationDigest('diary_post', postId.trim());

/// Tạo dấu nhận diện ổn định cho một lượt chọn ảnh. Dùng đường dẫn local để
/// lần retry sau khi app mở lại vẫn giữ cùng khóa trong đa số trường hợp.
String diaryMemoryBatchIdentity({
  required String uid,
  required String houseId,
  required Iterable<String> paths,
}) {
  final normalizedPaths =
      paths.map((path) => path.trim()).where((path) => path.isNotEmpty).toList()
        ..sort();
  return _diaryNotificationDigest(
    'diary_memory_batch',
    jsonEncode([uid.trim(), houseId.trim(), normalizedPaths]),
  );
}

String diaryMemoryBatchNotificationIdempotencyKey(String batchIdentity) =>
    _diaryNotificationDigest('diary_memory', batchIdentity.trim());
