import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/cloud_functions_helper.dart';

class PrivateMediaUrlResult {
  const PrivateMediaUrlResult({required this.url, required this.expiresAt});
  final String url;
  final int expiresAt;
}

class _PrivateMediaBatch {
  _PrivateMediaBatch(this.houseId, this.kind);

  final String houseId;
  final String kind;
  final requests = <String, Completer<Map<String, dynamic>>>{};
}

class _PrivateMediaUrlCacheEntry {
  _PrivateMediaUrlCacheEntry(this.result, this.createdAt, this.validUntil);

  final PrivateMediaUrlResult result;
  final int createdAt;
  final int validUntil;
  final age = Stopwatch()..start();
  Timer? expiryTimer;
}

class PrivateMediaUrlService {
  PrivateMediaUrlService({
    String? Function()? currentUid,
    Stream<String?> Function()? authChanges,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? invoke,
    DateTime Function()? now,
    this.batchRequests = false,
    this.cacheCompletedUrls = false,
    this.maximumCacheEntries = 90,
  }) : assert(maximumCacheEntries > 0),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _authChanges =
           authChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map(
             (user) => user?.uid,
           )),
       _invoke = invoke ?? _invokeCallable,
       _now = now ?? DateTime.now;

  static const Duration _cacheSafetyWindow = Duration(seconds: 5);
  static const Duration _maximumCacheLifetime = Duration(seconds: 90);

  final String? Function() _currentUid;
  final Stream<String?> Function() _authChanges;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) _invoke;
  final DateTime Function() _now;
  final bool batchRequests;
  final bool cacheCompletedUrls;
  final int maximumCacheEntries;
  final _pending = <String, Future<PrivateMediaUrlResult>>{};
  final _batches = <String, _PrivateMediaBatch>{};
  final _cache = <String, _PrivateMediaUrlCacheEntry>{};
  Timer? _batchTimer;
  StreamSubscription<String?>? _authSubscription;
  String? _uid;
  int _generation = 0;
  bool _disposed = false;

  void clear() {
    _generation++;
    _pending.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
    for (final batch in _batches.values) {
      for (final request in batch.requests.values) {
        request.completeError(
          FirebaseFunctionsException(code: 'cancelled', message: ''),
        );
      }
    }
    _batches.clear();
    for (final entry in _cache.values) {
      entry.expiryTimer?.cancel();
    }
    _cache.clear();
    final subscription = _authSubscription;
    _authSubscription = null;
    unawaited(subscription?.cancel());
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  static Future<Map<String, dynamic>> _invokeCallable(
    Map<String, dynamic> payload,
  ) async {
    // Chuẩn bị App Check trước khi xin link; làm mới và thử lại một lần
    // nếu máy chủ từ chối token, như các callable bảo vệ khác trong app.
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'resolveHouseMediaUrlSecure',
      payload: payload,
      timeout: const Duration(seconds: 20),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return result.data;
  }

  Future<PrivateMediaUrlResult> resolve({
    required String houseId,
    required String mediaId,
    required String kind,
    bool forceRefresh = false,
  }) async {
    final uid = _currentUid();
    if (_disposed || uid == null || uid.isEmpty) {
      clear();
      throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
    }
    final normalizedHouseId = houseId.trim();
    final normalizedMediaId = mediaId.trim();
    final normalizedKind = kind.trim();
    bool validId(String value) =>
        value.isNotEmpty &&
        value.length <= 128 &&
        !RegExp(r'[.#$\[\]/\\\s\x00-\x1f\x7f]').hasMatch(value);
    if (!validId(normalizedHouseId) ||
        !validId(normalizedMediaId) ||
        !const {
          'memory_image',
          'album_image',
          'voice',
        }.contains(normalizedKind)) {
      throw FirebaseFunctionsException(code: 'invalid-argument', message: '');
    }
    if (_uid != uid) {
      clear();
      _uid = uid;
    }
    final cacheKey =
        '$uid/$normalizedHouseId/$normalizedMediaId/$normalizedKind';
    if (forceRefresh) {
      final previous = _cache[cacheKey];
      if (previous != null) _removeCached(cacheKey, previous);
    }
    final cached = _getCached(cacheKey);
    if (cached != null) return cached;
    final generation = _generation;
    _ensureAuthSubscription();
    final pending =
        _pending[cacheKey] ??
        _resolveUncached(
          uid: uid,
          houseId: normalizedHouseId,
          mediaId: normalizedMediaId,
          kind: normalizedKind,
        );
    _pending[cacheKey] = pending;
    try {
      final result = await pending;
      if (_disposed || uid != _currentUid() || generation != _generation) {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
      }
      if (identical(_pending[cacheKey], pending)) {
        _cacheResult(cacheKey, result);
      }
      return result;
    } finally {
      if (identical(_pending[cacheKey], pending)) {
        _pending.remove(cacheKey);
      }
      _stopAuthSubscriptionIfIdle();
    }
  }

  void _ensureAuthSubscription() {
    if (_disposed || _authSubscription != null) return;
    _authSubscription = _authChanges().listen(
      (nextUid) {
        if (_disposed || nextUid == _uid) return;
        _uid = nextUid;
        clear();
      },
      onError: (Object _) => clear(),
      onDone: clear,
    );
  }

  PrivateMediaUrlResult? _getCached(String cacheKey) {
    final entry = _cache[cacheKey];
    if (entry == null) return null;
    final nowMs = _now().millisecondsSinceEpoch;
    if (nowMs < entry.createdAt ||
        entry.validUntil <= nowMs ||
        entry.age.elapsedMilliseconds >= entry.validUntil - entry.createdAt) {
      _removeCached(cacheKey, entry);
      return null;
    }
    _cache.remove(cacheKey);
    _cache[cacheKey] = entry;
    return entry.result;
  }

  void _cacheResult(String cacheKey, PrivateMediaUrlResult result) {
    if (!cacheCompletedUrls) return;
    final nowMs = _now().millisecondsSinceEpoch;
    final safeExpiry = result.expiresAt - _cacheSafetyWindow.inMilliseconds;
    final maximumExpiry = nowMs + _maximumCacheLifetime.inMilliseconds;
    final validUntil = safeExpiry < maximumExpiry ? safeExpiry : maximumExpiry;
    if (validUntil <= nowMs) return;

    final previous = _cache.remove(cacheKey);
    previous?.expiryTimer?.cancel();
    final entry = _PrivateMediaUrlCacheEntry(result, nowMs, validUntil);
    _cache[cacheKey] = entry;
    entry.expiryTimer = Timer(
      Duration(milliseconds: validUntil - nowMs),
      () => _removeCached(cacheKey, entry),
    );
    while (_cache.length > maximumCacheEntries) {
      final oldestKey = _cache.keys.first;
      _removeCached(oldestKey, _cache[oldestKey]!);
    }
  }

  void _removeCached(String cacheKey, _PrivateMediaUrlCacheEntry entry) {
    if (!identical(_cache[cacheKey], entry)) return;
    _cache.remove(cacheKey);
    entry.expiryTimer?.cancel();
    _stopAuthSubscriptionIfIdle();
  }

  void _stopAuthSubscriptionIfIdle() {
    if (_cache.isNotEmpty || _pending.isNotEmpty || _batches.isNotEmpty) return;
    final subscription = _authSubscription;
    _authSubscription = null;
    unawaited(subscription?.cancel());
  }

  Future<Map<String, dynamic>> _enqueueBatch({
    required String uid,
    required String houseId,
    required String mediaId,
    required String kind,
  }) {
    final key = '$uid/$houseId/$kind';
    final batch = _batches.putIfAbsent(
      key,
      () => _PrivateMediaBatch(houseId, kind),
    );
    final response = Completer<Map<String, dynamic>>();
    batch.requests[mediaId] = response;
    if (batch.requests.length == 12) {
      _batches.remove(key);
      unawaited(_sendBatch(batch));
    }
    _batchTimer ??= Timer(const Duration(milliseconds: 20), () {
      _batchTimer = null;
      final batches = _batches.values.toList();
      _batches.clear();
      for (final batch in batches) {
        unawaited(_sendBatch(batch));
      }
    });
    return response.future;
  }

  Future<void> _sendBatch(_PrivateMediaBatch batch) async {
    try {
      final data = await _invoke({
        'houseId': batch.houseId,
        'mediaIds': batch.requests.keys.toList(),
        'kind': batch.kind,
      });
      final items = data['items'];
      final replies = <String, Map<String, dynamic>>{};
      if (data['ok'] != true || data['kind'] != batch.kind || items is! List) {
        throw FirebaseFunctionsException(code: 'unavailable', message: '');
      }
      for (final item in items) {
        if (item is! Map ||
            item['mediaId'] is! String ||
            !batch.requests.containsKey(item['mediaId']) ||
            replies.containsKey(item['mediaId'])) {
          throw FirebaseFunctionsException(code: 'unavailable', message: '');
        }
        replies[item['mediaId'] as String] = Map<String, dynamic>.from(item);
      }
      if (replies.length != batch.requests.length) {
        throw FirebaseFunctionsException(code: 'unavailable', message: '');
      }
      for (final request in batch.requests.entries) {
        final reply = replies[request.key]!;
        if (reply['ok'] == true) {
          request.value.complete(reply);
        } else {
          final code = reply['code'];
          request.value.completeError(
            FirebaseFunctionsException(
              code:
                  const {
                    'permission-denied',
                    'not-found',
                    'failed-precondition',
                    'resource-exhausted',
                    'unavailable',
                  }.contains(code)
                  ? code as String
                  : 'unavailable',
              message: '',
            ),
          );
        }
      }
    } catch (error) {
      for (final request in batch.requests.values) {
        if (!request.isCompleted) request.completeError(error);
      }
    }
  }

  Future<PrivateMediaUrlResult> _resolveUncached({
    required String uid,
    required String houseId,
    required String mediaId,
    required String kind,
  }) async {
    final generation = _generation;
    try {
      final data = await (batchRequests
          ? _enqueueBatch(
              uid: uid,
              houseId: houseId,
              mediaId: mediaId,
              kind: kind,
            )
          : _invoke({'houseId': houseId, 'mediaId': mediaId, 'kind': kind}));
      if (uid != _currentUid() || generation != _generation) {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
      }
      final url = data['url']?.toString().trim() ?? '';
      final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      final uri = Uri.tryParse(url);
      if (data['ok'] != true ||
          data['kind'] != kind ||
          data['mediaId'] != mediaId ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          expiresAt <= _now().millisecondsSinceEpoch) {
        throw FirebaseFunctionsException(code: 'unavailable', message: '');
      }
      return PrivateMediaUrlResult(url: url, expiresAt: expiresAt);
    } on FirebaseFunctionsException catch (error) {
      // Không chuyển message/details có thể chứa bearer URL ra UI hoặc log.
      throw FirebaseFunctionsException(code: error.code, message: '');
    } catch (_) {
      throw FirebaseFunctionsException(code: 'unavailable', message: '');
    }
  }
}
