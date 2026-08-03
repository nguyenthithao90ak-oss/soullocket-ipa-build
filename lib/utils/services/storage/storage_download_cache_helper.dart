import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

class StorageDownloadCacheHelper {
  const StorageDownloadCacheHelper();

  static final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 40;

  String stableCacheToken(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  String cacheFileExtension(String url) {
    final parsed = Uri.tryParse(url);
    final path = parsed?.path ?? url;
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty || ext.length > 10) {
      return '.bin';
    }
    return ext;
  }

  Future<File> resolveCachedDownloadFile(
    String url, {
    required String namespace,
    String? cacheKey,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final normalizedNamespace = namespace.trim().isEmpty
        ? 'downloads'
        : namespace.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cacheDir = Directory(
      p.join(tempDir.path, 'soullocket_cache', normalizedNamespace),
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final keySource =
        (cacheKey ?? '').trim().isNotEmpty ? '${cacheKey!.trim()}|$url' : url;
    final fileName = '${stableCacheToken(keySource)}${cacheFileExtension(url)}';
    return File(p.join(cacheDir.path, fileName));
  }

  Future<bool> hasFreshCache(
    File cacheFile, {
    required Duration ttl,
  }) async {
    if (!await cacheFile.exists()) {
      return false;
    }
    final fileSize = await cacheFile.length();
    if (fileSize <= 0) {
      return false;
    }
    final modifiedAt = await cacheFile.lastModified();
    return DateTime.now().difference(modifiedAt) <= ttl;
  }

  Future<File?> getCachedNetworkFile(
    String url, {
    String namespace = 'downloads',
    String? cacheKey,
    Duration ttl = const Duration(hours: 18),
    bool forceRefresh = false,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final cacheFile = await resolveCachedDownloadFile(
      normalizedUrl,
      namespace: namespace,
      cacheKey: cacheKey,
    );

    if (!forceRefresh && await hasFreshCache(cacheFile, ttl: ttl)) {
      return cacheFile;
    }

    try {
      final response = await http
          .get(Uri.parse(normalizedUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
        return cacheFile;
      }
      debugPrint(
        'Cached download failed ($namespace): ${AppErrorMapper.resolve(
          response.statusCode,
          fallbackMessage: 'Không thể tải cache từ mạng.',
        ).message} $normalizedUrl',
      );
    } catch (e) {
      debugPrint('Cached download error ($namespace): ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể tải cache từ mạng.',
      ).message}');
    }

    if (await cacheFile.exists() && await cacheFile.length() > 0) {
      return cacheFile;
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

    final keySource = (cacheKey ?? '').trim().isNotEmpty
        ? '${cacheKey!.trim()}|$normalizedUrl'
        : normalizedUrl;
    final memKey = stableCacheToken(keySource);

    if (!forceRefresh && _memoryCache.containsKey(memKey)) {
      return _memoryCache[memKey];
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
        if (_memoryCache.length >= _maxMemoryCacheSize) {
          _memoryCache.remove(_memoryCache.keys.first);
        }
        _memoryCache[memKey] = bytes;
      }
      return bytes;
    } catch (e) {
      debugPrint(
          'Cached bytes read error ($namespace): ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể đọc cache đã tải.',
      ).message}');
      return null;
    }
  }

  Future<void> purgeStaleCache(
      {Duration staleThreshold = const Duration(days: 3)}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final baseCacheDir = Directory(p.join(tempDir.path, 'soullocket_cache'));
      if (!await baseCacheDir.exists()) {
        return;
      }

      final now = DateTime.now();
      int deletedCount = 0;
      int freedBytes = 0;

      await for (final entity
          in baseCacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > staleThreshold) {
              freedBytes += stat.size;
              await entity.delete();
              deletedCount++;
            }
          } catch (_) {}
        }
      }

      if (deletedCount > 0) {
        debugPrint(
            'StorageDownloadCacheHelper: Purged $deletedCount stale files, freed ${(freedBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      }
    } catch (e) {
      debugPrint('StorageDownloadCacheHelper: Failed to purge stale cache: $e');
    }
  }
}
