import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'private_image_disk_cache.dart';

Future<Uint8List> downloadPrivateImage(
  String url, {
  required bool Function() isCurrent,
  int? width,
  http.Client? client,
  void Function(int bytes)? onDownloadedBytes,
  void Function(Uint8List bytes)? onDownloadedOriginalBytes,
}) async {
  final transport = client ?? http.Client();
  final elapsed = Stopwatch()..start();
  StreamIterator<List<int>>? chunks;
  Duration remaining() {
    if (!isCurrent()) throw StateError('Cancelled image');
    final left = const Duration(seconds: 25) - elapsed.elapsed;
    if (left <= Duration.zero) throw TimeoutException('Image download');
    return left;
  }

  try {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid media URL');
    }
    final response = await transport
        .send(http.Request('GET', uri)..followRedirects = false)
        .timeout(remaining());
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > PrivateImageDiskCache.maxImageBytes) {
      throw const FormatException('Unusable image response');
    }
    final buffer = BytesBuilder(copy: false);
    chunks = StreamIterator(response.stream);
    while (await chunks.moveNext().timeout(remaining())) {
      if (buffer.length + chunks.current.length >
          PrivateImageDiskCache.maxImageBytes) {
        throw const FormatException('Image too large');
      }
      buffer.add(chunks.current);
    }
    if (buffer.isEmpty ||
        (response.contentLength != null &&
            buffer.length != response.contentLength)) {
      throw const FormatException('Incomplete image');
    }
    remaining();
    final bytes = buffer.takeBytes();
    onDownloadedOriginalBytes?.call(bytes);
    onDownloadedBytes?.call(bytes.length);
    if (width == null) return bytes;
    final targetWidth = width.clamp(64, 1600);
    // Ảnh gốc đã không rộng hơn độ rộng cần: giữ nguyên
    // tệp WebP/JPEG (~100–250 KB) thay vì giải mã rồi mã hóa lại PNG (~2 MB, tốn CPU và đĩa).
    if (await _widthOf(bytes) <= targetWidth) return bytes;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      allowUpscaling: false,
    );
    try {
      if (codec.frameCount > 1) return bytes;
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        remaining();
        return data?.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            ) ??
            bytes;
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    transport.close();
    await chunks?.cancel();
  }
}

/// Độ rộng ảnh đọc từ phần đầu tệp, không giải mã toàn ảnh.
Future<int> _widthOf(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return descriptor.width;
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
