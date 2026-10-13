import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../../utils/services/core/rtdb_settled_read.dart';
import '../../../../utils/services/offline_cache_service.dart';
import '../../../home/tabs/diary/utils/diary_memory_media.dart';
import '../../../home/tabs/diary/utils/private_memory_link_policy.dart';

/// Metadata của ảnh ghép dùng cùng kho Kỷ niệm, không chứa URL cấp quyền tạm thời.
abstract final class CollageMemoryPhotos {
  static String firstText(Map<String, dynamic> item, Iterable<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String key(Map<String, dynamic> item) =>
      firstText(item, const ['id', 'url', 'imageUrl', 'downloadUrl']);

  static bool isPrivate(Map<String, dynamic> item) =>
      PrivateMemoryLinkPolicy.isPrivate(item);

  static String source(Map<String, dynamic> item) => isPrivate(item)
      ? 'memory-private:${key(item)}'
      : firstText(item, const ['url', 'imageUrl', 'downloadUrl', 'mediaUrl']);

  static String thumbnail(Map<String, dynamic> item) => isPrivate(item)
      ? firstText(item, const ['url', 'resolvedUrl'])
      : firstText(item, const [
          'thumbUrl',
          'thumbnailUrl',
          'thumbnail',
          'previewUrl',
          'url',
          'imageUrl',
          'downloadUrl',
          'mediaUrl',
        ]);

  static int timestamp(Object? raw) {
    if (raw is DateTime) return raw.millisecondsSinceEpoch;
    final number = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (number != null) {
      if (number <= 0) return 0;
      return number < 100000000000 ? number * 1000 : number;
    }
    return DateTime.tryParse('$raw')?.millisecondsSinceEpoch ?? 0;
  }

  static Map<String, dynamic>? normalize(Map<String, dynamic> item) {
    if (isDiaryMemoryVideo(Map<Object?, Object?>.from(item)) ||
        item['deleted'] == true ||
        item['trashed'] == true ||
        item['status'] == 'trashed' ||
        item['status'] == 'deleted') {
      return null;
    }
    final private = isPrivate(item);
    final result = private
        ? PrivateMemoryLinkPolicy.offlineMetadata(item)
        : Map<String, dynamic>.from(item);
    // Bỏ cả các alias không nằm trong policy cũ khi đọc cache phiên trước.
    if (private) {
      for (final key in const [
        'collageUrl',
        'thumbnail',
        'imageUrl',
        'mediaUrl',
        'signedUrl',
      ]) {
        result.remove(key);
      }
    } else {
      final original = firstText(result, const [
        'url',
        'imageUrl',
        'downloadUrl',
        'mediaUrl',
        'resolvedUrl',
      ]);
      if (original.isEmpty || isDiaryMemoryVideoUrl(original)) return null;
      result['url'] = original;
    }
    if (key(result).isEmpty) return null;
    result['ts'] = timestamp(
      item['ts'] ?? item['timestamp'] ?? item['createdAt'] ?? item['date'],
    );
    return result;
  }

  static List<Map<String, dynamic>> catalog(
    Iterable<Map<String, dynamic>> items,
  ) {
    final deduped = <String, Map<String, dynamic>>{};
    for (final raw in items) {
      final item = raw['_resolvedPrivateUrl'] == true
          ? Map<String, dynamic>.from(raw)
          : normalize(raw);
      if (item == null) continue;
      item['ts'] = timestamp(
        item['ts'] ?? item['timestamp'] ?? item['createdAt'] ?? item['date'],
      );
      final id = key(item);
      if (!deduped.containsKey(id) ||
          (item['ts'] as int) >= (deduped[id]!['ts'] as int)) {
        deduped[id] = item;
      }
    }
    return deduped.values.toList()..sort((a, b) {
      final byDate = (b['ts'] as int).compareTo(a['ts'] as int);
      return byDate != 0 ? byDate : key(a).compareTo(key(b));
    });
  }

  static List<Map<String, dynamic>>? cachedItems(dynamic raw, DateTime now) {
    dynamic items = raw;
    if (raw is Map) {
      final saved = (raw['_cachedAt'] as num?)?.toInt() ?? 0;
      final age = now.millisecondsSinceEpoch - saved;
      if (saved == 0 ||
          age < 0 ||
          age >= const Duration(days: 60).inMilliseconds) {
        return null;
      }
      items = raw['items'];
    }
    if (items is! List) return null;
    return catalog([
      for (final item in items)
        if (item is Map) Map<String, dynamic>.from(item),
    ]);
  }
}

/// Một owner đọc metadata; mọi kết quả trễ đều bị ràng buộc UID/Nhà/lượt đọc.
class CollageMemoryLibrary extends ChangeNotifier {
  CollageMemoryLibrary({
    required String houseId,
    String? Function()? currentUid,
    String? Function()? currentHouseId,
    Stream<String?> Function()? authChanges,
    Future<dynamic> Function(String)? readCache,
    dynamic Function(String)? readCacheSync,
    Future<void> Function(String, dynamic)? writeCache,
    Future<List<Map<String, dynamic>>> Function(String)? readRemote,
    DateTime Function()? now,
    this.allowDiaryCache = true,
  }) : _houseId = houseId.trim(),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _currentHouseId =
           currentHouseId ??
           (() => OfflineCacheService.getPrefsSync()?.getString('il_house_id')),
       _authChanges =
           authChanges ??
           (() =>
               FirebaseAuth.instance.idTokenChanges().map((user) => user?.uid)),
       _readCache = readCache ?? OfflineCacheService.loadCache,
       _readCacheSync = readCacheSync ?? OfflineCacheService.loadCacheSync,
       _writeCache = writeCache ?? OfflineCacheService.saveCache,
       _readRemote = readRemote ?? _readRtdb,
       _now = now ?? DateTime.now;

