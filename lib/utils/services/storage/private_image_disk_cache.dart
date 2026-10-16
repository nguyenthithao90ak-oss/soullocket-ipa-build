import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class PrivateImageDiskCache {
  PrivateImageDiskCache({
    required this.openBox,
    required this.currentUid,
    DateTime Function()? now,
    this.maxBytes = 512 * 1024 * 1024,
    this.maxEntries = 1000,
  }) : _now = now ?? DateTime.now;

  // Ảnh riêng tư giữ trên máy tối đa 60 ngày / 1.000 bản / 512 MB (cái nào tới trước);
  // người dùng xóa được trong Cài đặt, ảnh bị xóa khỏi Nhật ký được dọn theo nhãn.
  static const ttl = Duration(days: 60);
  static const maxImageBytes = 16 * 1024 * 1024;
  static PrivateImageDiskCache? _instance;
  static Future<LazyBox<dynamic>>? _opening;
  static StreamSubscription<User?>? _auth;
  static String? _lastUid;

  static PrivateImageDiskCache get instance {
    if (_instance != null) return _instance!;
    final auth = FirebaseAuth.instance;
    _lastUid = auth.currentUser?.uid;
    _instance = PrivateImageDiskCache(
      openBox: _openEncryptedBox,
      currentUid: () => auth.currentUser?.uid,
    );
    _auth ??= auth.authStateChanges().listen((user) {
      if (user?.uid == _lastUid) return;
      _lastUid = user?.uid;
      unawaited(_instance!.clear());
    }, onError: (Object _) => unawaited(_instance!.clear()));
    return _instance!;
  }

  static Future<void> clearIfInitialized() async {
    await _instance?.clear();
  }

  static Future<LazyBox<dynamic>> _openEncryptedBox() {
    final existing = _opening;
    if (existing != null) return existing;

    final opening = () async {
      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      const name = 'private_memory_images_v2';
      var encoded = await storage.read(key: name);
      if (encoded == null) {
        encoded = base64Encode(Hive.generateSecureKey());
        await storage.write(key: name, value: encoded);
      }
      return Hive.openLazyBox<dynamic>(
        name,
        encryptionCipher: HiveAesCipher(base64Decode(encoded)),
        compactionStrategy: (entries, deleted) => deleted > 20,
      );
    }();
    _opening = opening;
    // Không giữ mãi Future lỗi sau một lần mở Hive thất bại tạm thời. Lượt đọc
    // kế tiếp phải được phép thử mở lại thay vì vô hiệu hóa cache cả phiên app.
    unawaited(
      opening.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_opening, opening)) _opening = null;
        },
      ),
    );
    return opening;
  }

  final Future<LazyBox<dynamic>> Function() openBox;
  final String? Function() currentUid;
  final DateTime Function() _now;
  final int maxBytes;
  final int maxEntries;
  Future<void> _work = Future<void>.value();
  int _generation = 0;

  static String key(String uid, String houseId, String memoryId, int? width) =>
      sha256
          .convert(utf8.encode(jsonEncode([uid, houseId, memoryId, width])))
          .toString();

  /// Nhãn chung cho mọi kích thước của một ảnh, để dọn khi ảnh bị xóa
  /// mà không lưu memoryId dạng đọc được trong chỉ mục.
  static String memoryTag(String uid, String houseId, String memoryId) => sha256
      .convert(utf8.encode(jsonEncode(['memory', uid, houseId, memoryId])))
      .toString()
      .substring(0, 32);

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _work.then((_) => action());
    _work = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<LazyBox<dynamic>> _box(String uid) async {
    final box = await openBox();
    final owner = await box.get('_owner');
    if (owner != uid) {
      await box.clear();
      await box.put('_owner', uid);
    }
    return box;
  }

  Future<Uint8List?> read(String uid, String cacheKey) {
    final generation = _generation;
    return _serial(() async {
      if (kIsWeb || uid != currentUid() || generation != _generation) {
        return null;
      }
      try {
        final box = await _box(uid);
        final index = Map<String, dynamic>.from(
          await box.get('_index') as Map? ?? {},
        );
        final metadata = index[cacheKey];
        if (metadata is! Map) return null;
        final savedAt = metadata['savedAt'] as int;
        final age = _now().millisecondsSinceEpoch - savedAt;
        if (age < 0 || age >= ttl.inMilliseconds) {
          await box.delete(cacheKey);
          index.remove(cacheKey);
          await box.put('_index', index);
          return null;
        }
        final bytes = await box.get(cacheKey);
        if (uid != currentUid() || generation != _generation) return null;
        if (bytes is! Uint8List ||
            bytes.isEmpty ||
            bytes.length != metadata['size']) {
          return null;
        }
        // Chỉ đẩy lên cuối hàng LRU khi bản ghi đã nằm ở nửa cũ: chỉ mục tới 1.000
        // mục, ghi lại mỗi lần xem ảnh sẽ làm cuộn album chậm.
        final keys = index.keys.toList(growable: false);
        if (keys.indexOf(cacheKey) < keys.length ~/ 2) {
          index.remove(cacheKey);
          index[cacheKey] = metadata;
          await box.put('_index', index);
        }
        return uid == currentUid() && generation == _generation ? bytes : null;
      } catch (_) {
        return null;
      }
    });
  }

  Future<Uint8List?> readPreview(
    String uid,
    String houseId,
    String memoryId,
  ) async {
    final generation = _generation;
    final tag = memoryTag(uid, houseId, memoryId);
    final cacheKey = await _serial<String?>(() async {
      if (kIsWeb || uid != currentUid() || generation != _generation) {
        return null;
      }
      try {
        final box = await _box(uid);
        final index = Map<String, dynamic>.from(
          await box.get('_index') as Map? ?? {},
        );
        if (uid != currentUid() || generation != _generation) return null;
        final now = _now().millisecondsSinceEpoch;
        for (final entry in index.entries.toList().reversed) {
          final metadata = entry.value;
          if (metadata is! Map ||
              metadata['mid'] != tag ||
              metadata['savedAt'] is! int) {
            continue;
          }
          final age = now - (metadata['savedAt'] as int);
          if (age >= 0 && age < ttl.inMilliseconds) return entry.key;
        }
        return null;
      } catch (_) {
        return null;
      }
    });
    if (cacheKey == null ||
        uid != currentUid() ||
        generation != _generation) {
      return null;
    }
    return read(uid, cacheKey);
  }

  /// Chỉ đọc chỉ mục để ưu tiên ảnh Nhật ký đã có trên máy, không giải mã
  /// hàng loạt ảnh và không mở URL mạng để kiểm tra cache.
  Future<Set<String>> cachedMemoryIds(
    String uid,
    String houseId,
    Iterable<String> memoryIds,
    Iterable<int?> widths,
  ) {
    final generation = _generation;
    return _serial(() async {
      if (kIsWeb || uid != currentUid() || generation != _generation) {
        return <String>{};
      }
      try {
        final box = await _box(uid);
        final index = Map<String, dynamic>.from(
          await box.get('_index') as Map? ?? {},
        );
        if (uid != currentUid() || generation != _generation) {
          return <String>{};
        }
        final now = _now().millisecondsSinceEpoch;
        final variants = widths.toSet();
        return {
          for (final id in memoryIds.take(80))
            if (variants.any((width) {
              final metadata = index[key(uid, houseId, id, width)];
              if (metadata is! Map || metadata['savedAt'] is! int) return false;
              final age = now - (metadata['savedAt'] as int);
              return age >= 0 && age < ttl.inMilliseconds;
            }))
              id,
        };
      } catch (_) {
        return <String>{};
      }
    });
  }

  Future<void> write(
    String uid,
    String cacheKey,
    Uint8List bytes,
    bool Function() isCurrent, {
    String? memoryTag,
  }) {
    final generation = _generation;
    return _serial(() async {
      bool allowed() =>
          uid == currentUid() && generation == _generation && isCurrent();
      if (kIsWeb ||
          !allowed() ||
          bytes.isEmpty ||
          bytes.length > maxImageBytes ||
          bytes.length > maxBytes ||
          maxEntries < 1) {
        return;
      }
      try {
        final box = await _box(uid);
        if (!allowed()) return;
        final index = Map<String, dynamic>.from(
          await box.get('_index') as Map? ?? {},
        );
        final now = _now().millisecondsSinceEpoch;
        for (final entry in index.entries.toList()) {
          final age = now - ((entry.value as Map)['savedAt'] as int);
          if (age < 0 || age >= ttl.inMilliseconds || entry.key == cacheKey) {
            await box.delete(entry.key);
            index.remove(entry.key);
          }
        }
        var total = index.values.fold<int>(
          0,
          (sum, value) => sum + (value['size'] as int),
        );
        while (index.isNotEmpty &&
            (index.length >= maxEntries || total + bytes.length > maxBytes)) {
          final oldest = index.keys.first;
          total -= (index.remove(oldest) as Map)['size'] as int;
          await box.delete(oldest);
        }
        if (!allowed()) return;
        await box.put(cacheKey, bytes);
        index[cacheKey] = {
          'size': bytes.length,
          'savedAt': now,
          if (memoryTag != null && memoryTag.isNotEmpty) 'mid': memoryTag,
        };
        await box.put('_index', index);
        await box.flush();
      } catch (_) {
        // Ảnh đã tải vẫn hiển thị nếu thiết bị không ghi được cache.
      }
    });
  }

  Future<void> remove(String uid, String cacheKey) => _serial(() async {
    if (kIsWeb || uid != currentUid()) return;
    try {
      final box = await _box(uid);
      final index = Map<String, dynamic>.from(
        await box.get('_index') as Map? ?? {},
      );
      index.remove(cacheKey);
      await box.delete(cacheKey);
      await box.put('_index', index);
    } catch (_) {}
  });

  /// Xóa mọi kích thước đã lưu của các ảnh vừa biến mất khỏi Nhật ký.
  Future<int> removeMemories(
    String uid,
    String houseId,
    Iterable<String> memoryIds,
  ) {
    final tags = {for (final id in memoryIds) memoryTag(uid, houseId, id)};
    return _serial(() async {
      if (kIsWeb || tags.isEmpty || uid != currentUid()) return 0;
      try {
        final box = await _box(uid);
        final index = Map<String, dynamic>.from(
          await box.get('_index') as Map? ?? {},
        );
        var removed = 0;
        for (final entry in index.entries.toList()) {
          final metadata = entry.value;
          if (metadata is Map && tags.contains(metadata['mid'])) {
            await box.delete(entry.key);
            index.remove(entry.key);
            removed++;
          }
        }
        if (removed > 0) await box.put('_index', index);
        return removed;
      } catch (_) {
        return 0;
      }
    });
  }

  /// Tổng dung lượng ảnh đang lưu của tài khoản hiện tại (byte), để hiển thị trong Cài đặt.
  Future<int> totalBytes(String uid) => _serial(() async {
    if (kIsWeb || uid != currentUid()) return 0;
    try {
      final box = await _box(uid);
      final index = await box.get('_index');
      if (index is! Map) return 0;
      var total = 0;
      for (final value in index.values) {
        if (value is Map && value['size'] is int) total += value['size'] as int;
      }
      return total;
    } catch (_) {
      return 0;
    }
  });

  Future<void> clear() {
    _generation++;
    return _serial(() async {
      if (kIsWeb) return;
      try {
        await (await openBox()).clear();
      } catch (_) {}
    });
  }
}
