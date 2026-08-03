import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'house_service.dart';

class SingleMatchService {
  SingleMatchService._();

  static final SingleMatchService instance = SingleMatchService._();
  static const String _profileIndexRoot = 'single_match_profiles';
  static const String _activePoolRoot = 'single_match_active_pool';
  static const Duration _profileIndexCacheTtl = Duration(minutes: 30);
  static const Duration _poolCacheTtl = Duration(minutes: 15);
  static const int _batchSize = 100; // ignore: unused_field

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final HouseService _houseService = HouseService();
  final Random _random = Random();

  // Cache profile index để tránh listen realtime liên tục
  Map<String, Map<dynamic, dynamic>>? _profileIndexCache;
  DateTime? _profileIndexCachedAt;

  // Cache active pool (chỉ user đang bật single match)
  Map<String, Map<dynamic, dynamic>>? _activePoolCache;
  DateTime? _activePoolCachedAt;

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
    // Return empty map to prevent permission-denied due to missing rules
    return <String, dynamic>{};
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

  /// Legacy: stream toàn bộ candidates từ profile index.
  /// Dùng cho tab Ghép đôi (cần UI scoring chi tiết).
  /// Cache 30 phút. Với 10k users, active pool ~2-3k, fit ~400KB.
  Stream<List<SingleMatchCandidate>> streamCandidates({
    required String currentHouseId,
  }) {
    late final StreamController<List<SingleMatchCandidate>> controller;
    var indexedProfiles = <String, Map<dynamic, dynamic>>{};
    var fallbackProfiles = <String, Map<dynamic, dynamic>>{};

    void emitMergedCandidates() {
      if (controller.isClosed) {
        return;
      }

      final allHouseIds = <String>{
        ...fallbackProfiles.keys,
        ...indexedProfiles.keys,
      };
      final candidates = <SingleMatchCandidate>[];

      for (final houseId in allHouseIds) {
        final mergedProfile = _mergeProfileMaps(
          fallbackProfiles[houseId],
          indexedProfiles[houseId],
        );
        final candidate = _candidateFromProfile(
          houseId,
          mergedProfile,
          currentHouseId: currentHouseId,
        );
        if (candidate != null) {
          candidates.add(candidate);
        }
      }

      controller.add(_sortCandidates(candidates));
    }

    controller = StreamController<List<SingleMatchCandidate>>(
      onListen: () {
        controller.add(const <SingleMatchCandidate>[]);
        // Dùng cache thay vì listen realtime toàn bộ single_match_profiles
        unawaited(_fetchProfileIndexWithCache().then((profiles) {
          if (!controller.isClosed) {
            indexedProfiles = profiles;
            emitMergedCandidates();
          }
        }).catchError((Object error) {
          debugPrint(
              '[SingleMatch] profile index fetch failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: L10nService()
                .translate('err_single_match_profile_index_stream_failed'),
          ).message}');
          emitMergedCandidates();
        }));
      },
    );

    return controller.stream;
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
    final baseMap = preferences
        .copyWith(
          updatedAt: nowMs,
        )
        .toMap();

    final updates = <String, dynamic>{
      'houses/$houseId/settings/singleMatch': baseMap,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...profileIndexUpdates(
        houseId: houseId,
        singleMatch: baseMap,
        updatedAt: nowMs,
      ),
    };

    // Active pool: chỉ lưu khi enabled
    if (preferences.enabled) {
      updates['$_activePoolRoot/$houseId'] = {
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'goal': preferences.goal,
        'voiceStyle': preferences.voiceStyle,
        'tags': preferences.tags,
        'intro': preferences.intro,
        'allowAudioCalls': preferences.allowAudioCalls,
        'allowVideoCalls': preferences.allowVideoCalls,
        'updatedAt': nowMs,
      };
    } else {
      updates['$_activePoolRoot/$houseId'] = null; // delete
    }

    await _db.update(updates);

