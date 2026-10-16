import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:firebase_database/firebase_database.dart'
    hide Query, Transaction;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/models/diary_post.dart';
import 'connectivity_service.dart';

/// DiaryService — quản lý tâm tư (nhật ký) trong Firestore
/// Path: houses/{houseId}/diaries/{postId}
/// Hỗ trợ Offline: Firestore tự động hỗ trợ bộ nhớ đệm (offline persistence).
class DiaryService {
  static final DiaryService _instance = DiaryService._internal();

  factory DiaryService() => _instance;
  DiaryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

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

  // ── THÊM nhật ký mới (có fallback offline) ─────────────────────────────
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

    final now = DateTime.now().millisecondsSinceEpoch;
    final postData = {
      'content': _sanitize(content),
      'mood': mood,
      if (customMoodUrl != null && customMoodUrl.trim().isNotEmpty)
        'customMoodUrl': customMoodUrl.trim(),
      'authorId': authorId,
      'authorName': authorName,
      if (authorEmail.trim().isNotEmpty) 'authorEmail': authorEmail.trim(),
      if (authorRole.trim().isNotEmpty) 'authorRole': authorRole.trim(),
      'imageUrl': imageUrl,
      'ts': now,
      'timestamp': now,
      'role': authorRole.trim().isNotEmpty ? authorRole.trim() : authorId,
    };

    // Firestore tự động hỗ trợ offline queue!
    final docRef = await _diariesRef(houseId).add(postData);
    return docRef.id;
  }

  // ── XÓA nhật ký ───────────────────────────────────────────────────────
  Future<void> deleteDiaryPost({
    required String houseId,
    required String postId,
    required String requestingAuthorId,
  }) async {
    final docRef = _diariesRef(houseId).doc(postId);
    final snap = await docRef.get();
    if (!snap.exists) throw UiCopy.text('copy_eb757d247d81');

    final data = snap.data()!;
    final owner = (data['authorId'] ?? '').toString();
    if (owner.isNotEmpty && owner != requestingAuthorId) {
      throw UiCopy.text('copy_83cbf45152c9');
    }
    await docRef.delete();
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
    // Chỉ migrate nếu chưa từng migrate — dùng flag nhẹ
    final migrateFlag = await _firestore
        .collection('houses')
        .doc(houseId)
        .collection('_meta')
        .doc('diary_migration')
        .get();
    if (migrateFlag.exists && migrateFlag.data()?['done'] == true) return;

    final snap = await _rtdb.child('houses/$houseId/diary').get();
    if (!snap.exists || snap.value == null) {
      // Ghi flag để không gọi lại
      try {
        await _firestore
            .collection('houses')
            .doc(houseId)
            .collection('_meta')
            .doc('diary_migration')
            .set({'done': true, 'ts': DateTime.now().millisecondsSinceEpoch});
      } catch (error) {
        debugPrint('[DiaryService] Không ghi được cờ migration rỗng: $error');
      }
      return;
    }

    final raw = snap.value;
    if (raw is! Map) return;

    final batch = _firestore.batch();
    int count = 0;

    raw.forEach((key, value) {
      if (value is Map) {
        final docRef = _diariesRef(houseId).doc(key.toString());
        batch.set(
          docRef,
          Map<String, dynamic>.from(value),
          SetOptions(merge: true),
        );
        count++;
      }
    });

    if (count > 0) {
      await batch.commit();
      // Xoá diary cũ trên RTDB để không tốn bandwidth nữa
      try {
        await _rtdb.child('houses/$houseId/diary').remove();
      } catch (error) {
        debugPrint('[DiaryService] Không xóa được dữ liệu RTDB cũ: $error');
      }
    }
    // Ghi flag
    try {
      await _firestore
          .collection('houses')
          .doc(houseId)
          .collection('_meta')
          .doc('diary_migration')
          .set({'done': true, 'ts': DateTime.now().millisecondsSinceEpoch});
    } catch (error) {
      debugPrint('[DiaryService] Không ghi được cờ hoàn tất migration: $error');
    }
  }
}
