import 'dart:async';

import 'call_setup_failure.dart';

/// Chỉ giữ ICE credential trong RAM, tối đa 5 phút và riêng từng UID.
class CallIceConfigCache {
  CallIceConfigCache({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  String? _uid;
  int _epoch = 0;
  DateTime? _validUntil;
  DateTime? _retryAfter;
  List<Map<String, dynamic>>? _servers;
  Future<List<Map<String, dynamic>>>? _loading;

  void clear() {
    _epoch++;
    _uid = null;
    _validUntil = null;
    _retryAfter = null;
    _servers = null;
    _loading = null;
  }

  Future<List<Map<String, dynamic>>> load(
    String uid,
    Future<Object?> Function() fetch,
  ) async {
    if (_uid != uid) {
      clear();
      _uid = uid;
    }
    final now = _now();
    if (_servers != null && now.isBefore(_validUntil!)) {
      return _copy(_servers!);
    }
    final pending = _loading;
    if (pending != null) return _copy(await pending);
    if (_retryAfter != null && now.isBefore(_retryAfter!)) return [];
    final epoch = _epoch;
    final operation = _fetch(fetch, uid, epoch);
    _loading = operation;
    try {
      return _copy(await operation);
    } finally {
      if (identical(_loading, operation)) _loading = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(
    Future<Object?> Function() fetch,
    String uid,
    int epoch,
  ) async {
    try {
      final raw = await fetch().timeout(const Duration(seconds: 5));
      if (epoch != _epoch || uid != _uid) return [];
      final now = _now();
      var deadline = now.add(const Duration(minutes: 5));
      final servers = <Map<String, dynamic>>[];
      final items = raw is List
          ? raw
          : raw is Map
          ? raw.values
          : const [];
      for (final item in items) {
        if (item is! Map) continue;
        final expiry = _expiry(item);
        // Chừa thời gian cho bắt tay; không dùng lại TURN sắp hết hạn.
        final safeExpiry = expiry?.subtract(const Duration(seconds: 30));
        if (safeExpiry != null && !safeExpiry.isAfter(now)) continue;
        final parsed = RtcIceServers.parse([item]);
        if (parsed.isEmpty) continue;
        servers.addAll(parsed);
        if (safeExpiry != null && safeExpiry.isBefore(deadline)) {
          deadline = safeExpiry;
        }
      }
      _servers = _copy(servers);
      _validUntil = servers.isEmpty
          ? now.add(const Duration(seconds: 15))
          : deadline;
      _retryAfter = null;
      return servers;
    } catch (_) {
      if (epoch == _epoch && uid == _uid) {
        _servers = null;
        _retryAfter = _now().add(const Duration(seconds: 15));
      }
      rethrow;
    }
  }

  static DateTime? _expiry(Map item) {
    final explicit = item['expiresAt'] ?? item['credentialExpiresAt'];
    // TURN REST thường đặt Unix expiry ở đầu username: "epoch:uid".
    final username = item['username'];
    final prefix = username is String ? username.split(':').first : '';
    final value = explicit is num
        ? explicit
        : explicit is String
        ? num.tryParse(explicit)
        : RegExp(r'^\d{10,13}$').hasMatch(prefix)
        ? num.tryParse(prefix)
        : null;
    if (value == null || !value.isFinite || value <= 0) return null;
    final milliseconds = value < 100000000000 ? value * 1000 : value;
    if (milliseconds > 8640000000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());
  }

  static List<Map<String, dynamic>> _copy(List<Map<String, dynamic>> servers) =>
      servers
          .map(
            (server) => {
              ...server,
              if (server['urls'] is List)
                'urls': List<String>.from(server['urls']),
            },
          )
          .toList();
}
