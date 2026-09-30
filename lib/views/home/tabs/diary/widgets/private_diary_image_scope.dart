import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../../utils/services/private_media_url_service.dart';

typedef PrivateDiaryImageCacheKey = ({
  String uid,
  String houseId,
  String memoryId,
  int? width,
});

class PrivateDiaryDiskCache {
  PrivateDiaryDiskCache._();

  static const ttl = Duration(days: 7);
  static final manager = CacheManager(
    Config(
      'soullocket_private_diary_v1',
      stalePeriod: ttl,
      maxNrOfCacheObjects: 200,
    ),
  );

  static String key({
    required String uid,
    required String houseId,
    required String memoryId,
    required int? width,
  }) {
    final source = '$uid\u0000$houseId\u0000$memoryId\u0000${width ?? 0}';
    return 'private-diary-${sha256.convert(utf8.encode(source))}';
  }

  static Future<bool> hasFresh(String cacheKey) async {
    if (kIsWeb) return false;
    try {
      final info = await manager.getFileFromCache(cacheKey);
      return info != null && info.validTill.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    try {
      await manager.emptyCache();
    } catch (_) {
      // Cache dọn thất bại không được làm hỏng luồng album.
    }
  }
}

class PrivateDiaryImageCacheEntry {
  PrivateDiaryImageCacheEntry(this.provider, this.validUntil)
    : _initialLifetime = (validUntil - DateTime.now().millisecondsSinceEpoch)
          .clamp(0, 115000);

  final ImageProvider<Object> provider;
  final int validUntil;
  final int _initialLifetime;
  final _age = Stopwatch()..start();
  Timer? _expiry;

  Duration get remaining => Duration(
    milliseconds: (validUntil - DateTime.now().millisecondsSinceEpoch).clamp(
      0,
      (_initialLifetime - _age.elapsedMilliseconds).clamp(0, 115000),
    ),
  );
}

class PrivateDiaryImageCache {
  PrivateDiaryImageCache({this.maximumEntries = 90})
    : assert(maximumEntries > 0);

  final int maximumEntries;
  final urlService = PrivateMediaUrlService(
    batchRequests: true,
    cacheCompletedUrls: true,
  );
  final _entries = <PrivateDiaryImageCacheKey, PrivateDiaryImageCacheEntry>{};
  StreamSubscription<String?>? _auth;
  String? _uid;
  bool _disposed = false;

  void bindSession(String uid, Stream<String?> authChanges) {
    if (_disposed || (_uid == uid && _auth != null)) return;
    clear();
    unawaited(_auth?.cancel());
    _uid = uid;
    _auth = authChanges.listen((nextUid) {
      if (nextUid != _uid) clear();
    }, onError: (Object _) => clear());
  }

  PrivateDiaryImageCacheEntry? get(PrivateDiaryImageCacheKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (_disposed || entry.remaining == Duration.zero) {
      _evict(entry);
      return null;
    }
    _entries[key] = entry;
    return entry;
  }

  void put(PrivateDiaryImageCacheKey key, PrivateDiaryImageCacheEntry entry) {
    if (_disposed || key.uid != _uid) return;
    final previous = _entries.remove(key);
    if (previous != null) _evict(previous);
    _entries[key] = entry;
    entry._expiry = Timer(entry.remaining, () => remove(entry));
    while (_entries.length > maximumEntries) {
      _evict(_entries.remove(_entries.keys.first)!);
    }
  }

  bool contains(PrivateDiaryImageCacheEntry entry) =>
      _entries.containsValue(entry);

  void remove(PrivateDiaryImageCacheEntry entry) {
    _entries.removeWhere((key, value) => identical(entry, value));
    _evict(entry);
  }

  void _evict(PrivateDiaryImageCacheEntry entry) {
    entry._expiry?.cancel();
    unawaited(entry.provider.evict());
  }

  void clear() {
    urlService.clear();
    for (final entry in _entries.values) {
      _evict(entry);
    }
    _entries.clear();
  }

  void clearMemory() {
    for (final entry in _entries.values) {
      _evict(entry);
    }
    _entries.clear();
  }

  void dispose() {
    _disposed = true;
    clear();
    urlService.dispose();
    unawaited(_auth?.cancel());
  }
}

class PrivateDiaryImageScope extends StatefulWidget {
  const PrivateDiaryImageScope({
    super.key,
    required this.houseId,
    required this.child,
  });

  final String houseId;
  final Widget child;

  static PrivateDiaryImageCache? maybeOf(BuildContext context, String houseId) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_PrivateDiaryImageScopeData>();
    return scope?.houseId == houseId ? scope?.cache : null;
  }

  @override
  State<PrivateDiaryImageScope> createState() => _PrivateDiaryImageScopeState();
}

class _PrivateDiaryImageScopeState extends State<PrivateDiaryImageScope>
    with WidgetsBindingObserver {
  final _cache = PrivateDiaryImageCache();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant PrivateDiaryImageScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) _cache.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      _cache.clearMemory();
    }
  }

  @override
  void dispose() {
    _cache.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PrivateDiaryImageScopeData(
    houseId: widget.houseId,
    cache: _cache,
    child: widget.child,
  );
}

class _PrivateDiaryImageScopeData extends InheritedWidget {
  const _PrivateDiaryImageScopeData({
    required this.houseId,
    required this.cache,
    required super.child,
  });

  final String houseId;
  final PrivateDiaryImageCache cache;

  @override
  bool updateShouldNotify(_PrivateDiaryImageScopeData oldWidget) =>
      oldWidget.houseId != houseId || oldWidget.cache != cache;
}
