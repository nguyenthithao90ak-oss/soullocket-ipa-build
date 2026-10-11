import 'dart:async';
import 'dart:typed_data';

/// Callback tiến độ cục bộ của một lần PUT, tính theo số byte đã đưa vào
/// request. Không tạo listener hay đọc thêm dữ liệu realtime từ server.
typedef StorageUploadProgressCallback = void Function(double progress);

abstract final class StorageUploadProgress {
  static const int chunkSize = 64 * 1024;

  /// Chừa 5% cho finalize/receipt sau khi PUT đã gửi đủ byte.
  static const double putProgressCeiling = 0.95;

  static Future<void> pumpBytes({
    required StreamSink<List<int>> sink,
    required Uint8List bytes,
    StorageUploadProgressCallback? onProgress,
  }) async {
    var sent = 0;
    onProgress?.call(0);
    try {
      while (sent < bytes.length) {
        final end = sent + chunkSize < bytes.length
            ? sent + chunkSize
            : bytes.length;
        sink.add(bytes.sublist(sent, end));
        sent = end;
        onProgress?.call(sent / bytes.length);
      }
    } finally {
      await sink.close();
    }
  }

  static Future<void> pumpStream({
    required StreamSink<List<int>> sink,
    required Stream<List<int>> source,
    required int totalBytes,
    StorageUploadProgressCallback? onProgress,
  }) async {
    if (totalBytes <= 0) {
      await sink.close();
      throw StateError('Invalid upload size');
    }
    var sent = 0;
    onProgress?.call(0);
    try {
      await for (final chunk in source) {
        if (chunk.isEmpty) continue;
        sent += chunk.length;
        if (sent > totalBytes) {
          throw StateError('Upload stream exceeded expected size');
        }
        sink.add(chunk);
        onProgress?.call(sent / totalBytes);
      }
      if (sent != totalBytes) {
        throw StateError('Upload stream ended before expected size');
      }
    } finally {
      await sink.close();
    }
  }
}
