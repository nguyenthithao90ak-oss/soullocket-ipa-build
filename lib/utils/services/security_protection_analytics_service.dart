import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'house_service.dart';
import 'security_protection_service.dart';
import '../app_error_mapper.dart';

class SecurityProtectionDailySummary {
  final String dayKey;
  final int allowCount;
  final int warnCount;
  final int blockCount;
  final int totalCount;

  const SecurityProtectionDailySummary({
    required this.dayKey,
    required this.allowCount,
    required this.warnCount,
    required this.blockCount,
    required this.totalCount,
  });
}

class SecurityProtectionAnalyticsService {
  SecurityProtectionAnalyticsService._internal();

  static final SecurityProtectionAnalyticsService _instance =
      SecurityProtectionAnalyticsService._internal();

  factory SecurityProtectionAnalyticsService() => _instance;

  static const String _eventsBasePath =
      'admin_system/security_protection_events';
  static const String _dailyBasePath =
      'admin_system/security_protection_daily_summary';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final HouseService _houseService = HouseService();

  Future<void> logDecision({
    required SecurityProtectionVerdict verdict,
    String eventType = 'risk_evaluated',
    String source = 'app',
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    try {
      final now = DateTime.now();
      final dayKey = _formatDayKey(now);
      final user = FirebaseAuth.instance.currentUser;
      final houseId = await _houseService.getCurrentHouseId();

      await _db.child('$_eventsBasePath/$dayKey').push().set({
        'ts': ServerValue.timestamp,
        'eventType': eventType,
        'source': source,
        'uid': user?.uid,
        'houseId': houseId,
        'screenId': verdict.screenId,
        'actionId': verdict.actionId,
        'reason': verdict.reason.key,
        'reasonCode': verdict.reasonCode,
        'rawRisk': verdict.rawRisk.key,
        'effectiveRisk': verdict.effectiveRisk.key,
        'rolloutStage': verdict.rolloutStage.key,
        'reasonEnabled': verdict.reasonEnabled,
        'signals': verdict.signals,
        'extra': {
          for (final entry in extra.entries) entry.key: entry.value,
        },
      });

      await _db.child('$_dailyBasePath/$dayKey').update({
        'totalCount': ServerValue.increment(1),
        '${verdict.effectiveRisk.key}Count': ServerValue.increment(1),
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Security protection analytics log failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể ghi thống kê bảo vệ bảo mật.',
      ).message}');
    }
  }

  Future<List<SecurityProtectionDailySummary>> fetchRecentDailySummaries({
    int days = 7,
  }) async {
    try {
      final snapshot = await _db.child(_dailyBasePath).limitToLast(days).get();
      final raw = snapshot.value;
      if (raw is! Map) {
        return const <SecurityProtectionDailySummary>[];
      }

      final items = <SecurityProtectionDailySummary>[];
      final map = Map<Object?, Object?>.from(raw);
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        final item = Map<Object?, Object?>.from(value);
        items.add(
          SecurityProtectionDailySummary(
            dayKey: entry.key?.toString() ?? '',
            allowCount: _readCounter(item['allowCount']),
            warnCount: _readCounter(item['warnCount']),
            blockCount: _readCounter(item['blockCount']),
            totalCount: _readCounter(item['totalCount']),
          ),
        );
      }

      items.sort((left, right) => right.dayKey.compareTo(left.dayKey));
      return items;
    } catch (e) {
      debugPrint('Security protection summary fetch failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể tải tổng hợp bảo vệ bảo mật.',
      ).message}');
      return const <SecurityProtectionDailySummary>[];
    }
  }

  String _formatDayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}

int _readCounter(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
