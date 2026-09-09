import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'house_service.dart';

class SingleMatchService {
  SingleMatchService._();

  static final SingleMatchService instance = SingleMatchService._();
  static const String _profileIndexRoot = 'single_match_profiles';
  static const String _activePoolRoot = 'single_match_active_pool';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final HouseService _houseService = HouseService();
  final Random _random = Random();

  final Map<String, String> _secretMatchIds = <String, String>{};

  static String profileIndexPath(String houseId) =>
      '$_profileIndexRoot/$houseId';

  static Map<String, dynamic> profileIndexUpdates({
    required String houseId,
    String? displayName,
    String? houseName,
    String? avatarUrl,
    String? bio,
    String? dobU1,
    String? relationshipMode,
    String? privacy,
    bool? searchPrivacy,
    Map<String, dynamic>? singleMatch,
    Object? updatedAt,
  }) {
    final path = profileIndexPath(houseId);
    final updates = <String, dynamic>{};
    if (displayName != null) updates['$path/displayName'] = displayName;
    if (houseName != null) updates['$path/houseName'] = houseName;
    if (avatarUrl != null) updates['$path/avatarUrl'] = avatarUrl;
    if (bio != null) updates['$path/bio'] = bio;
    if (dobU1 != null) updates['$path/dobU1'] = dobU1;
    if (relationshipMode != null) {
      updates['$path/relationshipMode'] = relationshipMode;
    }
    if (privacy != null) updates['$path/privacy'] = privacy;
    if (searchPrivacy != null) updates['$path/searchPrivacy'] = searchPrivacy;
    if (singleMatch != null) updates['$path/singleMatch'] = singleMatch;
    if (updatedAt != null) updates['$path/updatedAt'] = updatedAt;
    return updates;
  }

  Future<String?> getCurrentHouseId() => _houseService.getCurrentHouseId();

  Future<Map<String, dynamic>> fetchHouseSettings(String houseId) async {
    final settings = await _houseService.getHouseSettings(houseId);
    return settings ?? <String, dynamic>{};
  }

  Future<SingleMatchPreferences> loadPreferences(String houseId) async {
    final snap = await _db.child('houses/$houseId/settings/singleMatch').get();
    if (!snap.exists || snap.value is! Map) {
      return const SingleMatchPreferences();
    }
    return SingleMatchPreferences.fromMap(snap.value as Map);
  }

  /// Server lọc quyền riêng tư và danh sách chặn trước khi trả hồ sơ hiển thị.
  Stream<List<SingleMatchCandidate>> streamCandidates({
    required String currentHouseId,
  }) async* {
    yield const <SingleMatchCandidate>[];
    final profiles = await _fetchVisibleProfiles();
    final candidates = <SingleMatchCandidate>[];
    for (final entry in profiles.entries) {
      final candidate = _candidateFromProfile(
        entry.key,
        entry.value,
        currentHouseId: currentHouseId,
      );
      if (candidate != null) candidates.add(candidate);
    }
    yield _sortCandidates(candidates);
  }

  Future<Set<String>> fetchBlockedHouseIds(String houseId) async {
    final snap = await _db.child('houses/$houseId/blocked_users').get();
    if (!snap.exists || snap.value is! Map) {
      return <String>{};
    }

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final blocked = <String>{};
    for (final entry in raw.entries) {
      if (entry.value == true) {
        blocked.add(entry.key.toString().trim());
      }
    }
    return blocked;
  }

