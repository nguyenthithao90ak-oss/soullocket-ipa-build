import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/models/diary_post.dart';
import 'connectivity_service.dart';
import 'storage/diary_create_request_store.dart';

class DiaryQuota {
  const DiaryQuota({
    required this.plan,
    required this.isPro,
    required this.dayKey,
    required this.dailyLimit,
    required this.dailyUsed,
    required this.dailyRemaining,
    required this.totalLimit,
    required this.totalUsed,
    required this.totalRemaining,
  });

  final String plan;
  final bool isPro;
  final String dayKey;
  final int dailyLimit;
  final int dailyUsed;
  final int dailyRemaining;
  final int totalLimit;
  final int totalUsed;
  final int totalRemaining;

  bool get canCreate => dailyRemaining > 0 && totalRemaining > 0;

  factory DiaryQuota.fromMap(dynamic value) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};

    int readInt(String key) {
      final raw = map[key];
      if (raw is num) return raw.toInt().clamp(0, 2000000000);
      return int.tryParse(raw?.toString() ?? '')?.clamp(0, 2000000000) ?? 0;
    }

    return DiaryQuota(
      plan: map['plan']?.toString() == 'pro' ? 'pro' : 'free',
      isPro: map['isPro'] == true || map['plan']?.toString() == 'pro',
      dayKey: map['dayKey']?.toString() ?? '',
      dailyLimit: readInt('dailyLimit'),
      dailyUsed: readInt('dailyUsed'),
      dailyRemaining: readInt('dailyRemaining'),
      totalLimit: readInt('totalLimit'),
      totalUsed: readInt('totalUsed'),
      totalRemaining: readInt('totalRemaining'),
    );
  }
}

class DiaryQuotaException implements Exception {
  const DiaryQuotaException({required this.reason, this.quota});

  final String reason;
  final DiaryQuota? quota;

  bool get isDailyLimit => reason == 'daily';
  bool get isTotalLimit => reason == 'total';

  @override
  String toString() => 'DiaryQuotaException($reason)';
}

/// DiaryService — quản lý tâm tư (nhật ký) trong Firestore
/// Path: houses/{houseId}/diaries/{postId}
/// Các thao tác ghi bài đi qua Cloud Function để kiểm soát quota chung của House.
class DiaryService {
  static final DiaryService _instance = DiaryService._internal();

  factory DiaryService() => _instance;
  DiaryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Map<String, Future<String>> _createAttempts = {};

  HttpsCallable _diaryCallable() => _functions.httpsCallable(
        'diaryPostSecure',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

  Future<Map<String, dynamic>> _callDiary(Map<String, dynamic> payload) async {
    try {
      final result = await _diaryCallable().call(payload);
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw StateError('diary_invalid_server_response');
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        final details = error.details is Map
            ? Map<String, dynamic>.from(error.details as Map)
            : const <String, dynamic>{};
        throw DiaryQuotaException(
          reason: details['reason']?.toString() ??
              (error.message ?? '').trim(),
          quota: details['quota'] == null
              ? null
              : DiaryQuota.fromMap(details['quota']),
        );
      }
      rethrow;
    }
  }

