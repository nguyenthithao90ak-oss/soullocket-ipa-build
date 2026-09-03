import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Query, Transaction;
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:soullocket_app/models/social_post.dart';
import 'push_notification_helper.dart';
import 'local_database_service.dart';

/// SocialService — Quản lý social feed cộng đồng
/// Mô hình dữ liệu:
///   Firestore: `social_posts/{postId}` — bài đăng, bình luận và lượt thích.
///   Firestore: `house_likes/{houseId}/posts/{postId}` — chỉ mục bài đã thích.
///   RTDB:      `houses/...`, `friends/...` — quan hệ và quyền tương tác.
///
/// Tối ưu: dùng read-through cache (LocalDatabaseService) cho các GET
/// nhiều lần như check block, profile lookup — giảm tới 50% reads.
class SocialService {
  static final SocialService instance = SocialService();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocWithCacheFallback(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      return await docRef.get(const GetOptions(source: Source.server));
    } catch (_) {
      return await docRef.get(const GetOptions(source: Source.cache));
    }
  }

  Future<cf.QuerySnapshot<Map<String, dynamic>>> _getQueryWithCacheFallback(
    cf.Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      return await query.get(const GetOptions(source: Source.cache));
    }
  }

  static const List<String> _blockedCommunityTerms = <String>[
    '18+',
    'khieu dam',
    'sex',
    'clip nong',
    'nude',
    'au dam',
    'child porn',
    'csam',
    'hiep dam',
    'rape',
    'dit',
    'lon',
    'cac',
    'buoi',
    'cc',
    'cl',
    'vcl',
    'dcm',
    'vkl',
    'vl',
    'loz',
    'dm',
    'cave',
    'pho',
    'chich',
    'nung',
    'dam',
    'thu dam',
    'quay tay',
    'mbbg',
    'sgbb',
    'sgdd',
    'chui',
    'chui the',
    'dit me',
    'con di',
    'thang cho',
    'cut',
    'du ma',
    'du me',
    'mat lon',
    'ham lon',
    'vai lon',
    'cai lon',
    'cac cho',
    'ngu nhu cho',
    'oc cho',
    'dau bo',
    'bu cu',
    'suc cac',
    'tham du',
    'nung lon',
    'nung cac',
    'dam dang',
    'di diem',
    'diem thui',
    'cho de',
    'chet tiet',
    'khon nan',
    'mat day',
    'vo giao duc',
    'pho phach',
    'lon me may',
    'cac tao',
    'dit cu',
    'dit ba',
    'dit cha',
    'dit con me',
    'dmm',
    'dkm',
    'vcc',
    'vai ca cac',
    'deo',
    'bitch',
    'fuck',
    'shit',
    'asshole',
    'cunt',
    'dick',
    'pussy',
    'whore',
    'slut',
    'motherfucker',
    'bastard',
    'blowjob',
    'handjob',
    'tits',
    'boobs',
  ];

  /// Tải bài đăng từ nguồn dữ liệu chính là Firestore.
  Future<Map<String, dynamic>?> _loadPostHybrid(String postId) async {
    try {
      final doc = await _getDocWithCacheFallback(
        _firestore.collection('social_posts').doc(postId),
      );
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = postId;
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _loadCommentHybrid(
      String postId, String commentId) async {
    try {
      final doc = await _getDocWithCacheFallback(
        _firestore
            .collection('social_posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId),
      );
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = commentId;
        return data;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _readMapField(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<bool> _isBlockedBetween(
    String sourceHouseId,
    String targetHouseId,
  ) async {
    if (sourceHouseId.isEmpty || targetHouseId.isEmpty) return false;
    // Read-through cache: tránh gọi Firebase GET nhiều lần cho cùng 1 cặp
    final cacheKey = 'blocked:$sourceHouseId:$targetHouseId';
    final cached = await LocalDatabaseService().getCacheEntry(cacheKey);
    if (cached is bool) return cached;

    final results = await Future.wait([
      _dbRef.child('houses/$sourceHouseId/blocked_users/$targetHouseId').get(),
      _dbRef.child('houses/$targetHouseId/blocked_users/$sourceHouseId').get(),
    ]);
    final blocked = results.any((snap) => snap.value == true);

    // Cache 5 phút — blocked status hiếm khi thay đổi
    await LocalDatabaseService()
        .setCacheEntry(cacheKey, blocked, ttl: const Duration(minutes: 5));
    return blocked;
  }

  Future<void> assertCanInteractWithHouse({
    required String myHouseId,
    required String targetHouseId,
  }) async {
    if (await _isBlockedBetween(myHouseId, targetHouseId)) {
      throw 'Hai nhà đã chặn nhau, không thể tiếp tục tương tác.';
    }
  }

  Future<void> blockHouse({
    required String sourceHouseId,
    required String targetHouseId,
    bool removeFriendLinks = true,
  }) async {
    final source = sourceHouseId.trim();
    final target = targetHouseId.trim();
    if (source.isEmpty) {
      throw 'Không tìm thấy nhà hiện tại hợp lệ để chặn người dùng.';
    }
    if (target.isEmpty) {
      throw 'Không tìm thấy người dùng cần chặn.';
    }
    if (source == target) {
      throw 'Bạn không thể tự chặn chính mình.';
    }

    final updates = <String, Object?>{
      'houses/$source/blocked_users/$target': true,
    };
    if (removeFriendLinks) {
      updates['friends/$source/$target'] = null;
      updates['friends/$target/$source'] = null;
    }
    await _dbRef.update(updates);
  }

  Future<void> assertCanInteractWithPost({
    required String myHouseId,
    required String postId,
  }) async {
    final postData = await _loadPostHybrid(postId);
    if (postData == null) {
      throw 'Bài viết không tồn tại.';
    }
    final targetHouseId = (postData['houseId'] ?? '').toString();
    if (targetHouseId.isEmpty || targetHouseId == myHouseId) return;
    await assertCanInteractWithHouse(
      myHouseId: myHouseId,
      targetHouseId: targetHouseId,
    );
  }

  String _normalizeReportReason(String reason) {
    final normalized = reason.trim();
    return normalized.isEmpty ? 'reported_by_user' : normalized;
  }

  String normalizeCommunityText(String text) {
    var normalized = text.toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ắ': 'a',
      'ằ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ấ': 'a',
      'ầ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'è': 'e',
      'é': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ế': 'e',
      'ề': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'ì': 'i',
      'í': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ò': 'o',
      'ó': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ố': 'o',
      'ồ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ớ': 'o',
      'ờ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ứ': 'u',
      'ừ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
      'đ': 'd',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9+]+'), ' ');
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? validateCommunityText(
    String text, {
    required bool isComment,
    bool allowEmpty = false,
  }) {
    final trimmed = text.trim();
    final maxLength = isComment ? 180 : 300;
    if (trimmed.isEmpty) {
      if (allowEmpty) return null;
      return isComment
          ? 'Bình luận đang trống. Hãy viết vài dòng tử tế rồi gửi nhé.'
          : 'Bài viết đang trống. Hãy thêm nội dung hoặc ảnh trước khi đăng.';
    }
    if (trimmed.length > maxLength) {
      return isComment
          ? 'Bình luận chỉ nên tối đa $maxLength ký tự để dễ theo dõi.'
          : 'Bài viết chỉ nên tối đa $maxLength ký tự.';
    }

    final normalized = normalizeCommunityText(trimmed);
    final links = RegExp(r'(https?:\/\/|www\.)', caseSensitive: false)
        .allMatches(trimmed)
        .length;
    if (links > 1) {
      return 'Chỉ nên gắn tối đa 1 liên kết để tránh bị xem là spam.';
    }
    if (RegExp(r'(.)\1{7,}').hasMatch(normalized)) {
      return 'Nội dung có dấu hiệu spam ký tự lặp. Hãy viết rõ ràng hơn.';
    }
    return null;
  }

  bool containsBlockedCommunityTerms(String text) {
    final normalized = normalizeCommunityText(text);
    if (normalized.isEmpty) return false;
    for (final term in _blockedCommunityTerms) {
      if (normalized.contains(term)) {
        return true;
      }
    }
    return false;
  }

  Future<String> _resolveHouseLabel(String houseId) async {
    final normalized = houseId.trim();
    if (normalized.isEmpty) {
      return '';
    }

    final candidates = <String>[
      'houses/$normalized/settings/houseName',
      'houses/$normalized/houseName',
      'house_profiles/$normalized/houseName',
      'houses_public/$normalized/houseName',
    ];

    for (final path in candidates) {
      try {
        final snap = await _dbRef.child(path).get();
        final value = snap.value?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      } catch (_) {}
    }

    return normalized;
  }

  String _compactNotificationMessage(String value, {int maxLength = 160}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1)}…';
  }

  // [ĐÃ XÓA] Các hàm push notification cộng đồng cũ đã gỡ bỏ.
  Future<void> notifyPostLiked({
    required String postId,
    required String actorHouseId,
  }) async {}

  Future<void> notifyPostCommented({
    required String postId,
    required String actorHouseId,
    required String commentText,
  }) async {}

  Future<void> notifyCommentLiked({
    required String postId,
    required String commentId,
    required String actorHouseId,
  }) async {}


  // ── STREAM feed của 1 nhà ─────────────────────────────────────────────
  Future<List<SocialPost>> fetchHouseFeedPage(
    String houseId, {
    int limit = 10,
    int? endBeforeTs,
    bool includePrivate = false,
  }) async {
    var query = _firestore
        .collection('social_posts')
        .where('houseId', isEqualTo: houseId);
    if (!includePrivate) {
      query = query.where('privacy', isEqualTo: 'public');
    }
    query = query.orderBy('ts', descending: true).limit(limit);
    if (endBeforeTs != null) {
      query = query.where('ts', isLessThan: endBeforeTs);
    }
    final snap = await _getQueryWithCacheFallback(query);
    return snap.docs
        .map((doc) => SocialPost.fromJson(doc.id, doc.data()))
        .toList();
  }


  // ── XÓA bài ──────────────────────────────────────────────────────────
  Future<void> deletePost({
    required String postId,
    required String requestingHouseId,
  }) async {
    final normalizedPostId = postId.trim();
    final normalizedRequestingHouseId = requestingHouseId.trim();
    if (normalizedPostId.isEmpty) {
      throw 'Không tìm thấy bài viết cần xóa.';
    }
    if (normalizedPostId == '_legacy_delete_guard_') {
      throw 'Không tìm thấy bài viết cần xóa.';
    }

    // Load post from hybrid (Firestore/RTDB)
    final data = await _loadPostHybrid(normalizedPostId);
    if (data == null) {
      throw 'Bài viết không tồn tại.';
    }

    final postHouseId = (data['houseId'] ?? '').toString().trim();
    final legacyHouseId = (data['uid'] ?? '').toString().trim();
    final authorUid =
        (data['author_uid'] ?? data['authorUid'] ?? '').toString().trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final skipLegacyDeleteCheck =
        currentUid.isNotEmpty || normalizedRequestingHouseId.isNotEmpty;

    var canDelete = normalizedRequestingHouseId.isNotEmpty &&
        (normalizedRequestingHouseId == postHouseId ||
            normalizedRequestingHouseId == legacyHouseId);

    if (!canDelete && currentUid.isNotEmpty) {
      if (authorUid.isNotEmpty && authorUid == currentUid) {
        canDelete = true;
      } else {
        final managedHouseId =
            postHouseId.isNotEmpty ? postHouseId : legacyHouseId;
        if (managedHouseId.isNotEmpty) {
          final permissionChecks = await Future.wait([
            _dbRef.child('houses/$managedHouseId/owner_uid').get(),
            _dbRef.child('houses/$managedHouseId/members/$currentUid').get(),
            _dbRef.child('admins/$currentUid').get(),
          ]);
          final ownerUid = permissionChecks[0].value?.toString().trim() ?? '';
          final isMember = permissionChecks[1].exists;
          final isAdmin = permissionChecks[2].exists;
          canDelete = ownerUid == currentUid || isMember || isAdmin;
        }
      }
    }

    if (!canDelete) {
      throw 'Bạn không có quyền xóa bài viết này.';
    }

    if (!skipLegacyDeleteCheck &&
        data['houseId']?.toString() != requestingHouseId) {
      throw 'Bạn không có quyền xóa bài viết này.';
    }

    // Chỉ mục lượt thích cũ sẽ được người dùng dọn khi tải danh sách đã thích.
    // Không cho client của chủ bài xóa dữ liệu riêng của các nhà khác.
    await _firestore.collection('social_posts').doc(normalizedPostId).delete();
  }

  // ── TOGGLE LIKE (atomic) ──────────────────────────────────────────────
  Future<void> toggleLike({
    required String postId,
    required String myHouseId,
  }) async {
    await assertCanInteractWithPost(myHouseId: myHouseId, postId: postId);
    final docRef = _firestore.collection('social_posts').doc(postId);
    final likeRef = _firestore
        .collection('house_likes')
        .doc(myHouseId)
        .collection('posts')
        .doc(postId);
    var addedLike = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw 'Bài viết không tồn tại.';
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final currentLikesMap = _readMapField(data['likes_map']);
      final liked = currentLikesMap.containsKey(myHouseId);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (liked) {
        currentLikesMap.remove(myHouseId);
        transaction.delete(likeRef);
      } else {
        currentLikesMap[myHouseId] = {'by': myHouseId, 'ts': now};
        transaction.set(likeRef, {
          'houseId': myHouseId,
          'postId': postId,
          'likedAt': now,
        });
        addedLike = true;
      }

      transaction.update(docRef, {
        'likes_map': currentLikesMap,
        'likes': currentLikesMap.length,
      });
    });

    if (addedLike) {
      try {
        await notifyPostLiked(postId: postId, actorHouseId: myHouseId);
      } catch (_) {}
    }
  }

  // ── CHECK đã like chưa ───────────────────────────────────────────────
  Future<bool> hasLiked(String postId, String myHouseId) async {
    final postData = await _loadPostHybrid(postId);
    return postData != null &&
        _readMapField(postData['likes_map']).containsKey(myHouseId);
  }

  // ── STREAM like status realtime ───────────────────────────────────────
  Stream<bool> streamLikeStatus(String postId, String myHouseId) {
    return _firestore
        .collection('social_posts')
        .doc(postId)
        .snapshots()
        .map((snapshot) => snapshot.exists &&
            _readMapField(snapshot.data()?['likes_map'])
                .containsKey(myHouseId));
  }


  // ── DELETE COMMENT ──────────────────────────────────────────────────
  Future<void> deleteComment({
    required String commentId,
    required String postId,
    String? requestingHouseId,
  }) async {
    final docRef = _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final docSnap = await _getDocWithCacheFallback(docRef);

    final requester = requestingHouseId?.trim() ?? '';
    if (docSnap.exists) {
      final commentData = docSnap.data()!;
      if (requester.isNotEmpty) {
        final authorHouseId =
            (commentData['houseId'] ?? commentData['uid'] ?? '')
                .toString()
                .trim();
        final postDoc = await _getDocWithCacheFallback(
          _firestore.collection('social_posts').doc(postId),
        );
        final postOwnerHouseId =
            (postDoc.data()?['houseId'] ?? '').toString().trim();
        if (requester != authorHouseId && requester != postOwnerHouseId) {
          throw 'Bạn không có quyền xóa bình luận này.';
        }
      }
      await docRef.delete();
    }
  }

  // ── POST COMMENT ────────────────────────────────────────────────────
  Future<void> postComment({
    required String postId,
    required String houseId,
    required String content,
    String? authorName,
    String? authorAvt,
    String? replyTo,
    String? replyToName,
  }) async {
    final trimmedContent = content.trim();
    final validationError =
        validateCommunityText(trimmedContent, isComment: true);
    if (validationError != null) {
      throw validationError;
    }
    await assertCanInteractWithPost(myHouseId: houseId, postId: postId);
    final hasViolations = containsBlockedCommunityTerms(trimmedContent);

    // Resolve name and avt if not passed
    var resolvedName = authorName ?? '';
    var resolvedAvt = authorAvt ?? '';
    if (resolvedName.isEmpty) {
      resolvedName = await _resolveHouseLabel(houseId);
    }
    if (resolvedAvt.isEmpty) {
      try {
        final avtSnap =
            await _dbRef.child('houses/$houseId/settings/houseAvt').get();
        resolvedAvt = avtSnap.value?.toString() ?? '';
      } catch (_) {}
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final docRef = _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .doc();
    final commentId = docRef.id;

    final payload = {
      'id': commentId,
      'uid': houseId,
      'houseId': houseId,
      'u': resolvedName,
      'name': resolvedName,
      'author': resolvedName,
      'authorName': resolvedName,
      'content': trimmedContent,
      'c': trimmedContent,
      'text': trimmedContent,
      'ts': now,
      'reacts': 0,
      'isHidden': hasViolations,
      if (resolvedAvt.isNotEmpty) 'avt': resolvedAvt,
      if (resolvedAvt.isNotEmpty) 'authorAvt': resolvedAvt,
      if (replyTo != null) 'replyTo': replyTo,
      if (replyToName != null) 'replyToName': replyToName,
      'likes_map': <String, dynamic>{},
    };

    // Write to Firestore subcollection
    await docRef.set(payload);

    if (!hasViolations) {
      try {
        await notifyPostCommented(
          postId: postId,
          actorHouseId: houseId,
          commentText: trimmedContent,
        );
      } catch (_) {}
    }
  }

  // ── TOGGLE LIKE COMMENT ──────────────────────────────────────────────
  Future<void> toggleLikeComment({
    required String postId,
    required String commentId,
    required String myHouseId,
  }) async {
    final docRef = _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    bool liked = false;
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data() ?? {};
          final likesMap = Map<String, dynamic>.from(data['likes_map'] ?? {});
          liked = likesMap.containsKey(myHouseId);
          if (liked) {
            likesMap.remove(myHouseId);
          } else {
            likesMap[myHouseId] = {
              'ts': DateTime.now().millisecondsSinceEpoch,
              'by': myHouseId,
            };
          }
          transaction.update(docRef, {
            'likes_map': likesMap,
            'reacts': likesMap.length,
          });
        }
      });
    } catch (_) {}

    if (!liked) {
      try {
        await notifyCommentLiked(
          postId: postId,
          commentId: commentId,
          actorHouseId: myHouseId,
        );
      } catch (_) {}
    }
  }

  // ── REPORT POST ─────────────────────────────────────────────────────
  Future<void> reportPost({
    required String postId,
    required String reporterHouseId,
    required String reason,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.';
    }
    final postData = await _loadPostHybrid(postId);
    if (postData == null) {
      throw 'Bài viết không còn tồn tại.';
    }
    final targetHouseId = (postData['houseId'] ?? '').toString();
    await _firestore.collection('reports').add({
      'type': 'post_report',
      'postId': postId,
      'post': postId,
      'by': uid,
      'reporterHouseId': reporterHouseId,
      if (targetHouseId.isNotEmpty) 'targetHouseId': targetHouseId,
      'reason': _normalizeReportReason(reason),
      'status': 'open',
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reporterHouseId,
    required String reason,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.';
    }

    final commentData = await _loadCommentHybrid(postId, commentId);
    if (commentData == null) {
      throw 'Bình luận không còn tồn tại.';
    }
    final targetHouseId =
        (commentData['houseId'] ?? commentData['uid'] ?? '').toString();

    await _firestore.collection('reports').add({
      'type': 'comment_report',
      'postId': postId,
      'post': postId,
      'commentId': commentId,
      'by': uid,
      'reporterHouseId': reporterHouseId,
      if (targetHouseId.isNotEmpty) 'targetHouseId': targetHouseId,
      'reason': _normalizeReportReason(reason),
      'status': 'open',
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportUser({
    required String targetHouseId,
    required String reporterHouseId,
    required String reason,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.';
    }
    final target = targetHouseId.trim();
    final reporter = reporterHouseId.trim();
    if (target.isEmpty) {
      throw 'Không tìm thấy người dùng cần báo cáo.';
    }
    if (reporter.isEmpty) {
      throw 'Không tìm thấy nhà hiện tại để gửi báo cáo.';
    }
    if (target == reporter) {
      throw 'Bạn không thể tự báo cáo chính mình.';
    }

    await _firestore.collection('reports').add({
      'type': 'user_report',
      'targetHouseId': target,
      'target': target,
      'by': uid,
      'reporterHouseId': reporter,
      'reason': _normalizeReportReason(reason),
      'status': 'open',
      'ts': FieldValue.serverTimestamp(),
    });
  }


  // ── FETCH feed đã LIKE (Phân trang) ──────────────────────────────────
  Future<List<SocialPost>> fetchLikedFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    var query = _firestore
        .collection('house_likes')
        .doc(houseId)
        .collection('posts')
        .orderBy('likedAt', descending: true)
        .limit(limit);
    if (endBeforeTs != null) {
      query = query.where('likedAt', isLessThan: endBeforeTs);
    }
    final likedDocs = await _getQueryWithCacheFallback(query);
    if (likedDocs.docs.isEmpty) return [];

    final posts = <SocialPost>[];
    final futures = likedDocs.docs.map((likeDoc) => _firestore
        .collection('social_posts')
        .doc(likeDoc.id)
        .get());
    final docSnaps = await Future.wait(futures);

    final staleLikeRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (var index = 0; index < docSnaps.length; index += 1) {
      final doc = docSnaps[index];
      if (doc.exists && doc.data() != null) {
        try {
          posts.add(SocialPost.fromJson(doc.id, doc.data()!));
        } catch (_) {}
      } else {
        staleLikeRefs.add(likedDocs.docs[index].reference);
      }
    }
    if (staleLikeRefs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final reference in staleLikeRefs) {
        batch.delete(reference);
      }
      await batch.commit();
    }
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return posts;
  }

  // ── FETCH feed REPOST ───────────────────────────────────────────────
  Future<List<SocialPost>> fetchRepostFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    final posts = await fetchHouseFeedPage(houseId,
        limit: limit * 3, endBeforeTs: endBeforeTs);
    return posts.where((p) => p.isRepost).take(limit).toList();
  }

  // ── FETCH feed PRIVATE ──────────────────────────────────────────────
  Future<List<SocialPost>> fetchPrivateFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    final posts = await fetchHouseFeedPage(houseId,
        limit: limit * 3, endBeforeTs: endBeforeTs, includePrivate: true);
    return posts.where((p) => p.privacy == 'private').take(limit).toList();
  }

  // ── FETCH feed LOCKET ───────────────────────────────────────────────
  Future<List<SocialPost>> fetchLocketFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    var query = _firestore
        .collection('social_posts')
        .where('houseId', isEqualTo: houseId)
        .where('privacy', isEqualTo: 'public')
        .where('isLocket', isEqualTo: true)
        .orderBy('ts', descending: true)
        .limit(limit);
    if (endBeforeTs != null) {
      query = query.where('ts', isLessThan: endBeforeTs);
    }
    final snap = await _getQueryWithCacheFallback(query);
    return snap.docs
        .map((doc) => SocialPost.fromJson(doc.id, doc.data()))
        .toList();
  }

  // ── FETCH feed THEO LOẠI ─────────────────────────────────────────────
  Future<List<SocialPost>> fetchFeedByTypePage({
    required String feedType,
    String? houseId,
    int limit = 10,
    int? endBeforeTs,
  }) async {
    switch (feedType) {
      case 'liked':
        return houseId != null
            ? fetchLikedFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : const <SocialPost>[];
      case 'repost':
        return houseId != null
            ? fetchRepostFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : const <SocialPost>[];
      case 'private':
        return houseId != null
            ? fetchPrivateFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : const <SocialPost>[];
      case 'locket':
        return houseId != null
            ? fetchLocketFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : const <SocialPost>[];
      case 'hot':
        var query = _firestore
            .collection('social_posts')
            .where('privacy', isEqualTo: 'public')
            .orderBy('hotScore', descending: true)
            .limit(100);
        final snap = await _getQueryWithCacheFallback(query);
        final posts = snap.docs
            .map((doc) => SocialPost.fromJson(doc.id, doc.data()))
            .toList();
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (endBeforeTs != null) {
          posts.removeWhere(
              (p) => p.timestamp.millisecondsSinceEpoch >= endBeforeTs);
        }
        return posts.take(limit).toList();
      default:
        return const <SocialPost>[];
    }
  }

  // ── SCRIPT MIGRATION TỰ ĐỘNG CHO SOCIAL FEED ─────────────────────────
}