  Future<void> savePreferences({
    required String houseId,
    required SingleMatchPreferences preferences,
    String displayName = '',
    String avatarUrl = '',
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final baseMap = preferences.copyWith(updatedAt: nowMs).toMap();

    final updates = <String, dynamic>{
      'houses/$houseId/settings/singleMatch': baseMap,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...profileIndexUpdates(
        houseId: houseId,
        singleMatch: baseMap,
        updatedAt: nowMs,
      ),
    };

    // Pool chỉ là chỉ mục tìm kiếm; hồ sơ được server đọc theo quyền hiện tại.
    if (preferences.enabled) {
      updates['$_activePoolRoot/$houseId'] = {'updatedAt': nowMs};
    } else {
      updates['$_activePoolRoot/$houseId'] = null; // delete
    }

    await _db.update(updates);
  }

  Future<void> updateOwnDob({
    required String houseId,
    required String isoDob,
    String? avatarUrl,
    String? displayName,
  }) async {
    final normalized = isoDob.trim();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'houses/$houseId/settings/dobU1': normalized,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      // Xóa bản sao ngày sinh cũ; không nhân đôi dữ liệu riêng vào pool.
      '$_activePoolRoot/$houseId/dobU1': null,
      ...profileIndexUpdates(
        houseId: houseId,
        dobU1: normalized,
        updatedAt: nowMs,
      ),
    };

    await _db.update(updates);
  }

