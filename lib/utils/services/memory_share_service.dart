import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'l10n_service.dart';
import 'core/cloud_functions_helper.dart';

import '../../core/constants/app_config.dart';
import 'admob_service.dart';

class MemoryLimits {
  const MemoryLimits({
    required this.shareMaxItems,
    required this.shareFreeMaxItems,
    required this.shareProMaxItems,
    required this.shareDefaultTtlDays,
    required this.shareMaxTtlDays,
    required this.imageFreeDailyLimit,
    required this.imageProDailyLimit,
  });

  factory MemoryLimits.fromMap(Map<dynamic, dynamic> data) {
    final shareMaxTtlDays = _readLimitInt(
      data['shareMaxTtlDays'],
      fallbackMemoryLimits.shareMaxTtlDays,
    ).clamp(1, 365).toInt();

    final shareFreeMaxItems = _readLimitInt(
      data['shareFreeMaxItems'],
      fallbackMemoryLimits.shareFreeMaxItems,
    ).clamp(1, 500).toInt();

    final shareProMaxItems = _readLimitInt(
      data['shareProMaxItems'],
      fallbackMemoryLimits.shareProMaxItems,
    ).clamp(1, 1000).toInt();

    return MemoryLimits(
      shareMaxItems: _readLimitInt(
        data['shareMaxItems'],
        fallbackMemoryLimits.shareMaxItems,
      ).clamp(1, 1000).toInt(),
      shareFreeMaxItems: shareFreeMaxItems,
      shareProMaxItems: shareProMaxItems,
      shareDefaultTtlDays: _readLimitInt(
        data['shareDefaultTtlDays'],
        fallbackMemoryLimits.shareDefaultTtlDays,
      ).clamp(1, shareMaxTtlDays).toInt(),
      shareMaxTtlDays: shareMaxTtlDays,
      imageFreeDailyLimit: _readLimitInt(
        data['imageFreeDailyLimit'],
        fallbackMemoryLimits.imageFreeDailyLimit,
      ).clamp(0, 1000).toInt(),
      imageProDailyLimit: _readLimitInt(
        data['imageProDailyLimit'],
        fallbackMemoryLimits.imageProDailyLimit,
      ).clamp(0, 1000).toInt(),
    );
  }

  final int shareMaxItems;
  final int shareFreeMaxItems;
  final int shareProMaxItems;
  final int shareDefaultTtlDays;
  final int shareMaxTtlDays;
  final int imageFreeDailyLimit;
  final int imageProDailyLimit;

  int maxShareItems(bool isPro) => math.min(
    100,
    math.min(shareMaxItems, isPro ? shareProMaxItems : shareFreeMaxItems),
  );
}

const MemoryLimits fallbackMemoryLimits = MemoryLimits(
  shareMaxItems: 24,
  shareFreeMaxItems: 50,
  shareProMaxItems: 200,
  shareDefaultTtlDays: 7,
  shareMaxTtlDays: 183,
  imageFreeDailyLimit: 10,
  imageProDailyLimit: 30,
);

int _readLimitInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class MemoryShareResult {
  const MemoryShareResult({
    required this.token,
    required this.url,
    required this.expiresAt,
    required this.photoCount,
  });

  final String token;
  final String url;
  final int expiresAt;
  final int photoCount;
}

class MemoryShareService {
  MemoryShareService({
    FirebaseAuth? auth,
    String? Function()? currentUid,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? invoke,
    Future<bool> Function()? isPro,
  }) : _currentUid =
           currentUid ??
           (() => (auth ?? FirebaseAuth.instance).currentUser?.uid),
       _invoke = invoke ?? _invokeCallable,
       _isPro = isPro ?? (() => AdMobService().isProUser());

  static int get maxPhotosPerShare => fallbackMemoryLimits.shareMaxItems;
  static String get defaultShareTitle =>
      L10nService().translate('memory_share_default_title');
  static String get defaultShareDescription =>
      L10nService().translate('memory_share_default_description');
  static const String defaultBrandLabel = 'SoulLocket Memories';
  static const String defaultTheme = 'soullocket_dream';

  final String? Function() _currentUid;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  _invoke;
  final Future<bool> Function() _isPro;
  MemoryLimits? _cachedLimits;
  DateTime? _lastFetchTime;
  String? _cachedUid;
  String? _retryFingerprint;
  String? _retryRequestId;
  bool _creating = false;

