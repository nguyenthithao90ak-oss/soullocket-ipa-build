import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

import 'download_bytes_memory_cache.dart';

class StorageDownloadCacheHelper {
  const StorageDownloadCacheHelper();

  static const maxDownloadBytes = 64 * 1024 * 1024;
  static const maxDiskCacheBytes = 256 * 1024 * 1024;
  static const diskRetention = Duration(days: 30);
  static Future<void>? _purging;

  static final _memoryCache = DownloadBytesMemoryCache();
  static final Map<String, Future<File?>> _downloads = {};

  String _normalizeNamespace(String namespace) => namespace.trim().isEmpty
      ? 'downloads'
      : namespace.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  String _memoryCacheKey(String url, String namespace, String? cacheKey) {
    final normalizedNamespace = _normalizeNamespace(namespace);
    final normalizedKey = (cacheKey ?? '').trim();
    // Giữ namespace riêng và dùng khóa đầy đủ để tránh va chạm hash trong RAM.
    return '${normalizedNamespace.length}:$normalizedNamespace'
        '${normalizedKey.length}:$normalizedKey$url';
  }

  // Hash đủ dài để URL khác nhau không dùng nhầm cùng một tệp cache.
  String stableCacheToken(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  String cacheFileExtension(String url) {
    final parsed = Uri.tryParse(url);
    final path = parsed?.path ?? url;
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty || ext.length > 10) {
      return '.bin';
    }
    return ext;
  }

