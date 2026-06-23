import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

/// ============================================================
///  RankingService - GRA (Phase 41)
///  Top Hot leaderboard without full-reading the entire houses tree
/// ============================================================
class RankingService {
  static final RankingService _instance = RankingService._internal();
  factory RankingService() => _instance;
  RankingService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final Map<String, _CachedHouseSnapshot> _houseSnapshotCache =
      <String, _CachedHouseSnapshot>{};

  static const int _defaultTopLimit = 50;
  static const Duration _refreshDebounce = Duration(milliseconds: 120);
  static const Duration _houseSnapshotCacheTtl = Duration(minutes: 10);
  static const int _maxCachedHouseSnapshots = 120;

  /// Listen to Top Hot using small candidate queries instead of `houses.onValue`.
  ///
  /// Candidates come from:
  /// - `uploads/fire_totals` top values
  /// - `houses_public` top `hotScore`
  ///
  /// Detailed profile data is loaded only for those candidate ids.
  Stream<List<RankedHouse>> streamTopHot({int limit = _defaultTopLimit}) {
    final safeLimit = limit.clamp(1, _defaultTopLimit);

    late final StreamController<List<RankedHouse>> controller;
    StreamSubscription<DatabaseEvent>? fireTotalsSub;
    StreamSubscription<DatabaseEvent>? publicHotSub;
    Timer? refreshDebounce;

    Map<String, int> fireTotals = const <String, int>{};
    Set<String> publicHotIds = const <String>{};
    var isRefreshing = false;
    var refreshQueued = false;
    late void Function() scheduleRefresh;
    late Future<void> Function() refreshLeaderboard;

    refreshLeaderboard = () async {
      if (isRefreshing) {
        refreshQueued = true;
        return;
      }

      isRefreshing = true;
      try {
        final candidateIds = <String>{
          ...fireTotals.keys,
          ...publicHotIds,
        };

        if (candidateIds.isEmpty) {
          controller.add(const <RankedHouse>[]);
          return;
        }

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final ranked = await Future.wait(
          candidateIds.map(
            (houseId) => _loadRankedHouse(
              houseId: houseId,
              fireTotal: fireTotals[houseId] ?? 0,
              nowMs: nowMs,
            ),
          ),
        );

        final list = ranked.whereType<RankedHouse>().toList()
          ..sort((a, b) => b.hearts.compareTo(a.hearts));

        if (list.length > safeLimit) {
          list.removeRange(safeLimit, list.length);
        }

        for (var i = 0; i < list.length; i++) {
          list[i].currentRank = i + 1;
        }

        controller.add(list);
      } catch (error) {
        debugPrint(
          '[Ranking] refresh failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể cập nhật bảng xếp hạng.',
          ).message}',
        );
      } finally {
        isRefreshing = false;
        if (refreshQueued) {
          refreshQueued = false;
          scheduleRefresh();
        }
      }
    };

    scheduleRefresh = () {
      refreshDebounce?.cancel();
      refreshDebounce = Timer(_refreshDebounce, refreshLeaderboard);
    };

    controller = StreamController<List<RankedHouse>>.broadcast(
      onListen: () {
        fireTotalsSub = _db
            .ref('uploads/fire_totals')
            .orderByValue()
            .limitToLast(safeLimit)
            .onValue
            .listen(
          (event) {
            fireTotals = _parseScoreMap(event.snapshot.value);
            scheduleRefresh();
          },
          onError: (Object error) {
            debugPrint(
              '[Ranking] fire totals stream failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể tải dữ liệu xếp hạng.',
              ).message}',
            );
          },
        );

        publicHotSub = _db
            .ref('houses_public')
            .orderByChild('hotScore')
            .limitToLast(safeLimit)
            .onValue
            .listen(
          (event) {
            publicHotIds = _parseKeySet(event.snapshot.value);
            scheduleRefresh();
          },
          onError: (Object error) {
            debugPrint(
              '[Ranking] public hot stream failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể tải danh sách nổi bật.',
              ).message}',
            );
          },
        );
      },
      onCancel: () async {
        refreshDebounce?.cancel();
        await fireTotalsSub?.cancel();
        await publicHotSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<RankedHouse?> _loadRankedHouse({
    required String houseId,
    required int fireTotal,
    required int nowMs,
  }) async {
    final merged = await _loadMergedHouseSnapshot(houseId);
    final settings = _asStringMap(merged['settings']);

    final profileHearts = _readInt(merged['hearts_received']);
    final settingsHearts = _readInt(settings['hearts_received']);
    final hotScore = _readInt(merged['hotScore']);

    var totalHearts = profileHearts;
    if (settingsHearts > totalHearts) totalHearts = settingsHearts;
    if (fireTotal > totalHearts) totalHearts = fireTotal;
    if (hotScore > totalHearts) totalHearts = hotScore;

    if (totalHearts <= 0) {
      return null;
    }

    final proUntil = _readInt(settings['proUntil']) > 0
        ? _readInt(settings['proUntil'])
        : _readInt(merged['proUntil']);

    return RankedHouse(
      houseId: houseId,
      name: (settings['houseName']?.toString()) ??
          (merged['houseName']?.toString()) ??
          'Nguoi dung',
      avatar: (settings['houseAvatar']?.toString()) ??
          (merged['houseAvatar']?.toString()) ??
          (merged['avatar']?.toString()) ??
          '',
      bio: (settings['bio']?.toString()) ?? (merged['bio']?.toString()) ?? '',
      hearts: totalHearts,
      hasAdminFireTick:
          settings['adminFireTick'] == true || settings['redTickPro'] == true,
      isPro: proUntil > nowMs && proUntil > 0,
    );
  }

  Future<Map<String, dynamic>> _loadMergedHouseSnapshot(String houseId) async {
    final cached = _houseSnapshotCache[houseId];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.fetchedAt) < _houseSnapshotCacheTtl) {
      return cached.data;
    }

    final values = await Future.wait<Object?>([
      _safeGetValue('house_profiles/$houseId'),
      _safeGetValue('houses_public/$houseId'),
    ]);

    final merged = <String, dynamic>{
      ..._asStringMap(values[1]),
      ..._asStringMap(values[0]),
    };

    _houseSnapshotCache[houseId] = _CachedHouseSnapshot(
      data: merged,
      fetchedAt: now,
    );
    _trimHouseSnapshotCache();
    return merged;
  }

  Future<Object?> _safeGetValue(String path) async {
    try {
      return (await _db.ref(path).get()).value;
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _parseScoreMap(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }

    final map = <String, int>{};
    raw.forEach((key, value) {
      final score = _readInt(value);
      if (score > 0) {
        map[key.toString()] = score;
      }
    });
    return map;
  }

  Set<String> _parseKeySet(Object? raw) {
    if (raw is! Map) {
      return const <String>{};
    }

    final keys = <String>{};
    raw.forEach((key, value) {
      if (value != null) {
        keys.add(key.toString());
      }
    });
    return keys;
  }

  Map<String, dynamic> _asStringMap(Object? raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }
    return raw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _trimHouseSnapshotCache() {
    if (_houseSnapshotCache.length <= _maxCachedHouseSnapshots) {
      return;
    }

    final entries = _houseSnapshotCache.entries.toList()
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
    final removeCount = _houseSnapshotCache.length - _maxCachedHouseSnapshots;
    for (var index = 0; index < removeCount; index++) {
      _houseSnapshotCache.remove(entries[index].key);
    }
  }
}

class _CachedHouseSnapshot {
  const _CachedHouseSnapshot({
    required this.data,
    required this.fetchedAt,
  });

  final Map<String, dynamic> data;
  final DateTime fetchedAt;
}

class RankedHouse {
  final String houseId;
  final String name;
  final String avatar;
  final String bio;
  final int hearts;
  final bool hasAdminFireTick;
  final bool isPro;
  int currentRank;

  RankedHouse({
    required this.houseId,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.hearts,
    required this.hasAdminFireTick,
    required this.isPro,
    this.currentRank = 0,
  });
}
