import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../storage/private_image_disk_cache.dart';
import '../storage/private_image_download.dart';

class _SoulCachedImage {
  _SoulCachedImage(this.image) : age = Stopwatch()..start();
  final ui.Image image;
  final Stopwatch age;
  int get bytes => image.width * image.height * 4;
}

/// Cache dùng chung cho bìa và game; khóa theo tài khoản/nhà/ID ảnh,
/// không theo URL đã ký. Mỗi màn hình sở hữu một clone, tự dispose khi rời.
class SoulBlockImageCache {
  SoulBlockImageCache._()
    : _currentUidOverride = null,
      _diskOverride = null,
      _downloadOverride = null;

  @visibleForTesting
  SoulBlockImageCache.forTesting({
    required String? Function() currentUid,
    required PrivateImageDiskCache diskCache,
    required Future<Uint8List> Function(String, bool Function()) download,
  }) : _currentUidOverride = currentUid,
       _diskOverride = diskCache,
       _downloadOverride = download;

  static final instance = SoulBlockImageCache._();
  static const _maxDecodedBytes = 12 * 1024 * 1024;
  static const _maxEntries = 6;
  static const imageWidth = 1024;

  final String? Function()? _currentUidOverride;
  final PrivateImageDiskCache? _diskOverride;
  final Future<Uint8List> Function(String, bool Function())? _downloadOverride;
  String? get _currentUid => _currentUidOverride == null
      ? FirebaseAuth.instance.currentUser?.uid
      : _currentUidOverride();
  PrivateImageDiskCache? get _disk =>
      kIsWeb ? null : _diskOverride ?? PrivateImageDiskCache.instance;

  final _images = <String, _SoulCachedImage>{};
  final _pending = <String, Future<void>>{};
  StreamSubscription<User?>? _auth;
  String? _uid;
  String? _houseId;
  int _generation = 0;

  List<int?> variants(int diaryWidth) =>
      <int?>{imageWidth, diaryWidth, 768, 720, 640, null}.toList();

  void _bind(String uid, String houseId) {
    if (_currentUidOverride == null) {
      _auth ??= FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user?.uid != _uid) clear();
      }, onError: (Object _) => clear());
    }
    if (_uid == uid && _houseId == houseId) return;
    clear();
    _uid = uid;
    _houseId = houseId;
  }

  void clear() {
    _generation++;
    for (final entry in _images.values) {
      entry.image.dispose();
    }
    _images.clear();
    _pending.clear();
    _uid = null;
    _houseId = null;
  }

  String _key(String uid, String houseId, String id) =>
      PrivateImageDiskCache.key(uid, houseId, id, imageWidth);

  Future<Set<String>> cachedIds({
    required String uid,
    required String houseId,
    required Iterable<String> ids,
    required int diaryWidth,
  }) async {
    if (_currentUid != uid) return <String>{};
    _bind(uid, houseId);
    final generation = _generation;
    final list = ids.take(80).toList();
    final cached = {
      for (final id in list)
        if (_images.containsKey(_key(uid, houseId, id))) id,
    };
    if (!kIsWeb) {
      cached.addAll(
        await _disk!.cachedMemoryIds(uid, houseId, list, variants(diaryWidth)),
      );
    }
    return generation == _generation ? cached : <String>{};
  }

  Future<ui.Image?> load({
    required String uid,
    required String houseId,
    required String id,
    required int diaryWidth,
    required Future<String?> Function() resolveUrl,
  }) async {
    if (_currentUid != uid) return null;
    _bind(uid, houseId);
    final generation = _generation;
    final key = _key(uid, houseId, id);
    final cached = _images.remove(key);
    if (cached != null) {
      if (cached.age.elapsed < PrivateImageDiskCache.ttl) {
        _images[key] = cached;
        if (kDebugMode) debugPrint('[SoulBlockPhoto] RAM hit; no image GET');
        return cached.image.clone();
      }
      cached.image.dispose();
    }
    final future = _pending.putIfAbsent(
      key,
      () => _load(
        uid: uid,
        houseId: houseId,
        id: id,
        diaryWidth: diaryWidth,
        generation: generation,
        key: key,
        resolveUrl: resolveUrl,
      ),
    );
    try {
      await future;
      if (generation != _generation || _currentUid != uid) {
        return null;
      }
      return _images[key]?.image.clone();
    } finally {
      if (identical(_pending[key], future)) _pending.remove(key);
    }
  }

  Future<void> _load({
    required String uid,
    required String houseId,
    required String id,
    required int diaryWidth,
    required int generation,
    required String key,
    required Future<String?> Function() resolveUrl,
  }) async {
    bool current() => generation == _generation && _currentUid == uid;
    final disk = _disk;
    ui.Image? image;
    try {
      for (final width in variants(diaryWidth)) {
        final variantKey = PrivateImageDiskCache.key(uid, houseId, id, width);
        final bytes = await disk?.read(uid, variantKey);
        if (!current()) return;
        if (bytes == null) continue;
        try {
          image = await _decodeImage(bytes);
        } catch (_) {
          // Ảnh cache hỏng không được khóa một Nhật ký suốt 14 ngày. Bỏ bản
          // hỏng rồi thử kích thước khác hoặc tải lại đúng một lần.
          if (!current()) return;
          await disk?.remove(uid, variantKey);
          continue;
        }
        if (kDebugMode) {
          debugPrint('[SoulBlockPhoto] encrypted disk hit; no image GET');
        }
        break;
      }
      if (!current()) return;
      if (image == null) {
        final url = await resolveUrl();
        if (!current() || url == null) return;
        final bytes =
            await (_downloadOverride?.call(url, current) ??
                downloadPrivateImage(
                  url,
                  isCurrent: current,
                  onDownloadedBytes: (count) {
                    if (kDebugMode) {
                      debugPrint('[SoulBlockPhoto] image GET bytes=$count');
                    }
                  },
                ));
        if (!current()) return;
        // Giải mã một lần, giới hạn cả hai chiều trước khi ghi PNG. Ảnh dọc
        // rất dài không còn bị phóng thành bitmap lớn ở bước thu nhỏ theo rộng.
        image = await _decodeImage(bytes);
        if (!current()) return;
        if (disk != null) {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (!current()) return;
          if (data != null) {
            final resized = data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
            await disk.write(uid, key, resized, current);
            if (kDebugMode) {
              debugPrint(
                '[SoulBlockPhoto] one image GET; cachedBytes=${resized.length}',
              );
            }
          }
        }
      }
      if (!current()) return;
      _images[key] = _SoulCachedImage(image);
      image = null;
      int totalBytes() =>
          _images.values.fold(0, (sum, entry) => sum + entry.bytes);
      while (_images.length > _maxEntries || totalBytes() > _maxDecodedBytes) {
        _images.remove(_images.keys.first)!.image.dispose();
      }
    } finally {
      image?.dispose();
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        imageWidth / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
