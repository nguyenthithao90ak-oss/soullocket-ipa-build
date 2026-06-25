import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'house_service.dart';

class SingleMatchService {
  SingleMatchService._();

  static final SingleMatchService instance = SingleMatchService._();
  static const String _profileIndexRoot = 'single_match_profiles';
  static const Duration _profileIndexCacheTtl = Duration(minutes: 5);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final HouseService _houseService = HouseService();

  // Cache profile index để tránh listen realtime liên tục
  Map<String, Map<dynamic, dynamic>>? _profileIndexCache;
  DateTime? _profileIndexCachedAt;

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
    final snap = await _db.child('houses/$houseId/settings').get();
    if (!snap.exists || snap.value is! Map) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<SingleMatchPreferences> loadPreferences(String houseId) async {
    final snap = await _db.child('houses/$houseId/settings/singleMatch').get();
    if (!snap.exists || snap.value is! Map) {
      return const SingleMatchPreferences();
    }
    return SingleMatchPreferences.fromMap(snap.value as Map);
  }

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

    Future<void> loadFallbackProfiles() async {
      // Root read is disabled for house_profiles due to security rules.
      // We skip querying the root node to prevent Permission Denied warnings.
      emitMergedCandidates();
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
            fallbackMessage: L10nService().translate('err_single_match_profile_index_stream_failed'),
          ).message}');
          emitMergedCandidates();
        }));
        unawaited(loadFallbackProfiles());
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
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final baseMap = preferences
        .copyWith(
          updatedAt: nowMs,
        )
        .toMap();

    await _db.update({
      'houses/$houseId/settings/singleMatch': baseMap,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...profileIndexUpdates(
        houseId: houseId,
        singleMatch: baseMap,
        updatedAt: nowMs,
      ),
    });
  }

  Future<void> updateOwnDob({
    required String houseId,
    required String isoDob,
  }) async {
    final normalized = isoDob.trim();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.update({
      'houses/$houseId/settings/dobU1': normalized,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...profileIndexUpdates(
        houseId: houseId,
        dobU1: normalized,
        updatedAt: nowMs,
      ),
    });
  }

  Stream<List<SingleMatchHistoryEntry>> streamHistory(String houseId) {
    late final StreamController<List<SingleMatchHistoryEntry>> controller;
    StreamSubscription<DatabaseEvent>? historySub;

    controller = StreamController<List<SingleMatchHistoryEntry>>(
      onListen: () {
        controller.add(const <SingleMatchHistoryEntry>[]);
        historySub =
            _db.child('houses/$houseId/singleMatch/history').onValue.listen(
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
              fallbackMessage: L10nService().translate('err_single_match_history_stream_failed'),
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

  int? _ageFromDob(String rawDob) {
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

  // Fetch profile index 1 lần + cache 5 phút — tránh listen realtime liên tục
  Future<Map<String, Map<dynamic, dynamic>>> _fetchProfileIndexWithCache() async {
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
    final age = _ageFromDob(
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
}
