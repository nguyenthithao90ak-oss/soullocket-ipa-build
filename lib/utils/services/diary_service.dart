import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/models/diary_post.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';

/// DiaryService — quản lý tâm tư (nhật ký) trong Firebase
/// Path: houses/{houseId}/diary/{postId}
/// Hỗ trợ Offline: Khi mất mạng, bài viết sẽ được lưu vào hàng đợi SQLite
/// và tự đồng bộ khi có mạng trở lại.
class DiaryService {
  static final DiaryService _instance = DiaryService._internal();

  factory DiaryService() => _instance;
  DiaryService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // ── LISTEN realtime ────────────────────────────────────────────────────
  Stream<List<DiaryPost>> streamDiary(String houseId) {
    return _dbRef
        .child('houses/$houseId/diary')
        .orderByChild('ts')
        .limitToLast(AppConfig.diaryPageSize)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return <DiaryPost>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <DiaryPost>[];

      final posts = <DiaryPost>[];
      raw.forEach((key, value) {
        if (value is Map) {
          try {
            posts.add(DiaryPost.fromJson(key.toString(), value));
          } catch (_) {}
        }
      });
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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

    // Nếu đang online → ghi lên Firebase bình thường
    if (ConnectivityService().isOnline) {
      final newRef = _dbRef.child('houses/$houseId/diary').push();
      await newRef.set(postData);
      return newRef.key!;
    } else {
      // Offline → lưu vào SQLite hàng đợi, đồng bộ sau
      final tempId = 'offline_${now}_$authorId';
      postData['_tempId'] = tempId;
      await LocalDatabaseService().enqueueSync(
        'houses/$houseId/diary',
        'PUSH',
        jsonEncode(postData),
        operationId: tempId,
        entityType: 'diary_post',
      );
      return tempId; // ID tạm, không dùng để query Firebase
    }
  }

  // ── XÓA nhật ký ───────────────────────────────────────────────────────
  Future<void> deleteDiaryPost({
    required String houseId,
    required String postId,
    required String requestingAuthorId,
  }) async {
    final snap = await _dbRef.child('houses/$houseId/diary/$postId').get();
    if (!snap.exists) throw 'Bài viết không tồn tại.';
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final owner = (data['authorId'] ?? '').toString();
    if (owner.isNotEmpty && owner != requestingAuthorId) {
      throw 'Bạn không có quyền xóa bài viết này.';
    }
    await _dbRef.child('houses/$houseId/diary/$postId').remove();
  }

  // ── SỬA caption nhật ký ───────────────────────────────────────────────
  Future<void> updateDiaryContent({
    required String houseId,
    required String postId,
    required String newContent,
  }) async {
    if (newContent.trim().isEmpty) throw 'Nội dung không được để trống.';
    await _dbRef.child('houses/$houseId/diary/$postId').update({
      'content': _sanitize(newContent),
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── LẤY 1 lần (không stream) ──────────────────────────────────────────
  Future<List<DiaryPost>> fetchDiary(
    String houseId, {
    int limit = AppConfig.diaryPageSize,
  }) async {
    final snap = await _dbRef
        .child('houses/$houseId/diary')
        .orderByChild('ts')
        .limitToLast(limit)
        .get();

    if (!snap.exists || snap.value == null) return [];
    final raw = snap.value;
    if (raw is! Map) return [];

    final posts = <DiaryPost>[];
    raw.forEach((key, value) {
      if (value is Map) {
        try {
          posts.add(DiaryPost.fromJson(key.toString(), value));
        } catch (_) {}
      }
    });
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return posts;
  }

  // ── Sanitize input ────────────────────────────────────────────────────
  String _sanitize(String input) {
    return input.replaceAll('<', '&lt;').replaceAll('>', '&gt;').trim();
  }
}
