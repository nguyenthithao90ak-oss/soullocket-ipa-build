import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_error_mapper.dart';

export '../utils/services/gps_tracker_service.dart' show GpsTrackerService;

class GpsHistoryCleanupService {
  GpsHistoryCleanupService._();

  static final GpsHistoryCleanupService instance = GpsHistoryCleanupService._();

  static const int maxRetainedDays = 7;
  static const int maxPointsPerDay = 900;
  static const Duration _minRunInterval = Duration(hours: 6);

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Map<String, int> _lastRunAtMsByScope = <String, int>{};
  final Set<String> _runningScopes = <String>{};

  Future<void> scheduleCleanup({
    required String houseId,
    required String role,
  }) async {
    final normalizedHouseId = houseId.trim();
    final normalizedRole = role.trim();
    if (normalizedHouseId.isEmpty || normalizedRole.isEmpty) {
      return;
    }

    final scopeKey = '$normalizedHouseId|$normalizedRole';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastRunAtMs = _lastRunAtMsByScope[scopeKey];
    if (lastRunAtMs != null &&
        nowMs - lastRunAtMs < _minRunInterval.inMilliseconds) {
      return;
    }
    if (!_runningScopes.add(scopeKey)) {
      return;
    }

    try {
      await _cleanupScope(
        houseId: normalizedHouseId,
        role: normalizedRole,
      );
      _lastRunAtMsByScope[scopeKey] = nowMs;
    } on FirebaseException catch (error) {
      final info = AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('err_gps_cleanup_failed'),
      );
      if (error.code.toLowerCase() == 'permission-denied') {
        return;
      }
      debugPrint('GPS cleanup failed: ${info.message}');
    } finally {
      _runningScopes.remove(scopeKey);
    }
  }

  Future<void> _cleanupScope({
    required String houseId,
    required String role,
  }) async {
    final basePath = 'gps_history/$houseId/$role';
    try {
      final snapshot = await _dbRef.child(basePath).get();
      if (!snapshot.exists || snapshot.value is! Map) {
        return;
      }

      final rawBuckets = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final buckets = <_GpsHistoryDayBucket>[
        for (final entry in rawBuckets.entries)
          _GpsHistoryDayBucket(
            dateKey: entry.key.toString(),
            rawPoints: entry.value is Map
                ? Map<dynamic, dynamic>.from(entry.value as Map)
                : const <dynamic, dynamic>{},
          ),
      ]..sort((left, right) => left.dateKey.compareTo(right.dateKey));

      final updates = <String, dynamic>{};
      final keepStartIndex =
          buckets.length > maxRetainedDays ? buckets.length - maxRetainedDays : 0;

      for (var i = 0; i < keepStartIndex; i++) {
        updates['$basePath/${buckets[i].dateKey}'] = null;
      }

      for (var i = keepStartIndex; i < buckets.length; i++) {
        final bucket = buckets[i];
        final removableKeys = _collectOverflowPointKeys(bucket.rawPoints);
        for (final pointKey in removableKeys) {
          updates['$basePath/${bucket.dateKey}/$pointKey'] = null;
        }
      }

      if (updates.isEmpty) {
        return;
      }
      await _dbRef.update(updates);
    } on FirebaseException catch (error) {
      if (error.code.toLowerCase() == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  List<String> _collectOverflowPointKeys(Map<dynamic, dynamic> rawPoints) {
    final entries = <_GpsHistoryPointRef>[
      for (final entry in rawPoints.entries)
        _GpsHistoryPointRef(
          key: entry.key.toString(),
          ts: _readTimestamp(entry.value),
        ),
    ];

    if (entries.length <= maxPointsPerDay) {
      return const <String>[];
    }

    entries.sort((left, right) {
      final tsCompare = left.ts.compareTo(right.ts);
      if (tsCompare != 0) {
        return tsCompare;
      }
      return left.key.compareTo(right.key);
    });

    final overflowCount = entries.length - maxPointsPerDay;
    return [
      for (final entry in entries.take(overflowCount)) entry.key,
    ];
  }

  int _readTimestamp(dynamic rawPoint) {
    if (rawPoint is Map) {
      final value = rawPoint['ts'];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }
    return 0;
  }
}

class _GpsHistoryDayBucket {
  final String dateKey;
  final Map<dynamic, dynamic> rawPoints;

  const _GpsHistoryDayBucket({
    required this.dateKey,
    required this.rawPoints,
  });
}

class _GpsHistoryPointRef {
  final String key;
  final int ts;

  const _GpsHistoryPointRef({
    required this.key,
    required this.ts,
  });
}
