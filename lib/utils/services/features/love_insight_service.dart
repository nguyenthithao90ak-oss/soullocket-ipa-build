import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/ai_counselor_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/push_notification_helper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class LoveInsightTimelineEntry {
  final DateTime date;
  final String title;
  final String type;
  final String subtitle;

  const LoveInsightTimelineEntry({
    required this.date,
    required this.title,
    required this.type,
    required this.subtitle,
  });

  bool get isCustom => type == 'custom';

  Map<String, dynamic> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'title': title,
      'type': type,
      'subtitle': subtitle,
    };
  }

  factory LoveInsightTimelineEntry.fromMap(Map<String, dynamic> map) {
    return LoveInsightTimelineEntry(
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      title: map['title'] as String,
      type: map['type'] as String,
      subtitle: map['subtitle'] as String,
    );
  }
}

class LoveInsightData {
  final int updatedAt;
  final int loveScore;
  final String level;
  final int loveDays;
  final int positivity;
  final int diaryMonth;
  final int albumMonth;
  final int memoryThisMonth;
  final int activeDays;
  final int diaryTotal;
  final int albumTotal;
  final String suggestion;
  final double shareU1;
  final double shareU2;
  final double offU1;
  final double offU2;
  final double interactionRate;
  final String nameU1;
  final String nameU2;
  final String favoriteActivity;
  final int diaryU1;
  final int diaryU2;
  final int albumU1;
  final int albumU2;
  final int moodPosU1;
  final int moodPosU2;
  final int viewU1;
  final int viewU2;
  final int openU1;
  final int openU2;
  final int loveU1;
  final int loveU2;
  final List<LoveInsightTimelineEntry> timeline;

  const LoveInsightData({
    required this.updatedAt,
    required this.loveScore,
    required this.level,
    required this.loveDays,
    required this.positivity,
    required this.diaryMonth,
    required this.albumMonth,
    required this.memoryThisMonth,
    required this.activeDays,
    required this.diaryTotal,
    required this.albumTotal,
    required this.suggestion,
    required this.shareU1,
    required this.shareU2,
    required this.offU1,
    required this.offU2,
    required this.interactionRate,
    required this.nameU1,
    required this.nameU2,
    required this.favoriteActivity,
    required this.diaryU1,
    required this.diaryU2,
    required this.albumU1,
    required this.albumU2,
    required this.moodPosU1,
    required this.moodPosU2,
    required this.viewU1,
    required this.viewU2,
    required this.openU1,
    required this.openU2,
    required this.loveU1,
    required this.loveU2,
    required this.timeline,
  });

  Map<String, dynamic> toMap() {
    return {
      'updatedAt': updatedAt,
      'loveScore': loveScore,
      'level': level,
      'loveDays': loveDays,
      'positivity': positivity,
      'diaryMonth': diaryMonth,
      'albumMonth': albumMonth,
      'memoryThisMonth': memoryThisMonth,
      'activeDays': activeDays,
      'diaryTotal': diaryTotal,
      'albumTotal': albumTotal,
      'suggestion': suggestion,
      'shareU1': shareU1,
      'shareU2': shareU2,
      'offU1': offU1,
      'offU2': offU2,
      'interactionRate': interactionRate,
      'nameU1': nameU1,
      'nameU2': nameU2,
      'favoriteActivity': favoriteActivity,
      'diaryU1': diaryU1,
      'diaryU2': diaryU2,
      'albumU1': albumU1,
      'albumU2': albumU2,
      'moodPosU1': moodPosU1,
      'moodPosU2': moodPosU2,
      'viewU1': viewU1,
      'viewU2': viewU2,
      'openU1': openU1,
      'openU2': openU2,
      'loveU1': loveU1,
      'loveU2': loveU2,
      'timeline': timeline.map((x) => x.toMap()).toList(),
    };
  }

