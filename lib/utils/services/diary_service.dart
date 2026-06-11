import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
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
  Stream<List<DiaryPost>> streamDiary(String houseId) {
    return _diariesRef(houseId)
        .orderBy('ts', descending: true)
        .limit(AppConfig.diaryPageSize)
        .snapshots()
        .map((snapshot) {
      final posts = <DiaryPost>[];
      for (var doc in snapshot.docs) {
        try {
          posts.add(DiaryPost.fromJson(doc.id, doc.data()));
        } catch (_) {}
      }
      return posts;
    });
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
  }) async {
    if (content.trim().isEmpty) throw 'Nội dung không được để trống.';

    final now = DateTime.now().millisecondsSinceEpoch;
    final postData = {
      'content': _sanitize(content),
      'mood': mood,
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
    if (!snap.exists) throw 'Bài viết không tồn tại.';
    
    final data = snap.data()!;
    final owner = (data['authorId'] ?? '').toString();
    if (owner.isNotEmpty && owner != requestingAuthorId) {
      throw 'Bạn không có quyền xóa bài viết này.';
    }
    await docRef.delete();
  }

  // ── SỬA caption nhật ký ───────────────────────────────────────────────
  Future<void> updateDiaryContent({
    required String houseId,
    required String postId,
    required String newContent,
  }) async {
    if (newContent.trim().isEmpty) throw 'Nội dung không được để trống.';
    await _diariesRef(houseId).doc(postId).update({
      'content': _sanitize(newContent),
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── LẤY 1 lần (không stream) ──────────────────────────────────────────
  Future<List<DiaryPost>> fetchDiary(
    String houseId, {
    int limit = AppConfig.diaryPageSize,
  }) async {
    final snap = await _diariesRef(houseId)
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();

    final posts = <DiaryPost>[];
    for (var doc in snap.docs) {
      try {
        posts.add(DiaryPost.fromJson(doc.id, doc.data()));
      } catch (_) {}
    }
    return posts;
  }

  // ── Sanitize input ────────────────────────────────────────────────────
  String _sanitize(String input) {
    return input.replaceAll('<', '&lt;').replaceAll('>', '&gt;').trim();
  }

  // ── SCRIPT MIGRATION TỰ ĐỘNG ──────────────────────────────────────────
  Future<void> migrateDiariesFromRTDB(String houseId) async {
    final snap = await _rtdb.child('houses/$houseId/diary').get();
    if (!snap.exists || snap.value == null) return;
    
    final raw = snap.value;
    if (raw is! Map) return;

    final batch = _firestore.batch();
    int count = 0;

    raw.forEach((key, value) {
      if (value is Map) {
        final docRef = _diariesRef(houseId).doc(key.toString());
        batch.set(docRef, Map<String, dynamic>.from(value), SetOptions(merge: true));
        count++;
      }
    });

    if (count > 0) {
      await batch.commit();
      // Optional: Delete from RTDB after migration to save bandwidth
      // await _rtdb.child('houses/$houseId/diary').remove();
    }
  }
}
