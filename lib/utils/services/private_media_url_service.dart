import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/callable_app_check_guard.dart';
import 'core/cloud_functions_helper.dart';

class PrivateMediaUrlResult {
  const PrivateMediaUrlResult({
    required this.url,
    required this.expiresAt,
    this.variant = 'original',
  });
  final String url;
  final int expiresAt;
  // Backend có thể trả original khi ảnh cũ chưa hỗ trợ thumbnail.
  final String variant;
}

class _PrivateMediaBatch {
  _PrivateMediaBatch(this.houseId, this.kind, this.variant);

  final String houseId;
  final String kind;
  final String? variant;
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
  // Link xem riêng tư sống 50 phút từ 07/10/2026 (trước là 120 giây); giữ link tới 5 giây
  // trước hạn server, tối đa 45 phút, để ảnh/video đang hiện không xin link lại mỗi 90 giây.
  static const Duration _maximumCacheLifetime = Duration(minutes: 45);
  static const Duration _appCheckFailureCooldown = Duration(seconds: 30);
  static const Duration _batchWindow = Duration(milliseconds: 120);

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
  FirebaseFunctionsException? _appCheckFailure;
  int? _appCheckFailureAt;
  Stopwatch? _appCheckFailureAge;
  int _generation = 0;
  bool _disposed = false;