  factory LoveInsightData.fromMap(Map<String, dynamic> map) {
    return LoveInsightData(
      updatedAt: map['updatedAt'] as int? ?? 0,
      loveScore: map['loveScore'] as int? ?? 0,
      level: map['level'] as String? ?? '',
      loveDays: map['loveDays'] as int? ?? 0,
      positivity: map['positivity'] as int? ?? 0,
      diaryMonth: map['diaryMonth'] as int? ?? 0,
      albumMonth: map['albumMonth'] as int? ?? 0,
      memoryThisMonth: map['memoryThisMonth'] as int? ?? 0,
      activeDays: map['activeDays'] as int? ?? 0,
      diaryTotal: map['diaryTotal'] as int? ?? 0,
      albumTotal: map['albumTotal'] as int? ?? 0,
      suggestion: map['suggestion'] as String? ?? '',
      shareU1: (map['shareU1'] as num?)?.toDouble() ?? 0.0,
      shareU2: (map['shareU2'] as num?)?.toDouble() ?? 0.0,
      offU1: (map['offU1'] as num?)?.toDouble() ?? 0.0,
      offU2: (map['offU2'] as num?)?.toDouble() ?? 0.0,
      interactionRate: (map['interactionRate'] as num?)?.toDouble() ?? 0.0,
      nameU1: map['nameU1'] as String? ?? '',
      nameU2: map['nameU2'] as String? ?? '',
      favoriteActivity: map['favoriteActivity'] as String? ?? '',
      diaryU1: map['diaryU1'] as int? ?? 0,
      diaryU2: map['diaryU2'] as int? ?? 0,
      albumU1: map['albumU1'] as int? ?? 0,
      albumU2: map['albumU2'] as int? ?? 0,
      moodPosU1: map['moodPosU1'] as int? ?? 0,
      moodPosU2: map['moodPosU2'] as int? ?? 0,
      viewU1: map['viewU1'] as int? ?? 0,
      viewU2: map['viewU2'] as int? ?? 0,
      openU1: map['openU1'] as int? ?? 0,
      openU2: map['openU2'] as int? ?? 0,
      loveU1: map['loveU1'] as int? ?? 0,
      loveU2: map['loveU2'] as int? ?? 0,
      timeline: List<LoveInsightTimelineEntry>.from(
        (map['timeline'] as List<dynamic>? ?? []).map(
          (x) => LoveInsightTimelineEntry.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }
}

class LoveInsightService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Cache 5 phút để tránh tải toàn bộ diary+album nhiều lần
  static LoveInsightData? _cachedInsight;
  static String? _cachedHouseId;
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 15);

  String _tr(String key, [Map<String, Object?> params = const {}]) {
    final l10n = L10nService();
    return params.isEmpty ? l10n.translate(key) : l10n.format(key, params);
  }

  static const List<int> _monthMilestones = [1, 3, 6, 9];
  static const List<int> _dayMilestones = [
    10,
    30,
    100,
    200,
    300,
    365,
    400,
    500,
    600,
    700,
    800,
    900,
    1000,
    1100,
    1200,
    1300,
    1400,
    1500,
    1600,
    1700,
    1800,
    1900,
    2000,
    2100,
    2200,
    2300,
    2400,
    2500,
    2600,
    2700,
    2800,
    2900,
    3000,
    4000,
    5000,
    6000,
    7000,
    8000,
    9000,
    10000,
  ];
  static const int _maxYearMilestone = 50;

  static const Set<String> _positiveMoods = {
    '😍',
    '🥰',
    '😊',
    '😄',
    '🤩',
    '😘',
    '❤️',
    '💖',
    '😌',
    '🤗',
    '💞',
    '💝',
  };

  static const Set<String> _negativeMoods = {
    '😢',
    '😭',
    '😞',
    '😔',
    '😡',
    '💔',
    '😤',
    '😫',
    '😩',
    '🥺',
  };

  Future<LoveInsightData> computeInsights(
    String houseId,
    String relationshipMode,
  ) async {
    final now = DateTime.now();
    // Trả về cache nếu còn trong TTL 5 phút và cùng houseId
    if (_cachedInsight != null &&
        _cachedHouseId == houseId &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl) {
      return _cachedInsight!;
    }
    final monthStart = DateTime(now.year, now.month, 1);

    final firestore = FirebaseFirestore.instance;
    final cutoff45Days = now.subtract(const Duration(days: 45)).millisecondsSinceEpoch;

    try {
      final results = await Future.wait([
        firestore.collection('houses').doc(houseId).collection('diaries').where('ts', isGreaterThanOrEqualTo: cutoff45Days).get(),
        firestore.collection('houses').doc(houseId).collection('album').where('ts', isGreaterThanOrEqualTo: cutoff45Days).get(),
        _dbRef.child('houses/$houseId/settings').get(),
        _dbRef.child('houses/$houseId/presence').get(),
        _dbRef.child('houses/$houseId/metrics/diary_views').get(),
        _dbRef.child('houses/$houseId/metrics/app_open').get(),
        firestore.collection('houses').doc(houseId).collection('diaries').count().get(),
        firestore.collection('houses').doc(houseId).collection('album').count().get(),
      ]).timeout(const Duration(seconds: 8));

      final data = await _processInsightData(
        relationshipMode,
        monthStart,
        (results[0] as QuerySnapshot).docs,
        (results[1] as QuerySnapshot).docs,
        (results[2] as DataSnapshot).value,
        (results[3] as DataSnapshot).value,
        (results[4] as DataSnapshot).value,
        (results[5] as DataSnapshot).value,
        (results[6] as AggregateQuerySnapshot).count ?? 0,
        (results[7] as AggregateQuerySnapshot).count ?? 0,
      );
      await _saveInsightCache(houseId, relationshipMode, data);
      // Cập nhật in-memory cache
      _cachedInsight = data;
      _cachedHouseId = houseId;
      _cacheTime = DateTime.now();
      return data;
    } catch (e) {
      final cached = await _loadInsightCache(houseId, relationshipMode);
      if (cached != null) {
        return cached;
      }
      // Offline fallback
      return LoveInsightData(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        loveScore: 0,
        level: 'Chưa có',
        loveDays: 0,
        positivity: 0,
        diaryMonth: 0,
        albumMonth: 0,
        memoryThisMonth: 0,
        activeDays: 0,
        diaryTotal: 0,
        albumTotal: 0,
        suggestion:
            'Bạn đang offline hoặc mạng yếu, dữ liệu sẽ được cập nhật khi có mạng.',
        shareU1: 0,
        shareU2: 0,
        offU1: 0,
        offU2: 0,
        interactionRate: 0,
        nameU1: 'Bạn',
        nameU2: 'Người ấy',
        favoriteActivity: 'Chưa rõ',
        diaryU1: 0,
        diaryU2: 0,
        albumU1: 0,
        albumU2: 0,
        moodPosU1: 0,
        moodPosU2: 0,
        viewU1: 0,
        viewU2: 0,
        openU1: 0,
        openU2: 0,
        loveU1: 0,
        loveU2: 0,
        timeline: [],
      );
    }
  }

  String _insightCacheKey(String houseId, String relationshipMode) =>
      'love_insight_${houseId.trim()}_${relationshipMode.trim()}';

  Future<void> _saveInsightCache(
    String houseId,
    String relationshipMode,
    LoveInsightData data,
  ) async {
    try {
      await OfflineCacheService.saveCache(
        _insightCacheKey(houseId, relationshipMode),
        data.toMap(),
      );
    } catch (_) {}
  }

  Future<LoveInsightData?> _loadInsightCache(
    String houseId,
    String relationshipMode,
  ) async {
    try {
      final cached = await OfflineCacheService.loadCache(
        _insightCacheKey(houseId, relationshipMode),
      );
      if (cached is Map) {
        return LoveInsightData.fromMap(
          Map<String, dynamic>.from(Map<dynamic, dynamic>.from(cached)),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<LoveInsightData> _processInsightData(
    String relationshipMode,
    DateTime monthStart,
    List<QueryDocumentSnapshot> diaryDocs,
    List<QueryDocumentSnapshot> albumDocs,
    dynamic settingsValue,
    dynamic presenceValue,
    dynamic diaryViewsValue,
    dynamic appOpensValue,
    int totalDiaryCount,
    int totalAlbumCount,
  ) async {
    final now = DateTime.now();
    final diaryList = diaryDocs.map((e) => e.data() as Map<String, dynamic>).toList();
    final albumList = albumDocs.map((e) => e.data() as Map<String, dynamic>).toList();
    final settings = _asMap(settingsValue);
    final presence = _asMap(presenceValue);
    final diaryViews = _intMap(diaryViewsValue);
    final appOpens = _intMap(appOpensValue);
    final recent14Cutoff = _startOfDay(
      now.subtract(const Duration(days: 13)),
    ).millisecondsSinceEpoch;
    final recent30Cutoff = _startOfDay(
      now.subtract(const Duration(days: 29)),
    ).millisecondsSinceEpoch;

    final isSingle = relationshipMode == 'single';
    final rawNameU1 = _string(settings['nameU1'],
        fallback: L10nService().translate('home_bn_1fd75b'));
    final rawNameU2 = _string(settings['nameU2'],
        fallback: L10nService().translate('home_ngiy_5bab37'));
    final nameU1 = rawNameU1.toLowerCase() == 'bạn nam'
        ? L10nService().translate('male_role_default')
        : (rawNameU1.toLowerCase() == 'bạn nữ'
            ? L10nService().translate('female_role_default')
            : rawNameU1);
    final nameU2 = rawNameU2.toLowerCase() == 'bạn nữ'
        ? L10nService().translate('female_role_default')
        : (rawNameU2.toLowerCase() == 'bạn nam'
            ? L10nService().translate('male_role_default')
            : rawNameU2);

    var diaryTotal = totalDiaryCount;
    var diaryMonth = 0;
    var albumTotal = totalAlbumCount;
    var albumMonth = 0;
    var moodTotal = 0;
    var positiveMoodTotal = 0;
    var negativeMoodTotal = 0;
    final activeDays = <String>{};
    final recentActiveDays = <String>{};
    final recentActiveDaysU1 = <String>{};
    final recentActiveDaysU2 = <String>{};
    final recentOwnersByDay = <String, Set<String>>{};

    var diaryU1 = 0;
    var diaryU2 = 0;
    var albumU1 = 0;
    var albumU2 = 0;
    var moodPosU1 = 0;
    var moodPosU2 = 0;
    var moodTotalU1 = 0;
    var moodTotalU2 = 0;
    var recentMoodTotal = 0;
    var recentPositiveMoodTotal = 0;
    var recentNegativeMoodTotal = 0;
    var recentMoodTotalU1 = 0;
    var recentMoodTotalU2 = 0;
    var recentMoodPosU1 = 0;
    var recentMoodPosU2 = 0;

    var recentDiary14 = 0;
    var recentDiary30 = 0;
    var recentAlbum14 = 0;
    var recentAlbum30 = 0;
    var recentDiary14U1 = 0;
    var recentDiary14U2 = 0;
    var recentDiary30U1 = 0;
    var recentDiary30U2 = 0;
    var recentAlbum14U1 = 0;
    var recentAlbum14U2 = 0;
    var recentAlbum30U1 = 0;
    var recentAlbum30U2 = 0;

    var latestMemoryTs = 0;
    var latestU1TouchTs = 0;
    var latestU2TouchTs = 0;

    for (final item in diaryList) {
      final owner = _resolveOwner(item, nameU1, nameU2);
      final ts = _toTimestamp(item);
      if (ts > 0) {
        latestMemoryTs = max(latestMemoryTs, ts);
        if (owner == 'user1') {
          latestU1TouchTs = max(latestU1TouchTs, ts);
        } else if (owner == 'user2') {
          latestU2TouchTs = max(latestU2TouchTs, ts);
        }

        final dayKey = DateTime.fromMillisecondsSinceEpoch(ts)
            .toIso8601String()
            .split('T')
            .first;
        activeDays.add(dayKey);
        if (ts >= monthStart.millisecondsSinceEpoch) {
          diaryMonth++;
        }
        if (ts >= recent30Cutoff) {
          recentDiary30++;
          recentActiveDays.add(dayKey);
          if (owner.isNotEmpty) {
            recentOwnersByDay.putIfAbsent(dayKey, () => <String>{}).add(owner);
          }
          if (owner == 'user1') {
            recentDiary30U1++;
            recentActiveDaysU1.add(dayKey);
          } else if (owner == 'user2') {
            recentDiary30U2++;
            recentActiveDaysU2.add(dayKey);
          }
        }
        if (ts >= recent14Cutoff) {
          recentDiary14++;
          if (owner == 'user1') {
            recentDiary14U1++;
          } else if (owner == 'user2') {
            recentDiary14U2++;
          }
        }
      }

      final mood = _string(item['mood']);
      if (mood.isNotEmpty) {
        moodTotal++;
        if (owner == 'user1') {
          moodTotalU1++;
        } else if (owner == 'user2') {
          moodTotalU2++;
        }
        if (ts >= recent30Cutoff) {
          recentMoodTotal++;
          if (owner == 'user1') {
            recentMoodTotalU1++;
          } else if (owner == 'user2') {
            recentMoodTotalU2++;
          }
        }
        if (_positiveMoods.contains(mood)) {
          positiveMoodTotal++;
          if (owner == 'user1') {
            moodPosU1++;
          } else if (owner == 'user2') {
            moodPosU2++;
          }
          if (ts >= recent30Cutoff) {
            recentPositiveMoodTotal++;
            if (owner == 'user1') {
              recentMoodPosU1++;
            } else if (owner == 'user2') {
              recentMoodPosU2++;
            }
          }
        } else if (_negativeMoods.contains(mood)) {
          negativeMoodTotal++;
          if (ts >= recent30Cutoff) {
            recentNegativeMoodTotal++;
          }
        }
      }

      if (owner == 'user1') {
        diaryU1++;
      } else if (owner == 'user2') {
        diaryU2++;
      }
    }

    for (final item in albumList) {
      final owner = _resolveOwner(item, nameU1, nameU2);
      final ts = _toTimestamp(item);
      if (ts > 0) {
        latestMemoryTs = max(latestMemoryTs, ts);
        if (owner == 'user1') {
          latestU1TouchTs = max(latestU1TouchTs, ts);
        } else if (owner == 'user2') {
          latestU2TouchTs = max(latestU2TouchTs, ts);
        }

        final dayKey = DateTime.fromMillisecondsSinceEpoch(ts)
            .toIso8601String()
            .split('T')
            .first;
        activeDays.add(dayKey);
        if (ts >= monthStart.millisecondsSinceEpoch) {
          albumMonth++;
        }
        if (ts >= recent30Cutoff) {
          recentAlbum30++;
          recentActiveDays.add(dayKey);
          if (owner.isNotEmpty) {
            recentOwnersByDay.putIfAbsent(dayKey, () => <String>{}).add(owner);
          }
          if (owner == 'user1') {
            recentAlbum30U1++;
            recentActiveDaysU1.add(dayKey);
          } else if (owner == 'user2') {
            recentAlbum30U2++;
            recentActiveDaysU2.add(dayKey);
          }
        }
        if (ts >= recent14Cutoff) {
          recentAlbum14++;
          if (owner == 'user1') {
            recentAlbum14U1++;
          } else if (owner == 'user2') {
            recentAlbum14U2++;
          }
        }
      }

      if (owner == 'user1') {
        albumU1++;
      } else if (owner == 'user2') {
        albumU2++;
      }
    }

    final startDate = _parseFlexibleDate(_string(settings['startDate']));
    final loveDays = startDate == null
        ? 0
        : max(0, _startOfDay(now).difference(_startOfDay(startDate)).inDays);
    final positivity = moodTotal > 0
        ? ((positiveMoodTotal / moodTotal) * 100).round().clamp(0, 100)
        : 74;
    final memoryThisMonth = diaryMonth + albumMonth;
    final viewU1 = diaryViews['user1'] ?? 0;
    final viewU2 = diaryViews['user2'] ?? 0;
    final openU1 = appOpens['user1'] ?? 0;
    final openU2 = appOpens['user2'] ?? 0;

    final recentPositivity = recentMoodTotal > 0
        ? ((recentPositiveMoodTotal / recentMoodTotal) * 100)
            .round()
            .clamp(0, 100)
        : positivity;
    final blendedPositivity =
        ((positivity * 0.58) + (recentPositivity * 0.42)).round().clamp(0, 100);
    final recentMemory30 = recentDiary30 + recentAlbum30;
    final recentMemoryUnits = (recentDiary30 * 1.1) +
        (recentAlbum30 * 1.25) +
        (recentDiary14 * 0.6) +
        (recentAlbum14 * 0.75);
    final sharedDays30 = recentOwnersByDay.values
        .where((owners) => owners.contains('user1') && owners.contains('user2'))
        .length;
    final daysSinceLastMemory = _daysSinceTimestamp(latestMemoryTs, now);
    final daysSinceU1Touch = _daysSinceTimestamp(latestU1TouchTs, now);
    final daysSinceU2Touch = _daysSinceTimestamp(latestU2TouchTs, now);

    final attentionU1 = (viewU1 * 0.22) + (openU1 * 0.55);
    final attentionU2 = (viewU2 * 0.22) + (openU2 * 0.55);
    final attentionTotal = attentionU1 + attentionU2;

    final recentEffortU1 = (recentDiary30U1 * 1.9) +
        (recentAlbum30U1 * 1.6) +
        (recentMoodPosU1 * 1.0) +
        (recentDiary14U1 * 0.8) +
        (recentAlbum14U1 * 0.7);
    final recentEffortU2 = (recentDiary30U2 * 1.9) +
        (recentAlbum30U2 * 1.6) +
        (recentMoodPosU2 * 1.0) +
        (recentDiary14U2 * 0.8) +
        (recentAlbum14U2 * 0.7);
    final baseEffortU1 =
        (diaryU1 * 0.22) + (albumU1 * 0.18) + (moodPosU1 * 0.40);
    final baseEffortU2 =
        (diaryU2 * 0.22) + (albumU2 * 0.18) + (moodPosU2 * 0.40);
    final contribU1 = recentEffortU1 + baseEffortU1 + attentionU1;
    final contribU2 = recentEffortU2 + baseEffortU2 + attentionU2;
    final contribTotal = contribU1 + contribU2;
    final shareU1 = isSingle
        ? 1.0
        : contribTotal > 0
            ? contribU1 / contribTotal
            : 0.5;
    final shareU2 = isSingle
        ? 0.0
        : contribTotal > 0
            ? contribU2 / contribTotal
            : 0.5;
    final balanceRatio =
        isSingle ? 1.0 : (1 - ((shareU1 - 0.5).abs() * 2)).clamp(0.0, 1.0);

    final overallNegativeRatio =
        moodTotal > 0 ? negativeMoodTotal / moodTotal : 0.0;
    final recentNegativeRatio = recentMoodTotal > 0
        ? recentNegativeMoodTotal / recentMoodTotal
        : overallNegativeRatio;
    final moodPenalty = min(
      8.0,
      ((overallNegativeRatio * 0.4) + (recentNegativeRatio * 0.6)) * 12,
    );

    final offU1 = _calcOfflineDays(_asMap(presence['user1']), now);
    final offU2 = _calcOfflineDays(_asMap(presence['user2']), now);
    final offPenaltyU1 = offU1 > 1 ? min(18.0, (offU1 - 1) * 2.1) : 0.0;
    final offPenaltyU2 = offU2 > 1 ? min(18.0, (offU2 - 1) * 2.1) : 0.0;

    final freshnessScore = _freshnessBoost(
      daysSinceLastMemory,
      maxBoost: isSingle ? 10.0 : 8.0,
    );
    final stalePenalty = _stalePenalty(
      daysSinceLastMemory,
      startAfter: isSingle ? 5.0 : 4.0,
      step: isSingle ? 1.0 : 1.15,
      maxPenalty: isSingle ? 18.0 : 16.0,
    );

    final foundationScoreCouple =
        min(14.0, (log(max(1, loveDays + 1)) / log(3651)) * 14);
    final recentMemoryScoreCouple = min(20.0, (recentMemoryUnits / 18) * 20);
    final rhythmScoreCouple = min(14.0, (recentActiveDays.length / 18) * 14);
    final togetherScore = min(10.0, (sharedDays30 / 8) * 10);
    final positivityScoreCouple = min(12.0, (blendedPositivity / 100) * 12);
    final balanceScore = min(8.0, balanceRatio * 8);
    final attentionScoreCouple = min(6.0, (attentionTotal / 20) * 6);

    final foundationScoreSingle =
        min(10.0, (log(max(1, loveDays + 1)) / log(1461)) * 10);
    final recentMemoryScoreSingle = min(24.0, (recentMemoryUnits / 16) * 24);
    final rhythmScoreSingle = min(18.0, (recentActiveDaysU1.length / 18) * 18);
    final positivityScoreSingle = min(18.0, (blendedPositivity / 100) * 18);
    final attentionScoreSingle = min(6.0, (attentionU1 / 9) * 6);

    var loveScore = 0;
    if (isSingle) {
      final offlinePenalty = max(
        0.0,
        (offPenaltyU1 * 0.65) - (recentActiveDaysU1.length >= 6 ? 1.0 : 0.0),
      );
      loveScore = (24 +
              foundationScoreSingle +
              recentMemoryScoreSingle +
              rhythmScoreSingle +
              positivityScoreSingle +
              attentionScoreSingle +
              freshnessScore -
              moodPenalty -
              stalePenalty -
              offlinePenalty)
          .round();
      if (recentMemory30 >= 8 || recentActiveDaysU1.length >= 12) {
        loveScore = max(loveScore, 72);
      }
      if (recentDiary14 + recentAlbum14 >= 4 && blendedPositivity >= 75) {
        loveScore = max(loveScore, 68);
      }
    } else {
      final offlinePenalty = max(
        0.0,
        ((offPenaltyU1 + offPenaltyU2) * 0.62) -
            (recentActiveDays.length >= 8 ? 1.5 : 0.0),
      );
      loveScore = (26 +
              foundationScoreCouple +
              recentMemoryScoreCouple +
              rhythmScoreCouple +
              togetherScore +
              positivityScoreCouple +
              balanceScore +
              attentionScoreCouple +
              freshnessScore -
              moodPenalty -
              stalePenalty -
              offlinePenalty)
          .round();
      if (loveDays >= 90 && recentMemory30 >= 4) {
        loveScore = max(loveScore, 64);
      }
      if (loveDays >= 365 && recentActiveDays.length >= 8) {
        loveScore = max(loveScore, 70);
      }
      if (recentMemory30 >= 12 && sharedDays30 >= 5) {
        loveScore = max(loveScore, 76);
      }
    }
    loveScore = max(isSingle ? 30 : 28, min(100, loveScore));

    final level = loveScore >= 90
        ? 'Soulmate rực rỡ'
        : loveScore >= 75
            ? 'Yêu sâu đậm'
            : loveScore >= 60
                ? 'Đang rất ổn'
                : loveScore >= 45
                    ? 'Cần hâm nóng'
                    : 'Nên chăm nhau hơn';

    final user1Positivity = moodTotalU1 > 0
        ? ((moodPosU1 / moodTotalU1) * 100).round().clamp(0, 100)
        : blendedPositivity;
    final user2Positivity = moodTotalU2 > 0
        ? ((moodPosU2 / moodTotalU2) * 100).round().clamp(0, 100)
        : blendedPositivity;
    final recentUser1Positivity = recentMoodTotalU1 > 0
        ? ((recentMoodPosU1 / recentMoodTotalU1) * 100).round().clamp(0, 100)
        : user1Positivity;
    final recentUser2Positivity = recentMoodTotalU2 > 0
        ? ((recentMoodPosU2 / recentMoodTotalU2) * 100).round().clamp(0, 100)
        : user2Positivity;
    final blendedUser1Positivity =
        ((user1Positivity * 0.55) + (recentUser1Positivity * 0.45))
            .round()
            .clamp(0, 100);
    final blendedUser2Positivity =
        ((user2Positivity * 0.55) + (recentUser2Positivity * 0.45))
            .round()
            .clamp(0, 100);

    final loveU1 = _personalLoveScore(
      baseLoveScore: loveScore,
      effort: recentEffortU1 + (baseEffortU1 * 0.6),
      recentActiveDays: recentActiveDaysU1.length,
      positivity: blendedUser1Positivity,
      attention: attentionU1,
      daysSinceTouch: daysSinceU1Touch,
      offlineDays: offU1,
      isSingle: isSingle,
    );
    final loveU2 = isSingle
        ? loveU1
        : _personalLoveScore(
            baseLoveScore: loveScore,
            effort: recentEffortU2 + (baseEffortU2 * 0.6),
            recentActiveDays: recentActiveDaysU2.length,
            positivity: blendedUser2Positivity,
            attention: attentionU2,
            daysSinceTouch: daysSinceU2Touch,
            offlineDays: offU2,
            isSingle: false,
          );
    final interactionRate = recentActiveDays.isNotEmpty
        ? ((recentMemory30 / recentActiveDays.length) * 10).round() / 10
        : 0.0;
    final favoriteActivity = diaryTotal > albumTotal
        ? 'Viết nhật ký'
        : diaryTotal < albumTotal
            ? 'Đăng ảnh/video'
            : 'Cân bằng cả hai';

    final timeline = _buildTimeline(
      startDate: startDate,
      customEvents: _asMap(settings['customEvents']),
      isSingle: isSingle,
      now: now,
    );

    final suggestion = await _buildSuggestion(
      isSingle: isSingle,
      loveDays: loveDays,
      loveScore: loveScore,
      level: level,
      positivity: positivity,
      memoryThisMonth: memoryThisMonth,
      activeDays: activeDays.length,
      shareU1: shareU1,
      shareU2: shareU2,
      offU1: offU1,
      offU2: offU2,
      daysSinceLastMemory: daysSinceLastMemory,
      balanceRatio: balanceRatio,
      timeline: timeline,
      now: now,
    );

    return LoveInsightData(
      updatedAt: now.millisecondsSinceEpoch,
      loveScore: loveScore,
      level: level,
      loveDays: loveDays,
      positivity: positivity,
      diaryMonth: diaryMonth,
      albumMonth: albumMonth,
      memoryThisMonth: memoryThisMonth,
      activeDays: activeDays.length,
      diaryTotal: diaryTotal,
      albumTotal: albumTotal,
      suggestion: suggestion,
      shareU1: shareU1,
      shareU2: shareU2,
      offU1: offU1,
      offU2: offU2,
      interactionRate: interactionRate,
      nameU1: nameU1,
      nameU2: nameU2,
      favoriteActivity: favoriteActivity,
      diaryU1: diaryU1,
      diaryU2: diaryU2,
      albumU1: albumU1,
      albumU2: albumU2,
      moodPosU1: moodPosU1,
      moodPosU2: moodPosU2,
      viewU1: viewU1,
      viewU2: viewU2,
      openU1: openU1,
      openU2: openU2,
      loveU1: loveU1,
      loveU2: loveU2,
      timeline: timeline,
    );
  }

  Future<String> _buildSuggestion({
    required bool isSingle,
    required int loveDays,
    required int loveScore,
    required String level,
    required int positivity,
    required int memoryThisMonth,
    required int activeDays,
    required double shareU1,
    required double shareU2,
    required double offU1,
    required double offU2,
    required double daysSinceLastMemory,
    required double balanceRatio,
    required List<LoveInsightTimelineEntry> timeline,
    required DateTime now,
  }) async {
    final milestoneSuggestion = _buildMilestoneSuggestion(
      timeline: timeline,
      now: now,
      isSingle: isSingle,
    );

    if (isSingle) {
      if (memoryThisMonth <= 1 &&
          activeDays <= 2 &&
          milestoneSuggestion != null) {
        return milestoneSuggestion;
      }
      if (daysSinceLastMemory >= 6) {
        return _tr('love_insight_suggest_single_slow_rhythm');
      }
      if (loveScore >= 85) {
        return 'Bạn đang giữ nhịp sống rất ổn và đều. Hãy tiếp tục lưu lại những khoảnh khắc đẹp để hành trình của chính mình ngày càng đáng nhớ hơn.';
      }
      if (positivity >= 75 && memoryThisMonth >= 6) {
        return 'Năng lượng của bạn đang khá sáng và ổn. Giữ nhịp đều thêm vài ngày nữa, chỉ số này sẽ tăng rất nhanh chứ không chỉ đẹp nhất thời.';
      }
      if (loveScore >= 65) {
        return 'Nhịp sống của bạn đang đi đúng hướng. Chỉ cần thêm vài ngày ghi nhật ký hoặc lưu ảnh đều hơn là bảng chỉ số sẽ sáng lên rất nhanh.';
      }
      if (milestoneSuggestion != null) {
        return milestoneSuggestion;
      }
      return _tr('love_insight_suggest_single_need_self_care');
    }
    if (memoryThisMonth <= 1 &&
        activeDays <= 3 &&
        milestoneSuggestion != null) {
      return milestoneSuggestion;
    }
    if (daysSinceLastMemory >= 6) {
      return _tr('love_insight_suggest_couple_sparse_shared_marks');
    }
    if (balanceRatio < 0.45) {
      return 'Một phía đang chủ động nhiều hơn phía còn lại. Chỉ cần người đang yên hơn lên tiếng trước một chút, cảm giác cân bằng sẽ quay lại rất rõ.';
    }
    if (offU1 >= 2 || offU2 >= 2) {
      return 'Có vẻ một trong hai bạn đang vắng nhịp hơn bình thường. Một lời hỏi han ngắn nhưng đúng lúc sẽ hiệu quả hơn rất nhiều so với nhắn cho có.';
    }
    if (loveScore >= 85) {
      return 'Hai bạn đang giữ được nhịp yêu rất đẹp và ổn định. Chỉ cần thêm vài khoảnh khắc nhỏ có chủ đích, tình cảm sẽ còn đậm và sáng hơn nữa.';
    }
    if (loveDays >= 180 && memoryThisMonth >= 8) {
      return 'Nền của hai bạn vẫn tốt, chỉ cần giữ đều chất lượng tương tác trong vài tuần tới là cảm giác gắn bó sẽ tăng lên rất tự nhiên.';
    }
    if (loveScore >= 65) {
      return 'Mối quan hệ đang khá ổn và có nền tảng tốt. Một cuộc trò chuyện chất lượng hoặc một bất ngờ nhỏ đúng lúc sẽ kéo cảm xúc đi lên rất nhanh.';
    }
    if (milestoneSuggestion != null) {
      return milestoneSuggestion;
    }
    return _tr('love_insight_suggest_couple_cool_connection');
  }

  String? _buildMilestoneSuggestion({
    required List<LoveInsightTimelineEntry> timeline,
    required DateTime now,
    required bool isSingle,
  }) {
    if (timeline.isEmpty) {
      return null;
    }

    final today = _startOfDay(now);
    LoveInsightTimelineEntry? nearestUpcoming;
    LoveInsightTimelineEntry? nearestRecentPast;

    for (final entry in timeline) {
      final entryDay = _startOfDay(entry.date);
      if (!entryDay.isBefore(today)) {
        nearestUpcoming ??= entry;
      } else {
        nearestRecentPast ??= entry;
        break;
      }
    }

    if (nearestUpcoming != null) {
      final daysUntil = nearestUpcoming.date.difference(today).inDays;
      if (daysUntil <= 7) {
        if (daysUntil <= 0) {
          return isSingle
              ? 'Hôm nay là một cột mốc đẹp của hành trình này. Ghi lại một khoảnh khắc nhỏ để ngày đặc biệt có dấu ấn riêng nhé.'
              : 'Hôm nay là một cột mốc đẹp của hai bạn. Chỉ cần lưu lại một tấm ảnh hay một lời nhắn ngắn là đủ làm ngày này đáng nhớ hơn.';
        }
        return isSingle
            ? 'Chỉ còn $daysUntil ngày nữa tới "${nearestUpcoming.title}". Giữ nhịp vài ghi chú nhỏ từ bây giờ sẽ giúp cột mốc này ý nghĩa hơn nhiều.'
            : 'Chỉ còn $daysUntil ngày nữa tới "${nearestUpcoming.title}". Hai bạn có thể chuẩn bị một kỷ niệm nhỏ từ bây giờ để cảm xúc đến tự nhiên hơn.';
      }
    }

    if (nearestRecentPast != null) {
      final daysSince =
          today.difference(_startOfDay(nearestRecentPast.date)).inDays;
      if (daysSince <= 7) {
        return isSingle
            ? '"${nearestRecentPast.title}" vừa đi qua. Đây là lúc đẹp để ghi lại cảm xúc còn mới, để hành trình này có thêm chiều sâu.'
            : '"${nearestRecentPast.title}" vừa đi qua. Nếu hai bạn lưu lại một lời nhắn hay một tấm ảnh lúc này, cột mốc đó sẽ ở lại lâu hơn.';
      }
    }

    return null;
  }

  List<LoveInsightTimelineEntry> _buildTimeline({
    required DateTime? startDate,
    required Map<String, dynamic> customEvents,
    required bool isSingle,
    required DateTime now,
  }) {
    final timeline = <LoveInsightTimelineEntry>[];
//     final today = _startOfDay(now);

    if (startDate != null) {
      timeline.addAll(
        buildMilestoneTimeline(
          startDate: startDate,
          isSingle: isSingle,
        ),
      );
    }

    // ... custom events
    customEvents.forEach((key, val) {
      if (val is Map) {
        final dStr = val['date']?.toString() ?? '';
        final tStr = val['title']?.toString() ?? '';
        if (dStr.isNotEmpty && tStr.isNotEmpty) {
          try {
            final dt = DateTime.parse(dStr);
            timeline.add(LoveInsightTimelineEntry(
              date: dt,
              title: tStr,
              type: 'custom',
              subtitle: 'Sự kiện riêng',
            ));
          } catch (_) {}
        }
      }
    });

    timeline.sort((a, b) => b.date.compareTo(a.date));
    return timeline;
  }

  Future<void> checkAndNotifySmartReminders(
    String houseId,
    String relationshipMode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final nowTs = now.millisecondsSinceEpoch;
      final data = await computeInsights(houseId, relationshipMode);
      final settingsSnap = await _dbRef.child('houses/$houseId/settings').get();
      final presenceSnap = await _dbRef.child('houses/$houseId/presence').get();
      final metricsSnap = await _dbRef.child('houses/$houseId/metrics').get();
      final settings = _asMap(settingsSnap.value);
      final presence = _asMap(presenceSnap.value);
      final metrics = _asMap(metricsSnap.value);

      final upcomingDays = _daysUntilUpcomingAnniversary(settings['startDate']);
      if (upcomingDays == 7 &&
          await _tryAcquireReminderGate(
            prefs,
            type: 'upcoming_anniversary_7d',
            nowTs: nowTs,
          )) {
        await PushNotificationHelper.systemEvent(
          toHouseId: houseId,
          type: 'upcoming_anniversary_reminder',
          title: '💞 Sắp tới ngày kỷ niệm rồi',
          content:
              'Còn 7 ngày nữa là tới ngày đặc biệt của hai bạn, chuẩn bị một bất ngờ nhỏ nha.',
        );
        return;
      }

      if ((data.loveScore < 60 || data.interactionRate < 1.0) &&
          await _tryAcquireReminderGate(
            prefs,
            type: 'low_weekly_interaction',
            nowTs: nowTs,
          )) {
        String message = data.suggestion;
        final aiMessage = await AiCounselorService().callTextGeneration(
          'Dữ liệu: Love Score ${data.loveScore}/100, Tỷ lệ tương tác ${data.interactionRate}, Trạng thái: ${data.level}. '
              'Hãy viết 1 câu thông báo push ngắn gọn (dưới 15 từ), ấm áp, tinh tế để nhắc người dùng vào app hâm nóng tình cảm.',
          'Bạn là trợ lý ảo tâm lý SoulLocket. Hãy dùng ngôn ngữ chân thành, trẻ trung, tiếng Việt.',
        );
        if (aiMessage != null && aiMessage.isNotEmpty) {
          message = aiMessage;
        }
        await PushNotificationHelper.systemEvent(
          toHouseId: houseId,
          type: 'ai_interaction_reminder',
          title: 'Gửi một chút yêu thương ❤️',
          content: message,
        );
        return;
      }

      final quietRole = _resolveQuietRole(presence, metrics, now);
      if (quietRole != null &&
          await _tryAcquireReminderGate(
            prefs,
            type: 'long_time_no_checkin_$quietRole',
            nowTs: nowTs,
          )) {
        final name = quietRole == 'user2'
            ? _string(settings['nameU2'], fallback: 'người ấy')
            : _string(settings['nameU1'], fallback: 'người ấy');
        await PushNotificationHelper.systemEvent(
          toHouseId: houseId,
          type: 'long_time_no_checkin',
          title: '🌙 Dạo này hơi vắng nhịp',
          content:
              'Lâu rồi chưa thấy $name ghé app, thử gửi một lời hỏi han dịu dàng nhé.',
        );
      }
    } catch (_) {}
  }

  /// Kiểm tra và tự động gửi thông báo AI nếu điểm tương tác thấp (tối đa 1 lần/ngày)
  Future<void> checkAndNotifyLowInteraction(
    String houseId,
    String relationshipMode,
  ) {
    return checkAndNotifySmartReminders(houseId, relationshipMode);
  }

  Future<bool> _tryAcquireReminderGate(
    SharedPreferences prefs, {
    required String type,
    required int nowTs,
  }) async {
    final key = 'il_smart_reminder_$type';
    final lastTs = prefs.getInt(key) ?? 0;
    if (nowTs - lastTs < 24 * 60 * 60 * 1000) {
      return false;
    }
    await prefs.setInt(key, nowTs);
    return true;
  }

  int? _daysUntilUpcomingAnniversary(dynamic rawStartDate) {
    final startDate = _parseFlexibleDate(_string(rawStartDate));
    if (startDate == null) return null;
    final now = DateTime.now();
    var thisYearDate = DateTime(now.year, startDate.month, startDate.day);
    final today = _startOfDay(now);
    if (thisYearDate.isBefore(today)) {
      thisYearDate = DateTime(now.year + 1, startDate.month, startDate.day);
    }
    return thisYearDate.difference(today).inDays;
  }

  String? _resolveQuietRole(
    Map<String, dynamic> presence,
    Map<String, dynamic> metrics,
    DateTime now,
  ) {
    for (final role in const ['user1', 'user2']) {
      final presenceInfo = _asMap(presence[role]);
      final offlineDays = _calcOfflineDays(presenceInfo, now);
      final lastActiveByRole = _asMap(metrics['last_active_at']);
      final lastActiveTs = _toInt(lastActiveByRole[role]);
      final inactiveDays = _daysSinceTimestamp(lastActiveTs, now);
      if (offlineDays >= 2 || inactiveDays >= 3) {
        return role;
      }
    }
    return null;
  }

  LoveInsightTimelineEntry? nextMilestone({
    required DateTime startDate,
    required bool isSingle,
    DateTime? from,
  }) {
    final today = _startOfDay(from ?? DateTime.now());
    for (final entry
        in buildMilestoneTimeline(startDate: startDate, isSingle: isSingle)) {
      if (!entry.date.isBefore(today)) {
        return entry;
      }
    }
    return null;
  }

  List<LoveInsightTimelineEntry> buildMilestoneTimeline({
    required DateTime startDate,
    required bool isSingle,
  }) {
    final anchor = _startOfDay(startDate);
    final subtitle = isSingle ? 'Cột mốc hành trình' : 'Cột mốc quan trọng';
    final entries = <LoveInsightTimelineEntry>[];

    final now = DateTime.now();
    final limitDate = now.add(const Duration(days: 365));
    final pastDate = now.subtract(const Duration(days: 365 * 100));

    for (final months in _monthMilestones) {
      final d = _addMonthsClamped(anchor, months);
      if (d.isAfter(limitDate) || d.isBefore(pastDate)) continue;
      entries.add(
        LoveInsightTimelineEntry(
          date: d,
          title: _monthMilestoneTitle(months, isSingle: isSingle),
          type: 'milestone',
          subtitle: subtitle,
        ),
      );
    }

    for (final days in _dayMilestones) {
      final d = anchor.add(Duration(days: days));
      if (d.isAfter(limitDate) || d.isBefore(pastDate)) continue;
      entries.add(
        LoveInsightTimelineEntry(
          date: d,
          title: _dayMilestoneTitle(days, isSingle: isSingle),
          type: 'milestone',
          subtitle: subtitle,
        ),
      );
    }

    for (var years = 1; years <= _maxYearMilestone; years++) {
      final d = _addYearsClamped(anchor, years);
      if (d.isAfter(limitDate) || d.isBefore(pastDate)) continue;
      entries.add(
        LoveInsightTimelineEntry(
          date: d,
          title: _yearMilestoneTitle(years, isSingle: isSingle),
          type: 'milestone',
          subtitle: subtitle,
        ),
      );
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  String _resolveOwner(
    Map<String, dynamic> item,
    String nameU1,
    String nameU2,
  ) {
    final role = _string(item['role']).toLowerCase();
    if (role == 'user1' || role == 'user2') {
      return role;
    }

    final author = _string(item['a']);
    if (author.isNotEmpty && author == nameU1) {
      return 'user1';
    }
    if (author.isNotEmpty && author == nameU2) {
      return 'user2';
    }

    return '';
  }

  int _toTimestamp(Map<String, dynamic> item) {
    final rawTs = item['ts'];
    if (rawTs is int) {
      return rawTs;
    }
    if (rawTs is num) {
      return rawTs.toInt();
    }
    if (rawTs != null) {
      final parsed = int.tryParse(rawTs.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    final raw = _string(item['time']).isNotEmpty
        ? _string(item['time'])
        : _string(item['date']);
    final date = _parseFlexibleDate(raw);
    return date?.millisecondsSinceEpoch ?? 0;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }
    return value.map(
      (key, data) => MapEntry(key.toString(), data),
    );
  }

  Map<String, int> _intMap(Object? value) {
    final map = _asMap(value);
    return map.map((key, data) => MapEntry(key, _toInt(data)));
  }



  String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _calcOfflineDays(Map<String, dynamic> info, DateTime now) {
    final status = _string(info['status']).toLowerCase();
    if (status == 'online') {
      return 0;
    }

    final lastSeen = _toInt(info['lastSeen']) > 0
        ? _toInt(info['lastSeen'])
        : _toInt(info['lastOnline']);
    if (lastSeen <= 0) {
      return 0;
    }
    return max(
      0,
      now.difference(DateTime.fromMillisecondsSinceEpoch(lastSeen)).inMinutes /
          (60 * 24),
    );
  }

  double _daysSinceTimestamp(int timestamp, DateTime now) {
    if (timestamp <= 0) {
      return 999;
    }
    return max(
      0,
      now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp)).inMinutes /
          (60 * 24),
    );
  }

  double _freshnessBoost(double daysSince, {required double maxBoost}) {
    if (daysSince <= 1) return maxBoost;
    if (daysSince <= 3) return maxBoost * 0.78;
    if (daysSince <= 7) return maxBoost * 0.48;
    if (daysSince <= 14) return maxBoost * 0.2;
    return 0;
  }

  double _stalePenalty(
    double daysSince, {
    required double startAfter,
    required double step,
    required double maxPenalty,
  }) {
    if (daysSince <= startAfter) {
      return 0;
    }
    return min(maxPenalty, (daysSince - startAfter) * step);
  }

  int _personalLoveScore({
    required int baseLoveScore,
    required double effort,
    required int recentActiveDays,
    required int positivity,
    required double attention,
    required double daysSinceTouch,
    required double offlineDays,
    required bool isSingle,
  }) {
    final effortScore = min(18.0, (effort / (isSingle ? 12 : 14)) * 18);
    final rhythmScore = min(12.0, (recentActiveDays / 10) * 12);
    final moodScore = min(7.0, (positivity / 100) * 7);
    final attentionScore = min(8.0, (attention / 8) * 8);
    final freshnessScore = _freshnessBoost(daysSinceTouch, maxBoost: 6.0);
    final quietPenalty = _stalePenalty(
      daysSinceTouch,
      startAfter: isSingle ? 6.0 : 4.0,
      step: isSingle ? 0.9 : 1.1,
      maxPenalty: 14.0,
    );
    final offlinePenalty =
        offlineDays > 1 ? min(10.0, (offlineDays - 1) * 1.4) : 0.0;

    final score = (8 +
            (baseLoveScore * 0.54) +
            effortScore +
            rhythmScore +
            moodScore +
            attentionScore +
            freshnessScore -
            quietPenalty -
            offlinePenalty)
        .round();

    return max(isSingle ? 42 : 28, min(99, score));
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _addMonthsClamped(DateTime date, int months) {
    final zeroBasedMonth = date.month - 1 + months;
    final year = date.year + zeroBasedMonth ~/ 12;
    final month = zeroBasedMonth % 12 + 1;
    final day = min(date.day, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, day);
  }

  DateTime _addYearsClamped(DateTime date, int years) {
    final year = date.year + years;
    final day = min(date.day, DateTime(year, date.month + 1, 0).day);
    return DateTime(year, date.month, day);
  }

  String _monthMilestoneTitle(int months, {required bool isSingle}) {
    if (isSingle) {
      if (months == 1) return 'Tròn 1 tháng đồng hành';
      if (months == 6) return 'Tròn 6 tháng trưởng thành';
      return 'Tròn $months tháng đồng hành';
    }
    if (months == 1) return 'Tròn 1 tháng bên nhau';
    if (months == 6) return 'Tròn 6 tháng bên nhau';
    return 'Tròn $months tháng bên nhau';
  }

  String _dayMilestoneTitle(int days, {required bool isSingle}) {
    if (isSingle) {
      return 'Cột mốc $days ngày trải nghiệm';
    }
    return 'Kỷ niệm $days ngày yêu';
  }

  String _yearMilestoneTitle(int years, {required bool isSingle}) {
    if (isSingle) {
      return 'Cột mốc $years năm dùng app';
    }
    return 'Kỷ niệm $years năm';
  }

  DateTime? _parseFlexibleDate(String raw) {
    if (raw.isEmpty) {
      return null;
    }

    final direct = DateTime.tryParse(raw);
    if (direct != null) {
      return direct;
    }

    final ddmmyyyy = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})');
    final ddmmyyyyMatch = ddmmyyyy.firstMatch(raw);
    if (ddmmyyyyMatch != null) {
      return DateTime(
        int.parse(ddmmyyyyMatch.group(3)!),
        int.parse(ddmmyyyyMatch.group(2)!),
        int.parse(ddmmyyyyMatch.group(1)!),
      );
    }

    final yyyymmdd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
    final yyyymmddMatch = yyyymmdd.firstMatch(raw);
    if (yyyymmddMatch != null) {
      return DateTime(
        int.parse(yyyymmddMatch.group(1)!),
        int.parse(yyyymmddMatch.group(2)!),
        int.parse(yyyymmddMatch.group(3)!),
      );
    }

    return null;
  }
}