    // Clear cache để lần fetch sau lấy mới
    _activePoolCache = null;
    _activePoolCachedAt = null;
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
      ...profileIndexUpdates(
        houseId: houseId,
        dobU1: normalized,
        updatedAt: nowMs,
      ),
    };

    // Update active pool nếu entry tồn tại
    final activeEntry = await _db.child('$_activePoolRoot/$houseId').get();
    if (activeEntry.exists) {
      updates['$_activePoolRoot/$houseId/dobU1'] = normalized;
    }

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

            final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
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
                (left, right) => right.startedAt.compareTo(left.startedAt));
            controller.add(entries);
          },
          onError: (Object error) {
            debugPrint(
                '[SingleMatch] history stream failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: L10nService()
                  .translate('err_single_match_history_stream_failed'),
            ).message}');
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
    final hadBirthday = now.month > parsed.month ||
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

  // ===== Active Pool =====

  /// Fetch active pool (cached 15 phút).
  /// Chỉ chứa user đang bật single match — nhỏ hơn nhiều so với profile index.
  Future<Map<String, Map<dynamic, dynamic>>> _fetchActivePoolWithCache(
      {bool forceFetch = false}) async {
    final now = DateTime.now();
    if (!forceFetch &&
        _activePoolCache != null &&
        _activePoolCachedAt != null &&
        now.difference(_activePoolCachedAt!) < _poolCacheTtl) {
      return _activePoolCache!;
    }
    final snap = await _db.child(_activePoolRoot).get();
    final result = _readProfileMap(snap.value);
    _activePoolCache = result;
    _activePoolCachedAt = now;
    return result;
  }

  // ===== Profile Index (legacy) =====

  Future<Map<String, Map<dynamic, dynamic>>>
      _fetchProfileIndexWithCache() async {
    final now = DateTime.now();
    if (_profileIndexCache != null &&
        _profileIndexCachedAt != null &&
        now.difference(_profileIndexCachedAt!) < _profileIndexCacheTtl) {
      return _profileIndexCache!;
    }
    final snap = await _db.child(_profileIndexRoot).get();
    final result = _readProfileMap(snap.value);
    _profileIndexCache = result;
    _profileIndexCachedAt = now;
    return result;
  }

  Map<String, Map<dynamic, dynamic>> _readProfileMap(Object? rawValue) {
    if (rawValue is! Map) {
      return const <String, Map<dynamic, dynamic>>{};
    }

    final profiles = <String, Map<dynamic, dynamic>>{};
    final rawProfiles = Map<dynamic, dynamic>.from(rawValue);
    rawProfiles.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      final houseId = key.toString().trim();
      if (houseId.isEmpty) {
        return;
      }
      profiles[houseId] = Map<dynamic, dynamic>.from(value);
    });
    return profiles;
  }

  Map<dynamic, dynamic> _mergeProfileMaps(
    Map<dynamic, dynamic>? base,
    Map<dynamic, dynamic>? overlay,
  ) {
    final merged = <dynamic, dynamic>{};
    if (base != null) {
      merged.addAll(base);
    }
    if (overlay == null) {
      return merged;
    }

    overlay.forEach((key, value) {
      final current = merged[key];
      if (current is Map && value is Map) {
        merged[key] = _mergeProfileMaps(
          Map<dynamic, dynamic>.from(current),
          Map<dynamic, dynamic>.from(value),
        );
        return;
      }
      merged[key] = value;
    });
    return merged;
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
    final avatarUrl = (profile['avatarUrl'] ??
            profile['houseAvatar'] ??
            settings['houseAvatar'] ??
            profile['avatar'] ??
            '')
        .toString()
        .trim();
    final displayName = (profile['displayName'] ??
            profile['nameU1'] ??
            settings['nameU1'] ??
            profile['houseName'] ??
            settings['houseName'] ??
            '')
        .toString()
        .trim();
    final houseName =
        (profile['houseName'] ?? settings['houseName'] ?? '').toString().trim();
    final bio = (profile['bio'] ?? settings['bio'] ?? '').toString().trim();
    final updatedAt = _readInt(
      profile['updatedAt'] ??
          profile['updated_at'] ??
          settings['updatedAt'] ??
          singleMatch['updatedAt'],
    );
    final age = ageFromDob(
      (profile['dobU1'] ?? settings['dobU1'] ?? '').toString(),
    );

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
    final codeRef = _db.child('single_match_secret_codes').child(secretCode);
    final snapshot = await codeRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      await codeRef.set({
        'creatorHouseId': myHouseId,
        'createdAt': ServerValue.timestamp,
      });
      return null;
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final creatorHouseId = data['creatorHouseId']?.toString();
    final chatRoomId = data['chatRoomId']?.toString();

    if (creatorHouseId == myHouseId) {
      return null;
    }

    if (chatRoomId != null && chatRoomId.isNotEmpty) {
      if (data['joinedHouseId'] == myHouseId) return chatRoomId;
      throw Exception(L10nService().translate('core_err_general'));
    }

    final newRoomId = _db.child('chat_rooms').push().key!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await _db.child('chat_rooms').child(newRoomId).set({
      'type': 'single_match_secret',
      'createdAt': nowMs,
      'members': {
        creatorHouseId: true,
        myHouseId: true,
      },
      'status': 'active',
    });

    await codeRef.update({
      'joinedHouseId': myHouseId,
      'chatRoomId': newRoomId,
    });

    return newRoomId;
  }

  Stream<String?> watchSecretCodeMatch(String secretCode) {
    return _db
        .child('single_match_secret_codes/$secretCode/chatRoomId')
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
    final mappingRef =
        _db.child('houses/$myHouseId/singleMatch/chatMappings/$peerHouseId');
    final existing = await mappingRef.child('roomId').get();
    if (existing.exists && existing.value != null) {
      return existing.value.toString();
    }

    final roomId = _db.child('chat_rooms').push().key!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await _db.child('chat_rooms/$roomId').set({
      'type': 'single_match',
      'createdAt': nowMs,
      'members': {
        myHouseId: true,
        peerHouseId: true,
      },
      'status': 'active',
    });

    await mappingRef.set({
      'roomId': roomId,
      'peerName': peerName,
      'peerAvatarUrl': peerAvatarUrl,
      'createdAt': nowMs,
    });

    return roomId;
  }

  Stream<List<Map<String, dynamic>>> streamChatMappings(String houseId) {
    return _db
        .child('houses/$houseId/singleMatch/chatMappings')
        .onValue
        .map((event) {
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

  // ===== Scored Random Match (scale 10k) =====

  /// Pick ứng viên qua Cloud Function (ưu tiên) hoặc fallback client-side.
  ///
  /// Với 1M users:
  /// - Server chỉ đọc 100 user gần đây từ active pool (limitToLast)
  /// - Score + filter trong RAM server (nhanh, < 50ms)
  /// - Mỗi request = 1 function invocation + 100 RTDB reads
  /// - Blaze cost: ~$0.02/tháng cho 300k request
  ///
  /// Fallback client-side khi không internet hoặc function lỗi.
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
    // Thử server match trước
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('singleMatchPick')
          .call({
        'currentHouseId': currentHouseId,
        'excludeHouseIds': excludeHouseIds.toList(),
        'goal': goal,
        'voiceStyle': voiceStyle,
        'myTags': myTags,
        'myAge': myAge,
        'preferredAgeMin': preferredAgeMin,
        'preferredAgeMax': preferredAgeMax,
        'needAudio': needAudio,
        'needVideo': needVideo,
      }).timeout(const Duration(seconds: 10));

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['match'] is Map) {
        final match = Map<String, dynamic>.from(data['match'] as Map);
        if (match['houseId'] != null) {
          return SingleMatchCandidate(
            houseId: match['houseId'].toString(),
            displayName: (match['displayName'] ?? '').toString().trim(),
            houseName: (match['displayName'] ?? '').toString().trim(),
            avatarUrl: (match['avatarUrl'] ?? '').toString().trim(),
            bio: (match['bio'] ?? '').toString().trim(),
            intro: (match['intro'] ?? '').toString().trim(),
            goal: (match['goal'] ?? '').toString().trim(),
            voiceStyle: (match['voiceStyle'] ?? '').toString().trim(),
            tags: (match['tags'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
            allowAudioCalls: match['allowAudioCalls'] == true,
            allowVideoCalls: match['allowVideoCalls'] == true,
            enabled: true,
            privacy: 'public',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            age: match['age'] as int?,
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[SingleMatch] server match failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[SingleMatch] server match error: $e');
    }

    // Fallback client-side (active pool cache)
    return _pickScoredMatchClient(
      currentHouseId: currentHouseId,
      excludeHouseIds: excludeHouseIds,
      goal: goal,
      voiceStyle: voiceStyle,
      myTags: myTags,
      myAge: myAge,
      preferredAgeMin: preferredAgeMin,
      preferredAgeMax: preferredAgeMax,
      needAudio: needAudio,
      needVideo: needVideo,
    );
  }

  /// Client-side fallback scoring (khi không thể gọi Cloud Function).
  Future<SingleMatchCandidate?> _pickScoredMatchClient({
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
    var pool = await _fetchActivePoolWithCache();
    var scored = _scorePool(
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
        needVideo);

    if (scored.isEmpty) {
      // Force fetch nếu cache không tìm thấy ai phù hợp
      pool = await _fetchActivePoolWithCache(forceFetch: true);
      scored = _scorePool(
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
          needVideo);
    }

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

    // Lấy data gốc từ pool cache
    final poolData = await _fetchActivePoolWithCache();
    final rawEntry = poolData[picked.houseId];
    if (rawEntry is! Map) return null;

    final prefs = SingleMatchPreferences.fromMap(rawEntry);
    final peerDob = (rawEntry['dobU1'] ?? '').toString().trim();
    final peerName = (rawEntry['displayName'] ?? '').toString().trim();
    return SingleMatchCandidate(
      houseId: picked.houseId,
      displayName: peerName.isNotEmpty ? peerName : 'Người ấy',
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
      age: peerDob.isNotEmpty ? ageFromDob(peerDob) : null,
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

      final peerEnabled = _readBool(data['enabled'], fallback: true);
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
      final peerDob = (data['dobU1'] ?? '').toString().trim();
      final peerAge = peerDob.isNotEmpty ? ageFromDob(peerDob) : null;
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
