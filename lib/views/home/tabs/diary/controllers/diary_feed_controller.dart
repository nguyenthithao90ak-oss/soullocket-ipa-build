import 'dart:async';

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
import '../../../../../utils/services/role_utils.dart';

class DiaryFeedController extends ChangeNotifier {
  DiaryFeedController({
    FirebaseAuth? auth,
    DatabaseReference? dbRef,
    HouseService? houseService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _dbRef = dbRef ?? FirebaseDatabase.instance.ref(),
       _houseService = houseService ?? HouseService();

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
  StreamSubscription<List<DiaryPost>>? _pinnedSubscription;
  Timer? _diaryInitialLoadTimer;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<DiaryPost> _latestPosts = const [];
  List<DiaryPost> _pinnedPosts = const [];
  List<DiaryPost> _paginatedPosts = const [];

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  final Map<String, String> _authorNameByUid = <String, String>{};
  final Set<String> _hydratingAuthorUids = <String>{};
  final Map<String, String> _memberRoleByUid = <String, String>{};

  bool _disposed = false;
  String? _sessionUid;
  int _sessionGeneration = 0;

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

  int get _diaryCacheLimit =>
      kIsWeb ? _webDiaryCacheLimit : _appDiaryCacheLimit;

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  bool _isSessionCurrent(int generation, String uid, {String? houseId}) {
    return !_disposed &&
        generation == _sessionGeneration &&
        _sessionUid == uid &&
        _auth.currentUser?.uid == uid &&
        (houseId == null || _houseId == houseId);
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
    final String name;
    switch (_normalizeRole(role)) {
      case 'user1':
        name = _nameU1.trim();
      case 'user2':
        name = _nameU2.trim();
      default:
        return '';
    }
    // Nhãn mặc định "Bạn Nam"/"Bạn Nữ" không phải tên thật, kể cả khi nhà
    // đã đảo nhãn giới tính.
    final isDefaultLabel =
        name == L10nService().translate('home_bnnam_123ef2') ||
        name == L10nService().translate('home_bnn_babaec');
    return name.isEmpty || isDefaultLabel ? '' : name;
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

  String _resolveAuthorRole({required String authorId, String? authorRole}) {
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

  Future<void> _fetchHouseSettingsData(
    String houseId, {
    String? expectedUid,
    int? sessionGeneration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      final settingsMap = await _houseService.getHouseSettings(houseId);
      if (settingsMap == null) {
        return;
      }
      if (expectedUid != null &&
          (sessionGeneration == null ||
              !_isSessionCurrent(
                sessionGeneration,
                expectedUid,
                houseId: houseId,
              ))) {
        return;
      }

      _activeRoleKey = _memberRoleByUid[_auth.currentUser?.uid ?? ''] ?? role;
      final genderSwapped = RoleUtils.readGenderSwapped(settingsMap);
      _nameU1 =
          settingsMap['nameU1']?.toString() ??
          L10nService().translate(
            RoleUtils.defaultNameKey('user1', genderSwapped: genderSwapped),
          );
      _nameU2 =
          settingsMap['nameU2']?.toString() ??
          L10nService().translate(
            RoleUtils.defaultNameKey('user2', genderSwapped: genderSwapped),
          );
      _relationshipMode = HouseSettings.inferRelationshipModeFromSettingsMap(
        settingsMap,
      );
      final sdRaw = settingsMap['startDate'];
      _startDate = sdRaw == null ? null : DateTime.tryParse(sdRaw.toString());
      _notifySafely();
    } catch (e) {
      debugPrint(
        'Error fetching settings for diary names: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  Future<String?> resolveHouseId({
    String? expectedUid,
    int? sessionGeneration,
  }) async {
    bool isCurrent() =>
        expectedUid == null ||
        (sessionGeneration != null &&
            _isSessionCurrent(sessionGeneration, expectedUid));

    final cachedHouseId = _normalizeHouseId(_houseId);
    if (cachedHouseId != null) {
      if (!isCurrent()) return null;
      _applyHouseId(cachedHouseId);
      await _houseService.ensureFirestoreMembership(cachedHouseId);
      if (!isCurrent()) return null;
      await _fetchHouseSettingsData(
        cachedHouseId,
        expectedUid: expectedUid,
        sessionGeneration: sessionGeneration,
      );
      return cachedHouseId;
    }

    final resolvedHouseId = _normalizeHouseId(
      await _houseService.getCurrentHouseId(),
    );
    if (!isCurrent()) return null;
    _applyHouseId(resolvedHouseId);
    if (resolvedHouseId != null) {
      await _houseService.ensureFirestoreMembership(resolvedHouseId);
      if (!isCurrent()) return null;
      await _fetchHouseSettingsData(
        resolvedHouseId,
        expectedUid: expectedUid,
        sessionGeneration: sessionGeneration,
      );
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

  Future<String> _resolveAccountNameByUid(String uid, {User? authUser}) async {
    if (_normalizeRole(uid).isNotEmpty) {
      return '';
    }

    // Hồ sơ RTDB chỉ cho phép đọc chính UID của người đăng nhập. Tên hiện
    // tại đã có trong Auth hoặc tên role của House, nên không cần tạo thêm
    // một lượt đọc users/{uid} có thể bị từ chối.
    return _firstNameCandidate([
      if (authUser != null) authUser.displayName,
      if (authUser != null) _emailLocalPart(authUser.email),
    ]);
  }

  Future<void> _hydrateAuthorNames(
    Iterable<DiaryPost> posts, {
    String? expectedUid,
    int? sessionGeneration,
  }) async {
    bool isCurrent() =>
        expectedUid == null ||
        (sessionGeneration != null &&
            _isSessionCurrent(sessionGeneration, expectedUid));
    if (!isCurrent()) return;
    final currentUser = _auth.currentUser;
    final namesFromPosts = <String, String>{};
    for (final post in posts) {
      final uid = post.authorId.trim();
      if (uid.isEmpty) {
        continue;
      }
      final role = _resolveAuthorRole(
        authorId: uid,
        authorRole: post.authorRole,
      );
      final storedName = _normalizeAuthorLabel(
        post.authorName,
        authorId: uid,
        authorRole: role,
      );
      if (storedName.isNotEmpty) {
        namesFromPosts[uid] = storedName;
      }
    }
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
      // Không đọc users/{uid} ở đây: rule RTDB chỉ cho tài khoản đọc hồ sơ
      // của chính mình, nên việc tìm tên người còn lại tạo ra Permission
      // denied lặp lại. Tên đã lưu trong bài, tên theo role của House và
      // metadata Auth đủ để hiển thị mà không cần mở rộng quyền đọc.
      for (final uid in uids) {
        final nameFromPost = namesFromPosts[uid];
        if (nameFromPost != null && nameFromPost.isNotEmpty) {
          resolved[uid] = nameFromPost;
          continue;
        }

        final roleName = _houseNameForRole(_memberRoleByUid[uid] ?? '');
        if (roleName.isNotEmpty) {
          resolved[uid] = roleName;
          continue;
        }

        if (currentUser?.uid == uid) {
          final authName = _firstNameCandidate([
            currentUser?.displayName,
            _emailLocalPart(currentUser?.email),
          ]);
          if (authName.isNotEmpty) {
            resolved[uid] = authName;
          }
        }
      }
    } catch (e) {
      debugPrint('[DiaryFeed] resolve user names error: $e');
      // Fallback: resolve từ auth cho current user
      for (final uid in uids) {
        if (currentUser?.uid == uid &&
            currentUser?.displayName?.trim().isNotEmpty == true) {
          resolved[uid] = currentUser!.displayName!.trim();
        }
      }
    } finally {
      _hydratingAuthorUids.removeAll(uids);
    }

    if (resolved.isEmpty) {
      return;
    }
    if (!isCurrent()) return;
    _authorNameByUid.addAll(resolved);
    _notifySafely();
  }

  Future<void> _hydrateMemberRoles(
    String houseId, {
    String? expectedUid,
    int? sessionGeneration,
  }) async {
    try {
      final snaps = await Future.wait([
        _dbRef
            .child('houses/$houseId/owner_uid')
            .get()
            .timeout(const Duration(seconds: 8)),
        _dbRef
            .child('houses/$houseId/members')
            .get()
            .timeout(const Duration(seconds: 8)),
      ]);

      final ownerUidSnap = snaps[0];
      final membersSnap = snaps[1];

      if (expectedUid != null &&
          (sessionGeneration == null ||
              !_isSessionCurrent(
                sessionGeneration,
                expectedUid,
                houseId: houseId,
              ))) {
        return;
      }

      final ownerUid = ownerUidSnap.value?.toString().trim() ?? '';
      final membersRaw = membersSnap.value;
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
    } catch (e) {
      debugPrint('[DiaryFeed] hydrate member roles error: $e');
    }
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

  // TTL cho diary feed cache: 24 giờ
  static const Duration _diaryCacheTtl = Duration(days: 7);

  Future<void> _cacheDiaryPosts(
    String houseId,
    List<Map<String, dynamic>> items, {
    required String expectedUid,
    required int sessionGeneration,
  }) async {
    if (!_isSessionCurrent(sessionGeneration, expectedUid, houseId: houseId)) {
      return;
    }
    final limited = items.take(_diaryCacheLimit).toList(growable: false);
    final signature = _buildCacheSignature(limited);
    if (_lastDiaryCacheSignature == signature) {
      return;
    }
    _lastDiaryCacheSignature = signature;
    // Lưu kèm timestamp để hỗ trợ TTL khi đọc lại
    await OfflineCacheService.saveCache('diary_$houseId', {
      '_cachedAt': DateTime.now().millisecondsSinceEpoch,
      'items': limited,
    });
  }

  List<DiaryPost> _sortDiaryPosts(List<DiaryPost> posts) {
    // Cache, pinned stream và trang phân trang có thể giao nhau khi cùng một
    // thay đổi được phát gần nhau. Giữ một bản theo ID trước khi sắp xếp để
    // nhật ký luôn render mỗi mục đúng một lần.
    final seenIds = <String>{};
    posts.removeWhere((post) => !seenIds.add(post.id));
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

  void _updatePostsVN() {
    if (_disposed) return;
    final pinnedList = _pinnedPosts;
    final latestList = _latestPosts;
    final paginatedList = _paginatedPosts;

    if (pinnedList.isEmpty && latestList.isEmpty && paginatedList.isEmpty) {
      postsVN.value = const <DiaryPost>[];
      return;
    }

    // Snapshot ghim chỉ là dữ liệu bổ sung. Nếu listener danh sách mới hoặc
    // trang đã tải có cùng ID, bản mới hơn phải thay bản snapshot cũ để trạng
    // thái ghim/bỏ ghim không bị giữ lại trên giao diện.
    final byId = <String, DiaryPost>{
      for (final post in pinnedList) post.id: post,
    };
    for (final post in latestList) {
      byId[post.id] = post;
    }
    for (final post in paginatedList) {
      byId[post.id] = post;
    }
    final all = byId.values.toList();

    all.sort((a, b) {
      final pinnedCompare = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      if (pinnedCompare != 0) return pinnedCompare;
      final pinnedAtCompare = (b.pinnedAt ?? 0).compareTo(a.pinnedAt ?? 0);
      if (pinnedAtCompare != 0) return pinnedAtCompare;
      return b.timestamp.compareTo(a.timestamp);
    });
    postsVN.value = all;
  }

  Future<void> fetchDiaryPosts({
    required Future<User?> Function() resolveCurrentUser,
  }) async {
    final requestGeneration = ++_sessionGeneration;
    _isLoadingMore = false;
    final shouldShowBlockingLoader = postsVN.value.isEmpty;
    if (shouldShowBlockingLoader) {
      _setLoading(true);
    }

    User? user;
    try {
      user = await resolveCurrentUser().timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint(
        '[DiaryFeed] resolve current user timed out or failed: $error',
      );
      if (requestGeneration == _sessionGeneration) _setLoading(false);
      return;
    }
    if (user == null) {
      _sessionUid = null;
      final logoutGeneration = ++_sessionGeneration;
      final diarySubscription = _diarySubscription;
      final pinnedSubscription = _pinnedSubscription;
      _diarySubscription = null;
      _pinnedSubscription = null;
      await diarySubscription?.cancel();
      await pinnedSubscription?.cancel();
      if (_disposed || logoutGeneration != _sessionGeneration) return;
      _applyHouseId(null);
      postsVN.value = const <DiaryPost>[];
      _setLoading(false);
      return;
    }

    final sessionUid = user.uid;
    if (_sessionUid != null && _sessionUid != sessionUid) {
      _lastDiaryCacheSignature = null;
      _latestPosts = const [];
      _pinnedPosts = const [];
      _paginatedPosts = const [];
      postsVN.value = const <DiaryPost>[];
    }
    _sessionUid = sessionUid;
    if (!_isSessionCurrent(requestGeneration, sessionUid)) return;

    try {
      final houseId = await resolveHouseId(
        expectedUid: sessionUid,
        sessionGeneration: requestGeneration,
      ).timeout(const Duration(seconds: 15));
      if (!_isSessionCurrent(requestGeneration, sessionUid)) return;
      if (houseId != null) {
        await _hydrateMemberRoles(
          houseId,
          expectedUid: sessionUid,
          sessionGeneration: requestGeneration,
        ).timeout(const Duration(seconds: 8));
        if (!_isSessionCurrent(
          requestGeneration,
          sessionUid,
          houseId: houseId,
        )) {
          return;
        }
        await _fetchHouseSettingsData(
          houseId,
          expectedUid: sessionUid,
          sessionGeneration: requestGeneration,
        ).timeout(const Duration(seconds: 8));
        if (!_isSessionCurrent(
          requestGeneration,
          sessionUid,
          houseId: houseId,
        )) {
          return;
        }
      }
      await resolveCurrentAuthorName(user).timeout(const Duration(seconds: 8));
      if (!_isSessionCurrent(requestGeneration, sessionUid, houseId: houseId)) {
        return;
      }

      final initialPosts = <DiaryPost>[];
      if (houseId != null) {
        final cachedRaw = await OfflineCacheService.loadCache(
          'diary_$houseId',
        ).timeout(const Duration(seconds: 4));
        // Hỗ trợ format mới {_cachedAt, items} và format cũ List
        List? cachedData;
        if (cachedRaw is Map) {
          final cachedAt = (cachedRaw['_cachedAt'] as num?)?.toInt() ?? 0;
          final ttlMs = _diaryCacheTtl.inMilliseconds;
          if (DateTime.now().millisecondsSinceEpoch - cachedAt <= ttlMs) {
            cachedData = cachedRaw['items'] as List?;
          }
        } else if (cachedRaw is List) {
          cachedData = cachedRaw; // format cũ: chấp nhận không TTL
        }
        if (cachedData != null) {
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
          if (_isSessionCurrent(
            requestGeneration,
            sessionUid,
            houseId: houseId,
          )) {
            postsVN.value = initialPosts;
            unawaited(
              _hydrateAuthorNames(
                initialPosts,
                expectedUid: sessionUid,
                sessionGeneration: requestGeneration,
              ),
            );
            _setLoading(false);
          }
        }
      }

      if (houseId == null) {
        if (!_isSessionCurrent(requestGeneration, sessionUid)) return;
        final diarySubscription = _diarySubscription;
        final pinnedSubscription = _pinnedSubscription;
        _diarySubscription = null;
        _pinnedSubscription = null;
        await diarySubscription?.cancel();
        await pinnedSubscription?.cancel();
        if (!_isSessionCurrent(requestGeneration, sessionUid)) return;
        postsVN.value = const <DiaryPost>[];
        if (_isSessionCurrent(requestGeneration, sessionUid)) {
          _setLoading(false);
        }
        return;
      }

      _lastDocument = null;
      _hasMore = true;
      _isLoadingMore = false;
      _latestPosts = const [];
      _pinnedPosts = const [];
      _paginatedPosts = const [];

      final previousDiarySubscription = _diarySubscription;
      final previousPinnedSubscription = _pinnedSubscription;
      _diarySubscription = null;
      _pinnedSubscription = null;
      await previousDiarySubscription?.cancel();
      await previousPinnedSubscription?.cancel();
      if (!_isSessionCurrent(requestGeneration, sessionUid, houseId: houseId)) {
        return;
      }

      // Auto migrate old RTDB diaries to Firestore in the background
      unawaited(DiaryService().migrateDiariesFromRTDB(houseId));

      // Bài ghim chỉ cần một lần đọc khi mở Nhật ký. Giữ một listener duy
      // nhất cho danh sách mới để tránh hai luồng realtime cùng phát một bài.
      unawaited(
        DiaryService()
            .fetchPinnedDiary(houseId)
            .then((loadedPinned) {
              if (!_isSessionCurrent(
                requestGeneration,
                sessionUid,
                houseId: houseId,
              )) {
                return;
              }
              _pinnedPosts = loadedPinned;
              _updatePostsVN();
            })
            .catchError((Object error) {
              debugPrint('Pinned diary read failed: $error');
            }),
      );

      _diarySubscription = DiaryService()
          .streamDiary(houseId, limit: 10)
          .listen(
            (loadedPosts) {
              if (!_isSessionCurrent(
                requestGeneration,
                sessionUid,
                houseId: houseId,
              )) {
                return;
              }
              _diaryInitialLoadTimer?.cancel();
              _diaryInitialLoadTimer = null;
              try {
                if (_disposed) {
                  return;
                }

                if (loadedPosts.isEmpty) {
                  _latestPosts = const [];
                  _updatePostsVN();
                  unawaited(
                    _cacheDiaryPosts(
                      houseId,
                      const <Map<String, dynamic>>[],
                      expectedUid: sessionUid,
                      sessionGeneration: requestGeneration,
                    ),
                  );
                  return;
                }

                _latestPosts = loadedPosts;
                _updatePostsVN();

                final cacheList = loadedPosts.map((p) => p.toJson()).toList();
                unawaited(
                  _cacheDiaryPosts(
                    houseId,
                    cacheList,
                    expectedUid: sessionUid,
                    sessionGeneration: requestGeneration,
                  ),
                );
                unawaited(
                  _hydrateAuthorNames(
                    loadedPosts,
                    expectedUid: sessionUid,
                    sessionGeneration: requestGeneration,
                  ),
                );
              } catch (e, stack) {
                debugPrint('Error processing diary realtime event: $e\n$stack');
              } finally {
                _setLoading(false);
              }
            },
            onError: (Object error) {
              if (!_isSessionCurrent(
                requestGeneration,
                sessionUid,
                houseId: houseId,
              )) {
                return;
              }
              _diaryInitialLoadTimer?.cancel();
              _diaryInitialLoadTimer = null;
              debugPrint(
                'Diary realtime listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('home_khngthtinh_eb6eac')).message}',
              );
              _setLoading(false);
            },
          );
      _diaryInitialLoadTimer?.cancel();
      _diaryInitialLoadTimer = Timer(const Duration(seconds: 12), () {
        if (_isSessionCurrent(
          requestGeneration,
          sessionUid,
          houseId: houseId,
        )) {
          _setLoading(false);
        }
      });
    } catch (e) {
      debugPrint('[DiaryFeed] fetchDiaryPosts error: $e');
      if (_isSessionCurrent(requestGeneration, sessionUid)) {
        _setLoading(false);
      }
    }
  }

  Future<void> fetchNextDiaryPage() async {
    if (_isLoadingMore || !_hasMore) return;
    final houseId = _houseId;
    final sessionUid = _sessionUid ?? _auth.currentUser?.uid;
    final requestGeneration = _sessionGeneration;
    if (houseId == null ||
        sessionUid == null ||
        !_isSessionCurrent(requestGeneration, sessionUid, houseId: houseId)) {
      return;
    }

    _isLoadingMore = true;
    _notifySafely();

    try {
      if (_lastDocument == null) {
        final firstPageResult = await DiaryService()
            .fetchDiaryPage(houseId, limit: 10)
            .timeout(const Duration(seconds: 15));
        if (!_isSessionCurrent(
          requestGeneration,
          sessionUid,
          houseId: houseId,
        )) {
          return;
        }
        _lastDocument = firstPageResult.lastDoc;
        if (_lastDocument == null) {
          _hasMore = false;
          _isLoadingMore = false;
          _notifySafely();
          return;
        }
      }

      final result = await DiaryService()
          .fetchDiaryPage(houseId, limit: 10, startAfter: _lastDocument)
          .timeout(const Duration(seconds: 15));

      if (!_isSessionCurrent(requestGeneration, sessionUid, houseId: houseId)) {
        return;
      }

      if (result.posts.isNotEmpty) {
        _lastDocument = result.lastDoc;
        _paginatedPosts = [..._paginatedPosts, ...result.posts];
        _updatePostsVN();
      }
      _hasMore = result.hasMore;
    } catch (e) {
      debugPrint('Error fetching next diary page: $e');
    } finally {
      if (_isSessionCurrent(requestGeneration, sessionUid, houseId: houseId)) {
        _isLoadingMore = false;
        _notifySafely();
      }
    }
  }

  Future<void> pauseRealtime() async {
    _sessionGeneration++;
    _isLoadingMore = false;
    _diaryInitialLoadTimer?.cancel();
    _diaryInitialLoadTimer = null;
    final diarySubscription = _diarySubscription;
    final pinnedSubscription = _pinnedSubscription;
    _diarySubscription = null;
    _pinnedSubscription = null;
    await diarySubscription?.cancel();
    await pinnedSubscription?.cancel();
  }

  Future<void> deleteDiaryPost(DiaryPost post) async {
    final houseId = _houseId;
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (houseId == null || uid.isEmpty) {
      return;
    }
    await DiaryService().deleteDiaryPost(
      houseId: houseId,
      postId: post.id,
      requestingAuthorId: uid,
    );
  }

  Future<void> togglePinDiaryPost(DiaryPost post) async {
    final houseId = _houseId;
    if (houseId == null) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final diariesRef = FirebaseFirestore.instance
        .collection('houses')
        .doc(houseId)
        .collection('diaries');

    if (post.pinned) {
      batch.update(diariesRef.doc(post.id), {
        'pinned': false,
        'pinnedAt': null,
      });
    } else {
      for (final item in postsVN.value.where(
        (entry) => entry.pinned && entry.id != post.id,
      )) {
        batch.update(diariesRef.doc(item.id), {
          'pinned': false,
          'pinnedAt': null,
        });
      }
      batch.update(diariesRef.doc(post.id), {
        'pinned': true,
        'pinnedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Cập nhật snapshot local ngay sau thao tác rõ ràng của người dùng. Bài
    // ghim được đọc một lần khi mở màn hình nên nếu chỉ chờ listener danh sách
    // mới, một bài cũ có thể giữ trạng thái ghim cũ trong vài giây hoặc lâu hơn.
    final shouldPin = !post.pinned;
    final localPinnedAt = shouldPin
        ? DateTime.now().millisecondsSinceEpoch
        : null;

    DiaryPost withPinState(DiaryPost value, bool pinned, int? pinnedAt) {
      return DiaryPost.fromJson(value.id, <String, dynamic>{
        ...value.toJson(),
        'pinned': pinned,
        'pinnedAt': pinnedAt,
      });
    }

    List<DiaryPost> updateList(List<DiaryPost> values) {
      return [
        for (final value in values)
          if (value.id == post.id)
            withPinState(value, shouldPin, localPinnedAt)
          else if (shouldPin && value.pinned)
            withPinState(value, false, null)
          else
            value,
      ];
    }

    _latestPosts = updateList(_latestPosts);
    _paginatedPosts = updateList(_paginatedPosts);
    _pinnedPosts = shouldPin
        ? [withPinState(post, true, localPinnedAt)]
        : _pinnedPosts.where((value) => value.id != post.id).toList();
    _updatePostsVN();
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
    _sessionGeneration++;
    _diaryInitialLoadTimer?.cancel();
    _diarySubscription?.cancel();
    _pinnedSubscription?.cancel();
    postsVN.dispose();
    super.dispose();
  }
}