  // ── LẤY Collection Reference ───────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _diariesRef(String houseId) {
    return _firestore.collection('houses').doc(houseId).collection('diaries');
  }

  // ── LISTEN realtime ────────────────────────────────────────────────────
  Stream<List<DiaryPost>> streamDiary(String houseId, {int limit = 80}) {
    return _diariesRef(houseId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final posts = <DiaryPost>[];
          for (var doc in snapshot.docs) {
            try {
              posts.add(DiaryPost.fromJson(doc.id, doc.data()));
            } catch (error) {
              debugPrint('[DiaryService] Bỏ qua bản ghi lỗi ${doc.id}: $error');
            }
          }
          return posts;
        });
  }

  // ── LISTEN bài viết được ghim realtime ───────────────────────────────────
  Stream<List<DiaryPost>> streamPinnedDiary(String houseId) {
    return _diariesRef(
      houseId,
    ).where('pinned', isEqualTo: true).limit(1).snapshots().map((snapshot) {
      final posts = <DiaryPost>[];
      for (var doc in snapshot.docs) {
        try {
          posts.add(DiaryPost.fromJson(doc.id, doc.data()));
        } catch (error) {
          debugPrint('[DiaryService] Bản ghi ghim lỗi ${doc.id}: $error');
        }
      }
      return posts;
    });
  }

  /// Đọc bài ghim một lần khi mở Nhật ký. Bài ghim không cần một listener
  /// riêng vì danh sách mới đã có listener realtime và controller sẽ hợp nhất
  /// hai nguồn theo ID.
  Future<List<DiaryPost>> fetchPinnedDiary(String houseId) async {
    final snapshot = await _diariesRef(
      houseId,
    ).where('pinned', isEqualTo: true).limit(1).get();
    final posts = <DiaryPost>[];
    for (final doc in snapshot.docs) {
      try {
        posts.add(DiaryPost.fromJson(doc.id, doc.data()));
      } catch (error) {
        debugPrint('[DiaryService] Bản ghi ghim lỗi ${doc.id}: $error');
      }
    }
    return posts;
  }

  // ── THÊM nhật ký mới (server kiểm quota) ───────────────────────────────
  Future<String> addDiaryPost({
    required String houseId,
    required String content,
    required String mood,
    required String authorId,
    required String authorName,
    String authorEmail = '',
    String authorRole = '',
    String imageUrl = '',
    String? customMoodUrl,
  }) async {
    if (content.trim().isEmpty) throw UiCopy.text('copy_94f373c96775');
    if (content.trim().length > 5000) {
      throw UiCopy.text('copy_d39050654d84');
    }

    void assertOwner() {
      if (FirebaseAuth.instance.currentUser?.uid != authorId) {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'diary_owner_changed',
        );
      }
    }

    assertOwner();
    final payload = <String, dynamic>{
      'action': 'create',
      'houseId': houseId,
      'content': _sanitize(content),
      'mood': mood,
      'authorId': authorId,
      'authorName': authorName,
      'authorEmail': authorEmail.trim(),
      'authorRole': authorRole.trim(),
      'imageUrl': imageUrl.trim(),
      if (customMoodUrl != null && customMoodUrl.trim().isNotEmpty)
        'customMoodUrl': customMoodUrl.trim(),
    };
    final store = DiaryCreateRequestStore(await SharedPreferences.getInstance());
    assertOwner();
    final request = await store.claim(
      uid: authorId,
      houseId: houseId,
      payload: payload,
    );
    assertOwner();
    final active = _createAttempts[request.fingerprint];
    if (active != null) return active;
    final attempt = () async {
      try {
        final data = await _callDiary({
          ...payload,
          'requestId': request.requestId,
          'expectedUid': authorId,
        });
        final postId = data['postId']?.toString().trim() ?? '';
        if (postId.isEmpty) throw StateError('diary_invalid_server_response');
        assertOwner();
        await store.complete(request);
        assertOwner();
        return postId;
      } catch (error) {
        // Lỗi mạng/timeout hoặc response chưa rõ giữ cùng ID cho lần gửi lại.
        final rejected = error is DiaryQuotaException ||
            (error is FirebaseFunctionsException &&
                const {
                  'invalid-argument',
                  'permission-denied',
                  'failed-precondition',
                  'not-found',
                  'unimplemented',
                }.contains(error.code));
        // Một lần retry bị từ chối không phủ nhận lần trước có thể đã commit.
        if (rejected && !request.wasPending) await store.complete(request);
        rethrow;
      }
    }();
    _createAttempts[request.fingerprint] = attempt;
    try {
      return await attempt;
    } finally {
      if (identical(_createAttempts[request.fingerprint], attempt)) {
        _createAttempts.remove(request.fingerprint);
      }
    }
  }

  // ── XÓA nhật ký ───────────────────────────────────────────────────────
  Future<void> deleteDiaryPost({
    required String houseId,
    required String postId,
    required String requestingAuthorId,
  }) async {
    final data = await _callDiary({
      'action': 'delete',
      'houseId': houseId,
      'postId': postId,
      'expectedUid': requestingAuthorId,
    });
    if (data['deleted'] != true) throw UiCopy.text('copy_eb757d247d81');
  }

  Future<DiaryQuota> fetchDiaryQuota(String houseId) async {
    final data = await _callDiary({
      'action': 'status',
      'houseId': houseId,
    });
    return DiaryQuota.fromMap(data['quota']);
  }

  // ── SỬA caption nhật ký ───────────────────────────────────────────────
  Future<void> updateDiaryContent({
    required String houseId,
    required String postId,
    required String newContent,
  }) async {
    if (newContent.trim().isEmpty) throw UiCopy.text('copy_94f373c96775');
    if (newContent.trim().length > 5000) {
      throw UiCopy.text('copy_d39050654d84');
    }
    await _diariesRef(houseId).doc(postId).update({
      'content': _sanitize(newContent),
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getQueryWithCacheFallback(
    Query<Map<String, dynamic>> query,
  ) async {
    // If we're offline, get from cache directly for instant UI
    if (!ConnectivityService().isOnline) {
      try {
        return await query.get(const GetOptions(source: Source.cache));
      } catch (error) {
        debugPrint('[DiaryService] Không đọc được cache offline: $error');
      }
    }

    try {
      // Mạng yếu nhưng chưa được xác định là offline: không để UI chờ vô hạn,
      // quá hạn thì dùng bản cache đã lưu trên máy.
      return await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return await query.get(const GetOptions(source: Source.cache));
    }
  }

  // ── LẤY 1 lần (không stream) ──────────────────────────────────────────
  Future<List<DiaryPost>> fetchDiary(String houseId, {int limit = 80}) async {
    final snap = await _getQueryWithCacheFallback(
      _diariesRef(houseId).orderBy('timestamp', descending: true).limit(limit),
    );

    final posts = <DiaryPost>[];
    for (var doc in snap.docs) {
      try {
        posts.add(DiaryPost.fromJson(doc.id, doc.data()));
      } catch (error) {
        debugPrint('[DiaryService] Bỏ qua bản ghi lỗi ${doc.id}: $error');
      }
    }
    return posts;
  }

  // ── LẤY theo trang (phân trang) ─────────────────────────────────────────
  Future<
    ({
      List<DiaryPost> posts,
      DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      bool hasMore,
    })
  >
  fetchDiaryPage(
    String houseId, {
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _diariesRef(
      houseId,
    ).orderBy('timestamp', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await _getQueryWithCacheFallback(query);
    final posts = <DiaryPost>[];
    for (var doc in snap.docs) {
      try {
        posts.add(DiaryPost.fromJson(doc.id, doc.data()));
      } catch (error) {
        debugPrint('[DiaryService] Bỏ qua bản ghi trang lỗi ${doc.id}: $error');
      }
    }

    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    final hasMore = snap.docs.length == limit;

    return (posts: posts, lastDoc: lastDoc, hasMore: hasMore);
  }

  // ── Sanitize input ────────────────────────────────────────────────────
  String _sanitize(String input) {
    return input.replaceAll('<', '&lt;').replaceAll('>', '&gt;').trim();
  }

  // ── SCRIPT MIGRATION TỰ ĐỘNG ──────────────────────────────────────────
  Future<void> migrateDiariesFromRTDB(String houseId) async {
    await _callDiary({'action': 'migrate', 'houseId': houseId});
  }
}