  static Future<Map<String, dynamic>> _invokeCallable(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      name,
      payload: payload,
      timeout: const Duration(seconds: 65),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return result.data;
  }

  String _uid() {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
    }
    return uid;
  }

  void _checkSession(String uid) {
    if (_currentUid() != uid) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
    }
  }

  Future<MemoryLimits> fetchLimits() async {
    final uid = _uid();
    if (_cachedUid == uid &&
        _cachedLimits != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < const Duration(hours: 1)) {
      return _cachedLimits!;
    }
    try {
      final raw = await _invoke('getMemoryLimits', {});
      _checkSession(uid);
      final limits = MemoryLimits.fromMap(raw);
      _cachedUid = uid;
      _cachedLimits = limits;
      _lastFetchTime = DateTime.now();
      return limits;
    } catch (_) {
      _checkSession(uid);
      return fallbackMemoryLimits;
    }
  }

  Future<MemoryShareResult> createShareLink({
    required String houseId,
    required List<Map<String, dynamic>> photos,
    int expiryDays = 7,
    String? password,
  }) async {
    if (_creating) {
      throw FirebaseFunctionsException(code: 'aborted', message: '');
    }
    _creating = true;
    try {
      final uid = _uid();
      final normalizedHouseId = houseId.trim();
      final ids = photos
          .map((photo) => photo['id']?.toString().trim() ?? '')
          .toList();
      bool validId(String value) =>
          RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);
      final passwordText = password?.trim() ?? '';
      if (!validId(normalizedHouseId) ||
          ids.isEmpty ||
          ids.any((id) => !validId(id)) ||
          ids.toSet().length != ids.length ||
          passwordText.length > 32 ||
          photos.any(
            (photo) =>
                photo['mediaType'] == 'video' ||
                (photo['contentType']?.toString() ?? '').startsWith('video/'),
          )) {
        throw FirebaseFunctionsException(code: 'invalid-argument', message: '');
      }
      final limits = await fetchLimits();
      final pro = await _isPro();
      _checkSession(uid);
      final maxItems = limits.maxShareItems(pro);
      if (ids.length > maxItems ||
          expiryDays < 1 ||
          expiryDays > limits.shareMaxTtlDays) {
        throw FirebaseFunctionsException(code: 'invalid-argument', message: '');
      }
      final payload = <String, dynamic>{
        'houseId': normalizedHouseId,
        'memoryIds': ids,
        'expiryDays': expiryDays,
        'title': defaultShareTitle,
        'description': defaultShareDescription,
        'locale': L10nService().localeCode,
        if (passwordText.isNotEmpty) 'password': passwordText,
      };
      final fingerprint = sha256
          .convert(utf8.encode(jsonEncode([uid, payload])))
          .toString();
      if (_retryFingerprint != fingerprint) {
        _retryFingerprint = fingerprint;
        final random = math.Random.secure();
        _retryRequestId = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      }
      payload['requestId'] = _retryRequestId;
      final data = await _invoke('createMemoryShareLink', payload);
      _checkSession(uid);
      final token = data['token']?.toString() ?? '';
      final expiresAt = _readLimitInt(data['expiresAt'], 0);
      final photoCount = _readLimitInt(data['photoCount'], 0);
      if (!RegExp(r'^[A-Za-z0-9_-]{24,64}$').hasMatch(token) ||
          expiresAt <= DateTime.now().millisecondsSinceEpoch ||
          photoCount != ids.length) {
        throw FirebaseFunctionsException(code: 'data-loss', message: '');
      }
      _retryFingerprint = null;
      _retryRequestId = null;
      return MemoryShareResult(
        token: token,
        url: AppConfig.webUri(
          'memory-share',
          queryParameters: {'token': token},
        ).toString(),
        expiresAt: expiresAt,
        photoCount: photoCount,
      );
    } finally {
      _creating = false;
    }
  }

  Future<void> revokeShareLink(String token) async {
    final uid = _uid();
    final normalized = token.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{24,64}$').hasMatch(normalized)) {
      throw FirebaseFunctionsException(code: 'invalid-argument', message: '');
    }
    await _invoke('revokeMemoryShareLink', {'token': normalized});
    _checkSession(uid);
  }
}