  @visibleForTesting
  Future<Directory> cacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    return Directory(p.join(tempDir.path, 'soullocket_cache'));
  }

  Future<File> resolveCachedDownloadFile(
    String url, {
    required String namespace,
    String? cacheKey,
  }) async {
    final baseDirectory = await cacheDirectory();
    final normalizedNamespace = _normalizeNamespace(namespace);
    final cacheDir = Directory(p.join(baseDirectory.path, normalizedNamespace));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final keySource = _memoryCacheKey(url, namespace, cacheKey);
    final fileName = '${stableCacheToken(keySource)}${cacheFileExtension(url)}';
    return File(p.join(cacheDir.path, fileName));
  }

  Future<bool> hasFreshCache(File cacheFile, {required Duration ttl}) async {
    try {
      final stat = await cacheFile.stat();
      return stat.type == FileSystemEntityType.file &&
          stat.size > 0 &&
          stat.size <= maxDownloadBytes &&
          DateTime.now().difference(stat.modified) <= ttl;
    } on FileSystemException {
      return false;
    }
  }

  Future<File?> getCachedNetworkFile(
    String url, {
    String namespace = 'downloads',
    String? cacheKey,
    Duration ttl = const Duration(hours: 18),
    bool forceRefresh = false,
  }) async {
    final normalizedUrl = url.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (kIsWeb ||
        uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }

    final memKey = _memoryCacheKey(normalizedUrl, namespace, cacheKey);
    if (forceRefresh) _memoryCache.remove(memKey);

    final cacheFile = await resolveCachedDownloadFile(
      normalizedUrl,
      namespace: namespace,
      cacheKey: cacheKey,
    );

    if (!forceRefresh && await hasFreshCache(cacheFile, ttl: ttl)) {
      return cacheFile;
    }

    // Gộp cả forceRefresh đồng thời để nhiều widget chỉ tải một lần.
    final pending = _downloads[cacheFile.path];
    if (pending != null) return pending;
    final task = _downloadFile(normalizedUrl, cacheFile, memKey, namespace);
    _downloads[cacheFile.path] = task;
    try {
      return await task;
    } finally {
      if (identical(_downloads[cacheFile.path], task)) {
        _downloads.remove(cacheFile.path);
      }
    }
  }

  Future<File?> _downloadFile(
    String url,
    File cacheFile,
    String memKey,
    String namespace,
  ) async {
    final client = http.Client();
    final pendingFile = File('${cacheFile.path}.download');
    StreamIterator<List<int>>? chunks;
    RandomAccessFile? output;
    final elapsed = Stopwatch()..start();
    Duration remaining() {
      final left = const Duration(seconds: 10) - elapsed.elapsed;
      if (left <= Duration.zero) throw TimeoutException('Download timeout');
      return left;
    }

    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(remaining());
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxDownloadBytes) {
        throw const FormatException('Unusable download response');
      }
      // Ghi theo luồng, giới hạn cả phản hồi không có Content-Length.
      output = await pendingFile.open(mode: FileMode.write);
      chunks = StreamIterator(response.stream);
      var received = 0;
      while (await chunks.moveNext().timeout(remaining())) {
        received += chunks.current.length;
        if (received > maxDownloadBytes) {
          throw const FormatException('Download too large');
        }
        await output.writeFrom(chunks.current);
      }
      if (received == 0 ||
          (response.contentLength != null &&
              received != response.contentLength)) {
        throw const FormatException('Incomplete download');
      }
      await output.close();
      output = null;
      await pendingFile.rename(cacheFile.path);
      _memoryCache.remove(memKey);
      await purgeStaleCache();
      return cacheFile;
    } catch (_) {
      // Không ghi URL/chữ ký truy cập riêng tư vào log.
      debugPrint('Cached download failed ($namespace)');
    } finally {
      client.close();
      await chunks?.cancel();
      await output?.close();
      try {
        if (await pendingFile.exists()) await pendingFile.delete();
      } catch (_) {
        // Tệp tạm sẽ được dọn trong lần bảo trì tiếp theo.
      }
    }
    try {
      final stat = await cacheFile.stat();
      if (stat.type == FileSystemEntityType.file &&
          stat.size > 0 &&
          stat.size <= maxDownloadBytes) {
        return cacheFile;
      }
    } on FileSystemException {
      // Cache có thể vừa được dọn bởi một tác vụ khác.
    }
    return null;
  }

  Future<Uint8List?> downloadBytesWithCache(
    String url, {
    String namespace = 'downloads',
    String? cacheKey,
    Duration ttl = const Duration(hours: 18),
    bool forceRefresh = false,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) return null;

    final memKey = _memoryCacheKey(normalizedUrl, namespace, cacheKey);

    if (forceRefresh) {
      _memoryCache.remove(memKey);
    } else {
      final cached = _memoryCache.get(memKey, ttl: ttl);
      if (cached != null) return cached;
    }

    final file = await getCachedNetworkFile(
      normalizedUrl,
      namespace: namespace,
      cacheKey: cacheKey,
      ttl: ttl,
      forceRefresh: forceRefresh,
    );
    if (file == null) {
      return null;
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        // Dùng tuổi thật của file: bản disk cũ vẫn đọc được khi offline,
        // nhưng không được gia hạn TTL thành một bản RAM mới tinh.
        try {
          _memoryCache.put(
            memKey,
            bytes,
            modifiedAt: await file.lastModified(),
            ttl: ttl,
          );
        } catch (_) {
          // File có thể vừa được dọn sau khi đọc: vẫn trả dữ liệu đã đọc được,
          // chỉ bỏ qua cache RAM khi không xác định được tuổi của file.
          _memoryCache.remove(memKey);
        }
      }
      return bytes;
    } catch (e) {
      debugPrint(
        'Cached bytes read error ($namespace): ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể đọc cache đã tải.').message}',
      );
      return null;
    }
  }

  Future<void> purgeStaleCache({
    Duration staleThreshold = diskRetention,
    int maxBytes = maxDiskCacheBytes,
  }) async {
    if (kIsWeb) return;
    if (maxBytes < 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    final pending = _purging;
    if (pending != null) return pending;
    final task = _purge(staleThreshold, maxBytes);
    _purging = task;
    try {
      await task;
    } finally {
      if (identical(_purging, task)) _purging = null;
    }
  }

  Future<void> _purge(Duration retention, int maxBytes) async {
    try {
      final directory = await cacheDirectory();
      if (!await directory.exists()) return;
      final now = DateTime.now();
      final retained = <({File file, FileStat stat})>[];
      var total = 0;
      bool active(String path) =>
          _downloads.containsKey(path) ||
          (path.endsWith('.download') &&
              _downloads.containsKey(path.substring(0, path.length - 9)));
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (stat.type != FileSystemEntityType.file) continue;
          total += stat.size;
          if (active(entity.path)) continue;
          final temporary = entity.path.endsWith('.download');
          final ageLimit = temporary ? const Duration(days: 1) : retention;
          if (now.difference(stat.modified) > ageLimit) {
            await entity.delete();
            total -= stat.size;
          } else {
            retained.add((file: entity, stat: stat));
          }
        } on FileSystemException {
          // Tệp có thể vừa bị hệ điều hành hoặc tác vụ khác dọn.
        }
      }
      // Chỉ dọn bản tải lại được trong thư mục cache; giữ tệp đang tải.
      retained.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
      for (final entry in retained) {
        if (total <= maxBytes) break;
        if (active(entry.file.path)) continue;
        try {
          await entry.file.delete();
          total -= entry.stat.size;
        } on FileSystemException {
          // Thử lại trong lần bảo trì tiếp theo.
        }
      }
    } catch (_) {
      debugPrint('StorageDownloadCacheHelper: Cache maintenance unavailable');
    }
  }
}