  final String? Function() _currentUid;
  final String? Function() _currentHouseId;
  final Stream<String?> Function() _authChanges;
  final Future<dynamic> Function(String) _readCache;
  final dynamic Function(String) _readCacheSync;
  final Future<void> Function(String, dynamic) _writeCache;
  final Future<List<Map<String, dynamic>>> Function(String) _readRemote;
  final DateTime Function() _now;
  final bool allowDiaryCache;
  String _houseId;
  String? _ownerUid;
  int _generation = 0;
  bool _disposed = false;
  bool loading = false;
  bool hasError = false;
  bool settled = false;
  List<Map<String, dynamic>> photos = const [];
  StreamSubscription<String?>? _auth;

  static String cacheKey(String uid, String houseId) =>
      'collage_memories_v2_${base64Url.encode(utf8.encode(jsonEncode([uid, houseId])))}';

  static Future<List<Map<String, dynamic>>> _readRtdb(String houseId) async {
    final snapshot = await readQuerySettled(
      FirebaseDatabase.instance
          .ref('houses/$houseId/memories')
          .orderByChild('ts')
          .limitToLast(200),
    );
    return [
      for (final child in snapshot.children)
        if (child.value is Map)
          {
            ...Map<String, dynamic>.from(child.value as Map),
            'id': child.key,
            'houseId': houseId,
          },
    ];
  }

  void start() {
    if (_disposed || _auth != null) return;
    _ownerUid = _currentUid();
    _auth = _authChanges().distinct().listen((uid) {
      if (uid == _ownerUid) return;
      _ownerUid = uid;
      _clear();
      // Không đọc Nhà cũ bằng tài khoản vừa đăng nhập. Khi Auth khôi phục xong,
      // bắt đầu lại bằng UID mới và vẫn giữ guard Nhà/lượt đọc.
      if (uid != null && uid.isNotEmpty && _houseId.isNotEmpty) {
        unawaited(load());
      }
    }, onError: (Object _) => _clear());
    final uid = _ownerUid;
    if (uid != null && uid.isNotEmpty && _houseId.isNotEmpty) {
      final cached = _cached(uid, _readCacheSync);
      if (cached != null) photos = cached;
    }
    unawaited(load());
  }

  List<Map<String, dynamic>>? _cached(
    String uid,
    dynamic Function(String) read,
  ) {
    final own = CollageMemoryPhotos.cachedItems(
      read(cacheKey(uid, _houseId)),
      _now(),
    );
    if (own != null) return own;
    // Cache Nhật ký chỉ được dùng sau khi ngữ cảnh tài khoản/Nhà local khớp.
    final prefs = OfflineCacheService.getPrefsSync();
    if (allowDiaryCache &&
        prefs?.getString('il_auth_uid') == uid &&
        prefs?.getString('il_house_id') == _houseId) {
      return CollageMemoryPhotos.cachedItems(
        read('memories_$_houseId'),
        _now(),
      );
    }
    return null;
  }

  bool _current(String uid, String houseId, int generation) =>
      !_disposed &&
      generation == _generation &&
      uid == _currentUid() &&
      uid == _ownerUid &&
      houseId == _houseId &&
      (_currentHouseId() == null || _currentHouseId() == houseId);

  Future<void> load() async {
    final uid = _currentUid();
    final houseId = _houseId;
    if (_disposed ||
        loading ||
        uid == null ||
        uid.isEmpty ||
        houseId.isEmpty ||
        (_ownerUid != null && uid != _ownerUid)) {
      return;
    }
    _ownerUid = uid;
    final generation = ++_generation;
    bool current() => _current(uid, houseId, generation);
    if (!current()) {
      _clear();
      return;
    }
    loading = true;
    hasError = false;
    notifyListeners();
    try {
      if (!settled) {
        final raw = await _readCache(cacheKey(uid, houseId));
        if (!current()) return;
        final cached = CollageMemoryPhotos.cachedItems(raw, _now());
        if (cached != null) {
          photos = cached;
          notifyListeners();
        }
      }
      final remote = await _readRemote(
        houseId,
      ).timeout(const Duration(seconds: 14));
      if (!current()) return;
      photos = CollageMemoryPhotos.catalog(remote);
      settled = true;
      notifyListeners();
      // Cache riêng; không ghi đè cache dùng chung của Nhật ký. Catalog đã bỏ URL ký.
      await _writeCache(cacheKey(uid, houseId), {
        '_cachedAt': _now().millisecondsSinceEpoch,
        'items': photos,
      });
    } catch (error) {
      if (!current()) return;
      final code = error is FirebaseException ? error.code : '';
      if (code == 'permission-denied' || code == 'unauthenticated') {
        photos = const [];
        settled = true;
      }
      hasError = true;
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      } else if (!_disposed && generation == _generation) {
        _clear();
      }
    }
  }

  void changeHouse(String houseId) {
    if (_houseId == houseId.trim()) return;
    _houseId = houseId.trim();
    _ownerUid = _currentUid();
    _clear();
    unawaited(load());
  }

  void _clear() {
    if (_disposed) return;
    _generation++;
    photos = const [];
    loading = false;
    hasError = false;
    settled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_auth?.cancel());
    super.dispose();
  }
}
