import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueNotifier, debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../models/diary_post.dart';
import '../../../../../models/house_settings.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../utils/services/house_service.dart';
import '../../../../../utils/services/offline_cache_service.dart';
import '../../../../../utils/services/diary_service.dart';
import '../../../../../utils/services/l10n_service.dart';

class DiaryFeedController extends ChangeNotifier {
  DiaryFeedController({
    FirebaseAuth? auth,
    DatabaseReference? dbRef,
    HouseService? houseService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _dbRef = dbRef ?? FirebaseDatabase.instance.ref(),
        _houseService = houseService ?? HouseService();

  static const int _webDiaryRealtimeLimit = 40;
  static const int _appDiaryRealtimeLimit = 80;
  static const int _webDiaryCacheLimit = 28;
  static const int _appDiaryCacheLimit = 60;

  final FirebaseAuth _auth;
  final DatabaseReference _dbRef;
  final HouseService _houseService;

  final ValueNotifier<List<DiaryPost>> postsVN = ValueNotifier<List<DiaryPost>>(
    const <DiaryPost>[],
  );

  bool _isLoading = true;
  String? _houseId;
  String _nameU1 = L10nService().translate('home_bnnam_123ef2');
  String _nameU2 = L10nService().translate('home_bnn_babaec');
  String _currentAuthorName = '';
  String _activeRoleKey = 'user1';
  String _relationshipMode = 'single';
  DateTime? _startDate;
  String? _lastDiaryCacheSignature;
  StreamSubscription<List<DiaryPost>>? _diarySubscription;

  final Map<String, String> _authorNameByUid = <String, String>{};
  final Set<String> _hydratingAuthorUids = <String>{};
  final Map<String, String> _memberRoleByUid = <String, String>{};

  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get houseId => _houseId;
  String get nameU1 => _nameU1;
  String get nameU2 => _nameU2;
  String get activeRoleKey => _activeRoleKey;
  String get relationshipMode => _relationshipMode;
  DateTime? get startDate => _startDate;
  String get currentAuthorRole => _activeRoleKey == 'user1' ? 'user1' : 'user2';
  String get currentRoleName =>
      _activeRoleKey == 'user1' ? _nameU1.trim() : _nameU2.trim();

  int get _diaryRealtimeLimit =>
      kIsWeb ? _webDiaryRealtimeLimit : _appDiaryRealtimeLimit;

  int get _diaryCacheLimit =>
      kIsWeb ? _webDiaryCacheLimit : _appDiaryCacheLimit;

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    _notifySafely();
  }

  String? _normalizeHouseId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _applyHouseId(String? houseId) {
    final normalized = _normalizeHouseId(houseId);
    if (_houseId == normalized) {
      return;
    }

    _houseId = normalized;
    _lastDiaryCacheSignature = null;
    _authorNameByUid.clear();
    _memberRoleByUid.clear();
    _currentAuthorName = '';
    postsVN.value = const <DiaryPost>[];
    _notifySafely();
  }

  String _normalizeRole(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed == 'user1' || trimmed == 'user2') {
      return trimmed;
    }
    return '';
  }

  String _emailLocalPart(String? email) {
    final value = email?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    final atIndex = value.indexOf('@');
    return atIndex > 0 ? value.substring(0, atIndex) : value;
  }