  Stream<List<SingleMatchHistoryEntry>> streamHistory(String houseId) {
    late final StreamController<List<SingleMatchHistoryEntry>> controller;
    StreamSubscription<DatabaseEvent>? historySub;

    controller = StreamController<List<SingleMatchHistoryEntry>>(
      onListen: () {
        controller.add(const <SingleMatchHistoryEntry>[]);
        historySub = _db
            .child('houses/$houseId/singleMatch/history')
            .orderByKey()
            .limitToLast(50)
            .onValue
            .listen(
              (event) {
                if (!event.snapshot.exists || event.snapshot.value is! Map) {
                  controller.add(const <SingleMatchHistoryEntry>[]);
                  return;
                }

                final raw = Map<dynamic, dynamic>.from(
                  event.snapshot.value as Map,
                );
                final entries = <SingleMatchHistoryEntry>[];
                raw.forEach((key, value) {
                  if (value is! Map) {
                    return;
                  }
                  entries.add(
                    SingleMatchHistoryEntry.fromMap(
                      key.toString(),
                      Map<dynamic, dynamic>.from(value),
                    ),
                  );
                });
                entries.sort(
                  (left, right) => right.startedAt.compareTo(left.startedAt),
                );
                controller.add(entries);
              },
              onError: (Object error) {
                debugPrint(
                  '[SingleMatch] history stream failed: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('err_single_match_history_stream_failed')).message}',
                );
                if (!controller.isClosed) {
                  controller.add(const <SingleMatchHistoryEntry>[]);
                }
              },
            );
      },
      onCancel: () async {
        await historySub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> logHistory({
    required String houseId,
    required String action,
    required String peerHouseId,
    required String peerName,
    required String peerAvatarUrl,
    required String goal,
    required int startedAt,
    required int endedAt,
    required int durationSeconds,
    required double compatibilityScore,
    String note = '',
  }) async {
    await _db.child('houses/$houseId/singleMatch/history').push().set({
      'action': action,
      'peerHouseId': peerHouseId,
      'peerName': peerName,
      'peerAvatarUrl': peerAvatarUrl,
      'goal': goal,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'durationSeconds': durationSeconds,
      'compatibilityScore': compatibilityScore,
      'note': note,
    });
  }

  Future<void> attachOutgoingCallMetadata({
    required String roomId,
    required String callerHouseId,
    required String targetHouseId,
    required String callerName,
    required String callerAvatar,
    required bool isVideo,
    required String source,
  }) async {
    await _db.child('calls/$roomId').update({
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideo': isVideo,
      'houseId': callerHouseId,
      'calleeId': targetHouseId,
      'source': source,
      'updatedAt': ServerValue.timestamp,
    });
  }

  // ===== Age helpers =====

  int? ageFromDob(String rawDob) {
    final parsed = DateTime.tryParse(rawDob.trim());
    if (parsed == null) {
      return null;
    }
    final now = DateTime.now();
    var age = now.year - parsed.year;
    final hadBirthday =
        now.month > parsed.month ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hadBirthday) {
      age -= 1;
    }
    if (age < 0 || age > 120) {
      return null;
    }
    return age;
  }

  // ===== Internal helpers =====

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  /// Không tải index riêng tư hoặc giữ cache dùng chung qua các tài khoản.
  Future<Map<String, Map<dynamic, dynamic>>> _fetchVisibleProfiles() async {
    final requestUid = _houseService.currentUser?.uid;
    if (requestUid == null) {
      throw Exception(L10nService().translate('core_err_general'));
    }
    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'listSingleMatchCandidates',
      fallbackErrorMessage: L10nService().translate('core_err_general'),
    );
    if (_houseService.currentUser?.uid != requestUid) {
      throw Exception(L10nService().translate('core_err_general'));
    }
    final data = response.data;
    if (data is! Map || data['candidates'] is! List) {
      throw Exception(L10nService().translate('core_err_general'));
    }
    final profiles = <String, Map<dynamic, dynamic>>{};
    for (final value in data['candidates'] as List) {
      if (value is! Map) continue;
      final houseId = value['houseId']?.toString().trim() ?? '';
      if (houseId.isEmpty) continue;
      profiles[houseId] = <dynamic, dynamic>{
        ...Map<dynamic, dynamic>.from(value),
        'singleMatch': Map<dynamic, dynamic>.from(value),
      };
    }
    return profiles;
  }

  SingleMatchCandidate? _candidateFromProfile(
    String houseId,
    Map<dynamic, dynamic> profile, {
    required String currentHouseId,
  }) {
    if (houseId.isEmpty || houseId == currentHouseId) {
      return null;
    }

    final settings = profile['settings'] is Map
        ? Map<dynamic, dynamic>.from(profile['settings'] as Map)
        : <dynamic, dynamic>{};
    final singleMatch = profile['singleMatch'] is Map
        ? Map<dynamic, dynamic>.from(profile['singleMatch'] as Map)
        : (settings['singleMatch'] is Map
              ? Map<dynamic, dynamic>.from(settings['singleMatch'] as Map)
              : <dynamic, dynamic>{});

    final relationshipMode =
        (profile['relationshipMode'] ?? settings['relationshipMode'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (relationshipMode != 'single') {
      return null;
    }

    final privacy = (profile['privacy'] ?? settings['privacy'] ?? 'public')
        .toString()
        .trim()
        .toLowerCase();
    final searchPrivacy = _readBool(
      profile.containsKey('searchPrivacy')
          ? profile['searchPrivacy']
          : settings['searchPrivacy'],
      fallback: true,
    );
    if (privacy != 'public' || !searchPrivacy) {
      return null;
    }

    final prefs = SingleMatchPreferences.fromMap(singleMatch);
    if (!prefs.enabled) return null;
    final avatarUrl =
        (profile['avatarUrl'] ??
                profile['houseAvatar'] ??
                settings['houseAvatar'] ??
                profile['avatar'] ??
                '')
            .toString()
            .trim();
    final displayName =
        (profile['displayName'] ??
                profile['nameU1'] ??
                settings['nameU1'] ??
                profile['houseName'] ??
                settings['houseName'] ??
                '')
            .toString()
            .trim();
    final houseName = (profile['houseName'] ?? settings['houseName'] ?? '')
        .toString()
        .trim();
    final bio = (profile['bio'] ?? settings['bio'] ?? '').toString().trim();
    final updatedAt = _readInt(
      profile['updatedAt'] ??
          profile['updated_at'] ??
          settings['updatedAt'] ??
          singleMatch['updatedAt'],
    );
    final age = (profile['age'] as num?)?.toInt();

    return SingleMatchCandidate(
      houseId: houseId,
      displayName: displayName.isEmpty ? houseName : displayName,
      houseName: houseName,
      avatarUrl: avatarUrl,
      bio: bio,
      intro: prefs.intro,
      goal: prefs.goal,
      voiceStyle: prefs.voiceStyle,
      tags: prefs.tags,
      allowAudioCalls: prefs.allowAudioCalls,
      allowVideoCalls: prefs.allowVideoCalls,
      enabled: prefs.enabled,
      privacy: privacy,
      updatedAt: updatedAt,
      age: age,
    );
  }

  List<SingleMatchCandidate> _sortCandidates(
    List<SingleMatchCandidate> candidates,
  ) {
    candidates.sort((left, right) {
      final updated = right.updatedAt.compareTo(left.updatedAt);
      if (updated != 0) {
        return updated;
      }
      return left.displayName.compareTo(right.displayName);
    });
    return candidates;
  }

  // ===== Secret Code =====

  Future<String?> pairWithSecretCode({
    required String secretCode,
    required String myHouseId,
  }) async {
    final normalizedCode = secretCode.trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '',
    );
    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'pairSingleMatchSecretCode',
      payload: <String, dynamic>{'secretCode': normalizedCode},
      fallbackErrorMessage: L10nService().translate('core_err_general'),
    );
    final raw = response.data;
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    final matchId = data['matchId']?.toString().trim() ?? '';
    if (matchId.isNotEmpty) {
      _secretMatchIds[normalizedCode] = matchId;
    }
    final peerHouseId = data['peerHouseId']?.toString().trim() ?? '';
    return peerHouseId.isEmpty ? null : peerHouseId;
  }

  Stream<String?> watchSecretCodeMatch(String secretCode) {
    final normalizedCode = secretCode.trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '',
    );
    final matchId = _secretMatchIds[normalizedCode] ?? '';
    final user = _houseService.currentUser;
    if (matchId.isEmpty || user == null) {
      return Stream<String?>.value(null);
    }
    return _db
        .child(
          'single_match_secure/match_views/${user.uid}/$matchId/peerHouseId',
        )
        .onValue
        .map((event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            return event.snapshot.value.toString();
          }
          return null;
        });
  }

  // ===== Chat Room =====

  Future<String> getOrCreateMatchChatRoom({
    required String myHouseId,
    required String peerHouseId,
    required String peerName,
    required String peerAvatarUrl,
  }) async {
    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'createSingleMatchChatMapping',
      payload: <String, dynamic>{'peerHouseId': peerHouseId},
      fallbackErrorMessage: L10nService().translate('core_err_general'),
    );
    final raw = response.data;
    if (raw is! Map) {
      throw Exception(L10nService().translate('core_err_general'));
    }
    final data = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    final roomId = data['roomId']?.toString().trim() ?? '';
    if (roomId.isEmpty) {
      throw Exception(L10nService().translate('core_err_general'));
    }
    return roomId;
  }

  Stream<List<Map<String, dynamic>>> streamChatMappings(String houseId) {
    return _db.child('single_match_secure/chat_mappings/$houseId').onValue.map((
      event,
    ) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return const <Map<String, dynamic>>[];
      }
      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];
      raw.forEach((peerId, data) {
        if (data is! Map) return;
        final map = Map<String, dynamic>.from(data);
        map['peerHouseId'] = peerId.toString();
        list.add(map);
      });
      list.sort((a, b) {
        final at = (a['createdAt'] as num?)?.toInt() ?? 0;
        final bt = (b['createdAt'] as num?)?.toInt() ?? 0;
        return bt.compareTo(at);
      });
      return list;
    });
  }

  // ===== Scored Random Match =====

  /// Chấm điểm trên danh sách đã được server lọc quyền riêng tư.
  Future<SingleMatchCandidate?> pickScoredMatch({
    required String currentHouseId,
    required Set<String> excludeHouseIds,
    required String goal,
    required String voiceStyle,
    required List<String> myTags,
    int? myAge,
    int preferredAgeMin = 18,
    int preferredAgeMax = 60,
    bool needAudio = false,
    bool needVideo = false,
  }) async {
    final pool = await _fetchVisibleProfiles();
    final scored = _scorePool(
      pool,
      currentHouseId,
      excludeHouseIds,
      goal,
      voiceStyle,
      myTags,
      myAge,
      preferredAgeMin,
      preferredAgeMax,
      needAudio,
      needVideo,
    );

    if (scored.isEmpty) return null;

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Random từ top-N
    // Nếu pool < 20 → top 3
    // Pool 20-100 → top 20%
    // Tối đa 5
    final topN = () {
      if (scored.length < 3) return scored.length;
      if (scored.length < 20) return 3;
      return (scored.length ~/ 5).clamp(3, 5);
    }();

    final picked = scored[_random.nextInt(topN)];

    final rawEntry = pool[picked.houseId];
    if (rawEntry is! Map) return null;

    final prefs = SingleMatchPreferences.fromMap(rawEntry);
    final peerName = (rawEntry['displayName'] ?? '').toString().trim();
    return SingleMatchCandidate(
      houseId: picked.houseId,
      displayName: peerName,
      houseName: peerName,
      avatarUrl: (rawEntry['avatarUrl'] ?? '').toString().trim(),
      bio: (rawEntry['bio'] ?? '').toString().trim(),
      intro: prefs.intro,
      goal: prefs.goal,
      voiceStyle: prefs.voiceStyle,
      tags: prefs.tags,
      allowAudioCalls: prefs.allowAudioCalls,
      allowVideoCalls: prefs.allowVideoCalls,
      enabled: true,
      privacy: 'public',
      updatedAt: prefs.updatedAt,
      age: (rawEntry['age'] as num?)?.toInt(),
    );
  }

  List<_PoolEntry> _scorePool(
    Map<String, Map<dynamic, dynamic>> pool,
    String currentHouseId,
    Set<String> excludeHouseIds,
    String goal,
    String voiceStyle,
    List<String> myTags,
    int? myAge,
    int preferredAgeMin,
    int preferredAgeMax,
    bool needAudio,
    bool needVideo,
  ) {
    final myTagSet = myTags.map((t) => t.toLowerCase()).toSet();
    final scored = <_PoolEntry>[];

    for (final entry in pool.entries) {
      final hid = entry.key;
      if (hid == currentHouseId || excludeHouseIds.contains(hid)) continue;
      final data = entry.value;

      final peerEnabled = _readBool(data['enabled'], fallback: false);
      if (!peerEnabled) continue;

      final peerAudio = _readBool(data['allowAudioCalls'], fallback: true);
      final peerVideo = _readBool(data['allowVideoCalls'], fallback: true);
      if (!peerAudio && !peerVideo) continue;
      if (needAudio && !peerAudio) continue;
      if (needVideo && !peerVideo) continue;

      // Scoring nhanh
      var score = 50.0;

      // Goal match (+14)
      if ((data['goal'] as String?)?.trim() == goal) score += 14;

      // Voice match (+10)
      if ((data['voiceStyle'] as String?)?.trim() == voiceStyle) score += 10;

      // Tag match (+6 mỗi tag, tối đa +18)
      final peerTags = data['tags'];
      if (peerTags is List) {
        final sharedCount = peerTags
            .map((t) => t.toString().trim().toLowerCase())
            .where((t) => t.isNotEmpty && myTagSet.contains(t))
            .length;
        score += (sharedCount * 6).clamp(0, 18);
      }

      // Profile hoàn chỉnh
      final name = (data['displayName'] ?? '').toString().trim();
      final avatar = (data['avatarUrl'] ?? '').toString().trim();
      final bio = (data['bio'] ?? '').toString().trim();
      if (name.isNotEmpty) score += 5;
      if (avatar.isNotEmpty) score += 4;
      if (bio.isNotEmpty) score += 7;

      // Age
      final peerAge = (data['age'] as num?)?.toInt();
      if (peerAge != null && myAge != null) {
        if (peerAge >= preferredAgeMin && peerAge <= preferredAgeMax) {
          score += 12;
        } else {
          final gap = peerAge < preferredAgeMin
              ? preferredAgeMin - peerAge
              : peerAge - preferredAgeMax;
          score += (18 - gap * 2).clamp(0, 12);
        }
        final ageGap = (myAge - peerAge).abs();
        score += (10 - ageGap).clamp(0, 10);
      }

      // Gần đây
      final updatedAt = _readInt(data['updatedAt']);
      if (updatedAt > 0) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - updatedAt;
        if (ageMs < const Duration(days: 3).inMilliseconds) {
          score += 6;
        } else if (ageMs < const Duration(days: 14).inMilliseconds) {
          score += 3;
        }
      }

      scored.add(_PoolEntry(hid, score.clamp(24, 98)));
    }

    return scored;
  }
}

/// Internal score entry
class _PoolEntry {
  final String houseId;
  final double score;
  const _PoolEntry(this.houseId, this.score);
}
