import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Query, Transaction;
import 'package:soullocket_app/models/social_post.dart';
import 'push_notification_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SocialService — Quản lý social feed cộng đồng
/// Hybrid model:
///   Firestore: `social_posts/{postId}` — bài đăng, comments (subcollection), phân trang
///   RTDB:      `social_feed/{postId}` — stream realtime (chỉ listen bài mới nhất)
///              `post_likes`, `house_likes`, `houses/...` — metadata nhẹ
class SocialService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<Map<String, dynamic>?> _loadMap(String path) async {
    final snap = await _dbRef.child(path).get();
    if (!snap.exists || snap.value is! Map) return null;
    return Map<String, dynamic>.from(
        Map<dynamic, dynamic>.from(snap.value as Map));
  }

  /// Tải bài đăng từ Firestore trước, fallback sang RTDB nếu không có
  Future<Map<String, dynamic>?> _loadPostHybrid(String postId) async {
    try {
      final doc = await _firestore.collection('social_posts').doc(postId).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = postId;
        return data;
      }
    } catch (_) {}
    // Fallback RTDB (bài cũ chưa migrate)
    return _loadMap('social_feed/$postId');
  }

  /// Tải bình luận từ Firestore trước, fallback sang RTDB nếu không có
  Future<Map<String, dynamic>?> _loadCommentHybrid(String postId, String commentId) async {
    try {
      final doc = await _firestore
          .collection('social_posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = commentId;
        return data;
      }
    } catch (_) {}
    return _loadMap('social_feed/$postId/comments/$commentId');
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
    final results = await Future.wait([
      _dbRef.child('houses/$sourceHouseId/blocked_users/$targetHouseId').get(),
      _dbRef.child('houses/$targetHouseId/blocked_users/$sourceHouseId').get(),
    ]);
    return results.any((snap) => snap.value == true);
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

  Future<void> _pushCommunityNotification({
    required String toHouseId,
    required String fromHouseId,
    required String type,
    required String title,
    required String message,
    String? postId,
  }) async {
    final target = toHouseId.trim();
    final actor = fromHouseId.trim();
    if (target.isEmpty || actor.isEmpty || target == actor) {
      return;
    }

    final fromName = await _resolveHouseLabel(actor);
    await PushNotificationHelper.push(
      toHouseId: target,
      type: type,
      from: actor,
      fromId: actor,
      fromLabel: fromName,
      msg: _compactNotificationMessage(message),
      title: title,
      postId: postId,
      extra: const <String, dynamic>{
        'category': 'social',
        'section': 'community',
      },
    );
  }

  Future<void> notifyPostLiked({
    required String postId,
    required String actorHouseId,
  }) async {
    final postData = await _loadPostHybrid(postId);
    if (postData == null) {
      return;
    }

    final targetHouseId = (postData['houseId'] ?? '').toString().trim();
    await _pushCommunityNotification(
      toHouseId: targetHouseId,
      fromHouseId: actorHouseId,
      type: 'like',
      title: 'Lượt thích mới',
      message: 'đã thích bài đăng cộng đồng của bạn.',
      postId: postId,
    );
  }

  Future<void> notifyPostCommented({
    required String postId,
    required String actorHouseId,
    required String commentText,
  }) async {
    final postData = await _loadPostHybrid(postId);
    if (postData == null) {
      return;
    }

    final targetHouseId = (postData['houseId'] ?? '').toString().trim();
    await _pushCommunityNotification(
      toHouseId: targetHouseId,
      fromHouseId: actorHouseId,
      type: 'comment',
      title: 'Bình luận mới',
      message: commentText,
      postId: postId,
    );
  }

  Future<void> notifyCommentLiked({
    required String postId,
    required String commentId,
    required String actorHouseId,
  }) async {
    final commentData =
        await _loadCommentHybrid(postId, commentId);
    if (commentData == null || commentData['isHidden'] == true) {
      return;
    }

    final targetHouseId =
        (commentData['houseId'] ?? commentData['uid'] ?? '').toString().trim();
    await _pushCommunityNotification(
      toHouseId: targetHouseId,
      fromHouseId: actorHouseId,
      type: 'like',
      title: 'Lượt thích mới',
      message: 'đã thích bình luận cộng đồng của bạn.',
      postId: postId,
    );
  }

  // ── STREAM feed global (mới nhất) bằng onChildAdded ──────────────────
  Stream<SocialPost> streamNewGlobalFeed({int? afterTs}) {
    Query query = _dbRef.child('social_feed').orderByChild('ts');
    if (afterTs != null) {
      query = query.startAt(afterTs);
    }
    return query.onChildAdded.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        throw StateError('Invalid post');
      }
      return SocialPost.fromJson(
        event.snapshot.key!,
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  // ── STREAM cập nhật 1 post (lắng nghe like/comment realtime) ─────────
  Stream<SocialPost?> streamPostUpdates(String postId) {
    return _dbRef.child('social_feed/$postId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      return SocialPost.fromJson(
        event.snapshot.key!,
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  // ── STREAM feed của 1 nhà ─────────────────────────────────────────────
  Future<List<SocialPost>> fetchHouseFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    try {
      var query = _firestore
          .collection('social_posts')
          .where('houseId', isEqualTo: houseId)
          .orderBy('ts', descending: true)
          .limit(limit);
      if (endBeforeTs != null) {
        query = query.where('ts', isLessThan: endBeforeTs);
      }
      final snap = await query.get();
      return snap.docs
          .map((doc) => SocialPost.fromJson(doc.id, doc.data()))
          .toList();
    } catch (_) {
      Query query =
          _dbRef.child('social_feed').orderByChild('houseId').equalTo(houseId);
      final snap = await query.get();
      if (!snap.exists) return [];

      // Do Firebase Realtime Database không hỗ trợ multiple orderBy (cả houseId và ts),
      // chúng ta phải sort ở client và cắt page.
      final posts = _parseFeed(snap.value);
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (endBeforeTs != null) {
        posts.removeWhere(
            (p) => p.timestamp.millisecondsSinceEpoch >= endBeforeTs);
      }

      return posts.take(limit).toList();
    }
  }

  // ── LẤY 1 lần ────────────────────────────────────────────────────────
  Future<List<SocialPost>> fetchGlobalFeed({int limit = 10}) async {
    try {
      final snap = await _firestore
          .collection('social_posts')
          .orderBy('ts', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) => SocialPost.fromJson(doc.id, doc.data()))
          .toList();
    } catch (_) {
      final snap = await _dbRef
          .child('social_feed')
          .orderByChild('ts')
          .limitToLast(limit)
          .get();
      final posts = _parseFeed(snap.value);
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    }
  }

  Future<List<SocialPost>> fetchGlobalFeedPage({
    int limit = 20,
    int? endBeforeTs,
  }) async {
    try {
      var query = _firestore
          .collection('social_posts')
          .orderBy('ts', descending: true)
          .limit(limit);
      if (endBeforeTs != null) {
        query = query.where('ts', isLessThan: endBeforeTs);
      }
      final snap = await query.get();
      return snap.docs
          .map((doc) => SocialPost.fromJson(doc.id, doc.data()))
          .toList();
    } catch (_) {
      Query query = _dbRef.child('social_feed').orderByChild('ts');
      if (endBeforeTs != null) {
        query = query.endAt(endBeforeTs - 1);
      }
      final snap = await query.limitToLast(limit).get();
      final posts = _parseFeed(snap.value);
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    }
  }

  // ── ĐĂNG bài mới ─────────────────────────────────────────────────────
  Future<String> createPost({
    required String houseId,
    required String houseName,
    required String authorRole,
    required String authorName,
    required String authorAvt,
    required String content,
    String imageUrl = '',
    String videoUrl = '',
    String privacy = 'public',
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty && imageUrl.isEmpty && videoUrl.isEmpty) {
      throw 'Nội dung bài đăng không được để trống.';
    }

    final validationError = validateCommunityText(
      trimmedContent,
      isComment: false,
      allowEmpty: imageUrl.isNotEmpty || videoUrl.isNotEmpty,
    );
    if (validationError != null) {
      throw validationError;
    }
    final flagged = containsBlockedCommunityTerms(trimmedContent);
    final resolvedPrivacy = flagged ? 'private' : privacy;

    final now = DateTime.now().millisecondsSinceEpoch;
    final newRef = _dbRef.child('social_feed').push();
    final postId = newRef.key!;

    final postData = {
      'houseId': houseId,
      'houseName': houseName,
      'authorRole': authorRole,
      'authorName': authorName,
      'authorAvt': authorAvt,
      'houseAvt': authorAvt,
      'content': trimmedContent,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'likes': 0,
      'commentCount': 0,
      'shareCount': 0,
      'hotScore': 0,
      'ts': now,
      'privacy': resolvedPrivacy,
      'visibility': resolvedPrivacy,
      if (flagged) 'moderationStatus': 'flagged',
      'isRepost': false,
      'id': postId,
    };

    // Ghi nhận vào Firestore
    await _firestore.collection('social_posts').doc(postId).set(postData);

    // Ghi nhận vào RTDB để stream hoạt động
    await newRef.set(postData);

    return postId;
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

    final cleanupHouseIds = <String>{
      ..._readMapField(data['likes_map']).keys.map((key) => key.trim()),
    }..removeWhere((houseId) => houseId.isEmpty);

    final legacyPostLikesSnap =
        await _dbRef.child('post_likes/$normalizedPostId').get();
    if (legacyPostLikesSnap.value is Map) {
      cleanupHouseIds.addAll(
        Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(legacyPostLikesSnap.value as Map),
        ).keys.map((key) => key.trim()).where((houseId) => houseId.isNotEmpty),
      );
    }
    if (!skipLegacyDeleteCheck &&
        data['houseId']?.toString() != requestingHouseId) {
      throw 'Bạn không có quyền xóa bài viết này.';
    }

    // Xóa khỏi Firestore
    await _firestore.collection('social_posts').doc(normalizedPostId).delete();

    // Xóa khỏi RTDB
    final updates = <String, Object?>{
      'social_feed/$normalizedPostId': null,
      'post_likes/$normalizedPostId': null,
    };
    for (final houseId in cleanupHouseIds) {
      updates['house_likes/$houseId/$normalizedPostId'] = null;
    }
    await _dbRef.update(updates);
  }

  // ── TOGGLE LIKE (atomic) ──────────────────────────────────────────────
  Future<void> toggleLike({
    required String postId,
    required String myHouseId,
  }) async {
    await assertCanInteractWithPost(myHouseId: myHouseId, postId: postId);
    final postData = await _loadMap('social_feed/$postId');
    if (postData == null) {
      throw 'Bài viết không tồn tại.';
    }

    final likesMap = _readMapField(postData['likes_map']);
    final legacyLikeSnaps = await Future.wait([
      _dbRef.child('post_likes/$postId/$myHouseId').get(),
      _dbRef.child('house_likes/$myHouseId/$postId').get(),
    ]);
    final liked = likesMap.containsKey(myHouseId) ||
        legacyLikeSnaps.any((snap) => snap.exists);
    final storedLikes = postData['likes'];
    final currentLikes =
        storedLikes is num ? storedLikes.toInt() : likesMap.length;
    final nextLikes =
        liked ? (currentLikes > 0 ? currentLikes - 1 : 0) : currentLikes + 1;
    final updates = <String, Object?>{
      'post_likes/$postId/$myHouseId': liked ? null : true,
      'house_likes/$myHouseId/$postId': liked ? null : ServerValue.timestamp,
      'social_feed/$postId/likes_map/$myHouseId': liked
          ? null
          : {
              'by': myHouseId,
              'ts': ServerValue.timestamp,
            },
      'social_feed/$postId/likes': nextLikes,
    };

    await _dbRef.update(updates);

    // Update Firestore likes and likes_map
    try {
      final docRef = _firestore.collection('social_posts').doc(postId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data() ?? <String, dynamic>{};
          final currentLikesMap = Map<String, dynamic>.from(data['likes_map'] ?? <String, dynamic>{});
          if (liked) {
            currentLikesMap.remove(myHouseId);
          } else {
            currentLikesMap[myHouseId] = {
              'by': myHouseId,
              'ts': DateTime.now().millisecondsSinceEpoch,
            };
          }
          transaction.update(docRef, {
            'likes_map': currentLikesMap,
            'likes': currentLikesMap.length,
          });
        }
      });
    } catch (_) {}

    if (!liked) {
      try {
        await notifyPostLiked(postId: postId, actorHouseId: myHouseId);
      } catch (_) {}
    }
  }

  // ── CHECK đã like chưa ───────────────────────────────────────────────
  Future<bool> hasLiked(String postId, String myHouseId) async {
    final postData = await _loadMap('social_feed/$postId');
    if (postData != null &&
        _readMapField(postData['likes_map']).containsKey(myHouseId)) {
      return true;
    }

    final snaps = await Future.wait([
      _dbRef.child('post_likes/$postId/$myHouseId').get(),
      _dbRef.child('house_likes/$myHouseId/$postId').get(),
    ]);
    return snaps.any((snap) => snap.exists);
  }

  // ── STREAM like status realtime ───────────────────────────────────────
  Stream<bool> streamLikeStatus(String postId, String myHouseId) {
    return _dbRef.child('post_likes/$postId/$myHouseId').onValue.map(
          (event) => event.snapshot.exists,
        );
  }

  // ── Parse raw Firebase map → List<SocialPost> ─────────────────────────
  List<SocialPost> _parseFeed(Object? raw) {
    if (raw == null || raw is! Map) return [];
    final posts = <SocialPost>[];
    raw.forEach((key, value) {
      if (value is Map) {
        try {
          posts.add(SocialPost.fromJson(key.toString(), value));
        } catch (_) {}
      }
    });
    return posts;
  }

  // ── Unified Post Creation (Firebase only) ─────────────────────
  Future<String> createPostUnified({
    required String houseId,
    required String houseName,
    required String authorRole,
    required String authorName,
    required String authorAvt,
    required String content,
    String imageUrl = '',
    String videoUrl = '',
    String privacy = 'public',
    String mood = '',
    String moodEmoji = '',
    String location = '',
    String postType = 'mood',
    bool isAnon = false,
    bool isLocket = false,
    bool commentsEnabled = true,
  }) async {
    try {
      final trimmedContent = content.trim();
      if (trimmedContent.isEmpty &&
          imageUrl.trim().isEmpty &&
          videoUrl.trim().isEmpty) {
        throw 'Nội dung bài đăng không được để trống.';
      }
      final validationError = validateCommunityText(
        trimmedContent,
        isComment: false,
        allowEmpty: imageUrl.trim().isNotEmpty || videoUrl.trim().isNotEmpty,
      );
      if (validationError != null) {
        throw validationError;
      }
      final flagged = containsBlockedCommunityTerms(trimmedContent);
      final resolvedPrivacy = flagged ? 'private' : privacy;
      final normalizedPostType = postType.trim().isEmpty
          ? (isAnon
              ? 'confession'
              : imageUrl.trim().isNotEmpty
                  ? 'polaroid'
                  : 'mood')
          : postType.trim();
      final normalizedIsAnon =
          isAnon || normalizedPostType.toLowerCase() == 'confession';
      final now = DateTime.now().millisecondsSinceEpoch;
      final newRef = _dbRef.child('social_feed').push();
      final postId = newRef.key!;

      final postData = {
        'houseId': houseId,
        'houseName': houseName,
        'author_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'authorRole': authorRole,
        'authorName': authorName,
        'authorAvt': authorAvt,
        'houseAvt': authorAvt,
        'content': trimmedContent,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'likes': 0,
        'commentCount': 0,
        'shareCount': 0,
        'hotScore': 0,
        'ts': now,
        'privacy': resolvedPrivacy,
        'visibility': resolvedPrivacy,
        'mood': mood,
        'moodEmoji': moodEmoji,
        'location': location,
        'postType': normalizedPostType,
        'isAnon': normalizedIsAnon,
        'isLocket': isLocket,
        'commentsEnabled': commentsEnabled,
        if (flagged) 'moderationStatus': 'flagged',
        'isRepost': false,
        'id': postId,
      };

      // Ghi nhận vào Firestore
      await _firestore.collection('social_posts').doc(postId).set(postData);

      // Ghi nhận vào RTDB
      await newRef.set(postData);

      // Ghi nhận hashtag
      final exp = RegExp(r'\B#(\w+)');
      final matches = exp.allMatches(trimmedContent);
      final uniqueTags = matches.map((m) => m.group(1)!.toLowerCase()).toSet();
      for (final tag in uniqueTags) {
        if (tag.isNotEmpty) {
          _dbRef.child('hashtags/$tag/count').set(ServerValue.increment(1));
        }
      }

      return postId;
    } catch (e) {
      throw 'Không thể đăng bài: $e';
    }
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
    final docSnap = await docRef.get();

    final requester = requestingHouseId?.trim() ?? '';
    if (docSnap.exists) {
      final commentData = docSnap.data()!;
      if (requester.isNotEmpty) {
        final authorHouseId = (commentData['houseId'] ?? commentData['uid'] ?? '')
            .toString()
            .trim();
        final postDoc = await _firestore.collection('social_posts').doc(postId).get();
        final postOwnerHouseId = (postDoc.data()?['houseId'] ?? '').toString().trim();
        if (requester != authorHouseId && requester != postOwnerHouseId) {
          throw 'Bạn không có quyền xóa bình luận này.';
        }
      }
      await docRef.delete();
      await _firestore
          .collection('social_posts')
          .doc(postId)
          .update({'commentCount': FieldValue.increment(-1)});
    }

    // Also remove from RTDB
    await _dbRef.child('social_feed/$postId/comments/$commentId').remove();
    await _dbRef
        .child('social_feed/$postId/commentCount')
        .set(ServerValue.increment(-1));
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
        final avtSnap = await _dbRef.child('houses/$houseId/settings/houseAvt').get();
        resolvedAvt = avtSnap.value?.toString() ?? '';
      } catch (_) {}
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newCommentRef = _dbRef.child('social_feed/$postId/comments').push();
    final commentId = newCommentRef.key!;

    final payload = {
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
    await _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .set(payload);

    // Update commentCount on Firestore
    await _firestore
        .collection('social_posts')
        .doc(postId)
        .update({'commentCount': FieldValue.increment(1)});

    // Write to RTDB
    await newCommentRef.set(payload);
    await _dbRef
        .child('social_feed/$postId/commentCount')
        .set(ServerValue.increment(1));

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
          transaction.update(docRef, {'likes_map': likesMap});
        }
      });
    } catch (_) {}

    // Also update RTDB
    try {
      final commentLikeRef = _dbRef.child(
          'social_feed/$postId/comments/$commentId/likes_map/$myHouseId');
      final isLikedSnap = await commentLikeRef.get();
      if (isLikedSnap.exists) {
        await commentLikeRef.remove();
      } else {
        await commentLikeRef.set({
          'ts': ServerValue.timestamp,
          'by': myHouseId,
        });

        try {
          await notifyCommentLiked(
            postId: postId,
            commentId: commentId,
            actorHouseId: myHouseId,
          );
        } catch (_) {}
      }
    } catch (_) {}
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
    await _dbRef.child('reports').push().set({
      'type': 'post_report',
      'postId': postId,
      'post': postId,
      'by': uid,
      'reporterHouseId': reporterHouseId,
      if (targetHouseId.isNotEmpty) 'targetHouseId': targetHouseId,
      'reason': _normalizeReportReason(reason),
      'status': 'open',
      'ts': ServerValue.timestamp,
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

    final commentData =
        await _loadCommentHybrid(postId, commentId);
    if (commentData == null) {
      throw 'Bình luận không còn tồn tại.';
    }
    final targetHouseId =
        (commentData['houseId'] ?? commentData['uid'] ?? '').toString();

    await _dbRef.child('reports').push().set({
      'type': 'comment_report',
      'postId': postId,
      'post': postId,
      'commentId': commentId,
      'by': uid,
      'reporterHouseId': reporterHouseId,
      if (targetHouseId.isNotEmpty) 'targetHouseId': targetHouseId,
      'reason': _normalizeReportReason(reason),
      'status': 'open',
      'ts': ServerValue.timestamp,
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

    await _dbRef.child('reports').push().set({
      'type': 'user_report',
      'targetHouseId': target,
      'target': target,
      'by': uid,
      'reporterHouseId': reporter,
      'reason': _normalizeReportReason(reason),
      'status': 'open',
      'ts': ServerValue.timestamp,
    });
  }

  Stream<SocialPost> streamUnifiedFeed({int? afterTs}) {
    return streamNewGlobalFeed(afterTs: afterTs);
  }

  Future<List<SocialPost>> fetchUnifiedFeedPage({
    int limit = 20,
    int? endBeforeTs,
  }) {
    return fetchGlobalFeedPage(limit: limit, endBeforeTs: endBeforeTs);
  }

  // ── FETCH feed đã LIKE (Phân trang) ──────────────────────────────────
  Future<List<SocialPost>> fetchLikedFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    final snap = await _dbRef.child('house_likes/$houseId').get();
    if (!snap.exists || snap.value is! Map) return [];

    final data = snap.value as Map;
    final likedItems = data.entries
        .map((e) => {
              'postId': e.key.toString(),
              'ts': (e.value is num) ? (e.value as num).toInt() : 0,
            })
        .toList();

    likedItems.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));

    if (endBeforeTs != null) {
      likedItems.removeWhere((item) => (item['ts'] as int) >= endBeforeTs);
    }

    final pageItems = likedItems.take(limit).toList();
    if (pageItems.isEmpty) return [];

    final posts = <SocialPost>[];
    final futures = pageItems
        .map((item) => _dbRef.child('social_feed/${item['postId']}').get());
    final snaps = await Future.wait(futures);

    for (var s in snaps) {
      if (s.exists && s.value is Map) {
        try {
          posts.add(SocialPost.fromJson(s.key!, s.value as Map));
        } catch (_) {}
      }
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
        limit: limit * 3, endBeforeTs: endBeforeTs);
    return posts.where((p) => p.privacy == 'private').take(limit).toList();
  }

  // ── FETCH feed LOCKET ───────────────────────────────────────────────
  Future<List<SocialPost>> fetchLocketFeedPage(String houseId,
      {int limit = 10, int? endBeforeTs}) async {
    Query query =
        _dbRef.child('social_feed').orderByChild('isLocket').equalTo(true);
    final snap = await query.get();
    if (!snap.exists) return [];
    final posts = _parseFeed(snap.value);
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (endBeforeTs != null) {
      posts.removeWhere(
          (p) => p.timestamp.millisecondsSinceEpoch >= endBeforeTs);
    }
    return posts.take(limit).toList();
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
            : fetchGlobalFeedPage(limit: limit, endBeforeTs: endBeforeTs);
      case 'repost':
        return houseId != null
            ? fetchRepostFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : fetchGlobalFeedPage(limit: limit, endBeforeTs: endBeforeTs);
      case 'private':
        return houseId != null
            ? fetchPrivateFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : fetchGlobalFeedPage(limit: limit, endBeforeTs: endBeforeTs);
      case 'locket':
        return houseId != null
            ? fetchLocketFeedPage(houseId,
                limit: limit, endBeforeTs: endBeforeTs)
            : fetchGlobalFeedPage(limit: limit, endBeforeTs: endBeforeTs);
      case 'hot':
        Query query = _dbRef.child('social_feed').orderByChild('hotScore');
        final snap = await query.limitToLast(100).get();
        if (!snap.exists) return [];
        final posts = _parseFeed(snap.value);
        posts.sort((a, b) => b.hotScore.compareTo(a.hotScore));
        // Sort theo timestamp để cắt trang đúng cách
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (endBeforeTs != null) {
          posts.removeWhere(
              (p) => p.timestamp.millisecondsSinceEpoch >= endBeforeTs);
        }
        return posts.take(limit).toList();
      default:
        return fetchGlobalFeedPage(limit: limit, endBeforeTs: endBeforeTs);
    }
  }

  // ── SCRIPT MIGRATION TỰ ĐỘNG CHO SOCIAL FEED ─────────────────────────
  Future<void> migrateSocialFeedFromRTDB(String houseId) async {
    final trimmedHouseId = houseId.trim();
    if (trimmedHouseId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final migrationKey = 'social_feed_migrated_$trimmedHouseId';
    if (prefs.getBool(migrationKey) == true) return;

    try {
      final snap = await _dbRef
          .child('social_feed')
          .orderByChild('houseId')
          .equalTo(trimmedHouseId)
          .get();

      if (!snap.exists || snap.value is! Map) {
        await prefs.setBool(migrationKey, true);
        return;
      }

      final rawFeed = snap.value as Map;
      for (final entry in rawFeed.entries) {
        final postId = entry.key.toString();
        final postVal = entry.value;
        if (postVal is! Map) continue;

        final postData = Map<String, dynamic>.from(postVal);
        postData['id'] = postId;

        // 1. Write the post to Firestore
        await _firestore.collection('social_posts').doc(postId).set(postData, SetOptions(merge: true));

        // 2. Fetch and migrate comments for this post if any exist on RTDB
        final commentsSnap = await _dbRef.child('social_feed/$postId/comments').get();
        if (commentsSnap.exists && commentsSnap.value is Map) {
          final rawComments = commentsSnap.value as Map;
          final batch = _firestore.batch();
          int commentCount = 0;

          rawComments.forEach((commentKey, commentVal) {
            if (commentVal is Map) {
              final commentId = commentKey.toString();
              final commentData = Map<String, dynamic>.from(commentVal);
              commentData['id'] = commentId;

              final commentDocRef = _firestore
                  .collection('social_posts')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId);
              batch.set(commentDocRef, commentData, SetOptions(merge: true));
              commentCount++;
            }
          });

          if (commentCount > 0) {
            await batch.commit();
          }
        }
      }

      await prefs.setBool(migrationKey, true);
    } catch (_) {}
  }
}
