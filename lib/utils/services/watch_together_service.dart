import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_error_mapper.dart';

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

  String _normalizeVideoType(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'direct' ? 'direct' : 'youtube';
  }

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
    final normalizedHouseId = houseId.trim();
    final normalizedVideoUrl = videoUrl.trim();
    if (uid == null || normalizedHouseId.isEmpty || normalizedVideoUrl.isEmpty) {
      return;
    }

    await _db.ref('houses/$normalizedHouseId/movie_sync').set({
      'videoUrl': normalizedVideoUrl,
      'videoTitle': videoTitle.trim(),
      'videoType': _normalizeVideoType(videoType),
      'isPlaying': false,
      'positionSec': 0.0,
      'createdBy': uid,
      'updatedBy': uid,
      'updatedByName': updatedByName?.trim() ?? '',
      if (inviteId != null && inviteId.trim().isNotEmpty)
        'inviteId': inviteId.trim(),
      if (originClientId != null && originClientId.trim().isNotEmpty)
        'originClientId': originClientId.trim(),
      'lastUpdatedAt': ServerValue.timestamp,
      'sessionActive': true,
    });
  }

  /// Huỷ phòng xem (host thoát)
  Future<void> endSession(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/movie_sync').update({
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
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    final updates = <String, dynamic>{
      'isPlaying': isPlaying,
      'positionSec': positionSec.isNegative ? 0.0 : positionSec,
      if (durationSec != null) 'durationSec': durationSec.isNegative ? 0.0 : durationSec,
      if (uid != null) 'updatedBy': uid,
      if (updatedByName != null && updatedByName.trim().isNotEmpty)
        'updatedByName': updatedByName.trim(),
      if (originClientId != null && originClientId.trim().isNotEmpty)
        'originClientId': originClientId.trim(),
      'lastUpdatedAt': ServerValue.timestamp,
    };
    await _db.ref('houses/$normalizedHouseId/movie_sync').update(updates);
  }

  /// Tua video đến vị trí mới (Seek) — người kia tự tua theo
  Future<void> seek(
    String houseId,
    double positionSec, {
    String? originClientId,
    String? updatedByName,
  }) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    await _db.ref('houses/$normalizedHouseId/movie_sync').update({
      'positionSec': positionSec.isNegative ? 0.0 : positionSec,
      if (uid != null) 'updatedBy': uid,
      if (updatedByName != null && updatedByName.trim().isNotEmpty)
        'updatedByName': updatedByName.trim(),
      if (originClientId != null && originClientId.trim().isNotEmpty)
        'originClientId': originClientId.trim(),
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
    final normalizedHouseId = houseId.trim();
    final normalizedVideoUrl = videoUrl.trim();
    if (normalizedHouseId.isEmpty || normalizedVideoUrl.isEmpty) return;
    await _db.ref('houses/$normalizedHouseId/movie_sync').update({
      'videoUrl': normalizedVideoUrl,
      'videoTitle': videoTitle.trim(),
      'videoType': _normalizeVideoType(videoType),
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
    final normalizedHouseId = houseId.trim();
    final normalizedVideoUrl = videoUrl.trim();
    if (uid == null || normalizedHouseId.isEmpty || normalizedVideoUrl.isEmpty) {
      return null;
    }

    final inviteRef = _db.ref('houses/$normalizedHouseId/cinema_invites').push();
    final inviteId = inviteRef.key;
    if (inviteId == null) return null;

    final safeTitle =
        videoTitle.trim().isEmpty ? 'phim đang chiếu' : videoTitle;
    await inviteRef.set({
      'fromUid': uid,
      'fromName': senderName.trim(),
      'videoTitle': safeTitle,
      'videoUrl': normalizedVideoUrl,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });

    try {
      await _db.ref('notification_queue').push().set({
        'houseId': normalizedHouseId,
        'house_id': normalizedHouseId,
        'sender_uid': uid,
        'title': '${senderName.trim()} mời bạn vào rạp phim',
        'body': 'Chấp nhận để xem "$safeTitle" cùng nhau.',
        'data': {
          'screen': 'cinema',
          'type': 'cinema_invite',
          'houseId': normalizedHouseId,
          'targetHouseId': normalizedHouseId,
          'inviteId': inviteId,
          'url': normalizedVideoUrl,
          'title': safeTitle,
        },
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Failed to queue cinema invite notification: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xếp hàng thông báo mời xem phim.',
      ).message}');
    }

    return inviteId;
  }

  Future<void> acceptCinemaInvite({
    required String houseId,
    required String inviteId,
    required String accepterName,
  }) async {
    final uid = _auth.currentUser?.uid;
    final normalizedHouseId = houseId.trim();
    final normalizedInviteId = inviteId.trim();
    if (uid == null || normalizedHouseId.isEmpty || normalizedInviteId.isEmpty) {
      return;
    }

    await _db.ref('houses/$normalizedHouseId/cinema_invites/$normalizedInviteId').update({
      'status': 'accepted',
      'acceptedByUid': uid,
      'acceptedByName': accepterName.trim(),
      'acceptedAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Stream<MovieSyncState?> listenToSession(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<MovieSyncState?>.value(null);
    }
    return _db.ref('houses/$normalizedHouseId/movie_sync').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
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
    final normalizedHouseId = houseId.trim();
    final normalizedMessage = message.trim();
    if (uid == null || normalizedHouseId.isEmpty || normalizedMessage.isEmpty) {
      return;
    }

    await _db.ref('houses/$normalizedHouseId/movie_chat').push().set({
      'text': normalizedMessage,
      'color': color.trim().isEmpty ? '#FFFFFF' : color.trim(),
      'fromUid': uid,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Stream danmaku mới nhất (UI vẽ bay qua màn hình)
  Stream<DanmakuMessage?> listenToDanmaku(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<DanmakuMessage?>.value(null);
    }
    return _db
        .ref('houses/$normalizedHouseId/movie_chat')
        .orderByChild('createdAt')
        .limitToLast(1)
        .onChildAdded
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      data['id'] = event.snapshot.key ?? '';
      return DanmakuMessage.fromMap(data);
    });
  }

  /// Xóa danmaku cũ hơn 10 phút (tránh tích tụ rác Firebase)
  Future<void> cleanOldDanmaku(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final cutoff = DateTime.now()
        .subtract(const Duration(minutes: 10))
        .millisecondsSinceEpoch;
    final snap = await _db
        .ref('houses/$normalizedHouseId/movie_chat')
        .orderByChild('createdAt')
        .endAt(cutoff)
        .get();
    if (!snap.exists || snap.value is! Map) return;
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    for (final key in data.keys) {
      await _db.ref('houses/$normalizedHouseId/movie_chat/$key').remove();
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
      positionSec: ((map['positionSec'] as num?)?.toDouble() ?? 0.0).clamp(0.0, double.infinity),
      durationSec: ((map['durationSec'] as num?)?.toDouble() ?? 0.0).clamp(0.0, double.infinity),
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
      createdAt: _asTimestamp(map['createdAt']),
    );
  }
}

int _asTimestamp(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