  void clear() {
    _generation++;
    _appCheckFailure = null;
    _appCheckFailureAt = null;
    _appCheckFailureAge = null;
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
    String? variant,
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
        }.contains(normalizedKind) ||
        (variant != null &&
            !const {'original', 'thumbnail'}.contains(variant)) ||
        (variant == 'thumbnail' && normalizedKind == 'voice')) {
      throw FirebaseFunctionsException(code: 'invalid-argument', message: '');
    }
    if (_uid != uid) {
      clear();
      _uid = uid;
    }
    final cacheKey =
        '$uid/$normalizedHouseId/$normalizedMediaId/$normalizedKind/${variant ?? 'original'}';
    if (forceRefresh) {
      final previous = _cache[cacheKey];
      if (previous != null) _removeCached(cacheKey, previous);
    }
    final cached = _getCached(cacheKey);
    if (cached != null) return cached;
    final blocked = _recentAppCheckFailure();
    if (blocked != null) throw blocked;
    final generation = _generation;
    _ensureAuthSubscription();
    final pending =
        _pending[cacheKey] ??
        _resolveUncached(
          uid: uid,
          houseId: normalizedHouseId,
          mediaId: normalizedMediaId,
          kind: normalizedKind,
          variant: variant,
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

  FirebaseFunctionsException? _recentAppCheckFailure() {
    final failure = _appCheckFailure;
    if (failure == null) return null;
    final elapsed = _now().millisecondsSinceEpoch - _appCheckFailureAt!;
    if (elapsed >= _appCheckFailureCooldown.inMilliseconds ||
        _appCheckFailureAge!.elapsed >= _appCheckFailureCooldown) {
      _appCheckFailure = null;
      _appCheckFailureAt = null;
      _appCheckFailureAge = null;
      return null;
    }
    return failure;
  }

  FirebaseFunctionsException _rejectAppCheck(
    Object? cause,
    String uid,
    int generation,
  ) {
    final throttled =
        cause is FirebaseException &&
        (const {
              'resource-exhausted',
              'too-many-requests',
            }.contains(cause.code) ||
            (cause.message ?? '').toLowerCase().contains('too many attempts'));
    final failure = FirebaseFunctionsException(
      code: throttled ? 'resource-exhausted' : 'failed-precondition',
      message: '',
    );
    if (!_disposed && uid == _currentUid() && generation == _generation) {
      _appCheckFailure = failure;
      _appCheckFailureAt = _now().millisecondsSinceEpoch;
      _appCheckFailureAge = Stopwatch()..start();
    }
    return failure;
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
    required String? variant,
  }) {
    final key = '$uid/$houseId/$kind/${variant ?? 'original'}';
    final batch = _batches.putIfAbsent(
      key,
      () => _PrivateMediaBatch(houseId, kind, variant),
    );
    final response = Completer<Map<String, dynamic>>();
    batch.requests[mediaId] = response;
    if (batch.requests.length == 12) {
      _batches.remove(key);
      unawaited(_sendBatch(batch));
    }
    // Lướt album thì ô mới hiện dần: chờ 20 ms chỉ gom ~2 ảnh/lượt (đo 13/10/2026,
    // 99 ảnh = 45 lượt, mỗi lượt máy chủ tốn ~24 thao tác cố định). Chờ 120 ms để
    // gom nhiều ảnh hơn; ô vừa hiện chỉ chậm thêm ~0,1 giây.
    _batchTimer ??= Timer(_batchWindow, () {
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
      final data = await _invokeWithVariant({
        'houseId': batch.houseId,
        'mediaIds': batch.requests.keys.toList(),
        'kind': batch.kind,
        if (batch.variant != null) 'variant': batch.variant,
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

  Future<Map<String, dynamic>> _invokeWithVariant(
    Map<String, dynamic> payload,
  ) async {
    final generation = _generation;
    final uid = _currentUid();
    try {
      return await _invoke(payload);
    } on FirebaseFunctionsException catch (error) {
      // Chỉ lùi giao thức khi server cũ chưa hiểu variant. Không thử lại khi
      // bị từ chối quyền, App Check, hết hạn mức hay lỗi mạng.
      if (!payload.containsKey('variant') ||
          !const {'invalid-argument', 'unimplemented'}.contains(error.code)) {
        rethrow;
      }
      if (_disposed || generation != _generation || uid != _currentUid()) {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
      }
      final legacy = Map<String, dynamic>.from(payload)..remove('variant');
      return _invoke(legacy);
    }
  }

  Future<PrivateMediaUrlResult> _resolveUncached({
    required String uid,
    required String houseId,
    required String mediaId,
    required String kind,
    required String? variant,
  }) async {
    final generation = _generation;
    try {
      final data = await (batchRequests
          ? _enqueueBatch(
              uid: uid,
              houseId: houseId,
              mediaId: mediaId,
              kind: kind,
              variant: variant,
            )
          : _invokeWithVariant({
              'houseId': houseId,
              'mediaId': mediaId,
              'kind': kind,
              'variant': ?variant,
            }));
      if (uid != _currentUid() || generation != _generation) {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
      }
      final url = data['url']?.toString().trim() ?? '';
      final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      final actualVariant = data['variant'] ?? 'original';
      final uri = Uri.tryParse(url);
      if (data['ok'] != true ||
          data['kind'] != kind ||
          data['mediaId'] != mediaId ||
          !const {'original', 'thumbnail'}.contains(actualVariant) ||
          (variant != 'thumbnail' && actualVariant != 'original') ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          expiresAt <= _now().millisecondsSinceEpoch) {
        throw FirebaseFunctionsException(code: 'unavailable', message: '');
      }
      return PrivateMediaUrlResult(
        url: url,
        expiresAt: expiresAt,
        variant: actualVariant as String,
      );
    } on FirebaseFunctionsException catch (error) {
      // Không chuyển message/details có thể chứa bearer URL ra UI hoặc log.
      throw FirebaseFunctionsException(code: error.code, message: '');
    } on CallableAppCheckException catch (error) {
      throw _rejectAppCheck(error.cause, uid, generation);
    } on CallableVerificationException catch (error) {
      throw FirebaseFunctionsException(code: error.cause.code, message: '');
    } on FirebaseAuthException catch (error) {
      throw FirebaseFunctionsException(
        code: error.code == 'network-request-failed'
            ? 'unavailable'
            : error.code == 'too-many-requests'
            ? 'resource-exhausted'
            : 'unauthenticated',
        message: '',
      );
    } on FirebaseException catch (error) {
      if (error.plugin == 'firebase_app_check' &&
          !const {
            'network-request-failed',
            'unavailable',
          }.contains(error.code)) {
        throw _rejectAppCheck(error, uid, generation);
      }
      throw FirebaseFunctionsException(code: 'unavailable', message: '');
    } on TimeoutException {
      throw FirebaseFunctionsException(code: 'deadline-exceeded', message: '');
    } catch (_) {
      throw FirebaseFunctionsException(code: 'unavailable', message: '');
    }
  }
}