  String _firstNameCandidate(Iterable<String?> candidates) {
    for (final value in candidates) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  String _houseNameForRole(String role) {
    switch (_normalizeRole(role)) {
      case 'user1':
        final name = _nameU1.trim();
        return (name.isEmpty || name == L10nService().translate('home_bnnam_123ef2')) ? '' : name;
      case 'user2':
        final name = _nameU2.trim();
        return (name.isEmpty || name == L10nService().translate('home_bnn_babaec')) ? '' : name;
      default:
        return '';
    }
  }

  String _normalizeAuthorLabel(
    String? value, {
    String authorId = '',
    String authorRole = '',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }

    if (trimmed == authorId ||
        trimmed == authorRole ||
        _normalizeRole(trimmed).isNotEmpty) {
      return '';
    }

    final lowered = trimmed.toLowerCase();
    if (lowered == L10nService().translate('home_ngiyu_ef6c08') ||
        lowered == 'nguoi yeu' ||
        lowered == L10nService().translate('home_bnnam_b57724') ||
        lowered == 'ban nam' ||
        lowered == L10nService().translate('home_bnn_be46dc') ||
        lowered == 'ban nu') {
      return '';
    }

    if (trimmed.contains('@')) {
      return _emailLocalPart(trimmed);
    }

    return trimmed;
  }

  String _resolveAuthorRole({
    required String authorId,
    String? authorRole,
  }) {
    final normalizedRole = _normalizeRole(authorRole);
    if (normalizedRole.isNotEmpty) {
      return normalizedRole;
    }

    final idAsRole = _normalizeRole(authorId);
    if (idAsRole.isNotEmpty) {
      return idAsRole;
    }

    if (authorId.isNotEmpty && authorId == _auth.currentUser?.uid) {
      return currentAuthorRole;
    }

    return _memberRoleByUid[authorId]?.trim() ?? '';
  }

  Future<void> _fetchHouseSettingsData(String houseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      final settingsMap = await _houseService.getHouseSettings(houseId);
      if (settingsMap == null) {
        return;
      }

      _activeRoleKey = _memberRoleByUid[_auth.currentUser?.uid ?? ''] ?? role;
      _nameU1 = settingsMap['nameU1']?.toString() ?? L10nService().translate('home_bnnam_123ef2');
      _nameU2 = settingsMap['nameU2']?.toString() ?? L10nService().translate('home_bnn_babaec');
      _relationshipMode =
          HouseSettings.inferRelationshipModeFromSettingsMap(settingsMap);
      final sdRaw = settingsMap['startDate'];
      _startDate = sdRaw == null ? null : DateTime.tryParse(sdRaw.toString());
      _notifySafely();
    } catch (e) {
      debugPrint(
        'Error fetching settings for diary names: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  Future<String?> resolveHouseId() async {
    final cachedHouseId = _normalizeHouseId(_houseId);
    if (cachedHouseId != null) {
      _applyHouseId(cachedHouseId);
      await _fetchHouseSettingsData(cachedHouseId);
      return cachedHouseId;
    }

    final resolvedHouseId = _normalizeHouseId(
      await _houseService.getCurrentHouseId(),
    );
    _applyHouseId(resolvedHouseId);
    if (resolvedHouseId != null) {
      await _fetchHouseSettingsData(resolvedHouseId);
    }
    return resolvedHouseId;
  }

  Future<String> resolveCurrentAuthorName(User user) async {
    final houseNameCandidate = _houseNameForRole(currentAuthorRole);
    if (houseNameCandidate.isNotEmpty) {
      _authorNameByUid[user.uid] = houseNameCandidate;
      if (_currentAuthorName != houseNameCandidate) {
        _currentAuthorName = houseNameCandidate;
        _notifySafely();
      }
      return houseNameCandidate;
    }

    final resolved = await _resolveAccountNameByUid(user.uid, authUser: user);
    if (resolved.isNotEmpty &&
        !resolved.contains('@') &&
        resolved != user.uid &&
        resolved.length < 20) {
      _authorNameByUid[user.uid] = resolved;
      if (_currentAuthorName != resolved) {
        _currentAuthorName = resolved;
        _notifySafely();
      }
      return resolved;
    }

    final fallback = _firstNameCandidate([
      currentRoleName,
      _emailLocalPart(user.email),
      L10nService().translate('home_ti_a843eb'),
    ]);
    _authorNameByUid[user.uid] = fallback;
    if (_currentAuthorName != fallback) {
      _currentAuthorName = fallback;
      _notifySafely();
    }
    return fallback;
  }

  Future<String> _resolveAccountNameByUid(
    String uid, {
    User? authUser,
  }) async {
    if (_normalizeRole(uid).isNotEmpty) {
      return '';
    }

    final candidates = <String?>[
      if (authUser != null) authUser.displayName,
    ];

    try {
      final snap = await _dbRef
          .child('users/$uid')
          .get()
          .timeout(const Duration(seconds: 2));
      final raw = snap.value;
      if (raw is Map) {
        candidates.addAll([
          raw['displayName']?.toString(),
          raw['name']?.toString(),
          raw['fullName']?.toString(),
          raw['username']?.toString(),
          _emailLocalPart(raw['email']?.toString()),
        ]);
      }
    } catch (_) {}

    candidates.addAll([
      if (authUser != null) _emailLocalPart(authUser.email),
    ]);

    return _firstNameCandidate(candidates);
  }

  Future<void> _hydrateAuthorNames(Iterable<DiaryPost> posts) async {
    final currentUser = _auth.currentUser;
    final uids = posts
        .map((post) => post.authorId.trim())
        .where(
          (uid) =>
              uid.isNotEmpty &&
              _normalizeRole(uid).isEmpty &&
              !_authorNameByUid.containsKey(uid) &&
              !_hydratingAuthorUids.contains(uid),
        )
        .toList(growable: false);
    if (uids.isEmpty) {
      return;
    }

    _hydratingAuthorUids.addAll(uids);
    final resolved = <String, String>{};
    try {
      final entries = await Future.wait(
        uids.map((uid) async {
          final name = await _resolveAccountNameByUid(
            uid,
            authUser: currentUser?.uid == uid ? currentUser : null,
          );
          return MapEntry(uid, name);
        }),
      );

      for (final entry in entries) {
        if (entry.value.isNotEmpty) {
          resolved[entry.key] = entry.value;
        }
      }
    } finally {
      _hydratingAuthorUids.removeAll(uids);
    }

    if (resolved.isEmpty) {
      return;
    }
    _authorNameByUid.addAll(resolved);
    _notifySafely();
  }

  Future<void> _hydrateMemberRoles(String houseId) async {
    try {
      final snap = await _dbRef
          .child('houses/$houseId')
          .get()
          .timeout(const Duration(seconds: 3));
      final raw = snap.value;
      if (raw is! Map) {
        return;
      }

      final houseData = Map<dynamic, dynamic>.from(raw);
      final ownerUid = houseData['owner_uid']?.toString().trim() ?? '';
      final membersRaw = houseData['members'];
      final roles = <String, String>{};

      if (membersRaw is Map) {
        membersRaw.forEach((key, value) {
          final uid = key.toString().trim();
          if (uid.isEmpty) {
            return;
          }

          var role = '';
          if (value is Map) {
            role = _normalizeRole(value['role']?.toString());
          }

          if (uid == ownerUid) {
            role = 'user1';
          } else if (role.isEmpty) {
            role = 'user2';
          }

          roles[uid] = role;
        });
      }

      if (ownerUid.isNotEmpty) {
        roles[ownerUid] = 'user1';
      }

      if (roles.isEmpty) {
        return;
      }

      _memberRoleByUid
        ..clear()
        ..addAll(roles);

      final currentUid = _auth.currentUser?.uid ?? '';
      final resolvedRole = _memberRoleByUid[currentUid] ?? '';
      if (_normalizeRole(resolvedRole).isNotEmpty) {
        _activeRoleKey = resolvedRole;
        _notifySafely();
      }
    } catch (_) {}
  }

  int _readCacheTs(Map<String, dynamic> item) {
    final raw = item['ts'] ?? item['timestamp'] ?? item['date'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _buildCacheSignature(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return '0';
    }

    final first = items.first;
    final last = items.last;
    final firstId = first['id']?.toString() ?? '';
    final lastId = last['id']?.toString() ?? '';
    final firstTs = _readCacheTs(first);
    final lastTs = _readCacheTs(last);
    return '${items.length}|$firstId|$firstTs|$lastId|$lastTs';
  }

  Future<void> _cacheDiaryPosts(
    String houseId,
    List<Map<String, dynamic>> items,
  ) async {
    final limited = items.take(_diaryCacheLimit).toList(growable: false);
    final signature = _buildCacheSignature(limited);
    if (_lastDiaryCacheSignature == signature) {
      return;
    }
    _lastDiaryCacheSignature = signature;
    await OfflineCacheService.saveCache('diary_$houseId', limited);
  }

  List<DiaryPost> _sortDiaryPosts(List<DiaryPost> posts) {
    posts.sort((a, b) {
      final pinnedCompare = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      if (pinnedCompare != 0) {
        return pinnedCompare;
      }

      final pinnedAtCompare = (b.pinnedAt ?? 0).compareTo(a.pinnedAt ?? 0);
      if (pinnedAtCompare != 0) {
        return pinnedAtCompare;
      }

      return b.timestamp.compareTo(a.timestamp);
    });
    return posts;
  }

  Future<void> fetchDiaryPosts({
    required Future<User?> Function() resolveCurrentUser,
  }) async {
    final shouldShowBlockingLoader = postsVN.value.isEmpty;
    if (shouldShowBlockingLoader) {
      _setLoading(true);
    }

    final user = await resolveCurrentUser();
    if (user == null) {
      await _diarySubscription?.cancel();
      _diarySubscription = null;
      _applyHouseId(null);
      postsVN.value = const <DiaryPost>[];
      _setLoading(false);
      return;
    }

    try {
      final houseId = await resolveHouseId();
      if (houseId != null) {
        await _hydrateMemberRoles(houseId);
        await _fetchHouseSettingsData(houseId);
      }
      await resolveCurrentAuthorName(user);

      final initialPosts = <DiaryPost>[];
      if (houseId != null) {
        final cachedData =
            await OfflineCacheService.loadCache('diary_$houseId');
        if (cachedData is List) {
          for (final item in cachedData.take(_diaryCacheLimit)) {
            if (item is! Map) {
              continue;
            }
            initialPosts.add(
              DiaryPost.fromJson(
                item['id']?.toString() ?? '',
                Map<dynamic, dynamic>.from(item),
              ),
            );
          }
          _sortDiaryPosts(initialPosts);
          postsVN.value = initialPosts;
          unawaited(_hydrateAuthorNames(initialPosts));
          _setLoading(false);
        }
      }

      final connectivityResult = await Connectivity().checkConnectivity().then(
            (results) =>
                results.isNotEmpty ? results.first : ConnectivityResult.none,
          );

      if (connectivityResult == ConnectivityResult.none) {
        _setLoading(false);
        return;
      }

      if (houseId == null) {
        await _diarySubscription?.cancel();
        _diarySubscription = null;
        postsVN.value = const <DiaryPost>[];
        _setLoading(false);
        return;
      }

      await _diarySubscription?.cancel();
      
      // Auto migrate old RTDB diaries to Firestore in the background
      unawaited(DiaryService().migrateDiariesFromRTDB(houseId));

      _diarySubscription = DiaryService().streamDiary(houseId, limit: _diaryRealtimeLimit).listen(
        (loadedPosts) {
          try {
            if (_disposed) {
              return;
            }

            if (loadedPosts.isEmpty) {
              _lastDiaryCacheSignature = '0';
              unawaited(
                  OfflineCacheService.saveCache('diary_$houseId', const []));
              postsVN.value = const <DiaryPost>[];
              return;
            }

            final cacheList = loadedPosts.map((p) => p.toJson()).toList();

            _sortDiaryPosts(loadedPosts);
            unawaited(_cacheDiaryPosts(houseId, cacheList));

            postsVN.value = loadedPosts;
            unawaited(_hydrateAuthorNames(loadedPosts));
          } catch (e, stack) {
            debugPrint('Error processing diary realtime event: $e\n$stack');
          } finally {
            _setLoading(false);
          }
        },
        onError: (Object error) {
          debugPrint(
            'Diary realtime listener failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: L10nService().translate('home_khngthtinh_eb6eac'),
            ).message}',
          );
          _setLoading(false);
        },
      );
    } catch (_) {
      _setLoading(false);
    }
  }

  Future<void> pauseRealtime() async {
    await _diarySubscription?.cancel();
    _diarySubscription = null;
  }

  Future<void> deleteDiaryPost(DiaryPost post) async {
    final houseId = _houseId;
    if (houseId == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('houses').doc(houseId).collection('diaries').doc(post.id).delete();
  }

  Future<void> togglePinDiaryPost(DiaryPost post) async {
    final houseId = _houseId;
    if (houseId == null) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final diariesRef = FirebaseFirestore.instance.collection('houses').doc(houseId).collection('diaries');

    if (post.pinned) {
      batch.update(diariesRef.doc(post.id), {'pinned': false, 'pinnedAt': null});
    } else {
      for (final item in postsVN.value
          .where((entry) => entry.pinned && entry.id != post.id)) {
        batch.update(diariesRef.doc(item.id), {'pinned': false, 'pinnedAt': null});
      }
      batch.update(diariesRef.doc(post.id), {'pinned': true, 'pinnedAt': FieldValue.serverTimestamp()});
    }

    await batch.commit();
  }

  String resolvedPostAuthorName(DiaryPost post) {
    final authorId = post.authorId.trim();
    final authorRole = _resolveAuthorRole(
      authorId: authorId,
      authorRole: post.authorRole,
    );

    final storedName = _normalizeAuthorLabel(
      post.authorName,
      authorId: authorId,
      authorRole: authorRole,
    );
    if (storedName.isNotEmpty) {
      return storedName;
    }

    final resolvedName = _normalizeAuthorLabel(
      _authorNameByUid[authorId],
      authorId: authorId,
      authorRole: authorRole,
    );
    if (resolvedName.isNotEmpty) {
      return resolvedName;
    }

    final roleName = _houseNameForRole(authorRole);
    if (roleName.isNotEmpty) {
      return roleName;
    }

    if (authorId == _auth.currentUser?.uid) {
      return _currentAuthorName.trim();
    }

    return '';
  }

  String resolveMemoryAuthorName(Map<String, dynamic> item) {
    final authorId = item['authorId']?.toString().trim() ?? '';
    final authorRole = _resolveAuthorRole(
      authorId: authorId,
      authorRole: item['authorRole']?.toString(),
    );
    final resolved = _normalizeAuthorLabel(
      _authorNameByUid[authorId],
      authorId: authorId,
      authorRole: authorRole,
    );
    if (resolved.isNotEmpty) {
      return resolved;
    }

    final storedName = _normalizeAuthorLabel(
      item['authorName']?.toString(),
      authorId: authorId,
      authorRole: authorRole,
    );
    if (storedName.isNotEmpty) {
      return storedName;
    }

    final roleName = _houseNameForRole(authorRole);
    if (roleName.isNotEmpty) {
      return roleName;
    }

    final rawAuthor = item['author']?.toString();
    return _firstNameCandidate([
      rawAuthor != null && rawAuthor.contains('@')
          ? _emailLocalPart(rawAuthor)
          : rawAuthor,
      _emailLocalPart(item['authorEmail']?.toString()),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _diarySubscription?.cancel();
    postsVN.dispose();
    super.dispose();
  }
}
