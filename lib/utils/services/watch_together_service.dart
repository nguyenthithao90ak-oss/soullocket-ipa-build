import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ============================================================
///  WatchTogetherService — Gra (Logic/Data)
///  Rạp Chiếu Phim Đôi Realtime — Watch Together (Phase 17+)
///
///  Chức năng:
///  1. Đồng bộ trạng thái Play / Pause / Seek của video.
///  2. Chọn nguồn phim: YouTube URL hoặc link video trực tiếp.
///  3. Chat danmaku (tin nhắn trôi ngang màn hình) trong khi xem.
///  4. Phòng xem (session) có thể tạo / huỷ.
///  5. Đọc trạng thái người yêu đang xem phim gì (Presence Phim).
/// ============================================================
class WatchTogetherService {
  static final WatchTogetherService _instance =
      WatchTogetherService._internal();
  factory WatchTogetherService() => _instance;
  WatchTogetherService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────
  // 1. TẠO / THAM GIA PHÒNG XEM
  // ─────────────────────────────────────────────────────────────

  /// Tạo phòng xem phim mới hoặc ghi đè phòng cũ của nhà
  Future<void> createSession({
    required String houseId,
    required String videoUrl,
    String videoTitle = '',
    String videoType = 'youtube', // youtube | direct
    String? inviteId,
    String? originClientId,
    String? updatedByName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.ref('houses/$houseId/movie_sync').set({
      'videoUrl': videoUrl,
      'videoTitle': videoTitle,
      'videoType': videoType,
      'isPlaying': false,
      'positionSec': 0.0,
      'createdBy': uid,
      'updatedBy': uid,
      'updatedByName': updatedByName ?? '',
      if (inviteId != null && inviteId.isNotEmpty) 'inviteId': inviteId,
      if (originClientId != null && originClientId.isNotEmpty)
        'originClientId': originClientId,
      'lastUpdatedAt': ServerValue.timestamp,
      'sessionActive': true,
    });
  }

  /// Huỷ phòng xem (host thoát)
  Future<void> endSession(String houseId) async {
    await _db.ref('houses/$houseId/movie_sync').update({
      'sessionActive': false,
      'isPlaying': false,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ĐIỀU KHIỂN PHÁT VIDEO (ĐỒNG BỘ REALTIME)
  // ─────────────────────────────────────────────────────────────

  /// Gửi tín hiệu Play hoặc Pause + vị trí hiện tại
  Future<void> updatePlaybackState({
    required String houseId,
    required bool isPlaying,
    required double positionSec,
    double? durationSec,
    String? originClientId,
    String? updatedByName,
  }) async {
    final uid = _auth.currentUser?.uid;
    final updates = <String, dynamic>{
      'isPlaying': isPlaying,
      'positionSec': positionSec,
      if (durationSec != null) 'durationSec': durationSec,
      if (uid != null) 'updatedBy': uid,
      if (updatedByName != null) 'updatedByName': updatedByName,
      if (originClientId != null) 'originClientId': originClientId,
      'lastUpdatedAt': ServerValue.timestamp,
    };
    await _db.ref('houses/$houseId/movie_sync').update(updates);
  }

  /// Tua video đến vị trí mới (Seek) — người kia tự tua theo
  Future<void> seek(
    String houseId,
    double positionSec, {
    String? originClientId,
    String? updatedByName,
  }) async {
    final uid = _auth.currentUser?.uid;
    await _db.ref('houses/$houseId/movie_sync').update({
      'positionSec': positionSec,
      if (uid != null) 'updatedBy': uid,
      if (updatedByName != null) 'updatedByName': updatedByName,
      if (originClientId != null) 'originClientId': originClientId,
      'seekedAt': ServerValue.timestamp,
    });
  }

  /// Đổi phim đang xem
  Future<void> changeVideo({
    required String houseId,
    required String videoUrl,
    String videoTitle = '',
    String videoType = 'youtube',
  }) async {
    await _db.ref('houses/$houseId/movie_sync').update({
      'videoUrl': videoUrl,
      'videoTitle': videoTitle,
      'videoType': videoType,
      'isPlaying': false,
      'positionSec': 0.0,
      'lastUpdatedAt': ServerValue.timestamp,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 3. STREAM LẮNG NGHE TRẠNG THÁI (UI TRAE SẼ DÙNG)
  // ─────────────────────────────────────────────────────────────

  /// Stream trạng thái phòng xem (isPlaying, positionSec, videoUrl...)
  Future<String?> sendCinemaInvite({
    required String houseId,
    required String senderName,
    required String videoTitle,
    required String videoUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final inviteRef = _db.ref('houses/$houseId/cinema_invites').push();
    final inviteId = inviteRef.key;
    if (inviteId == null) return null;

    final safeTitle =
        videoTitle.trim().isEmpty ? 'phim đang chiếu' : videoTitle;
    await inviteRef.set({
      'fromUid': uid,
      'fromName': senderName,
      'videoTitle': safeTitle,
      'videoUrl': videoUrl,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });

    try {
      await _db.ref('notification_queue').push().set({
        'houseId': houseId,
        'house_id': houseId,
        'sender_uid': uid,
        'title': '$senderName mời bạn vào rạp phim',
        'body': 'Chấp nhận để xem "$safeTitle" cùng nhau.',
        'data': {
          'screen': 'cinema',
          'type': 'cinema_invite',
          'houseId': houseId,
          'targetHouseId': houseId,
          'inviteId': inviteId,
          'url': videoUrl,
          'title': safeTitle,
        },
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Failed to queue cinema invite notification: $e');
    }

    return inviteId;
  }

  Future<void> acceptCinemaInvite({
    required String houseId,
    required String inviteId,
    required String accepterName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || inviteId.trim().isEmpty) return;

    await _db.ref('houses/$houseId/cinema_invites/$inviteId').update({
      'status': 'accepted',
      'acceptedByUid': uid,
      'acceptedByName': accepterName,
      'acceptedAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Stream<MovieSyncState?> listenToSession(String houseId) {
    return _db.ref('houses/$houseId/movie_sync').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return MovieSyncState.fromMap(data);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 4. DANMAKU — TIN NHẮN TRÔI NGANG MÀN HÌNH
  // ─────────────────────────────────────────────────────────────

  /// Gửi 1 tin nhắn chạy ngang màn hình khi đang xem phim
  Future<void> sendDanmaku({
    required String houseId,
    required String message,
    String color = '#FFFFFF',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.ref('houses/$houseId/movie_chat').push().set({
      'text': message,
      'color': color,
      'fromUid': uid,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Stream danmaku mới nhất (UI vẽ bay qua màn hình)
  Stream<DanmakuMessage?> listenToDanmaku(String houseId) {
    return _db
        .ref('houses/$houseId/movie_chat')
        .orderByChild('createdAt')
        .limitToLast(1)
        .onChildAdded
        .map((event) {
      if (!event.snapshot.exists) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      data['id'] = event.snapshot.key ?? '';
      return DanmakuMessage.fromMap(data);
    });
  }

  /// Xóa danmaku cũ hơn 10 phút (tránh tích tụ rác Firebase)
  Future<void> cleanOldDanmaku(String houseId) async {
    final cutoff = DateTime.now()
        .subtract(const Duration(minutes: 10))
        .millisecondsSinceEpoch;
    final snap = await _db
        .ref('houses/$houseId/movie_chat')
        .orderByChild('createdAt')
        .endAt(cutoff)
        .get();
    if (!snap.exists) return;
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    for (final key in data.keys) {
      await _db.ref('houses/$houseId/movie_chat/$key').remove();
    }
  }
}

// ─── MODELS ─────────────────────────────────────────────────────────────────

class MovieSyncState {
  final String videoUrl;
  final String videoTitle;
  final String videoType;
  final bool isPlaying;
  final double positionSec;
  final double durationSec;
  final bool sessionActive;
  final int lastUpdatedAt;
  final String originClientId;
  final String updatedByName;
  final String inviteId;

  MovieSyncState({
    required this.videoUrl,
    required this.videoTitle,
    required this.videoType,
    required this.isPlaying,
    required this.positionSec,
    required this.durationSec,
    required this.sessionActive,
    required this.lastUpdatedAt,
    required this.originClientId,
    required this.updatedByName,
    required this.inviteId,
  });

  factory MovieSyncState.fromMap(Map<String, dynamic> map) {
    return MovieSyncState(
      videoUrl: map['videoUrl']?.toString() ?? '',
      videoTitle: map['videoTitle']?.toString() ?? '',
      videoType: map['videoType']?.toString() ?? 'youtube',
      isPlaying: map['isPlaying'] == true,
      positionSec: (map['positionSec'] as num?)?.toDouble() ?? 0.0,
      durationSec: (map['durationSec'] as num?)?.toDouble() ?? 0.0,
      sessionActive: map['sessionActive'] == true,
      lastUpdatedAt: (map['lastUpdatedAt'] as num?)?.toInt() ?? 0,
      originClientId: map['originClientId']?.toString() ?? '',
      updatedByName: map['updatedByName']?.toString() ?? '',
      inviteId: map['inviteId']?.toString() ?? '',
    );
  }
}

class DanmakuMessage {
  final String id;
  final String text;
  final String color;
  final String fromUid;
  final int createdAt;

  DanmakuMessage({
    required this.id,
    required this.text,
    required this.color,
    required this.fromUid,
    required this.createdAt,
  });

  factory DanmakuMessage.fromMap(Map<String, dynamic> map) {
    return DanmakuMessage(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      color: map['color']?.toString() ?? '#FFFFFF',
      fromUid: map['fromUid']?.toString() ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
